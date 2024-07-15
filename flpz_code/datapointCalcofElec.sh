#!/bin/bash
# Flexoelectricity and Piezoelectricity Calculation for Perturbed Systems
# Usage: ./datapointCalcofElec.sh <input_file>

# Function to check correct number of arguments
check_args() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 <input_file>"
        exit 1
    fi
}

# Function to read input parameters
read_input_params() {
    local input_file="$1"
    structure=$(grep "name" "$input_file" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    general_structure_file=$(grep "genstruc" "$input_file" | awk '{print $2}')
    nproc=$(grep "nproc" "$input_file" | awk '{print $2}')
    vecNum=$(grep "vecNum" "$input_file" | awk '{print $2}')
    num_datapoints=$(grep "num_datapoints" "$input_file" | awk '{print $2}')
    max=$(grep "max" "$input_file" | awk '{print $2}')
    min=$(grep "min" "$input_file" | awk '{print $2}')
}

# Function to calculate step size
calc_step_size() {
    echo "scale=10; ($max-$min)/$num_datapoints" | bc
}

# Function to initialize output files
init_output_files() {
    xpoints="xpoints${structure}_vec$vecNum.m"
    datasets_file="datasets_file${structure}_vec$vecNum.in"
    datasetsAbo_file="datasetsAbo_vec$vecNum.in"

    echo "%x displacement vector magnitude" > "$xpoints"
    echo "x_vec = [" >> "$xpoints"
    echo "$num_datapoints" > "$datasets_file"
    : > "$datasetsAbo_file"
}

# Function to extract and normalize eigenvector displacements
extract_normalize_eigdisp() {
    local input_file="$1"
    local mode_location=$(grep -n "eigen_disp" "$input_file" | cut -d: -f1)
    local begin_mode=$((mode_location + 1))
    local end_mode=$((begin_mode + $(grep "natom" "$general_structure_file" | awk '{print $2}') - 1))
    
    eig_disp=$(sed -n "${begin_mode},${end_mode}p" "$input_file")
    eigdisp_array=($eig_disp)
    
    local eig_squaresum=0
    for eig_component in "${eigdisp_array[@]}"; do
        eig_squaresum=$(echo "scale=15; $eig_component^2 + $eig_squaresum" | bc)
    done
    local normfact=$(echo "scale=15; sqrt($eig_squaresum)" | bc)
    
    for i in "${!eigdisp_array[@]}"; do
        eigdisp_array[i]=$(echo "scale=15; ${eigdisp_array[i]}/$normfact" | bc)
    done
}

# Function to create perturbed system files
create_perturbed_files() {
    local iteration="$1"
    local filename="${structure}_${iteration}_vec$vecNum"
    local filename_abi="${filename}.abi"
    
    echo "${structure}_${iteration}_vec${vecNum}o_DS4_DDB" >> "$datasets_file"
    echo "${structure}_${iteration}_vec${vecNum}o_DS5_DDB" >> "$datasets_file"
    echo "${filename}.abo" >> "$datasetsAbo_file"
    
    # Extract and perturb cartesian coordinates
    local xcart_location=$(grep -n "xcart" "$general_structure_file" | cut -d: -f1)
    local xcart_start=$((xcart_location + 1))
    local xcart_end=$((xcart_start + $(grep "natom" "$general_structure_file" | awk '{print $2}') - 1))
    local xcart=$(sed -n "${xcart_start},${xcart_end}p" "$general_structure_file")
    
    local count=0
    local nxcart_array=()
    for component in $xcart; do
        local eig_dispcomp="${eigdisp_array[$count]}"
        local cstep_size=$(echo "scale=15; ${step_size} * ${iteration}" | bc)
        local perturbation=$(echo "scale=15; ${eig_dispcomp} * ${cstep_size}" | bc)
        nxcart_array+=("$(echo "scale=15; ${component} + ${perturbation}" | bc)")
        count=$((count + 1))
    done
    
    echo "$cstep_size" >> "$xpoints"
    
    # Create ABINIT input file
    create_abinit_input "$filename_abi" "${nxcart_array[@]}"
    
    # Create and submit batch script
    create_batch_script "$filename" "$filename_abi"
}

# Function to create ABINIT input file
create_abinit_input() {
    local filename_abi="$1"
    shift
    local nxcart_array=("$@")
    
    cat << EOF > "$filename_abi"
##################################################
# ${structure}: Flexoelectric Tensor Calculation #
##################################################

ndtset 5

# Set 1: Ground State Self-Consistency
#*************************************

getwfk1 0
kptopt1 1
tolvrs1 1.0d-18

# Set 2: Reponse function calculation of d/dk wave function
#**********************************************************

iscf2 -3
rfelfd2 2
tolwfr2 1.0d-20

# Set 3: Response function calculation of d2/dkdk wavefunction
#*************************************************************

getddk3 2
iscf3 -3
rf2_dkdk3 3
tolwfr3 1.0d-16
rf2_pert1_dir3 1 1 1
rf2_pert2_dir3 1 1 1

# Set 4: Response function calculation to q=0 phonons, electric field and strain
#*******************************************************************************
getddk4 2
rfelfd4 3
rfphon4 1
rfstrs4 3
rfstrs_ref4 1
tolvrs4 1.0d-8
prepalw4 1

# Set 5: Long-wave Calculations
#******************************

optdriver5 10
get1wf5 4
get1den5 4
getddk5 2
getdkdk5 3
lw_flexo5 1

# turn off various file outputs
prtpot 0
prteig 0

EOF

    # Add general info about the structure
    cat "$general_structure_file" >> "$filename_abi"

    # Replace xcart with new perturbed coordinates
    local xcart_location=$(grep -n "xcart" "$filename_abi" | cut -d: -f1)
    local xcart_start=$xcart_location
    local xcart_end=$((xcart_start + $(grep "natom" "$general_structure_file" | awk '{print $2}')))
    sed -i "${xcart_start},${xcart_end}d" "$filename_abi"
    echo "xcart" >> "$filename_abi"
    for ((i=0; i<${#nxcart_array[@]}; i+=3)); do
        echo "${nxcart_array[i]} ${nxcart_array[i+1]} ${nxcart_array[i+2]}" >> "$filename_abi"
    done


    # If this is the first perturbation, print the space group
    if [[ $iteration -eq 1 ]]; then 
        echo "The space group of the perturbed cell is $(bash findSpaceGroup.sh $filename_abi)"
    fi 
}

# Function to create and submit batch script
create_batch_script() {
    local filename="$1"
    local filename_abi="$2"
    local script="b-script-${filename}"
    
    cat << EOF > "${script}"
#!/bin/bash
#SBATCH --job-name=abinit
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${nproc}
#SBATCH --cpus-per-task=1
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

export OMP_NUM_THREADS=24

mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np ${nproc} abinit ${filename_abi} >& ${filename}.log
EOF

    local job_id=$(sbatch "${script}" | awk '{print $4}')
    job_ids+=($job_id)
    echo "Submitted batch job $job_id"
    rm "${script}"
}

# Function to wait for all jobs to complete
wait_for_jobs() {
    for job_id in "${job_ids[@]}"; do
        while squeue -h -j "$job_id" &>/dev/null; do
            sleep 600  # Check every 10 minutes
        done
        echo "Job $job_id completed"
    done
    echo "All Batch Scripts have Completed."
}

# Main execution
check_args "$@"
read_input_params "$1"
step_size=$(calc_step_size)
init_output_files
extract_normalize_eigdisp "$1"

job_ids=()
for iteration in $(seq 0 "$num_datapoints"); do
    create_perturbed_files "$iteration"
done

wait_for_jobs

echo "Data Analysis Begins"
echo "];" >> "$xpoints"

# Organize files
mkdir -p datapointAbiFiles DDBs
mv ${structure}_*_vec${vecNum}.abi datapointAbiFiles/
bash dataAnalysis.sh "${datasets_file}" "$xpoints" "$datasetsAbo_file" "$structure" "$vecNum"
echo "Data Analysis is Complete"

mv ${structure}_*_vec${vecNum}.abo datapointAbiFiles/
mv ${structure}_*_vec${vecNum}_DS4_DDB ${structure}_*_vec${vecNum}_DS5_DDB DDBs/
rm ${structure}_*_vec*

echo "Flexoelectricity and Piezoelectricity calculation completed successfully."
