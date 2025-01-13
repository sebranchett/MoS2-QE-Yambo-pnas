#!/bin/bash

module load 2023r1
module load gnuplot

WORKDIR=${PWD}/../MoS2-5-5-2
cd "$WORKDIR"

gnuplot <<\EOF
set terminal png size 400,300
set output '../figures/exciton-5-5-2.png'
set title 'Excitons along Gamma-Kappa'
set xlabel '|q| (a.u.)'
set ylabel 'Exiton energy (eV)'
set xrange [ 0 : 0.6 ]
set yrange [ -0.7 : 2.4 ]
set xzeroaxis
plot 'output/o-BSE.excitons_interpolated' using 1:2 with l lt rgb "#000000" title "BSE exciton"
EOF
