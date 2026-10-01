# SeisSol.jl

[![CI](https://github.com/boriskaus/SeisSol.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/boriskaus/SeisSol.jl/actions/workflows/CI.yml)

A small Julia wrapper that makes it easy to run [**SeisSol**](https://seissol.org) examples on
**Linux, macOS and Windows**, without compiling anything and without Docker or a cluster.
It downloads a precompiled SeisSol binary ([`SeisSol_jll`](https://github.com/boriskaus/SeisSol_jll.jl)),
starts it with MPI + OpenMP, and offers a few helpers to edit parameter files and read the output.

> **This package is not part of, nor endorsed by, the SeisSol project.**
> All the science and software engineering is the work of the SeisSol group; see
> [Credits](#credits-and-how-to-cite). If you publish results obtained with this package,
> please cite SeisSol and the papers below.

## What is SeisSol?

SeisSol is an open-source package for simulating 3D seismic, acoustic and gravity waves and
**earthquake rupture dynamics**. It uses an arbitrary high-order derivative discontinuous
Galerkin (ADER-DG) method on unstructured tetrahedral meshes, supports elastic, anisotropic,
viscoelastic and poroelastic media, several friction laws (linear slip weakening,
rate-and-state, ...), off-fault plasticity and thermal pressurisation, and is optimised for
large supercomputers (MPI + OpenMP, GPUs).

## Limitations — please read

The binary behind this package is a **generic, portable build**, chosen so that it runs everywhere:

- no CPU-specific optimisation (SeisSol's `noarch` target) and no libxsmm/PSpaMM kernels, so it
  is considerably **slower than an optimised SeisSol** on HPC systems;
- fixed configuration: convergence order 4, elastic equations, double precision;
- no NetCDF, ASAGI or GPU support.

It is meant for learning, teaching, testing setups and small/medium problems on a laptop or
workstation. For production runs, build SeisSol from source on your cluster as described in the
[SeisSol documentation](https://seissol.readthedocs.io).
SeisSol also needs a **mesh** in its PUML (`.puml.h5`) format, generated with
[PUMGen](https://github.com/SeisSol/PUMGen) and gmsh; this package does not generate meshes.

## Installation

Julia ≥ 1.11 is required. The binary packages are not yet in the General registry, so they are
installed from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/boriskaus/easi_jll.jl")
Pkg.add(url="https://github.com/boriskaus/SeisSol_jll.jl")
Pkg.add(url="https://github.com/boriskaus/SeisSol.jl")
```

The binary is built for MPICH (Linux, macOS) and Microsoft MPI (Windows), which are the
defaults of MPI.jl. If you changed `MPIPreferences` to another MPI, switch back with
`using MPIPreferences; MPIPreferences.use_jll_binary("MPICH_jll")` and restart Julia.

## Usage

```julia
using SeisSol

run_proxy()                        # kernel benchmark without input files: checks the installation

par = download_example("tpv13")    # SCEC TPV13 rupture benchmark from the SeisSol training material
set_parameters!(par; EndTime = 2.0)
mkpath(joinpath(dirname(par), "outputs"))
run_seissol(par; nprocs = 4)             # 4 MPI ranks, 1 OpenMP thread each (default)

energy = read_energy(joinpath(dirname(par), "outputs", "tpv13-energy.csv"))
M0 = energy["seismic_moment"]      # (time = ..., value = ...)
moment_magnitude(M0.value[end])    # Mw
```

Main functions (see their docstrings):

| function | purpose |
|---|---|
| `run_seissol(parfile; nprocs, nthreads, ...)` | run SeisSol with MPI (+ OpenMP; 1 thread per rank by default when `nprocs > 1`) |
| `run_proxy(; kernel, cells, timesteps)` | SeisSol's kernel benchmark (needs no input) |
| `examples()`, `example_info(name)`, `download_example(name)` | list, describe and download the example setups of the SeisSol training material and examples repository (checksum-verified) |
| `get_parameter`, `set_parameters!`, `delete_parameter!` | edit SeisSol parameter files |
| `read_energy`, `moment_magnitude` | read `*-energy.csv`, compute Mw |
| `citation()` | print the references to cite |

`examples()` lists 24 setups: `"tpv13"` and `"earthquake-tsunami"` are known to run with the bundled binary; `"kaikoura"`, `"sulawesi"` need a binary with ASAGI; the `"examples/..."` entries (SCEC benchmarks) only contain the setup files, their meshes must be generated with gmsh and PUMGen. `example_info(name)` shows the status.

Visualise the XDMF/HDF5 output (fault and free-surface fields) with [ParaView](https://www.paraview.org).

## Tests and CI

The test suite mirrors the checks of SeisSol's own CI (the solver must refuse to run without
input, every kernel of the proxy mini-app must run) and adds parameter-file and output tests
and a real dynamic-rupture run (TPV13, 1 and 2 MPI ranks, compared with a reference moment).
GitHub Actions runs it on Linux, Intel and Apple-silicon macOS and Windows.
Locally: `julia --project=. test/runtests.jl` (`Pkg.test()` works once the JLLs are registered).

## Credits and how to cite

**SeisSol** is developed by the SeisSol group at LMU Munich, TU Munich and UC San Diego, led by
[Alice-Agnes Gabriel](https://orcid.org/0000-0003-0112-8412) and
[Michael Bader](https://orcid.org/0009-0000-4334-1938), together with many contributors
(authors in the [SeisSol `CITATION.cff`](https://github.com/SeisSol/SeisSol/blob/master/CITATION.cff)).
The SeisSol team acknowledges Martin Käser and Michael Dumbser, originators of the first
version of SeisSol, and early contributors Cristobal Castro, Verena Hermann and Josep de la
Puente. SeisSol is released under the BSD-3-Clause license:
<https://github.com/SeisSol/SeisSol> · <https://seissol.org> · <https://seissol.readthedocs.io>.
The example setups are taken from the
[SeisSol training material](https://github.com/SeisSol/Training) and the
[SeisSol examples](https://github.com/SeisSol/Examples) (both BSD-3-Clause); TPV13 and the other `tpv*` cases implement the
SCEC/USGS dynamic rupture benchmark (Harris et al., 2009, *Seismol. Res. Lett.* 80(1),
doi:[10.1785/gssrl.80.1.119](https://doi.org/10.1785/gssrl.80.1.119)).

Please cite SeisSol and the papers relevant for what you do, for example:

- Dumbser, M. & Käser, M. (2006). An arbitrary high-order discontinuous Galerkin method for elastic waves on unstructured meshes – II. The three-dimensional isotropic case. *Geophys. J. Int.* 167(1), 319–336. doi:[10.1111/j.1365-246X.2006.03120.x](https://doi.org/10.1111/j.1365-246X.2006.03120.x)
- de la Puente, J., Ampuero, J.-P. & Käser, M. (2009). Dynamic rupture modeling on unstructured meshes using a discontinuous Galerkin method. *J. Geophys. Res.* 114, B10302. doi:[10.1029/2008JB006271](https://doi.org/10.1029/2008JB006271)
- Pelties, C., de la Puente, J., Ampuero, J.-P., Brietzke, G. B. & Käser, M. (2012). Three-dimensional dynamic rupture simulation with a high-order discontinuous Galerkin method on unstructured tetrahedral meshes. *J. Geophys. Res.* 117, B02309. doi:[10.1029/2011JB008857](https://doi.org/10.1029/2011JB008857)
- Heinecke, A. et al. (2014). Petascale high order dynamic rupture earthquake simulations on heterogeneous supercomputers. *SC '14*. doi:[10.1109/SC.2014.6](https://doi.org/10.1109/SC.2014.6)
- Uphoff, C., Rettenberger, S., Bader, M., Madden, E. H., Ulrich, T., Wollherr, S. & Gabriel, A.-A. (2017). Extreme scale multi-physics simulations of the tsunamigenic 2004 Sumatra megathrust earthquake. *SC '17*. doi:[10.1145/3126908.3126948](https://doi.org/10.1145/3126908.3126948)
- Uphoff, C. & Bader, M. (2019). Yet another tensor toolbox for discontinuous Galerkin methods and other applications (Yateto). arXiv:[1903.11521](https://arxiv.org/abs/1903.11521)

`citation()` prints the same list. For the complete and current list of publications see the
[SeisSol documentation](https://seissol.readthedocs.io) and `CITATION.cff` in the SeisSol repository.

This wrapper is released under the MIT license (see `LICENSE`); the SeisSol solver, PUML,
easi, Yateto and the other components inside the binary keep their own licenses
(mostly BSD-3-Clause; the license files are shipped inside the `SeisSol_jll` and `easi_jll` packages).
