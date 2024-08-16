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
shift $((OPTIND - 1))

# This will move down each line in the mapping variable and print every corresponding eigenvector in an array.
# Note that the

eig_vec="$1"
mapping="$2"

if [ "$eigVecExtOpt" = "matlab" ]; then

  declare -a extendedEig_vec
  while read -r line; do
    extendedEig_vec+=("$(echo "$eig_vec" | sed -n "${line}p")")
  done < <(echo "$mapping")

  # Print each element of the array
  for element in "${extendedEig_vec[@]}"; do
    echo "$element"
  done
elif [ "$eigVecExtOpt" = "python" ]; then
  extendedEig_vec=("$($mapping | tr -d '[],')")
  for element in "${extendedEig_vec[@]}"; do
    echo "$element"
  done
fi
