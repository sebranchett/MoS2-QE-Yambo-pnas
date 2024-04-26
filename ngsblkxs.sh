# W size convergence
rm -f NGsBlkXp.dat
for NGsBlkXp in .5 01 03 05 10 15 20; do
  shift=$(grep "  52 " gvec-${NGsBlkXp}/output/o-gwppa.out.qp | grep "  1  " | awk '{print $4}')
  grep "  53 " gvec-${NGsBlkXp}/output/o-gwppa.out.qp | grep "  1  " | awk -v NGsBlkXp="$NGsBlkXp" -v shift="$shift" '{print NGsBlkXp " " $3+$4-shift}' >> NGsBlkXp.dat
done

gnuplot <<\EOF
set terminal png size 500,400
set output 'NGsBlkXp.png'
set title 'size convergence NGsBlkXs (Ry)'
set yrange [ 2 : ]
plot 'NGsBlkXp.dat' w lp
EOF
