#!/bin/bash
# Flexoelectricity and Piezoelectricity Calculation for Perturbed Systems
# Usage: ./datapointCalcofElec.sh <input_file>

# Python-based calculation function. Eliminates the need to install bc
calculate() {
    python3 - <<END
from decimal import Decimal, getcontext
import math

def decimal_sqrt(x):
    return Decimal(x).sqrt()

getcontext().prec = 10  # Set precision to 10 digits total
x = '$1'
# Replace math functions with Decimal-compatible versions
x = x.replace('sqrt', 'decimal_sqrt')
x = x.replace('^', '**')  # Replace ^ with ** for exponentiation
for func in ['sin', 'cos', 'tan', 'exp', 'log']:
    x = x.replace(func, f'Decimal({func})')
x = x.replace('pi', str(Decimal(math.pi)))
result = eval(x, {'Decimal': Decimal, 'decimal_sqrt': decimal_sqrt}, {})
print(f'{result:.10g}')
END
}

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
    natom=$(grep "natom" "$general_structure_file" | awk '{print $2}')
    vecNum=$(grep "vecNum" "$input_file" | awk '{print $2}')
    bScriptPreamble=$(grep "sbatch_preamble" "$input_file" | awk '{print $2}')
    phonon_coupling=$(grep "phonon_coupling" "$input_file" | awk '{print $2}')

    # Reads certain arguments depending on whether the user specified a phonon coupling calculation.
    if [ "$phonon_coupling" = 1 ]; then
        grid_dimX=$(grep "grid_dim" "$input_file" | awk '{print $2}')
        grid_dimY=$(grep "grid_dim" "$input_file" | awk '{print $3}')
        xmin=$(grep "grid_range" "$input_file" | awk '{print $2}')
        xmax=$(grep "grid_range" "$input_file" | awk '{print $3}')
        ymin=$(grep "grid_range" "$input_file" | awk '{print $4}')
        ymax=$(grep "grid_range" "$input_file" | awk '{print $5}')
    else
        num_datapoints=$(grep "num_datapoints" "$input_file" | awk '{print $2}')
        max=$(grep "max" "$input_file" | awk '{print $2}')
        min=$(grep "min" "$input_file" | awk '{print $2}')
    fi
}

# Function to calculate step size
calc_step_size() {
    echo "xmax: $xmax"
    echo "xmin: $xmin"
    echo "ymax: $ymax"
    echo "ymin: $ymin"
    echo "grid_dimX: $grid_dimX"
    echo "grid_dimY: $grid_dimY"
    if [ "$phonon_coupling" = 1 ]; then
        step_sizeX=$(calculate "($xmax-$xmin)/$grid_dimX")
        step_sizeY=$(calculate "($ymax-$ymin)/$grid_dimY")
        echo "Step Size X: $step_sizeX"
        echo "Step Size Y: $step_sizeY"
    else
        step_size=$(calculate "($max-$min)/$num_datapoints")
        echo "Step Size: $step_size"
    fi
}

# Function to initialize output files
init_output_files() {
    xpoints="xpoints${structure}_vec$vecNum.m"
    datasets_file="datasets_file${structure}_vec$vecNum.in"
    datasetsAbo_file="datasetsAbo_vec$vecNum.in"

    echo "%x displacement vector magnitude" >"$xpoints"
    echo "x_vec = [" >>"$xpoints"
    echo "$num_datapoints" >"$datasets_file"

    if [ "$phonon_coupling" = 1 ]; then
        "$(calculate "$grid_dimX*$grid_dimY")" >"$datasets_file"
    else
        echo "$num_datapoints" >"$datasets_file"
    fi
    : >"$datasetsAbo_file"

    echo "Output files initialized:"
    echo "xpoints: $xpoints"
    echo "datasets_file: $datasets_file"
    echo "datasetsAbo_file: $datasetsAbo_file"
}

