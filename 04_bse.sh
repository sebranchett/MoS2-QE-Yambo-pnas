#!/bin/bash

#SBATCH --job-name=bse
#SBATCH --partition=compute-p1,compute-p2
#SBATCH --account=innovation
#SBATCH --time=02:00:00
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=3900MB

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module use --append /projects/electronic_structure/.modulefiles
module load yambo
module load gnuplot

###############################################################################
# Initial set up
###############################################################################

WORKDIR=${PWD}/MoS2
cd "$WORKDIR"

# Find model characteristics
qpoints=$(grep 'IBZ Q-points' output/r-init_setup | awk '{print $4}')
Highest_valence_band=$(grep 'Filled Bands' output/r-init_setup | awk '{print $5}')

###############################################################################
# USER PARAMETERS - These parameters change a lot for different calculations
###############################################################################
# 1 - these parameters need to be converged

# BSE bands for calculation - BSEBands
Number_valence_bands_bse=4
Number_conduction_bands_bse=8

# BSENGexx
Exchange_components_Ry=68
# VXCRLvcs
XCpotential_components_Ry=15
# NGsBlkXs
Response_block_size_Ry=5

# BSEQptR - number of centre of mass momenta of the exciton
q_min=1
q_max=${qpoints}

# 2 - these parameters do not need to be converged

# BLongDir - Electric Field - depends on polarisation of light
BLongDir=' 1.000000 | 1.000000 | 1.000000 |'

# Add extra parameters for SLEPC solver
# SEB

# BSE excitons to plot
# SEB
Number_excitons=4
# Bands path, divisions and title for plotting
BANDS_kpts='0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |'
BANDS_steps=50
Band_plot_title='"BSE excitons along Gamma-Kappa path"'

###############################################################################
# BSE
###############################################################################

# Calculate band indices
Lower_band_bse=$((${Highest_valence_band} + 1 - ${Number_valence_bands_bse}))
Upper_band_bse=$((${Highest_valence_band} + ${Number_conduction_bands_bse}))

# Create input
rm -f bse.in
yambo -o b -k sex -y d -F bse.in -J output/BSE
sed -i "s/BSENGexx.*/BSENGexx= ${Exchange_components_Ry} Ry  # [BSK] Exchange components/" bse.in
sed -i "s/BSENGBlk.*/BSENGBlk= ${Response_block_size_Ry} Ry  # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/" bse.in
# BSEBands
sed -i "s/.*# \[BSK\] Bands range/ ${Lower_band_bse} | ${Upper_band_bse} |  # [BSK] Bands range/" bse.in
# BSEQptR
sed -i "s/.*# \[BSK\] Transferred momenta range/ ${q_min} | ${q_max} |  # [BSK] Transferred momenta range/" bse.in
# write exciton composition, in terms of electron-hole pairs, to disk
sed -i "s/#WRbsWF/WRbsWF/" bse.in
# Read the QP corrections from previous GW calculation
sed -i "/WRbsWF/a KfnQPdb= \"E < output\/gwppa\/ndb.QP\"  # [EXTQP BSK BSS] Database action" bse.in

# Add extra parameters for SLEPC solver
# see: https://wiki.yambo-code.eu/wiki/index.php/Bethe-Salpeter_solver:_SLEPC
sed -i '/BSSmod/a BSSNEig= 55\nBSSEnTarget= 1.50 eV\nBSSSlepcMaxIt=0' bse.in

# edit BLongDir
sed -i "/% BLongDir/a remove this line and the next" bse.in
sed -i "/remove this line and the next/,+1d" bse.in
# replace the removed line
sed -i "/% BLongDir/a \ ${BLongDir}  # [BSS] [cc] Electric Field" bse.in

# Run Bethe-Salpeter
srun yambo -F bse.in -J "output/gwppa,output/BSE"
# report at output/r-gwppa_optics_dipoles_bss_bse

# Plot the Optical Absorption
gnuplot  <<\EOF
set terminal png size 500,400
set output 'BSE-optical-absorption.png'
set title 'BSE Optical absorption vs. Energy (eV)'
plot 'output/o-gwppa.eps_q1_diago_bse' u 1:2 w l
EOF
mv -f BSE-optical-absorption.png BSE-optical-absorption_$SLURM_JOB_NAME.png

# Following this:
# https://www.yambo-code.eu/wiki/index.php?title=How_to_analyse_excitons
# Plot the exciton strengths
srun ypp -e s 1 -V qp -J "output/BSE,output/gwppa"
# report at r-output/BSE_excitons
gnuplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-strength.png'
set title 'Excitons sorted for the q-index = 1 (optical limit q=0)'
set xlabel 'E (eV)'
set ylabel 'Strength'
plot 'output/o-BSE.exc_qpt1_E_sorted' with p
EOF
mv -f BSE-exciton-strength.png BSE-exciton-strength_$SLURM_JOB_NAME.png

# Interpolate exciton dispersion
# Create the ypp input file:
rm -f bse_exciton.in
srun ypp -e i -F bse_exciton.in

# and edit it:
sed -i "s/States=.*/States= \"1 - ${Number_excitons}\"  # Index of the BS state(s)/" bse_exciton.in
# add path in K-space
sed -i "/%BANDS_kpts /a \ ${BANDS_kpts}" bse_exciton.in
# edit number of steps along path
sed -i "s/BANDS_steps.*/BANDS_steps= ${BANDS_steps}  # Number of divisions/" bse_exciton.in
# smooth the interpolation
sed -i "s/INTERP_mode.*/INTERP_mode= \"BOLTZ\"  # Interpolation mode (NN=nearest point, BOLTZ=boltztrap aproach)/" bse_exciton.in

# and run ypp:
srun ypp -F bse_exciton.in -J "output/BSE,output/gwppa"
# report at output/r-BSE_excitons_interpolate

# Plot exciton energies
cat > $SLURM_JOB_ID.gplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-along-path.png'
set title Band_plot_title
set xlabel '|q| (a.u.)'
set ylabel 'Exiton energy (eV)'
set yrange [ 0 : ]
plot for [i=2:Last_column] 'output/o-BSE.excitons_interpolated' using 1:i with l title "Exciton ".(i-1)
EOF
gnuplot -e "Last_column=$((${Number_excitons} + 1))" -e "Band_plot_title=${Band_plot_title}" $SLURM_JOB_ID.gplot
mv -f BSE-exciton-along-path.png BSE-exciton-along-path_$SLURM_JOB_NAME.png
rm $SLURM_JOB_ID.gplot

