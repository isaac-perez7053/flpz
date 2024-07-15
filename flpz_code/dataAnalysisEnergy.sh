#!/bin/bash

# dataAnalysisEnergy.sh
# Analyzes the total energy of the perturbed system from datapoint calculations

# Usage: ./dataAnalysisEnergy.sh <derivative_db_file> <x_points_file> <abo_files_list> <structure_name> <vector_number>

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

# Load required modules
module purge
module load slurm cpu/0.17.3b gcc/10.2.0 openmpi/4.1.3 wannier90/3.1.0 netcdf-fortran/4.5.3 libxc/5.1.5 fftw/3.3.10 netlib-scalapack/2.1.0

# Add Abinit to PATH
export PATH=/expanse/projects/qstore/use300/jpg/abinit-10.0.5/bin:$PATH

# Check if the correct number of arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <derivative_db_file> <x_points_file> <abo_files_list> <structure_name> <vector_number>"
    exit 1
fi

# Read the command line arguments
derivative_db_file="$1"
x_points_file="$2"
abo_files_list="$3"
structure_name="$4"
vector_number="$5"

# Set up output files
output_file="Datasets_vec${vector_number}.m"
energy_output_file="totEnergy_${vector_number}.m"

# Initialize total energy vector
echo "totEnergy_vec = [" > "$energy_output_file"

# Get number of datapoints
num_datapoints=$(sed -n '1p' "$derivative_db_file")

# Extract and store total energy for each dataset
for dataset in $(seq 1 $((num_datapoints + 1))); do
    abo_file=$(sed -n "${dataset}p" "$abo_files_list")
    etotal=$(grep "etotal1" "$abo_file" | awk '{print $2}')
    echo "$etotal" >> "$energy_output_file"
done

# Finalize total energy vector
echo "];" >> "$energy_output_file"

# Combine x points and total energy vectors in final output
cat "$x_points_file" "$energy_output_file" > "$output_file"

echo "Cleaning up temporary files..."
rm -f "fort.7" "output.log"

echo "Analysis complete. Results saved in $output_file"
