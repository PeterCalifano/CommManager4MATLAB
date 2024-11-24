close all
clear
clc

%% TEST SCRIPT: CommManager class 
%% DESCRIPTION
% What the script does
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 12-06-2024     Pietro Califano     Script initialized.

% Define object properties
serverAddress = " ";
portNumber = 1;

% Create communication handler
commHandler = CommManager(serverAddress, portNumber, 20);

% Initialize tcpclient object and communication to server
commHandler.Initialize()

% Test function to write data buffer
%TODO
dataBuffer = 0;
commHandler.WriteBuffer(dataBuffer);

% Test function to read data buffer
%TODO
recvBuffer = commHandler.ReadBuffer();





