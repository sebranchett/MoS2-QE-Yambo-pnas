#!/bin/bash

#SBATCH --job-name=MoS2-10-10-3
#SBATCH --partition=compute
#SBATCH --account=research-as-cheme
#SBATCH --time=72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB

# find your account with:
# sacctmgr list -sp user $USER

module load 2023r1
module load openmpi
module load openblas
module load fftw
export CPATH=$FFTW_ROOT/include:$CPATH
module load hdf5
module load netcdf-c
module load netcdf-fortran
module load gnuplot
# See QE Prerequisites
export LC_ALL=C

QEDIR=/scratch/sbranchett/yambo-evaluation/q-e-qe-7.2
YAMBODIR=/scratch/sbranchett/parallel-yambo/yambo-5.2.0
export PATH=$PATH:$QEDIR/bin:$YAMBODIR/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$YAMBODIR/lib

# Reproducing this paper:
# https://www.pnas.org/doi/full/10.1073/pnas.2010110118
# Evidence of ideal excitonic insulator in bulk MoS2 under pressure
# Input file generated using AMS for Quantum Espresso
# Pseudopotentials from https://www.physics.rutgers.edu/gbrv/

WORKDIR=${PWD}/MoS2-10-10-3
cd "$WORKDIR"

# DFT with Quantum Espresso
mkdir -p output
# scf
srun pw.x < mos2-scf.in > output/mos2-scf.out
# bands - for the graph
# srun pw.x < mos2-bands.in > output/mos2-bands.out
# nscf
srun pw.x < mos2-nscf.in > output/mos2-nscf.out

# Convert Quantum Espresso output to Yambo input
cd MoS2.save
srun p2y > ../output/mos2-p2y.out
cd ..

# Copy the converted Qantum Espresso DFT data
srun -n1 cp -rf MoS2.save/SAVE SAVE

# Create initialisation file
rm -f init.in
srun -n1 yambo -i -V RL -F init.in
# and run it:
srun yambo -F init.in -J output/init.out
# report at output/r-init.out_setup

# Create GW input file with:
rm -f gwppa.in
srun -n1 yambo -p p -F gwppa.in
# Make changes to GW input file
# 1) Change parameters
sed -i 's/EXXRLvcs.*/EXXRLvcs=  68              Ry    # [XX] Exchange    RL components/' gwppa.in
sed -i 's/VXCRLvcs.*/VXCRLvcs=  15              Ry    # [XC] XCpotential RL components/' gwppa.in
sed -i 's/GTermKind.*/GTermKind= "BG"                  # [GW] GW terminator ("none","BG" Bruneval-Gonze,"BRS" Berger-Reining-Sottile)/' gwppa.in
sed -i "s|NGsBlkXp.*|NGsBlkXp=   5              Ry    # [Xp] Response block size|" gwppa.in
sed -i "/GbndRnge/i UseEbands" gwppa.in

# 2) Add parallel directives
cat >> gwppa.in << EOF

# Dipoles
DIP_ROLEs= "k c v"                             # CPUs roles (k,c,v)
DIP_CPU= "$SLURM_NTASKS_PER_NODE $SLURM_NTASKS_PER_NODE $SLURM_NTASKS_PER_NODE"  # CPUs for each role
DIP_Threads= 0
# Response functions
X_all_q_ROLEs= "q g k c v"                     # CPUs roles (q,g,k,c,v)
X_all_q_CPU= "2 2 $SLURM_NTASKS_PER_NODE $SLURM_NTASKS_PER_NODE $SLURM_NTASKS_PER_NODE"  # CPUs for each role
X_Threads= 0
# Self-energy
SE_ROLEs= "q qp b"                             # CPUs roles (q,qp,b)
SE_CPU= " 2 2 $SLURM_NTASKS_PER_NODE"          # CPUs for each role
SE_Threads= 0

EOF

# G0W0
srun yambo -F gwppa.in -J output/gwppa.out
# report at output/r-gwppa.out_HF_and_locXC_gw0_em1d_ppa_el_el_corr

# Following step 3 of this tutorial to draw band structures
# https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

# clean up to be sure
rm -f ypp_bands.in
# create ypp input
srun -n1 ypp -s b -F ypp_bands.in
# edit number of bands
sed -i '/1 \| 302/d' ypp_bands.in
sed -i '/BANDS_bands/a \  50 | 59 |                      # Number of bands' ypp_bands.in
# add path in K-space
sed -i '/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |' ypp_bands.in
# edit number of steps along path
sed -i "s/10/50/" ypp_bands.in
sed -i 's/INTERP_mode= "NN"   /INTERP_mode= "BOLTZ"/' ypp_bands.in

# ypp to interpolate DFT results
srun ypp -F ypp_bands.in
# report at r_electrons_bnds
mv -f o.bands_interpolated o.bands_interpolated_dft

