# Only the binary packages, without SeisSol.jl: the three JLLs have to be added in ONE call, as
# long as they are not registered (ASAGI_jll and easi_jll are dependencies of SeisSol_jll).
using Pkg
Pkg.activate(mktempdir())
Pkg.add([PackageSpec(url = "https://github.com/boriskaus/ASAGI_jll.jl"),
         PackageSpec(url = "https://github.com/boriskaus/easi_jll.jl"),
         PackageSpec(url = "https://github.com/boriskaus/SeisSol_jll.jl")])
using SeisSol_jll
if Sys.iswindows()
    SeisSol_jll.is_available() && error("a Windows binary is not expected")
    println("Windows: SeisSol_jll is not available, as intended")
else
    SeisSol_jll.is_available() || error("SeisSol_jll not available")
    SeisSol_jll.seissol_proxy() do exe
        run(`$exe 100 1 all`)
    end
    SeisSol_jll.seissol() do exe     # no input file: must abort but find all its libraries
        out = IOBuffer()
        run(pipeline(ignorestatus(`$exe`); stdout = out, stderr = out))
        occursin("Welcome to SeisSol", String(take!(out))) || error("the solver did not start")
    end
end
println("SeisSol_jll works on its own")
