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
    print "\nCalculated xcart:"
    for (i = 1; i <= natom; i++) {
        xcart_x = x[3*i-2]*r[1] + x[3*i-1]*r[4] + x[3*i]*r[7]
        xcart_y = x[3*i-2]*r[2] + x[3*i-1]*r[5] + x[3*i]*r[8]
        xcart_z = x[3*i-2]*r[3] + x[3*i-1]*r[6] + x[3*i]*r[9]
        printf "%.10f %.10f %.10f\n", xcart_x, xcart_y, xcart_z
    }
}')

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


