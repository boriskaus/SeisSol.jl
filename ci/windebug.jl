# Debug run of the experimental Windows build of SeisSol under gdb (temporary, branch windows-debug).
using Pkg, Downloads
Pkg.activate(mktempdir())
Pkg.add(["CodecZlib", "HDF5_jll", "PARMETIS_jll", "yaml_cpp_jll", "Lua_jll", "MicrosoftMPI_jll", "CompilerSupportLibraries_jll"])
Pkg.add([PackageSpec(url = "https://github.com/boriskaus/ASAGI_jll.jl"),
         PackageSpec(url = "https://github.com/boriskaus/easi_jll.jl"),
         PackageSpec(url = "https://github.com/boriskaus/SeisSol.jl", rev = "main")])
using CodecZlib, Tar
using HDF5_jll, PARMETIS_jll, yaml_cpp_jll, Lua_jll, MicrosoftMPI_jll, CompilerSupportLibraries_jll, easi_jll
using SeisSol

jlls = (HDF5_jll, PARMETIS_jll, yaml_cpp_jll, Lua_jll, MicrosoftMPI_jll, CompilerSupportLibraries_jll, easi_jll)
dirs = unique(vcat((vcat(collect(m.PATH_list), collect(m.LIBPATH_list)) for m in jlls)...))
println("DLL search dirs:"); foreach(d -> println("  ", d), dirs)

root = mktempdir()
tarball = joinpath(root, "seissol.tar.gz")
Downloads.download(get(ENV, "WIN_TARBALL", "https://github.com/boriskaus/SeisSol_jll.jl/releases/download/windows-debug/seissol-win-debug.tar.gz"), tarball)
inst = joinpath(root, "inst"); mkpath(inst)
open(tarball) do io
    Tar.extract(GzipDecompressorStream(io), inst)
end
exe = joinpath(inst, "bin", "seissol.exe"); proxy = joinpath(inst, "bin", "seissol_proxy.exe")
@show isfile(exe) isfile(proxy)

winpath = join([replace(d, "/" => "\\") for d in dirs], ";") * ";" * ENV["PATH"]
env = Dict(ENV); env["PATH"] = winpath; env["SEISSOL_COMMTHREAD"] = "0"; env["OMP_NUM_THREADS"] = "1"
gdb = Sys.which("gdb")
println("gdb = ", gdb)

function dbg(label, cmd; dir = pwd())
    println("\n==================== $label ====================")
    full = `$gdb -batch -ex "set pagination off" -ex "set confirm off" -ex run -ex "bt 30" -ex "thread apply all bt 6" --args $cmd`
    p = run(pipeline(ignorestatus(Cmd(full; env = env, dir = dir)); stderr = stdout))
    println("---- gdb exit: ", p.exitcode)
end
function plain(label, cmd; dir = pwd())
    println("\n==================== $label ====================")
    p = run(pipeline(ignorestatus(Cmd(cmd; env = env, dir = dir)); stderr = stdout))
    println("---- exit: 0x", string(UInt32(p.exitcode % UInt32), base = 16))
end

for k in ("ader", "localwoader", "local", "neigh", "neigh_dr", "godunov_dr")
    dbg("proxy $k under gdb", `$proxy 100 1 $k`)
end
plain("proxy plain", `$proxy 100 1 all`)

par = download_example("tpv13"; dir = joinpath(root, "tpv13"))
set_parameters!(par; EndTime = 0.2)
mkpath(joinpath(dirname(par), "outputs"))
d = dirname(par)
dbg("solver (1 rank, no mpiexec) under gdb", `$exe parameters.par`; dir = d)
mpiexec = joinpath(MicrosoftMPI_jll.artifact_dir, "bin", "mpiexec.exe")
plain("mpiexec -n 1", `$mpiexec -n 1 $exe parameters.par`; dir = d)
plain("mpiexec -n 2", `$mpiexec -n 2 $exe parameters.par`; dir = d)
