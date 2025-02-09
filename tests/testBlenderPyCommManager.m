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
charBlenderPyInterfacePath            = "/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/lib/corto_PeterCdev/server_api/";
charBlenderPyInterfacePath            = strcat(charBlenderPyInterfacePath, charScriptName);
charStartBlenderServerScriptPath    = "/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/lib/corto_PeterCdev/server_api/StartBlenderServer.sh";

charServerAddress = 'localhost';
ui32ServerPort = [30001, 51000]; % [TCP, UDP]
ui32TargetPort = 51001; % UDP recv
dCommTimeout = 30;
i64RecvTCPsize = int64(4 * 2048 * 1536 * 64/8); % Number of bytes to read: 4*64*NumOfpixels

return

%% BlenderPyCommManager_connectionWithoutAutoManagement

% Construct command to run
charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
    charStartBlenderServerScriptPath, charBlenderModelPath, charBlenderPyInterfacePath);

% system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
charStartBlenderCommand = strcat(charStartBlenderCommand, " &");

% Make start call
system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
system(charStartBlenderCommand);
pause(1); % Wait sockets instantiation

% Define cortopy comm. manager object initializing in place (connection to server)
assert(BlenderPyCommManager.checkRunningBlenderServerStatic(ui32ServerPort(1)), 'Server startup attempt failed. Test cannot continue.')

objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
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

clear objBlenderPyCommManager 
return

%% BlenderPyCommManager_serverManagementMethods
objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', false, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', false, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath);

% Start server using instance method
bIsRunning = objBlenderPyCommManager.startBlenderServer();

% Check if server is ok
bIsRunning(:) = objBlenderPyCommManager.checkRunningBlenderServer();
assert(bIsRunning)

% Attempt connection
objBlenderPyCommManager.Initialize();

% Delete instance and terminate server
delete(objBlenderPyCommManager) % MUST NOT close server
bIsRunning(:) = objBlenderPyCommManager.checkRunningBlenderServerStatic(ui32ServerPort(1));
assert(bIsRunning)

% Terminate server manually
objBlenderPyCommManager.terminateBlenderProcessesStatic()

return
%% BlenderPyCommManager_serverAutoManagement
% Instance definition with automatic management of server
objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath);

% Delete instance and terminate server
delete(objBlenderPyCommManager)
return
%% BlenderPyCommManager_renderImageFromPQ_
clear objBlenderPyCommManager

% Instance definition with automatic management of server
objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i64RecvTCPsize);

% Compose scene data stuct 
dSceneDataVector_ref = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat];%, dBody2Pos, dBody2Quat];

% Test renderImageFromPQ_ method
bApplyBayerFilter = true;
bIsImageRGB = true;
dImg = objBlenderPyCommManager.renderImageFromPQ_(dSceneDataVector_ref, ...
    "bApplyBayerFilter", bApplyBayerFilter, "bIsImageRGB", bIsImageRGB); 


% TODO: fix issue in reception. The issue is that ReadBuffer assumes the sender specifies 4 bytes for the
% message length first, but it is not the case here. --> add length as input to Read buffer, that if not 0
% makes the class avoid the reading of the first 4 bytes.
figure('WindowState', 'normal')
imshow(dImg);
pause(1);
clear objBlenderPyCommManager
return

%% BlenderPyCommManager_composeSceneDataVector
clear objBlenderPyCommManager_test

% Instance definition with automatic management of server
objBlenderPyCommManager_test = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', false, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', false, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i64RecvTCPsize);

% Compose reference scene data stuct 
dSceneDataVector_ref = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat];%, dBody2Pos, dBody2Quat];

% Assign data
% Nav frame is CAMERA frame
% Convert Blender quaternions to DCM for testing (quaternions already in Blender convention)
dSunVector_NavFrame             = dSunPos;
dCameraOrigin_NavFrame          = dSCPos;
dCameraAttDCM_NavframeFromTF    = quat2dcm(dSCquat);
dBodiesOrigin_NavFrame          = dBody1Pos;
dBodiesAttDCM_NavFrameFromTF    = quat2dcm(dBody1Quat);

