#!/bin/bash

# Data Analysis Script
# Takes output of datapoint calculations, runs anaddb, and stores output in a MATLAB file for plotting

# Usage: ./dataAnalysis.sh <derivative_db_list> <x_points_file> <abo_files_list> <structure_name> <vector_number>

# SLURM directives
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

# Load modules
module purge
module load slurm cpu/0.17.3b gcc/10.2.0 openmpi/4.1.3 wannier90/3.1.0 netcdf-fortran/4.5.3 libxc/5.1.5 fftw/3.3.10 netlib-scalapack/2.1.0
export PATH=/expanse/projects/qstore/use300/jpg/abinit-10.0.5/bin:$PATH

# Check if the correct number of arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <derivative_db_list> <x_points_file> <abo_files_list> <structure_name> <vector_number>"
    exit 1
fi

# Read command line arguments
input_fileAn="$1"
xpoints="$2"
inputAbo_files="$3"
structure="$4"
vecNum="$5"

# Create output files
output_file="Datasets_vec${vecNum}.m"
outputEn_file="totEnergy_vec${vecNum}.m"
echo "totEnergy_vec = [" > "$outputEn_file"

num_datapoints=$(sed -n '1p' "$input_fileAn")

# Create anaddb files
create_anaddb_files() {
    cat << EOF > "flexoanaddb.abi"
! anaddb calculation of flexoelectric tensor
flexoflag 1
EOF

    cat << EOF > "piezoanaddb.abi"
! Input file for the anaddb code
elaflag 3  ! flag for the elastic constant
piezoflag 3 !the flag for the piezoelectric constant
instrflag 1 ! the flag for the internal strain tensor
EOF
}

create_anaddb_files

# Process datasets
for dataset in $(seq 1 $((num_datapoints + 1))); do
    dataset_locP=$((dataset * 2))
    dataset_locF=$((dataset_locP + 1))
    dataset_fileP=$(sed -n "${dataset_locP}p" "$input_fileAn")
    dataset_fileF=$(sed -n "${dataset_locF}p" "$input_fileAn")   

    # Extract total energy
    grep "etotal1" "$(sed -n "${dataset}p" "$inputAbo_files")" | awk '{print $2}' >> "$outputEn_file"

    # Create anaddb file of files
    create_anaddb_files_of_files() {
        local type=$1
        local dataset=$2
        local dataset_file=$3
        cat << EOF > "anaddb${type}_${dataset}.files"
${type,,}oanaddb.abi
${type,,}oElec_${dataset}
${dataset_file}
dummy1
dummy2
dummy3
EOF
    }

    create_anaddb_files_of_files "F" "$dataset" "$dataset_fileF"
    create_anaddb_files_of_files "P" "$dataset" "$dataset_fileP"

    # Run Anaddb
    mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 1 anaddb < "anaddbF_${dataset}.files" > "anaddbF_${dataset}.files.log" 2>&1
    mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 1 anaddb < "anaddbP_${dataset}.files" > "anaddbP_${dataset}.files.log" 2>&1
done

# Extract and store tensors
for dataset in $(seq 1 $((num_datapoints + 1))); do
    echo -e "%Flexoelectric Tensor: Dataset ${dataset}\n" >> "$output_file"
    grep -A11 'TOTAL' "flexoElec_${dataset}" | grep -o '[-]\?[0-9]*\.*[0-9]\+' | xargs -n 1 | sed 's/^/    /' | sed '1s/^/mu'"${dataset}"' = [\n/' | sed '$s/$/];/' >> "$output_file"
    echo -e "\n\n%Piezoelectric Tensor: Dataset ${dataset}\n" >> "$output_file"
    grep -A7 'Proper piezoelectric constants (relaxed ion)' "piezoElec_${dataset}" | grep -o '[-]\?[0-9]*\.*[0-9]\+' | tail -n +2 | xargs -n 1 | sed 's/^/    /' | sed '1s/^/chi'"${dataset}"' = [\n/' | sed '$s/$/];/' >> "$output_file"
    echo -e "\n\n" >> "$output_file"

    rm "flexoElec_${dataset}" "piezoElec_${dataset}"
done

# Finalize output file
echo "];" >> "$outputEn_file"
cat "$xpoints" >> "$output_file"
cat "$outputEn_file" >> "$output_file"

# Clean up
echo "Cleaning up files..."
rm anaddb* _anaddb.nc fort.7 output.log "$outputEn_file"

