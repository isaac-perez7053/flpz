#!/bin/bash 
################################

# Extracts the eigenvectors and creates input files
# with a displaced unit cell

# Input: 
# 1.) A file with the eigen frequencies of a phonon
# representation. Listed from lowest to highest frequency.
# Consists of two columns, left in THz and right in cm^-1
# The top line will be deleted with this code. 
# 2.) A file with the eigen displacement vectors list from 
# associated lowest to highest frequency. 
# 3.) Input file of flpz program

# Output: 
# An input file for the datapoint calculation.  

################################


if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

######################################################
# Read input files and calculate constant quantities #
######################################################


## Read the command line arguments
dynFreqs_file="$1"
fceVecs_file="$2"
input_file="$3"

num_phon=$(grep "num_phon" "$input_file" | awk '{print $2}')
mode_location=$(grep -n "calc_phon" "$input_file" | cut -d: -f1)
begin_mode=$(( mode_location+1 ))
end_mode=$(( mode_location+num_phon ))
## Extract lines from begin_mode to end_mode and normalize in the process 
calc_phon=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

####################################
# Check which vectors are unstable #
####################################

sed '1d' "$dynFreqs_file" > "tmpfile.abi" && mv "tmpfile.abi" "$dynFreqs_file" 
# Check if the phonon is unstable and not acoustic
unstable_phonons=$(awk '
    {
        if ($1 ~ /-/ || $2 ~ /-/) {
            if ($2 < -20) {
                print NR
            }
        }
    }
' "$dynFreqs_file")
unstable_nlines=$(echo "$eigVec_lines" | wc -l )
unstable_nlines="${eigVec_nlines#"${eigVec_nlines%%[![:space:]]*}"}" 
echo "There are "$unstable_nlines" total unstable phonons" 

if [[ $num_phonon -gt $unstable_count ]]; then
        echo "Error: Requested phonon $phonon is out of range. Only $unstable_count unstable phonons found."
        exit 1
fi

# Check if requested phonons are within range and check that the users
# desired calculated phonons match with those found. If so, add them 
# to the list of to be calculated phonons 
eigVec_lines=""
for phonon in $unstable_phonons; do
   for desired_phonon in "$calc_phon"; do
      if [ $phonon = $desired_phonon ]; then
         if [[ -n $unstable_phonon ]]; then
            eigVec_lines+="$unstable_phonon "
         fi
      fi
done

eigVec_nlines=$(echo "$eigVec_lines" | wc -w)

echo "Extracting $eigVec_nlines unstable phonons: $eigVec_lines"

#####################################
# Create input files with eigenVecs #
#####################################

for files in $eigVec_lines
do
   # Copy input file and rename 
   cp "$input_file" "${input_file}_vec${files}"
   echo -e "vecNum ${files}" >> "${input_file}_vec${files}"

   # Take corresponding eigenvector and place in inputfile
   eigVec=$(sed -n "${files}p" "$fceVecs_file")
   echo "eigen_disp" >> "${input_file}_vec${files}"
   eigVec_arr=()

   #Input eigVec into array
   for eigVec in ${eigVec}
   do
      eigVec_arr+=("$eigVec")  
   done
   #Construct matrix line and input in file 
   for (( i=0; i<${#eigVec_arr[@]}; i+=3 ))
   do
      line="${eigVec_arr[i]} ${eigVec_arr[$(( i+1))]} ${eigVec_arr[$(( i+2))]}"
      echo "${line}" >> "${input_file}_vec${files}"  
   done 
done 

# For later inputs, place information into input file
echo "eigVec_nlines $eigVec_nlines" >> "$input_file"
echo -e "eigVec_lines\n${eigVec_lines}" >> "$input_file"
  