dSceneDataVector_ref = objBlenderPyCommManager_test.composeSceneDataVector(dSunVector_NavFrame', ...
    dCameraOrigin_NavFrame', ...
    dCameraAttDCM_NavframeFromTF, ...
    dBodiesOrigin_NavFrame', ...
    dBodiesAttDCM_NavFrameFromTF, ...
    "enumRenderingFrame", EnumRenderingFrame.CAMERA);

assert(all((dSceneDataVector_ref - dSceneDataVector_ref) < 2*eps, 'all') )

clear objBlenderPyCommManager_test
return

%% BlenderPyCommManager_renderImage
clear objBlenderPyCommManager

% Instance definition with automatic management of server
objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', i64RecvTCPsize);


% Assign data
% Nav frame is CAMERA frame
% Convert Blender quaternions to DCM for testing (quaternions already in Blender convention)
dSunVector_NavFrame             = dSunPos;
dCameraOrigin_NavFrame          = dSCPos;
dCameraAttDCM_NavframeFromTF    = quat2dcm(dSCquat);
dBodiesOrigin_NavFrame          = dBody1Pos;
dBodiesAttDCM_NavFrameFromTF    = quat2dcm(dBody1Quat);

% Test renderImage method
dImg = objBlenderPyCommManager.renderImage(dSunVector_NavFrame', ...
                                        dCameraOrigin_NavFrame', ...
                                        dCameraAttDCM_NavframeFromTF, ...
                                        dBodiesOrigin_NavFrame', ...
                                        dBodiesAttDCM_NavFrameFromTF, ...
                                        "enumRenderingFrame", EnumRenderingFrame.CAMERA, ...
                                        'bConvertCamQuatToBlenderQuat', false);

pause(1);

% Do same test calling internal method again
dSceneDataVector_ref = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat];%, dBody2Pos, dBody2Quat];

bApplyBayerFilter = true;
bIsImageRGB = true;
dImg_check = objBlenderPyCommManager.renderImageFromPQ_(dSceneDataVector_ref, ...
    "bApplyBayerFilter", bApplyBayerFilter, "bIsImageRGB", bIsImageRGB); 

% Call renderImageSequence for preliminary test
dSunVector_Buffer_NavFrame = dSunVector_NavFrame';
dCameraOrigin_Buffer_NavFrame = dCameraOrigin_NavFrame';
dCameraAttDCM_Buffer_NavframeFromTF = dCameraAttDCM_NavframeFromTF;
dBodiesOrigin_Buffer_NavFrame = dBodiesOrigin_NavFrame';
dBodiesAttDCM_Buffer_NavFrameFromTF = dBodiesAttDCM_NavFrameFromTF;

bConvertCamQuatToBlenderQuat = false;
bEnableFramesPlot = true;
dImg_seq = objBlenderPyCommManager.renderImageSequence(  dSunVector_Buffer_NavFrame, ...
                                                                dCameraOrigin_Buffer_NavFrame, ...
                                                                dCameraAttDCM_Buffer_NavframeFromTF, ...
                                                                dBodiesOrigin_Buffer_NavFrame, ...
                                                                dBodiesAttDCM_Buffer_NavFrameFromTF, ...
                                                                "charOutputDatatype", "double", ...
                                                                "bEnableFramesPlot", bEnableFramesPlot, ...
                                                                "bConvertCamQuatToBlenderQuat", bConvertCamQuatToBlenderQuat);



figure('WindowState', 'normal')
imshow(dImg);
title('Method: renderImage')

figure('WindowState', 'normal')
imshow(dImg_check);
title('Method: renderImageFromPQ_')

figure('WindowState', 'normal')
imshow(dImg_seq);
title('Method: renderImageSequence')

pause(2);


% Delete instance and terminate server
clear objBlenderPyCommManager
return


%% BlenderPyCommManager_renderImageSequence_Itokawa
clear objBlenderPyCommManager
close all
pause(0.2);
% TODO: load setup for SLAM simulations
addpath("/home/peterc/devDir/nav-frontend/tests/emulator"); % HARDCODED PATH, need future update
run('loadSimulationSetup');

