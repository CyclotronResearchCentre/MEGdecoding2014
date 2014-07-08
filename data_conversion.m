%% Conversion script
% First create a basic FT data structure, then convert it into SPM format.
% Code based on SPM's example script spm_eeg_convert_arbitrary_data.m, then
% adding more steps.
%
% I. Overall steps for a single subject:
%---------------------------------------
% 1. turn raw mat files into SPM-meeg objects and define all the key
%    properties: channels (nale, type, position in 2D) and events.
% 2. Export data into images, 1xMAG and 2xGRAD for all events
% 2b. Combine the 2xGRAD into a single nGRAD, taking the norm of the two
%      GRAD images at each sensor/voxel
% 3. Average across all events the MAG images
% 3b. What to do with GRAD images? 
%      - Average the original -> mGRAD, then take the norm of the pair of
%        mGRAD images -> nmGRAD, or
%      - Average the nGRAD images -> mnGRAD
%     The former (nmGRAD) is probably a better option
%
% 
% II. Steps for across subjects analysis:
%----------------------------------------
% - Compare the mean images mMAG and nmGRAD across the subject and try to
%   realign
%   -> use the coreg function? Take care of the masking?
% - Other option is to go directly for multi-subject classification and see
%   how it rates with respect with the other submitted results.
% - need to rescale data (each event) or z-transform the data, using the
%   pre-stimulus signal? -> this can be done preferably before image
%   transformation. But what to do with GRAD data?



%% List of files to convert
% Main directory
Dmain = '/Users/chrisp/Documents/MATLAB/3_Data/DecMEG2014/data/';
% List of subject's raw data (mat file) to process
P_dat = {...
    'train_subject01.mat'};
% P_dat = {...
%     'train_subject01.mat';
%     'train_subject02.mat';
%     'train_subject03.mat';
%     'train_subject04.mat'};
N_dat = numel(P_dat);

%  Some defintions
def_Nchannels = 306;
def_Nsamples  = 375;


%% Create channel template file: 
%   Nchannels, Cnames, Cpos (2 x Nchan, [.05 .95]), Rxy
Nchannels = def_Nchannels;
Cnames = cell(Nchannels,1);
Cind = 0;
for ii=1:26
    if ii==8, Njj = 2; else Njj = 4; end;
    for jj=1:Njj
        for kk=1:3
            Cind = Cind+1;
            if ii<10
                Cnames{Cind} = sprintf('MEG 0%d%d%d',ii,jj,kk);
            else
                Cnames{Cind} = sprintf('MEG %d%d%d',ii,jj,kk);
            end
        end
    end
end
% rescaling Cpos
Cpos = Cpos_MEG;
% fplot(Cpos(:,1),Cpos(:,2),'.')
mM_X = [min(Cpos(:,1)) max(Cpos(:,1))];
mM_Y = [min(Cpos(:,2)) max(Cpos(:,2))];
dX = diff(mM_X); midX = mM_X(1)+dX/2;
dY = diff(mM_Y); midY = mM_Y(1)+dY/2;
Cpos(:,1) = (Cpos(:,1)-midX)/dX*.95+.5;
Cpos(:,2) = (Cpos(:,2)-midY)/dY*.95+.5;
Cpos = Cpos';
Rxy = 1.5;
% fplot(Cpos(:,1),Cpos(:,2),'.')
fn_chanTemp = 'decMEG_chanTemplate';
save(fn_chanTemp,'Nchannels','Cnames','Cpos','Rxy')

