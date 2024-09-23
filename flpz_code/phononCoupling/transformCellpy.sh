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

    #Extract rprim with proper indentation
    rprim=$(awk '
        /^rprim/{flag=1; next} 
        flag && NF==3 {
            print "        [" $1 ", " $2 ", " $3 "],"
            if (++count == 3) exit
        }
    ' "$file")


    # Extract xred and format it with 3 columns and proper indentation
        # Extract and perturb cartesian coordinates
    #xred_location=$(grep -n "xred" "$file" | cut -d: -f1)
   # local xred_start=$((xred_location + 1))

    #local xred_end=$((xred_start + natom - 1))
    #xred=$(sed -n "${xred_start},${xred_end}p" "$file")
    
    
    # Extract xred (or xcart) and format it with 3 columns and proper indentation
    xred=$(awk -v natom="$natom" '
        /^xred/{flag=1; next} 
        flag && NF==3 {
            print "        [" $1 ", " $2 ", " $3 "],"
            if (++count == natom) exit
        }
    ' "$file")

    # Format the data for Python with proper indentation
    echo "# Primitive vectors of the $cellType cell"
    echo "${cellType}Cell = np.array(["
    echo "$rprim"
    echo "    ])"
    echo "# $cellType cell expressed in reduced coordinates"
    echo "${cellType}_posfrac = np.array(["
    echo "$xred"
    echo "    ])"
}

originalCellGenStruc=../catio3_GM4-_Energy/$(grep "genstruc" "$originalCell" | awk '{print $2}')
targetCellGenStruc=../catio3_GM4-_Energy/$(grep "genstruc" "$targetCell" | awk '{print $2}')

echo "Original structures"

echo "$originalCellGenStruc"
echo "$targetCellGenStruc"

# Extract data from input files. I have place holder in rn.
originalCellData=$(extract_cell_data "$originalCellGenStruc" "ORIGINAL")
targetCellData=$(extract_cell_data "$targetCellGenStruc" "TARGET")

echo "Original Cell Data"

echo "$originalCellData"


echo "targetCellData"
echo "$targetCellData"

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
#echo "" >>"$newPythonFile"
#echo "# Call the function" >>"$newPythonFile"
#echo "Mapping, outDiff = transformCell_Map(ORIGINALCell, TARGETCell, ORIGINAL_posfrac, TARGET_posfrac)" >>"$newPythonFile"
#echo "print('Mapping:', Mapping)" >>"$newPythonFile"
#echo "print('outDiff:', outDiff)" >>"$newPythonFile"

# Remove temporary files
rm "$originalTempFile" "$targetTempFile"

# Execute the modified Python script
python3 "$newPythonFile"

echo "Python script executed. Check the results in $newPythonFile"
