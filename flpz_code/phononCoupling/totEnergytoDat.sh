#!/bin/bash

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Please provide the input Matlab file as an argument."
    exit 1
fi

input_file=$1
output_file="${input_file%.*}.dat"

# If the input file exists somewhere else beside the current working directory
mv "$output_file" . 

# Extract x_vec and totEnergy_vec values
x_vec="($(sed -n '/x_vec = \[/,/];/p' "$input_file" | grep -v '[x_vec=\[\];]' | tr -d ' '))"
totEnergy_vec="($(sed -n '/totEnergy_vec = \[/,/];/p' "$input_file" | grep -v '[totEnergy_vec=\[\];]' | tr -d ' '))"

# Write to output file
> "$output_file"  # Clear the file if it exists
for i in "${!x_vec[@]}"; do
    x=${x_vec[$i]}
    energy=${totEnergy_vec[$i]}
    if [[ $x =~ ^[0-9.eE+-]+$ ]] && [[ $energy =~ ^[0-9.eE+-]+$ ]]; then
        printf "%.10f %.10f\n" "$x" "$energy" >> "$output_file"
    fi
done

echo "Conversion complete. Output written to $output_file"