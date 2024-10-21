#!/bin/bash

# This script is used to resolve any discrepancy with the use of SLURM on different computers,
# allowing the user to customize their SLURM preamble. Although the first argument is redundant,
# it allows the code to be used in a general context.

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <inputCode> <b_script_preamble>"
    exit 1
fi

# Handle inputs
inputCode="$1"
bScriptPreamble="$2"

# Directory to check and create edited input files
dir_name="flpz_input_compiled"

# Check if directory exists, remove if it does, then create it
if [ -d "$dir_name" ]; then
    rm -rf "$dir_name"
fi
cp -r "$inputCode" "$dir_name"

# File to be inserted at the beginning of each specified file
file_to_insert=$bScriptPreamble

# List of files to process
files_to_process=(
    "b-script-flpzEnergy"
    "b-script-flpzPert"
    "b-script-flpzCouple"
    "b-script-flpzCoupleAnalyze"
)

# Function to insert file content after the first line
insert_file() {
    local target_file="$1"
    local temp_file="${target_file}.temp"

    sed "1r $file_to_insert" "$target_file" >"$temp_file" && mv "$temp_file" "$target_file"
}

# Process each file
for file in "${files_to_process[@]}"; do
    # Insert the content at the beginning of the copied file
    insert_file "$dir_name/$file"
    echo "Processed: $file"
done

echo "All files processed. Results are in $dir_name directory."
