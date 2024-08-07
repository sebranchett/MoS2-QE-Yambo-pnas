# Testing use of Quantum Espresso and Yambo on DelftBlue
Testing use of software by reproducing the pressure=0 results for MoS2 from this article: https://www.pnas.org/doi/full/10.1073/pnas.2010110118.

This link explains everything you need to get started on DelftBlue: https://doc.dhpc.tudelft.nl/delftblue/crash-course/.

Unit cell and atom coordinate information taken from supporting information. [AMS ADF](https://www.scm.com/product/adf/) used to create the initial geometry input for Quantum Espresso.

Quantum Espresso input extended following this tutorial: https://flex.phys.tohoku.ac.jp/QE/workshop_QE_2016/DFT-hands-on-nguyen.pdf.

Pseudo-potentials downloaded from here: http://www.quantum-simulation.org/potentials/sg15_oncv/upf/.

Yambo input created following this tutorial: https://www.yambo-code.eu/wiki/index.php/LiF.

In addition, this tutorial was helpful for the Yambo GW  calculation and band structure plots: https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

In addition, these tutorials were helpful for the Yambo BSE calculation:
* https://www.yambo-code.eu/wiki/index.php/Static_screening
* https://www.yambo-code.eu/wiki/index.php/Bethe-Salpeter_kernel
* https://www.yambo-code.eu/wiki/index.php/How_to_choose_the_input_parameters
* https://www.yambo-code.eu/wiki/index.php/Bethe-Salpeter_on_top_of_quasiparticle_energies
* https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons

Information on running Yambo in parallel can be found here: https://www.yambo-code.eu/wiki/index.php/Using_Yambo_in_parallel and here: https://www.yambo-code.eu/wiki/index.php/Parallelization.

## Notes
The runs with 5-5-2 in the title are on a 5 x 5 x 2 k-point grid, instead of the 27 × 27 × 3 k-point grid used in the article. The 5-5-2 results are less accurate, but the calculations run much faster. This is useful for testing. The 10-10-3 files are for a 10 x 10 x 3 k-point grid, and were used to test scaling.

`convergence.sh` is an example of how to perform some standard GW convergence tests.

Because the 10-10-3 and 27-27-3 runs take so much time, it was convenient to split them into two parts: one for the DFT and GW  (named MoS2-x-x-x.sh) and the other for BSE (named bse-x-x-x.sh). The directories bse-x-x-x then contain the
- `SAVE` directory, containing the DFT results
- `output/gwppa.out` directory, containing the GW results

copied from the MoS2-x-x-x directory. The 5-5-2 run was not split in this way.

Approximate timings:
|             | 5x5x5 | 10x10x3 | 27x27x3|
|-------------|-------|---------|--------|
| cpu         | 24    | 24      | 24     |
| memory (GB) | 64    | 180     | 180    |
| DFT         | 2 (m) | 5 (m)   | 20 (m) |
| GW          | 20 (m) | 7 (h)  | 15 (d) |
| BSE         | 50 (m) | t.b.d. | t.b.d. |

### Results
![DFT and GW band results for 27x27x3 grid](./figures/bands-27-27-3.png)

Compare to Figure 2A for P = 0 in [Ataei et.al. PNAS 2021](https://www.pnas.org/doi/full/10.1073/pnas.2010110118).

![BSE exciton for 5x5x2 grid](./figures/exciton-5-5-2.png)

N.B. These results are for the 5 x 5 x 2 grid.
Compare to Figure 3A for P = 0 in [Ataei et.al. PNAS 2021](https://www.pnas.org/doi/full/10.1073/pnas.2010110118).

## Acknowledgments
Please acknowledge Quantum ESPRESSO by referencing the following 2 papers:
* QUANTUM ESPRESSO: a modular and open-source software project for quantum simulations of materials, P. Giannozzi, S. Baroni, N. Bonini, M. Calandra, R. Car, C. Cavazzoni, D. Ceresoli, G. L. Chiarotti, M. Cococcioni, I. Dabo, A. Dal Corso, S. Fabris, G. Fratesi, S. de Gironcoli, R. Gebauer, U. Gerstmann, C. Gougoussis, A. Kokalj, M. Lazzeri, L. Martin-Samos, N. Marzari, F. Mauri, R. Mazzarello, S. Paolini, A. Pasquarello, L. Paulatto, C. Sbraccia, S. Scandolo, G. Sclauzero, A. P. Seitsonen, A. Smogunov, P. Umari, R. M. Wentzcovitch, J.Phys.: Condens.Matter 21, 395502 (2009)
* Advanced capabilities for materials modelling with Quantum ESPRESSO, P. Giannozzi, O. Andreussi, T. Brumme, O. Bunau, M. Buongiorno Nardelli, M. Calandra, R. Car, C. Cavazzoni, D. Ceresoli, M. Cococcioni, N. Colonna, I. Carnimeo, A. Dal Corso, S. de Gironcoli, P. Delugas, R. A. DiStasio Jr, A. Ferretti, A. Floris, G. Fratesi, G. Fugallo, R. Gebauer, U. Gerstmann, F. Giustino, T. Gorni, J Jia, M. Kawamura, H.-Y. Ko, A. Kokalj, E. Küçükbenli, M .Lazzeri, M. Marsili, N. Marzari, F. Mauri, N. L. Nguyen, H.-V. Nguyen, A. Otero-de-la-Roza, L. Paulatto, S. Poncé, D. Rocca, R. Sabatini, B. Santra, M. Schlipf, A. P. Seitsonen, A. Smogunov, I. Timrov, T. Thonhauser, P. Umari, N. Vast, X. Wu, S. Baroni, J.Phys.: Condens.Matter 29, 465901 (2017)

Please acknowledge YAMBO by referencing the following 2 papers:
* Many-body perturbation theory calculations using the yambo code,
D. Sangalli, A. Ferretti, H. Miranda, C. Attaccalite, I. Marri, E. Cannuccia, P. Melo,
M Marsili, F Paleari, A Marrazzo, G Prandini, P Bonfà, M O Atambo, F Affinito,
M Palummo, A Molina-Sánchez, C Hogan, M Grüning, D Varsano and A Marini.
J. Phys.: Condens. Matter 31, 325902 (2019).
* Yambo: An ab initio tool for excited state calculations,
A. Marini, C. Hogan, M. Grüning, D. Varsano
Computer Physics Communications 180, 1392 (2009).

Please acknowledge DelftBlue by [adding a citation to Bibliography](https://doc.dhpc.tudelft.nl/delftblue/Citing-DHPC) or adding the text:
> "The authors acknowledge the use of computational resources of DelftBlue supercomputer, provided by Delft High Performance Computing Centre (https://www.tudelft.nl/dhpc)."
