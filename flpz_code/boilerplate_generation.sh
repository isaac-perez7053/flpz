#!/bin/bash 
 
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <arg1>"
    exit 1
fi

## Read the command line arguments
input_file="$1"
# File with the general (structural) information about the compound
general_structure_file="$(grep "genstruc" "$input_file" | awk '{print $2}')"

##fdf
time_limit=$(grep "time_limit" "$input_file" | awk '{print $2}')

#Psuedopotential read
ntypat=$(grep "ntypat" "$general_structure_file" | awk '{print $2}')

mkdir boilerplate

# Move pseudopotentials to boilerplate
pp_dirpath="$(grep "pp_dirpath" "$general_structure_file" | awk '{print $2}' | sed 's/[,"]//g')"

for ntypat in $(seq 2 $(( ntypat + 1)) )
do 
   pseudos="$(grep "pseudos" "$general_structure_file" | awk "{print \$$ntypat}" | sed 's/[,"]//g')"
   cp "$pp_dirpath$pseudos" boilerplate/.
done

##############################
# Generation of jobscript.sh #
##############################

script="jobscript.sh"

cat << EOF > "${script}"
#!/bin/bash
#SBATCH --job-name=abinit
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
##Change this to your allocation ID
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

#SET the number of openmp threads
export OMP_NUM_THREADS=24


mpirun --mca btl_openib_if_include "mlx5_2:1" --mca btl self,vader -np 2 abinit DISTNAME.abi >& log

EOF

mv "${script}" boilerplate

###########################################
# cp general_structure.abi to boilerplate #
###########################################

cp $general_structure_file boilerplate/template.abi 
sed -i '/acell/c\CELLDEF' boilerplate/template.abi 
xcart_location=$(grep -n "xcart" "boilerplate/template.abi" | cut -d: -f1)
xcart_start=$(( xcart_location  ))
xcart_end=$(( xcart_location+$(grep "natom" "$general_structure_file" | awk '{print $2}') ))
sed "$xcart_start,${xcart_end}d" "boilerplate/template.abi" > "tmpfile.abi" && mv "tmpfile.abi" "boilerplate/template.abi"
sed -i '/natom/d' "boilerplate/template.abi"
sed -i '/ntypat/d' "boilerplate/template.abi"
sed -i '/typat/d' "boilerplate/template.abi"
sed -i '/znucl/d' "boilerplate/template.abi"

