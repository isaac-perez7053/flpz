function Mapping=transformCell_Map()


ORIGINALCELL

TARGETCELL


%make lists of all the positions corresponding to each element type for the
%Gamma cell
Gamma_posfrac_Ca=[Gamma_posfrac(1:1,:)];
Gamma_posfrac_Ti=[Gamma_posfrac(2:2,:)];
Gamma_posfrac_O=[Gamma_posfrac(3:5,:)];

%store those in a cell array
Gamma_posCell={Gamma_posfrac_Ca,Gamma_posfrac_Ti,Gamma_posfrac_O};


%make lists of all the positions corresponding to each element type for the
%target cell
Target_posfrac_Ca=[Target_posfrac(1:2,:)];
Target_posfrac_Ti=[Target_posfrac(2:4,:)];
Target_posfrac_O=[Target_posfrac(5:10,:)];

Target_posCell={Target_posfrac_Ca,Target_posfrac_Ti,Target_posfrac_O};



%solving T*P6mmmCell=R3barmCell
%T=R3barmCell*inv(P6mmmCell)

%I think what I want to do is do everything in cartesian, expand the cell,
%then manually find things in it.

%make supercell that extends from -3 to 3 in each direction. overkill but
%should definitely be enough

atomSuperCell={};
aTest=[];
dimSize=3;
for aType=1:length(Gamma_posfrac)%(Gamma_posCell)
    madeSuper=[];
    %[L,~]=size(Gamma_posCell{aType});
    xStencil=[1,0,0];%[ones(L,1),zeros(L,2)];
    yStencil=[0,1,0];%[zeros(L,1),ones(L,1),zeros(L,1)];
    zStencil=[0,0,1];%[zeros(L,2),ones(L,1)];
    for xdim=-dimSize:dimSize
        for ydim=-dimSize:dimSize
            for zdim=-dimSize:dimSize
                shiftedPos=Gamma_posfrac(aType,:)+xdim*xStencil+ydim*yStencil+zdim*zStencil;
                madeSuper=[madeSuper;shiftedPos];
            end
        end
    end
    atomSuperCell{aType}=madeSuper;
    aTest=[aTest;madeSuper];
end


aTest=aTest*GammaCell;



Mapping=zeros(length(Target_posfrac),1);
outDiff=zeros(size(Target_posfrac));

finalDiff=[];
tolerance=.2; %angstroms, tolerance to match atoms
for aType=1:length(Gamma_posfrac)
    thisAtom_orig=atomSuperCell{aType};
    [L,~]=size(thisAtom_orig);
    [Lt,~]=size(Target_posfrac);
    
    for a=1:L
        atomVec=(thisAtom_orig(a,:)*GammaCell);%*rotMat;
        for at=1:Lt
            atomTargetVec=(Target_posfrac(at,:)*TargetCell);
            norm(atomVec-atomTargetVec);
            if norm(atomVec-atomTargetVec)<tolerance
                Mapping(at)=aType;
                disp(['atom type ', num2str(aType),' matches in supercell atom ',num2str(at)])
                outDiff(at,:)=(atomVec-atomTargetVec);
                %outDiff=[outDiff;(atomVec-atomTargetVec)];
            end
        end
    end

    %finalSuperCell=[finalSuperCell;inPos];
    %finalDiff=[finalDiff;outDiff];
end
Mapping



