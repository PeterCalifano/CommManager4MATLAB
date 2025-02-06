close all
clear
clc

% Unit test for CORTO interfaces and CommManager (S5 Didymos Milani scenario)
% SUN:   POS [-1.87979488e+08  2.98313209e+04  5.99584851e+07] - Q [ 0.57104144  0.41702718 -0.41731124 -0.57083389]
% SC:    POS [0. 0. 0.] - Q [1. 0. 0. 0.]
% BODY (0):   POS: [  0.16706893   0.0235506  -13.93270439] - Q [-0.05240883 -0.20821087  0.76502471  0.60715537]
% BODY (1):   POS: [  0.96841929   0.38199128 -13.145638  ] - Q [-0.17513088 -0.35985445  0.70648485  0.58370726]

% Load_test_data
% From milani-gnc simulation
dSunPos  = [-1.87979488e+08  2.98313209e+04  5.99584851e+07];
dSunQuat = [ 0.57104144  0.41702718 -0.41731124 -0.57083389];

dSCPos  = [0. 0. 0.];
dSCquat = [1. 0. 0. 0.];

dBody1Pos = [  0.16706893   0.0235506  -13.93270439]; % [BU] 
dBody2Pos = [  0.96841929   0.38199128 -13.145638  ]; % [BU]

dBody1Quat = [-0.05240883 -0.20821087  0.76502471  0.60715537]; % [BU] 
dBody2Quat = [-0.17513088 -0.35985445  0.70648485  0.58370726]; % [BU]

% DEVNOTE: test opens and closes the server multiple times due to current server limitation in handling
% disconnections and reconnections.

% Define post test cleanup
cleanup = onCleanup(@() clear); 

% Select Blender model
charScriptName              = 'CORTO_UDP_TCP_interface.py'; 

% charBlenderModelPath    = '/home/peterc/devDir/rendering-sw/corto_PeterCdev/input/OLD_ones_0.1/S5_Didymos_Milani/S5_Didymos_Milani.blend';
charBlenderModelPath                = "/home/peterc/devDir/projects-DART/data/rcs-1/pre-phase-A/blender/Apophis_RGB.blend";
charCORTOpyInterfacePath            = "/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/lib/corto_PeterCdev/server_api/";
charCORTOpyInterfacePath            = strcat(charCORTOpyInterfacePath, charScriptName);
charStartBlenderServerScriptPath    = "/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/lib/corto_PeterCdev/server_api/StartBlenderServer.sh";

charServerAddress = 'localhost';
ui32ServerPort = [30001, 51000]; % [TCP, UDP]
ui32TargetPort = 51001; % UDP recv
dCommTimeout = 30;
i32RecvTCPsize = 4 * 2048 * 1536 * 64/8; % Number of bytes to read: 4*64*NumOfpixels

return

%% CORTOpyCommManager_connectionWithoutAutoManagement

% Construct command to run
charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
    charStartBlenderServerScriptPath, charBlenderModelPath, charCORTOpyInterfacePath);

% system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
charStartBlenderCommand = strcat(charStartBlenderCommand, " &");

% Make start call
system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
system(charStartBlenderCommand);
pause(1); % Wait sockets instantiation

% Define cortopy comm. manager object initializing in place (connection to server)
assert(CORTOpyCommManager.checkRunningBlenderServerStatic(ui32ServerPort(1)), 'Server startup attempt failed. Test cannot continue.')

objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true);

pause(0.25);

% Terminate Blender process to close server (manually)
if isunix == true
    % Find the process
    [~, result] = system('pgrep -f blender'); % Get the process ID(s) of blender
    %disp(result);

    % Trim whitespace
    result = strtrim(result);

    % Split the PIDs into a cell array of strings
    pids = strsplit(result);

    if not(isempty(result))
        % Kill the process
        for pid = pids
            fprintf('Killing process %s...\n', pid{:})
            system(sprintf('kill -9 %s', pid{:}));
        end
    end

else
    error("This code should not run for Windows as the InitFcn of the model performs the task directly. Report using issues please.")
end

clear objCortopyCommManager 
return

%% CORTOpyCommManager_serverManagementMethods
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', false, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', false, 'charCORTOpyInterfacePath', charCORTOpyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath);

% Start server using instance method
bIsRunning = objCortopyCommManager.startBlenderServer();

% Check if server is ok
bIsRunning(:) = objCortopyCommManager.checkRunningBlenderServer();
assert(bIsRunning)

