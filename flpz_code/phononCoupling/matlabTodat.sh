#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Usage: ./matlabTodat.sh <matlab_file>

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Please provide the input Matlab file as an argument." >&2
    exit 1
fi

input_file="$1"
output_file="${input_file%.*}.dat"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found." >&2
    exit 1
fi

# Extract x_vec and totEnergy_vec values
mapfile -t x_vec < <(sed -n '/x_vec = \[/,/];/p' "$input_file" | grep -v '[x_vec=\[\];]' | sed 's/^[[:space:]]*//' | tr -d '[];')
mapfile -t totEnergy_vec < <(sed -n '/totEnergy_vec = \[/,/];/p' "$input_file" | grep -v '[totEnergy_vec=\[\];]' | sed 's/^[[:space:]]*//' | tr -d '[];')

# Write to output file
> "$output_file"

# Process x_vec and totEnergy_vec
for ((i = 0; i < ${#x_vec[@]} && i < ${#totEnergy_vec[@]}; i++)); do
    IFS=' ' read -r x y <<< "${x_vec[$i]}"
    energy="${totEnergy_vec[$i]}"

    # Remove any trailing commas
    x=${x%,}
    y=${y%,}
    energy=${energy%,}

    if [[ $x =~ ^-?[0-9.eE+-]+$ ]] && [[ $y =~ ^-?[0-9.eE+-]+$ ]] && [[ $energy =~ ^-?[0-9.eE+-]+$ ]]; then
        printf "%.10f %.10f %.10f\n" "$x" "$y" "$energy" >> "$output_file"
    fi
done

echo "Conversion complete. Output written to $output_file"