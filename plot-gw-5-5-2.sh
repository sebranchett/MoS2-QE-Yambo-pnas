#!/bin/bash

#SBATCH --job-name=MoS2-ypp
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=00:20:00
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

# Following step 3 of this tutorial to draw band structures
# https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

# create ypp input
srun -n1 ypp -s b -F ypp_bands.in
# edit number of bands
sed -i 's/ 1 | 102/50 |  59/' ypp_bands.in
# add path in K-space
sed -i '/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |' ypp_bands.in
# edit number of steps along path
sed -i "s/10/30/" ypp_bands.in

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

# Now create some plots
# E_gw vs. E_dft
gnuplot <<\EOF
set terminal png size 500,400
set output 'E_gw-E_dft.png'
plot 'output/o-gwppa.out.qp' using 3:($3+$4) w p title "E_gw vs. E_dft"
EOF

# DFT bands
gnuplot <<\EOF
set terminal png size 500,400
set output 'dft-interpolated-5-5-2.png'
set title 'DFT bands along Gamma-Kappa path'
plot 'o.bands_interpolated_dft' using 0:2 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:3 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:5 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:7 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:9 w l linetype 7, \
     'o.bands_interpolated_dft' using 0:11 w l linetype 7
EOF

# GW bands
gnuplot <<\EOF
set terminal png size 500,400
set output 'gw-interpolated-5-5-2.png'
set title 'G0W0 bands along Gamma-Kappa path'
plot 'o.bands_interpolated_gw' using 0:2 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:3 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:5 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:7 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:9 w l linetype -1, \
     'o.bands_interpolated_gw' using 0:11 w l linetype -1
EOF

