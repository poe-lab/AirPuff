function [choice2, deltaThreshold] = thresholdTrainingProgram(TargetCSCString)
Fs= 1024; % This is a constant for this program.
% downSamplingFactor = round(samplingFrequency/Fs); % This is used to down-sample 
% %the data if the sampling frequency in Cheetah cannot be set to 1024Hz.
D_lo = 0.4; % Specify low end of Delta band
D_hi = 4.9; % Specify high end of Delta band
%deltaThreshold = .75e-08; % Set to the threshold determined from baseline state scoring.
EEG_Fc = 30; % The EEG low-pass cut-off frequency. Default is 30 Hz.
EEG_highpass_enable = 0; % Set to '0' to turn off high-pass filter, '1' to turn on.
EEG_HP_Fc = 1; % The EEG high-pass cut-off frequency. Default is 1 Hz.
EEG_Notch_enable = 0; % Set to '0' to turn off notch filter, '1' to turn on.
%sampfactor = 1; % Set to '1' for no down-sampling and higher for desired down-sampling.
tenSecStates = [1 1 1 1 1]; %This is setting up the history for start of 
tenSecSleep = [0 0 0 0 0];%the program for the 10 seconds prior to programs start.
count = 0; shortData = 0;
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

% Find index of target CSC in 'CheetahObjects'
CscIndex = find(strcmp(TargetCSCString,cheetahObjects) == 1);

% Open up a stream for all objects 
succeeded = NlxOpenStream(cheetahObjects(CscIndex));
if succeeded == 0
        disp(sprintf('FAILED to open stream for %s', TargetCSCString));
end;
if succeeded == 1
    disp 'PASSED open stream for all current objects'
end

%Retrieve AD Bit Value and convert user-set threshold to AD Bit Volts.
[succeeded, ADBitValue] = NlxSendCommand('-GetADBitVolts CSC11'); % !Change this to accept the entered CSC #!
ADBitValue =str2double(char(ADBitValue(1)));  % Converts from a string to a number

if succeeded == 1
    disp 'Retrieved A/D Bit Value'
end

% Pull in streaming CSC data and related recording info.
[succeeded,~, ~, ~, samplingFreqArray, ~, ~, ~ ] = NlxGetNewCSCData(TargetCSCString);
if succeeded == 0
    disp(sprintf('FAILED to get sampling frequency'));
else
    disp(sprintf('Sampling frequency is %d' ,samplingFreqArray(1)));
end
samplingFreqArray = double(samplingFreqArray);
data2SecLength = (2 * samplingFreqArray(1))-1;   % Finds length of data vector = 2 sec
[bLow,aLow] = ellip(7,1,60, EEG_Fc/(samplingFreqArray(1)/2)); 

%This loop is run to get new data from NetCom.  All open streams must be
%servised regularly, or there will be dropped records.
warning('off', 'signal:spectrum:obsoleteFunction');
scoredEpochs = 0;
sleepEpochDeltaPower = zeros(10,1);
while scoredEpochs <10    %  Check if the user has scored 10 sleep epochs.
    % Pull in streaming CSC data and related recording info.
    [succeeded,dataArray, ~, ~, ~,...
        numValidSamplesArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewCSCData(TargetCSCString);

    if succeeded == 0
        disp(sprintf('FAILED to get new data for CSC stream %s on pass %d', TargetCSCString, pass));
        break;
    elseif length(dataArray) < (data2SecLength + 1)
        shortData = shortData + 1
        pause(2);
    else               
        twoSecBinEEG = dataArray(end - data2SecLength:end);  %Extracts last 2 sec of EEG data pulled in
        % Apply filter(s)
        twoSecBinEEG = double(twoSecBinEEG'); % Applied if streamed same as recorded in CSC file.
        twoSecBinEEG=filter(bLow,aLow,twoSecBinEEG);
        downSamplingFactor = round(samplingFreqArray(1)/Fs); % This is used to down-sample 
        %the data if the sampling frequency in Cheetah cannot be set to 1024Hz.
        % Down-sample if required.
        if downSamplingFactor > 1
            twoSecBinEEG = twoSecBinEEG(1:downSamplingFactor:end); 
        end
        % Convert EEG to Volts
        twoSecBinEEG = twoSecBinEEG*ADBitValue;
        % Apply algorithm to determine if animal has been sleeping for 10 seconds.

        % Calculate FFT(s)
         % This is calculating power in frequency domain
        windowsize =length(twoSecBinEEG);
        %     h = spectrum.welch('Hann', ones(windowsize,1), 0);  % Form: h = spectrum.welch('Hann',window,100*noverlap/window);
        %     hpsd = psd(h, double(twoSecBinEEG), 'NFFT', df, 'Fs', Fs);    %Form: hpsd = psd(h,x,'NFFT',nfft,'Fs',Fs);
        %     Pxx2 = hpsd.Data;
        %     F2 = hpsd.Frequencies;
            % SPECTRUM is obsolete. Replaced with above 4 lines that does the equivalent.

        [Pxx2,F2]=spectrum(twoSecBinEEG,windowsize,0,ones(windowsize,1),Fs);
        % ******  [P,F] = SPECTRUM(X,NFFT,NOVERLAP,WINDOW,Fs)

        %For the EEG signal
        index_delta=find(F2(1)+D_lo< F2 & F2 < F2(1)+D_hi);      % Default delta band 0.4 -4 Hz

        deltaPower = sum(Pxx2(index_delta))/windowsize *2  

        % Create a figure of the 2 second epoch of EEG
        xAxis = 2/windowsize:2/windowsize:2; % Defines the x axis for the 2 sec epoch of data
        
        plot(xAxis,twoSecBinEEG)
        set(gca,'XTick',0:.5:2)
        set(gca,'XTickLabel',{'0','0.5','1','1.5','2'})
        title('2 Second Epoch of EEG');
        xlabel('Time (s)');
        ylabel('Amplitude (mV)');
        scrsz = get(0,'ScreenSize');
        set(figure(1),'OuterPosition',[scrsz(3)/4 3*scrsz(4)/4-50 700 300])
        
        % Construct a questdlg with two options
        remainingEpochs2Score = num2str(10 - scoredEpochs);
        choice = questdlg([remainingEpochs2Score ' more SLEEP epochs to score. What is the state?'],...
            'State Selection', ...
         'Sleep','Not Sleep','Not Sleep');
        % Handle response
        switch choice
            case 'Sleep'
                scoredEpochs = scoredEpochs + 1;
                sleepEpochDeltaPower(scoredEpochs)= deltaPower;
            case 'Not Sleep'
        end
        close % Closes the EEG plot
    end
    pause(1);  % Pause time in seconds
end
deltaThreshold = mean(sleepEpochDeltaPower);
stdDevSleepDeltaPower = std(sleepEpochDeltaPower);

%close all open streams before disconnecting
succeeded = NlxCloseStream(cheetahObjects(CscIndex));
if succeeded == 0
    disp(sprintf('FAILED to close stream for %s', TargetCSCString)); %#ok<*DSPS>
end

if succeeded == 1
    disp 'PASSED close stream for all current objects'
end


%Disconnects from the server and shuts down NetCom
succeeded = NlxDisconnectFromServer();
if succeeded ~= 1
    disp 'FAILED disconnect from server'
else
    disp 'PASSED disconnect from server'
end

choice2 = questdlg({['Average Delta Power: ' num2str(deltaThreshold)], ['Standard Deviation: ' num2str(stdDevSleepDeltaPower)]},...
            'Begin Experiment', ...
         'Continue','Exit','Continue'); 
     
%remove all vars created in this test script
%clear