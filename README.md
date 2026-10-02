# SeisSol.jl

[![CI](https://github.com/boriskaus/SeisSol.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/boriskaus/SeisSol.jl/actions/workflows/CI.yml)

A small Julia wrapper that makes it easy to run [**SeisSol**](https://seissol.org) examples on
**Linux and macOS** (Windows: see the limitations), without compiling anything and without Docker or a cluster.
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

- **Windows:** the Windows build of SeisSol currently **crashes at runtime**, so `SeisSol.jl` refuses to run it and tells you to use **WSL2** instead. In WSL2 (Windows Subsystem for Linux, `wsl --install`, then e.g. Ubuntu) install Julia and SeisSol.jl exactly as described below; the Linux binary is used and everything works, including `export_prefix` and the terminal usage. The rest of the wrapper (parameter files, example download, output reading) also works natively on Windows. `SEISSOL_ALLOW_WINDOWS=true` lifts the block.

The binary behind this package is a **generic, portable build**, chosen so that it runs everywhere:

- the same settings as the SeisSol team's Docker image: AVX2/FMA kernels (`hsw`) generated with
  libxsmm and PSpaMM on x86_64, NEON kernels on aarch64 (PSpaMM on Linux, generic kernels on macOS),
  so that it runs on any CPU of the last decade but is **not tuned to your CPU like a build on an HPC system**;
- fixed configuration: convergence order 4, elastic equations, double precision (no viscoelastic,
  poroelastic or anisotropic variants), 32-bit METIS indices, no GPU support;
- ASAGI and NetCDF are enabled (e.g. Kaikoura, Sulawesi).

It is meant for learning, teaching, testing setups and small/medium problems on a laptop or
workstation. For production runs, build SeisSol from source on your cluster as described in the
[SeisSol documentation](https://seissol.readthedocs.io).
SeisSol also needs a **mesh** in its PUML (`.puml.h5`) format, generated with
[PUMGen](https://github.com/SeisSol/PUMGen) and gmsh; this package does not generate meshes.

## Installation

Julia ≥ 1.11 is required. The binary packages are not yet in the General registry, so they are
installed from GitHub. Start Julia **without** `--project` (so that the default environment is
active; the prompt of the package manager, `]`, shows `(@v1.12) pkg>`) and run:

```julia
using Pkg
Pkg.add(url="https://github.com/boriskaus/ASAGI_jll.jl")
Pkg.add(url="https://github.com/boriskaus/easi_jll.jl")
Pkg.add(url="https://github.com/boriskaus/SeisSol_jll.jl")
Pkg.add(url="https://github.com/boriskaus/SeisSol.jl")
```

(Add the four packages in this order, or all in one `Pkg.add([PackageSpec(url=...), ...])`
call; `SeisSol_jll` cannot be installed on its own because its dependencies are not registered.)

**Where is it installed?** Packages live in an *environment*. The commands above install into
the default environment, which is what a plain `julia` and `julia -e '...'` use. If you install
into a project instead (e.g. you started `julia --project=.` in a course folder, or ran
`] activate .` first), then `using SeisSol` only works in that project, and the terminal commands
below must be started with the same project, e.g. `julia --project=/path/to/folder -e '...'`.
`julia -e 'using Pkg; Pkg.status()'` shows what the default environment contains, and
`julia --project=. -e 'using Pkg; Pkg.status()'` what the project in the current folder contains.
A clean way to keep SeisSol separate is a *shared* environment:

```julia
using Pkg
Pkg.activate("seissol"; shared=true)      # ~/.julia/environments/seissol
# ... the four Pkg.add lines from above ...
```

and then start Julia with `julia --project=@seissol` (REPL) or `julia --project=@seissol -e '...'`.

The binary is built for MPICH (Linux, macOS), which is the default of MPI.jl. If you changed `MPIPreferences` to another MPI, switch back with
`using MPIPreferences; MPIPreferences.use_jll_binary("MPICH_jll")` and restart Julia.

## Usage

```julia
using SeisSol

run_proxy()                        # kernel benchmark without input files: checks the installation

par = download_example("tpv13")    # SCEC TPV13 benchmark from the SeisSol training material -> creates ./tpv13
set_parameters!(par; EndTime = 2.0)
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
| `seissol_executable()`, `export_prefix(dir)` | path of the executable; standalone installation for use without Julia |
| `examples()`, `example_info(name)`, `download_example(name)` | list, describe and download the example setups of the SeisSol training material and examples repository (checksum-verified) |
| `get_parameter`, `set_parameters!`, `delete_parameter!` | edit SeisSol parameter files |
| `read_energy`, `moment_magnitude` | read `*-energy.csv`, compute Mw |
| `citation()` | print the references to cite |

`examples()` lists 24 setups: `"tpv13"`, `"earthquake-tsunami"`, `"kaikoura"` and `"sulawesi"` are known to run with the bundled binary; the `"examples/..."` entries (SCEC benchmarks) only contain the setup files, their meshes must be generated with gmsh and PUMGen. `example_info(name)` shows the status.

Visualise the XDMF/HDF5 output (fault and free-surface fields) with [ParaView](https://www.paraview.org).

## Running SeisSol directly from the terminal (without Julia)

Julia is only needed once, to download SeisSol. After that the solver is an ordinary
executable that you can use from a shell, a script or a job system.

### Quick start: copy and paste

Works in a Linux or macOS terminal (on Windows, use a WSL2 Ubuntu terminal, see above).

**A. Install (once, about 2 minutes).** You need Julia ≥ 1.11; if `julia --version` does not work,
install it first (see [julialang.org/install](https://julialang.org/install)) and open a new terminal:

```sh
curl -fsSL https://install.julialang.org | sh      # only if you do not have Julia yet
```

Then paste the following. It installs SeisSol.jl and the SeisSol binaries into a separate
Julia environment called `@seissol` (this does not interfere with other Julia work) and creates
the standalone folder `~/seissol`:

```sh
julia --project=@seissol -e '
using Pkg
Pkg.add([PackageSpec(url="https://github.com/boriskaus/ASAGI_jll.jl"),
         PackageSpec(url="https://github.com/boriskaus/easi_jll.jl"),
         PackageSpec(url="https://github.com/boriskaus/SeisSol_jll.jl"),
         PackageSpec(url="https://github.com/boriskaus/SeisSol.jl")])
using SeisSol
export_prefix(expanduser("~/seissol"))'
```

The last lines of the output tell you where everything is. To use `seissol` and `mpiexec`
without typing the path, add the folder to your `PATH`
(`echo 'export PATH=$HOME/seissol/bin:$PATH' >> ~/.bashrc`, on macOS `~/.zshrc`; open a new terminal).
To update later: `rm -rf ~/seissol`, run the same block again.

**B. Run an example** (the SCEC TPV13 earthquake-rupture benchmark, a few seconds of simulated time on
4 MPI processes, about 30 s on a laptop):

```sh
mkdir -p ~/seissol_examples && cd ~/seissol_examples
julia --project=@seissol -e 'using SeisSol; download_example("tpv13")'      # creates the folder tpv13
cd tpv13
sed -i.bak 's/^EndTime.*/EndTime = 2.0/' parameters.par                     # shorten the run (original: 8 s)
export SEISSOL_COMMTHREAD=0 OMP_NUM_THREADS=1
~/seissol/bin/mpiexec -n 4 ~/seissol/bin/seissol parameters.par
```

The results are in `tpv13/outputs/`: open `tpv13-fault.xdmf` (slip and tractions on the fault),
`tpv13.xdmf` (3D wavefield) and `tpv13-free-surface-*.vtkhdf` (ground surface) in
[ParaView](https://www.paraview.org); `tpv13-energy.csv` contains the energy and seismic moment
as a function of time. Other examples: `julia --project=@seissol -e 'using SeisSol; println(examples())'`.

### The same, step by step

**1. Install SeisSol into a folder** (one time; this is what the quick start does. Use the same
environment in which you installed SeisSol.jl: plain `julia` for the default environment, otherwise
`julia --project=<project or @seissol> ...`, see [Installation](#installation)):

```sh
julia -e 'using SeisSol; export_prefix(expanduser("~/seissol"))'
```

`export_prefix` prints where everything is and how to run it. It creates a self-contained folder (the files are hard links into the Julia artifact
folder where possible, so it takes little extra disk space):

```
~/seissol/bin/seissol          the solver
~/seissol/bin/seissol_proxy    kernel benchmark that needs no input files
~/seissol/bin/mpiexec          the MPI launcher that matches the solver (MPICH)
~/seissol/lib/                 all shared libraries; the executables find them by themselves,
                               no LD_LIBRARY_PATH / DYLD_LIBRARY_PATH is needed
```

(`julia -e 'using SeisSol; println(seissol_executable())'` prints the path of the executable
inside the Julia artifact, but that one needs the libraries of its dependencies and is therefore
best used through `export_prefix`.) Optionally add the folder to your path:
`export PATH=$HOME/seissol/bin:$PATH`.

**2. Check the installation** with the built-in benchmark:

```sh
~/seissol/bin/seissol_proxy 10000 10 all     # <cells> <time steps> <kernel>
```

**3. Get an example** (a mesh `*.puml.h5`, material/fault `*.yaml` files and a parameter file
`*.par`). With Julia (this also fixes the parameter file, see below):

```sh
julia -e 'using SeisSol; download_example("tpv13")'     # creates the folder ./tpv13
cd tpv13
```

or with git and no Julia at all (all examples of the SeisSol training material):

```sh
git clone --depth 1 https://github.com/SeisSol/Training.git
cd Training/tpv13
sed -i.bak '/RFileName/d' parameters.par     # this parameter file names a receiver file that is not in the repository
```

Then, for a quick test, shorten the simulation (the original runs 8 s):

```sh
sed -i.bak 's/^EndTime.*/EndTime = 2.0/' parameters.par
```

**4. Run it.** SeisSol reads the parameter file given as its only argument; relative file names
inside it are relative to the *current directory*, so start it from the example folder:

```sh
export SEISSOL_COMMTHREAD=0      # no dedicated MPI thread (see below)
export OMP_NUM_THREADS=1         # OpenMP threads per MPI rank
~/seissol/bin/mpiexec -n 4 ~/seissol/bin/seissol parameters.par      # 4 MPI ranks
```

A single rank also works without `mpiexec`: `~/seissol/bin/seissol parameters.par`. Results appear
where `OutputFile` points to (`outputs/tpv13-*`): XDMF/HDF5 files for
[ParaView](https://www.paraview.org) and the `*-energy.csv` file with the energy and seismic moment.
SeisSol creates the output folder (`outputs/`) itself, but only its last component: for an `OutputFile` like `results/run1/tpv13` the folder `results` must already exist. Other parameters you may want to change are `OutputFile`, `EnergyOutputInterval` and the output masks.

**Settings that matter**

| setting | meaning |
|---|---|
| `mpiexec -n N` | number of MPI ranks (processes). Use about one per physical core. |
| `OMP_NUM_THREADS` | OpenMP threads per rank. With several ranks use `1`; with a single rank you can use all cores. Total cores used = ranks × threads. |
| `SEISSOL_COMMTHREAD=0` | SeisSol normally reserves one core per rank for MPI communication and stops with *"There are no free CPUs left"* if you use all cores. `0` switches this off (polling instead); the right choice on laptops and workstations. |
| `OMP_PLACES=cores`, `OMP_PROC_BIND=close` | optional: pin the threads to cores (Linux). |
| `ulimit -s unlimited` | optional: SeisSol warns when the stack size limit is small; larger problems may need it. |

On macOS, if the system refuses to start a downloaded executable, remove the quarantine
attribute: `xattr -r -d com.apple.quarantine ~/seissol`.

The MPI that is shipped is MPICH, so use the `mpiexec` from the same folder; do not mix it with
an `mpiexec` of another MPI installation. To run on several nodes, use the launcher options of
your cluster together with a SeisSol that is built for that machine (this generic build is not
meant for HPC systems).

### Which MPI is used, and how to change it

The solver is linked against **MPICH** (currently 5.0.2, the `MPICH_jll` package). The
exported folder contains this MPICH: the launcher `bin/mpiexec` and the library `lib/libmpi.so.12`
(`libmpi.12.dylib` on macOS). Your system's MPI (OpenMPI, Intel MPI, a cluster MPI, ...) is **not**
used unless you ask for it. You can see what is used with:

```sh
~/seissol/bin/mpiexec --version                  # launcher
ldd ~/seissol/bin/seissol | grep mpi             # library (macOS: otool -L)
```

Always start the solver with the `mpiexec` of the *same* MPI it loads at run time; an `mpiexec`
of another MPI family (e.g. OpenMPI's, which also uses a different library `libmpi.so.40`)
cannot start it.

**Using another MPI.** MPICH has a stable binary interface (ABI), so the solver also runs on top
of any other MPI that implements the *MPICH ABI* and provides `libmpi.so.12`: a system MPICH,
MVAPICH, Intel MPI, Cray MPICH, ... Point the dynamic loader to its library directory and use its launcher:

```sh
export MPI=/opt/mpich                             # the other MPI installation
export LD_LIBRARY_PATH=$MPI/lib:$LD_LIBRARY_PATH  # picked up before the libraries of ~/seissol/lib
$MPI/bin/mpiexec -n 4 ~/seissol/bin/seissol parameters.par
ldd ~/seissol/bin/seissol | grep libmpi           # check: should now point into $MPI/lib
```

(On macOS use `DYLD_LIBRARY_PATH`, or delete `lib/libmpi*.dylib` from the folder.) This was
tested on Linux with the shipped MPICH 5.0.2 against a system MPICH 4.3.0: same results. It was
not tested with Intel MPI, MVAPICH, Cray MPICH or on macOS. MPI libraries with another ABI
(OpenMPI) cannot be used this way; for those, or when you want full speed on a cluster
(network-specific MPI, tuned kernels), build SeisSol from source against that MPI as described in
the [SeisSol documentation](https://seissol.readthedocs.io).

Inside Julia, `run_seissol` uses the MPI that [MPI.jl](https://github.com/JuliaParallel/MPI.jl)
is configured for (MPICH by default). `SeisSol_jll` only exists for MPICH, so switching MPI.jl to
another MPI with `MPIPreferences` makes `SeisSol_jll` unavailable; use the terminal procedure
above for other MPIs.

Once `SeisSol_jll` is registered in the General registry, [JLLPrefixes.jl](https://github.com/JuliaPackaging/JLLPrefixes.jl)
creates such a folder for any JLL (`collect_artifact_paths(["SeisSol_jll"])` followed by
`deploy_artifact_paths("~/seissol", paths)`).

## Tests and CI

The test suite mirrors the checks of SeisSol's own CI (the solver must refuse to run without
input, every kernel of the proxy mini-app must run) and adds parameter-file and output tests
and a real dynamic-rupture run (TPV13, 1 and 2 MPI ranks, compared with a reference moment).
GitHub Actions runs it on Linux, Intel and Apple-silicon macOS and Windows (where the solver tests are skipped).
Locally: `julia --project=. test/runtests.jl`. (`Test` is declared as the test dependency, but `Pkg.test()` itself currently fails with Julia 1.12's Pkg for projects that have URL `[sources]` for unregistered packages ("expected package `Test` to be registered"); it will work once the JLLs are registered in General.)

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
