#!/bin/bash

# FLPZ Perturbation Program
# Executes the FLPZ (Flexoelectric Piezoelectric) perturbation calculations

# Usage: ./flpzPert.sh <input_file> <smodes_input> <irrep>

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_file> <smodes_input> <irrep>"
    exit 1
fi

echo "Beginning FLPZ Program"

# Read input files and calculate constant quantities
input_file="$1"
smodes_input="$2"
irrep="$3"

general_structure_file=$(grep "genstruc" "$input_file" | awk '{print $2}')
structure=$(grep "name" "$input_file" | awk '{print $2}')
ntypat=$(grep "ntypat" "$general_structure_file" | awk '{print $2}')

# Create new working directory
dir="${structure}_${irrep}"
mkdir -p "$dir"

# Copy necessary files to working directory
handle_files() {
    local source_dir="$1"
    local files=(
        "boilerplate_generation.sh"
        "smodes_symmadapt_abinit.py"
        "loop_smodes.tcsh"
        "smodes_postproc_abinit.py"
        "eigVecExtElec.sh"
        "datapointCalcofElec.sh"
        "dataAnalysis.sh"
        "xredToxcart.sh"
        "findAngle.py"
        "findSpaceGroup.sh"
    )
    for file in "${files[@]}"; do
        if [ "$2" = "rm" ]; then
            rm "$source_dir/$file"
        elif [ "$2" = "cp" ]; then
            cp "$source_dir/$file" "$dir/"
        fi
    done
}

handle_files
cp "$input_file" "$dir/"
cp "$smodes_input" "$dir/"

# Generate boilerplate
bash "$dir/boilerplate_generation.sh" "$input_file"
mv boilerplate "$dir"

# Change to working directory
cd "$dir"

# Process smodes and FCEvecs
python3 smodes_symmadapt_abinit.py "$smodes_input" "$irrep"
tcsh loop_smodes.tcsh "$irrep"

# Copy pseudopotentials
copy_pseudos() {
    local dest_dir=$1
    for i in $(seq 2 $((ntypat + 1))); do
        pseudos=$(grep "pseudos" "../$general_structure_file" | awk "{print \$$i}" | sed 's/[,"]//g')
        cp "boilerplate/$pseudos" "$dest_dir/"
    done
}

copy_pseudos "SMODES_$irrep"
copy_pseudos "."

echo "Successfully created dependencies"
echo "FCEvec calculations begin"

# Wait for jobs to finish 
job_ids=()
file_path=joblist

count=0
while IFS= read -r line
do
    cd "SMODES_${irrep}/dist_${count}"
   # Submit job and capture the job ID
    job_id=$(sbatch jobscript.sh | awk '{print $4}')
    job_ids+=($job_id)
    echo "Submitted batch job $job_id"
    cd -
    count=$(( count + 1 ))
done < "$file_path"

# Wait for all jobs to finish
for job_id in "${job_ids[@]}"; do
    squeue -h -j "$job_id"
    while [ $? -eq 0 ]; do
        sleep 60  # Check every minute
        squeue -h -j "$job_id"
    done
    echo "Job $job_id completed"
done

echo "All batch scripts have completed"
echo "Post-processing of FCEvecs begins"

# Post-processing of FCEvecs
# Reassign SMODES output as new genstruc
sed -i "s|^genstruc .*|genstruc SMODES_${irrep}/dist_0/dist_0.abi|" "$input_file"
general_structure_file=$(grep "genstruc" "$input_file" | awk '{print $2}')


echo "The space group of the unperturbed cell is $(bash findSpaceGroup.sh $general_structure_file)"
bash xredToxcart.sh "SMODES_${irrep}/dist_0/dist_0.abi"

python3 smodes_postproc_abinit.py "$irrep"
mv "SMODES_${irrep}/FCEvecs.dat" "."
mv "SMODES_${irrep}/DynFreqs.dat" "."

bash eigVecExtElec.sh "DynFreqs.dat" "FCEvecs.dat" "$input_file"

eigVec_nlines=$(grep "eigVec_nlines" "$input_file" | awk '{print $2}')
mode_location=$(grep -n "eigVec_lines" "$input_file" | cut -d: -f1)
eigVec_lines=$(sed -n "$((mode_location+1)),$((mode_location+eigVec_nlines))p" "$input_file")

echo "Post-processing of FCEvecs is complete"
echo "Calculation of datapoints begins"

# Calculate datapoints
for eigVec in $eigVec_lines; do
    bash datapointCalcofElec.sh "${input_file}_vec${eigVec}"
done

handle_files "." "rm"

echo "FLPZ Program has completed calculations"

