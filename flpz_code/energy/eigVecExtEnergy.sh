#!/bin/bash

# Eigenvalue Vector Extraction for Energy Calculations
# Extracts unstable phonon modes and creates input files with eigenvectors

# Usage: ./eigVecExtEnergy.sh <dynFreqs_file> <fceVecs_file> <input_file>

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <dynFreqs_file> <fceVecs_file> <input_file>"
    exit 1
fi

dynFreqs_file="$1"
fceVecs_file="$2"
input_file="$3"

# Remove the first line of dynFreqs_file (assumed to be a header)
sed '1d' "$dynFreqs_file" >"tmpfile.abi" && mv "tmpfile.abi" "$dynFreqs_file"

# Find unstable phonons (excluding acoustic modes)
find_unstable_phonons() {
    awk '                                  
        {
            if ($1 ~ /-/ || $2 ~ /-/) {
                if ($2 < -20) {
                    print NR
                }
            }
        }
    ' "$dynFreqs_file"
}

eigVec_lines=$(find_unstable_phonons)
eigVec_nlines=$(echo "$eigVec_lines" | wc -w)

echo "There are $eigVec_nlines unstable phonons"

# Create input files with eigenvectors
create_input_files() {
    local file_num=$1
    local output_file="${input_file}_vec${file_num}"

    cp "$input_file" "$output_file"
    echo "vecNum ${file_num}" >>"$output_file"
    echo "eigen_disp1" >>"$output_file"

    sed -n "${file_num}p" "$fceVecs_file" |
        awk '{
        for (i=1; i<=NF; i+=3) {
            print $i, $(i+1), $(i+2)
        }
    }' >>"$output_file"
}

for file_num in $eigVec_lines; do
    create_input_files "$file_num"
done

# Update the original input file with eigenvector information
{
    echo "eigVec_nlines $eigVec_nlines"
    echo "eigVec_lines"
    echo "$eigVec_lines"
} >>"$input_file"

echo "Eigenvalue vector extraction for energy calculations completed successfully."
