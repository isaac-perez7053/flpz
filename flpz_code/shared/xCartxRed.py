#!/usr/bin/env python3
import sys
import os
import numpy as np

def parse_args():
    if len(sys.argv) < 8:
        print("Usage: python xCartxRed.py <mode> <rprim> <xcart/xred> <acella> <acellb> <acellc> <natom>")
        sys.exit(1)
    try:
        return (sys.argv[1], sys.argv[2], sys.argv[3], 
                float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]), 
                int(sys.argv[7]))
    except ValueError as e:
        print(f"Error parsing arguments: {e}")
        sys.exit(1)

def reshape_rprimxCxR(rprim_str, xCxR_str):
    rprim_list = [float(x) for x in rprim_str.split()]
    xCxR_list = [float(x) for x in xCxR_str.split()]
    return np.array(rprim_list).reshape(3, 3), np.array(xCxR_list).reshape(int(natom), 3)

def calculateXred(rprim, xcart, a, b, c):
    # Scale the primitive vectors by acell
    rprim_scaled = rprim.copy()  # Created a copy to avoid modifying the original
    natom, num_cords = xcart.shape
    xred=np.empty((natom, num_cords))
    rprim_scaled[0] *= a
    rprim_scaled[1] *= b
    rprim_scaled[2] *= c
    for i in range(natom):
        xred[i] = np.dot(np.linalg.inv(rprim_scaled), xcart[i].T).T
    print(xred)
    return xred

def calculateXcart(rprim, xred, a, b, c): 
    # Scale the primitive vectors by acell
    rprim_scaled = rprim.copy()  # Created a copy to avoid modifying the original
    natom, num_cords = xred.shape
    xcart=np.empty((natom, num_cords))
    rprim_scaled[0] *= a
    rprim_scaled[1] *= b
    rprim_scaled[2] *= c
    for i in range(natom):  
        xcart[i] = np.dot(rprim_scaled, xred[i].T).T
    print(xcart)
    return xcart


mode, rprim_str, xCxR_str, a, b, c, natom = parse_args()
rprim, xCxR = reshape_rprimxCxR(rprim_str, xCxR_str)

if mode.lower() == "xred":
    result = calculateXred(rprim, xCxR, a, b, c)
    for row in result:
        print(" ".join(f"{x:.10f}" for x in row) + " " * (30 - len(" ".join(f"{x:.10f}" for x in row))))
elif mode.lower() == "xcart":
    result = calculateXcart(rprim, xCxR, a, b, c)
    for row in result:
        print(" ".join(f"{x:.10f}" for x in row) + " " * (30 - len(" ".join(f"{x:.10f}" for x in row))))
else:
    print("Invalid mode. Please use 'xred' or 'xcart'.")
