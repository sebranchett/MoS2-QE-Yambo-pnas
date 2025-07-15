#!/bin/bash

#SBATCH --job-name=prb-convergence
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=24
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

QEDIR=/scratch/sbranchett/qe-yambo/q-e-qe-7.3.1
YAMBODIR=/scratch/sbranchett/slepc-yambo/yambo-5.2.3
export PATH=$PATH:$QEDIR/bin:$YAMBODIR/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$YAMBODIR/lib

# Reproducing this paper:
# https://www.pnas.org/doi/full/10.1073/pnas.2010110118
# Evidence of ideal excitonic insulator in bulk MoS2 under pressure
# Input file generated using AMS for Quantum Espresso
# Pseudopotentials from https://www.physics.rutgers.edu/gbrv/

WORKDIR=${PWD}/conv
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

# Create initialisation file with:
srun -n1 yambo -i -V RL -F init.in
# Change parameters
sed -i 's/MaxGvecs.*/MaxGvecs=  50                    # [INI] Max number of G-vectors planned to use/' init.in
# and run it:
srun yambo -F init.in -J output/init.out

# Create GW input file with:
srun -n1 yambo -p p -F gwppa.in
# Make changes to GW input file
# 1) Add parallel directives
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

# 2) Change parameters
sed -i 's/GTermKind.*/GTermKind= "BG"                  # [GW] GW terminator ("none","BG" Bruneval-Gonze,"BRS" Berger-Reining-Sottile)/' gwppa.in

# W size convergence
rm -f G0W0_w_convergence.dat
for NGsBlkXp in 01 02 03 04 05 06 07; do
  sed -i "s|NGsBlkXp= 1                RL|NGsBlkXp= ${NGsBlkXp}                 Ry|" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${NGsBlkXp}Ry
  shift=$(grep "  52 " o-G0W0_W_${NGsBlkXp}Ry.qp | grep "  1  " | awk '{print $4}')
  grep "  53 " o-G0W0_W_${NGsBlkXp}Ry.qp | grep "  1  " | awk -v NGsBlkXp="$NGsBlkXp" -v shift="$shift" '{print NGsBlkXp " " $3+$4-shift}' >> G0W0_w_convergence.dat
  sed -i "s|NGsBlkXp= ..                 Ry|NGsBlkXp= 1                RL|" gwppa.in
done

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_size_convergence_NGsBlkXs.png'
set title 'W size convergence NGsBlkXs (Ry)'
plot 'G0W0_w_convergence.dat' w lp
EOF

# W bands convergence
sed -i "s|NGsBlkXp= 1                RL|NGsBlkXp= 3                Ry|" gwppa.in
rm -f G0W0_w_bands_convergence.dat
for BndsRnXp in 100 150 200 250 300; do
  sed -i "/BndsRnXp/{n;s|  1 . 300|  1 \| ${BndsRnXp}|}" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${BndsRnXp}_bands
  shift=$(grep "  52 " o-G0W0_W_${BndsRnXp}_bands.qp | grep "  1  " | awk '{print $4}')
  grep "  53 " o-G0W0_W_${BndsRnXp}_bands.qp* | grep "  1  " | awk -v BndsRnXp="$BndsRnXp" -v shift="$shift" '{print BndsRnXp " " $3+$4-shift}' >> G0W0_w_bands_convergence.dat
  # set back to 1 - 10
  sed -i "/BndsRnXp/{n;s|  1 . ${BndsRnXp}|  1 \| 300|}" gwppa.in
done
sed -i "s|NGsBlkXp= 3                Ry|NGsBlkXp= 1                RL|" gwppa.in

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_bands_convergence_BndsRnXs.png'
set title 'W bands convergence BndsRnXs - NGsBlkXs=3Ry'
plot 'G0W0_w_bands_convergence.dat' w lp
EOF

# Empty bands convergence
sed -i "s|NGsBlkXp= 1                RL|NGsBlkXp= 3                Ry|" gwppa.in
sed -i "/GbndRnge/i UseEbands" gwppa.in
rm -f G0W0_empty_bands_convergence.dat
for GbndRnge in 50 100 150 200 250 300; do
  sed -i "/GbndRnge/{n;s|  1 . 300|  1 \| ${GbndRnge}|}" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${GbndRnge}_empty_bands
  shift=$(grep "  52 " o-G0W0_W_${GbndRnge}_empty_bands.qp | grep "  1  " | awk '{print $4}')
  grep "  53 " o-G0W0_W_${GbndRnge}_empty_bands.qp* | grep "  1  " | awk -v GbndRnge="$GbndRnge" -v shift="$shift" '{print GbndRnge " " $3+$4-shift}' >> G0W0_empty_bands_convergence.dat
  # set back to 1 - 300
  sed -i "/GbndRnge/{n;s|  1 . ${GbndRnge}|  1 \| 300|}" gwppa.in
done
sed -i "s|NGsBlkXp= 3                Ry|NGsBlkXp= 1                RL|" gwppa.in
sed -i "/UseEbands/d" gwppa.in

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_empty_bands_convergence_GbndRnge.png'
set title 'W empty bands convergence GbndRnge - NGsBlkXs=3Ry'
plot 'G0W0_empty_bands_convergence.dat' w lp
EOF

