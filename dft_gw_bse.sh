#!/bin/bash

task1=$(sbatch --parsable                               01_scf.sh)
task2=$(sbatch --parsable --dependency=aftercorr:$task1 02_gw.sh)
task3=$(sbatch --parsable --dependency=aftercorr:$task2 03_sscreen.sh)
task4=$(sbatch --parsable --dependency=aftercorr:$task3 04_bse.sh)
