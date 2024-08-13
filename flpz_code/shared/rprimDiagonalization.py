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
    real_eigenvalues = eigenvalues.real
    
    # Construct the diagonal matrix of eigenvalues
    D = np.diag(real_eigenvalues)
    
    # The columns of eigenvectors are the eigenvectors
    P = eigenvectors
    
    # Compute P inverse
    P_inv = np.linalg.inv(P)
    
    return P, D, P_inv

# Example usage
A = np.array([[1, 2], [2, 1]])
P, D, P_inv = diagonalize(A)


rprim_str = parse_args()
rprim = reshape_rprim(rprim_str)
if has_orthogonal_rows(rprim):
    P, D, P_inv = diagonalize(rprim)
    for row in D:
        print(" ".join(f"{x.real:.10f}" for x in row))
else:
    for row in rprim:
        print(" ".join(f"{x:.10f}" for x in row))

