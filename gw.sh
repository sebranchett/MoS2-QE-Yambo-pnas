#!/bin/bash

#SBATCH --job-name=gw
#SBATCH --partition=compute-p1,compute-p2
#SBATCH --account=innovation
#SBATCH --time=01:00:00
#SBATCH --ntasks=24
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=3900MB
# #SBATCH --mail-type=ALL

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module use --append /projects/electronic_structure/.modulefiles
module load yambo
module load gnuplot

# Reproducing this paper:
# https://www.pnas.org/doi/full/10.1073/pnas.2010110118
# Evidence of ideal excitonic insulator in bulk MoS2 under pressure
# Input file generated using AMS for Quantum Espresso
# Pseudopotentials from https://www.physics.rutgers.edu/gbrv/

WORKDIR=${PWD}/MoS2
cd "$WORKDIR"

# Set up calculation parameters
# GW bands for correction calculation - QPkrange
Number_valence_bands_gw=6
Number_conduction_bands_gw=10
# GW bands for plot
Number_valence_bands_gw_p=3
Number_conduction_bands_gw_p=7
# EXXRLvcs
Exchange_components_Ry=68
# VXCRLvcs
XCpotential_components_Ry=15
# NGsBlkXp
Response_block_size_Ry=5

# Electric Field
LongDrXp=' 1.000000 | 1.000000 | 1.000000 |'
# Bands path, divisions in k-space and title
BANDS_kpts='0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |'
BANDS_steps=50
Band_plot_title='"DFT and GW bands along Gamma-Kappa path"'

mkdir -p output
# Copy the converted Qantum Espresso DFT data
# Find the prefix name from the scf.in file
prefix=$(grep prefix scf.in | awk '{print $3}' | tr -d '[:punct:]')
cp -rf ${prefix}.save/SAVE SAVE

# Create initialisation file (init.in) for Yambo
rm -f init.in
yambo -i -V RL -F init.in
# and run it:
srun yambo -F init.in -J output/init
# Yambo report at output/r-init_setup

# Find model characteristics
kpoints=$(grep 'IBZ K-points' output/r-init_setup | awk '{print $4}')
Highest_valence_band=$(grep 'Filled Bands' output/r-init_setup | awk '{print $5}')

# Calculate band indices
Lower_band_gw=$((${Highest_valence_band} + 1 - ${Number_valence_bands_gw}))
Upper_band_gw=$((${Highest_valence_band} + ${Number_conduction_bands_gw}))
Lower_band_gw_p=$((${Highest_valence_band} + 1 - ${Number_valence_bands_gw_p}))
Upper_band_gw_p=$((${Highest_valence_band} + ${Number_conduction_bands_gw_p}))

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
sed -i "/LongDrXp/a \ ${LongDrXp}  # [Xp] [cc] Electric Field" gwppa.in

# reduce the number of bands to calculate the correction for
# first add a dummy line below QPkrange
sed -i "/QPkrange/a remove this line and the next" gwppa.in
# now remove the dummy line and the line below
# now add all the k points and the required bands
sed -i "/remove this line and the next/,+1d" gwppa.in
sed -i "/QPkrange/a \ 1 | ${kpoints} | ${Lower_band_gw} | ${Upper_band_gw} |" gwppa.in

# and run the GW calculation:
srun yambo -F gwppa.in -J output/gwppa
# Yambo report at output/r-gwppa_HF_and_locXC_gw0_em1d_ppa_el_el_corr

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
sed -i "/BANDS_bands/a \  ${Lower_band_gw_p} | ${Upper_band_gw_p} |  # Number of bands" ypp_bands.in

# add path in K-space
sed -i "/%BANDS_kpts /a \ ${BANDS_kpts}" ypp_bands.in
# edit number of steps along path
sed -i "s/BANDS_steps.*/BANDS_steps= ${BANDS_steps}  # Number of divisions/" ypp_bands.in
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

# Now run ypp to interpolate GW results
srun ypp -F ypp_bands.in
# report at r_electrons_bnds_01
mv -f o.bands_interpolated o.bands_interpolated_gw

# DFT and bands
cat > $SLURM_JOB_ID.gplot <<\EOF
set terminal png size 500,400
set output 'interpolated.png'
set title Band_plot_title
set xlabel '|k| (a.u.)'
set ylabel 'Energy (eV)'
plot 'o.bands_interpolated_dft' using 1:2 w l linetype 7 title "DFT", \
     for [i=3:Last_column] 'o.bands_interpolated_dft' using 1:i w l linetype 7 notitle, \
     'o.bands_interpolated_gw' using 1:2 w l linetype -1 title "GW", \
     for [i=3:Last_column] 'o.bands_interpolated_gw' using 1:i w l linetype -1 notitle
EOF
gnuplot -e "Last_column=$((${Number_valence_bands_gw_p} + ${Number_conduction_bands_gw_p} + 1))" -e "Band_plot_title=${Band_plot_title}" $SLURM_JOB_ID.gplot
mv -f interpolated.png interpolated_$SLURM_JOB_NAME.png
rm $SLURM_JOB_ID.gplot

