const PROXY_NAME = "SeisSol_proxy_Release_dnoarch_4_elastic"

function check_available()
    if !SeisSol_jll.is_available()
        error("""SeisSol_jll is not available for this platform/MPI combination.
              The binary is built for MPICH (Linux, macOS) and Microsoft MPI (Windows).
              If you changed the MPI implementation in MPIPreferences, switch back with
                  using MPIPreferences; MPIPreferences.use_jll_binary("MPICH_jll")
              and restart Julia.""")
    end
    return nothing
end

"""
    default_nthreads(nprocs)

OpenMP threads per MPI rank. With several MPI ranks this is 1 (pure MPI, one core per rank);
a single rank uses the available hardware threads, at most 8 (the problems this generic build
is meant for are small).
"""
default_nthreads(nprocs::Integer) = nprocs > 1 ? 1 : clamp(Sys.CPU_THREADS, 1, 8)

function seissol_env(nthreads, commthread, pin)
    env = ["OMP_NUM_THREADS" => string(nthreads),
           "SEISSOL_COMMTHREAD" => commthread ? "1" : "0"]
    if pin
        push!(env, "OMP_PLACES" => "cores", "OMP_PROC_BIND" => "close")
    end
    return env
end

function launch(exe::AbstractString, args; nprocs, nthreads, commthread, pin, dir, logfile)
    env = seissol_env(nthreads, commthread, pin)
    return MPI.mpiexec() do mpiexec
        cmd = Cmd(`$mpiexec -n $nprocs $exe $args`; dir = dir)
        cmd = addenv(cmd, env...)
        if logfile === nothing
            run(cmd)
        else
            run(pipeline(cmd; stdout = logfile, stderr = logfile))
        end
        true
    end
end

"""
    run_seissol(parfile; nprocs=1, nthreads=default_nthreads(nprocs), dir=dirname(parfile),
                commthread=false, pin=false, logfile=nothing)

Run SeisSol on the parameter file `parfile` with `nprocs` MPI ranks and `nthreads` OpenMP
threads per rank. Relative paths inside the parameter file (mesh, output) are interpreted
relative to `dir`, which defaults to the folder of the parameter file.

Keywords
- `commthread`: use a dedicated MPI communication thread (SeisSol default). It is switched off
  by default, which is the robust choice on desktops and CI machines with few cores; it needs a
  free core per rank.
- `pin`: pin OpenMP threads to cores (`OMP_PLACES=cores`, `OMP_PROC_BIND=close`).
- `logfile`: write the SeisSol output to this file instead of the terminal.

Throws if SeisSol fails and returns `true` otherwise.
"""
function run_seissol(parfile::AbstractString; nprocs::Integer = 1,
                     nthreads::Integer = default_nthreads(nprocs),
                     dir::AbstractString = dirname(abspath(parfile)),
                     commthread::Bool = false, pin::Bool = false, logfile = nothing)
    check_available()
    isfile(parfile) || throw(ArgumentError("parameter file not found: $parfile"))
    par = relpath(abspath(parfile), abspath(dir))
    return SeisSol_jll.seissol() do exe
        launch(exe, par; nprocs, nthreads, commthread, pin, dir = abspath(dir), logfile)
    end
end

"""
    run_proxy(; kernel="all", cells=100, timesteps=1, nthreads=1, logfile=nothing)

Run the SeisSol *proxy* mini-application, a self-contained kernel benchmark that needs no
input files. `kernel` is one of `"all"`, `"ader"`, `"localwoader"`, `"local"`, `"neigh"`,
`"neigh_dr"` or `"godunov_dr"`. Useful to check the installation and to estimate performance.
"""
function run_proxy(; kernel::AbstractString = "all", cells::Integer = 100,
                   timesteps::Integer = 1, nthreads::Integer = 1, logfile = nothing)
    check_available()
    return SeisSol_jll.seissol() do exe
        proxy = joinpath(dirname(exe), PROXY_NAME * (Sys.iswindows() ? ".exe" : ""))
        isfile(proxy) || error("proxy executable not found: $proxy")
        launch(proxy, `$cells $timesteps $kernel`; nprocs = 1, nthreads,
               commthread = false, pin = false, dir = pwd(), logfile)
    end
end
