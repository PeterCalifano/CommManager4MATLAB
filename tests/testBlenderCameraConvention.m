function objTests = testBlenderCameraConvention()
%% SIGNATURE
% objTests = testBlenderCameraConvention()
% -------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Verify MATLAB [H,W]/vertical-horizontal camera fields at Blender's XY boundary.
% Test configuration and asymmetric RGBA/Bayer decoding without starting or contacting a server.
% MATLAB's functiontests entry point rejects argument-validation blocks.
% -------------------------------------------------------------------------------------------------
%% INPUT
% None. Select SimulationGears and YAML dependencies before running.
% -------------------------------------------------------------------------------------------------
%% OUTPUT
% objTests    Function-based unit tests.
% -------------------------------------------------------------------------------------------------
%% CHANGELOG
% 18-10-2026  Pietro Califano, Codex GPT-6.1  Cover camera ordering and unchanged wire orientation.
% 12-11-2026  Pietro Califano, Claude Opus 5.5  Readability pass; drop default-value assertions.
% -------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% BlenderPyCommManager, CCameraIntrinsics, CServerFreeBlenderPyCommManager, yaml.
% -------------------------------------------------------------------------------------------------

%% Function code
objTests = functiontests(localfunctions);
end

function setupOnce(~)
% Put the library sources and the server-free fixture on the path.
charRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(charRoot, 'src'), fullfile(charRoot, 'tests', 'helpers'));
end

function testExplicitCameraWithoutYamlIsKept(objTestCase)
% Construct the manager from an explicit camera and an explicit data type, without YAML.
objCamera = CCameraIntrinsics([7, 11], [2.75, 1.75], [4, 6], uint32(4));
objManager = MakeManager_(objTestCase, ...
    'objCameraIntrisincs', objCamera, ...
    'enumCommDataType', EnumCommDataType.UINT16, ...
    'i64RecvTCPsize', int64(-10));

% Expect the camera unchanged and the receive buffer sized as H*W*4 channels*2 bytes.
VerifyCamera_(objTestCase, objManager.objCameraIntrinsics, objCamera);
verifyEqual(objTestCase, objManager.enumCommDataType, EnumCommDataType.UINT16);
verifyEqual(objTestCase, objManager.i64RecvTCPsize, int64(4*6*4*2));
end

function testYamlXYCameraLoadsAsMatlabHW(objTestCase)
% Construct the manager from a Blender XY configuration only.
charYaml = MakeYaml_(objTestCase);
charBefore = fileread(charYaml);
objManager = MakeManager_(objTestCase, 'charConfigYamlFilename', string(charYaml));
objCamera = objManager.objCameraIntrinsics;

% Expect [H,W] fields, a centred principal point and the pinhole focal lengths of the configured FoV.
verifyEqual(objTestCase, objCamera.ImageSize, [4, 6]);
verifyEqual(objTestCase, objCamera.PrincipalPoint, [3.5, 2.5]);
verifyEqual(objTestCase, objCamera.FocalLength, [3/tand(38), 2/tand(21)], 'AbsTol', 1e-12);
verifyEqual(objTestCase, rad2deg(objCamera.dFovHW(:)), [42; 76], 'AbsTol', 1e-12);
verifyEqual(objTestCase, objCamera.ui32NumOfChannels, uint32(4));

% Expect the configuration file untouched.
verifyEqual(objTestCase, fileread(charYaml), charBefore);
end

function testExplicitCameraOverridesYamlWithoutReconstruction(objTestCase)
% Construct the manager from both a configuration and an explicit camera.
charYaml = MakeYaml_(objTestCase);
objCamera = CCameraIntrinsics([7, 11], [2.75, 1.75], [4, 6], uint32(4));
objManager = MakeManager_(objTestCase, ...
    'charConfigYamlFilename', string(charYaml), ...
    'objCameraIntrisincs', objCamera);

% Expect the explicit camera, including its non-centred principal point.
VerifyCamera_(objTestCase, objManager.objCameraIntrinsics, objCamera);
end

function testYamlWritesWidthHeightAndHorizontalVerticalFov(objTestCase)
% Construct the manager so that it rewrites the configuration from an explicit camera.
charYaml = MakeYaml_(objTestCase);
objCamera = CCameraIntrinsics([7, 11], [3.5, 2.5], [4, 6], uint32(4));
objManager = MakeManager_(objTestCase, ...
    'charConfigYamlFilename', string(charYaml), ...
    'objCameraIntrisincs', objCamera, ...
    'charDatasetSaveFolder', string(fileparts(charYaml)));

% Expect width and height in X and Y, and the horizontal and vertical FoV of the pinhole camera.
strWritten = yaml.loadFile(charYaml);
verifyEqual(objTestCase, strWritten.Camera_params.sensor_size_x, 6);
verifyEqual(objTestCase, strWritten.Camera_params.sensor_size_y, 4);
verifyEqual(objTestCase, strWritten.Camera_params.FOV_x, 2*atand(3/7), 'AbsTol', 1e-12);
verifyEqual(objTestCase, strWritten.Camera_params.FOV_y, 2*atand(2/11), 'AbsTol', 1e-12);
VerifyCamera_(objTestCase, objManager.objCameraIntrinsics, objCamera);
end