% Attempt connection
objCortopyCommManager.Initialize();

% Delete instance and terminate server
delete(objCortopyCommManager) % MUST NOT close server
bIsRunning(:) = objCortopyCommManager.checkRunningBlenderServerStatic(ui32ServerPort(1));
assert(bIsRunning)

% Terminate server manually
objCortopyCommManager.terminateBlenderProcessesStatic()

return
%% CORTOpyCommManager_serverAutoManagement
% Instance definition with automatic management of server
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charCORTOpyInterfacePath', charCORTOpyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath);

% Delete instance and terminate server
delete(objCortopyCommManager)
return
%% CORTOpyCommManager_renderImageFromPQ_

% Instance definition with automatic management of server
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charCORTOpyInterfacePath', charCORTOpyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i32RecvTCPsize);

% Compose scene data stuct 
dSceneDataVector = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat];%, dBody2Pos, dBody2Quat];

% Test renderImageFromPQ_ method
bApplyBayerFilter = true;
bIsImageRGB = true;
dImg = objCortopyCommManager.renderImageFromPQ_(dSceneDataVector, ...
    "bApplyBayerFilter", bApplyBayerFilter, "bIsImageRGB", bIsImageRGB); 


% TODO: fix issue in reception. The issue is that ReadBuffer assumes the sender specifies 4 bytes for the
% message length first, but it is not the case here. --> add length as input to Read buffer, that if not 0
% makes the class avoid the reading of the first 4 bytes.

imshow(dImg);
pause(1);

%% CORTOpyCommManager_renderImage

% Instance definition with automatic management of server
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charCORTOpyInterfacePath', charCORTOpyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i32RecvTCPsize);


% Assign data
% Nav frame is CAMERA frame
% Convert Blender quaternions to DCM for testing
dSunVector_NavFrame             = dSunPos;
dSunAttDCM_NavframeFromTF       = quat2dcm(dSunQuat); 
dCameraOrigin_NavFrame          = dSCPos;
dCameraAttDCM_NavframeFromTF    = quat2dcm(dSCquat);
dBodiesOrigin_NavFrame          = dBody1Pos;
dBodiesAttDCM_NavFrameFromTF    = quat2dcm(dBody1Quat);

% Test renderImage method
dImg = objCortopyCommManager.renderImage(dSunVector_NavFrame, ...
                                        dSunAttDCM_NavframeFromTF, ...
                                        dCameraOrigin_NavFrame', ...
                                        dCameraAttDCM_NavframeFromTF, ...
                                        dBodiesOrigin_NavFrame', ...
                                        dBodiesAttDCM_NavFrameFromTF, ...
                                        "enumRenderingFrame", EnumRenderingFrame.CAMERA, ...
                                        "bApplyBayerFilter", true, ...
                                        "bIsImageRGB", true);

imshow(dImg);
pause(1);


% Delete instance and terminate server
delete(objCortopyCommManager)

%% CORTOpyCommManager_renderImageSequence

% TODO: load setup for SLAM simulations


% Overwrite model definition
charBlenderModelPath

% Instance definition with automatic management of server
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charCORTOpyInterfacePath', charCORTOpyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i32RecvTCPsize);


% Assign data
% Nav frame is TARGET BODY frame
% Convert Blender quaternions to DCM for testing
dSunVector_Buffer_NavFrame             = dSunPositions_TB;
dSunAttDCM_Buffer_NavframeFromTF       = quat2dcm(dSunQuat); 
dCameraOrigin_Buffer_NavFrame          = dSCPos;
dCameraAttDCM_Buffer_NavframeFromTF    = quat2dcm(dSCquat);
dBodiesOrigin_Buffer_NavFrame          = dBody1Pos;
dBodiesAttDCM_Buffer_NavFrameFromTF    = quat2dcm(dBody1Quat);

% Test renderImage method
dImg = objCortopyCommManager.renderImageSequence(dSunVector_Buffer_NavFrame, ...
                                                 dSunAttDCM_Buffer_NavframeFromTF, ...
                                                 dCameraOrigin_Buffer_NavFrame', ...
                                                 dCameraAttDCM_Buffer_NavframeFromTF, ...
                                                 dBodiesOrigin_Buffer_NavFrame', ...
                                                 dBodiesAttDCM_Buffer_NavFrameFromTF, ...
                                                 "enumRenderingFrame", EnumRenderingFrame.TARGET_BODY, ...
                                                 "bApplyBayerFilter", true, ...
                                                 "bIsImageRGB", true);







