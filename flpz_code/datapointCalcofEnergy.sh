#!/bin/bash
## Check if the correct number of arguments are provided
# Storing inputs from input file
################################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

## Read the command line arguments
input_file="$1"

## Root of all files input: searches for name in file and translates from upper to lowercase
structure=$(grep "name"  "$input_file" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

# File with the general (structural) information about the compound
general_structure_file="$(grep "genstruc" "$input_file" | awk '{print $2}')"

##fdf
nproc=$(grep "nproc" "$input_file" | awk '{print $2}')

##Grab vector iteration
vecNum=$(grep "vecNum" "$input_file" | awk '{print $2}')

##Number of datapoints including the max and min specified 
num_datapoints=$(grep "num_datapoints" "$input_file" | awk '{print $2}')
max=$(grep "max" "$input_file" | awk '{print $2}')
min=$(grep "min" "$input_file" | awk '{print $2}')

#Find step sizes 
step_size=$(echo "scale=10; ($max-$min)/$num_datapoints" | bc)

#Initalize a file that stores the xpoints
xpoints="xpoints${structure}_vec$vecNum.m"
echo "%x displacement vector magnitude" >> "$xpoints"
echo "x_vec = [" >> "$xpoints"

#Initialize the input file for data analysis
datasets_file="datasets_file${structure}_vec$vecNum.in"
echo "$num_datapoints" >> "$datasets_file"

#Initialize the input file that stores name of abo files
datasetsAbo_file="datasetsAbo_vec$vecNum.in"

## Define original xcart and eig_disp
## Extract matrix from file and normalize components
mode_location=$(grep -n "eigen_disp" "$input_file" | cut -d: -f1)
begin_mode=$(( mode_location+1 ))
end_mode=$(( mode_location+$(grep "natom" "$general_structure_file" | awk '{print $2}') ))
## Extract lines from begin_mode to end_mode and normalize in the process 
eig_disp=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

##############################################
# Calculation of normalized eigendisplacements
##############################################

# Initialize an empty array 
eigdisp_array=()

# Use a while loop to read each domain into the array
   for eig_component in ${eig_disp}
   do
      eigdisp_array+=("$eig_component")
   done

eig_squaresum=0
#NORMALIZATION of eigenvectors
   #Calculation of normalization factor
   for eig_component in "${eigdisp_array[@]}"
   do
      eig_squaresum=$(echo "scale=15; $eig_component^2 + $eig_squaresum" |bc)
   done
   normfact=$(echo "scale=15; sqrt($eig_squaresum)" | bc )
   #Divide all elements in the array by the normfact
   for eig_component in $(seq 0 $(( ${#eigdisp_array[@]} - 1 )))
   do
     eigdisp_array[eig_component]=$(echo "scale=15; ${eigdisp_array[$eig_component]}/$normfact" | bc)
   done

#Creation of PID array
pids=()

#####################################
# Creation of perturbation and files
#####################################

## Beginning of for loop that will create a file for each datapoint 
for iteration in $(seq 0 "$num_datapoints")
do
   ## Extract the cartesian coordinates of the crystal system
   xcart_location=$(grep -n "xcart" "$general_structure_file" | cut -d: -f1)
   xcart_start=$(( xcart_location+1 ))
   xcart_end=$(( xcart_location+$(grep "natom" "$general_structure_file" | awk '{print $2}') ))
   ## Extract lines from xcart_start to xcart_end
   xcart=$(sed -n "${xcart_start},${xcart_end}p" "$general_structure_file")

 ## Name the to-be-generated file
   filename="${structure}_${iteration}_vec$vecNum"
   filename_abi="${filename}.abi"


 ## Update datasets_file 
   echo "${structure}_${iteration}_vec${vecNum}.abo" >> "$datasetsAbo_file"
   
######################################
# Add the perturbation into the system
######################################

# Initializing a counter
count=0

# Intialize an empty array for new xcart
nxcart_array=()

   for component in ${xcart};
   do
      eig_dispcomp="${eigdisp_array[$count]}"
      cstep_size=$(echo "scale=15; ${step_size} * ${iteration}" | bc)
      perturbation=$(echo "scale=15; ${eig_dispcomp} * ${cstep_size}" | bc)
      nxcart_array+=("$(echo "scale=15; ${component} + ${perturbation}" | bc)")
      count=$(( count + 1 ))
   done

# Update xpoints
echo -e "$cstep_size\n" >> "$xpoints"



cat << EOF > "$filename_abi"
##################################################
# ${structure}: Flexoelectric Tensor Calculation #
##################################################

ndtset 1

# Ground State Self-Consistency
#******************************

getwfk1 0
kptopt1 1
tolvrs1 1.0d-18

# turn off various file outputs, here we will be interested only the
# DDB files  
   prtpot 0
   prteig 0

EOF

## Add general info about the structure
   cat "$general_structure_file" >> "$filename_abi"

## Replaces old xcart with the new xcart
#######################################
   xcart_location=$(grep -n "xcart" "$filename_abi" | cut -d: -f1)
   xcart_start=$(( xcart_location  ))
   xcart_end=$(( xcart_location+$(grep "natom" "$general_structure_file" | awk '{print $2}') ))
   sed "$xcart_start,${xcart_end}d" "$filename_abi" > "tmpfile.abi" && mv "tmpfile.abi" "$filename_abi"
   #Construct matrix line and input in file
   echo "xcart" >> "$filename_abi" 
   for (( i=0; i<${#nxcart_array[@]}; i+=3 ))
   do
      line="${nxcart_array[$i]} ${nxcart_array[$(( i+1))]} ${nxcart_array[$(( i+2))]}"
      echo "${line}" >> "$filename_abi"
   done

## Writes the batch script
##########################

   script="b-script-${structure}_${iteration}"

cat << EOF > "${script}"
#!/bin/bash
#SBATCH --job-name=abinit
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${nproc}
#SBATCH --cpus-per-task=1
##Change this to your allocation ID
#SBATCH --account=crl174
#SBATCH --mem=64G
#SBATCH --time=23:59:59
#SBATCH --output=output.log

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

#SET the number of openmp threads
export OMP_NUM_THREADS=24


mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np ${nproc} abinit ${filename_abi} >& ${filename}.log

EOF

#submit script and add to PIDS array
job_id=$(sbatch "${script}" | awk '{print $4}')
job_ids+=($job_id)
echo "Submitted batch job $job_id"
rm "${script}"

done


# Wait for all jobs to finish before data analysis
for job_id in "${job_ids[@]}"; do
    squeue -h -j "$job_id"
    while [ $? -eq 0 ]; do
        sleep 600  # Check every 10 minutes
        squeue -h -j "$job_id"
    done
    echo "Job $job_id completed"
done
echo "All Batch Scripts have Completed."
echo "Data Analysis Begins"

#Finish xpoints vector
echo -e "];\n" >> "$xpoints"

# Store abi and abo files
mkdir datapointAbiFiles
for iteration in $(seq 0 "$num_datapoints")
do
   mv ${structure}_${iteration}_vec${vecNum}.abi datapointAbiFiles
done 

# Submit results to data analysis
bash dataAnalysisEnergy.sh "${datasets_file}" "$xpoints" "$datasetsAbo_file" "$structure" "$vecNum"

echo "Data Analysis is Complete"

for iteration in $(seq 0 "$num_datapoints")
do
   mv ${structure}_${iteration}_vec${vecNum}.abo datapointAbiFiles
done

# Store DDB files
mkdir DDBs
for iteration in $(seq 0 "$num_datapoints")
do
   mv ${structure}_${iteration}_vec${vecNum}_DS4_DDB DDBs
   mv ${structure}_${iteration}_vec${vecNum}_DS5_DDB DDBs 
done

for iteration in $(seq 0 "$num_datapoints")
do
   rm ${structure}_${iteration}_vec*
done
