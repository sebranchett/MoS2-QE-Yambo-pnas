#!/bin/bash

#SBATCH --job-name=MoS2-bse
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=02:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8GB

# find your account with:
# sacctmgr list -sp user $USER
# #SBATCH --account=research-uco-ict

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

WORKDIR=${PWD}/bse-5-5-2
cd "$WORKDIR"

# The GW results should be in the current location

# Static screening
# Create input
srun -n1 yambo -X s -F statscreen.in
sed -i 's/NGsBlkXs.*/NGsBlkXs= 5                Ry    # [Xs] Response block size/' statscreen.in
sed -i 's/0.000000 |/1.000000 |/g' statscreen.in
# Run static screening
srun yambo -F statscreen.in -J BSE
# Find the number of q-points
qpoints=$(grep 'IBZ Q-points' r-BSE_screen_dipoles_em1s | awk '{print $4}')

# Bethe-Salpeter kernel
# Create input
srun -n1 yambo -o b -k sex -F bse_kernel.in -J BSE
sed -i 's/BSENGexx.*/BSENGexx=  68              Ry    # [BSK] Exchange components/' bse_kernel.in
sed -i 's/BSENGBlk.*/BSENGBlk=   5              Ry    # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/' bse_kernel.in
# The article states three valence and five conduction bands
# Band 52 is the highest occupied state, and states are degenerate
sed -i 's/.*# \[BSK\] Bands range/  47 |  62 |                     # [BSK] Bands range/' bse_kernel.in
sed -i "s/.*# \[BSK\] Transferred momenta range/ 1 | ${qpoints} |                             # [BSK] Transferred momenta range/" bse_kernel.in
# and run
srun yambo -F bse_kernel.in -J BSE

# Reading the QP corrections from a previous GW calculation
# Create input
srun -n1 yambo -F bse_qp.in -y d -V qp -J BSE

sed -i 's/BSENGexx.*/BSENGexx=  68              Ry    # [BSK] Exchange components/' bse_qp.in
sed -i 's/BSENGBlk.*/BSENGBlk=   5              Ry    # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/' bse_qp.in
# Read the QP corrections from previous GW calculation
sed -i 's/KfnQPdb.*/KfnQPdb= "E < output\/gwppa.out\/ndb.QP"  # [EXTQP BSK BSS] Database action/' bse_qp.in
# write exciton composition, in terms of electron-hole pairs, to disk
sed -i 's/#WRbsWF/WRbsWF/' bse_qp.in
sed -i "s/.*# \[BSK\] Transferred momenta range/ 1 | ${qpoints} |                             # [BSK] Transferred momenta range/" bse_qp.in
# and run BSE
srun yambo -F bse_qp.in -J "output/gwppa.out,BSE"

# Plot the Optical Absorption
gnuplot  <<\EOF
set terminal png size 500,400
set output 'BSE-optical-absorption-5-5-2.png'
set title 'BSE Optical absorption vs. Energy (eV)'
plot 'output/o-gwppa.out.eps_q1_diago_bse' u 1:2 w l
EOF

# Following this:
# https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons
# Plot the exciton strengths
srun ypp -e s 1 -V qp -J "BSE,output/gwppa.out"
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-strength-5-5-2.png'
set title 'Excitons sorted for the q-index = 1 (optical limit q=0)'
set xlabel 'E (eV)'
set ylabel 'Strength'
plot 'o-BSE.exc_qpt1_E_sorted' with p
EOF

# Interpolate exciton dispersion
srun ypp -e i -F bse_exciton.in
sed -i 's/States= "0 - 0"/States= "0 - 4"/' bse_exciton.in
sed -i 's/INTERP_mode= "NN"   /INTERP_mode= "BOLTZ"/' bse_exciton.in
sed -i 's/BANDS_steps= 10 /BANDS_steps= 100/' bse_exciton.in
sed -i '/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |' bse_exciton.in
srun ypp -F bse_exciton.in -J "BSE,output/gwppa.out"
# Plot exciton energies
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-along-path-5-5-2.png'
set title 'BSE excitons along Gamma-Kappa path'
set xlabel '|q| (a.u.)'
set ylabel 'Exiton energy (eV)'
set yrange [ 0 : ]
plot for [i=2:7] 'o-BSE.excitons_interpolated' using 1:i with l title "Exciton ".(i-1)
EOF
