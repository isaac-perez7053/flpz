#!/bin/bash
##################################

# Finds the space group of a 
# crystal system using isotropy. 

# Input: An abi file 

# Output: The space group number. 

###################################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

###############################
# Store necessary information #
###############################

input_file="$1"
fsInput_file="findSymInput.in"
natom=$(grep "natom"  "$input_file" | awk '{print $2}')
rprim_location=$(grep -n "rprim" "$input_file" | cut -d: -f1)
## Turn rprim vectors into numpy vectors
rprim1=$(sed -n "$(( rprim_location + 1 ))p" "$input_file")
rprim2=$(sed -n "$(( rprim_location + 2 ))p" "$input_file")
rprim3=$(sed -n "$(( rprim_location + 3 ))p" "$input_file")

nrprim1="($(echo "$rprim1" | awk '{print $1}'), $(echo "$rprim1" | awk '{print $2}'), $(echo "$rprim1" | awk '{print $3}'))"
nrprim2="($(echo "$rprim2" | awk '{print $1}'), $(echo "$rprim2" | awk '{print $2}'), $(echo "$rprim2" | awk '{print $3}'))"
nrprim3="($(echo "$rprim3" | awk '{print $1}'), $(echo "$rprim3" | awk '{print $2}'), $(echo "$rprim3" | awk '{print $3}'))"


############################
# acell lattice parameters #
############################
# Function to expand shorthand notation
expand_notation() {
    input="$1"
    count="${input%%\**}"
    value="${input#*\*}"
    if [[ "$input" == *"*"* ]]; then
        printf "$value %.0s" $(seq 1 $count)
    else
        echo "$input"
    fi
}

# Read the line containing 'acell' from the input file
acell_line=$(grep "^acell" "$input_file")

# Extract parameters
params=($(echo "$acell_line" | awk '{for(i=2;i<=NF;i++) print $i}'))

# Expand and assign variables
expanded_params=()
for param in "${params[@]}"; do
    expanded=$(expand_notation "$param")
    expanded_params+=($expanded)
done
# Assign to variables
a="${expanded_params[0]}"
b="${expanded_params[1]}"
c="${expanded_params[2]}"

#Extract xcart or xred depending on which is used. 
if grep -q "^[[:space:]]*xred" "$input_file"; then
   xred_location=$(grep -n "xred" "$input_file" | cut -d: -f1)
   xred_start=$(( xred_location+1  ))
   xred_end=$(( xred_location+natom ))
   xred=$(sed -n "${xred_start},${xred_end}p" "$input_file")
fi

if grep -q "^[[:space:]]*xcart" "$input_file"; then
   xcart_location=$(grep -n "xcart" "$input_file" | cut -d: -f1)
   xcart_start=$(( xcart_location+1  ))
   xcart_end=$(( xcart_location+natom ))
   xcart=$(sed -n "${xcart_start},${xcart_end}p" "$input_file")
fi

# Extract ntypat 
typat_unexp=($(grep "^typat"  "$input_file"| awk '{for(i=2;i<=NF;i++) print $i}'))
expanded_typat=()
for typat_one in "${typat_unexp[@]}"; do
    expanded=$(expand_notation "$typat_one")
    expanded_typat+=($expanded)
done


###################################
# Calculate necessary information #
###################################

alpha=$(./findAngle.py "$nrprim2" "$nrprim3")
beta=$(./findAngle.py "$nrprim1" "$nrprim3")
gamma=$(./findAngle.py "$nrprim1" "$nrprim2")

##############################
# Creates FINDSYM input file # 
##############################

echo "!useKeyWords" >> "$fsInput_file"
echo "!latticeParameters" >> "$fsInput_file"
echo "$a, $b, $c, $alpha, $beta, $gamma" >> "$fsInput_file"
echo "!atomCount" >> "$fsInput_file"
echo "$natom" >> "$fsInput_file"
echo "!atomType" >> "$fsInput_file"
echo "${expanded_typat[@]}" >> "$fsInput_file"
echo "!atomPosition" >> "$fsInput_file"
echo "$xred" "$xcart" >> "$fsInput_file"

findsym "$fsInput_file" | grep "_symmetry_Int_Tables_number" | awk '{print $2}'
rm "$fsInput_file"
