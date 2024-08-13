#!/bin/bash
# Creates the boilerplate, a dependency for the SMODES calculation
# Usage: ./boilerplate_generation.sh <input_file>

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
#   time_limit=$(grep "time_limit" "$input_file" | awk '{print $2}')
    ntypat=$(grep "ntypat" "$general_structure_file" | awk '{print $2}')
    bScriptPreamble=$(grep "sbatch_preamble" "$input_file" | awk '{print $2}')

}

# Function to create boilerplate directory and copy pseudopotentials
setup_boilerplate() {
    mkdir -p boilerplate
    if [ ! -f "$general_structure_file" ]; then
        echo "Error: General structure file '$general_structure_file' not found"
        exit 1
    fi
    pp_dirpath=$(grep "pp_dirpath" "$general_structure_file" | awk '{print $2}' | sed 's/[,"]//g')
    if [ -z "$pp_dirpath" ]; then
        echo "Error: pp_dirpath not found in $general_structure_file"
        exit 1
    fi

    for i in $(seq 2 $((ntypat + 1))); do
        pseudos=$(grep "pseudos" "$general_structure_file" | awk "{print \$$i}" | sed 's/[,"]//g')
        cp -r "${pp_dirpath}${pseudos}" boilerplate/
    done
}

# Function to generate jobscript.sh
generate_jobscript() {
    local script="boilerplate/jobscript.sh"
    cat <<EOF >"$script"
#!/bin/bash
$preamble

mpirun -hosts=localhost -np  $SLURM_NTASKS  abinit  DISTNAME.abi >& log
EOF
}

# Function to prepare template.abi
prepare_template() {
    if [ ! -f "$general_structure_file" ]; then
        echo "Error: General structure file '$general_structure_file' not found"
        exit 1
    fi
    cp "$general_structure_file" boilerplate/template.abi
    sed -i '/acell/c\CELLDEF' boilerplate/template.abi
    sed -i '/natom/d; /ntypat/d; /typat/d; /znucl/d' boilerplate/template.abi

    local vars=("rprim" "xred" "xcart")
    for var in "${vars[@]}"; do
        if grep -q "^[[:space:]]*$var" boilerplate/template.abi; then
            start_line=$(grep -n "$var" boilerplate/template.abi | cut -d: -f1)
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

# Read preamble content
if [ -f "$bScriptPreamble" ]; then
    preamble=$(<"$bScriptPreamble")
else
    echo "Error: bScriptPreamble file '$bScriptPreamble' not found"
    exit 1
fi

setup_boilerplate
generate_jobscript
prepare_template

echo "Boilerplate generation completed successfully."
