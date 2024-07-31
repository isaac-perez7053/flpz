#!/usr/bin/env python3
import numpy as np
import sys
import ast
np.set_printoptions(precision=10)

def parse_vector(vector_str):
    """Convert string representation of vector to numpy array."""
    try:
        vector = ast.literal_eval(vector_str)
        return np.array(vector)
    except:
        print(f"Error: Unable to parse vector {vector_str}")
        sys.exit(1)

def unit_vector(vector):
    """Returns the unit vector of the vector."""
    return vector / np.linalg.norm(vector)

def angle_between(v1, v2):
    """Returns the angle in radians between vectors 'v1' and 'v2'."""
    v1_u = unit_vector(v1)
    v2_u = unit_vector(v2)
    return np.arccos(np.clip(np.dot(v1_u, v2_u), -1.0, 1.0))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: ./findAngle.py <vector1> <vector2>")
        sys.exit(1)

    var1 = parse_vector(sys.argv[1])
    var2 = parse_vector(sys.argv[2])

    angle = angle_between(var1, var2)
    print(f"{np.degrees(angle):.6f}")  # Print angle in degrees

