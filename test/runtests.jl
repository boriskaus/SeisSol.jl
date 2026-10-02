using Test
using SeisSol
using SeisSol_jll

# The tests that start the solver are skipped wherever there is no SeisSol binary.
const RUN_SOLVER = SeisSol.solver_usable()

# The first testset mirrors the checks in SeisSol's own CI workflow
# (SeisSol/.github/workflows/build-seissol.yml): the solver must refuse to run without an
# input file, and each kernel of the proxy mini-app must run.
@testset "SeisSol CI checks" begin
    RUN_SOLVER || @info "Skipping tests that start SeisSol: SeisSol_jll is not available on this platform"
    @testset "solver without input fails" begin
        if RUN_SOLVER
            SeisSol_jll.seissol() do exe
                proc = run(pipeline(ignorestatus(`$exe`); stdout = devnull, stderr = devnull))
                @test !success(proc)
            end
        else
            @test_skip false
        end
    end

    @testset "proxy kernel $kernel" for kernel in
                                         ("ader", "localwoader", "local", "neigh", "neigh_dr", "godunov_dr", "all")
        if RUN_SOLVER
            mktemp() do log, io
                close(io)
                @test run_proxy(; kernel, cells = 100, timesteps = 1, logfile = log)
                @test occursin("PERFORMANCE SUMMARY", read(log, String))
            end
        else
            @test_skip false
        end
    end
end

@testset "standalone prefix (use without Julia)" begin
    RUN_SOLVER && @test isfile(seissol_executable())
    if RUN_SOLVER
        dir = export_prefix(joinpath(mktempdir(), "prefix"))
        ext = Sys.iswindows() ? ".exe" : ""
        @test isfile(joinpath(dir, "bin", "seissol" * ext)) && isfile(joinpath(dir, "bin", "mpiexec" * ext))
        # run the exported proxy with an EMPTY environment: everything must be found via RUNPATH
        out = IOBuffer()
        # nothing from the Julia environment is available: only the exported folder
        cleanenv = Sys.iswindows() ? Dict("SystemRoot" => ENV["SystemRoot"], "PATH" => joinpath(ENV["SystemRoot"], "System32")) : Dict{String,String}()
        cmd = setenv(`$(joinpath(dir, "bin", Sys.iswindows() ? "seissol_proxy.exe" : "seissol_proxy")) 50 1 all`, cleanenv)
        @test success(pipeline(cmd; stdout = out, stderr = devnull))
        @test occursin("PERFORMANCE SUMMARY", String(take!(out)))
    else
        @test_skip false
    end
end

@testset "parameter files" begin
    mktempdir() do dir
        par = joinpath(dir, "test.par")
        write(par, """
        &Output
        OutputFile = 'outputs/test'  ! prefix
        EndTime = 8.0
        OutputMask = 1 1 1
        RFileName = 'rec.dat'
        /
        """)
        @test get_parameter(par, "EndTime") == "8.0"
        @test get_parameter(par, "outputfile") == "outputs/test"
        @test_throws KeyError get_parameter(par, "Missing")

        set_parameters!(par; EndTime = 2.5, OutputFile = "new/out", OutputMask = [0, 1, 0])
        @test get_parameter(par, "EndTime") == "2.5"
        @test get_parameter(par, "OutputFile") == "new/out"
        @test get_parameter(par, "OutputMask") == "0 1 0"
        @test occursin("! prefix", read(par, String))   # comments are preserved
        @test_throws KeyError set_parameters!(par; Nope = 1)

        delete_parameter!(par, "RFileName")
        @test_throws KeyError get_parameter(par, "RFileName")
        @test_throws KeyError delete_parameter!(par, "RFileName")
        @test_throws ArgumentError run_seissol(joinpath(dir, "does_not_exist.par"))
    end
end

