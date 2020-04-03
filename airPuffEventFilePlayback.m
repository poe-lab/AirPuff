function airPuffEventFilePlayback  % Define all variables

%Request user input to select event file:
working_dir = pwd;
current_dir = 'C:\SleepData\Datafiles'; % This is the default directory that opens.
cd(current_dir);
[filename, pathname] = uigetfile('*.nev', 'Select a Cheetah event file'); %This waits for user input and limits selection to .nev files.
% Check for whether or not a file was selected
if isempty(filename) || isempty(pathname)
    uiwait(errordlg('You need to select an event file. Please try again',...
        'ERROR','modal'));
    cd(working_dir);
else
    cd(working_dir);
    NevFile= fullfile(pathname, filename);
end

%load event file
ExtractHeader = 0;  % 0 for no and 1 for yes
ExtractMode = 1;  %Extract all data points

[TimeStamps, EventStrings] =Nlx2MatEV( NevFile, [1 0 0 0 1], ExtractHeader, ExtractMode, []);

%convert to time delays for air puffs

targetEvent = '10 sec sleep detected';
numOfEvents = size(TimeStamps,2);
indexOfAirPuffs = [];
for i = 1:numOfEvents
    if isequal(targetEvent, EventStrings{i,1})
        indexOfAirPuffs = [indexOfAirPuffs, i];
    end  
end
airPuffTimeStamps = TimeStamps(1,indexOfAirPuffs)';
%airPuffDelaySequence = airPuffTimeStamps - airPuffTimeStamps(1);
sizeAirPuffTS = size(airPuffTimeStamps,1);
airPuffDelaySequence = zeros(sizeAirPuffTS,1);

for i = 2:sizeAirPuffTS
    airPuffDelaySequence(i) = airPuffTimeStamps(i) - airPuffTimeStamps(i-1);
end
%convert to seconds
airPuffDelaySequence = airPuffDelaySequence * 0.000001;

% Establish Neuralynx router connection:
serverName = '10.21.156.160';  % Name or IP of the computer running Cheetah
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
succeeded = NlxSetApplicationName('Event Playback of Air Puffs');
if succeeded ~= 1
    disp 'FAILED set the application name'
else
    disp 'PASSED set the application name'
end

% Post an event to the Event Log for start of sleep deprivation.
[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Beginning Playback of Air Puffs from Event File" 10 11');
% You can use NlxSendCommand to send any Cheetah command to Cheetah.
if succeeded == 0
    disp 'FAILED to send command'
else
    disp 'PASSED send command'
end  


pause on   

pause(5);

for i = 2:sizeAirPuffTS
    pause(airPuffDelaySequence(i));
    
    %Trigger air puff through Cheetah
    [succeeded, cheetahReply] = NlxSendCommand('-DigitalIOTtlPulse PCI-DIO24_0 0 0 High');
    %Send event to Cheetah
    [succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Air Puff Event" 10 11');
    if succeeded == 0
        disp 'FAILED to send command'
    end
end

pause off

[succeeded, cheetahReply] = NlxSendCommand('-PostEvent "Air Puff Event Playback Complete" 10 11');
if succeeded == 0
    disp 'FAILED to send command'
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