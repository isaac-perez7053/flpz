#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

input_file="$1"

# Get the number of atoms
natom=$(grep "natom" "$input_file" | awk '{print $2}')

# Extract rprim matrix
rprim=$(awk '/rprim/,/^$/' "$input_file" | tail -n 3)

# Extract xred coordinates
xred=$(awk -v natom="$natom" '/xred/,/^$/ {if (NR > 1 && count < natom) {print; count++}}' "$input_file")

# Perform the conversion using awk
xcart=$(awk -v rprim="$rprim" -v xred="$xred" -v natom="$natom" '
BEGIN {
    split(rprim, r, /[ \n]/)
    split(xred, x, /[ \n]/)
    
    for (i = 1; i <= natom * 3; i += 3) {
        xcart_x = x[i]*r[1] + x[i+1]*r[4] + x[i+2]*r[7]
        xcart_y = x[i]*r[2] + x[i+1]*r[5] + x[i+2]*r[8]
        xcart_z = x[i]*r[3] + x[i+1]*r[6] + x[i+2]*r[9]
        printf "%.10f %.10f %.10f\n", xcart_x, xcart_y, xcart_z
    }
}')

# Use sed to replace xred with xcart in-place
sed -i.bak '
/xred/,/^$/ {
    /xred/c\
xcart
    /^$/!d
}
/xcart/r /dev/stdin
' "$input_file" <<< "$xcart"

echo "Conversion complete. Original file backed up as ${input_file}.bak"