# Function to extract and normalize eigenvector displacements 
extract_normalize_eigdisp1() {
    local input_file="$1"

    # Extraction of the eigen displacement in the input file. 
    mode_location=$(grep -in "eigen_disp1" "$input_file" | cut -d: -f1)

    if [ -z "$mode_location" ]; then
        echo "Error: Could not find eigen_disp1 in $input_file"
        exit 1
    fi

    local begin_mode=$((mode_location + 1))
    local end_mode=$((begin_mode + natom - 1))

    eig_disp1=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

    if [ -z "$eig_disp1" ]; then
        echo "Error: Could not extract eigenvector data"
        exit 1
    fi

    # Declare an array that will hold the eigen displacement
    declare -ag "eigdisp_array1"

    # Read all components into the array
    while read -r line; do
        read -ra temp_array <<<"$line"
        eigdisp_array+=("${temp_array[@]}")
    done <<<"$eig_disp1"

    # Calculate the normalized eigen displacement
    local eig_squaresum=0
    for eig_component in "${eigdisp_array[@]}"; do
        eig_squaresum=$(calculate "$eig_component**2 + $eig_squaresum")
    done
    normfact=$(calculate "sqrt($eig_squaresum)")

    local normalized_array=()
    for i in "${!eigdisp_array[@]}"; do
        normalized_value=$(calculate "${eigdisp_array[i]}/$normfact")
        normalized_array+=("$normalized_value")
    done

    # Assign the normalized array back to eigdisp_array
    eigdisp_array1=("${normalized_array[@]}")
}

# Function to extract and normalize the second eigen displacement
extract_normalize_eigdisp2() {
    local input_file="$1"

    # Locate the eigen displacament in the input file. 
    mode_location=$(grep -in "eigen_disp2" "$input_file" | cut -d: -f1)

    if [ -z "$mode_location" ]; then
        echo "Error: Could not find eigen_disp2 in $input_file"
        exit 1
    fi

    local begin_mode=$((mode_location + 1))
    local end_mode=$((begin_mode + natom - 1))

    eig_disp2=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

    if [ -z "$eig_disp2" ]; then
        echo "Error: Could not extract eigenvector data"
        exit 1
    fi

    # Declare an array that will hold the second eigen displacement
    declare -ag "eigdisp_array2"

    # Read all components into the array
    while read -r line; do
        read -ra temp_array <<<"$line"
        eigdisp_array2+=("${temp_array[@]}")
    done <<<"$eig_disp2"

    # Normalize the vector
    local eig_squaresum=0
    for eig_component in "${eigdisp_array2[@]}"; do
        eig_squaresum=$(calculate "$eig_component**2 + $eig_squaresum")
    done
    normfact=$(calculate "sqrt($eig_squaresum)")

    local normalized_array=()
    for i in "${!eigdisp_array2[@]}"; do
        normalized_value=$(calculate "${eigdisp_array2[i]}/$normfact")
        normalized_array+=("$normalized_value")
    done

    # Assign the normalized array back to eigdisp_array
    eigdisp_array2=("${normalized_array[@]}")
}

