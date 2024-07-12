#!/bin/bash

module load 2023r1
module load gnuplot

WORKDIR=${PWD}/../MoS2-27-27-3
cd "$WORKDIR"

# DFT and bands
gnuplot <<\EOF
set terminal png size 200,400
set output '../figures/bands-27-27-3.png'
set title 'Bands along Gamma-Kappa'
set yrange [-2.5:3.]
plot 'o.bands_interpolated_dft' using 0:2 w l lt rgb "#56B4E9" title "DFT", \
     'o.bands_interpolated_dft' using 0:3 w l lt rgb "#56B4E9" notitle, \
     'o.bands_interpolated_dft' using 0:5 w l lt rgb "#56B4E9" notitle, \
     'o.bands_interpolated_dft' using 0:7 w l lt rgb "#56B4E9" notitle, \
     'o.bands_interpolated_dft' using 0:9 w l lt rgb "#56B4E9" notitle, \
     'o.bands_interpolated_dft' using 0:11 w l lt rgb "#56B4E9"  notitle, \
     'o.bands_interpolated_gw' using 0:2 w l lt rgb "#000000" title "GW", \
     'o.bands_interpolated_gw' using 0:3 w l lt rgb "#000000" notitle, \
     'o.bands_interpolated_gw' using 0:5 w l lt rgb "#000000" notitle, \
     'o.bands_interpolated_gw' using 0:7 w l lt rgb "#000000" notitle, \
     'o.bands_interpolated_gw' using 0:9 w l lt rgb "#000000" notitle, \
     'o.bands_interpolated_gw' using 0:11 w l lt rgb "#000000" notitle
EOF

