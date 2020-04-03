function airPuffSleepDeprivation09122012  % Define all variables
% Dialog box to enter the channel number of the EEG to be analyzed for sleep:
EEG_acq_ent = [];
while isempty(EEG_acq_ent)
    prompt={'Enter CSC # to be used for EEG:'};
    dlgTitle='EEG Channel Select';
    lineNo=1;
    answer = inputdlg(prompt,dlgTitle,lineNo);
    EEG_acq_ent = str2double(answer{1,1});
    clear answer prompt dlgTitle lineNo
end
TargetCSCString = ['CSC' num2str(EEG_acq_ent)];
% Dialog box to enter the Delta power threshold for sleep:
deltaStatus = 0;
deltaThreshold = [];
while isequal(deltaStatus,0)
    prompt={'Enter threshold of Delta power for SLEEP (Leave blank if unknown):'};
    dlgTitle='Set Power Threshold';
    lineNo=1;
    answer = inputdlg(prompt,dlgTitle,lineNo);
    if isequal(answer{1,1}, '')
        % Enter code to go to the training program.
        [choice2, deltaThreshold] = thresholdTrainingProgram(TargetCSCString);
        deltaStatus = 1;
    else
        deltaThreshold = str2double(answer{1,1});
        if isempty(deltaThreshold)
        else
            deltaStatus = 1;
            choice2 = 'Continue';
        end
    end
    clear answer prompt dlgTitle lineNo
end

% Handle response
switch choice2
    case 'Exit' % User chose to exit the program after determining delta power threshold
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

    % Find index of target CSC in 'CheetahObjects'
    CscIndex = find(strcmp(TargetCSCString,cheetahObjects) == 1);

    % Open up a stream for target CSC
    succeeded = NlxOpenStream(cheetahObjects(CscIndex));
    if succeeded == 0
        disp(sprintf('FAILED to open stream for %s', char(cheetahObjects(CscIndex))));
    end

    if succeeded == 1
        disp 'PASSED open stream for all current objects'
    end

    %Retrieve AD Bit Value and convert user-set threshold to AD Bit Volts.
    [succeeded, ADBitValue] = NlxSendCommand(['-GetADBitVolts ' TargetCSCString]);
    ADBitValue =str2double(char(ADBitValue(1)));  % Converts from a string to a number
    if succeeded == 1
        disp 'Retrieved A/D Bit Value'
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
    [succeeded,~, ~, ~, samplingFreqArray, ~, ~, ~ ] = NlxGetNewCSCData(TargetCSCString);
    if succeeded == 0
        disp(sprintf('FAILED to get sampling frequency'));
        %break;
    else
        disp(sprintf('Sampling frequency is %d' ,samplingFreqArray(1)));
    end
    samplingFreqArray = double(samplingFreqArray);
    data2SecLength = (2 * samplingFreqArray(1))-1;   % Finds length of data vector = 2 sec
    [bLow,aLow] = ellip(7,1,60, EEG_Fc/(samplingFreqArray(1)/2)); 

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
        [succeeded,dataArray, ~, ~, ~,...
            numValidSamplesArray, numRecordsReturned, numRecordsDropped ] = NlxGetNewCSCData(TargetCSCString);

        if succeeded == 0
            disp(sprintf('FAILED to get new data for CSC stream %s on pass %d', TargetCSCString, pass));
            break;
        elseif length(dataArray) < (data2SecLength + 1)
            shortData = shortData + 1
            pause(2);

        else
            %disp(sprintf('Retrieved %d CSC records for %s with %d dropped.', numRecordsReturned, objectToRetrieve, numRecordsDropped));

    %Here is where you'll perform some calculation on any of the returned values.
    %Make sure any calculations done here don't take too much time, otherwise 
    %NetCom will back up and you will have dropped records.

            twoSecBinEEG = dataArray(end - data2SecLength:end);  %Extracts last 2 sec of EEG data pulled in

            % Apply filter(s)
            twoSecBinEEG = double(twoSecBinEEG'); % Applied if streamed same as recorded in CSC file.
            twoSecBinEEG=filter(bLow,aLow,twoSecBinEEG);

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

            deltaPower = sum(Pxx2(index_delta))/windowsize *2;  

            % Determine state via logic.
            % State = 0 is asleep, State = 1 is awake
            % Push-Pop states.
            if deltaPower > deltaThreshold
                tenSecStates = [tenSecStates(2:5) 0]  %Scored as ASLEEP
            else
                tenSecStates = [tenSecStates(2:5) 1]  %Scored as AWAKE.
            end
            % If true, trigger puff of air.

            if isequal(tenSecStates,tenSecSleep)
                %Trigger air puff through Cheetah
                %Send event to Cheetah
                [succeeded, cheetahReply] = NlxSendCommand('-DigitalIOTtlPulse PCI-DIO24_0 0 0 High');
                %[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "10 sec sleep detected" 10 11');
                if succeeded == 0
                    disp 'FAILED to send command'
    %             else
    %                 disp 'PASSED send command'
                end
                %Should there be a delay before next puff?  I can use ones in the
                %'tenSecStates' to cause a delay.
                tenSecStates = [1 1 1 0 0]; %Each leading 1 in the vector represents 
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
    succeeded = NlxCloseStream(TargetCSCString);
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
        msgbox('The program has run successfully.');
    end
end
%remove all vars created in this test script
clear