#!/bin/bash

#SBATCH --job-name=scf
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=01:00:00
#SBATCH --ntasks=24
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=3900MB
# #SBATCH --mail-type=ALL

# find your account with:
# sacctmgr list -sp user $USER

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module use --append /projects/electronic_structure/.modulefiles
module load qe
module load yambo

WORKDIR=${PWD}/MoS2
cd "$WORKDIR"

# Find the prefix name from scf.in
prefix=$(grep prefix scf.in | awk '{print $3}' | tr -d '[:punct:]')

# DFT with Quantum Espresso
# parameters to converge in combination with GW/BSE: ecutwfc, nbnd, K_POINTS
mkdir -p output
# scf
srun pw.x < scf.in > output/scf.out
# bands - for the graph
# # srun pw.x < bands.in > output/bands.out
# nscf
# srun pw.x < nscf.in > output/nscf.out

# Convert Quantum Espresso output to Yambo input
cd ${prefix}.save
srun p2y > ../output/p2y.out
cd ..
# p2y.out is empty if all went well