%% LOOP over datafiles.
for ii=1:N_dat
    
    % Load data & permute directions.
    %----------------------------------------------------------------------
    load(fullfile(Dmain,P_dat{ii}))
    data = permute(X,[2 3 1]);
    
    % Some details about the data
    %----------------------------------------------------------------------
    Nchannels = size(data,1);
    Nsamples  = size(data,2);
    if Nchannels~=def_Nchannels || Nsamples~=def_Nsamples
        error('Wrong data size')
    end
    
    Ntrials   = size(data,3);
    TimeOnset = tmin; % in sec
    Fsample = sfreq;
    
    % NEED to define channel names properly
    % Just giving it numbers right now.
    chlabels = cellstr(num2str((1:Nchannels)'));
    
    % define the output file name
    %----------------------------------------------------------------------
    if ii<10
        fname = sprintf('train_subj_0%d',ii);
    else
        fname = sprintf('train_subj_%d',ii);
    end
    
    % create the time axis (should be the same for all trials)
    %----------------------------------------------------------------------
    timeaxis = [0:(Nsamples-1)]./Fsample + TimeOnset;
    
    % Create the Fieldtrip raw struct
    %----------------------------------------------------------------------
    
    ftdata = [];
    
    for jj = 1:Ntrials
        ftdata.trial{jj} = squeeze(data(:, :, jj));
        ftdata.time{jj} = timeaxis;
    end
    
    ftdata.fsample = Fsample;
    ftdata.label = chlabels;
    ftdata.label = ftdata.label(:);
    
    % Convert the ftdata struct to SPM M\EEG dataset
    %----------------------------------------------------------------------
    D = spm_eeg_ft2spm(ftdata, fname);
    
    % NEED to add relevant informations!
    %----------------------------------------------------------------------
    D = type(D, 'evoked');                       % Sets the dataset type
    D = chantype(D, 1:3:Nchannels, 'MEGMAG');    % Sets the channel type
    D = chantype(D, 2:3:Nchannels, 'MEGGRAD');   % Sets the channel type
    D = chantype(D, 3:3:Nchannels, 'MEGGRAD');   % Sets the channel type
    D = chanlabels(D,1:Nchannels,Cnames); % Sets channel labels
    D = conditions(D, find(y),  'Face');  % Sets the condition Face
    D = conditions(D, find(~y), 'ScrF');  % Sets the condition ScrF
    save(D);
        
    % Fix channel names and locations
    %----------------------------------------------------------------------
    S = struct(...
        'D', D,...
        'task', 'loadtemplate',...
        'P', fn_chanTemp,...
        'save',1);
    D = spm_eeg_prep(S);    

    % save and move to subject directory
    %----------------------------------------------------------------------
    save(D);
    Dsubj_ii = fullfile(Dmain,spm_str_manip(P_dat{ii},'r'));
    if ~exist(Dsubj_ii,'dir')
        mkdir(Dsubj_ii)
    end
    D = move(D,Dsubj_ii);

    %% TO DO
    % Do averaging across all events 
    %   NOTE: cannot average across conditions, so no need to do it in
    %   siganl space.
    % Export into images, single events & global average, MAG + 2xGRAD
    %   -> float32 images
    % Need to average images: take all images -> create mean response image
    % What to do with GRAD data? 
    %   -> take the norm of the 2 components?
    
    % Image conversion
    %----------------------------------------------------------------------
    S.D = D;
    S.mode = 'scalp x time';
    chan_order = {'MEG', 'GRAD2', 'GRAD3'};
    chan_select = {'MEGMAG','regexp_^MEG.*2$','regexp_^MEG.*3$'};
    prefix_types = {'MegMag_','MegGrad2_','MegGrad3_'};

    for jj=1:3
        fprintf('\nExporting channel type : %s',chan_order{jj});
        S.channels = chan_select{jj};
        S.prefix = prefix_types{jj};
        images = spm_eeg_convert2images(S);    
    end
    fprintf('\n')
    
end




return

% %% Create channel template file: 
% %   Nchannels, Cnames, Cpos (2 x Nchan, [.05 .95]), Rxy
% 
% Nchannels = 306;
% 
% % Create channel names
% Cnames = cell(Nchannels,1);
% Cind = 0;
% for ii=1:26
%     if ii==8, Njj = 2; else Njj = 4; end;
%     for jj=1:Njj
%         for kk=1:3
%             Cind = Cind+1;
%             if ii<10
%                 Cnames{Cind} = sprintf('MEG 0%d%d%d',ii,jj,kk);
%             else
%                 Cnames{Cind} = sprintf('MEG %d%d%d',ii,jj,kk);
%             end
%         end
%     end
% end
% Rxy = 1.5;
% 
% % rescaling Cpos
% Cpos = Cpos_MEG;
% % fplot(Cpos(:,1),Cpos(:,2),'.')
% mM_X = [min(Cpos(:,1)) max(Cpos(:,1))];
% mM_Y = [min(Cpos(:,2)) max(Cpos(:,2))];
% dX = diff(mM_X); midX = mM_X(1)+dX/2;
% dY = diff(mM_Y); midY = mM_Y(1)+dY/2;
% Cpos(:,1) = (Cpos(:,1)-midX)/dX*.95+.5;
% Cpos(:,2) = (Cpos(:,2)-midY)/dY*.95+.5;
% % fplot(Cpos(:,1),Cpos(:,2),'.')
% 
% save decMEG_chanTemplate Nchannels Cnames Cpos Rxy


