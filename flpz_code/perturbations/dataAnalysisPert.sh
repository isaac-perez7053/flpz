#!/bin/bash

# dataAnalysisPert.sh
# Analyses the total energy, flexoelectricity, and piezoelectricity of the perturbed system form
# datapoint calculations. Note, there are many checks in this script due to an error 
# in Abinit currently. 

# Usage: ./dataAnalysisPert.sh <derivative_db_file> <x_points_file> <abo_files_list> <vector_number>

# set -e  # Exit immediately if a command exits with a non-zero status.


OPTSTRING=":p:"

run_piezo="false"
# Parse command line options
while getopts "${OPTSTRING}" opt; do
    case $opt in
    p)
        run_piezo=true
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done
shift $(( OPTIND - 1 ))

if [ "$run_piezo" = "true" ]; then 
    echo "Piezo flag -p activated"
fi 

# Function to clean up temporary files
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f anaddbF_*.files anaddbP_*.files anaddb*.abi _anaddb.nc fort.7 output.log flexoanaddb.abi piezoanaddb.abi
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File $1 does not exist"
        return 1
    fi
    return 0
}

# Function to check executable permissions
check_executable() {
    if [ ! -x "$(command -v "$1")" ]; then
        echo "Error: $1 is not executable or not in PATH"
        return 1
    fi
    return 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

## Check if the correct number of arguments are provided
if [ "$#" -ne 4 ] && [ "$#" -ne 5 ]; then
    echo "Usage: $0 [-p] <derivative_db_file> <x_points_file> <abo_files_list> <vector_number>"
    exit 1
fi

if [ ! -w "." ]; then
    echo "Error: No write permission in current directory"
    exit 1
fi

if ! anaddb <"${anaddbfilesF}" >"${anaddbfilesF}.direct.out" 2>"${anaddbfilesF}.direct.err"; then
    echo "Error: anaddb failed when run directly"
    cat "${anaddbfilesF}.direct.err"
else
    echo "anaddb succeeded when run directly"
fi

## Read the command line arguments
input_fileAn="$1"
xpoints="$2"
inputAbo_files="$3"
vecNum="$4"

# Check if input files exist
for file in "$input_fileAn" "$xpoints" "$inputAbo_files"; do
    check_file "$file" || exit 1
done

# Creation of output file
output_file="Datasets_vec${vecNum}.m"
outputEn_file="totEnergy_vec${vecNum}.m"

# Initialize total energy vector
echo "totEnergy_vec = [" >"$outputEn_file"

# Get number of datapoints
num_datapoints=$(sed -n '1p' "$input_fileAn")
echo "num_datapoints: $num_datapoints"

######################
## Create anaddb files
######################

anaddbP="piezoanaddb.abi"
cat <<EOF >"${anaddbP}"
! Input file for the anaddb code

elaflag 3  ! flag for the elastic constant
piezoflag 3 !the flag for the piezoelectric constant
instrflag 1 ! the flag for the internal strain tensor

EOF

if [ "$run_piezo" != "true" ]; then
anaddbF="flexoanaddb.abi"
cat <<EOF >"${anaddbF}"
! anaddb calculation of flexoelectric tensor

flexoflag 1

EOF
fi

successful_runs=0
for dataset in $(seq 1 $((num_datapoints + 1))); do
    #Find dataset filename
    if [ "$run_piezo" = "true" ]; then 
        dataset_locP=$((dataset + 1 ))
    else
        dataset_locP=$((dataset * 2))
        dataset_locF=$((dataset_locP + 1))
        dataset_fileF=$(sed -n "${dataset_locF}p" "$input_fileAn" | tr -d '[:space:]')
    fi
    dataset_fileP=$(sed -n "${dataset_locP}p" "$input_fileAn" | tr -d '[:space:]')

    # Check for mpirun and anaddb
    if ! command_exists mpirun; then
        echo "Error: mpirun is not installed or not in PATH"
        exit 1
    fi

    if ! command_exists anaddb; then
        echo "Error: anaddb is not installed or not in PATH"
        exit 1
    fi

    # Check executable permissions
    check_executable mpirun || exit 1
    check_executable anaddb || exit 1

    echo "mpirun location: $(which mpirun)"
    echo "anaddb location: $(which anaddb)"


    echo "Debug: Looking for the file '$dataset_fileP'"
    ls -l "$dataset_fileP" 2>/dev/null || echo "Files not found"


    if [ "$run_piezo" != "true" ]; then 
        echo "Debug: Looking for the file '$dataset_fileF'"
        ls -l "$dataset_fileF" 2>/dev/null || echo "Files not found"
    fi 

    # Check if dataset files exist
    if ! check_file "$dataset_fileP"; then
        echo "Skipping dataset $dataset for piezoelectricity due to missing files"
        continue
    fi

    if [ "$run_piezo" != "true" ] && ! check_file "$dataset_fileF"; then 
        echo "Skipping dataset $dataset for flexoelectricity due to missing files"
        continue
    fi 

    #Search for totenergy and store
    abo_file=$(sed -n "${dataset}p" "$inputAbo_files")
    if check_file "$abo_file"; then
        grep "etotal1" "$abo_file" | awk '{print $2}' >>"$outputEn_file"
    else
        echo "Warning: ABO file $abo_file not found for dataset $dataset"
    fi

    ################################
    ## Creation of the file of files
    ################################

    anaddbfilesP="anaddbP_${dataset}.files"

        cat <<EOF >"${anaddbfilesP}"
${anaddbP}
piezoElec_${dataset}
${dataset_fileP}
dummy1
dummy2
dummy3
dummy4
EOF

    if [ "$run_piezo" != "true" ]; then 

        anaddbfilesF="anaddbF_${dataset}.files"

        cat <<EOF >"${anaddbfilesF}"
${anaddbF}
flexoElec_${dataset}
${dataset_fileF}
dummy1
dummy2
dummy3    
dummy4        
EOF


    fi


    echo "Processing dataset $dataset"
    if [ "$run_piezo" = "true" ]; then 
        echo "Using files: ${dataset_fileP}"
    else 
        echo "Using files: ${dataset_fileP} and ${dataset_fileF}"
        echo "Debug: Content of ${anaddbfilesF}:"
        cat "${anaddbfilesF}":
    fi 
    echo "Debug: Checking if anaddb is executable:"
    ls -l "$(which anaddb)"

    anaddb <"${anaddbfilesP}" >"${anaddbfilesP}.out" 2>"${anaddbfilesP}.err"

    if [ "$run_piezo" != "true" ]; then 
        anaddb <"${anaddbfilesF}" >"${anaddbfilesF}.out" 2>"${anaddbfilesF}.err"
    fi
    # Run Anaddb Files
    # if ! mpirun -v -hosts=localhost -np 1 anaddb < "${anaddbfilesF}" > "${anaddbfilesF}.out" 2> "${anaddbfilesF}.err"; then
    #         echo "Error: mpirun failed for ${anaddbfilesF}"
    #         echo "mpirun command: mpirun -v -hosts=localhost -np 1 anaddb < ${anaddbfilesF}"
    #         cat "${anaddbfilesF}.out" "${anaddbfilesF}.err"
    #         continue
    # fi

    # if ! mpirun -v -hosts=localhost -np 1 anaddb < "${anaddbfilesP}" > "${anaddbfilesP}.out" 2> "${anaddbfilesP}.err"; then
    #         echo "Error: mpirun failed for ${anaddbfilesP}"
    #         echo "mpirun command: mpirun -v -hosts=localhost -np 1 anaddb < ${anaddbfilesP}"
    #         cat "${anaddbfilesP}.out" "${anaddbfilesP}.err"
    #         continue
    # fi

    if [ ! -f "flexoElec_${dataset}" ] && [ "$run_piezo" != "true" ]; then
        echo "Error: flexoElec_${dataset} was not created"
        continue
    fi
    if [ ! -f "piezoElec_${dataset}" ]; then
        echo "Error: piezoElec_${dataset} was not created"
        continue
    fi

    successful_runs=$((successful_runs + 1))
done

echo "];" >>"$outputEn_file"

if [ "$successful_runs" -eq 0 ]; then
    echo "No successful runs occurred. Skipping tensor processing."
    exit 1
fi

# Process and store tensor data
for dataset in $(seq 1 $((num_datapoints + 1))); do

    piezo_file="piezoElec_${dataset}"
    
    if [ "$run_piezo" != "true" ]; then 
        flexo_file="flexoElec_${dataset}"
        if check_file "$flexo_file"; then 
             # Store flexoelectric tensor into output file
            echo -e "%Flexoelectric Tensor: Dataset ${dataset}\n" >>"$output_file"
            flexoTen="mu${dataset} = [$(grep -A11 'TOTAL' "$flexo_file" | grep -o '[-]\?[0-9]*\.*[0-9]\+')];"
            echo "${flexoTen}" >>"$output_file"
            echo -e "\n\n\n" >>"$output_file"
        else
            echo "Warning: Missing tensor files for dataset $dataset"
        fi 
    fi

    if check_file "$piezo_file"; then
        # Store piezoelectric tensor into output file
        echo -e "%Piezoelectric Tensor: Dataset ${dataset}\n" >>"${output_file}"
        piezoTen="chi${dataset} = [$(grep -A7 'Proper piezoelectric constants (relaxed ion)' "$piezo_file" | grep -o '[-]\?[0-9]*\.*[0-9]\+' | tail -n +2)];"
        echo "${piezoTen}" >>"$output_file"
        echo -e "\n\n\n" >>"$output_file"

        # Delete processed files
        rm -f "$flexo_file" "$piezo_file"
    else
        echo "Warning: Missing tensor files for dataset $dataset"
    fi
done

# Combines the x_vec with the flexoElectricity matrices
if check_file "$xpoints" && check_file "$outputEn_file"; then
    cat "$xpoints" >>"$output_file"
    cat "$outputEn_file" >>"$output_file"
else
    echo "Error: Unable to append x_points or total energy data"
fi

rm anaddb*
echo "Data analysis completed. Output saved to $output_file"
