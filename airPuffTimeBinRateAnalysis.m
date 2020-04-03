function airPuffTimeBinRateAnalysis(numMinutesInBin)
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

% Remove all events that do not pertain to air puffing:
k = strfind(EventStrings, 'TTL');
numEvents=size(k,1);
for i = 1:numEvents
    if isempty(k{i,1})
    else
        TimeStamps(i)=0;
    end
end

m = TimeStamps>0;
TimeStamps = TimeStamps(m)';
EventStrings = EventStrings(m);
TimeStamps = TimeStamps/1000000;
timeInMinutes = (TimeStamps-TimeStamps(1))/60;
numBins = floor(timeInMinutes(end)/numMinutesInBin);
airPuffRates = zeros(numBins,1);
for i = 1:numBins
    eventsInBinLogical = timeInMinutes> ((i-1)*numMinutesInBin) & timeInMinutes < (i * numMinutesInBin);
    eventsInBin = EventStrings(eventsInBinLogical);
    timeStampsInBin = timeInMinutes(eventsInBinLogical);
    puffIndex = strfind(eventsInBin, '10');
    numEvents=size(puffIndex,1);
    subTime = ones(numEvents,1);
    for k = 1:numEvents
        if isempty(puffIndex{k,1})
            subTime(k) = 0;
        end
    end
    subtractTime = 0;
    for k = 1:numEvents
        if isequal(k,numEvents)
            if isequal(subTime(k),0)
                if isequal(subTime(k-1),0)
                else
                    subtractTime = [subtractTime; ((i * numMinutesInBin) - timeStampsInBin(k))];
                end
            end
        else
            if isequal(subTime(k),0)
                if isequal(subTime(k+1),0)
                    subtractTime = timeStampsInBin(k+1)-timeStampsInBin(k);
                elseif isequal(k,1)
                    subtractTime = [subtractTime; (timeStampsInBin(k)-((i-1) * numMinutesInBin))];
                end
            end
        end
    end
    airPuffRates(i) = sum(subTime)/(numMinutesInBin - sum(subtractTime));
end
end