#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Get the number of atoms
natom=$(grep "natom" "$input_file" | awk '{print $2}')
echo "Number of atoms: $natom"

# Extract rprim matrix (3 lines after the line containing only "rprim")
rprim=$(awk '/^rprim[[:space:]]*$/ {for(i=1;i<=3;i++) {getline; if (NF==3) print}}' "$input_file")

# Extract acell
acell=$(grep "acell" "$input_file")

# Extract xcart coordinates
xred=$(awk '/^xred[[:space:]]*$/ {for(i=1;i<='"$natom"';i++) {getline; if (NF==3) print}}' "$input_file")

# Perform the conversion using awk
xcart=$(awk -v rprim="$rprim" -v xred="$xred" -v natom="$natom" '
BEGIN {
    split(rprim, r, /[ \n]/)
    split(xred, x, /[ \n]/)
    
    for (i = 1; i <= natom * 3; i += 3) {
        xcart_x = x[i]*r[2] + x[i+1]*r[5] + x[i+2]*r[8]
        xcart_y = x[i]*r[3] + x[i+1]*r[6] + x[i+2]*r[9]
        xcart_z = x[i]*r[4] + x[i+1]*r[7] + x[i+2]*r[10]
        printf "%.10f %.10f %.10f\n", xcart_x, xcart_y, xcart_z
    }
}')

echo "Calculated xcart:"
echo "$xcart"

if [ -z "$xcart" ]; then
    echo "Error: xcart calculation failed"
    exit 1
fi

# Create a temporary file
temp_file=$(mktemp)

# Process the file and write to the temporary file
awk -v xcart="$xcart" -v rprim="$rprim" -v acell="$acell" '
/xred/,/^$/ {
    if ($0 ~ /xred/) {
        print "xcart"
        print xcart
        print ""
        print acell
	print "rprim"
        print rprim
        next
    }
    if ($0 ~ /^$/) {
        next
    }
    next
}
!/acell/ && !/rprim/ {print}
' "$input_file" > "$temp_file"
# Replace the original file with the temporary file
mv "$temp_file" "$input_file"


