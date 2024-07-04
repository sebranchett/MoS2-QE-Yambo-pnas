#!/bin/bash

module load 2023r1
module load gnuplot

gnuplot <<\EOF
set terminal png size 500,400
set output 'interpolated-combined.png'
set title 'DFT and GW bands along Gamma-Kappa path'
plot 'MoS2-5-5-2/o.bands_interpolated_dft' using 0:2 w l lt rgb "#56B4E9" title "5-5-2 DFT", \
     'MoS2-5-5-2/o.bands_interpolated_dft' using 0:3 w l lt rgb "#56B4E9" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_dft' using 0:5 w l lt rgb "#56B4E9" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_dft' using 0:7 w l lt rgb "#56B4E9" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_dft' using 0:9 w l lt rgb "#56B4E9" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_dft' using 0:11 w l lt rgb "#56B4E9" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:2 w l lt rgb "#0072B2" title "5-5-2 GW", \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:3 w l lt rgb "#0072B2" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:5 w l lt rgb "#0072B2" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:7 w l lt rgb "#0072B2" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:9 w l lt rgb "#0072B2" notitle, \
     'MoS2-5-5-2/o.bands_interpolated_gw' using 0:11 w l lt rgb "#0072B2" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:2 w l lt rgb "#E69F00" title "10-10-3 DFT", \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:3 w l lt rgb "#E69F00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:5 w l lt rgb "#E69F00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:7 w l lt rgb "#E69F00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:9 w l lt rgb "#E69F00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_dft' using 0:11 w l lt rgb "#E69F00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:2 w l lt rgb "#D55E00" title "10-10-3 GW", \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:3 w l lt rgb "#D55E00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:5 w l lt rgb "#D55E00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:7 w l lt rgb "#D55E00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:9 w l lt rgb "#D55E00" notitle, \
     'MoS2-10-10-3/o.bands_interpolated_gw' using 0:11 w l lt rgb "#D55E00" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:2 w l lt rgb "#009E73" title "27-27-3 DFT", \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:3 w l lt rgb "#009E73" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:5 w l lt rgb "#009E73" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:7 w l lt rgb "#009E73" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:9 w l lt rgb "#009E73" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_dft' using 0:11 w l lt rgb "#009E73" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:2 w l lt rgb "#000000" title "27-27-3 GW", \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:3 w l lt rgb "#000000" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:5 w l lt rgb "#000000" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:7 w l lt rgb "#000000" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:9 w l lt rgb "#000000" notitle, \
     'MoS2-27-27-3/o.bands_interpolated_gw' using 0:11 w l lt rgb "#000000" notitle
EOF