% Overwrite model definition if needed
% charBlenderModelPath       = "/home/peterc/devDir/rendering-sw/corto_PeterCdev/data/scenarios/S2_Itokawa/S2_Itokawa.blend";
charBlenderModelPath       = "/home/peterc/devDir/rendering-sw/corto_PeterCdev/data/scenarios/S2_Itokawa/S2_Itokawa.blend";
charBlenderPyInterfacePath = "/home/peterc/devDir/rendering-sw/corto_PeterCdev/server_api/BlenderPy_UDP_TCP_interface.py";

% objCamera.ui32NumOfChannels = 4; % Camera loaded from yaml file

dCommTimeout = 120;
% Instance definition with automatic management of server
objBlenderPyCommManager = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true, 'charBlenderModelPath', charBlenderModelPath, ...
    'bAutoManageBlenderServer', true, 'charBlenderPyInterfacePath', charBlenderPyInterfacePath, ...
    'charStartBlenderServerCallerPath', charStartBlenderServerScriptPath, ...
    'ui32TargetPort', ui32TargetPort, 'i64RecvTCPsize', -10, "bSendLogToShellPipe", true);%, ...
    %"objCameraIntrisincs", objCamera);

% Define scene 
ui32NumOfImgs = 1; %length(strScenConfig.dTimestamps);

% Nav frame is TARGET BODY frame
% Convert Blender quaternions to DCM for testing
dSunVector_Buffer_NavFrame             = zeros(3, ui32NumOfImgs);
dSunAttDCM_Buffer_NavframeFromTF       = zeros(3,3, ui32NumOfImgs);
dCameraOrigin_Buffer_NavFrame          = zeros(3, ui32NumOfImgs);
dCameraAttDCM_Buffer_NavframeFromTF    = zeros(3, 3, ui32NumOfImgs);
dBodiesOrigin_Buffer_NavFrame          = zeros(3, ui32NumOfImgs);
dBodiesAttDCM_Buffer_NavFrameFromTF    = zeros(3, 3, ui32NumOfImgs);

% Construct scene buffers
for ui32TimestampID = 1:ui32NumOfImgs

    % NOTE: Nav frame is CUSTOM_FRAME if IN frame, TARGET_BODY if TB
    dSunDirGT_TB = strMainBodyRefData.dDCM_INfromTB(:,:, ui32TimestampID)' * strMainBodyRefData.dSunPosition_IN(:, ui32TimestampID);
    dSunVector_Buffer_NavFrame(:, ui32TimestampID)               = strMainBodyRefData.dSunPosition_IN(:, ui32TimestampID)/1000;

    dCameraOrigin_Buffer_NavFrame(:, ui32TimestampID)            = 3*strReferenceData.dxSCref_IN(1:3, ui32TimestampID)/norm(strReferenceData.dxSCref_IN(1:3, ui32TimestampID));
    % dCameraOrigin_Buffer_NavFrame(:, ui32TimestampID)           = strReferenceData.dxSCref_IN(1:3, ui32TimestampID)/1000;
    
    % Use attitude generator
    % objPointingGenerator = CAttitudePointingGenerator(strReferenceData.dxSCref_IN(1:3, ui32TimestampID), [0;0;0]);
    % [objPointingGenerator, dCameraAttDCM_Buffer_NavframeFromTF(:, :, ui32TimestampID)]   = objPointingGenerator.pointToTarget_PositionOnly();

    dCameraAttDCM_Buffer_NavframeFromTF(:, :, ui32TimestampID)   = strReferenceData.dDCM_INfromCAM(:, :, ui32TimestampID);

    % dCameraAttDCM_Buffer_NavframeFromTF(:, :, ui32TimestampID)   = strMainBodyRefData.dDCM_INfromTB(:,:, ui32TimestampID)' * ...
    %                                                                 strReferenceData.dDCM_INfromCAM(:, :, ui32TimestampID);

    dBodiesOrigin_Buffer_NavFrame(:, ui32TimestampID)            = zeros(3,1);
    % dBodiesAttDCM_Buffer_NavFrameFromTF(:, :, ui32TimestampID)   = strMainBodyRefData.dDCM_INfromTB(:,:, ui32TimestampID);
    dBodiesAttDCM_Buffer_NavFrameFromTF(:, :, ui32TimestampID)   = eye(3);

