#!/bin/bash

#SBATCH --job-name=geom
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

# Reproducing this paper:
# https://www.pnas.org/doi/full/10.1073/pnas.2010110118
# Evidence of ideal excitonic insulator in bulk MoS2 under pressure
# Input file generated using AMS for Quantum Espresso
# Pseudopotentials from https://www.physics.rutgers.edu/gbrv/

WORKDIR=${PWD}/geom
cd "$WORKDIR"

# Geometry optimisation with Quantum Espresso
mkdir -p output
# geometry optimisation
# parameters to converge: ecutwfc, nbnd, K_POINTS
srun pw.x < geom.in > output/geom.out
# write the new coordinates to a file, because they're not easy to find
sed -n '/Begin final coordinates/,/End final coordinates/ {p}' output/geom.out > output/new_coordinates.txt

