# Generates data/examples.toml from local clones of the SeisSol example repositories.
# Usage: julia tools/generate_examples_manifest.jl <path to SeisSol/Training> <path to SeisSol/Examples>
# The manifest pins every file (path, size, git blob SHA-1) at the commit of the clones, so that
# download_example can verify downloads without any network lookup.
using TOML

training, examples = ARGS

# name => (repo, folder, parfile, status, description)
# status: "runs" (checked with the bundled binary), "needs-asagi", "needs-mesh", "unverified"
const META = [
    ("tpv13", "Training", "tpv13", "parameters.par", "runs",
     "SCEC TPV13: spontaneous rupture on a normal fault with off-fault plasticity (coarse mesh, 37k tetrahedra)"),
    ("earthquake-tsunami", "Training", "earthquake-tsunami", "parameters_qwx.par", "runs",
     "Dynamic rupture of a subduction-type fault with the free-surface response (two meshes: 105k and 225k tetrahedra)"),
    ("cdb_tpv23", "Training", "cdb_tpv23", "parameters_qwx.par", "unverified",
     "SCEC TPV23 style rupture with a fault-zone (damage) material; a quick test with the bundled binary produced NaNs"),
    ("kaikoura", "Training", "kaikoura", "parametersLSW.par", "needs-asagi",
     "2016 Kaikoura earthquake (New Zealand), linear slip weakening (parametersLSW.par) and rate-and-state (parametersRS.par); 3D structure read with ASAGI"),
    ("sulawesi", "Training", "sulawesi", "parametersLSW.par", "needs-asagi",
     "2018 Palu (Sulawesi) earthquake with 3D velocity model read with ASAGI"),
    ("northridge", "Training", "northridge", "parameters.par", "needs-mesh",
     "1994 Northridge earthquake with a kinematic source (gmsh mesh must be converted with PUMGen, SRF source needs the NRF converter)"),
]
const EXAMPLES_DESC = Dict(
    "tpv5" => "SCEC TPV5: planar fault, heterogeneous initial stress (mesh must be generated)",
    "tpv6_7" => "SCEC TPV6/7: rupture with heterogeneous stress",
    "tpv12_13" => "SCEC TPV12/13: normal fault with plasticity",
    "tpv16" => "SCEC TPV16/17: random stress",
    "tpv24" => "SCEC TPV24: branching fault",
    "tpv29" => "SCEC TPV29/30: rough fault",
    "tpv33" => "SCEC TPV33: fault with a weak zone",
    "tpv34" => "SCEC TPV34: rupture in a 3D velocity model",
    "tpv36_37" => "SCEC TPV36/37: rupture in a 3D velocity model",
    "tpv101" => "SCEC TPV101: rate-and-state friction",
    "tpv104" => "SCEC TPV104: rate-and-state with fast velocity weakening",
    "tpv105" => "SCEC TPV105: rate-and-state with strong velocity weakening",
    "WP2_LOH1" => "LOH.1 wave propagation benchmark",
    "WP2_LOH3" => "LOH.3 wave propagation benchmark (viscoelastic)",
    "Northridge" => "Northridge earthquake",
    "Northridge_FL33" => "Northridge earthquake with friction law 33",
    "convergence_elastic" => "Plane-wave convergence test (elastic)",
    "convergence_acoustic_elastic" => "Plane-wave convergence test (acoustic-elastic)",
)

function git(dir, args...)
    readchomp(Cmd(`git -C $dir $args`))
end

function files_of(dir, folder)
    out = []
    for line in split(git(dir, "ls-tree", "-r", "-l", "HEAD", folder), '\n')
        isempty(line) && continue
        meta, path = split(line, '\t')
        _, _, sha, size = split(meta)
        push!(out, Dict("path" => String(path), "size" => parse(Int, size), "sha1" => String(sha)))
    end
    return out
end

function parfile_of(files, folder)
    pars = sort([basename(f["path"]) for f in files if endswith(f["path"], ".par")])
    return isempty(pars) ? "" : first(pars)
end

manifest = Dict{String,Any}("example" => Any[])
for (name, repo, folder, par, status, desc) in META
    push!(manifest["example"], Dict("name" => name, "repo" => "SeisSol/Training",
          "commit" => git(training, "rev-parse", "HEAD"), "folder" => folder, "parfile" => par,
          "status" => status, "description" => desc, "files" => files_of(training, folder)))
end
for folder in sort(readdir(examples))
    startswith(folder, ".") && continue
    isdir(joinpath(examples, folder)) || continue
    files = files_of(examples, folder)
    push!(manifest["example"], Dict("name" => "examples/" * folder, "repo" => "SeisSol/Examples",
          "commit" => git(examples, "rev-parse", "HEAD"), "folder" => folder,
          "parfile" => parfile_of(files, folder), "status" => "needs-mesh",
          "description" => get(EXAMPLES_DESC, folder, folder) * ". Only the setup files are provided: generate the mesh with gmsh and PUMGen (see generating_the_mesh.sh)",
          "files" => files))
end
open(joinpath(@__DIR__, "..", "data", "examples.toml"), "w") do io
    TOML.print(io, manifest)
end
println("wrote ", length(manifest["example"]), " examples")
