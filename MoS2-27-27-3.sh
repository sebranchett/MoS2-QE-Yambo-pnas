#!/bin/bash

#SBATCH --job-name=MoS2-27-27-3
#SBATCH --partition=compute
#SBATCH --account=research-as-cheme
#SBATCH --time=120:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem=180GB

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

WORKDIR=${PWD}/MoS2-27-27-3
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

# Create initialisation file
rm -f init.in
srun -n1 yambo -i -V RL -F init.in
# and run it:
srun yambo -F init.in -J output/init.out

# Create GW input file with:
rm -f gwppa.in
srun -n1 yambo -p p -F gwppa.in
# Make changes to GW input file
# 1) Change parameters
sed -i 's/EXXRLvcs.*/EXXRLvcs=  68              Ry    # [XX] Exchange    RL components/' gwppa.in
sed -i 's/VXCRLvcs.*/VXCRLvcs=  15              Ry    # [XC] XCpotential RL components/' gwppa.in
sed -i 's/GTermKind.*/GTermKind= "BG"                  # [GW] GW terminator ("none","BG" Bruneval-Gonze,"BRS" Berger-Reining-Sottile)/' gwppa.in
sed -i "s|NGsBlkXp.*|NGsBlkXp=   5              Ry    # [Xp] Response block size|" gwppa.in
sed -i "/GbndRnge/i UseEbands" gwppa.in

# 2) Add parallel directives
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

# G0W0
srun yambo -F gwppa.in -J output/gwppa.out

# Following step 3 of this tutorial to draw band structures
# https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

# clean up to be sure
rm -f ypp_bands.in
# create ypp input
srun -n1 ypp -s b -F ypp_bands.in
# edit number of bands
sed -i '/1 \| 302/d' ypp_bands.in
sed -i '/BANDS_bands/a \  50 | 59 |                      # Number of bands' ypp_bands.in
# add path in K-space
sed -i '/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |' ypp_bands.in
# edit number of steps along path
sed -i "s/10/50/" ypp_bands.in

# ypp to interpolate DFT results
srun ypp -F ypp_bands.in
mv -f o.bands_interpolated o.bands_interpolated_dft

# create ypp input for GW bands
cat <<\EOF >> ypp_bands.in
GfnQPdb= "E < ./output/gwppa.out/ndb.QP"
EOF

# ypp to interpolate GW results
srun ypp -F ypp_bands.in
mv -f o.bands_interpolated o.bands_interpolated_gw

# DFT and bands
gnuplot <<\EOF
set terminal png size 500,400
set output 'interpolated-27-27-3.png'
set title 'DFT and GW bands along Gamma-Kappa path'
plot 'o.bands_interpolated_dft' using 0:2 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:3 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:5 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:7 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:9 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:11 w l linetype 7, \
     'o.bands_interpolated_gw' using 0:2 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:3 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:5 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:7 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:9 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:11 w l linetype -1
EOF

