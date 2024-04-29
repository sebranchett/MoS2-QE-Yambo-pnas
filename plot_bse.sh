#!/bin/bash

#SBATCH --job-name=plot-bse
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1GB

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

# Following this:
# https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons

srun ypp -e s 1 -V qp -J "BSE,output/gwppa.out"
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE_exciton_strength.png'
set title 'Excitons sorted for the q-index = 1 (optical limit q=0)'
set xlabel 'E [ev]'
set ylabel 'Strength'
plot 'o-BSE.exc_qpt1_E_sorted' with p
EOF
