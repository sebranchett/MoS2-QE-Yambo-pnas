#!/bin/bash

#SBATCH --job-name=MoS2-5-5-2
#SBATCH --partition=compute
#SBATCH --account=innovation
#SBATCH --time=04:00:00
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=3900MB

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

WORKDIR=${PWD}/MoS2-5-5-2
cd "$WORKDIR"

# Set up calculation parameters
# GW bands for plot
Number_valence_bands_gw=3
Number_conduction_bands_gw=7
# BSE bands for calculation - BSEBands
Number_valence_bands_bse=6
Number_conduction_bands_bse=10
# BSE excitons to plot
Number_excitons=4
# GW and BSE
Exchange_components_Ry=68
XCpotential_components_Ry=15
Response_block_size_Ry=5

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
cp -rf MoS2.save/SAVE SAVE

# Create initialisation file
rm -f init.in
yambo -i -V RL -F init.in
# and run it:
srun yambo -F init.in -J output/init
# report at output/r-init_setup

Highest_valence_band=$(grep 'Filled Bands' output/r-init_setup | awk '{print $5}')
Lower_band_gw=$((${Highest_valence_band} + 1 - ${Number_valence_bands_gw}))
Upper_band_gw=$((${Highest_valence_band} + ${Number_conduction_bands_gw}))
Lower_band_bse=$((${Highest_valence_band} + 1 - ${Number_valence_bands_bse}))
Upper_band_bse=$((${Highest_valence_band} + ${Number_conduction_bands_bse}))

# G0W0

# Create GW input file with:
rm -f gwppa.in
yambo -p p -F gwppa.in

# Make changes to GW input file:
sed -i "s/EXXRLvcs.*/EXXRLvcs=  ${Exchange_components_Ry} Ry  # [XX] Exchange    RL components/" gwppa.in
sed -i "s/VXCRLvcs.*/VXCRLvcs=  ${XCpotential_components_Ry} Ry  # [XC] XCpotential RL components/" gwppa.in
sed -i "s/NGsBlkXp.*/NGsBlkXp=  ${Response_block_size_Ry} Ry  # [Xp] Response block size/" gwppa.in
sed -i "s/GTermKind.*/GTermKind= \"BG\"  # [GW] GW terminator (\"none\",\"BG\" Bruneval-Gonze,\"BRS\" Berger-Reining-Sottile)/" gwppa.in
sed -i "/GbndRnge/i UseEbands" gwppa.in
# edit the LongDrXp direction
# first add a dummy line below LongDrXp
sed -i "/LongDrXp/a remove this line and the next" gwppa.in
# now remove the dummy line and the line below, which has the default direction
sed -i "/remove this line and the next/,+1d" gwppa.in
# now add in the new direction
sed -i "/LongDrXp/a \  1.000000 | 1.000000 | 1.000000 |  # [Xp] [cc] Electric Field" gwppa.in

# and run the GW calculation:
srun yambo -F gwppa.in -J output/gwppa
# report at output/r-gwppa_HF_and_locXC_gw0_em1d_ppa_el_el_corr

# Following step 3 of this tutorial to draw band structures
# https://www.yambo-code.eu/wiki/index.php/How_to_obtain_the_quasi-particle_band_structure_of_a_bulk_material:_h-BN

# clean up to be sure
rm -f r_electrons_bnds*
rm -f o.bands_interpolated*
rm -f ypp_bands.in
# create ypp input
ypp -s b -F ypp_bands.in
# edit number of bands
# first add a dummy line below BANDS-bands
sed -i "/BANDS_bands/a remove this line and the next" ypp_bands.in
# now remove the dummy line and the line below, which has the default band range
sed -i "/remove this line and the next/,+1d" ypp_bands.in
# now add in the new band range
sed -i "/BANDS_bands/a \  ${Lower_band_gw} | ${Upper_band_gw} |  # Number of bands" ypp_bands.in
# add path in K-space
sed -i "/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |" ypp_bands.in
# edit number of steps along path
sed -i "s/BANDS_steps.*/BANDS_steps= 50  # Number of divisions/" ypp_bands.in
# smooth the interpolation
sed -i "s/INTERP_mode.*/INTERP_mode= \"BOLTZ\"  # Interpolation mode (NN=nearest point, BOLTZ=boltztrap aproach)/" ypp_bands.in

# run ypp to interpolate DFT results
srun ypp -F ypp_bands.in
# report at r_electrons_bnds
mv -f o.bands_interpolated o.bands_interpolated_dft

# update ypp input for GW bands
cat <<\EOF >> ypp_bands.in
GfnQPdb= "E < ./output/gwppa/ndb.QP"
EOF

# run ypp to interpolate GW results
srun ypp -F ypp_bands.in
# report at r_electrons_bnds_01
mv -f o.bands_interpolated o.bands_interpolated_gw

