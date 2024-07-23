#!/bin/bash 
#SBATCH --job-name=FLPZ_Energy
#SBATCH --error=FLPZ_Energy.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --account=crl174
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=FLPZ_Energy.out


# FLPZ Coupling Program
# Executes the FLPZ (Flexoelectric Piezoelectric) perturbation coupling calculations

# Usage: ./flpzCouple.sh <input_file> <datasets1> (optional) <dataset2> (optional)

# Extraction of variables
input_file="$1"
irrep_1="$2"
irrep_2="$3"

read_input_params() {
structure=$(grep "name" "$input_file" |awk '{print $2}')
inputIrrep_1=$(grep "inputIrrep_1" "$input_file" | awk '{print $2}')
inputIrrep_2=$(grep "inputIrrep_2" "$input_file" | awk '{print $2}')
inputData_1=$(grep "inputData_1" "$input_file" |awk '{print $2}')
inputData_2=$(grep "inputData_2" "$input_file" | awk '{print $2}')

# Read eigendisplacement vectors of both input irrepresentations
mode_location=$(grep -n "eigen_disp" "$inputIrrep_1" | cut -d: -f1)
general_structure_file=$(grep "genstruc" "$inputIrrep_1" | awk '{print $2}')
begin_mode=$((mode_location + 1))
end_mode=$((begin_mode + $(grep "natom" "$general_structure_file" | awk '{print $2}') - 1))
eig_disp1=$(sed -n "${begin_mode},${end_mode}p" "$input_file")

mode_location=$(grep -n "eigen_disp" "$inputIrrep_2" | cut -d: -f1)
general_structure_file=$(grep "genstruc" "$inputIrrep_2" | awk '{print $2}')
begin_mode=$((mode_location + 1))
end_mode=$((begin_mode + $(grep "natom" "$general_structure_file" | awk '{print $2}') - 1))
eig_disp2=$(sed -n "${begin_mode},${end_mode}p" "$input_file")
}

#TODO
# I need to find a way to make both eigendisplacements compatible with one another as both used different bases in the initial 
# calculation. 

# Creation of new working directory 
dir="${structure}_${irrep_1}_${irrep_2}"
mkdir "$dir"
cd "$dir" || exit

# Calculate datapoints
bash datapointCalcofElec.sh "${input_file}_vec${eigVec}"



