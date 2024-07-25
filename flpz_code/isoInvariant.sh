#!/bin/bash 

# Creates the input to the invariance program on Isotropy
# Usage: ./isoInvariant.sh <input_file> <irrep_1> <irrep_2>

isoInput="isoInputInv.txt"
input_file="$1"
irrep_1="$2"
irrep_2="$3"

read_input_params() {
    general_structure_file=$(grep "genstruc" "$input_file" | awk '${print $2}')
    min_degree=$(grep "min_degree" "$input_file" | awk '${print $2}')
    max_degree=$(grep "max_degree" "$input_file" | awk '${print $2}')
    irrepDir_1=$(grep "irrepDir_1" "$input_file" | awk '${print $2}')
    irrepDir_2=$(grep "irrepDir_2" "$input_file" | awk '${print $2}')
}

# Create FINDSYM input file
create_invariant_input() {
    cat << EOF > "$isoInput"
VALUE PARENT $(bash findSpaceGroup.sh "$general_structure_file")
VALUE IRREP ${irrep_1} ${irrep_2}
Value degree ${min_degree} ${max_degree}
value direction ${irrepDir_1} ${irrepDir_2}
DISPLAY INVARIANT
EOF
}

read_input_params
create_invariant_input
iso < "$isoInput"

# Clean up
rm "$isoInput"