# DFT and bands
gnuplot <<\EOF
set terminal png size 500,400
set output 'interpolated.png'
set title 'DFT and GW bands along Gamma-Kappa path'
set xlabel '|k| (a.u.)'
set ylabel 'Energy (eV)'
plot 'o.bands_interpolated_dft' using 1:2 w l linetype 7 title "DFT", \
     'o.bands_interpolated_dft' using 1:3 w l linetype 7 notitle, \
     'o.bands_interpolated_dft' using 1:5 w l linetype 7 notitle, \
     'o.bands_interpolated_dft' using 1:7 w l linetype 7 notitle, \
     'o.bands_interpolated_dft' using 1:9 w l linetype 7 notitle, \
     'o.bands_interpolated_dft' using 1:11 w l linetype 7 notitle, \
     'o.bands_interpolated_gw' using 1:2 w l linetype -1 title "GW", \
     'o.bands_interpolated_gw' using 1:3 w l linetype -1 notitle, \
     'o.bands_interpolated_gw' using 1:5 w l linetype -1 notitle, \
     'o.bands_interpolated_gw' using 1:7 w l linetype -1 notitle, \
     'o.bands_interpolated_gw' using 1:9 w l linetype -1 notitle, \
     'o.bands_interpolated_gw' using 1:11 w l linetype -1 notitle
EOF
mv -f interpolated.png interpolated_$SLURM_JOB_NAME.png

# BSE

# Static screening
# Create input
rm -f statscreen.in
yambo -X s -F statscreen.in
sed -i "s/NGsBlkXs.*/NGsBlkXs= ${Response_block_size_Ry} Ry  # [Xs] Response block size/" statscreen.in
# set directions for Electric Field - LongDrXs
sed -i "/LongDrXs/a remove this line and the next" statscreen.in
sed -i "/remove this line and the next/,+1d" statscreen.in
sed -i "/LongDrXs/a \  1.000000 | 1.000000 | 1.000000 |  # [Xs] [cc] Electric Field" statscreen.in

# Run static screening
srun yambo -F statscreen.in -J output/BSE
# report at output/r-BSE_screen_dipoles_em1s
# Find the number of q-points
qpoints=$(grep 'IBZ Q-points' output/r-BSE_screen_dipoles_em1s | awk '{print $4}')

# Bethe-Salpeter
# Create input
rm -f bse.in
yambo -o b -k sex -y d -F bse.in -J output/BSE
sed -i "s/BSENGexx.*/BSENGexx= ${Exchange_components_Ry} Ry  # [BSK] Exchange components/" bse.in
sed -i "s/BSENGBlk.*/BSENGBlk= ${Response_block_size_Ry} Ry  # [BSK] Screened interaction block size [if -1 uses all the G-vectors of W(q,G,Gp)]/" bse.in
# The article states three valence and five conduction bands
# Band 52 is the highest occupied state, and states are degenerate
sed -i "s/.*# \[BSK\] Bands range/ ${Lower_band_bse} | ${Upper_band_bse} |  # [BSK] Bands range/" bse.in
sed -i "s/.*# \[BSK\] Transferred momenta range/ 1 | ${qpoints} |  # [BSK] Transferred momenta range/" bse.in
# write exciton composition, in terms of electron-hole pairs, to disk
sed -i "s/#WRbsWF/WRbsWF/" bse.in
# Read the QP corrections from previous GW calculation
sed -i "/WRbsWF/a KfnQPdb= \"E < output\/gwppa\/ndb.QP\"  # [EXTQP BSK BSS] Database action" bse.in

# edit BLongDir
sed -i "/% BLongDir/a remove this line and the next" bse.in
sed -i "/remove this line and the next/,+1d" bse.in
# replace the removed line
sed -i "/% BLongDir/a \ 1.000000 | 1.000000 | 1.000000 |  # [BSS] [cc] Electric Field" bse.in

# set default number of CPUs for Linear Algebra
sed -i "/WRbsWF/a BS_nCPU_LinAlg_INV= -1  # [PARALLEL] CPUs for Linear Algebra (if -1 it is automatically set)" bse.in
sed -i "/WRbsWF/a BS_nCPU_LinAlg_DIAGO= -1  # [PARALLEL] CPUs for Linear Algebra (if -1 it is automatically set)" bse.in

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
# smooth the interpolation
sed -i "s/INTERP_mode.*/INTERP_mode= \"BOLTZ\"  # Interpolation mode (NN=nearest point, BOLTZ=boltztrap aproach)/" bse_exciton.in
sed -i "s/BANDS_steps.*/BANDS_steps= 100  # Number of divisions/" bse_exciton.in
# add path in K-space
sed -i "/%BANDS_kpts /a \ 0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |" bse_exciton.in

# and run ypp:
srun ypp -F bse_exciton.in -J "output/BSE,output/gwppa"
# report at output/r-BSE_excitons_interpolate

# Plot exciton energies
cat > $SLURM_JOB_ID.gplot <<\EOF
set terminal png size 500,400
set output 'BSE-exciton-along-path.png'
set title 'BSE excitons along Gamma-Kappa path'
set xlabel '|q| (a.u.)'
set ylabel 'Exiton energy (eV)'
set yrange [ 0 : ]
plot for [i=2:Last_column] 'output/o-BSE.excitons_interpolated' using 1:i with l title "Exciton ".(i-1)
EOF
gnuplot -e "Last_column=$((${Number_excitons} + 1))" $SLURM_JOB_ID.gplot
mv -f BSE-exciton-along-path.png BSE-exciton-along-path_$SLURM_JOB_NAME.png
rm $SLURM_JOB_ID.gplot

