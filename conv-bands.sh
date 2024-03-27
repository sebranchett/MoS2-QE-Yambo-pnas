#!/bin/bash

#SBATCH --job-name=prb-convb
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem=32GB

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

WORKDIR=${PWD}/conv
cd "$WORKDIR"

# W bands convergence
sed -i "s|NGsBlkXp= 1                RL|NGsBlkXp= 3                Ry|" gwppa.in
# rm -f G0W0_w_bands_convergence.dat
for BndsRnXp in 10 20 30 40 50; do
  sed -i "/BndsRnXp/{n;s|  1 . .0|  1 \| ${BndsRnXp}|}" gwppa.in
#   rm -f o-G0W0_W_${BndsRnXp}_bands.qp
  srun yambo -F gwppa.in -J G0W0_W_${BndsRnXp}_bands
  # set back to 1 - 10
  sed -i "/BndsRnXp/{n;s|  1 . ${BndsRnXp}|  1 \| 10|}" gwppa.in
done
sed -i "s|NGsBlkXp= 3                Ry|NGsBlkXp= 1                RL|" gwppa.in

grep "  53 " o-G0W0_W_${BndsRnXp}_bands.qp | grep "  1  " | awk '{print $3+$4}' >> G0W0_w_bands_convergence.dat
# gnuplot "$WORKDIR"/G0W0_w_bands_convergence.gnuplot
# mv *.png "$WORKDIR"/Silicon/plots/