function testExplicitRgbCameraUsesRgbaWireBudget(objTestCase)
% Construct the manager from a configuration and an explicit RGB camera.
charYaml = MakeYaml_(objTestCase);
objCamera = CCameraIntrinsics([7, 11], [2.75, 1.75], [4, 6], uint32(3));
objManager = MakeManager_(objTestCase, ...
    'charConfigYamlFilename', string(charYaml), ...
    'objCameraIntrisincs', objCamera, ...
    'i64RecvTCPsize', int64(-10));

% Expect three logical channels and a receive buffer sized for RGBA doubles.
VerifyCamera_(objTestCase, objManager.objCameraIntrinsics, objCamera);
verifyEqual(objTestCase, objManager.i64RecvTCPsize, int64(4*6*4*8));

% Expect a buffer of exactly that size to decode to the encoded image.
[dWire, dExpected] = MakeAsymmetricRgba_();
dReceived = dWire(1:double(objManager.i64RecvTCPsize)/8);
verifyEqual(objTestCase, objManager.unpackImageFromCORTO(dReceived, false, true), dExpected);
end

function testExplicitRgbCameraWithoutYamlUsesRgbaWireBudget(objTestCase)
% Construct the manager from an explicit RGB camera and double transport, without YAML.
objCamera = CCameraIntrinsics([7, 11], [2.75, 1.75], [4, 6], uint32(3));
objManager = MakeManager_(objTestCase, ...
    'objCameraIntrisincs', objCamera, ...
    'enumCommDataType', EnumCommDataType.DOUBLE, ...
    'i64RecvTCPsize', int64(-10));

% Expect the camera unchanged and a receive buffer sized for RGBA doubles.
VerifyCamera_(objTestCase, objManager.objCameraIntrinsics, objCamera);
verifyEqual(objTestCase, objManager.i64RecvTCPsize, int64(4*6*4*8));
end

function testRgbWireOrientationAndChannelsArePreserved(objTestCase)
% Decode an asymmetric RGBA buffer through an explicit RGBA camera.
[dWire, dExpected] = MakeAsymmetricRgba_();
objCamera = CCameraIntrinsics([7, 11], [3.5, 2.5], [4, 6], uint32(4));
objManager = MakeManager_(objTestCase, 'objCameraIntrisincs', objCamera);
dActual = objManager.unpackImageFromCORTO(dWire, false, true);

% Expect an [H,W,3] image with the top-left red and bottom-right blue values in place.
verifyEqual(objTestCase, size(dActual), [4, 6, 3]);
verifyEqual(objTestCase, dActual, dExpected);
verifyEqual(objTestCase, dActual(1, 1, 1), 111);
verifyEqual(objTestCase, dActual(4, 6, 3), 346);
end

function testBayerRetainsBggrPatternInMatlabHW(objTestCase)
% Decode the asymmetric RGBA buffer with the Bayer filter enabled.
[dWire, dRgb] = MakeAsymmetricRgba_();
objCamera = CCameraIntrinsics([7, 11], [3.5, 2.5], [4, 6], uint32(4));
objManager = MakeManager_(objTestCase, 'objCameraIntrisincs', objCamera);
dActual = objManager.unpackImageFromCORTO(dWire, true, true);

% Expect the BGGR mosaic of the encoded image: blue, green / green, red on each 2x2 cell.
dExpected = zeros(4, 6);
dExpected(1:2:end, 1:2:end) = dRgb(1:2:end, 1:2:end, 3);
dExpected(1:2:end, 2:2:end) = dRgb(1:2:end, 2:2:end, 2);
dExpected(2:2:end, 1:2:end) = dRgb(2:2:end, 1:2:end, 2);
dExpected(2:2:end, 2:2:end) = dRgb(2:2:end, 2:2:end, 1);
verifyEqual(objTestCase, size(dActual), [4, 6]);
verifyEqual(objTestCase, dActual, dExpected);
end

function objManager = MakeManager_(objTestCase, varargin)
%% SIGNATURE
% objManager = MakeManager_(objTestCase, varargin)
% -------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Construct a manager and release its host object after the test.
% -------------------------------------------------------------------------------------------------
%% INPUT
% objTestCase    MATLAB test case.
% varargin       Constructor camera and YAML options.
% -------------------------------------------------------------------------------------------------
%% OUTPUT
% objManager     Manager that never initializes communication or a server.
% -------------------------------------------------------------------------------------------------
%% CHANGELOG
% 18-10-2026  Pietro Califano, Codex GPT-6.1  Add server-free ownership helper.
% -------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% CServerFreeBlenderPyCommManager.
% -------------------------------------------------------------------------------------------------
arguments (Input)
    objTestCase (1,1) matlab.unittest.TestCase
end
arguments (Input, Repeating)
    varargin
end
arguments (Output)
    objManager (1,1) CServerFreeBlenderPyCommManager
end

%% Function code
objManager = CServerFreeBlenderPyCommManager(varargin{:});
objTestCase.addTeardown(@() delete(objManager));
end

