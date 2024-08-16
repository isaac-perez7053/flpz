import numpy as np

ORIGINALCELL

TARGETCELL

def transformCell_Map():

    # Make lists of all the positions corresponding to each element type for the Gamma cell
    Gamma_posfrac_Ca = Gamma_posfrac[0:1, :]
    Gamma_posfrac_Ti = Gamma_posfrac[1:2, :]
    Gamma_posfrac_O = Gamma_posfrac[2:5, :]

    # Store those in a list
    Gamma_posCell = [Gamma_posfrac_Ca, Gamma_posfrac_Ti, Gamma_posfrac_O]

    # Make lists of all the positions corresponding to each element type for the target cell
    Target_posfrac_Ca = Target_posfrac[0:2, :]
    Target_posfrac_Ti = Target_posfrac[2:4, :]
    Target_posfrac_O = Target_posfrac[4:10, :]

    Target_posCell = [Target_posfrac_Ca, Target_posfrac_Ti, Target_posfrac_O]

    # Make supercell that extends from -3 to 3 in each direction
    atomSuperCell = []
    aTest = []
    dimSize = 3
    for aType in range(len(Gamma_posfrac)):
        madeSuper = []
        xStencil = np.array([1, 0, 0])
        yStencil = np.array([0, 1, 0])
        zStencil = np.array([0, 0, 1])
        for xdim in range(-dimSize, dimSize + 1):
            for ydim in range(-dimSize, dimSize + 1):
                for zdim in range(-dimSize, dimSize + 1):
                    shiftedPos = Gamma_posfrac[aType] + xdim * xStencil + ydim * yStencil + zdim * zStencil
                    madeSuper.append(shiftedPos)
        atomSuperCell.append(np.array(madeSuper))
        aTest.extend(madeSuper)

    aTest = np.dot(np.array(aTest), GammaCell)

    Mapping = np.zeros(len(Target_posfrac), dtype=int)
    outDiff = np.zeros_like(Target_posfrac)

    tolerance = 0.2  # angstroms, tolerance to match atoms
    for aType in range(len(Gamma_posfrac)):
        thisAtom_orig = atomSuperCell[aType]
        for a, atomVec in enumerate(np.dot(thisAtom_orig, GammaCell)):
            for at, atomTargetVec in enumerate(np.dot(Target_posfrac, TargetCell)):
                if np.linalg.norm(atomVec - atomTargetVec) < tolerance:
                    Mapping[at] = aType + 1  # +1 because Python is 0-indexed
                    print(f"atom type {aType + 1} matches in supercell atom {at + 1}")
                    outDiff[at] = atomVec - atomTargetVec

    return Mapping, outDiff

# Call the function and print the results
Mapping, outDiff = transformCell_Map()
print("Mapping:")
print(Mapping)

# I'm not sure if the outdiff works yet
print("\noutDiff:")
print(outDiff)

# Example usage:
# ORIGINALCELL and TARGETCELL should be defined before calling the function
# Gamma_posfrac and Target_posfrac should also be defined
# Mapping, outDiff = transformCell_Map(ORIGINALCELL, TARGETCELL)
