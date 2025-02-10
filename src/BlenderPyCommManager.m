classdef BlenderPyCommManager < CommManager
    %% CONSTRUCTOR
    %
    % -------------------------------------------------------------------------------------------------------------
    %% DESCRIPTION
    %
    % -------------------------------------------------------------------------------------------------------------
    %% DATA MEMBERS
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 13-01-2025    Pietro Califano     First prototype implementation deriving from CommManager.
    % 20-01-2025    Pietro Califano     Implementation of methods for Blender inputs preparation and
    %                                   rendering loop execution for dataset generation.
    % 31-01-2024    Pietro Califano     Implement auto management of Blender server for Linux.
    % 07-02-2025    Pietro Califano     Major update of class to introduce camera object, improve
    %                                   configuration and communication handling. Render methods tested.
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % Functions and classes in SimulationGears_for_SpaceNav repository. Specifiocally, CCameraIntrinsics.
    % git@github.com:PeterCalifano/SimulationGears_for_SpaceNav.git
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Function code


    properties (SetAccess = protected, GetAccess = public)
        
        % ui32BlenderRecvPort % Get from yaml file else from input
        % ui32ServerPort % Get from yaml if specified else from input % Defined in superclass
        
        % Configuration
        bSendLogToShellPipe                     (1,1) logical {islogical, isscalar} = false % FIXME, not working is true due to system call failure

        charBlenderModelPath                (1,1) string {mustBeA(charBlenderModelPath, ["string", "char"])}
        charBlenderPyInterfacePath            (1,1) string {mustBeA(charBlenderPyInterfacePath, ["string", "char"])}  
        charStartBlenderServerCallerPath    (1,1) string {mustBeA(charStartBlenderServerCallerPath, ["string", "char"])}
        
        % Bytes to image conversion params
        objCameraIntrinsics = CCameraIntrinsics()
        % bApplyBayerFilter (1,1) logical {islogical, isscalar} = false;
        % bIsImageRGB       (1,1) logical {islogical, isscalar} = false;

        enumCommDataType (1,1) {mustBeA(enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.DOUBLE

        % Runtime flags
        bIsValidServerAutoManegementConfig      (1,1) logical {islogical, isscalar} = false
        bIsServerRunning                        (1,1) logical {islogical, isscalar} = false
    end


    %% PUBLIC methods
    methods (Access = public)
        % CONSTRUCTOR
        function self = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
            arguments
                charServerAddress (1,:) {ischar, isstring}              = "127.0.0.1" % Assumes localhost
                ui32ServerPort    (1,2) uint32  {isvector, isnumeric}   = [30001, 51000]; % [TCP, UDP] Assumes ports used by BlenderPy interface
                dCommTimeout      (1,1) double  {isscalar, isnumeric}   = 45
            end
            % TODO: adjust kwargs required for BlenderPy
            arguments
                kwargs.bInitInPlace                     (1,1) logical       {islogical, isscalar} = false
                kwargs.enumCommMode                     (1,1) EnumCommMode  {isa(kwargs.enumCommMode, 'EnumCommMode')} = EnumCommMode.UDP_TCP
                kwargs.bLittleEndianOrdering            (1,1) logical       {islogical, isscalar} = true;
                kwargs.dOutputDatagramSize              (1,1) double        {isscalar, isnumeric} = 512
                kwargs.ui32TargetPort                   (1,1) uint32        {isscalar, isnumeric} = 0
                kwargs.charTargetAddress                (1,:) string        {mustBeA(kwargs.charTargetAddress , ["string", "char"])} = "127.0.0.1"
                kwargs.i64RecvTCPsize                   (1,1) int64         {isscalar, isnumeric} = -1; % SPECIAL MODE: -5, -10 (auto compute)
                kwargs.charConfigYamlFilename           (1,:) string        {mustBeA(kwargs.charConfigYamlFilename , ["string", "char"])}  = ""
                kwargs.bAutoManageBlenderServer         (1,1) logical       {isscalar, islogical} = false
                kwargs.charStartBlenderServerCallerPath (1,:) string        {mustBeA(kwargs.charStartBlenderServerCallerPath , ["string", "char"])} = ""
                kwargs.charBlenderModelPath             (1,:) string        {mustBeA(kwargs.charBlenderModelPath , ["string", "char"])} = ""
                kwargs.charBlenderPyInterfacePath       (1,:) string        {mustBeA(kwargs.charBlenderPyInterfacePath , ["string", "char"])} = ""
                kwargs.objCameraIntrisincs              (1,1)               {mustBeA(kwargs.objCameraIntrisincs, "CCameraIntrinsics")} = CCameraIntrinsics()
                kwargs.enumCommDataType                 (1,1)               {mustBeA(kwargs.enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.UNSET
                kwargs.bSendLogToShellPipe              (1,1) logical  = false;
            end

            bIsValidServerAutoManegementConfig = false;

            % Check if auto management can be used
            if isunix()

                if kwargs.bAutoManageBlenderServer && strcmpi(kwargs.charStartBlenderServerCallerPath, "")
                    % If requested but not configured correctly
                    warning(['Auto management requested, but charStartBlenderServerCallerPath not set. ' ...
                        'Mode cannot be enabled: please manage server manually.'])
                    bIsValidServerAutoManegementConfig = false;

                    if any([strcmpi(kwargs.charBlenderModelPath , ""), strcmpi(kwargs.charBlenderPyInterfacePath, "")])
                        error("Auto management requested, but either charBlenderPyInterfacePath or charBlenderModelPath paths are undefined.")
                    end

                    if kwargs.bInitInPlace
                        error('Auto manegement requested together with connection in-place, but cannot be enabled. Throwing error (connection attempt would fail) ...')
                    end

                elseif kwargs.bAutoManageBlenderServer
                    % All inputs provided
                    disp('Auto management of Blender server set to enabled.')
                    bIsValidServerAutoManegementConfig = true;
                else
                    disp('Auto management mode for Blender server disabled. Please make sure the server is open before attemping connection.')
                end

            elseif kwargs.bAutoManageBlenderServer
                % Requested but not on Linux
                warning('Auto management requested, but is only supported on Linux.')
                bIsValidServerAutoManegementConfig = false;
             end


            % Run blender server automanagement code (after base class instantiation)
            if bIsValidServerAutoManegementConfig
                % Override init in place and connect after starting server
                bInitInPlace = false;
            else
                % Manually management of server
                bInitInPlace = kwargs.bInitInPlace;
            end

            % Initialize base class to define self 
            self = self@CommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
                'bUSE_PYTHON_PROTO', false, 'bUSE_CPP_PROTO', false, 'bInitInPlace', bInitInPlace, ...
                'charTargetAddress', kwargs.charTargetAddress, 'bLittleEndianOrdering', kwargs.bLittleEndianOrdering, ...
                'dOutputDatagramSize', kwargs.dOutputDatagramSize, 'enumCommMode', kwargs.enumCommMode, ...
                'i64RecvTCPsize', kwargs.i64RecvTCPsize, 'ui32TargetPort',  kwargs.ui32TargetPort);

            self.bDefaultConstructed = false; % This class cannot be constructed as non-functional.

            % Store paths
            self.charStartBlenderServerCallerPath = kwargs.charStartBlenderServerCallerPath;
            self.charBlenderModelPath = kwargs.charBlenderModelPath;
            self.charBlenderPyInterfacePath = kwargs.charBlenderPyInterfacePath;
            self.bIsValidServerAutoManegementConfig = bIsValidServerAutoManegementConfig;
            self.ui32ServerPort = ui32ServerPort;
            self.bSendLogToShellPipe = kwargs.bSendLogToShellPipe;

            % Start server if in auto management mode
            if bIsValidServerAutoManegementConfig
                [self.bIsServerRunning] = self.startBlenderServer();
            end

            % Parse yaml configuration file if provided
            if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                self.parseYamlConfig_(kwargs.charConfigYamlFilename);
            end

            % Determine transmission dtype
            % Input kwargs overrides all
            if not(kwargs.enumCommDataType == EnumCommDataType.UNSET)
                self.enumCommDataType  = kwargs.enumCommDataType;

                if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                    warning('Both datatype option and yaml configuration file specified. Input datatype overrides specification. Please remove it if this is unintended.')
                end

            elseif not(strcmpi(kwargs.charConfigYamlFilename, ""))
                self.enumCommDataType = upper(self.strConfigFromYaml.image_dtype);
            end

            if self.i64RecvTCPsize == -10
                switch self.enumCommDataType

                    case "DOUBLE"
                        dMSG_ENTRY_BYTES_SIZE = 8; % TODO: generalize for different dtype

                    case "SINGLE"
                        dMSG_ENTRY_BYTES_SIZE = 4; % TODO: generalize for different dtype

                    case "UINT8"
                        dMSG_ENTRY_BYTES_SIZE = 1; % TODO: generalize for different dtype

                    case "UINT16"
                        dMSG_ENTRY_BYTES_SIZE = 2; % TODO: generalize for different dtype

                    case "UINT32"
                        dMSG_ENTRY_BYTES_SIZE = 4; % TODO: generalize for different dtype

                    case "UNSET"
                        warning('Unset message entry datatype: assuming double by default (8 bytes per entry).')
                        self.enumCommDataType = "DOUBLE";
                end
            end

            % Load camera data from object, yaml config or default data (Milani NavCam)
            % Input object overrides all

            if not(kwargs.objCameraIntrisincs.bDefaultConstructed)
                fprintf('\nCamera parameters initialized from input object.\n')
                self.objCameraIntrinsics = kwargs.objCameraIntrisincs;

                if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                    warning('Both camera object and yaml configuration file specified. Camera object overrides parameters. Please remove it if this is unintended.')
                end

            elseif kwargs.objCameraIntrisincs.bDefaultConstructed && not(strcmpi(kwargs.charConfigYamlFilename, ""))
                fprintf('\nCamera parameters initialized from yaml configuration file.\n')
                % Get params from file

                % Construct camera intrinsics object and assign
                dFOV_x              = self.strConfigFromYaml.Camera_Params.FOV_x; % [deg] Horizontal Field of View
                dFOV_y              = self.strConfigFromYaml.Camera_Params.FOV_Y; % [deg] Vertical Field of View
                dSensor_size_x      = self.strConfigFromYaml.Camera_Params.sensor_size_x; % [px] Horizontal resolution
                dSensor_size_y      = self.strConfigFromYaml.Camera_Params.sensor_size_y; % [px] Vertical resolution
                ui32NumOfChannels   = self.strConfigFromYaml.Camera_Params.n_channels;

                dPrincipalPoint_uv = [dSensor_size_x, dSensor_size_y]./2;
            
                % TODO: add assert on rounding! Must be integer

                % self.ui32NumOfChannels = self.strConfigFromYaml.Camera_Params.n_channels;
                dFocalLength_uv = [(dSensor_size_x / 2) / tand(dFOV_x / 2), (dSensor_size_y / 2) / tand(dFOV_y / 2)];

                % Construct camera intrinsics object
                self.objCameraIntrinsics = CCameraIntrinsics( dFocalLength_uv, dPrincipalPoint_uv, [dSensor_size_x, dSensor_size_y], ui32NumOfChannels );

            else
                % Assume Milani/RCS-1 NavCam parameters
                warning('No camera object nor yaml configuration file specified. Assuming Milani NavCam parameters.')

                dFOV_x = 21; % [deg]
                dFOV_y = 16;
                dSensor_size_x = 2048; % [px]
                dSensor_size_y = 1536; 
                ui32NumOfChannels = uint32(4); % RGBA

                dFocalLength_uv = [(dSensor_size_x / 2) / tand(dFOV_x / 2), (dSensor_size_y / 2) / tand(dFOV_y / 2)];
                ui32ImageSize = [dSensor_size_x, dSensor_size_y];
                dPrincipalPoint = double(ui32ImageSize)/2;

                self.objCameraIntrinsics = CCameraIntrinsics(dFocalLength_uv, dPrincipalPoint, ui32ImageSize, ui32NumOfChannels);

                dMSG_ENTRY_BYTES_SIZE = 8;
                self.enumCommDataType = EnumCommDataType.DOUBLE;

                % Assign TCP recv size (fixed in Milani/RCS-1 case
                % self.i64RecvTCPsize = int64(4 * 2048 * 1536 * dBYTES_IN_DOUBLE);
            end

            % Auto compute TCP message recv size from camera data if available
            if self.i64RecvTCPsize == -10

                % Compute recv TCP buffer size
                dAutoComputedRecvTCPsize = (self.objCameraIntrinsics.ui32NumOfChannels * ...
                                            self.objCameraIntrinsics.ImageSize(2) * ...
                                            self.objCameraIntrinsics.ImageSize(1) * ...
                                            dMSG_ENTRY_BYTES_SIZE);

                % Set buffer size
                self.i64RecvTCPsize = int64(dAutoComputedRecvTCPsize);

            end

            % Print camera parameters for monitoring
            self.printCameraParams()

            % Check if initialization in place is configured correctly
            if kwargs.bInitInPlace && kwargs.ui32TargetPort == 0
                warning(['You requested connection of TCP at instantiation of class, but no ui32TargetPort was specified. ' ...
                    'Make sure to pass it when sending data or set it before attempting'])
            end

            % If connection in place, try to connect to server
            if bIsValidServerAutoManegementConfig && bInitInPlace == false
                self.Initialize(); % TODO check this call is ok
            end

        end
        
        % DESTRUCTOR
        function delete(self)
            % If auto management of Blender server, call termination method
            if self.bIsValidServerAutoManegementConfig && self.bIsServerRunning
                self.terminateBlenderProcesses();
            end
        end
        
        % SETTERS
        function setTargetPortUDP(self, ui32TargetPort)
            arguments
                self
                ui32TargetPort                   (1,1) uint32        {isscalar, isnumeric} = 51001 % Defaut for CORTO UDP recv
            end

            self.ui32TargetPort = ui32TargetPort;
        end

        % GETTERS
        function printCameraParams(self, objCameraIntrinsics)
            arguments
                self
                objCameraIntrinsics (1,1) {mustBeA(objCameraIntrinsics, "CCameraIntrinsics")} = CCameraIntrinsics()
            end


            if objCameraIntrinsics.bDefaultConstructed
                % Use camera object in self
                objCameraIntrinsics = self.objCameraIntrinsics;
            end


            fprintf("\nBlenderPyCommManager will use the following camera parameters:\n");

            % Focal Length
            fprintf(" - Focal length: [%.2f, %.2f] [mm or px] (X, Y)\n", objCameraIntrinsics.FocalLength(1), objCameraIntrinsics.FocalLength(2));

            % Field of View (FoV)
            fprintf(" - Field of View (FoV): [%.2f, %.2f] degrees (X, Y)\n", rad2deg(objCameraIntrinsics.dFovHW(1)), rad2deg(objCameraIntrinsics.dFovHW(2)));

            % Image Size
            fprintf(" - Image size: [%d, %d] pixels (Width X, Height Y)\n", objCameraIntrinsics.ImageSize(1), objCameraIntrinsics.ImageSize(2));

            % Image Type
            if objCameraIntrinsics.ui32NumOfChannels == 3 || objCameraIntrinsics.ui32NumOfChannels == 4
                fprintf(" - Image type: RGB (3-4 channels). Blender will send 4 channels (with Alpha)\n");
            elseif objCameraIntrinsics.ui32NumOfChannels == 1
                fprintf(" - Image type: Grayscale (1 channel)\n");
            else
                error('Invalid number of channels. Expected 1 (Grayscale) or 3/4 (RGB/RGBA) but found %d', objCameraIntrinsics.ui32NumOfChannels)
            end

            % Image Data Type
            fprintf("\n Communication buffer details:\n")
            fprintf(" - Image data type for transmission: %s\n", self.enumCommDataType);

            % Assumed Buffer Size for TCP Transmission
            fprintf(" - Assumed buffer size for TCP transmission: %d bytes\n", self.i64RecvTCPsize);
        end

        % METHODS
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % IMAGES SEQUENCE RENDERING from "disaggregated" scene data
        function [outImgArrays, objSceneFigs, self] = renderImageSequence(self, dSunVector_Buffer_NavFrame , ...
                                                         dCameraOrigin_Buffer_NavFrame, ...
                                                         dCameraAttDCM_Buffer_NavframeFromOF, ...
                                                         dBodiesOrigin_Buffer_NavFrame, ...
                                                         dBodiesAttDCM_Buffer_NavFrameFromOF, ...
                                                         kwargs)
            arguments (Input)
                self
                dSunVector_Buffer_NavFrame              (3,:)   double {isvector, isnumeric}
                dCameraOrigin_Buffer_NavFrame           (3,:)   double {isvector, isnumeric}
                dCameraAttDCM_Buffer_NavframeFromOF     (3,3,:) double {ismatrix, isnumeric}
                dBodiesOrigin_Buffer_NavFrame           (3,:,:)   double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_Buffer_NavFrameFromOF     (3,3,:,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments (Input)
                kwargs.ui32TargetPort                  (1,1) uint32 {isscalar, isnumeric} = 0
                kwargs.charOutputDatatype              (1,:) string {isa(kwargs.charOutputDatatype, 'string')} = "uint8"
                kwargs.ui32NumOfBodies                 (1,1) uint32 {isnumeric, isscalar} = 1
                kwargs.objCameraIntrinsics             (1,1) {mustBeA(kwargs.objCameraIntrinsics, "CCameraIntrinsics")} = CCameraIntrinsics()
                kwargs.enumRenderingFrame              (1,1) EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.CUSTOM_FRAME % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.bEnableFramesPlot               (1,1) logical {islogical} = false;
                kwargs.bConvertCamQuatToBlenderQuat    (1,1) logical {isscalar, islogical} = true;
                kwargs.bDisplayImage                   (1,1) logical {islogical} = false;
            end
                
            % Determine number of images from camera origin array
            ui32NumOfImages = uint32(size(dCameraOrigin_Buffer_NavFrame, 2));

            % Determine number of bodies and check validity
            % Default number of body is 1. Overridden by yaml configuration if any.
            ui32NumOfBodies     = kwargs.ui32NumOfBodies;
            if not(strcmpi(self.charConfigYamlFilename, ""))
                ui32NumOfBodies = uint32(self.strConfigFromYaml.num_bodies);
            end

            if (ui32NumOfBodies == 1 && ui32NumOfImages > 1) || (ui32NumOfImages == 1 && ui32NumOfBodies > 1)
                assert( ndims(dBodiesAttDCM_Buffer_NavFrameFromOF) == 3);
            elseif ui32NumOfBodies == 1 && ui32NumOfImages == 1
                assert( ismatrix(dBodiesAttDCM_Buffer_NavFrameFromOF));
            elseif ui32NumOfBodies > 1 && ui32NumOfImages > 1
                assert( ndims(dBodiesAttDCM_Buffer_NavFrameFromOF) == 4);
            else
                error('Invalid size of dBodiesAttDCM_Buffer_NavFrameFromOF')
            end

            % Assert validity of other buffers
            assert(size(dSunVector_Buffer_NavFrame, 2) == ui32NumOfImages, ...
                'dSunVector_Buffer_NavFrame must have the same number of columns as images.');

            assert(size(dCameraAttDCM_Buffer_NavframeFromOF, 3) == ui32NumOfImages, ...
                'dCameraAttDCM_Buffer_NavframeFromOF must have the same 3rd dimension as images.');

            assert(size(dBodiesOrigin_Buffer_NavFrame, 3) == kwargs.ui32NumOfBodies, ...
                'dBodiesOrigin_Buffer_NavFrame must have the same 3rd dimension as number of bodies.');

            assert(size(dBodiesAttDCM_Buffer_NavFrameFromOF, 4) == kwargs.ui32NumOfBodies, ...
                'dBodiesAttDCM_Buffer_NavFrameFromOF must have the same 4th dimension as number of bodies.');


            % Optionally the user may instantiate the class or set the data for rendering sequence before calling this method. Default args uses class attributes.
            % TODO (PC) complete configuration setup for method. Need to add indexing of input yaml config
            if kwargs.objCameraIntrinsics.bDefaultConstructed && self.objCameraIntrinsics.bDefaultConstructed
                error('No camera parameters specified at instantiation or as input to this method. Please retry providing a valid CCameraIntrinsics object.')
            
            elseif not(kwargs.objCameraIntrinsics.bDefaultConstructed) && not(self.objCameraIntrinsics.bDefaultConstructed)
                warning('A valid CCameraIntrinsics is available from class instantiation but is overridden by input objCameraIntrisincs object.')
                fprintf('\nUsing camera parameters from input object\n')
                
                objCameraIntrinsics_ = kwargs.objCameraIntrinsics;

            elseif not(self.objCameraIntrinsics.bDefaultConstructed) && kwargs.objCameraIntrinsics.bDefaultConstructed
                % Get camera parameters from
                objCameraIntrinsics_ = self.objCameraIntrinsics;

            else
                error('Invalid class configuration: error in retrieving camera parameters from instance or input!');
            end


            % Determine target post and override instance setting if provided as input
            if kwargs.ui32TargetPort > 0
                % Temporarily override set target port
                ui32PrevPort = self.ui32TargetPort;
                self.ui32TargetPort = kwargs.ui32TargetPort;
            end

            % Input and validation checks 
                        
            % Rendering loop
            % outImgArrays = zeros(objCameraIntrinsics_.ImageSize(1), objCameraIntrinsics_.ImageSize(2), ...
            %     objCameraIntrinsics_.ui32NumOfChannels, ui32NumOfImages, char( kwargs.charOutputDatatype) );

            outImgArrays = zeros(objCameraIntrinsics_.ImageSize(2), objCameraIntrinsics_.ImageSize(1), ...
                ui32NumOfImages, char( kwargs.charOutputDatatype) );
            % BlenderPyCommManager.computeSunBlenderQuatFromPosition(dSunVector_NavFrame);

            if kwargs.enumRenderingFrame == "CUSTOM_FRAME"
                fprintf("\nScene data specified with respect to a custom frame. No check or transformation of the inputs is performed at rendering time.\n")
            end

            objSceneFigs = gobjects(ui32NumOfImages, 1);

            for idImg = 1:ui32NumOfImages
                
                % Get data from buffers
                dSunVector_NavFrame             = dSunVector_Buffer_NavFrame         (:, idImg);
                dCameraOrigin_NavFrame          = dCameraOrigin_Buffer_NavFrame      (:, idImg);
                dCameraAttDCM_NavframeFromOF    = dCameraAttDCM_Buffer_NavframeFromOF(:,:, idImg);

                if ui32NumOfBodies == 1
                    % Handle single body assuming 2D and 3D arrays as inputs
                    dBodiesOrigin_NavFrame          = dBodiesOrigin_Buffer_NavFrame      (:, idImg);
                    dBodiesAttDCM_NavFrameFromOF    = dBodiesAttDCM_Buffer_NavFrameFromOF(:,:, idImg);

                else
                    % Handle multiple bodies as 3D and 4D matrices for positions and DCMs
                    dBodiesOrigin_NavFrame          = dBodiesOrigin_Buffer_NavFrame      (:,:, idImg);
                    dBodiesAttDCM_NavFrameFromOF    = dBodiesAttDCM_Buffer_NavFrameFromOF(:,:,:, idImg);
                end

                try
                    if kwargs.bEnableFramesPlot
                        fprintf("\nProducing requested visualization of scene frames to render...\n")

                            % Convert DCMs to quaternion
                            dSceneEntityQuatArray_RenderFrameFromOF = transpose( dcm2quat(dBodiesAttDCM_NavFrameFromOF) );
                            dCameraQuat_RenderFrameFromCam          = transpose( dcm2quat(dCameraAttDCM_NavframeFromOF) );

                            % if kwargs.bConvertCamQuatToBlenderQuat
                            % DEVNOTE: removed because plot function operates using the same convention as
                            % this function, contrarily to Blender. Assuming that the plot is correct, the
                            % downstream operations should be correct too.
                            %     dCameraQuat_RenderFrameFromCam = BlenderPyCommManager.convertCamQuatToBlenderQuatStatic(dCameraQuat_RenderFrameFromCam);
                            % end

                            % Construct figure with plot
                            [objSceneFigs(idImg)] = PlotSceneFrames_Quat(dBodiesOrigin_NavFrame, ...
                                                                          dSceneEntityQuatArray_RenderFrameFromOF, ...
                                                                          dCameraOrigin_NavFrame, ...
                                                                          dCameraQuat_RenderFrameFromCam, 'bUseBlackBackground', true, ...
                                                                          "charFigTitle", "Visualization with Blender camera quaternion");
                    end

                catch ME
                    warning("Failed to reproduce visualization of scene frames due to error.")
                    fprintf("\n%s", string(ME.message))
                end

                fprintf("\nSending data to render image %d of %d...\n", idImg, ui32NumOfImages)
                % Call renderImage implementation ( TODO (PC) complete implementation ) 
                dImg = self.renderImage(dSunVector_NavFrame, ...
                                        dCameraOrigin_NavFrame, ...
                                        dCameraAttDCM_NavframeFromOF, ...
                                        dBodiesOrigin_NavFrame, ...
                                        dBodiesAttDCM_NavFrameFromOF, ...
                                        "enumRenderingFrame", kwargs.enumRenderingFrame, ...
                                        "ui32TargetPort", kwargs.ui32TargetPort, ...
                                        "bConvertCamQuatToBlenderQuat", kwargs.bConvertCamQuatToBlenderQuat); % TODO: specify kwargs and how to treat image


                % Store image into output array
                outImgArrays(1:self.objCameraIntrinsics.ImageSize(2), 1:self.objCameraIntrinsics.ImageSize(1), idImg) = cast(dImg, kwargs.charOutputDatatype);
                fprintf("Completed image %d of %d.\n", idImg, ui32NumOfImages)

                if kwargs.bDisplayImage
                    figure(95)
                    clf;
                    imshow( outImgArrays(:,:,idImg) )
                    axis image
                end


                % Get labels data
                % TODO (PC) next upgrade, transmit through TCP? TBD

                pause(0.5)
                
                if kwargs.bEnableFramesPlot
                    close(objSceneFigs(idImg)); % Close figure to prevent accumulation
                end
            end

            % Squeeze array if number of channels is equal to 1
            if objCameraIntrinsics_.ui32NumOfChannels == 1
                outImgArrays = squeeze(outImgArrays);
            end

            if kwargs.ui32TargetPort > 0
                % Reset target port to previous value
                self.ui32TargetPort = ui32PrevPort;
            end

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % SINGLE IMAGE RENDERING from "disaggregated" scene data
        function [dImg, self] = renderImage(self, dSunVector_NavFrame, ...
                                            dCameraOrigin_NavFrame, ...
                                            dCameraAttDCM_NavframeFromOF, ...
                                            dBodiesOrigin_NavFrame, ...
                                            dBodiesAttDCM_NavFrameFromOF, ...
                                            kwargs)
            arguments
                self
                dSunVector_NavFrame             (3,1)   double {isvector, isnumeric}
                dCameraOrigin_NavFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_NavframeFromOF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_NavFrame          (3,:)   double {ismatrix, isnumeric} = zeros(3,1)
                dBodiesAttDCM_NavFrameFromOF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame              (1,1) EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin              (3,1) double  {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_NavFrameFromRenderFrame    (3,3) double  {ismatrix, isnumeric} = eye(3)
                kwargs.ui32TargetPort                  (1,1) uint32  {isscalar, isnumeric} = 0
                kwargs.bConvertCamQuatToBlenderQuat    (1,1) logical {isscalar, islogical} = true;
            end
            
            % Input size and validation checks
            assert( size(dBodiesOrigin_NavFrame, 2) == size(dBodiesAttDCM_NavFrameFromOF, 3), 'Number of bodies position does not match number of attitude matrices')

            if kwargs.ui32TargetPort > 0
                % Temporarily override set target port
                ui32PrevPort = self.ui32TargetPort;
                self.ui32TargetPort = kwargs.ui32TargetPort;
            end

            % Determine size of vector
            dSceneDataVector = zeros(1, 7 * (2 + size(dBodiesOrigin_NavFrame, 2))); % [PQ_i] representation [SunPQ, CameraPQ, Body1PQ, ... BodyNPQ]

            % Convert disaggregated scene data to dSceneData vector representation
            dSceneDataVector(:) = self.composeSceneDataVector(dSunVector_NavFrame, dCameraOrigin_NavFrame, ...
                dCameraAttDCM_NavframeFromOF, dBodiesOrigin_NavFrame, dBodiesAttDCM_NavFrameFromOF, ...
                'enumRenderingFrame', kwargs.enumRenderingFrame, ...
                'dRenderFrameOrigin', kwargs.dRenderFrameOrigin, ...
                'dDCM_NavFrameFromRenderFrame', kwargs.dDCM_NavFrameFromRenderFrame, ...
                'bConvertCamQuatToBlenderQuat', kwargs.bConvertCamQuatToBlenderQuat);

            
            % TODO: rework renderImageFromPQ_ to avoid the need for these flags!
            if self.objCameraIntrinsics.ui32NumOfChannels == 1
                bApplyBayerFilter_ = false;
                bIsImageRGB_       = false;
            else
                bApplyBayerFilter_ = true;
                bIsImageRGB_       = true;
            end

            % Call renderImageFromPQ_ implementation
            [dImg, self] = self.renderImageFromPQ_(dSceneDataVector, "bApplyBayerFilter", bApplyBayerFilter_, "bIsImageRGB", bIsImageRGB_);

            % Reset target port to previous state
            if kwargs.ui32TargetPort > 0
                self.ui32TargetPort = ui32PrevPort;
            end

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % SINGLE IMAGE RENDERING from PQ scene data (intended as internal implementation, but exposed)
        function [dImg, self] = renderImageFromPQ_(self, dSceneDataVector, options)
            arguments
                self       (1,1)
                dSceneDataVector (1,:) double {isvector, isnumeric}
            end
            arguments % TODO: remove these options and replace with camera object from self
                options.bApplyBayerFilter (1,1) logical {islogical, isscalar} = false; 
                options.bIsImageRGB       (1,1) logical {islogical, isscalar} = false;
            end
            % NOTE: this class is intended as internal method, but left exposed for advanced users
            % and improved flexibility of the class implementation.
            
            if nargin > 1
                bApplyBayerFilter_   = options.bApplyBayerFilter; 
                bIsImageRGB_         = options.bIsImageRGB      ;
            else
                % LOAD FROM SELF
                if self.objCameraIntrinsics.ui32NumOfChannels == 1
                    bApplyBayerFilter_ = false;
                    bIsImageRGB_       = false;
                else
                    bApplyBayerFilter_ = true;
                    bIsImageRGB_       = true;
                end
            end

            % Input check
            assert( mod(length(dSceneDataVector), 7) == 0, ['Number of doubles to send to BlenderPy must be a multiple of 7 (PQ message). \n' ...
                'Required format: [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat, ... dBodyNPos, dBodyNQuat]']);
            assert( size(dSceneDataVector, 2) - 14 > 0, 'Only Sun and Camera PQ specified in dSceneData message. You should specify at least 1 body.');

            % Cast to bytes
            ui8SceneDataBuffer = typecast(dSceneDataVector, 'uint8');
            
            % Send to BlenderPy server
            pause(0.1);
            writtenBytes = self.WriteBuffer(ui8SceneDataBuffer, false);
            fprintf('\n\tSent %d bytes. Image requested. Waiting for data...\n', writtenBytes)

            % Wait for data reception from BlenderPy
            [~, recvDataBuffer, self] = self.ReadBuffer(); 
            pause(0.1);

            % Cast data to selected datatype
            if self.enumCommDataType == EnumCommDataType.UNSET
                warning('Data type in instance attribute is UNSET at buffer conversion! This should not have occurred. Default to double to prevent error: result may be incorrect.')
                self.enumCommDataType = EnumCommDataType.DOUBLE;
            end

            recvDataVector = typecast(recvDataBuffer, lower(string(self.enumCommDataType)));

            % Cast buffer to double and display image % TODO (PC): TBC if to keep here. May be moved to
            % acquireFrame of frontend algorithm branch?
            dImg = self.unpackImageFromCORTO(recvDataVector, bApplyBayerFilter_, bIsImageRGB_);

        end

    end

    % Blender server automanagement methods
    methods (Access = public)
        % TODO this must be printed only if truly enabled. These methods can also be called manually

        function [bIsServerRunning] = startBlenderServer(self)
            % Call static method to start server
            [bIsServerRunning] = BlenderPyCommManager.startBlenderServerStatic(self.charBlenderModelPath, ...
                                                                             self.charBlenderPyInterfacePath, ...
                                                                             self.charStartBlenderServerCallerPath, ...
                                                                             self.bSendLogToShellPipe, ...
                                                                             self.ui32ServerPort(1), ...
                                                                             self.bIsValidServerAutoManegementConfig);

            self.bIsServerRunning = bIsServerRunning;
        end

        function [bIsServerRunning] = checkRunningBlenderServer(self)
            [bIsServerRunning] = BlenderPyCommManager.checkRunningBlenderServerStatic(self.ui32ServerPort(1));
            self.bIsServerRunning = bIsServerRunning;
        end


        function [] = terminateBlenderProcesses(self)
            if self.bIsValidServerAutoManegementConfig
                fprintf("\nAuto managed mode is enabled. Attempting to terminate Blender processes automatically... \n")
            end
            % Call static termination method
            BlenderPyCommManager.terminateBlenderProcessesStatic()
        end


        % TODO (PC) make this function generic. Currently only for Milani NavCam!
        function dImg = unpackImageFromCORTO(self, dImgBuffer, bApplyBayerFilter, bIsImageRGB)
            arguments
                self 
                dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
                bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
                bIsImageRGB         (1,1) logical {islogical, isscalar} = false;
            end

            if bIsImageRGB
                % Call external function
                dImg = self.unpackImageFromCORTO_impl(dImgBuffer, bApplyBayerFilter);
            else
                error('Current version of the BlenderPy server api only ships RGB data. Remove this error once updated.')
                % TODO (PC) You will need to modify the input to the class/function
                % Implement and verify

                dImg = zeros(self.objCameraIntrinsics.ImageSize(1), self.objCameraIntrinsics.ImageSize(2), 'double');
                dImg(:, :) = reshape(transpose(dImgBuffer), self.objCameraIntrinsics.ImageSize(1), self.objCameraIntrinsics.ImageSize(2));
            end
        end

    end
    
    %% PROTECTED
    methods (Access = protected)
        % Internal implementations
        function dImgRGB = unpackImageFromCORTO_impl(self, dImgBuffer, bApplyBayerFilter)
            arguments
                self                (1,1)
                dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
                bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
            end
            %% SIGNATURE
            % dImgRGB = unpackImageFromCORTO(dImgBuffer, bApplyBayerFilter)%#codegen
            % -------------------------------------------------------------------------------------------------------------
            %% DESCRIPTION
            % What the function does
            % -------------------------------------------------------------------------------------------------------------
            %% INPUT
            % dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
            % bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
            % -------------------------------------------------------------------------------------------------------------
            %% OUTPUT
            % dImg
            % -------------------------------------------------------------------------------------------------------------
            %% CHANGELOG
            % First author: Milani GNC Team (M. Pugliatti, A. Rizza, F. Piccolo) for milani-gnc prototype
            % 13-01-2025    Pietro Califano     Adapted from legacy code of milani-gnc
            % -------------------------------------------------------------------------------------------------------------

            ui32ImgHeight   = self.objCameraIntrinsics.ImageSize(2);
            ui32ImgWidth    = self.objCameraIntrinsics.ImageSize(1);

            dImgRGB = zeros(ui32ImgHeight, ui32ImgWidth, 3, 'double');

            % Decompose the ImgPackage in the 4 RGBA channels
            dR = dImgBuffer(1:4:end);
            dG = dImgBuffer(2:4:end);
            dB = dImgBuffer(3:4:end);

            assert(length(dR) == ui32ImgWidth * ui32ImgHeight, 'Incorrect size of image buffer, not matching specified resolution. Something may have gone wrong in the configuration.')
            assert(length(dG) == ui32ImgWidth * ui32ImgHeight, 'Incorrect size of image buffer, not matching specified resolution. Something may have gone wrong in the configuration.')
            assert(length(dB) == ui32ImgWidth * ui32ImgHeight, 'Incorrect size of image buffer, not matching specified resolution. Something may have gone wrong in the configuration.')

            % Reshape the RGB channels as matrix
            dR = ( flip( reshape( dR', ui32ImgWidth, ui32ImgHeight), 2) )';
            dG = ( flip( reshape( dG', ui32ImgWidth, ui32ImgHeight), 2) )';
            dB = ( flip( reshape( dB', ui32ImgWidth, ui32ImgHeight), 2) )';

            % Compose the RGB tensor
            dImgRGB(:,:,1) = dR;
            dImgRGB(:,:,2) = dG;
            dImgRGB(:,:,3) = dB;

            if bApplyBayerFilter
                dImgRGB = self.applyBayerFilter_(dImgRGB);
            end

        end

        % TODO (PC): rework these functions!
        function dImgBayer = applyBayerFilter_(self, ImgRGB)
            % This function convert the RGB image of the environment into one generted
            % by the Milani NavCam with a 'bgrr' pattern

            dImgBayer = zeros(self.objCameraIntrinsics.ImageSize(2), self.objCameraIntrinsics.ImageSize(1));

            % Generate the pattern of the bayer filter
            dBayerFilter = BlenderPyCommManager.createBayerFilter_(dImgBayer, 'bggr'); % NOTE (PC) remove this coding horror...

            % Sample the environment RGB image with a bayer filter
            dImgBayer = BlenderPyCommManager.applyBayer_to_RGB_(ImgRGB,dBayerFilter);

        end

    end % End of methods section

    
    %% STATIC PUBLIC
    methods (Static, Access = public)

        % Method to start blender server
        function [bIsServerRunning] = startBlenderServerStatic(charBlenderModelPath, ...
                                                               charBlenderPyInterfacePath, ...
                                                               charStartBlenderServerCallerPath, ...
                                                               bSendLogToShellPipe, ...
                                                               ui32NetworkPortToCheck, ...
                                                               bIsValidServerAutoManegementConfig)
            arguments
                charBlenderModelPath                    
                charBlenderPyInterfacePath            
                charStartBlenderServerCallerPath
                bSendLogToShellPipe                     
                ui32NetworkPortToCheck                  (1,1) uint32 {isnumeric, isscalar} = 51001        
                bIsValidServerAutoManegementConfig      (1,1) logical {islogical, isscalar} = false
            end

            bIsServerRunning = false;

            if BlenderPyCommManager.checkUnix_()
                % charBlenderModelPath             % Path of .blend file to load
                % charBlenderPyInterfacePath         % Path to python Blender interface script
                % charStartBlenderServerCallerPath % Path to caller bash script

                % DEVNOTE method works using the same assumption of RCS-1 code. The script is called by
                % blender instead of as standalone. Next iterations will work by opening the server and
                % setup everything calling Blender when needed for rendering
                assert(isfile(charBlenderModelPath), sprintf('Blender model file %s not found.', charBlenderModelPath))
                assert(isfile(charBlenderPyInterfacePath), sprintf('CORTO interface pyscript not found at %s.', charBlenderPyInterfacePath))
                assert(isfile(charStartBlenderServerCallerPath), sprintf('Bash script to start CORTO interface pyscript not found at %s.', charStartBlenderServerCallerPath))

                % Check if path has extesion
                [charFileRoot, charFileName, charFileExt] = fileparts(charStartBlenderServerCallerPath);

                if isempty(charFileExt) == true
                    charStartBlenderServerCallerPath = fullfile(charFileRoot, charFileName, charFileExt);
                end


                try
                    if bIsValidServerAutoManegementConfig
                        fprintf("\nAuto managed mode is enabled. Attempting to start Blender server automatically... ")
                    end

                    % Construct command to run
                    charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
                        charStartBlenderServerCallerPath, charBlenderModelPath, charBlenderPyInterfacePath);

                    % Logging options
                    if bSendLogToShellPipe == true
                        system('mkfifo /tmp/blender_pipe'); % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
                        charStartBlenderCommand = char(strcat(charStartBlenderCommand, " > /tmp/blender_pipe &"));
                        charLogPipePath = "Logging to pipe: /tmp/blender_pipe";
                    else
                        charStartBlenderCommand = char(strcat(charStartBlenderCommand, " &"));
                        charLogPipePath = "Log disabled.";
                    end

                    % Execute the command
                    system(charStartBlenderCommand);
                    pause(1.5); % Wait sockets instantiation

                    % Check server is running
                    [bIsServerRunning] = BlenderPyCommManager.checkRunningBlenderServerStatic(ui32NetworkPortToCheck);

                    if not(bIsServerRunning)
                        error("\nAttempt to start server using command: \t\n%s.\nHowever, the server did not started correctly. Check log if available.", charStartBlenderCommand)
                    end

                    fprintf(sprintf("DONE. %s \n", charLogPipePath));

                catch ME
                    if bIsValidServerAutoManegementConfig
                        disp('')
                        warning("Auto managed Blender server startup failed due to the error below.")
                        fprintf("\nError message: %s", string(ME.message));
                        fprintf("\nExecution PAUSED. Please start server manually before continuing.\n"); 
                        pause();
                    else
                        error("\nStartup of Blender server failed in manual mode due to: %s", string(ME.message) );
                    end
                end

            end
        end
        
        % Method to check server status
        function [bIsServerRunning] = checkRunningBlenderServerStatic(ui32NetworkPort)
            arguments
                ui32NetworkPort (1,1) uint32 {isnumeric, isscalar}
            end

            if BlenderPyCommManager.checkUnix_()
                % TODO
                % ui32BlenderRecvPort % Required in self

                [~, netstat_out] = system(sprintf('netstat -tulpnv | grep %d', ui32NetworkPort)); % Get the process ID(s) of blender
                % Check if port in output message
                if contains(netstat_out, sprintf("%d", ui32NetworkPort))
                    bIsServerRunning = true;
                else
                    bIsServerRunning = false;
                end

            end

        end
        
        % Method to terminate server if running
        function [] = terminateBlenderProcessesStatic()

            if BlenderPyCommManager.checkUnix_()

                % Find the process
                [~, charResult] = system('pgrep -f blender'); % Get the process ID(s) of blender

                % Trim whitespace
                charResult = strtrim(charResult);

                % Split the PIDs into a cell array of strings
                pids = strsplit(charResult);

                if not(isempty(charResult))
                    % Kill the process
                    for pid = pids
                        fprintf('Killing process %s...\n', pid{:})
                        system(sprintf('kill -9 %s', pid{:}));
                    end
                end

            end

        end
        
        % Compose scene data vector PQ 
        function [dSceneDataVector] = composeSceneDataVector( dSunVector_NavFrame, ...
                                                              dCameraOrigin_NavFrame, ...
                                                              dCameraAttDCM_NavframeFromOF, ...
                                                              dBodiesOrigin_NavFrame, ...
                                                              dBodiesAttDCM_NavFrameFromOF, ...
                                                              kwargs)
            arguments
                dSunVector_NavFrame             (3,1)   double {isvector, isnumeric}
                dCameraOrigin_NavFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_NavframeFromOF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_NavFrame          (3,:)   double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_NavFrameFromOF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame              (1,1)    EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin              (3,1)    double {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_NavFrameFromRenderFrame    (3,3)    double {ismatrix, isnumeric} = eye(3)
                kwargs.bConvertCamQuatToBlenderQuat    (1,1)    logical {islogical, isscalar} = false;
            end
            % Method to compose scene data vector (PQ data). Input attitude matrices are the matrices that
            % project a vector A_OF in OF frame onto the basis composing NavFrame reference frame.

            % Get number of bodies
            ui32NumOfBodies = size(dBodiesOrigin_NavFrame, 2);
            assert(size(dBodiesAttDCM_NavFrameFromOF, 3) == ui32NumOfBodies, 'Unmatched number of bodies in Position and Attitude DCM arrays. Please check input data.');
            
            % TODO: based on selected rendering frame, assert identity and origin
            if kwargs.enumRenderingFrame == EnumRenderingFrame.CAMERA
                fprintf('\n\tUsing CAMERA frame as Rendering frame...\n')
                assert( all(dCameraOrigin_NavFrame == 0, 'all') );
                assert( all(dCameraAttDCM_NavframeFromOF == eye(3), 'all') )
    
            elseif kwargs.enumRenderingFrame == EnumRenderingFrame.TARGET_BODY
                fprintf('\n\tUsing TARGET_BODY frame as Rendering frame...')
                assert( all(dBodiesOrigin_NavFrame(:, 1) == 0, 'all') );
                assert( all(dBodiesAttDCM_NavFrameFromOF(:,:,1) == eye(3), 'all') )
    
            elseif kwargs.enumRenderingFrame == EnumRenderingFrame.CUSTOM_FRAME
                % No check, assume inputs are already in place
                fprintf('\n\tUsing CUSTOM_FRAME frame as Rendering frame...')
            else
                error('Invalid or unsupported type of rendering frame')
            end

            % Convert all attitude matrices to quaternions used by Blender
            dSunQuaternion_OFfromNavFrame    = BlenderPyCommManager.computeSunBlenderQuatFromPosition(dSunVector_NavFrame);
                
            if kwargs.bConvertCamQuatToBlenderQuat

                % Transpose DCM to adjust to Blender rotation definition of DCM (TBC) and transform to Quat
                dCameraBlendQuaternion_OFfromNavFrame = BlenderPyCommManager.convertCamQuatToBlenderQuatStatic(...
                    DCM2quat( transpose( dCameraAttDCM_NavframeFromOF ) , false) );
            
            else
                % DEVNOTE: ACHTUNG: Blender require attitude matrix to be defined from NavFrame TO OF!
                dCameraBlendQuaternion_OFfromNavFrame = DCM2quat(transpose(dCameraAttDCM_NavframeFromOF), false);
            end
            
            dBodiesQuaternion_OFfromNavFrame = zeros(4, ui32NumOfBodies);

            for idB = 1:ui32NumOfBodies
                % DEVNOTE: the quaternion corresponding to the matrix NavFrameFromTF must be first
                % transposed to be the one required by Blender due to the convention for its/my definition
                % of rotation matrices.
                dBodiesQuaternion_OFfromNavFrame(:, idB) = transpose( DCM2quat(transpose( dBodiesAttDCM_NavFrameFromOF ) , false) ) ;

            end

            % Compose output vector
            dSceneDataVector = zeros(1, 14 + ui32NumOfBodies * 7);
            
            % Allocate Sun PQ
            dSceneDataVector(1:7) = [dSunVector_NavFrame; dSunQuaternion_OFfromNavFrame];
            % Allocate Camera PQ
            dSceneDataVector(8:14) = [dCameraOrigin_NavFrame; dCameraBlendQuaternion_OFfromNavFrame];

            % Allocate bodies PQ
            ui32bodiesAllocPtr = uint32(15);
            ui32DeltaPQ = uint32(7);

            for idB = 1:ui32NumOfBodies
                dSceneDataVector(ui32bodiesAllocPtr : ui32bodiesAllocPtr + 6) = [dBodiesOrigin_NavFrame(1:3, idB); dBodiesQuaternion_OFfromNavFrame(1:4, idB)];
                ui32bodiesAllocPtr = ui32bodiesAllocPtr + ui32DeltaPQ;
            end

        end

        % TODO (PC) complete methods for conversions
        function [dBlenderQuat_AfromB, dBlenderDCM_AfromB] = convertNonBlenderDCMtoBlenderQuat(dNonBlenderDCM_AfromB)
            arguments (Input)
                dNonBlenderDCM_AfromB (3,3,:) double {ismatrix, isnumeric}
            end
            arguments (Output)
                dBlenderQuat_AfromB (3,:) double {ismatrix,isnumeric} % TODO (PC) specify convertion in the documentation
                dBlenderDCM_AfromB (3,3,:) double {ismatrix,isnumeric}
            end

            % Get number of matrices to convert
            ui32NumOfDCM = uint32(size(dBlenderDCM_AfromB, 3));

            % Conversion loop (TOOD)
            for idM = 1:ui32NumOfDCM
                % Convert matrices to Blender DCMs

                % Convert DCM TO Blender quaternions

            end
        end

        function [dBlenderQuat_AfromB] = convertDCM2BlenderQuat(dDCM_AfromB)
            arguments
                dDCM_AfromB (3,3,:) double {ismatrix,isnumeric}
            end

            % Get number of conversion to be done
            ui32NumOfDCM = uint32(size(dDCM_AfromB, 3));

            if ui32NumOfDCM == 1
                dBlenderQuat_AfromB = [0; 0; 0; 0];
                dBlenderQuat_AfromB(:) = DCM2BlenderQuat_(dDCM_AfromB);
            else
                dBlenderQuat_AfromB = zeros(4, ui32NumOfDCM);
                for idM = 1:ui32NumOfDCM
                    dBlenderQuat_AfromB(1:4, idM) = DCM2BlenderQuat_(dDCM_AfromB(1:3, 1:3, idM));
                end
            end
            % LOCAL FUNCTION impl
            function [dBlenderQuat_AfromB] = DCM2BlenderQuat_(dDCM_AfromB)
                % TODO conversion
                
            end
        end

        function [dBlenderCamDCM_AfromB] = convertNonBlenderCamDCMtoBlenderCamDCM(dNonBlenderCamDCM_AfromB)
            arguments
                dNonBlenderCamDCM_AfromB (3,3,:) double {ismatrix,isnumeric}
            end

            % Allocate output
            dBlenderCamDCM_AfromB = zeros(size(dNonBlenderCamDCM_AfromB));

            for idM = 1:size(dNonBlenderCamDCM_AfromB, 3)

                % Get DCM matrix
                dTmpCamDCM = dNonBlenderCamDCM_AfromB(:,:, idM);

                % Modify Camera DCM by rotating around X axis of pi radians
    
                dAxisZ_Bl = -dTmpCamDCM(3, :);
                dAxisX_Bl =  dTmpCamDCM(1, :);
                dAxisY_Bl = -dTmpCamDCM(2, :);
                
                % Recompose DCM
                dBlenderCamDCM_AfromB(:,:,idM) = [dAxisX_Bl; dAxisY_Bl; dAxisZ_Bl];
                
            end

        end

        function [dNonBlenderDCM_AfromB] = convertBlenderDCMtoNonBlenderDCM(dBlenderDCM_AfromB)
            arguments
                dBlenderDCM_AfromB (3,3,:) double {ismatrix,isnumeric}
            end

            % Allocate output
            dNonBlenderDCM_AfromB = zeros(size(dBlenderDCM_AfromB));

            for idM = 1:size(dBlenderDCM_AfromB, 3)
                % Rotate NonBlenderDCM to Blender DCM

            end

        end


        % Static method to convert camera quaternion to blender camera quaternion (inverse Z axis)
        function [dCameraBlendQuatArray] = convertCamQuatToBlenderQuatStatic(dCameraQuaternionArray)
            arguments
                dCameraQuaternionArray (4,:) double {ismatrix, isnumeric}
            end

            dCameraBlendQuatArray = zeros(size(dCameraQuaternionArray));

            for idQ = 1:size(dCameraQuaternionArray, 2)
                % DEVNOTE: the quaternion corresponding to the matrix NavFrameFromTF must be first
                % transposed to be the one required by Blender due to the convention for its definition.
                % In fact, Blender requires the quaternion from World frame to Object frame!
                dCameraBlendQuatArray(1:4, idQ) = quatmultiply( dCameraQuaternionArray(1:4,idQ)' , [0,1,0,0]);
            end
        end

        % Static method to convert blender camera quaternion to camera quaternion (normal Z axis)
        function [dCameraQuaternionArray] = convertBlenderQuatToCamQuatStatic(dCameraBlendQuatArray)
            arguments
                dCameraBlendQuatArray (4,:) double {ismatrix, isnumeric}
            end

            dCameraQuaternionArray = zeros(size(dCameraBlendQuatArray));

            for idQ = 1:size(dCameraBlendQuatArray, 2)
                dCameraQuaternionArray(1:4, idQ) = quatmultiply([0,1,0,0], quatinv(dCameraBlendQuatArray(1:4,idQ)') );
            end
        end

        % TODO (PC) make this function generic. Currently only for Milani NavCam!
        function dImg = unpackImageFromCORTO_Static(dImgBuffer, bApplyBayerFilter, bIsImageRGB)
            arguments
                dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
                bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
                bIsImageRGB         (1,1) logical {islogical, isscalar} = false;
            end

            if bIsImageRGB
                % Call external function
                dImg = unpackImageFromCORTO_(dImgBuffer, bApplyBayerFilter);
            else
                % TODO (PC) You will need to modiy the input to the class/function
                error('Not implemented yet. Requires size of camera to be known!')
                % dImg = zeros(1536, 2048, 3, 'uint8');

            end
        end
    
        
        % Function to check if system is Unix
        function [bIsUnixFlag] = checkUnix_()
            bIsUnixFlag = isunix();
            if not(bIsUnixFlag)
                warning('Called a Linux only method. Auto management of Blender Server is not available on other systems.')
            end
        end
    end
    

    methods (Static, Access = public)

        function [dSunBlenderQuat_OFfromNavFrame, dSunDCM_OFfromNavFrame] = computeSunBlenderQuatFromPosition(dSunPositionArray_NavFrame)
            arguments
                dSunPositionArray_NavFrame (3,:) double {isvector, isnumeric}
            end
            % Function to construct quaternion determining Sun direction as required by Blender, from position
            % NOTE: quaternion must be the one corresponding to the DCM from NavFrame (World) to "Sun frame"

            ui32NumOfQuats = size(dSunPositionArray_NavFrame, 2);
            dSunBlenderQuat_OFfromNavFrame = zeros(4, ui32NumOfQuats);
            dSunDCM_OFfromNavFrame = zeros(3, 3, ui32NumOfQuats);

            % Compute unit direction
            dUnitVectorToSunArray = dSunPositionArray_NavFrame./vecnorm(dSunPositionArray_NavFrame, 2, 1);
        
            % Compute Z axis in NavFrame
            dZaxisArray_NavFrame = dUnitVectorToSunArray;
            dAuxVectorArray_NavFrame =  repmat([1; 0; 0], 1, ui32NumOfQuats); % Auxiliary vector, can be arbitrary not aligned
            
            % Compute X axis in NavFrame
            dXaxisArray_NavFrame = cross(dAuxVectorArray_NavFrame, dZaxisArray_NavFrame);
            dXaxisArray_NavFrame = dXaxisArray_NavFrame ./ vecnorm(dXaxisArray_NavFrame, 2, 1);

            % Compute Y axis in NavFrame
            dYaxisArray_NavFrame = cross(dZaxisArray_NavFrame, dXaxisArray_NavFrame);

            for idR = 1:ui32NumOfQuats

                % Construct DCM ( TODO: validate matrix)
                % NOTE: matrix has axes of OF frame expressed in NavFrame as rows, such that dot product
                % on each project a vector from NavFrame basis to OF basis.
                dSunDCM_OFfromNavFrame(:,:, idR) = [dXaxisArray_NavFrame(:,idR)'; dYaxisArray_NavFrame(:,idR)'; dZaxisArray_NavFrame(:,idR)']; 

                % Convert to quaternion
                dSunBlenderQuat_OFfromNavFrame(1:4, idR) = DCM2quat( dSunDCM_OFfromNavFrame(:,:, idR), false); 

            end


        end



        function [img_bayer] = applyBayer_to_RGB_(RGB, BayerFilter)
            % TODO (PC): rework legacy function
            %This function is used to apply a Bayer filter to an RGB otuput image from
            %Blender. The output image is the equivalent of an output that would have
            %been obtained from an RGB sensor before interpolation.
            %
            %   INPUT:
            %           RGB: RGB tensor output from Blender [n x m x 3]
            %           BayerFilter: BayerFilter tensor [n x m x 3]
            %
            %   OUTPUT:
            %           img_bayer: RGB intensity matrix sampled with the BayerFilter[n x m](-)
            %
            % I/O handling
            img_bayer = double(zeros(size(RGB,1),size(RGB,2)));

            % Generate the img_bayer matrix
            img_bayer(:, :) = double(sum(double(RGB).*double(BayerFilter),3));
        end

        function [BayerFilter] = createBayerFilter_(img_size, pattern)
            % TODO (PC): rework legacy function
            %This function is used to create a BayerFilter logic array that mimic the
            %pattern of a bayer filter
            %
            %   INPUT:
            %           img_size: an empty matrix with the size of the desired
            %           pattern [n x m](-)
            %           pattern: pattern of the bayer filter listed as [1,2;3,4]
            %
            %   OUTPUT:
            %           BayerFilter: a logic tensor which identify the R,G,B pixels [n x m x 3](-)
            %
            % I/O handling

            res_x = size(img_size,2);
            res_y = size(img_size,1);
            BayerFilter = zeros(res_y,res_x,3);

            % Generate the BayerFilter tensor

            if strcmp(pattern,'bggr')
                for ii = 1:1:res_y
                    if mod(ii,2) == 0
                        j0 = 1;
                    else
                        j0 = 2;
                    end
                    for jj = j0:2:res_x
                        BayerFilter(ii,jj,2) = 1;
                    end
                end

                for ii = 1:2:res_y
                    for jj = 1:2:res_x
                        BayerFilter(ii,jj,3) = 1;
                    end
                end

                for ii = 2:2:res_y
                    for jj = 2:2:res_x
                        BayerFilter(ii,jj,1) = 1;
                    end
                end
            else
                error('\n Not implemented yet \n')
            end
        end

    end
end
