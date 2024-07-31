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

# Function to expand shorthand notation
expand_notation() {
    local input="$1"
    local count="${input%%\**}"
    local value="${input#*\*}"
    if [[ "$input" == *"*"* ]]; then
        printf "$value %.0s" $(seq 1 "$count")
    else
        echo "$input"
    fi
}

# Function to extract data from input file
extract_data() {
    local input_file="$1"
    natom=$(grep "natom" "$input_file" | awk '{print $2}')

    rprim=$(awk '/^rprim/{flag=1; next} flag{print; if (NF==0 || ++count==3) exit}' "$input_file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')

    if [ -z "$rprim" ]; then
        rprim="1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0"
        echo "rprim not found in input file. Using default values:"
    fi

    acell=$(grep "acell" "$input_file" | tr -d '\n')
    xred=$(awk '/^xred/{flag=1; next} flag && NF==3{print; if (++count=='"$natom"') exit}' "$input_file" | tr '\n' ' ' | sed 's/ $//')
    xcart=$(awk '/^xcart/{flag=1; next} flag && NF==3{print; if (++count=='"$natom"') exit}' "$input_file" | tr '\n' ' ' | sed 's/ $//')

    if [ -n "$xred" ]; then 
        echo "File is already expressed in reduced coordinates"
        exit 1
    fi 

    # Extract and expand acell parameters
    acell_params="($(grep "^acell" "$input_file" | awk '{for(i=2;i<=NF;i++) print $i}'))"
    expanded_params=()
    for param in "${acell_params[@]}"; do
        expanded=$(expand_notation "$param")
        expanded_params+=("$expanded")
    done
    a="${expanded_params[0]}"
    b="${expanded_params[1]}"
    c="${expanded_params[2]}"
}

calculate_xcart() {
    python3 ./xCartxRed.py "$@" | tr '\n' ' ' | sed 's/ $//'
}

# Function to update the input file with new xcart coordinates
update_input_file() {
    local input_file="$1"
    local new_coords="$2"
    local coord_type="$3"
    temp_file=$(mktemp)

    # Remove existing acell, rprim, xcart, and xred entries
    sed -e '/^acell/d' \
        -e '/^rprim/,+3d' \
        -e '/^xcart/,+'"$natom"'d' \
        -e '/^xred/,+'"$natom"'d' \
        "$input_file" > "$temp_file"

    # Insert new values
    awk -v acell="$acell" -v rprim="$rprim" -v coords="$new_coords" -v coord_type="$coord_type" -v natom="$natom" '
    BEGIN {
        split(coords, c, /[[:space:]]+/)
        split(rprim, r)
        values_printed = 0
    }
    /^#/ && !values_printed {
        print
        print acell
        print "rprim"
        print r[1], r[2], r[3]
        print r[4], r[5], r[6]
        print r[7], r[8], r[9]
        print coord_type
        for (i=1; i<=natom*3; i+=3) {
            print c[i], c[i+1], c[i+2]
        }
        values_printed = 1
        next
    }
    {print}
    ' "$temp_file" > "${input_file}.new"

    if [ -s "${input_file}.new" ]; then
        mv "${input_file}.new" "$input_file"
        echo "Input file updated successfully."
    else
        echo "Error: New file is empty. Original file not modified."
        cat "${input_file}.new"  # Print content of new file for debugging
        rm "${input_file}.new"
        exit 1
    fi

    rm "$temp_file"
}


# Main execution
check_args "$@"
input_file="$1"
extract_data "$input_file"
xred=$(calculate_xcart "xred" "$rprim" "$xcart" "$a" "$b" "$c" "$natom")
update_input_file "$input_file" "$xred" "xred"
