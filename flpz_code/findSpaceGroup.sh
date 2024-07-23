#!/bin/bash

# Find Space Group Script
# Finds the space group of a crystal system using isotropy

# Usage: ./findSpaceGroup.sh <abi_file>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <abi_file>"
    exit 1
fi

input_file="$1"
fsInput_file="findSymInput.in"

# Extract necessary information
natom=$(grep "natom" "$input_file" | awk '{print $2}')
rprim_location=$(grep -n "rprim" "$input_file" | cut -d: -f1)

# Extract rprim vectors
extract_rprim() {
    local line=$1
    sed -n "$((rprim_location + line))p" "$input_file" | \
    awk '{printf "(%s, %s, %s)\n", $1, $2, $3}'
}

nrprim1=$(extract_rprim 1)
nrprim2=$(extract_rprim 2)
nrprim3=$(extract_rprim 3)

# Function to expand shorthand notation
expand_notation() {
    local input="$1"
    local count="${input%%\**}"
    local value="${input#*\*}"
    if [[ "$input" == *"*"* ]]; then
        printf "$value %.0s" $(seq 1 $count)
    else
        echo "$input"
    fi
}

# Extract and expand acell parameters
acell_params=($(grep "^acell" "$input_file" | awk '{for(i=2;i<=NF;i++) print $i}'))
expanded_params=($(for param in "${acell_params[@]}"; do expand_notation "$param"; done))
a="${expanded_params[0]}"
b="${expanded_params[1]}"
c="${expanded_params[2]}"

# Extract xred or xcart
extract_coordinates() {
    local keyword=$1
    local start=$(grep -n "^[[:space:]]*$keyword" "$input_file" | cut -d: -f1)
    [ -n "$start" ] && sed -n "$((start+1)),$((start+natom))p" "$input_file"
}

xred=$(extract_coordinates "xred")
xcart=$(extract_coordinates "xcart")

# Extract and expand typat
typat_unexp=($(grep "^typat" "$input_file" | awk '{for(i=2;i<=NF;i++) print $i}'))
expanded_typat=($(for typat_one in "${typat_unexp[@]}"; do expand_notation "$typat_one"; done))

# Calculate angles
calculate_angle() {
    ./findAngle.py "$1" "$2"
}

alpha=$(calculate_angle "$nrprim2" "$nrprim3")
beta=$(calculate_angle "$nrprim1" "$nrprim3")
gamma=$(calculate_angle "$nrprim1" "$nrprim2")

# Create FINDSYM input file
cat << EOF > "$fsInput_file"
!useKeyWords
!occupationTolerance
0.01
!latticeParameters
$a, $b, $c, $alpha, $beta, $gamma
!atomCount
$natom
!atomType
${expanded_typat[@]}
!atomPosition
$xred
$xcart
EOF

# Run FINDSYM and extract space group number
findsym "$fsInput_file" | grep "_symmetry_Int_Tables_number" | awk '{print $2}'

# Clean up
rm "$fsInput_file"
