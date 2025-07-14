#!/bin/bash

#SBATCH --job-name=sscreen
#SBATCH --partition=compute-p1,compute-p2
#SBATCH --account=innovation
#SBATCH --time=01:00:00
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=3900MB

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module use --append /projects/electronic_structure/.modulefiles
module load yambo

###############################################################################
# Initial set up
###############################################################################

WORKDIR=${PWD}/MoS2
cd "$WORKDIR"

# Requires these directories:
# - SAVE - after GW calculation
# - output/gwppa.out

# Find model characteristics
dft_nbnd=$(grep "Empty Bands" output/r-init_setup | awk '{print $6}')

###############################################################################
# USER PARAMETERS
###############################################################################

# BndsRnXs - Polarization function bands
pol_bnd_min=1
pol_bnd_max=${dft_nbnd}

# Electric Field - this depends on the dimensionality of the material
LongDrXs=' 1.000000 | 1.000000 | 1.000000 |'

# NGsBlkXs
Response_block_size_Ry=5

###############################################################################
# Static Screening
###############################################################################

# Create input file
rm -f statscreen.in
yambo -X s -F statscreen.in

# Make changes to the input file:
# first add a dummy line below BndsRnXs
sed -i "/BndsRnXs/a remove this line and the next" statscreen.in
# now remove the dummy line and the line below
sed -i "/remove this line and the next/,+1d" statscreen.in
# now add the bands range
sed -i "/BndsRnXs/a \ ${pol_bnd_min} | ${pol_bnd_max} |  # [Xs] Polarization function bands" statscreen.in

sed -i "s/NGsBlkXs.*/NGsBlkXs=  ${Response_block_size_Ry} Ry  # [Xs] Response block size/" statscreen.in

# first add a dummy line below LongDrXs
sed -i "/LongDrXs/a remove this line and the next" statscreen.in
# now remove the dummy line and the line below, which has the default direction
sed -i "/remove this line and the next/,+1d" statscreen.in
# now add in the new direction
sed -i "/LongDrXs/a \ ${LongDrXs}  # [Xs] [cc] Electric Field" statscreen.in

# Run static screening
srun yambo -F statscreen.in -J output/BSE
# Yambo reports at output/r-BSE_screen_dipoles_em1s

