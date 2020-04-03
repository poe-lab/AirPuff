function Thresholds = psd3dPlots(PSDvalues)
%Called by the following programs:
%--thresholdTrainingProgramForFullAutoScoring.m

% Structure of each row of 'PSDvalues' is
%[statenum powerEMG deltaPower thetaPower sigmaPower st_power dt_ratio]
global X1 Y1 Z1 X2 Y2 Z2
% Setup the colormap for the states.
Cmap(1,:)=[1 0.8 0];  % Yellow   => Active Waking
Cmap(2,:)=[0 0 1];    % Blue     => Quiet Sleep
Cmap(3,:)=[1 0 0];    % Red      => REM
Cmap(4,:)=[0 1 0.1];  % Green    => Quiet Waking
Cmap(5,:)=[0 0 0];    % Black    => Unhooked
Cmap(6,:)=[0 1 1];    % Cyan     => Trans REM
Cmap(7,:)= [0.85 0.85 0.85];    % Grey    => Cleared State
Cmap(8,:)=[1 1 1];    % White    => Intermediate Waking

figure(1);
whitebg(figure(1),[1,1,1])
set(gcf,'color',[187/255, 201/255, 214/255],'position',[100 533 450 340])
set(gca,'Xcolor',[0, 0, 0],'YColor',[0 0 0],'ZColor',[0 0 0])

figure(2);
whitebg(figure(2),[1,1,1])
set(gcf,'color',[187/255, 201/255, 214/255],'position',[100 100 450 340])
set(gca,'Xcolor',[0, 0, 0],'YColor',[0 0 0],'ZColor',[0 0 0])

Sum_P_sigma=0; Length_P_sigma=0; Squaresum_P_sigma=0;
Mean_sigma=[]; Std_dev_sigma=[];

lowdt=[];highdt=[];lowst=[];highst=[];lowemg=[];highemg=[];dtless=[];emghigh=[];

S = 20;  % Size of the circle
C = [];
numOfEpochs = size(PSDvalues, 1);
for i = 1:numOfEpochs
    C(i,:) = Cmap(PSDvalues(i,1),:); %#ok<AGROW>
end



figure(1),scatter3(PSDvalues(:,7),PSDvalues(:,6),PSDvalues(:,2),S,C,'o','filled');
xlabel('Delta/Theta Power');ylabel('Sigma*Theta Power');zlabel('EMG Power');
set(get(gca,'Title'),'Color','k')
set(get(gca,'XLabel'),'Color','k')
set(get(gca,'YLabel'),'Color','k')
set(get(gca,'ZLabel'),'Color','k')
set(gca,'Xcolor','k','YColor','k','ZColor','k')
view(-65,22); hold on, pause(2)


figure(2),scatter3(PSDvalues(:,5),PSDvalues(:,4),PSDvalues(:,3),S,C,'filled');
xlabel('Sigma Power');ylabel('Theta Power');zlabel('Delta Power');
set(get(gca,'Title'),'Color','k')
set(get(gca,'XLabel'),'Color','k')
set(get(gca,'YLabel'),'Color','k')
set(get(gca,'ZLabel'),'Color','k')
set(gca,'Xcolor','k','YColor','k','ZColor','k')
view(-65,22);  axis on, hold on, pause(2),

% Find the minimum and maximum for sigma, theta and delta_lo values
figure(1),
X1=xlim; Y1=ylim; Z1=zlim; 
set(gca,'XlimMode','manual','YlimMode','manual','ZlimMode','manual')
figure(2),
X2=xlim; Y2=ylim; Z2=zlim;
set(gca,'XlimMode','manual','YlimMode','manual','ZlimMode','manual')

% Get the details in the Figure Manipulator GUI 
figureManipulations;
manipulator_handles=guihandles(figureManipulations);

set(manipulator_handles.x1mini,'String',X1(1)), set(manipulator_handles.x1maxi,'String',X1(2))
set(manipulator_handles.y1mini,'String',Y1(1)), set(manipulator_handles.y1maxi,'String',Y1(2))
set(manipulator_handles.z1mini,'String',Z1(1)), set(manipulator_handles.z1maxi,'String',Z1(2))
set(manipulator_handles.x2mini,'String',X2(1)), set(manipulator_handles.x2maxi,'String',X2(2))
set(manipulator_handles.y2mini,'String',Y2(1)), set(manipulator_handles.y2maxi,'String',Y2(2))
set(manipulator_handles.z2mini,'String',Z2(1)), set(manipulator_handles.z2maxi,'String',Z2(2))
% 
% thresholdsComplete = 0;
Thresholds = [];
sigmaSD = std(PSDvalues(:,5));
def = {'','','','','',''};
thresholdStatus = 0;
while thresholdStatus < 6 
    thresholdStatus = 0;
    % Dialog box to enter the power thresholds for auto-scoring:
    prompt = {'Enter EMG Threshold:','Enter SxT Threshold:','Enter D/T Threshold:',...
        'Enter Delta Threshold:','Enter Theta Threshold:','Enter Sigma Threshold:'};
    dlg_title = 'Thresholds from Training Data';
    lineNo = 1;
    options.WindowStyle= 'normal';
    answer = inputdlg(prompt,dlg_title,lineNo,def,options);
    def = answer';
    for i = 1:6 %Get all of the entered threshold values and make sure they are numbers.
        if isequal(answer{i,1}, '') %Check to see if empty threshold box
        elseif isnan(str2double(answer{i,1}))   %Check to see if not a number
        else
            Thresholds(i) = str2double(answer{i,1});    %#ok<AGROW> %It is a number, so add to threshold vector
            thresholdStatus = thresholdStatus + 1;
        end
    end
    clear answer prompt dlgTitle lineNo
end
close
Thresholds(7) = sigmaSD;

% while isequal(thresholdsComplete, 0)
%     
% end
