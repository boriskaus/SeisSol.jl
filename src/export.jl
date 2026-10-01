"""
    seissol_executable() -> String

Path of the SeisSol executable inside the Julia artifact. To run it outside Julia use
[`export_prefix`](@ref), as the executable needs the libraries of its dependencies.
"""
function seissol_executable()
    check_available()
    return SeisSol_jll.seissol_path
end

# Executables that are copied into an exported prefix: SeisSol itself and the MPI launcher.
const EXPORTED_BINARIES = r"^(seissol|seissol_proxy|mpiexec.*|mpirun|hydra_.*)$"

function link_or_copy(src, dst; link::Bool)
    ispath(dst) && return
    if islink(src)
        symlink(readlink(src), dst)
    elseif link
        try
            Base.Filesystem.hardlink(src, dst)
        catch
            cp(src, dst)
        end
    else
        cp(src, dst)
    end
    return
end

"""
    export_prefix(dir; link=true) -> dir

Create a standalone installation of SeisSol in `dir` that can be used without Julia:
`dir/bin/seissol`, `dir/bin/seissol_proxy`, the MPI launcher `dir/bin/mpiexec`, and all shared
libraries they need in `dir/lib`. Files are hard-linked (falling back to copies) when
`link=true`, so that the export takes no extra disk space if `dir` is on the same file
system as `~/.julia/artifacts`.

```julia
using SeisSol
export_prefix("/opt/seissol")
```
```sh
cd tpv13; /opt/seissol/bin/mpiexec -n 4 /opt/seissol/bin/seissol parameters.par
```
"""
function export_prefix(dir::AbstractString; link::Bool = true)
    check_available()
    bin = mkpath(joinpath(dir, "bin"))
    lib = mkpath(joinpath(dir, "lib"))
    for d in SeisSol_jll.PATH_list
        isdir(d) || continue
        for f in readdir(d)
            p = joinpath(d, f)
            isfile(p) && occursin(EXPORTED_BINARIES, f) && link_or_copy(p, joinpath(bin, f); link)
        end
    end
    for d in SeisSol_jll.LIBPATH_list
        isdir(d) || continue
        for f in readdir(d)
            p = joinpath(d, f)
            if isfile(p) || islink(p)
                occursin(r"\.(so|dylib)", f) && link_or_copy(p, joinpath(lib, f); link)
            end
        end
    end
    return dir
end