# Function to create perturbed system files
create_perturbed_files() {
    
    # Read inputs and initialize filenames
    local iteration="$1"
    local filename="${structure}_${iteration}_vec$vecNum"
    local filename_abi="${filename}.abi"

    # Store the file names of the databases and .abo files into another file
    echo "${structure}_${iteration}_vec${vecNum}o_DS4_DDB" >>"$datasets_file"
    echo "${structure}_${iteration}_vec${vecNum}o_DS5_DDB" >>"$datasets_file"
    echo "${filename}.abo" >>"$datasetsAbo_file"

    # Extract and perturb cartesian coordinates
    # Find the location of the cartesian coordinates. 
    xcart_location=$(grep -n "xcart" "$general_structure_file" | cut -d: -f1)
    if [ -z "$xcart_location" ]; then
        echo "Error: Could not find 'xcart' in $general_structure_file"
        exit 1
    fi

    local xcart_start=$((xcart_location + 1))
    local xcart_end=$((xcart_start + natom - 1))
    xcart=$(sed -n "${xcart_start},${xcart_end}p" "$general_structure_file")

    if [ -z "$xcart" ]; then
        echo "Error: Failed to extract xcart coordinates from $general_structure_file"
        exit 1
    fi

    local count=0
    local nxcart_array=()
    local displacement_vector=()

    # Calculate the scalar used to multiple the eigen-displacement for the file
    cstep_size=$(calculate "${step_size} * ${iteration}")
    for component in $xcart; do
        local eig_dispcomp="${eigdisp_array1[$count]}"
        
        # Perturb the coordiantes and store displacement vector 
        perturbation=$(calculate "${eig_dispcomp} * ${cstep_size}")
        nxcart_array+=("$(calculate "${perturbation}+${component}")")
        displacement_vector+=("$perturbation")
        count=$((count + 1))
    done

    echo "$cstep_size" >>"$xpoints"
    echo ""

    # Echo displacement vector
    echo "Displacement vector for ${filename}:"
    for ((i = 0; i < ${#displacement_vector[@]}; i += 3)); do
        echo "${displacement_vector[i]} ${displacement_vector[i + 1]} ${displacement_vector[i + 2]}"
    done
    echo ""
    # Echo new cartesian coordinates
    echo "New cartesian coordinates for ${filename}:"
    for ((i = 0; i < ${#nxcart_array[@]}; i += 3)); do
        echo "${nxcart_array[i]} ${nxcart_array[i + 1]} ${nxcart_array[i + 2]}"
    done
    echo ""
    # Create ABINIT input file
    create_abinit_input "$filename_abi" "${nxcart_array[@]}"

    # Create and submit batch script
    create_batch_script "$filename" "$filename_abi"
}

# Function to create perturbed system files
create_perturbedcoupled_files() {

    # Read inputs and initialize files
    local iterationX="$1"
    local iterationY="$2"
    local filename="${structure}_${iterationX}_${iterationY}_vec$vecNum"
    local filename_abi="${filename}.abi"

    # Store DDB and .abo file names into separate files
    echo "${structure}_${iterationX}_${iterationY}_vec${vecNum}o_DS4_DDB" >>"$datasets_file"
    echo "${structure}_${iterationX}_${iterationY}_vec${vecNum}o_DS5_DDB" >>"$datasets_file"
    echo "${filename}.abo" >>"$datasetsAbo_file"

    # Extract and perturb cartesian coordinates
    xcart_location=$(grep -n "xcart" "$general_structure_file" | cut -d: -f1)
    if [ -z "$xcart_location" ]; then
        echo "Error: Could not find 'xcart' in $general_structure_file"
        exit 1
    fi

    local xcart_start=$((xcart_location + 1))

    local xcart_end=$((xcart_start + natom - 1))
    xcart=$(sed -n "${xcart_start},${xcart_end}p" "$general_structure_file")

    if [ -z "$xcart" ]; then
        echo "Error: Failed to extract xcart coordinates from $general_structure_file"
        exit 1
    fi

    local count=0
    local nxcart_array=()
    local displacement_vector=()

    # Calculate the scalars used to multiply the displacement vectors
    cstep_sizeX=$(calculate "${step_sizeX} * ${iterationX}")
    cstep_sizeY=$(calculate "${step_sizeY} * ${iterationY}")
    for component in $xcart; do
        local eig_dispcompX="${eigdisp_array1[$count]}"
        local eig_dispcompY="${eigdisp_array2[$count]}"

        # Perturb the coordinates by the overall displacement vector and store displacement vector
        perturbationX=$(calculate "${eig_dispcompX}*${cstep_sizeX}")
        perturbationY=$(calculate "${eig_dispcompY}*${cstep_sizeY}")
        nxcart_array+=("$(calculate "${component}+${perturbationX}+${perturbationY}")")
        displacement_vector+=("$(calculate "$perturbationX+$perturbationY")")
        count=$((count + 1))
    done

    echo "$cstep_sizeX $cstep_sizeY" >>"$xpoints"
    echo ""

    # Echo displacement vector
    echo "Displacement vector for ${filename}:"
    for ((i = 0; i < ${#displacement_vector[@]}; i += 3)); do
        echo "${displacement_vector[i]} ${displacement_vector[i + 1]} ${displacement_vector[i + 2]}"
    done
    echo ""
    # Echo new cartesian coordinates
    echo "New cartesian coordinates for ${filename}:"
    for ((i = 0; i < ${#nxcart_array[@]}; i += 3)); do
        echo "${nxcart_array[i]} ${nxcart_array[i + 1]} ${nxcart_array[i + 2]}"
    done
    echo ""
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

    cat <<EOF >"$filename_abi"
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
    cat "$general_structure_file" >>"$filename_abi"

    # Find the line number where xcart starts
    xcart_start=$(grep -n "^xcart" "$filename_abi" | cut -d: -f1)

    if [ -z "$xcart_start" ]; then
        echo "Error: Unable to locate xcart coordinates in $filename_abi"
        exit 1
    fi

    # Count the number of coordinate lines (should be equal to natom)
    xcart_end=$((xcart_start + natom))

    echo "Printing old xcart:"
    sed -n "${xcart_start},${xcart_end}p" "$filename_abi"

    # Delete existing xcart coordinates
    sed -i "${xcart_start},${xcart_end}d" "$filename_abi"

    # Insert new xcart coordinates
    sed -i "${xcart_start}ixcart" "$filename_abi"
    for ((i = 0; i < ${#nxcart_array[@]}; i += 3)); do
        sed -i "${xcart_start}a${nxcart_array[i]} ${nxcart_array[i + 1]} ${nxcart_array[i + 2]}" "$filename_abi"
        xcart_start=$((xcart_start + 1))
    done

    echo "Printing new xcart:"
    grep -A "$natom" "^xcart" "$filename_abi"

    bash xcartToxred.sh "$filename_abi"
    echo ""
    # Print the space group of the perturbed cell
    space_group=$(bash findSpaceGroup.sh "$filename_abi")
    if [ -z "${space_group}" ]; then
        echo "The space group of cell ${iteration} is unavailable"
    else
        echo "The space group of cell ${iteration} is $space_group"
    fi
    echo ""
    bash xredToxcart.sh "$filename_abi"
}

# Function to create and submit batch script
create_batch_script() {
    local filename="$1"
    local filename_abi="$2"
    local script="b-script-${filename}"

    # Read the preamble file contents if it hasn't been done already
    if [ -z "$preamble" ]; then
        preamble=$(<"$bScriptPreamble")
    fi

    cat <<EOF >"${script}"
#!/bin/bash
$preamble

mpirun -hosts=localhost -np  ${nproc}  abinit  ${filename_abi} >& ${filename}.log
EOF

    job_id=$(sbatch "${script}" | awk '{print $4}')
    local job_id
    job_ids+=("$job_id")
    echo "Submitted batch job $job_id"
    rm "${script}"
}

# Function to wait for all jobs to complete
wait_for_jobs() {
    start_time=$(date +%s)
    timeout=43200 # 12 hours in seconds

    while true; do
        all_completed=true
        for job_id in "${job_ids[@]}"; do
            if squeue -h -j "$job_id" &>/dev/null; then
                all_completed=false
                break
            else
                echo "Job $job_id completed"
            fi
        done

        if $all_completed; then
            echo "All Batch Scripts have Completed."
            return 0
        fi

        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [ $elapsed_time -ge $timeout ]; then
            echo "Timeout reached. Exiting after 3 hours."
            return 1
        fi

        sleep 60 # Check every minute
    done
}

# Main execution
check_args "$@"
read_input_params "$1"
calc_step_size
init_output_files
extract_normalize_eigdisp1 "$1"
echo ""
echo "Printing eigdisp_array1:"
for ((i = 0; i < ${#eigdisp_array1[@]}; i += 3)); do
    echo "${eigdisp_array1[i]} ${eigdisp_array1[i + 1]} ${eigdisp_array1[i + 2]}"
done
echo ""
job_ids=()
# Create perturbed files
if [ "$phonon_coupling" = 1 ]; then
    extract_normalize_eigdisp2 "$1"
    echo ""
    echo "Printing eigdisp_array2:"
    for ((i = 0; i < ${#eigdisp_array2[@]}; i += 3)); do
        echo "${eigdisp_array2[i]} ${eigdisp_array2[i + 1]} ${eigdisp_array2[i + 2]}"
    done
    echo ""
    for iterationX in $(seq 1 "$grid_dimX"); do
        for iterationY in $(seq 1 "$grid_dimY"); do
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
echo "];" >>"$xpoints"

# Organize files and run the data analysis script
mkdir -p "datapointAbiFiles_vec${vecNum}"
mv "${structure}_*_vec${vecNum}.abi" "datapointAbiFiles_vec${vecNum}/"
bash dataAnalysisEnergy.sh "${datasets_file}" "$xpoints" "$datasetsAbo_file" "$vecNum"
echo "Data Analysis is Complete"

mv "${structure}_*_vec${vecNum}.abo" "datapointAbiFiles_vec${vecNum}/"

echo "Total energy calculation for perturbed system completed successfully."
