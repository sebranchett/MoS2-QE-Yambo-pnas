#!/bin/bash

#SBATCH --job-name=MoS2-plot
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

WORKDIR=${PWD}/MoS2-5-5-2
cd "$WORKDIR"
# bands calculation along a path in K-space
srun pw.x < mos2-bands.in > output/mos2-bands.out
# bands with bands.x
srun bands.x < mos2-bands-bands.in > output/mos2-bands-bands.out

# find number of K-points in output
K_POINTS="$(grep "number of k points" $WORKDIR/output/mos2-bands.out | awk '{print $5}')"
echo number of k points is $K_POINTS
K_BLOCK=$(($K_POINTS+1))
FIRST_PLOT_BAND=49
PLOT_BANDS=12
LAST_LINE=$(($K_BLOCK*($FIRST_PLOT_BAND+$PLOT_BANDS-1)))

# create a file with results from the required bands only
head -n $LAST_LINE MoS2.bands.gnu | tail -n $(($K_BLOCK*$PLOT_BANDS)) > dft-5-5-2.data

# plot the results
gnuplot <<\EOF
set terminal png size 500,400
set output 'dft-5-5-2.png'
set title 'DFT bands along Gamma-Kappa path'
plot "dft-5-5-2.data" w l
EOF

