function Thresholds = thresholdTrainingProgramForFullAutoScoring(EMGTargetCSCString, EEGTargetCSCString, EEG2TargetCSCString)
Fs= 1024; % This is a constant for this program.
% downSamplingFactor = round(samplingFrequency/Fs); % This is used to down-sample 
% %the data if the sampling frequency in Cheetah cannot be set to 1024Hz.

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

shortData = 0; % This is a counter to see the number of times the data is loaded too quickly.

% Establish Neuralynx router connection
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
succeeded = NlxSetApplicationName('Threshold Training Program');
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
%data2SecLength = (2 * samplingFreqArray(1))-1;   % Finds length of data vector = 2 sec
data10SecLength = (10 * samplingFreqArray(1))-1;   % Finds length of data vector = 10 sec
[bLowEEG,aLowEEG] = ellip(7,1,60, EEG_Fc/(samplingFreqArray(1)/2)); 
[bLowEMG,aLowEMG] = ellip(7,1,60, EMG_Fc/(samplingFreqArray(1)/2));

% Open stream for a second EEG signal if selected:
if isequal(EEG2TargetCSCString, 'None')
else
    EEG2CscIndex = find(strcmp(EEG2TargetCSCString,cheetahObjects) == 1);
    % Open up a stream for target EEG2 CSC
    succeeded = NlxOpenStream(cheetahObjects(EEG2CscIndex));
    if succeeded == 0
        disp(sprintf('FAILED to open stream for %s', char(cheetahObjects(EEG2CscIndex))));
    end

    if succeeded == 1
        disp 'PASSED open stream for EEG2 object'
    end
    %Retrieve EEG2 AD Bit Value and convert user-set threshold to AD Bit Volts.
    [succeeded, Eeg2ADBitValue] = NlxSendCommand(['-GetADBitVolts ' EEG2TargetCSCString]);
    Eeg2ADBitValue =str2double(char(Eeg2ADBitValue(1)));  % Converts from a string to a number
    Eeg2ADBit2uV = Eeg2ADBitValue * 10^6;
    clear Eeg2ADBitValue
    if succeeded == 1
        disp 'Retrieved EEG2 A/D Bit Value'
    end
end

%This loop is run to get new data from NetCom.  All open streams must be
%servised regularly, or there will be dropped records.
warning('off', 'signal:spectrum:obsoleteFunction');

scoredEpochsStatus = 0;  %Used to exit the following 'while' loop once enough epochs have been scored
remainingEpoch = [5 5 5 5 5];  %The # of epochs to manually score of each state [AW QW QS RE TR]
%totalTrainingEpochs = sum(remainingEpoch);  %Used to set up size of matrix for results
% trainingResults = zeros(totalTrainingEpochs, 7);  %Sets up the size of the results matrix
trainingResults = [];

