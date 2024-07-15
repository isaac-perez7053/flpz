#!/bin/bash
# Converts reduced coordinates (xred) to Cartesian coordinates (xcart)
# Usage: ./xredToxcart.sh <input_file>

# Function to check correct number of arguments
check_args() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 <input_file>"
        exit 1
    fi
}

# Function to extract data from input file
extract_data() {
    local input_file="$1"
    natom=$(grep "natom" "$input_file" | awk '{print $2}')
    echo "Number of atoms: $natom"

    rprim=$(awk '/^rprim[[:space:]]*$/ {for(i=1;i<=3;i++) {getline; if (NF==3) print}}' "$input_file")
    acell=$(grep "acell" "$input_file")
    xred=$(awk '/^xred[[:space:]]*$/ {for(i=1;i<='"$natom"';i++) {getline; if (NF==3) print}}' "$input_file")
}

# Function to convert reduced coordinates to Cartesian coordinates
convert_xred_to_xcart() {
    xcart=$(awk -v rprim="$rprim" -v xred="$xred" -v natom="$natom" '
    BEGIN {
        split(rprim, r, /[[:space:]]+/)
        split(xred, x, /[[:space:]]+/)

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
}

# Function to update the input file with new xcart coordinates
update_input_file() {
    local input_file="$1"
    local temp_file=$(mktemp)

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

    mv "$temp_file" "$input_file"
}

# Main execution
check_args "$@"
input_file="$1"
extract_data "$input_file"
convert_xred_to_xcart
update_input_file "$input_file"

echo "Conversion from xred to xcart completed successfully."

