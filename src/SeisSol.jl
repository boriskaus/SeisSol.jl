"""
    SeisSol

Small cross-platform wrapper around the [SeisSol](https://seissol.org) earthquake simulator
(ADER-DG, dynamic rupture and seismic wave propagation on unstructured tetrahedral meshes).

SeisSol is developed by the SeisSol group (LMU Munich, TU Munich, UC San Diego and many
contributors); this package only provides convenient access to the precompiled
[`SeisSol_jll`](https://github.com/boriskaus/SeisSol_jll.jl) binary. **Please cite the SeisSol
publications when you use it**, see [`citation`](@ref).

The binary is a generic build (no CPU-specific optimisations, convergence order 4, elastic
equations, double precision). It is meant for learning, testing and small/medium problems on
laptops and workstations. For production runs on HPC systems build an optimised SeisSol.
"""
module SeisSol

using Downloads, MPI, MPIPreferences, Printf, SHA, TOML
using SeisSol_jll

export run_seissol, run_proxy, download_example, examples, example_info,
       get_parameter, set_parameters!, delete_parameter!,
       read_energy, moment_magnitude, citation

include("run.jl")
include("parameters.jl")
include("examples.jl")
include("output.jl")
include("citation.jl")

end # module
