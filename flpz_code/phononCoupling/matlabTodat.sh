#!/bin/bash

# Usage: ./matlabTodat.sh <matlab_file>

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Please provide the input Matlab file as an argument."
    exit 1
fi

input_file=$1
output_file="${input_file%.*}.dat"

# Extract x_vec and totEnergy_vec values
mapfile -t x_vec < <(sed -n '/x_vec = \[/,/];/p' "$input_file" | grep -v '[x_vec=\[\];]' | tr -d ' ')
mapfile -t totEnergy_vec < <(sed -n '/totEnergy_vec = \[/,/];/p' "$input_file" | grep -v '[totEnergy_vec=\[\];]' | tr -d ' ')

# Write to output file
>"$output_file" # Clear the file if it exists

# If the output file exists somewhere else beside the current working directory, move it
if [ ! -f "$output_file" ] && [ -f "../$output_file" ]; then
    mv "../$output_file" .
fi

# This doesn't handle y coordinate yet.
for ((i = 0; i < ${#x_vec[@]}; i++)); do
    x="${x_vec[$i]}"
    # x=$(${x_vec[$i]} | awk '{print $1}')
    # y=$(${x_vec[$i]} | awk '{print $2}')
    energy="${totEnergy_vec[$i]}"
    if [[ $x =~ ^[0-9.eE+-]+$ ]] && [[ $energy =~ ^[0-9.eE+-]+$ ]]; then
        printf "%.10f %.10f\n" "$x" "$energy" >>"$output_file"
    #    printf "%.10f %.10f %.10f\n" "$x" "$y" "$energy" >> "$output_file"
    fi
done

echo "Conversion complete. Output written to $output_file"
