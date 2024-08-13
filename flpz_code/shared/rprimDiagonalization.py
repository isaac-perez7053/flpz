#!/usr/bin/env python3
import sys
import os
import numpy as np
import subprocess

def parse_args():
    if len(sys.argv) != 2:
        print("Usage: python rprimDiagonalization.py <rprim>")
        sys.exit(1)
    try:
        return (sys.argv[1])
    except ValueError as e:
        print(f"Error parsing arguments: {e}")
        sys.exit(1)

def reshape_rprim(rprim_str):
    rprim_list = [float(x) for x in rprim_str.split()]
    return np.array(rprim_list).reshape(3, 3)

def has_orthogonal_rows(matrix, tol=1e-8):
    matrix = np.array(matrix)
    
    # Compute the dot product of each pair of rows
    dot_products = np.dot(matrix, matrix.T)
    
    # Create a mask for the diagonal elements
    mask = np.eye(matrix.shape[0], dtype=bool)
    
    # Set diagonal elements to zero
    dot_products[mask] = 0
    
    # Check if all off-diagonal elements are close to zero
    return np.allclose(dot_products, 0, atol=tol)

def diagonalize(matrix):
    # Compute the eigenvalues and eigenvectors
    eigenvalues, eigenvectors = np.linalg.eig(matrix)
    
    # Round eigenvalues to handle potential floating-point inaccuracies
    eigenvalues = np.round(eigenvalues, decimals=10)
    
    # Construct the diagonal matrix of eigenvalues
    D = np.diag(eigenvalues.real)
    
    return D

def check_and_rearrange(matrix):
    # All possible permutations of the identity matrix
    target_forms = [
        np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1]]),  # Identity (no change needed)
        np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]]),
        np.array([[0, 1, 0], [1, 0, 0], [0, 0, 1]]),
        np.array([[0, 1, 0], [0, 0, 1], [1, 0, 0]]),
        np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]]),
        np.array([[0, 0, 1], [0, 1, 0], [1, 0, 0]])
    ]
    
    abs_matrix = np.abs(matrix)
    
    for i, target in enumerate(target_forms):
        if np.allclose(abs_matrix, target):
            # Create a permutation array to rearrange the rows
            perm = np.argmax(target, axis=1)
            return matrix[perm]
    
    return matrix

rprim_str = parse_args()
rprim = reshape_rprim(rprim_str)
rprim = check_and_rearrange(rprim)

if has_orthogonal_rows(rprim):
    D = diagonalize(rprim)
    for row in D:
        print(" ".join(f"{x.real:.10f}" for x in row))
else:
    for row in rprim:
        print(" ".join(f"{x:.10f}" for x in row))

import numpy as np

def rearrange_to_diagonal(arr):
    diag = np.diag(arr)
    return np.diag(diag)