# create ypp input for GW bands
cat <<\EOF >> ypp_bands.in
GfnQPdb= "E < ./output/gwppa.out/ndb.QP"
EOF

# ypp to interpolate GW results
srun ypp -F ypp_bands.in
# report at r_electrons_bnds_01
mv -f o.bands_interpolated o.bands_interpolated_gw

# DFT and bands
gnuplot <<\EOF
set terminal png size 500,400
set output 'interpolated-10-10-3.png'
set title 'DFT and GW bands along Gamma-Kappa path'
plot 'o.bands_interpolated_dft' using 0:2 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:3 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:5 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:7 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:9 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:11 w l linetype 7, \
     'o.bands_interpolated_gw' using 0:2 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:3 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:5 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:7 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:9 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:11 w l linetype -1
EOF

# BSE

# Static screening
# Create input
srun -n1 yambo -X s -F statscreen.in
sed -i 's/NGsBlkXs.*/NGsBlkXs= 5                Ry    # [Xs] Response block size/' statscreen.in
# set directions for Electric Field - LongDrXs
sed -i 's/0.000000 |/1.000000 |/g' statscreen.in
# Run static screening
srun yambo -F statscreen.in -J BSE
# report at r-BSE_screen_dipoles_em1s
# Find the number of q-points
qpoints=$(grep 'IBZ Q-points' r-BSE_screen_dipoles_em1s | awk '{print $4}')

# Bethe-Salpeter
# Create input
yambo -o b -k sex -y d -F bse.in -J BSE
sed -i 's/BSENGexx.*/BSENGexx=  68              Ry    # [BSK] Exchange components/' bse.in
sed -i 's/BSENGBlk.*/BSENGBlk=   5              Ry    # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/' bse.in
# The article states three valence and five conduction bands
# Band 52 is the highest occupied state, and states are degenerate
sed -i 's/.*# \[BSK\] Bands range/  47 |  62 |                     # [BSK] Bands range/' bse.in
sed -i "s/.*# \[BSK\] Transferred momenta range/ 1 | ${qpoints} |                             # [BSK] Transferred momenta range/" bse.in
# write exciton composition, in terms of electron-hole pairs, to disk
sed -i 's/#WRbsWF/WRbsWF/' bse.in
# Read the QP corrections from previous GW calculation
sed -i '/WRbsWF/a KfnQPdb= "E < output\/gwppa.out\/ndb.QP"  # [EXTQP BSK BSS] Database action' bse.in
# reduce parallelisation memory use
sed -i '/dipoles/a PAR_def_mode= "memory"           # [PARALLEL] Default distribution mode ("balanced"/"memory"/"workload"/"KQmemory")' bse.in

# add a line to remove the line below (limitation of sed?)
sed -i "/% BLongDir/a remove this line and the next" bse.in
sed -i "/remove this line and the next/,+1d" bse.in
# replace the removed line
sed -i "/% BLongDir/a \ 1.000000 | 1.000000 | 1.000000 |        # [BSS] [cc] Electric Field" bse.in

# Run Bethe-Salpeter
srun yambo -F bse.in -J "output/gwppa.out,BSE"
# report at output/r-gwppa.out_optics_dipoles_bss_bse
# Plot the Optical Absorption
gnuplot  <<\EOF
set terminal png size 500,400
set output 'BSE-optical-absorption-10-10-3.png'
set title 'BSE Optical absorption vs. Energy (eV)'
plot 'output/o-gwppa.out.eps_q1_diago_bse' u 1:2 w l
EOF

# Following this:
# https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons
# Plot the exciton strengths
srun ypp -e s 1 -V qp -J "BSE,output/gwppa.out"
# report at r-BSE_excitons
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-strength-10-10-3.png'
set title 'Excitons sorted for the q-index = 1 (optical limit q=0)'
set xlabel 'E (eV)'
set ylabel 'Strength'
plot 'o-BSE.exc_qpt1_E_sorted' with p
EOF

# Interpolate exciton dispersion
rm -f bse_exciton.in
srun ypp -e i -F bse_exciton.in
sed -i 's/States= "0 - 0"/States= "0 - 4"/' bse_exciton.in
sed -i 's/INTERP_mode= "NN"   /INTERP_mode= "BOLTZ"/' bse_exciton.in
sed -i 's/BANDS_steps= 10 /BANDS_steps= 100/' bse_exciton.in
sed -i '/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |' bse_exciton.in
srun ypp -F bse_exciton.in -J "BSE,output/gwppa.out"
# report at r-BSE_excitons_interpolate
# Plot exciton energies
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-along-path-10-10-3.png'
set title 'BSE excitons along Gamma-Kappa path'
set xlabel '|q| (a.u.)'
set ylabel 'Exiton energy (eV)'
set yrange [ 0 : ]
plot for [i=2:7] 'o-BSE.excitons_interpolated' using 1:i with l title "Exciton ".(i-1)
EOF