while isequal(scoredEpochsStatus,0)  %  Check if the user has scored required epochs.
    % Pull in streaming CSC data and related recording info.
    [EEGsucceeded,EEGdataArray, ~, ~, ~, ~, ~, ~ ] = NlxGetNewCSCData(EEGTargetCSCString);
    [EMGsucceeded,EMGdataArray, ~, ~, ~, ~, ~, ~ ] = NlxGetNewCSCData(EMGTargetCSCString);
    
    % Pull in data for a second EEG signal if selected:
    if isequal(EEG2TargetCSCString, 'None')
        EEG2succeeded = 1;
        lengthEEG2 = data10SecLength + 1;
    else
        [EEG2succeeded,EEG2dataArray, ~, ~, ~, ~, ~, ~ ] = NlxGetNewCSCData(EEG2TargetCSCString);
        if isequal(EEG2succeeded,0)
            disp(sprintf('FAILED to get new data for EEG2 CSC stream %s on pass %d',...
                EEG2TargetCSCString, pass));
        else
            lengthEEG2 = length(EEG2dataArray);
        end
    end
    
    if isequal(EEGsucceeded,0)
        disp(sprintf('FAILED to get new data for EEG CSC stream %s on pass %d',...
            EEGTargetCSCString, pass));
    elseif isequal(EMGsucceeded,0)
        disp(sprintf('FAILED to get new data for EMG CSC stream %s on pass %d',...
            EMGTargetCSCString, pass));    
    elseif length(EEGdataArray) < (data10SecLength + 1) || length(EMGdataArray)...
            < (data10SecLength + 1) || lengthEEG2 < (data10SecLength + 1)
        shortData = shortData + 1
        pause(2);
    else            
        tenSecBinEEG = EEGdataArray(end - data10SecLength:end);  %Extracts last 10 sec of EEG data pulled in
        clear EEGdataArray
        tenSecBinEMG = EMGdataArray(end - data10SecLength:end);  %Extracts last 10 sec of EMG data pulled in
        clear EMGdataArray

        % Apply filters to EEG and EMG signals:
        tenSecBinEEG = double(tenSecBinEEG'); % Applied if streamed same as recorded in CSC file.
%         tenSecBinEEG=filter(bLowEEG,aLowEEG,tenSecBinEEG);

        tenSecBinEMG = double(tenSecBinEMG'); % Applied if streamed same as recorded in CSC file.
%         tenSecBinEMG=filter(bLowEMG,aLowEMG,tenSecBinEMG);
        
        downSamplingFactor = round(samplingFreqArray(1)/Fs); % This is used to down-sample 
        %the data if the sampling frequency in Cheetah cannot be set to 1024Hz.
        
        % Down-sample if required:
        if downSamplingFactor > 1
            tenSecBinEEG = tenSecBinEEG(1:downSamplingFactor:end);
            tenSecBinEMG = tenSecBinEMG(1:downSamplingFactor:end);
        end
        
        % Convert EEG and EMG to Volts:
        tenSecBinEEG = tenSecBinEEG*EegADBit2uV;
        tenSecBinEMG = tenSecBinEMG*EmgADBit2uV;
        
        % Isolate the target 2 second epoch that will be scored in order to
        % calculate the power for threshold settings:
        ds10SecLength = length(tenSecBinEEG);
        ds2SecLength = ds10SecLength/5;
        twoSecBinEEG = tenSecBinEEG((2*ds2SecLength+1):3*ds2SecLength);
        twoSecBinEMG = tenSecBinEMG((2*ds2SecLength+1):3*ds2SecLength);
        
        % This is taking integral in time domain of the 2 second target EMG
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
        index_delta=find(F2(1)+D_lo< F2 & F2 < F2(1)+D_hi);  % Default delta band 0.4 -4 Hz
        index_theta=find(F2(1)+T_lo< F2 & F2 < F2(1)+T_hi);  % Default theta band 5-9 Hz
        index_sigma=find(F2(1)+S_lo< F2 & F2 < F2(1)+S_hi);  % Default sigma band 10-14 Hz

        deltaPower = sum(Pxx2(index_delta))/windowsize *2;
        thetaPower = sum(Pxx2(index_theta))/windowsize *2;
        sigmaPower = sum(Pxx2(index_sigma))/windowsize *2;
        clear index_delta index_theta index_sigma

        st_power = abs(sigmaPower * thetaPower);  % Used to indicate waking
        dt_ratio = abs(deltaPower/thetaPower);

        if isequal(EEG2TargetCSCString, 'None')
            % Create a figure of the 10 second epoch of EEG
            xAxis = 0:10/(ds10SecLength-1):10; % Defines the x axis for the 10 sec epoch of data

            subplot(2,1,1); plot(xAxis,tenSecBinEMG)
            set(gca,'XTick',0:1:10)
            set(gca,'XTickLabel',{'0','1','2','3','4','5','6','7','8','9','10 seconds'})
            ylim([-200 200])
            title('EMG');
            xlabel('Time (s)');
            ylabel('Amplitude (uV)');
            scrsz = get(0,'ScreenSize');
            set(figure(1),'OuterPosition',[0 scrsz(4)/2 scrsz(3) scrsz(4)/2])

            subplot(2,1,2); plot(xAxis,tenSecBinEEG)
            set(gca,'XTick',0:1:10)
            set(gca,'XTickLabel',{'0','1','2','3','4','5','6','7','8','9','10 seconds'})
            ylim([-200 200])
            title('EEG');
            ylabel('Amplitude (uV)');
            set(figure(1),'OuterPosition',[0 scrsz(4)/2 scrsz(3) scrsz(4)/2])
            
            annotation('rectangle',[.44 .05 .155 .91],'LineStyle','-.','LineWidth',1,...
            'Color',[1 0 0]);
            
            annotation('textbox',[0.44 0.019 0.155 0.035],...
            'String',{'2 sec epoch'},...
            'HorizontalAlignment','center',...
            'FitBoxToText','off',...
            'LineStyle','none',...
            'Color',[1 0 0]);
        else
            tenSecBinEEG2 = EEG2dataArray(end - data10SecLength:end);  %Extracts last 2 sec of EEG2 data pulled in
            clear EEG2dataArray
            % Apply filters to EEG2 signal:
            tenSecBinEEG2 = double(tenSecBinEEG2'); % Applied if streamed same as recorded in CSC file.
%            tenSecBinEEG2=filter(bLowEEG,aLowEEG,tenSecBinEEG2);  % Uses same filters as primary EEG signal
            
            % Down-sample if required:
            if downSamplingFactor > 1
                tenSecBinEEG2 = tenSecBinEEG2(1:downSamplingFactor:end);
            end
            
            % Convert EEG2 to Volts:
            tenSecBinEEG2 = tenSecBinEEG2*Eeg2ADBit2uV;
            
            % Create a figure of the 10 second epoch of the EMG and 2 EEG signals:
            xAxis = 0:10/(ds10SecLength-1):10; % Defines the x axis for the 10 sec epoch of data

            subplot(3,1,1); plot(xAxis,tenSecBinEMG)
            set(gca,'XTick',0:1:10)
            set(gca,'XTickLabel',{'0','1','2','3','4','5','6','7','8','9','10 seconds'})
            ylim([-200 200])
            title('EMG');
            ylabel('Amplitude (uV)');
            scrsz = get(0,'ScreenSize');
            set(figure(1),'OuterPosition',[0 2*scrsz(4)/5 scrsz(3) 3*scrsz(4)/5])

            subplot(3,1,2); plot(xAxis,tenSecBinEEG)
            set(gca,'XTick',0:1:10)
            set(gca,'XTickLabel',{'0','1','2','3','4','5','6','7','8','9','10 seconds'})
            ylim([-200 200])
            title('Primary EEG');
            ylabel('Amplitude (uV)');
            scrsz = get(0,'ScreenSize');
            set(figure(1),'OuterPosition',[0 2*scrsz(4)/5 scrsz(3) 3*scrsz(4)/5])
            
            subplot(3,1,3); plot(xAxis,tenSecBinEEG2)
            set(gca,'XTick',0:1:10)
            set(gca,'XTickLabel',{'0','1','2','3','4','5','6','7','8','9','10 seconds'})
            ylim([-200 200])
            title('Secondary EEG');
            ylabel('Amplitude (uV)');
            scrsz = get(0,'ScreenSize');
            set(figure(1),'OuterPosition',[0 2*scrsz(4)/5 scrsz(3) 3*scrsz(4)/5])
            
            annotation('rectangle',[.44 .05 .155 .91],'LineStyle','-.','LineWidth',1,...
            'Color',[1 0 0]);
            
            annotation('textbox',[0.44 0.019 0.155 0.035],...
            'String',{'2 sec epoch'},...
            'HorizontalAlignment','center',...
            'FitBoxToText','off',...
            'LineStyle','none',...
            'Color',[1 0 0]);
        end
        
        

        % Construct a questdlg with 6 options
        inputOptions={'Active Wake','Quiet Wake','Quiet Sleep',...
            'REM','Transition', 'Skip'};
        defSelection=inputOptions{6};
        choiceState=bttnChoiceDialog(inputOptions, 'State Selection', defSelection,...
         {'Remaining states to score:  ', ['AW=' num2str(remainingEpoch(1))...
         ', QW=' num2str(remainingEpoch(2)) ', QS=' num2str(remainingEpoch(3))...
         ', RE=' num2str(remainingEpoch(4)) ', TR=' num2str(remainingEpoch(5))],...
         '', 'What is the state?'});
        
       % Handle response
        switch choiceState
            case 1
                if isequal(remainingEpoch(1),0)  %Finished scoring minimum number of epochs. 
                    % Add more for better threshold settings:
                    trainingResults = [trainingResults;...
                        [1 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                else
                    remainingEpoch(1) = remainingEpoch(1) - 1; %Reduce # of remaining AW epochs to score by 1.
                    trainingResults = [trainingResults;...
                        [1 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                end
            case 2
                if isequal(remainingEpoch(2),0)  %Finished scoring minimum number of epochs. 
                    % Add more for better threshold settings:
                    trainingResults = [trainingResults;...
                        [2 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                else
                    remainingEpoch(2) = remainingEpoch(2) - 1;  %Reduce # of remaining QW epochs to score by 1.
                    trainingResults = [trainingResults;...
                        [2 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                end
            case 3
                if isequal(remainingEpoch(3),0)  %Finished scoring minimum number of epochs. 
                    % Add more for better threshold settings:
                    trainingResults = [trainingResults;...
                        [3 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                else
                    remainingEpoch(3) = remainingEpoch(3) - 1;  %Reduce # of remaining QS epochs to score by 1.
                    trainingResults = [trainingResults;...
                        [3 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                end    
            case 4
                if isequal(remainingEpoch(4),0)  %Finished scoring minimum number of epochs. 
                    % Add more for better threshold settings:
                    trainingResults = [trainingResults;...
                        [4 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                else
                    remainingEpoch(4) = remainingEpoch(4) - 1;  %Reduce # of remaining RE epochs to score by 1.
                    trainingResults = [trainingResults;...
                        [4 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                end
            case 5
                if isequal(remainingEpoch(5),0)  %Finished scoring minimum number of epochs. 
                    % Add more for better threshold settings:
                    trainingResults = [trainingResults;...
                        [6 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];
                else
                    remainingEpoch(5) = remainingEpoch(5) - 1;  %Reduce # of remaining TR epochs to score by 1.
                    trainingResults = [trainingResults;...
                        [6 powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]];  %TR = 6.
                end
        end
        close % Closes the EEG plot
        if isequal(remainingEpoch, [0 0 0 0 0])
            scoredEpochsStatus = 1;
        end
    end
    pause(1);  % Pause time in seconds
end

% All training epochs with power values have been collected.  Now the user
% needs to view the data in 3-D in order to choose thresholds.
Thresholds = psd3dPlots(trainingResults);

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
end

end