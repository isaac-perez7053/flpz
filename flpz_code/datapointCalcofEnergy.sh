#!/bin/bash
# Calculates the total energy of the perturbed system for the flpz program
# Usage: ./datapointCalcofEnergy.sh <input_file>

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
    phonon_coupling=$(grep "phonon_coupling" "$input_file" | awk '{print $2}')

    # Reads certain arguments depending on whether the user specified a phonon coupling calculation.
    if [ "$phonon_coupling" = 1 ]; then
        dataset_1=$(grep "dataset_1" "$input_file" | awk '{print $2}')
        dataset_2=$(grep "dataset_2" "$input_file" | awk '{print $2}')
        grid_dimX=$(grep "grid_dim" "$input_file" |awk '{print $2}')
        grid_dimY=$(grep "grid_dim" "$input_file" |awk '{print $3}')
        xmin=$(grep "grid_range" "$input_file" | awk '{print $2}')
        xmax=$(grep "grid_range" "$input_file" | awk '{print $3}')
        ymin=$(grep "grid_range" "$input_file" | awk '{print $4}')
        ymax=$(grep "grid_range" "$input_file" | awk '{pring $5}')
    else
        num_datapoints=$(grep "num_datapoints" "$input_file" | awk '{print $2}')
        max=$(grep "max" "$input_file" | awk '{print $2}')
        min=$(grep "min" "$input_file" | awk '{print $2}')
    fi
}

# Function to calculate step size
calc_step_size() {
    if [ "$phonon_coupling" = 1 ]; then
            step_sizeX=("scale=10; ($xmax-$xmin)/$grid_dimX" |bc)
            step_sizeY=("scale=10; ($ymax-$ymin)/$grid_dimY" |bc)
    else
            step_size=("scale=10; ($max-$min)/$num_datapoints" | bc)
    fi
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
    local eig_dispNum="$2"
    local mode_location=$(grep -n "eigen_disp${eig_dispNum}" "$input_file" | cut -d: -f1)
    local begin_mode=$((mode_location + 1))
    local end_mode=$((begin_mode + $(grep "natom" "$general_structure_file" | awk '{print $2}') - 1))
    
    eig_disp=$(sed -n "${begin_mode},${end_mode}p" "$input_file")
    eigdisp_array${eig_dispNum}=($eig_disp)
    
    local eig_squaresum=0
    for eig_component in "${eigdisp_array${eigen_dispNum}[@]}"; do 
        eig_squaresum=$(echo "scale=15; $eig_component^2 + $eig_squaresum" | bc)
    done
    local normfact=$(echo "scale=15; sqrt($eig_squaresum)" | bc)
    
    for i in "${!eigdisp_array${eig_dispNum}[@]}"; do
        eigdisp_array${eig_dispNum}[i]=$(echo "scale=15; ${eigdisp_array${eig_dispNum}[i]}/$normfact" | bc)
    done
}

# Function to create perturbed system files
create_perturbed_files() {
    local iteration="$1"
    local filename="${structure}_${iteration}_vec$vecNum"
    local filename_abi="${filename}.abi"
    
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

# Function to create perturbed system files
create_perturbedcoupled_files() {
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
        local eig_dispcompX="${eigdisp_array[$count]}"
	    local eig_dispcompY="${eigdisp_array2[$count]}"
        local step_sizeX=$(echo "scale=15; ${step_sizeX} * ${iterationX}" | bc)
	    local step_sizeY=$(echo "scale=15; ${step_sizeY} * ${iterationY}" | bc)
        local perturbationX=$(echo "scale=15; ${eig_dispcompX} * ${step_sizeX}" | bc)
	    local perturbationY=$(echo "scale=15; ${eig_dispcompY} * ${step_sizeY}" | bc)
        nxcart_array+=("$(echo "scale=15; ${component} + ${perturbationX} + ${perturbationY}" | bc)")
        count=$((count + 1))
    done

    echo "$step_sizeX $step_sizeY" >> "$xpoints"

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

ndtset 1

# Ground State Self-Consistency
#******************************

getwfk1 0
kptopt1 1
tolvrs1 1.0d-18

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

    # Print the space group of the perturbed cell
    if [ "$phonon_coupling" = 1]; then
        echo "The space group of cell ${iteration} is $(bash findSpaceGroup.sh $filename_abi)"
    else 
        echo "The space group of cell ${iterationX}, ${iterationY} is $(bash findSpaceGroup.sh $filename_abi)"
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
calc_step_size
init_output_files
extract_normalize_eigdisp "$1" "1"
job_ids=()
# Create perturbed files
if [ "$phonon_coupling" = 1 ]; then
    extract_normalize_eigdisp "$1" "2"
    for iterationX in $(seq 1 $grid_dimX); do 
        for iterationY in $(seq 1 $grid_dimY); do
		create_perturbedcoupled_files "$iterationX" "$iterationY"
	done
    done
else	
    for iteration in $(seq 0 "$num_datapoints"); do
        create_perturbed_files "$iteration"
    done
fi

wait_for_jobs

echo "Data Analysis Begins"
echo "];" >> "$xpoints"

# Organize files
mkdir -p datapointAbiFiles_vec${vecNum}
mv ${structure}_*_vec${vecNum}.abi datapointAbiFiles_vec${vecNum}/
bash dataAnalysisEnergy.sh "${datasets_file}" "$xpoints" "$datasetsAbo_file" "$structure" "$vecNum"
echo "Data Analysis is Complete"

mv ${structure}_*_vec${vecNum}.abo datapointAbiFiles_vec${vecNum}/

echo "Total energy calculation for perturbed system completed successfully."