@testset "output helpers" begin
    mktempdir() do dir
        csv = joinpath(dir, "e-energy.csv")
        write(csv, """
        time,variable,measurement
        0.0,seismic_moment,0.0
        0.0,elastic_energy,1.0
        0.5,seismic_moment,1.0e18
        0.5,elastic_energy,2.0
        """)
        e = read_energy(csv)
        @test e["seismic_moment"].time == [0.0, 0.5]
        @test e["seismic_moment"].value == [0.0, 1.0e18]
        @test e["elastic_energy"].value == [1.0, 2.0]
    end
    @test moment_magnitude(1.0e18) ≈ 2 / 3 * 18 - 6.07
    io = IOBuffer()
    citation(io)
    @test occursin("Dumbser", String(take!(io)))
end

@testset "example manifest" begin
    @test length(examples()) >= 20
    for name in examples()
        ex = SeisSol.EXAMPLES[name]
        @test ex["status"] in keys(SeisSol.STATUS)
        @test all(f -> length(f["sha1"]) == 40 && f["size"] >= 0, ex["files"])
        # the main parameter file is part of the example
        isempty(ex["parfile"]) || @test any(f -> basename(f["path"]) == ex["parfile"], ex["files"])
    end
    io = IOBuffer()
    example_info("kaikoura"; io)
    @test occursin("runs", String(take!(io)))

    # a small example from the SeisSol examples repository (setup files only, no mesh)
    dir = mktempdir()
    par = @test_logs (:warn, r"mesh is not included") match_mode = :any download_example("examples/tpv5"; dir)
    @test isfile(par) && basename(par) == "parameters.par"
    @test get_parameter(par, "MeshFile") == "tpv5_f200m.puml.h5"
    @test !isdir(joinpath(dir, "figures"))

    # default location: a folder named after the example in the current directory; repeated
    # calls do not download again
    mktempdir() do tmp
        cd(tmp) do
            par = download_example("examples/tpv5")
            @test samefile(par, joinpath(tmp, "tpv5", "parameters.par"))
            t = mtime(par)
            @test download_example("examples/tpv5") == par
            @test mtime(par) == t
        end
    end
end

@testset "ASAGI example (Sulawesi: 3D velocity model read from NetCDF)" begin
    @test SeisSol.EXAMPLES["sulawesi"]["status"] == "runs"
    if RUN_SOLVER && !Sys.iswindows()    # ASAGI is not part of the Windows binary
        par = download_example("sulawesi"; dir = mktempdir())
        dir = dirname(par)
        set_parameters!(par; EndTime = 0.05)
        @test run_seissol(par; nprocs = 2, logfile = joinpath(dir, "seissol.log"))
        @test occursin("SeisSol done", read(joinpath(dir, "seissol.log"), String))
    else
        @test_skip false
    end
end

@testset "TPV13 dynamic rupture example" begin
    @test "tpv13" in examples(status = "runs")
    @test_throws ArgumentError download_example("nonexistent")

    function run_tpv13(nprocs)
        par = download_example("tpv13"; dir = mktempdir())
        dir = dirname(par)
        set_parameters!(par; EndTime = 1.0)
        @test run_seissol(par; nprocs, logfile = joinpath(dir, "seissol.log"))   # SeisSol creates outputs/ itself
        @test occursin("SeisSol done", read(joinpath(dir, "seissol.log"), String))
        energy = read_energy(joinpath(dir, "outputs", "tpv13-energy.csv"))
        M0 = energy["seismic_moment"]
        @test M0.time[end] ≈ 1.0
        @test isfinite(M0.value[end]) && M0.value[end] > 0
        @test all(isfinite, energy["elastic_energy"].value)
        return M0.value[end]
    end

    if RUN_SOLVER
        M1 = run_tpv13(1)
        # reference seismic moment at t = 1 s (SeisSol 1.3.2, order 4, double precision)
        @test M1 ≈ 3.03e18 rtol = 0.05
        if Sys.CPU_THREADS >= 2
            # the result must not depend on the number of MPI ranks (up to round-off/partitioning)
            @test run_tpv13(2) ≈ M1 rtol = 1e-3
        end
    else
        @test_skip false
    end
end