function VerifyCamera_(objTestCase, objActual, objExpected)
%% SIGNATURE
% VerifyCamera_(objTestCase, objActual, objExpected)
% -------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Verify explicit calibration is preserved, including a non-centred principal point.
% -------------------------------------------------------------------------------------------------
%% INPUT
% objTestCase    MATLAB test case.
% objActual      Camera held by the manager.
% objExpected    Camera passed to the manager.
% -------------------------------------------------------------------------------------------------
%% OUTPUT
% None.
% -------------------------------------------------------------------------------------------------
%% CHANGELOG
% 18-10-2026  Pietro Califano, Codex GPT-6.1  Cover explicit camera input.
% -------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% CCameraIntrinsics.
% -------------------------------------------------------------------------------------------------
arguments (Input)
    objTestCase (1,1) matlab.unittest.TestCase
    objActual (1,1) CCameraIntrinsics
    objExpected (1,1) CCameraIntrinsics
end

%% Function code
verifyEqual(objTestCase, objActual.ImageSize, objExpected.ImageSize);
verifyEqual(objTestCase, objActual.FocalLength, objExpected.FocalLength);
verifyEqual(objTestCase, objActual.PrincipalPoint, objExpected.PrincipalPoint);
verifyEqual(objTestCase, objActual.dFovHW, objExpected.dFovHW);
verifyEqual(objTestCase, objActual.ui32NumOfChannels, objExpected.ui32NumOfChannels);
end

function charYaml = MakeYaml_(objTestCase)
%% SIGNATURE
% charYaml = MakeYaml_(objTestCase)
% -------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Write a disposable Blender XY camera configuration: 6 px wide, 4 px high, 76 deg by 42 deg FoV.
% -------------------------------------------------------------------------------------------------
%% INPUT
% objTestCase    MATLAB test case owning folder cleanup.
% -------------------------------------------------------------------------------------------------
%% OUTPUT
% charYaml       Configuration file path.
% -------------------------------------------------------------------------------------------------
%% CHANGELOG
% 18-10-2026  Pietro Califano, Codex GPT-6.1  Supply asymmetric camera fields without assets.
% -------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% yaml.dumpFile.
% -------------------------------------------------------------------------------------------------
arguments (Input)
    objTestCase (1,1) matlab.unittest.TestCase
end
arguments (Output)
    charYaml (1,:) char
end

%% Function code
% Create a temporary folder removed after the test.
charFolder = tempname;
mkdir(charFolder);
objTestCase.addTeardown(@() rmdir(charFolder, 's'));
charYaml = fullfile(charFolder, 'camera.yml');

% Write the server, camera, renderer and model sections through the yaml package.
strConfig = struct( ...
    'Server_params', struct( ...
        'output_path', charFolder, ...
        'image_dtype', 'double'), ...
    'Camera_params', struct( ...
        'sensor_size_x', 6, ...
        'sensor_size_y', 4, ...
        'FOV_x', 76, ...
        'FOV_y', 42, ...
        'n_channels', 3, ...
        'bit_encoding', 8, ...
        'compression', 100), ...
    'RenderingEngine_params', struct( ...
        'file_format', 'PNG', ...
        'device', 'CPU'), ...
    'BlenderModel_params', struct( ...
        'bodies_names', {{'fixture'}}));
yaml.dumpFile(charYaml, strConfig, "block");
end

function [dWire, dExpected] = MakeAsymmetricRgba_()
%% SIGNATURE
% [dWire, dExpected] = MakeAsymmetricRgba_()
% -------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Encode distinguishable pixels as interleaved RGBA, bottom row first and left to right.
% Each value encodes its channel (hundreds), row (tens) and column (units).
% -------------------------------------------------------------------------------------------------
%% INPUT
% None.
% -------------------------------------------------------------------------------------------------
%% OUTPUT
% dWire          Column buffer in Blender wire order.
% dExpected      Top-row-first MATLAB RGB tensor.
% -------------------------------------------------------------------------------------------------
%% CHANGELOG
% 18-10-2026  Pietro Califano, Codex GPT-6.1  Detect row/column/channel orientation changes.
% -------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% None.
% -------------------------------------------------------------------------------------------------
arguments (Output)
    dWire (:,1) double
    dExpected (4,6,3) double
end

%% Function code
dExpected = zeros(4, 6, 3);
dWire = zeros(4*6*4, 1);
ui32Entry = uint32(1);

% Walk the rows bottom to top and the columns left to right, appending alpha 999 to each pixel.
for ui32Row = uint32(4:-1:1)
    for ui32Column = uint32(1):uint32(6)
        dPixel = [100+10*double(ui32Row)+double(ui32Column); ...
            200+10*double(ui32Row)+double(ui32Column); ...
            300+10*double(ui32Row)+double(ui32Column)];
        dExpected(ui32Row, ui32Column, :) = reshape(dPixel, 1, 1, 3);
        dWire(ui32Entry:ui32Entry+3) = [dPixel; 999];
        ui32Entry = ui32Entry+4;
    end
end
end
