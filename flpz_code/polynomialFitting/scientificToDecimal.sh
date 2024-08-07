#!/bin/bash

# Check if a filename was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

filename=$1

# Check if the file exists
if [ ! -f "$filename" ]; then
    echo "File not found: $filename"
    exit 1
fi

# Create a temporary file
temp_file=$(mktemp)

# Process the file
while IFS= read -r line
do
    # Check if the line contains scientific notation
    if [[ $line =~ -?[0-9]+\.[0-9]+E\+[0-9]+ ]]; then
        # Extract the number and convert it
        number=$(echo "$line" | awk '{print $1}')
        decimal=$(awk 'BEGIN {printf "%.10f\n", '"$number"'}')

        # Replace the scientific notation with the decimal
        echo "$decimal" >> "$temp_file"
    else
        # If no scientific notation, just copy the line
        echo "$line" >> "$temp_file"
    fi
done < "$filename"

# Replace the original file with the temporary file
mv "$temp_file" "$filename"

echo "Conversion complete. File $filename has been updated."
