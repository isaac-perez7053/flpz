#!/bin/bash 

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <eig_vec> <mapping>"
    exit 1
fi


# This will move down each line in the mapping variable and print every corresponding eigenvector in an array. 
# Note that the 

eig_vec="$1"
mapping="$2"

declare -a extendedEig_vec
while read -r line; do
    extendedEig_vec+=("$(echo "$eig_vec" | sed -n "${line}p")")
done < <(echo "$mapping")

# Print each element of the array
for element in "${extendedEig_vec[@]}"; do
    echo "$element"
done
