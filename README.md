# Quantum Espresso and Yambo on DelftBlue
This repository contains a working example of how to perform DFT, GW, and BSE calculations using [Quantum Espresso](https://www.quantum-espresso.org/) and [Yambo](https://www.yambo-code.eu/) on the [DelftBlue supercomputer](https://doc.dhpc.tudelft.nl/delftblue/).

This working example is inspired by the pressure=0 results for MoS2 from this article: https://www.pnas.org/doi/full/10.1073/pnas.2010110118.

For useful resources and tutorials, [see here](./resources.md).

## Main scripts

There are 4 main scripts in this repository:
- 01_scf.sh - run a DFT calculation using Quantum Espresso. This script requires:
  - scf.in - input file for the self-consistent field calculation. For this example unit cell and atom coordinate information were taken from the [PNAS article](https://www.pnas.org/doi/full/10.1073/pnas.2010110118) supporting information. [AMS ADF](https://www.scm.com/product/adf/) was used to create the initial geometry input for Quantum Espresso
  - pseudopotentials for the atom types in the system. See [Useful Resources](./resources.md) for links to download pseudopotentials.
  
  Since the DFT calculation is relatively fast, no nscf calculation is needed after scf, in this case.

  This script also converts the output file to a format that Yambo can read

- 02_gw.sh - run a GW calculation using Yambo. This script requires:
  - the `SAVE` directory from the DFT calculation

- 03_sscreen.sh - run the static screening part of a BSE calculation using Yambo. This script requires:
  - `SAVE` directory
  - `output/gwppa` directory, containing the GW results

- 04_bse.sh - run the BSE equation calculation using Yambo. This script requires:
  - `SAVE` directory
  - `output/gwppa` directory
  - `output/BSE` directory, containing the static screening results

The Yambo scripts have the following general structure:
- set up
- define parameters specific to the calculation. There is some guidance on which parameters need to be converged
- create input files
- run the calculation
- plot results

## Bonus Scripts
- dft_gw_bse.sh - a convenience script that runs the DFT, GW, and BSE calculations in sequence, using the main scripts above
- 00_geom.sh - demonstrates how to optimise the geometry of the system using Quantum Espresso. This script requires:
  - geom.in - input file for the geometry optimisation calculation
  - pseudopotentials
- gw_convergence_eg.sh - a script that shows how a GW calculation can be run with different parameter values


## Acknowledgments
This repository has benefitted greatly from many enlightening discussions with [Laurens Siebbeles](https://www.tudelft.nl/tnw/over-faculteit/afdelingen/chemical-engineering/principal-investigators/laurens-siebbeles), [Engin Torun](https://orcid.org/0000-0001-9943-3460) and [Saskia Poort](https://www.linkedin.com/in/saskia-p-2a4a09355/).

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
