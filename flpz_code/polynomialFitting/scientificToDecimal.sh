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
    # Split the line into two parts
    first_part=$(echo "$line" | awk '{print $1}')
    second_part=$(echo "$line" | awk '{print $2}')

    # Convert scientific notation to decimal
    decimal=$(printf "%.10f" "$second_part")

    # Print the result to the temporary file
    echo "$first_part $decimal" >> "$temp_file"
done < "$filename"

# Replace the original file with the temporary file
mv "$temp_file" "$filename"

echo "Conversion complete. File $filename has been updated."
