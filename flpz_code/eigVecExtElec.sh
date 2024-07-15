#!/bin/bash

# Eigenvalue Vector Extraction for Electronic Calculations
# Extracts the eigenvectors and creates input files with a displaced unit cell

# Usage: ./eigVecExtElec.sh <dynFreqs_file> <fceVecs_file> <input_file>

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <dynFreqs_file> <fceVecs_file> <input_file>"
    exit 1
fi

dynFreqs_file="$1"
fceVecs_file="$2"
input_file="$3"

# Extract calculation parameters
num_phon=$(grep "num_phon" "$input_file" | awk '{print $2}')
mode_location=$(grep -n "calc_phon" "$input_file" | cut -d: -f1)
calc_phon=""
if [ -n "$num_phon" ] && [ -n "$mode_location" ]; then
    calc_phon=$(sed -n "$((mode_location+1)),$((mode_location+num_phon))p" "$input_file")
fi

# Remove the first line of dynFreqs_file (assumed to be a header)
sed '1d' "$dynFreqs_file" > "tmpfile.abi" && mv "tmpfile.abi" "$dynFreqs_file"

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

unstable_phonons=$(find_unstable_phonons)
unstable_nlines=$(echo "$unstable_phonons" | wc -w)

echo "There are $unstable_nlines total unstable phonons"

# Check if requested phonons are within range and match with those found
eigVec_lines=""
if [ -n "$num_phon" ]; then
    for phonon in $unstable_phonons; do
        for desired_phonon in $calc_phon; do
            if [ "$phonon" = "$desired_phonon" ]; then
                eigVec_lines+="$phonon "
            fi
        done
    done
else
    eigVec_lines=$unstable_phonons
fi

eigVec_nlines=$(echo "$eigVec_lines" | wc -w)

echo "Extracting $eigVec_nlines unstable phonons: $eigVec_lines"

# Create input files with eigenvectors
create_input_files() {
    local file_num=$1
    local output_file="${input_file}_vec${file_num}"
    
    cp "$input_file" "$output_file"
    echo "vecNum ${file_num}" >> "$output_file"
    echo "eigen_disp" >> "$output_file"
    
    sed -n "${file_num}p" "$fceVecs_file" |
    awk '{
        for (i=1; i<=NF; i+=3) {
            print $i, $(i+1), $(i+2)
        }
    }' >> "$output_file"
}

for file_num in $eigVec_lines; do
    create_input_files "$file_num"
done

# Update the original input file with eigenvector information
{
    echo "eigVec_nlines $eigVec_nlines"
    echo "eigVec_lines"
    echo "$eigVec_lines"
} >> "$input_file"

echo "Eigenvalue vector extraction completed successfully."
