#!/bin/bash
#SBATCH --job-name="abinit"
#SBATCH --output="abinit.%j.%N.out"
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=120G
#SBATCH --account=crl174
#SBATCH --export=ALL
#SBATCH -t 23:59:59

module purge
module load slurm
module load cpu/0.17.3b
module load gcc/10.2.0
module load openmpi/4.1.3
module load wannier90/3.1.0
module load netcdf-fortran/4.5.3
module load libxc/5.1.5
module load fftw/3.3.10
module load netlib-scalapack/2.1.0
export PATH=/expanse/projects/qstore/use300/jpg/abinit-10.0.5/bin:$PATH

## Check if the correct number of arguments are provided
# Storing inputs from input file
################################

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

## Read the command line arguments
input_fileAn="$1"
xpoints="$2"
inputAbo_files="$3"
structure="$4"
vecNum="$5"

# Creation of output file
output_file="Datasets_vec${vecNum}.m"

# Creation of totenergy vector file
outputEn_file="totEnergy_${vecNum}.m"
echo "totEnergy_vec = [" >> "$outputEn_file"

num_datapoints=$(sed -n '1p' "$input_fileAn")
#Search for totenergy and store
for dataset in $(seq 1 $(( num_datapoints + 1 )))
do
   echo "$(grep "etotal1" "$(sed -n "${dataset}p" "$inputAbo_files")" |awk '{print $2}')" >> "$outputEn_file"
done

# Combines the x_vec with the flexoElectricity matricies
echo "];" >> "$outputEn_file"
cat "$xpoints" >> "$output_file"
cat "$outputEn_file" >> "$output_file"

echo "Cleaning Up Some Files for You"
#rm $inputAbo_files
#rm $input_fileAn
#rm $xpoints

rm "fort.7"
rm "output.log"