end

% Test computation of Sun direction in batch (static method)
[dSunAttQuat_Buffer_NavframeFromTF, dSunAttDCM_Buffer_NavframeFromTF] = BlenderPyCommManager.computeSunBlenderQuatFromPosition(dSunVector_Buffer_NavFrame);

% Plot reference frames of ith scene (normal camera quaternion)
% objSceneArray = gobjects(length(ui32SceneIDs), 1);

% for ui32SceneID = ui32SceneIDs
% 
%     % Convert DCMs to quaternion
%     dSceneEntityQuatArray_RenderFrameFromTF = dcm2quat(dBodiesAttDCM_Buffer_NavFrameFromTF(:,:, ui32SceneID))';
%     dCameraQuat_RenderFrameFromCam          = dcm2quat(dCameraAttDCM_Buffer_NavframeFromTF(:, :, ui32SceneID))';
% 
%     % Construct figure with plot
%     [objSceneArray(ui32SceneID)] = PlotSceneFrames_Quat(dBodiesOrigin_Buffer_NavFrame(:, ui32SceneID), ...
%         dSceneEntityQuatArray_RenderFrameFromTF, ...
%         dCameraOrigin_Buffer_NavFrame(:, ui32SceneID), ...
%         dCameraQuat_RenderFrameFromCam, 'bUseBlackBackground', true, ...
%         "charFigTitle", "Visualization with normal camera quaternion");
% 
% end

% Plot reference frames of ith scene (inverted "Blender" camera quaternion)
% objSceneArray_2 = gobjects(length(ui32SceneIDs), 1);
% 
% for ui32SceneID = ui32SceneIDs
% 
%     % Convert DCMs to quaternion
%     dSceneEntityQuatArray_RenderFrameFromTF = dcm2quat(dBodiesAttDCM_Buffer_NavFrameFromTF(:,:, ui32SceneID))';
%     dCameraQuat_RenderFrameFromCam          = dcm2quat(dCameraAttDCM_Buffer_NavframeFromTF(:, :, ui32SceneID))';
% 
%     dCameraQuat_RenderFrameFromCam = BlenderPyCommManager.convertCamQuatToBlenderQuatStatic(dCameraQuat_RenderFrameFromCam);
% 
%     % Construct figure with plot
%     [objSceneArray_2(ui32SceneID)] = PlotSceneFrames_Quat(dBodiesOrigin_Buffer_NavFrame(:, ui32SceneID), ...
%                                                             dSceneEntityQuatArray_RenderFrameFromTF, ...
%                                                             dCameraOrigin_Buffer_NavFrame(:, ui32SceneID), ...
%                                                             dCameraQuat_RenderFrameFromCam, 'bUseBlackBackground', true, ...
%                                                             "charFigTitle", "Visualization with Blender camera quaternion");
% 
% end

% Test renderImageSequence method
bConvertCamQuatToBlenderQuat = true;
bEnableFramesPlot = true;
ui8OutImgArrays = objBlenderPyCommManager.renderImageSequence(dSunVector_Buffer_NavFrame, ...
                                                 dCameraOrigin_Buffer_NavFrame, ...
                                                 dCameraAttDCM_Buffer_NavframeFromTF, ...
                                                 dBodiesOrigin_Buffer_NavFrame, ...
                                                 dBodiesAttDCM_Buffer_NavFrameFromTF, ...
                                                 "charOutputDatatype", "double", ...
                                                 "bEnableFramesPlot", bEnableFramesPlot, ...
                                                 "bConvertCamQuatToBlenderQuat", bConvertCamQuatToBlenderQuat, ...
                                                 "enumRenderingFrame", EnumRenderingFrame.CUSTOM_FRAME);

figure
imshow(ui8OutImgArrays(:,:,1))

% figure;
% imshow(ui8OutImgArrays(:,:,2))




