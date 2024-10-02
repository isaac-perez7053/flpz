#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  echo "Usage: $0 -m/p <eig_vec> <mapping>"
  exit 1
fi

OPTSTRING=":m:p:"

# Parse command line options
while getopts "${OPTSTRING}" opt; do
  case $opt in
  m)
    eigVecExtOpt="matlab"
    ;;
  p)
    eigVecExtOpt="python"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done
shift 

eig_vec="$1"
mapping="$2"


# Ensure mapping is valid before processing
if [ -z "$mapping" ]; then
  echo "Error: mapping is empty!"
  exit 1
fi

# Filter out any unwanted newlines or spaces in mapping
clean_mapping=$(echo "$mapping" | tr -d '\r' | tr -d '\n' | tr -s ' ')

if [ "$eigVecExtOpt" = "matlab" ]; then
  declare -a extendedEig_vec
  while read -r line; do
    if [[ ! -z "$line" ]]; then
      extendedEig_vec+=("$(echo "$eig_vec" | sed -n "${line}p")")
    fi
  done < <(echo "$clean_mapping")
  
  for element in "${extendedEig_vec[@]}"; do
    echo "$element"
  done
elif [ "$eigVecExtOpt" = "python" ]; then
  cleaned_mapping=$(echo "$clean_mapping" | tr -cd '0-9 ')
  IFS=' ' read -ra extendedEig_vec <<< "$cleaned_mapping"
  for element in "${extendedEig_vec[@]}"; do
    if [[ "$element" =~ ^[0-9]+$ ]]; then
      echo "$eig_vec" | sed -n "${element}p"
    else
      echo "Warning: Invalid element '$element' skipped" >&2
    fi
  done
fi


