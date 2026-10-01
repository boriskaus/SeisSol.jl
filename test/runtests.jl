using Test
using SeisSol
using SeisSol_jll

# The first testset mirrors the checks in SeisSol's own CI workflow
# (SeisSol/.github/workflows/build-seissol.yml): the solver must refuse to run without an
# input file, and each kernel of the proxy mini-app must run.
@testset "SeisSol CI checks" begin
    @test SeisSol_jll.is_available()

    @testset "solver without input fails" begin
        SeisSol_jll.seissol() do exe
            proc = run(pipeline(ignorestatus(`$exe`); stdout = devnull, stderr = devnull))
            @test !success(proc)
        end
    end

    @testset "proxy kernel $kernel" for kernel in
                                         ("ader", "localwoader", "local", "neigh", "neigh_dr", "godunov_dr", "all")
        mktemp() do log, io
            close(io)
            @test run_proxy(; kernel, cells = 100, timesteps = 1, logfile = log)
            @test occursin("PERFORMANCE SUMMARY", read(log, String))
        end
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

@testset "TPV13 dynamic rupture example" begin
    @test examples() == ["tpv13"]
    @test_throws ArgumentError download_example("nonexistent")

    function run_tpv13(nprocs)
        par = download_example("tpv13")
        dir = dirname(par)
        set_parameters!(par; EndTime = 1.0)
        mkpath(joinpath(dir, "outputs"))
        @test run_seissol(par; nprocs, logfile = joinpath(dir, "seissol.log"))
        @test occursin("SeisSol done", read(joinpath(dir, "seissol.log"), String))
        energy = read_energy(joinpath(dir, "outputs", "tpv13-energy.csv"))
        M0 = energy["seismic_moment"]
        @test M0.time[end] ≈ 1.0
        @test isfinite(M0.value[end]) && M0.value[end] > 0
        @test all(isfinite, energy["elastic_energy"].value)
        return M0.value[end]
    end

    M1 = run_tpv13(1)
    # reference seismic moment at t = 1 s (SeisSol 1.3.2, order 4, double precision)
    @test M1 ≈ 3.03e18 rtol = 0.05
    if Sys.CPU_THREADS >= 2
        # the result must not depend on the number of MPI ranks (up to round-off/partitioning)
        @test run_tpv13(2) ≈ M1 rtol = 1e-3
    end
end
