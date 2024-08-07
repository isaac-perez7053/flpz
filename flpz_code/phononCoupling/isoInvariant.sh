#!/bin/bash

# Creates the input to the invariance program on Isotropy
# Usage: ./isoInvariant.sh <input_file> <irrep_1> <irrep_2>

# Check if correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_file> <irrep_1> <irrep_2>"
    exit 1
fi

isoInput="isoInputInv.txt"
isoOutput="iso.log"
input_file="$1"
irrep_1="$2"
irrep_2="$3"

read_input_params() {
    general_structure_file=$(grep "genstruc" "$input_file" | awk '{print $2}')
    min_degree=$(grep "min_degree" "$input_file" | awk '{print $2}')
    max_degree=$(grep "max_degree" "$input_file" | awk '{print $2}')
    irrepDir_1=$(grep "irrepDir_1" "$input_file" | awk '{print $2}')
    irrepDir_2=$(grep "irrepDir_2" "$input_file" | awk '{print $2}')
}

# Create FINDSYM input file
create_invariant_input() {
    cat <<EOF >"$isoInput"
VALUE PARENT $(bash findSpaceGroup.sh "$general_structure_file")
VALUE IRREP ${irrep_1} ${irrep_2}
Value degree ${min_degree} ${max_degree}
value direction ${irrepDir_1} ${irrepDir_2}
DISPLAY INVARIANT
EOF
}

read_input_params
create_invariant_input

# Run iso program and process output
iso <"$isoInput" >"$isoOutput" 2>&1

awk '
    /Deg Invariants/,/^$/ {
        if (NF == 2 && $1 ~ /^[0-9]+$/) {
            gsub("n1", "x", $2)
            gsub("n2", "y", $2)
            printf "%s ", $2
        }
    }
' "$isoOutput" | sed 's/ $//'

# Clean up
rm "$isoInput"
rm "$isoOutput"
