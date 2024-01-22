# Testing Quantum Espresso and Yambo installation on DelftBlue
Testing software installation by reproducing the pressure=0 results for MoS2 from this article: https://www.pnas.org/doi/full/10.1073/pnas.2010110118.

Unit cell and atom coordinate information taken from supporting information.

Quantum Espresso input created following this tutorial: https://flex.phys.tohoku.ac.jp/QE/workshop_QE_2016/DFT-hands-on-nguyen.pdf.

Pseudo-potentials downloaded from here: http://www.quantum-simulation.org/potentials/sg15_oncv/upf/.

Yambo input created following this tutorial: https://www.yambo-code.eu/wiki/index.php/LiF.

Yambo band structure plots created following step 3 of this tutorial: https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

The runs with 5-5-2 in the title are on a 5 x 5 x 2 k-point grid, instead of the 27 × 27 × 3 k-point grid used in the article. The 5-5-2 results are less accurate, but the calculations run much faster. This is useful for testing.
