#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <OriginalCell> <TargetCell>"
    exit 1
fi

originalCell="$1"
targetCell="$2"
matlabFile="transformCell_Map.m"
newMatlabFile="transformCell_MapTest_modified.m"

# Function to extract cell data from input files
extract_cell_data() {
    local file="$1"
    local cellType="$2"

    natom=$(grep "natom" "$file" | awk '{print $2}')
    
    # Extract rprim (this part is already correct)
    rprim=$(awk '/^rprim/{flag=1; next} flag{printf "               %s\n", $0; if (NF==0 || ++count==3) exit}' "$file")
    
    # Extract xred and format it with 3 columns
    xred=$(awk -v natom="$natom" '
        /^xred/{flag=1; next} 
        flag && NF==3 {
            printf "               %s %s %s\n", $1, $2, $3
            if (++count == natom) exit
        }
    ' "$file")
    
    # Format the data for MATLAB
    echo "% Primitive vectors of the $cellType cell"
    echo "${cellType}Cell=[   $rprim];"
    echo "% $cellType cell expressed in reduced coordinates"
    echo "${cellType}_posfrac=[${xred%$'\n'}];"
}

# Extract data from input files
originalCellData=$(extract_cell_data "$originalCell" "Gamma")
targetCellData=$(extract_cell_data "$targetCell" "Target")

# Create temporary files with the cell data
originalTempFile=$(mktemp)
targetTempFile=$(mktemp)
echo "$originalCellData" > "$originalTempFile"
echo "$targetCellData" > "$targetTempFile"

# Create modified MATLAB file
cp "$matlabFile" "$newMatlabFile"

# Replace ORIGINALCELL and TARGETCELL in the new file
sed -i '' "/ORIGINALCELL/ r $originalTempFile" "$newMatlabFile"
sed -i '' "s/ORIGINALCELL//g" "$newMatlabFile"
sed -i '' "/TARGETCELL/ r $targetTempFile" "$newMatlabFile"
sed -i '' "s/TARGETCELL//g" "$newMatlabFile"

# Remove temporary files
rm "$originalTempFile" "$targetTempFile"

# Execute the modified MATLAB script
MATLAB_PATH="/Applications/MATLAB_R2024a.app/bin/matlab"
"$MATLAB_PATH" -nodisplay -nosplash -nodesktop -r "run('$newMatlabFile'); exit;"
rm "$newMatlabFile"

echo "MATLAB script executed. Check the results in $newMatlabFile"
