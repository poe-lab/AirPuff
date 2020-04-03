function airPuffSleepDeprivationWithFullAutoScorer  % Define all variables
% Dialog box to enter the channel number of the EMG to be analyzed:
EMG_acq_ent = [];
while isempty(EMG_acq_ent)
    prompt={'Enter CSC # to be used for EMG:'};
    dlgTitle='EMG Channel Select';
    lineNo=1;
    answer = inputdlg(prompt,dlgTitle,lineNo);
    EMG_acq_ent = str2double(answer{1,1});
    clear answer prompt dlgTitle lineNo
end
EMGTargetCSCString = ['CSC' num2str(EMG_acq_ent)];

% Dialog box to enter the channel number of the EEG to be analyzed:
EEG_acq_ent = [];
while isempty(EEG_acq_ent)
    prompt={'Enter CSC # to be used for primary EEG:'};
    dlgTitle='Primary EEG Channel Select';
    lineNo=1;
    answer = inputdlg(prompt,dlgTitle,lineNo);
    EEG_acq_ent = str2double(answer{1,1});
    clear answer prompt dlgTitle lineNo
end
EEGTargetCSCString = ['CSC' num2str(EEG_acq_ent)];

% Question box for adding another EEG signal:
addEegChoice = questdlg('Would you like to add a second EEG signal?',...
            'Additional EEG', 'Yes', 'No','No');
% If the user chooses 'Yes', this box appears to select the source of the
% second EEG signal:
EEG2_acq_ent = [];
switch addEegChoice
    case 'Yes'
        while isempty(EEG2_acq_ent)
            prompt={'Enter CSC # to be used for secondary EEG:'};
            dlgTitle='Secondary EEG Channel Select';
            lineNo=1;
            answer = inputdlg(prompt,dlgTitle,lineNo);
            EEG2_acq_ent = str2double(answer{1,1});
            clear answer prompt dlgTitle lineNo 
        end
        EEG2TargetCSCString = ['CSC' num2str(EEG2_acq_ent)];
    case 'No'
        EEG2TargetCSCString = 'None';
end
Thresholds = [];
% Thresholds(1) = EMG; Thresholds(2) = Delta; Thresholds(3) = Theta;
% Thresholds(4) = Sigma; Thresholds(5) = SigmaSD

choice = questdlg('Do you have threshold values, or do you need to train the Auto-Scorer?',...
            'Threshold Entries', 'Enter Thresholds','Train Auto-Scorer','Train Auto-Scorer');

% Handle response
switch choice
    case 'Enter Thresholds'
        def = {'','','','','','',''};
        while thresholdStatus < 7 %#ok<NODEF>
            thresholdStatus = 0;
            % Dialog box to enter the power thresholds for auto-scoring:
            prompt = {'Enter EMG Threshold:','Enter SxT Threshold:','Enter D/T Threshold:',...
                'Enter Delta Threshold:','Enter Theta Threshold:',...
                'Enter Sigma Threshold:','Enter Sigma Standard Deviation:'};
            dlg_title = 'Auto-scoring Thresholds';
            lineNo = 1;

            answer = inputdlg(prompt,dlg_title,lineNo,def);
            def = answer';
            for i = 1:7 %Get all of the entered threshold values and make sure they are numbers.
                if isequal(answer{i,1}, '') %Check to see if empty threshold box
                elseif isnan(str2double(answer{i,1}))   %Check to see if not a number
                else
                    Thresholds(i) = str2double(answer{i,1});    %#ok<AGROW> %It is a number, so add to threshold vector
                    thresholdStatus = thresholdStatus + 1;
                end
            end
            clear answer prompt dlgTitle lineNo
        end
        
    case 'Train Auto-Scorer'
        Thresholds = thresholdTrainingProgramForFullAutoScoring(EMGTargetCSCString, EEGTargetCSCString, EEG2TargetCSCString);
end

unhookedThreshold = 0.001;
choiceSaveThresholds = questdlg('Save threshold values?', '',...
         'Yes','No','Yes');

