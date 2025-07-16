#!/bin/bash

#SBATCH --job-name=qe_bands
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=3900MB
# #SBATCH --mail-type=ALL

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module use --append /projects/electronic_structure/.modulefiles
module load qe
module load gnuplot

WORKDIR=${PWD}/qe_bands
cd "$WORKDIR"

mkdir -p output
# Define the scf results directory
directory="../MoS2"
# Find the prefix name from bands.in
prefix=$(grep prefix bands.in | awk '{print $3}' | tr -d '[:punct:]')
# Copy the scf output
cp -rf ${directory}/${prefix}.save ${prefix}.save
cp -rf ${directory}/${prefix}.xml ${prefix}.xml

# find highest occupied band energy
shift=$(grep highest ${directory}/output/scf.out | awk '{print $7}')

# DFT with Quantum Espresso
srun pw.x < bands.in > output/bands.out
bands.x < bands-bands.in > output/bands-bands.out

# Plot exciton energies
cat > $SLURM_JOB_ID.gplot <<\EOF
set terminal png size 500,400
set output 'bands.png'
set title 'Quantum Espresso DFT bands'
set xlabel '|k| (a.u.)'
set ylabel 'Energy (eV)'
set yrange [ -4. : 4. ]
plot 'MoS2.bands.gnu' u ($1):($2 - shift) w l notitle
EOF
gnuplot -e "shift=${shift}" $SLURM_JOB_ID.gplot
rm $SLURM_JOB_ID.gplot

