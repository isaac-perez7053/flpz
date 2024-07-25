#!/bin/bash

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Please provide the input Matlab file as an argument."
    exit 1
fi

input_file=$1
output_file="${input_file%.*}.dat"

# Extract x_vec and totEnergy_vec values
x_vec=($(grep -A 11 'x_vec = \[' "$input_file" | tail -n 10 | tr -d ';'))
totEnergy_vec=($(grep -A 11 'totEnergy_vec = \[' "$input_file" | tail -n 10 | tr -d ';'))

# Write to output file
> "$output_file"  # Clear the file if it exists
for i in "${!x_vec[@]}"; do
    x=${x_vec[$i]}
    energy=$(printf "%.10f" "${totEnergy_vec[$i]/#**-**/-}")
    printf "%.10f %s\n" "$x" "$energy" >> "$output_file"
done

echo "Conversion complete. Output written to $output_file"