switch choiceSaveThresholds
    case 'Yes'
        %Request user input to name time stamp file:
        prompt = {'File name for threshold values:'};
        def = {'SubjectNumber'};
        dlgTitle = 'Save Threshold Settings';
        lineNo = 1;
        answer = inputdlg(prompt,dlgTitle,lineNo,def);
        filename = char(answer(1,:));
        dateString = date;
        thresholdFilename = strcat('C:\SleepData\', filename, dateString, '.xls');

        thresholdArray = {'Threshold Settings for 2 second epochs', dateString;...
            'EMG:', Thresholds(1); 'Sigma*Theta:', Thresholds(2); 'Delta/Theta:', Thresholds(3);...
            'Delta:',Thresholds(4); 'Theta:', Thresholds(5); 'Sigma:', Thresholds(6);...
            'Sigma Std Dev:', Thresholds(7); 'Unhooked:', unhookedThreshold};

        xlswrite(thresholdFilename,thresholdArray)
        clear prompt def dlgTitle lineNo answer filename thresholdFilename thresholdArray
    case 'No'
        % Continue to experiment phase.
end
clear choiceSaveThresholds

choice2 = questdlg('Begin Experiment?', '',...
         'Continue','Exit','Continue');

% Handle response
switch choice2
  case 'Exit' % User chose to exit the program after determining thresholds
        msgbox('The program was terminated by the user before beginning the experiment.');
  case 'Continue'
    % Define constants:
    deprivationTime = [];
    % Set to the amount of time in seconds you want to run the program.
    while isempty(deprivationTime)
        prompt={'Enter deprivation time in seconds:'};
        dlgTitle='Deprivation Time';
        lineNo=1;
        answer = inputdlg(prompt,dlgTitle,lineNo);
        deprivationTime = str2double(answer{1,1});
        clear answer prompt dlgTitle lineNo
    end
    
    Fs= 1024; % This is a constant for this program.
    
    % EEG bandwidths:
    D_lo = 0.4; % Specify low end of Delta band
    D_hi = 4.9; % Specify high end of Delta band
    T_lo = 5; % Specify low end of Theta band
    T_hi = 9;   % Specify high end of Theta band
    S_lo = 10; % Specify low end of Sigma band
    S_hi = 14;  % Specify high end of Sigma band
    
    % EEG filter set:
    EEG_Fc = 30; % The EEG low-pass cut-off frequency. Default is 30 Hz.
    EEG_highpass_enable = 0; % Set to '0' to turn off high-pass filter, '1' to turn on.
    EEG_HP_Fc = 1; % The EEG high-pass cut-off frequency. Default is 1 Hz.
    EEG_Notch_enable = 0; % Set to '0' to turn off notch filter, '1' to turn on.

    % EMG filter set:
    EMG_Fc = 30; % The EMG high-pass cut-off frequency. Default is 30 Hz.
    EMG_Notch_enable=0; % Set to '0' to turn off notch filter, '1' to turn on.
    EMG_lowpass_enable=0;  % Set to '0' to turn off low-pass filter, '1' to turn on.
    
    % State vectors:
    tenSecStates = [1 1 1 0 1]; %This is setting up the history for start of 
    tenSecSleep = [0 0 0 0 0]; %the program for the 10 seconds prior to programs start.
    %real3EpochHistory = [0 0 0];  % This information is needed in the auto-scoring algorithm.
    autoScoredEpochs = [];  % Record the auto-scored epochs and save at end of program.
    
    count = 0; shortData = 0;
    
    % Establish Neuralynx router connection:
    serverName = '141.214.56.56';  % Name or IP of the computer running Cheetah
    disp(sprintf('Connecting to %s...', serverName));  %Status display
    succeeded = NlxConnectToServer(serverName);  % Checks to see if connected successfully
    %Every NetCom function returns a value indicating if the command succeeded (Yes=1, No=0).

    if succeeded ~= 1
        disp(sprintf('FAILED connect to %s. Exiting script.', serverName));
        return;
    else
        disp(sprintf('Connect successful.'));
    end

    serverIP = NlxGetServerIPAddress();
    disp(sprintf('Connected to IP address: %s', serverIP));

    serverPCName = NlxGetServerPCName();
    disp(sprintf('Connected to PC named: %s', serverPCName));

    serverApplicationName = NlxGetServerApplicationName();
    disp(sprintf('Connected to the NetCom server application: %s', serverApplicationName));

    %Identify this program to the server we're connected to.
    succeeded = NlxSetApplicationName('Real-Time Sleep Deprivation via Air Puff');
    if succeeded ~= 1
        disp 'FAILED set the application name'
    else
        disp 'PASSED set the application name'
    end

    % Get a list of all objects in Cheetah, along with their types.
    [succeeded, cheetahObjects, cheetahTypes] = NlxGetCheetahObjectsAndTypes;
    if succeeded == 0
        disp 'FAILED get cheetah objects and types'
    else
        disp 'PASSED get cheetah objects and types'
    end

    % Find index of target CSCs in 'CheetahObjects'
    EEGCscIndex = find(strcmp(EEGTargetCSCString,cheetahObjects) == 1);
    EMGCscIndex = find(strcmp(EMGTargetCSCString,cheetahObjects) == 1);
    
    % Open up a stream for target EEG CSC
    succeeded = NlxOpenStream(cheetahObjects(EEGCscIndex));
    if succeeded == 0
        disp(sprintf('FAILED to open stream for %s', char(cheetahObjects(EEGCscIndex))));
    end

    if succeeded == 1
        disp 'PASSED open stream for EEG object'
    end

     % Open up a stream for target EMG CSC
    succeeded = NlxOpenStream(cheetahObjects(EMGCscIndex));
    if succeeded == 0
        disp(sprintf('FAILED to open stream for %s', char(cheetahObjects(EMGCscIndex))));
    end

    if succeeded == 1
        disp 'PASSED open stream for EMG object'
    end
    
    %Retrieve EEG AD Bit Value and convert user-set threshold to AD Bit Volts.
    [succeeded, EegADBitValue] = NlxSendCommand(['-GetADBitVolts ' EEGTargetCSCString]);
    EegADBitValue =str2double(char(EegADBitValue(1)));  % Converts from a string to a number
    EegADBit2uV = EegADBitValue * 10^6;
    clear EegADBitValue
    if succeeded == 1
        disp 'Retrieved EEG A/D Bit Value'
    end
    
    %Retrieve EMG AD Bit Value and convert user-set threshold to AD Bit Volts.
    [succeeded, EmgADBitValue] = NlxSendCommand(['-GetADBitVolts ' EMGTargetCSCString]);
    EmgADBitValue =str2double(char(EmgADBitValue(1)));  % Converts from a string to a number
    EmgADBit2uV = EmgADBitValue * 10^6;
    clear EmgADBitValue
    if succeeded == 1
        disp 'Retrieved EMG A/D Bit Value'
    end
    
    % Post an event to the Event Log for start of sleep deprivation.
    [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Beginning Sleep Deprivation" 10 11');
    % You can use NlxSendCommand to send any Cheetah command to Cheetah.
    if succeeded == 0
        disp 'FAILED to send command'
    else
        disp 'PASSED send command'
    end  

    %objectToRetrieve = char(cheetahObjects(EEG_acq_ent));
    % Pull in streaming CSC data and related recording info.
    [succeeded,~, ~, ~, samplingFreqArray, ~, ~, ~ ] = NlxGetNewCSCData(EEGTargetCSCString);
    if succeeded == 0
        disp(sprintf('FAILED to get sampling frequency'));
        %break;
    else
        disp(sprintf('Sampling frequency is %d' ,samplingFreqArray(1)));
    end
    
    % Note that the program is assuming the EEG and EMG signals have the
    % same sampling rate.
    samplingFreqArray = double(samplingFreqArray);
    data2SecLength = (2 * samplingFreqArray(1))-1;   % Finds length of data vector = 2 sec
    [bLowEEG,aLowEEG] = ellip(7,1,60, EEG_Fc/(samplingFreqArray(1)/2)); 
    [bLowEMG,aLowEMG] = ellip(7,1,60, EMG_Fc/(samplingFreqArray(1)/2));
    
    %This loop is run to get new data from NetCom.  All open streams must be
    %servised regularly, or there will be dropped records.
    warning('off', 'signal:spectrum:obsoleteFunction');
    runningTime = 0; % Initiate the variable for testing length of time the program has been running.
    tic  % Initiate stopwatch
    while runningTime <deprivationTime    %  Check if the program has reached the stop time.
        %isequal(endProgram, 1)    % Continue to run until endProgram = 0.  Change value at command line.
            %determine the type of acquisition entity we are currently indexed
            %to and call the appropriate function for that type
        %tic % Start timer

        % Pull in streaming CSC data and related recording info.
        [EEGsucceeded,EEGdataArray, ~, ~, ~, ~, ~, ~ ] = NlxGetNewCSCData(EEGTargetCSCString);
        [EMGsucceeded,EMGdataArray, ~, ~, ~, ~, ~, ~ ] = NlxGetNewCSCData(EMGTargetCSCString);
%         [succeeded,dataArray, ~, ~, ~,...
%             numValidSamplesArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewCSCData(TargetCSCString);
        if isequal(EEGsucceeded,0)
            disp(sprintf('FAILED to get new data for EEG CSC stream %s on pass %d', EEGTargetCSCString, pass));
        elseif isequal(EMGsucceeded,0)
            disp(sprintf('FAILED to get new data for EMG CSC stream %s on pass %d', EMGTargetCSCString, pass));
        elseif length(EEGdataArray) < (data2SecLength + 1) || length(EMGdataArray) < (data2SecLength + 1)
            shortData = shortData + 1
            pause(2);

        else
            %disp(sprintf('Retrieved %d CSC records for %s with %d dropped.', numRecordsReturned, objectToRetrieve, numRecordsDropped));

    %Here is where you'll perform some calculation on any of the returned values.
    %Make sure any calculations done here don't take too much time, otherwise 
    %NetCom will back up and you will have dropped records.

            twoSecBinEEG = EEGdataArray(end - data2SecLength:end);  %Extracts last 2 sec of EEG data pulled in
            clear EEGdataArray
            twoSecBinEMG = EMGdataArray(end - data2SecLength:end);  %Extracts last 2 sec of EMG data pulled in
            clear EMGdataArray
            
            % Apply filters to EEG and EMG signals:
            twoSecBinEEG = double(twoSecBinEEG'); % Applied if streamed same as recorded in CSC file.
%             twoSecBinEEG=filter(bLowEEG,aLowEEG,twoSecBinEEG);
            
            twoSecBinEMG = double(twoSecBinEMG'); % Applied if streamed same as recorded in CSC file.
%             twoSecBinEMG=filter(bLowEMG,aLowEMG,twoSecBinEMG);
            
            %  OPTIONAL highpass filter for EEG signals
            % if isequal(EEG_highpass_enable, 1)
            %     [bHigh,aHigh] = ellip(7,1,60, EEG_HP_Fc/(samplingFreqArray(1)/2),'high');
            %     twoSecBinEEG = filter(bHigh,aHigh, twoSecBinEEG);
            % end

            %  OPTIONAL 60Hz Notch filter for EEG signals
            % if isequal(EEG_Notch_enable, 1)
            %     wo = 60/(samplingFreqArray/2);
            %     [bNotch,aNotch] =  iirnotch(wo, wo/35);
            %     twoSecBinEEG = filter(bNotch,aNotch, twoSecBinEEG);
            % end
            downSamplingFactor = round(samplingFreqArray(1)/Fs); % This is used to down-sample 
            %the data if the sampling frequency in Cheetah cannot be set to 1024Hz.
            
            % Down-sample if required:
            if downSamplingFactor > 1
                twoSecBinEEG = twoSecBinEEG(1:downSamplingFactor:end);
                twoSecBinEMG = twoSecBinEMG(1:downSamplingFactor:end);
            end
            
            % Convert EEG and EMG to Volts:
            twoSecBinEEG = twoSecBinEEG*EegADBit2uV;
            twoSecBinEMG = twoSecBinEMG*EmgADBit2uV;
            
            % Apply algorithm to determine if animal has been sleeping for 10 seconds.
            
            % This is taking integral in time domain of the EMG  
            absVj=abs(twoSecBinEMG).^2; % absolute square????????????????
            powerEMG = sum(absVj)/length(absVj);  % sum of all squared Vj's
            
            % Calculate FFT of EEG
             % This is calculating power in frequency domain
            windowsize =length(twoSecBinEEG);
            
            % Power spectral analysis on the EEG signal:
            [Pxx2,F2]=spectrum(twoSecBinEEG,windowsize,0,ones(windowsize,1),Fs);
            % ******  [P,F] = SPECTRUM(X,NFFT,NOVERLAP,WINDOW,Fs)

            %For the EEG signal
            index_delta=[];index_theta=[];index_sigma=[];
            index_delta=find(F2(1)+D_lo< F2 & F2 < F2(1)+D_hi);      % Default delta band 0.4 -4 Hz
            index_theta=find(F2(1)+T_lo< F2 & F2 < F2(1)+T_hi);    % Default theta band 5-9 Hz
            index_sigma=find(F2(1)+S_lo< F2 & F2 < F2(1)+S_hi);     % Default sigma band 10-14 Hz

            deltaPower = sum(Pxx2(index_delta))/windowsize *2;
            thetaPower = sum(Pxx2(index_theta))/windowsize *2;
            sigmaPower = sum(Pxx2(index_sigma))/windowsize *2;
            clear index_delta index_theta index_sigma
            
            st_power = abs(sigmaPower * thetaPower);   % Used to indicate waking
            dt_ratio = abs(deltaPower/thetaPower); 

            % FULL AUTOSCORER LOGIC
            tempState = 2;  % Set the default state as QS.

            % Score epochs either as REM or QS depending on their DT ratio and EMG
            if dt_ratio < Thresholds(3) && powerEMG < Thresholds(1)
                tempState = 3;  % Change the state to REM.
            end
    
            % WAKING decision point
            if powerEMG > Thresholds(1) && st_power < Thresholds(2)
            % Now from all those epochs which can be termed as QW/ AW based on
            % STthresh
                tempState = 1;  % Change the state to AW.
            end

            % Check if the threshold is given & then look for the UNhooked epochs  
            % The logic in this section is not performed if no threshold is entered.
            if isempty(unhookedThreshold)==0  
                if powerEMG < 1 && st_power < unhookedThreshold
                    tempState = 5;
                end
            end
 
            % For absolute detection of AW states from states with very high EMG as
            % well as high Sigma * Theta value which are scored as QS before this
            if isequal(tempState,2)
                if powerEMG > Thresholds(1) && st_power > Thresholds(2)
                    tempState = 1;  % Change to AW
                else
                    % Check if they have low D/T power and should be REM
                    if dt_ratio < Thresholds(3) && powerEMG < (1.1*Thresholds(1));
                        tempState = 3;  % Change to REM
                    end
                end
            end
    
            % Check if there are any TR state within QS states
            if isequal(tempState,2)
%                 if st_power > (5*averageSTpower)    % + 10*StdDevforAverageSTpower));
%                     tempState = 6;  % Change to TR
%                 end
                %Original published logic:
                if sigmaPower > (Thresholds(6) + 2*Thresholds(7))  % This line is in the analysis of 1 s epochs.
                    % The multiplier is 3SD in 10s epochs.
                    tempState = 6;  % Change to TR
                end

            end             

    % To see if there is any QW within the AW or QS states by checking
    % their sigma, delta and theta levels. They should be below the
    % threshold set by the user
            if isequal(tempState,1) || (isequal(tempState,2) && deltaPower < Thresholds(4))
                if thetaPower < Thresholds(5) && sigmaPower < Thresholds(6)
                    if powerEMG < 2.5*Thresholds(1)
                        tempState = 4;  % Change to QW.  This logic may need to be reviewed.
                    end
                end
            end
    
            % For absolute REM detection with the REM states
            if isequal(tempState,3)
                %Change from REM to Qiuet Wake if the last three epochs were AW (=1) or
                %QW (=4)
                if isequal(tenSecStates(3:5), [1 1 1])
                    tempState = 4;
                end
            end
            
        % This will not be used unless we want to add new logic to make IW 
        % detection a determinant for another state.
            if isequal(tempState,4)
                if thetaPower > Thresholds(5)
                    % Change to Intermediate Wake (IW) for correction.
                    tempState = 8;
                end
            end
            
            %Save the auto-scored state
            autoScoredEpochs = [autoScoredEpochs; tempState];
            
%This is the END of the auto-scoring component.  Now set the sleep/wake
%value in the 'tenSecStates' vector for the air puff logic.
            % Determine state via logic.
            % State = 0 is asleep, State = 1 is awake
            % Push-Pop states.
            switch tempState
                case 1
                    tenSecStates = [tenSecStates(2:5) 1]; %Scored as AWAKE.
                case 2
                    tenSecStates = [tenSecStates(2:5) 0]; %Scored as ASLEEP.
                case 3
                    tenSecStates = [tenSecStates(2:5) 0]; %Scored as ASLEEP.
                case 4
                    tenSecStates = [tenSecStates(2:5) 1]; %Scored as AWAKE.
                case 5
                    tenSecStates = [tenSecStates(2:5) 1]; %Scored as AWAKE.
                case 6
                    tenSecStates = [tenSecStates(2:5) 0]; %Scored as ASLEEP.
                % case 7 will not occur since the epoch will always be
                % scored.
                case 8
                    tenSecStates = [tenSecStates(2:5) 1]; %Scored as AWAKE.
            end
   
            if isequal(tenSecStates,tenSecSleep)
                %Trigger air puff through Cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-DigitalIOTtlPulse PCI-DIO24_0 0 0 High');
                %Send event to Cheetah
                %[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "10 sec sleep detected" 10 11');
                if succeeded == 0
                    disp 'FAILED to send command'
    %             else
    %                 disp 'PASSED send command'
                end
                %Should there be a delay before next puff?  I can use ones in the
                %'tenSecStates' to cause a delay.
                tenSecStates = [1 1 0 0 0]; %Each leading 1 in the vector represents 
                % a 2 second delay before the next possible air puff.

            end
            runningTime = toc;  % See how long program has been running.
        end

        pause(1.75); %1/22 errors for 1.5s
        %toc %End timer
        %plot(twoSecBinEEG);
        count = count + 1;
    end

    pause(3);

    %close all open streams before disconnecting
    succeeded = NlxCloseStream(EEGTargetCSCString);
    if isequal(succeeded, 0)
        disp(sprintf('FAILED to close stream for %s', EEGTargetCSCString)); %#ok<*DSPS>
    else
        disp 'PASSED close EEG stream'
    end
    
    succeeded = NlxCloseStream(EMGTargetCSCString);
    if isequal(succeeded, 0)
        disp(sprintf('FAILED to close stream for %s', EMGTargetCSCString)); %#ok<*DSPS>
    else
        disp 'PASSED close EMG stream'
    end


    %Disconnects from the server and shuts down NetCom
    succeeded = NlxDisconnectFromServer();
    if succeeded ~= 1
        disp 'FAILED disconnect from server'
    else
        disp 'PASSED disconnect from server'
        msgbox('The program has run successfully.');
    end
end
%remove all vars created in this test script
clear
end