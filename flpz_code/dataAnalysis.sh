#!/bin/bash
##############################

# Takes output of datapoint calculations and 
# automatically runs anaddb and stores output of
# anaddb into final matlab file for plotting

# Input: 
# 1.) An output file from the datapoint calculation
# listing all derivative database names. 
# 2.) An output file from the datapoint calculation 
# that is a matlab vector containing all calculated x points
# 3.) An output file form the datapoint calculation containing
# list of all abo file names for total energy vector. 
# 4.) Name of structure as listed in the input file
# 5.) The associated vector number of the calculation  

# Output: 
# 1.) A matlab file containing vectors of the flexoelectric,
# piezoelectric, x points, and total energy of calculation. 

##############################
#SBATCH --job-name="abinit"
#SBATCH --output="abinit.%j.%N.out"
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=120G
#SBATCH --account=crl174
#SBATCH --export=ALL
#SBATCH -t 23:59:59

module purge
module load slurm
module load cpu/0.17.3b
module load gcc/10.2.0
module load openmpi/4.1.3
module load wannier90/3.1.0
module load netcdf-fortran/4.5.3
module load libxc/5.1.5
module load fftw/3.3.10
module load netlib-scalapack/2.1.0
export PATH=/expanse/projects/qstore/use300/jpg/abinit-10.0.5/bin:$PATH

## Check if the correct number of arguments are provided
# Storing inputs from input file
################################

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

## Read the command line arguments
input_fileAn="$1"
xpoints="$2"
inputAbo_files="$3"
structure="$4"
vecNum="$5"

# Creation of output file
output_file="Datasets_vec${vecNum}.m"

# Creation of totenergy vector file
outputEn_file="totEnergy_vec${vecNum}.m"
echo "totEnergy_vec = [" >> "$outputEn_file"

num_datapoints=$(sed -n '1p' "$input_fileAn")

######################
## Create anaddb files
######################

# Write anaddb file for flexoelectric tensor
anaddbF="flexoanaddb.abi"
cat << EOF > "${anaddbF}"
! anaddb calculation of flexoelectric tensor

flexoflag 1

EOF

# Write anaddb file for piezoelectric tensor
anaddbP="piezoanaddb.abi"
cat <<EOF > "${anaddbP}"
! Input file for the anaddb code

elaflag 3  ! flag for the elastic constant
piezoflag 3 !the flag for the piezoelectric constant
instrflag 1 ! the flag for the internal strain tensor

EOF
# Store dataset file names and process files
for dataset in $(seq 1 $(( num_datapoints + 1 )))
do  
	#Find dataset filename
        dataset_locP=$(( dataset * 2 ))
        dataset_locF=$(( dataset_locP + 1 ))
	dataset_fileP=$(sed -n "${dataset_locP}p" "$input_fileAn")
        dataset_fileF=$(sed -n "${dataset_locF}p" "$input_fileAn")   

        #Search for totenergy and store
	echo "$(grep "etotal1" "$(sed -n "${dataset}p" "$inputAbo_files")" |awk '{print $2}')" >> "$outputEn_file"

################################
## Creation of the file of files 
################################
anaddbfilesF="anaddbF_${dataset}.files"
anaddbfilesP="anaddbP_${dataset}.files"

# Create anaddb file of files for flexoelectricity
cat << EOF > "${anaddbfilesF}"
${anaddbF}
flexoElec_${dataset}
${dataset_fileF}
dummy1
dummy2
dummy3	

EOF

# Create anaddb file of files for piezoelectricty 
cat << EOF > "${anaddbfilesP}"
${anaddbP}
piezoElec_${dataset}
${dataset_fileP}
dummy1
dummy2
dummy3

EOF

# Run Anaddb Files
mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 1 anaddb < ${anaddbfilesF} >& ${anaddbfilesF}.log
mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 1 anaddb < ${anaddbfilesP} >& ${anaddbfilesP}.log

done

# After mpiruns are finixed, search for tensors and store in final output file
for dataset in $(seq 1 $(( num_datapoints + 1 )))
do

   # Store flexoelectric tensor into output file
   echo -e "%Flexoelectric Tensor: Dataset ${dataset}\n" >> "$output_file"
   flexoTen="mu${dataset} = [$(grep -A11 'TOTAL' "flexoElec_${dataset}" | grep -o '[-]\?[0-9]*\.*[0-9]\+')];"
   echo "${flexoTen}" >> "$output_file"
   echo -e "\n\n\n" >> $output_file
   echo -e "%Piezoelectric Tensor: Dataset ${dataset}\n" >> "${output_file}"

   # Store piezoelectric tensor into output file
   piezoTen="chi${dataset} = [$(grep -A7 'Proper piezoelectric constants (relaxed ion)' "piezoElec_${dataset}" | grep -o '[-]\?[0-9]*\.*[0-9]\+' | tail -n +2)];"
   echo "${piezoTen}" >> $output_file
   echo -e "\n\n\n" >> $output_file

   # Delete files that have no use
   rm "flexoElec_${dataset}" "piezoElec_${dataset}"
done

# Combines the x_vec with the flexoElectricity matricies
echo "];" >> "$outputEn_file"
cat "$xpoints" >> "$output_file"
cat "$outputEn_file" >> "$output_file"

# Delete any extraneous files 
echo "Cleaning Up Some Files for You"
rm "${anaddbfilesF}" "${anaddbfilesP}" "${anaddbP}" "${anaddbF}"
rm anaddb*
rm _anaddb.nc 
#rm $inputAbo_files
rm $outputEn_file
#rm $input_fileAn
#rm $xpoints

rm "fort.7"
rm "output.log"


