close all
clear
clc

%% Unit test for CORTO interfaces and CommManager (S5 Didymos Milani scenario)
% SUN:   POS [-1.87979488e+08  2.98313209e+04  5.99584851e+07] - Q [ 0.57104144  0.41702718 -0.41731124 -0.57083389]
% SC:    POS [0. 0. 0.] - Q [1. 0. 0. 0.]
% BODY (0):   POS: [  0.16706893   0.0235506  -13.93270439] - Q [-0.05240883 -0.20821087  0.76502471  0.60715537]
% BODY (1):   POS: [  0.96841929   0.38199128 -13.145638  ] - Q [-0.17513088 -0.35985445  0.70648485  0.58370726]

%% Test data from milani-gnc simulation
dSunPos  = [-1.87979488e+08  2.98313209e+04  5.99584851e+07];
dSunQuat = [ 0.57104144  0.41702718 -0.41731124 -0.57083389];

dSCPos  = [0. 0. 0.];
dSCquat = [1. 0. 0. 0.];

dBody1Pos = [  0.16706893   0.0235506  -13.93270439]; % [BU] 
dBody2Pos = [  0.96841929   0.38199128 -13.145638  ]; % [BU]

dBody1Quat = [-0.05240883 -0.20821087  0.76502471  0.60715537]; % [BU] 
dBody2Quat = [-0.17513088 -0.35985445  0.70648485  0.58370726]; % [BU]

BlenderModelPath = '/home/peterc/devDir/rendering-sw/corto_PeterCdev/input/OLD_ones_0.1/S5_Didymos_Milani/S5_Didymos_Milani.blend';

charScriptName = 'CORTO_to_Simulink_HF_1_d.py';
CORTO_pyInterface_path = '/home/peterc/devDir/projects-DART/milani-gnc/script/CORTO_interfaces/corto_PeterCdev/scripts/';
CORTO_pyInterface_path = strcat(CORTO_pyInterface_path, charScriptName);

% Construct command to run
charStartBlenderCommand = sprintf('bash script/CORTO_interfaces/StartBlenderServer.sh -m "%s" -p "%s"', ...
    BlenderModelPath, CORTO_pyInterface_path);

% system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
charStartBlenderCommand = strcat(charStartBlenderCommand, " > /tmp/blender_pipe &");

% Execute the command
% [~, result] = system(charStartBlenderCommand);

[status, result] = system('ps aux | grep blender'); % Check if process is running
disp(result);

%% 
% TODO (PC): add code to test UDP-TCP server with CORTO interface

% Compose and cast buffer
dBuffer = [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat, dBody2Pos, dBody2Quat];
ui8Buffer = typecast(dBuffer, 'uint8');

% Create CommManager object
charServerAddress = 'localhost';
ui32ServerPort = [30001, 51000]; % [TCP, UDP]
ui32TargetPort = 51001;
dCommTimeout = 20;
objCommManager = CommManager(charServerAddress, ui32ServerPort, ...
    dCommTimeout, "bLittleEndianOrdering", false, ...
    "enumCommMode", "UDP_TCP", "ui32RecvTCPsize", 8*4*2048*1536);

% Test initialization
objCommManager.Initialize();

% Test write
writtenBytes = objCommManager.WriteBuffer(ui8Buffer, false, ui32TargetPort);

% Test read
[recvBytes, recvDataBuffer, self] = objCommManager.ReadBuffer(); % TODO (PC) check endianness of recv

% Try to swap bytes?
% bytes = read(tcpClient, numBytes, 'uint8');
% data = typecast(uint8(bytes), 'single');
% recvDataBuffer = swapbytes(recvDataBuffer); % NOT NEEDED 

% Cast buffer to double and display image
dImgRGB = UnpackImageFromCORTO(recvDataVector);
imshow(dImgRGB);

return
%% Code to kill Blender processes
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
        fprintf('Killing process %s...', pid{:})
        system(sprintf('kill -9 %s', pid{:}));
    end
end
