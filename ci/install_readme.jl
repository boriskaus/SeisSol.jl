# Follows the README from scratch in a clean environment: install, run_proxy, export_prefix,
# run SeisSol from a shell without Julia. Used by .github/workflows/Install.yml.
using Pkg
repo = get(ENV, "GITHUB_REPOSITORY", "boriskaus/SeisSol.jl")
rev = get(ENV, "GITHUB_SHA", "main")

envdir = mktempdir()
Pkg.activate(envdir)
Pkg.add(url = "https://github.com/boriskaus/ASAGI_jll.jl")
Pkg.add(url = "https://github.com/boriskaus/easi_jll.jl")
Pkg.add(url = "https://github.com/boriskaus/SeisSol_jll.jl")
Pkg.add(url = "https://github.com/$repo", rev = rev)

using SeisSol

if Sys.iswindows()
    # there is no usable Windows binary: a clear message pointing to WSL2 is expected
    msg = try run_proxy(); "" catch e; sprint(showerror, e) end
    occursin("WSL2", msg) || error("expected the WSL2 hint on Windows, got: $msg")
    println("Windows: blocked with a clear message, as intended")
    exit(0)
end

println("== run_proxy()")
run_proxy(; cells = 200, timesteps = 1)

println("== download_example + run_seissol (2 MPI ranks)")
par = download_example("tpv13"; dir = joinpath(mktempdir(), "tpv13"))
set_parameters!(par; EndTime = 0.5)
run_seissol(par; nprocs = 2, logfile = joinpath(dirname(par), "julia_run.log"))
M0 = read_energy(joinpath(dirname(par), "outputs", "tpv13-energy.csv"))["seismic_moment"].value[end]
println("seismic moment after 0.5 s: ", M0)
isfinite(M0) && M0 > 0 || error("bad seismic moment")

println("== export_prefix and a run from a shell without Julia")
prefix = export_prefix(joinpath(mktempdir(), "seissol"))
bin(name) = joinpath(prefix, "bin", name)
# nothing from the Julia environment is available: only the exported folder
cleanenv = Dict("HOME" => homedir(), "PATH" => "/usr/bin:/bin", "SEISSOL_COMMTHREAD" => "0", "OMP_NUM_THREADS" => "1")
run(setenv(`$(bin("seissol_proxy")) 100 1 all`, cleanenv))
rm(joinpath(dirname(par), "outputs"); recursive = true)   # SeisSol creates it again
run(setenv(`$(bin("mpiexec")) -n 2 $(bin("seissol")) parameters.par`, cleanenv; dir = dirname(par)))
M1 = read_energy(joinpath(dirname(par), "outputs", "tpv13-energy.csv"))["seismic_moment"].value[end]
M1 ≈ M0 || error("shell run ($M1) differs from the Julia run ($M0)")
println("shell run reproduces the Julia run: ", M1)
