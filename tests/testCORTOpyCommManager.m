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

BlenderModelPath = '/home/peterc/devDir/rendering-sw/corto_PeterCdev/input/OLD_ones_0.1/S5_Didymos_Milani/S5_Didymos_Milani.blend';

charScriptName = 'CORTO_UDP_TCP_interface.py';
% charScriptName = 'CORTO_to_Simulink_HF_1_d.py';

%BlenderModelPath = "/home/peterc/devDir/projects-DART/data/rcs-1/pre-phase-A/blender/Apophis_RGB.blend";

% CORTO_pyInterface_path  = 'script/CORTO_interfaces/corto_PeterCdev/server_api/CORTO_UDP_TCP_interface.py';
% CORTO_pyInterface_path = '/home/peterc/devDir/projects-DART/milani-gnc/script/CORTO_interfaces/corto_PeterCdev/scripts/';
CORTO_pyInterface_path = '/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/lib/corto_PeterCdev/server_api/';

CORTO_pyInterface_path = strcat(CORTO_pyInterface_path, charScriptName);

% Construct command to run
charStartBlenderCommand = sprintf('bash script/CORTO_interfaces/StartBlenderServer.sh -m "%s" -p "%s"', ...
    BlenderModelPath, CORTO_pyInterface_path);

% system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
charStartBlenderCommand = strcat(charStartBlenderCommand, " > /tmp/blender_pipe &");

% Define cortopy comm. manager object initializing in place (connection to server)
charServerAddress = 'localhost';
ui32ServerPort = [30001, 51000]; % [TCP, UDP]
ui32TargetPort = 51001;
dCommTimeout = 20;
objCortopyCommManager = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
    'bInitInPlace', true);

% Define post test cleanup
cleanup = onCleanup(@() clear); 

%% CORTOpyCommManager_renderImageFromPQ_

% Compose scene data stuct 
dSceneDataVector = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat];%, dBody2Pos, dBody2Quat];

% Test renderImageFromPQ_ method
dImg = objCortopyCommManager.renderImageFromPQ_(dSceneDataVector);
imshow(dImg);
pause(2);

%% CORTOpyCommManager_renderImage
% Convert Blender quaternions to DCM for testing

% Assign data
dSunVector_NavFrame = dSunPos;
dSunAttDCM_NavframeFromTF; 
dCameraOrigin_NavFrame = dSCPos;
dCameraAttDCM_NavframeFromTF;
dBodiesOrigin_NavFrame = [dBody1Pos; dBody2Pos];
dBodiesAttDCM_NavFrameFromTF;

% Test renderImage method
dImg = objCortopyCommManager.renderImage(dSunVector_NavFrame, ...
                                        dSunAttDCM_NavframeFromTF, ...
                                        dCameraOrigin_NavFrame, ...
                                        dCameraAttDCM_NavframeFromTF, ...
                                        dBodiesOrigin_NavFrame, ...
                                        dBodiesAttDCM_NavFrameFromTF, ...
                                        kwargs);

%% CORTOpyCommManager_renderImageSequence
% TODO

