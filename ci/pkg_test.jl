# `] test SeisSol` of the installed package, the way users run it.
using Pkg
Pkg.activate(mktempdir())
Pkg.add(url = "https://github.com/boriskaus/ASAGI_jll.jl")
Pkg.add(url = "https://github.com/boriskaus/easi_jll.jl")
Pkg.add(url = "https://github.com/boriskaus/SeisSol_jll.jl")
Pkg.add(url = "https://github.com/$(get(ENV, "GITHUB_REPOSITORY", "boriskaus/SeisSol.jl"))", rev = get(ENV, "GITHUB_SHA", "main"))
Pkg.test("SeisSol")
