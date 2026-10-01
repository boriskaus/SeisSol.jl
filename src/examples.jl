# Example setups are taken from the SeisSol training material (BSD-3-Clause,
# https://github.com/SeisSol/Training). Meshes are generated with PUMGen/gmsh by the SeisSol
# team; this package does not create meshes.
const TRAINING_COMMIT = "7436574a00888541a600e4f5910681b71b6a8a4d"
const TRAINING_URL = "https://raw.githubusercontent.com/SeisSol/Training/$TRAINING_COMMIT"

const EXAMPLES = Dict(
    "tpv13" => (
        description = "SCEC TPV13: spontaneous rupture on a normal fault with off-fault " *
                      "plasticity (coarse training mesh, 37k tetrahedra)",
        folder = "tpv13",
        files = Dict(
            "parameters.par" => "d64ccdad252f572d62a075f2369e6ace1727dfe488ba7b2e825a1dcfd59a2fb5",
            "tpv12_13_fault.yaml" => "dff210284c396474ffa441e3e837bffc7f6a03c98fb58938bee996a0917666d6",
            "tpv12_13_initial_stress.yaml" => "dc437fe17e807eee7d5f87efff2336eb7eca81ae6e1c0983e8b9b79d07a37d96",
            "tpv12_13_material.yaml" => "c7d3419bdb5adfb56c13fc450e6cf5f325cb1893e8ed133e2d7f6e9386632220",
            "tpv13_training.puml.h5" => "214a11addcaa07cd4fb9f4d1b74b021f837bd6998a919b91b3ae1d966f805aa7",
        ),
    ),
)

"""
    examples()

Names of the examples that can be fetched with [`download_example`](@ref).
"""
examples() = sort!(collect(keys(EXAMPLES)))

"""
    download_example(name; dir=mktempdir()) -> parfile

Download the example `name` (see [`examples`](@ref)) from the SeisSol training repository into
`dir`, verify the checksums, and return the path of its parameter file. The record-point file
that the original parameter file refers to is not part of the training repository, so that
entry is removed.

```julia
par = download_example("tpv13")
set_parameters!(par; EndTime = 1.0)
run_seissol(par; nprocs = 2)
```
"""
function download_example(name::AbstractString; dir::AbstractString = mktempdir())
    haskey(EXAMPLES, name) || throw(ArgumentError("unknown example \"$name\"; available: $(examples())"))
    ex = EXAMPLES[name]
    mkpath(dir)
    for (file, checksum) in ex.files
        path = joinpath(dir, file)
        Downloads.download("$TRAINING_URL/$(ex.folder)/$file", path)
        got = bytes2hex(open(sha256, path))
        got == checksum || error("checksum mismatch for $file (got $got, expected $checksum)")
    end
    par = joinpath(dir, "parameters.par")
    name == "tpv13" && delete_parameter!(par, "RFileName")
    return par
end
