const REFERENCES = """
SeisSol is the work of many people; if you use this package, please cite SeisSol and the
papers that describe the methods you use (see also https://seissol.readthedocs.io and the
CITATION.cff in https://github.com/SeisSol/SeisSol):

 - Dumbser, M. and Käser, M. (2006). An arbitrary high-order discontinuous Galerkin method for
   elastic waves on unstructured meshes - II. The three-dimensional isotropic case.
   Geophysical Journal International 167(1), 319-336. doi:10.1111/j.1365-246X.2006.03120.x
 - de la Puente, J., Ampuero, J.-P. and Käser, M. (2009). Dynamic rupture modeling on
   unstructured meshes using a discontinuous Galerkin method.
   Journal of Geophysical Research 114, B10302. doi:10.1029/2008JB006271
 - Pelties, C., de la Puente, J., Ampuero, J.-P., Brietzke, G. B. and Käser, M. (2012).
   Three-dimensional dynamic rupture simulation with a high-order discontinuous Galerkin
   method on unstructured tetrahedral meshes.
   Journal of Geophysical Research 117, B02309. doi:10.1029/2011JB008857
 - Heinecke, A., Breuer, A., Rettenberger, S., Bader, M., Gabriel, A.-A., Pelties, C.,
   Bode, A., Barth, W., Liao, X.-K., Vaidyanathan, K., Smelyanskiy, M. and Dubey, P. (2014).
   Petascale high order dynamic rupture earthquake simulations on heterogeneous
   supercomputers. SC '14. doi:10.1109/SC.2014.6
 - Uphoff, C., Rettenberger, S., Bader, M., Madden, E. H., Ulrich, T., Wollherr, S. and
   Gabriel, A.-A. (2017). Extreme scale multi-physics simulations of the tsunamigenic 2004
   Sumatra megathrust earthquake. SC '17. doi:10.1145/3126908.3126948
 - Uphoff, C. and Bader, M. (2019). Yet another tensor toolbox for discontinuous Galerkin
   methods and other applications (Yateto). arXiv:1903.11521

SeisSol: https://seissol.org, https://github.com/SeisSol/SeisSol (BSD-3-Clause)
"""

"""
    citation()

Print how to credit SeisSol (and its authors) when using results obtained with this package.
"""
function citation(io::IO = stdout)
    print(io, REFERENCES)
    return nothing
end
