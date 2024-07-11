#!/bin/bash
###############################
# Executable for flpz program #
###############################

# Check for correct number of arguments

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

echo "Beginning flpz Program"

######################################################
# Read input files and calculate constant quantities #
######################################################

## Read the command line arguments
input_file="$1"
general_structure_file="$(grep "genstruc" "$input_file" | awk '{print $2}')"
structure="$(grep "name" "$input_file" | awk '{print $2}')"
smodes_input="$2"
irrep="$3"
ntypat=$(grep "ntypat" "$general_structure_file" | awk '{print $2}')

#####################################################
# Creation of new working directory and input files #
#####################################################

# Main working directory for calculations
dir="${structure}_${irrep}"
mkdir "$dir"

# Copy code into new working directory
cp flpz_code/boilerplate_generation.sh "$dir"/.
cp flpz_code/smodes_symmadapt_abinit.py "$dir"/.
cp flpz_code/loop_smodes.tcsh "$dir"/.
cp flpz_code/smodes_postproc_abinit.py "$dir"/.
cp flpz_code/eigVecExtElec.sh "$dir"/.
cp flpz_code/datapointCalcofElec.sh "$dir"/.
cp flpz_code/dataAnalysis.sh "$dir"/.
cp flpz_code/xredToxcart.sh "$dir"/.
cp "$input_file" "$dir"/.
cp "$smodes_input" "$dir"/.
cp flpz_code/findAngle.py "$dir"/.
cp flpz_code/findSpaceGroup.sh "$dir"/.

# Generation of boilerplate for Prof. Ritz's code
bash "$dir"/boilerplate_generation.sh "$input_file"
mv boilerplate "$dir"

### Begin Working in new directory ###
cd "$dir"

# Processing of smodes and FCEvecs using smodes program
python3 smodes_symmadapt_abinit.py "$smodes_input" "$irrep"
# Creates job scripts for FCEvec calculations
tcsh loop_smodes.tcsh "$irrep"

# Copy pseudopotentials into SMODES_irrep for abi cacluations
for ntypat in $(seq 2 $(( ntypat + 1)) )
do
   pseudos="$(grep "pseudos" "../$general_structure_file" | awk "{print \$$ntypat}" | sed 's/[,"]//g')"
   cp boilerplate/"$pseudos" SMODES_"$irrep"/.
done

# Copy pseudopotentials into Calculation for abi cacluations
for ntypat in $(seq 2 $(( ntypat + 1)) )
do
   pseudos="$(grep "pseudos" "../$general_structure_file" | awk "{print \$$ntypat}" | sed 's/[,"]//g')"
   cp boilerplate/"$pseudos" .
done

#NOTE: Leave it up to user to correctly put pseudopotentials in flpz directory and directory
#before. 


echo "Successfully Created Dependencies"
echo "FCEvec Calculations Begin"

####################################################################
# Stores job PIDS into array and waits for all processes to finish #
####################################################################
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

echo "All Batch Scripts have Completed"
echo "Post Processing of FCEvecs Begin"

###############################
#  Post Processing of FCEvecs #
###############################

# Reassign genStruc as boilerplate base calculation.  
new_content="genstruc SMODES_${irrep}/dist_0/dist_0.abi"

awk -v new="$new_content" '
/genstruc/ {
    print new
    next
}
{print}
' "$input_file" > "${input_file}.tmp" && mv "${input_file}.tmp" "$input_file"

# Report spacegroup of SMODES basis cell
echo "The space group of the unperturbed cell is "$(bash findSpaceGroup.py $general_structure_file)"" 

# Report space of perturbed cell if datapoints greater than 0 
if [[ -gt $num_datapoints 0 ]]
then
        echo "The space group of the perturbed cell is "$(bash findSpaceGroup.py "SMODES_${irrep}/dist_1/dist_1.abi")""
fi

# Convert xred to xcart for human readability
bash xredToxcart.sh "SMODES_${irrep}/dist_0/dist_0.abi"

# Process smodes output
python3 smodes_postproc_abinit.py "$irrep"
mv "SMODES_${irrep}/FCEvecs.dat" "."
mv "SMODES_${irrep}/DynFreqs.dat" "."

# Take unstable eigenvectors and cat to input
bash eigVecExtElec.sh "DynFreqs.dat" "FCEvecs.dat" "$input_file"

# Store outputs of previous script
eigVec_nlines=$(grep "eigVec_nlines" "$input_file" | awk '{print $2}')

# Put eigenvectors in the right place for calculation of datapoints
mode_location=$(grep -n "eigVec_lines" "$input_file" | cut -d: -f1)
begin_mode=$(( mode_location+1 ))
end_mode=$(( mode_location+$eigVec_nlines ))

## Extract lines from begin_mode to end_mode and normalize in the process 
eigVec_lines=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

echo "Post Processing of FCEvecs is Complete"
echo "Calculation of Datapoints Begin"

#############################
# Calculation of datapoints #
#############################

# Execute all input files generated
for eigVec in ${eigVec_lines}
do
   bash datapointCalcofElec.sh "${input_file}_vec${eigVec}"
done

echo "flpz Program has Completed Calculations"

