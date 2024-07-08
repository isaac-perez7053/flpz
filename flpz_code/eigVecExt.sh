#!/bin/bash 
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

####################################
# Check which vectors are unstable #
####################################

sed '1d' "$dynFreqs_file" > "tmpfile.abi" && mv "tmpfile.abi" "$dynFreqs_file" 
# Check if the phonon is unstable and not acoustic
eigVec_lines=$(awk '
    {
        if ($1 ~ /-/ || $2 ~ /-/) {
            if ($2 < -20) {
                print NR
            }
        }
    }
' "$dynFreqs_file")
eigVec_nlines=$(echo "$eigVec_lines" | wc -l )
eigVec_nlines="${eigVec_nlines#"${eigVec_nlines%%[![:space:]]*}"}" 
echo "There are "$eigVec_nlines" unstable phonons" 

#####################################
# Create input files with eigenVecs #
#####################################

for files in $eigVec_lines
do
   cp "../$input_file" "${input_file}_vec${files}"
   echo -e "vecNum ${files}" >> "${input_file}_vec${files}"
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

echo "eigVec_nlines $eigVec_nlines" >> "../$input_file"
echo -e "eigVec_lines\n${eigVec_lines}" >> "../$input_file"
  
