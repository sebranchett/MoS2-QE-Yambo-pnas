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

WORKDIR=${PWD}/bse
cd "$WORKDIR"

# The GW results should be in the current location

# Static screening
# Create input
srun -n1 yambo -X s -F statscreen.in
# Change LongDrXs so perturbing electric field has components in each direction
sed -i 's/NGsBlkXs.*/NGsBlkXs= 5                Ry    # [Xs] Response block size/' statscreen.in
sed -i 's/0.000000 |/1.000000 |/g' statscreen.in
# Run static screening
srun yambo -F statscreen.in -J BSE

# Bethe-Salpeter kernel
# Create input
srun -n1 yambo -o b -k sex -F bse_kernel.in -J BSE
sed -i 's/BSENGexx.*/BSENGexx=  68              Ry    # [BSK] Exchange components/' bse_kernel.in
sed -i 's/BSENGBlk.*/BSENGBlk= -1               RL    # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/' bse_kernel.in
# The article states three valence and five conduction bands
# Band 52 is the highest occupied state, and states are degenerate
sed -i 's/.*# \[BSK\] Bands range/  47 |  62 |                     # [BSK] Bands range/' bse_kernel.in
sed -i 's/.*# \[BSK\] Transferred momenta range/ 1 | 10 |                             # [BSK] Transferred momenta range/' bse_kernel.in
# and run
srun yambo -F bse_kernel.in -J BSE

# Reading the QP corrections from a previous GW calculation
# Create input
srun -n1 yambo -F bse_qp.in -y d -V qp -J BSE

# Read the QP corrections from previous GW calculation
sed -i 's/KfnQPdb.*/KfnQPdb= "E < output\/gwppa.out\/ndb.QP"  # [EXTQP BSK BSS] Database action/' bse_qp.in
# write exciton composition, in terms of electron-hole pairs, to disk
sed -i 's/#WRbsWF/WRbsWF/' bse_qp.in
sed -i 's/.*# \[BSK\] Transferred momenta range/ 1 | 10 |                             # [BSK] Transferred momenta range/' bse_qp.in
# and run BSE
srun yambo -F bse_qp.in -J "output/gwppa.out,BSE"

# Plot the results
gnuplot  <<\EOF
set terminal png size 500,400
set output 'bse-5-5-2.png'
set title 'BSE Optical absorption vs. Energy (eV)'
plot 'output/o-gwppa.out.eps_q1_diago_bse' u 1:2 w l
EOF

# Following this:
# https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons
srun ypp -e s 1 -V qp -J "BSE,output/gwppa.out"
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE_exciton_strength.png'
set title 'Excitons sorted for the q-index = 1 (optical limit q=0)'
set xlabel 'E (eV)'
set ylabel 'Strength'
plot 'o-BSE.exc_qpt1_E_sorted' with p
EOF
