#!/bin/bash

# dataAnalysisEnergy.sh
# Analyzes the total energy of the perturbed system from datapoint calculations

# Usage: ./dataAnalysisEnergy.sh <derivative_db_file> <x_points_file> <abo_files_list> <structure_name> <vector_number>

# Check if the correct number of arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <derivative_db_file> <x_points_file> <abo_files_list> <vector_number>"
    exit 1
fi

# Read the command line arguments
derivative_db_file="$1"
x_points_file="$2"
abo_files_list="$3"
vector_number="$4"

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
