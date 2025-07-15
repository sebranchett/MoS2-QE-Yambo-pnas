#!/bin/bash

#SBATCH --job-name=gw_conv
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

###############################################################################
# Initial set up
###############################################################################

WORKDIR=${PWD}/conv
cd "$WORKDIR"

mkdir -p output
# Define prefix of DFT results
prefix="../MoS2/MoS2"
cp -rf ${prefix}.save/SAVE SAVE

# Create initialisation file (init.in) for Yambo and run the initialisation
rm -f init.in
yambo -i -V RL -F init.in  # this creates the input file
# Change parameters
sed -i 's/MaxGvecs.*/MaxGvecs=  50                    # [INI] Max number of G-vectors planned to use/' init.in
# and run it
srun yambo -F init.in -J output/init  # this runs the initialisation
# Yambo report at output/r-init_setup

# Find model characteristics
kpoints=$(grep 'IBZ K-points' output/r-init_setup | awk '{print $4}')
Highest_valence_band=$(grep 'Filled Bands' output/r-init_setup | awk '{print $5}')
Lowest_conduction_band=$(grep "Empty Bands" output/r-init_setup | awk '{print $5}')
dft_nbnd=$(grep "Empty Bands" output/r-init_setup | awk '{print $6}')

###############################################################################
# USER PARAMETERS - These parameters change a lot for different calculations
###############################################################################
# 1 - these parameters need to be converged

# GW bands for correction calculation - QPkrange
Number_valence_bands_gw=4
Number_conduction_bands_gw=8

# EXXRLvcs
Exchange_components_Ry=68
# VXCRLvcs
XCpotential_components_Ry=15
# NGsBlkXp
Response_block_size_Ry=5

# BndsRnXp - Polarization function bands
pol_bnd_min=1
pol_bnd_max=${dft_nbnd}
# GbndRnge - G[W] bands range
g_bnd_min=1
g_bnd_max=${dft_nbnd}

# QPkrange - QP generalized Kpoint/Band indices
# The k-point range can be reduced when convergence testing
k_min=1
k_max=${kpoints}

# 2 - these parameters do not need to be converged

# Electric Field
LongDrXp=' 1.000000 | 1.000000 | 1.000000 |'

# GW bands for plot
Number_valence_bands_gw_p=${Number_valence_bands_gw}
Number_conduction_bands_gw_p=${Number_conduction_bands_gw}
# Bands path, divisions in k-space and title for plotting
BANDS_kpts='0.00000 |0.00000 |0.00000 |\n 0.33333 |0.33333 |0.00000 |'
BANDS_steps=50
Band_plot_title='"DFT and GW bands along Gamma-Kappa path"'

###############################################################################
# GW
###############################################################################

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
sed -i "/QPkrange/a \ ${k_min} | ${k_max} | ${Lower_band_gw} | ${Upper_band_gw} |" gwppa.in

# reduce the number of bands for the polarization function
# first add a dummy line below BndsRnXp
sed -i "/BndsRnXp/a remove this line and the next" gwppa.in
# now remove the dummy line and the line below
sed -i "/remove this line and the next/,+1d" gwppa.in
# now add the bands range
sed -i "/BndsRnXp/a \ ${pol_bnd_min} | ${pol_bnd_max} |  # [Xp] Polarization function bands" gwppa.in

# reduce the number of bands for G[W]
# first add a dummy line below GbndRnge
sed -i "/GbndRnge/a remove this line and the next" gwppa.in
# now remove the dummy line and the line below
sed -i "/remove this line and the next/,+1d" gwppa.in
# now add the bands range
sed -i "/GbndRnge/a \ ${g_bnd_min} | ${g_bnd_max} |  # [GW] G[W] bands range" gwppa.in

###############################################################################
# Convergence
###############################################################################

# W size convergence
rm -f G0W0_w_convergence.dat
for NGsBlkXp in 01 02 03 04 05 06 07; do
  sed -i "s|NGsBlkXp=.*|NGsBlkXp= ${NGsBlkXp} Ry|" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${NGsBlkXp}Ry
  shift=$(grep "  ${Highest_valence_band} " o-G0W0_W_${NGsBlkXp}Ry.qp | grep "  1  " | awk '{print $4}')
  grep "  ${Lowest_conduction_band} " o-G0W0_W_${NGsBlkXp}Ry.qp | grep "  1  " | awk -v NGsBlkXp="$NGsBlkXp" -v shift="$shift" '{print NGsBlkXp " " $3+$4-shift}' >> G0W0_w_convergence.dat
done

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_size_convergence_NGsBlkXs.png'
set title 'W size convergence NGsBlkXs (Ry)'
plot 'G0W0_w_convergence.dat' w lp
EOF

# W bands convergence
sed -i "s|NGsBlkXp=.*|NGsBlkXp= 3 Ry|" gwppa.in
rm -f G0W0_w_bands_convergence.dat
for BndsRnXp in 60 70 80 90 100; do
  sed -i "/BndsRnXp/{n;s/.*/ 1 \| ${BndsRnXp} \|  # [Xp] Polarization function bands/}" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${BndsRnXp}_bands
  shift=$(grep "  ${Highest_valence_band} " o-G0W0_W_${BndsRnXp}_bands.qp | grep "  1  " | awk '{print $4}')
  grep "  ${Lowest_conduction_band} " o-G0W0_W_${BndsRnXp}_bands.qp* | grep "  1  " | awk -v BndsRnXp="$BndsRnXp" -v shift="$shift" '{print BndsRnXp " " $3+$4-shift}' >> G0W0_w_bands_convergence.dat
done

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_bands_convergence_BndsRnXs.png'
set title 'W bands convergence BndsRnXs - NGsBlkXs=3Ry'
plot 'G0W0_w_bands_convergence.dat' w lp
EOF

# Empty bands convergence
sed -i "s|NGsBlkXp=.*|NGsBlkXp= 3 Ry|" gwppa.in
rm -f G0W0_empty_bands_convergence.dat
for GbndRnge in 60 70 80 90 100; do
  sed -i "/GbndRnge/{n;s/.*/ 1 \| ${GbndRnge} \|  # [GW] G[W] bands range/}" gwppa.in
  srun yambo -F gwppa.in -J G0W0_W_${GbndRnge}_empty_bands
  shift=$(grep "  ${Highest_valence_band} " o-G0W0_W_${GbndRnge}_empty_bands.qp | grep "  1  " | awk '{print $4}')
  grep "  ${Lowest_conduction_band} " o-G0W0_W_${GbndRnge}_empty_bands.qp* | grep "  1  " | awk -v GbndRnge="$GbndRnge" -v shift="$shift" '{print GbndRnge " " $3+$4-shift}' >> G0W0_empty_bands_convergence.dat
done

gnuplot <<\EOF
set terminal png size 500,400
set output 'W_empty_bands_convergence_GbndRnge.png'
set title 'W empty bands convergence GbndRnge - NGsBlkXs=3Ry'
plot 'G0W0_empty_bands_convergence.dat' w lp
EOF

