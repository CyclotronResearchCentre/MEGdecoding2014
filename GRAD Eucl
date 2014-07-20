% Main directory
clc; clear
Wdir = '/home/antogeo/Documents/Projects/DecMEG2014/data/data/';
 
for i = 1 : 16
    % make a string corresponding to the subject number
    if i < 10, num = strcat('0', int2str(i)); else num = int2str(i); end
    % path and subject name to be read
    Fold_Grad2 = strcat(Wdir,'MegGrad2_train_subject', num);
    Fold_Grad3 = strcat(Wdir,'MegGrad3_train_subject', num);
    Fold_Mag = strcat(Wdir,'MegMag_train_subject', num);
    % Faces
    % Vi = input names
    Vi = { strcat(Fold_Grad2, '/condition_Face.nii' )
           strcat(Fold_Grad3, '/condition_Face.nii' )
           strcat(Fold_Mag,   '/condition_Face.nii' )
        };
    % Vo = ouput folder and name
    Vo = strcat(Wdir, 'train_subject', num, '/', 'Eucl_Face', num , '.nii,1' );
    spm_imcalc(Vi, Vo, 'sqrt((i1 .* i1) + (i2 .* i2))');
    % ScrF
    % Vi = input names
    Vi = { strcat(Fold_Grad2, '/condition_ScrF.nii' )
           strcat(Fold_Grad3, '/condition_ScrF.nii' )
           strcat(Fold_Mag,   '/condition_ScrF.nii' )
        };
    % Vo = ouput folder and name
    Vo = strcat(Wdir, 'train_subject', num, '/', 'Eucl_ScrF', num , '.nii,1' );
    spm_imcalc(Vi, Vo, 'sqrt((i1 .* i1) + (i2 .* i2))');  
end
