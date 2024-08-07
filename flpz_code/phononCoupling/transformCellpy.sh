#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <OriginalCell> <TargetCell>"
    exit 1
fi

originalCell="$1"
targetCell="$2"
pythonFile="transformCell_Map.py"
newPythonFile="transformCell_MapTest_modified.py"

# Function to extract cell data from input files
extract_cell_data() {
    local file="$1"
    local cellType="$2"

    natom=$(grep "natom" "$file" | awk '{print $2}')

    # Extract rprim
    rprim=$(awk '/^rprim/{flag=1; next} flag{printf "    [%s],\n", $0; if (NF==0 || ++count==3) exit}' "$file")

    # Extract xred and format it with 3 columns
    xred=$(awk -v natom="$natom" '
        /^xred/{flag=1; next} 
        flag && NF==3 {
            printf "    [%s, %s, %s],\n", $1, $2, $3
            if (++count == natom) exit
        }
    ' "$file")

    # Format the data for Python
    echo "# Primitive vectors of the $cellType cell"
    echo "${cellType}Cell = np.array(["
    echo "${rprim%,}"
    echo "])"
    echo "# $cellType cell expressed in reduced coordinates"
    echo "${cellType}_posfrac = np.array(["
    echo "${xred%,}"
    echo "])"
}

# Extract data from input files
originalCellData=$(extract_cell_data "$originalCell" "ORIGINAL")
targetCellData=$(extract_cell_data "$targetCell" "TARGET")

# Create temporary files with the cell data
originalTempFile=$(mktemp)
targetTempFile=$(mktemp)
echo "$originalCellData" >"$originalTempFile"
echo "$targetCellData" >"$targetTempFile"

# Create modified Python file
cp "$pythonFile" "$newPythonFile"

# Add numpy import if not present
sed -i '1iimport numpy as np' "$newPythonFile"

# Replace ORIGINALCELL and TARGETCELL in the new file
sed -i "/ORIGINALCELL/ r $originalTempFile" "$newPythonFile"
sed -i "s/ORIGINALCELL//g" "$newPythonFile"
sed -i "/TARGETCELL/ r $targetTempFile" "$newPythonFile"
sed -i "s/TARGETCELL//g" "$newPythonFile"

# Add code to call the function at the end of the file
echo "" >>"$newPythonFile"
echo "# Call the function" >>"$newPythonFile"
echo "Mapping, outDiff = transformCell_Map(ORIGINALCell, TARGETCell, ORIGINAL_posfrac, TARGET_posfrac)" >>"$newPythonFile"
echo "print('Mapping:', Mapping)" >>"$newPythonFile"
echo "print('outDiff:', outDiff)" >>"$newPythonFile"

# Remove temporary files
rm "$originalTempFile" "$targetTempFile"

# Execute the modified Python script
python3 "$newPythonFile"

echo "Python script executed. Check the results in $newPythonFile"
