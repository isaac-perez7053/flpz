#!/bin/bash
# Creates the boilerplate, a dependency for the SMODES calculation
# Usage: ./boilerplate_generation.sh <input_file>

set -e  # Exit immediately if a command exits with a non-zero status

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
    general_structure_file=$(grep "genstruc" "$input_file" | awk '{print $2}')
    time_limit=$(grep "time_limit" "$input_file" | awk '{print $2}')
    ntypat=$(grep "ntypat" "$general_structure_file" | awk '{print $2}')
}

# Function to create boilerplate directory and copy pseudopotentials
setup_boilerplate() {
    mkdir -p boilerplate
    local pp_dirpath=$(grep "pp_dirpath" "$general_structure_file" | awk '{print $2}' | sed 's/[,"]//g')
    
    for i in $(seq 2 $((ntypat + 1))); do
        local pseudos=$(grep "pseudos" "$general_structure_file" | awk "{print \$$i}" | sed 's/[,"]//g')
        cp "${pp_dirpath}${pseudos}" boilerplate/
    done
}

# Function to generate jobscript.sh
generate_jobscript() {
    local script="boilerplate/jobscript.sh"
    cat << EOF > "$script"
#!/bin/bash
#SBATCH --job-name=abinit
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --account=crl174
#SBATCH --mem=64G
#SBATCH --time=${time_limit}
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

mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 2 abinit DISTNAME.abi >& log
EOF
}

# Function to prepare template.abi
prepare_template() {
    cp "$general_structure_file" boilerplate/template.abi
    sed -i '/acell/c\CELLDEF' boilerplate/template.abi
    sed -i '/natom/d; /ntypat/d; /typat/d; /znucl/d' boilerplate/template.abi

    local vars=("rprim" "xred" "xcart")
    for var in "${vars[@]}"; do
        if grep -q "^[[:space:]]*$var" boilerplate/template.abi; then
            local start_line=$(grep -n "$var" boilerplate/template.abi | cut -d: -f1)
            local end_line
            if [ "$var" = "rprim" ]; then
                end_line=$((start_line + 3))
            else
                end_line=$((start_line + $(grep "natom" "$general_structure_file" | awk '{print $2}')))
            fi
            sed -i "${start_line},${end_line}d" boilerplate/template.abi
        fi
    done
}

# Main execution
check_args "$@"
read_input_params "$1"
setup_boilerplate
generate_jobscript
prepare_template

echo "Boilerplate generation completed successfully."
