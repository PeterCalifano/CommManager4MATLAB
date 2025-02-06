classdef CORTOpyCommManager < CommManager
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
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % 1) Move yaml configuration parser in parent classes instead of this specific TBD
    % -------------------------------------------------------------------------------------------------------------
    %% Function code


    properties (SetAccess = protected, GetAccess = public)
        
        % ui32BlenderRecvPort % Get from yaml file else from input
        % ui32ServerPort % Get from yaml if specified else from input % Defined in superclass
        
        % Configuration
        bSendLogToShellPipe                     (1,1) logical {islogical, isscalar} = false % FIXME, not working is true due to system call failure

        charBlenderModelPath                (1,1) string {mustBeA(charBlenderModelPath, ["string", "char"])}
        charCORTOpyInterfacePath            (1,1) string {mustBeA(charCORTOpyInterfacePath, ["string", "char"])}  
        charStartBlenderServerCallerPath    (1,1) string {mustBeA(charStartBlenderServerCallerPath, ["string", "char"])}
        
        % Bytes to image conversion params
        objCameraIntrinsics 
        bApplyBayerFilter (1,1) logical {islogical, isscalar} = false;
        bIsImageRGB       (1,1) logical {islogical, isscalar} = false;

        enumCommDataType (1,1) {mustBeA(enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.DOUBLE

        % Runtime flags
        bIsValidServerAutoManegementConfig      (1,1) logical {islogical, isscalar} = false
        bIsServerRunning                        (1,1) logical {islogical, isscalar} = false
    end


    %% PUBLIC methods
    methods (Access = public)
        % CONSTRUCTOR
        function self = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
            arguments
                charServerAddress (1,:) {ischar, isstring}              = "127.0.0.1" % Assumes localhost
                ui32ServerPort    (1,2) uint32  {isvector, isnumeric}   = [30001, 51000]; % [TCP, UDP] Assumes ports used by CORTOpy interface
                dCommTimeout      (1,1) double  {isscalar, isnumeric}   = 45
            end
            % TODO: adjust kwargs required for CORTOpy
            arguments
                kwargs.bInitInPlace                     (1,1) logical       {islogical, isscalar} = false
                kwargs.enumCommMode                     (1,1) EnumCommMode  {isa(kwargs.enumCommMode, 'EnumCommMode')} = EnumCommMode.UDP_TCP
                kwargs.bLittleEndianOrdering            (1,1) logical       {islogical, isscalar} = true;
                kwargs.dOutputDatagramSize              (1,1) double        {isscalar, isnumeric} = 512
                kwargs.ui32TargetPort                   (1,1) uint32        {isscalar, isnumeric} = 0
                kwargs.charTargetAddress                (1,:) string        {mustBeA(kwargs.charTargetAddress , ["string", "char"])} = "127.0.0.1"
                kwargs.i64RecvTCPsize                   (1,1) int64         {isscalar, isnumeric} = -1; % SPECIAL MODE: -5
                kwargs.charConfigYamlFilename           (1,:) string        {mustBeA(kwargs.charConfigYamlFilename , ["string", "char"])}  = ""
                kwargs.bAutoManageBlenderServer         (1,1) logical       {isscalar, islogical} = false
                kwargs.charStartBlenderServerCallerPath (1,:) string        {mustBeA(kwargs.charStartBlenderServerCallerPath , ["string", "char"])} = ""
                kwargs.charBlenderModelPath             (1,:) string        {mustBeA(kwargs.charBlenderModelPath , ["string", "char"])} = ""
                kwargs.charCORTOpyInterfacePath         (1,:) string        {mustBeA(kwargs.charCORTOpyInterfacePath , ["string", "char"])} = ""
                kwargs.objCameraIntrisincs              (1,1)               {mustBeA(kwargs.objCameraIntrisincs, "CCameraIntrinstics")} = CCameraIntrinsics()
                kwargs.enumCommDataType                 (1,1)               {mustBeA(kwargs.enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.UNSET
            end

            bIsValidServerAutoManegementConfig = false;
            
            % Check if auto management can be used
            if isunix()

                if kwargs.bAutoManageBlenderServer && strcmpi(kwargs.charStartBlenderServerCallerPath, "")
                    % If requested but not configured correctly
                    warning(['Auto management requested, but charStartBlenderServerCallerPath not set. ' ...
                        'Mode cannot be enabled: please manage server manually.'])
                    bIsValidServerAutoManegementConfig = false;

                    if any([strcmpi(kwargs.charBlenderModelPath , ""), strcmpi(kwargs.charCORTOpyInterfacePath, "")])
                        error("Auto management requested, but either charCORTOpyInterfacePath or charBlenderModelPath paths are undefined.")
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

            % Store paths
            self.charStartBlenderServerCallerPath = kwargs.charStartBlenderServerCallerPath;
            self.charBlenderModelPath = kwargs.charBlenderModelPath;
            self.charCORTOpyInterfacePath = kwargs.charCORTOpyInterfacePath;
            self.bIsValidServerAutoManegementConfig = bIsValidServerAutoManegementConfig;
            self.ui32ServerPort = ui32ServerPort;
            
            % Start server if in auto management mode
            if bIsValidServerAutoManegementConfig
                [self.bIsServerRunning] = self.startBlenderServer();
            end

            % Parse yaml configuration file if provided
            if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                self.parseYamlConfig_(kwargs.charConfigYamlFilename);
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
                % TODO --> need to add constructor from fov TBD

                % self.strConfigFromYaml.Camera_Params.FOV_x;
                % self.strConfigFromYaml.Camera_Params.FOV_Y;
                % self.strConfigFromYaml.Camera_Params.sensor_size_x
                % self.strConfigFromYaml.Camera_Params.sensor_size_y

                % self.ui32NumOfChannels = self.strConfigFromYaml.Camera_Params.n_channels;

                % self.objCameraIntrinsics = CCameraIntrinsics();
                error('Not yet implemented >.<')

            else
                % Assume Milani NavCam parameters
                warning('No camera object nor yaml configuration file specified. Assuming Milani NavCam parameters.')
                error('Not yet implemented >.<')

                dFocalLength
                ui32ImageSize = [2048, 1536];
                dPrincipalPoint = double(ui32ImageSize)/2;

                self.objCameraIntrinsics = CCameraIntrinsics(dFocalLength, dPrincipalPoint, ui32ImageSize);
            end

            % Determine transmission dtype
            % Input kwargs overrides all
            if not(kwargs.enumCommDataType == EnumCommDataType.UNSET)
                self.enumCommDataType  = kwargs.enumCommDataType;

                if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                    warning('Both datatype option and yaml configuration file specified. Input datatype overrides specification. Please remove it if this is unintended.')
                end

            elseif not(strcmpi(kwargs.charConfigYamlFilename, ""))
            

            end

            % If not specified, determine recv size of image
            if not(kwargs.i64RecvTCPsize ~= -1) 
                % TODO: how to distinguish case actual -1 case from "autocompute" case?

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
        function printCameraParams(self)
            fprintf("\nCORTOpyCommManager will use the following camera parameters:\n");

            % Focal Length
            fprintf(" - Focal length: [%.2f, %.2f] [mm or px] (X, Y)\n", self.objCameraIntrinsics.FocalLength(1), self.objCameraIntrinsics.FocalLength(2));

            % Field of View (FoV)
            fprintf(" - Field of View (FoV): [%.2f, %.2f] degrees (X, Y)\n", rad2deg(self.objCameraIntrinsics.dFovHW(1)), rad2deg(self.objCameraIntrinsics.dFovHW(2)));

            % Image Size
            fprintf(" - Image size: [%d, %d] pixels (Width X, Height Y)\n", self.objCameraIntrinsics.ImageSize(1), self.objCameraIntrinsics.ImageSize(2));

            % Image Type
            if self.bIsImageRGB
                fprintf(" - Image type: RGB (3-4 channels). Blender will send 4 channels (with Alpha)\n");
            else
                fprintf(" - Image type: Grayscale (1 channel)\n");
            end

            % Image Data Type
            fprintf(" - Image data type for transmission: %s\n", self.enumCommDataType);

            % Assumed Buffer Size for TCP Transmission
            fprintf(" - Assumed buffer size for TCP transmission: %d bytes\n", self.i64RecvTCPsize);
        end

        % METHODS

        function [outImgArrays, self] = renderImageSequence(self, dSunVector_Buffer_NavFrame , ...
                                                         dSunAttDCM_Buffer_NavframeFromTF, ...
                                                         dCameraOrigin_Buffer_NavFrame, ...
                                                         dCameraAttDCM_Buffer_NavframeFromTF, ...
                                                         dBodiesOrigin_Buffer_NavFrame, ...
                                                         dBodiesAttDCM_Buffer_NavFrameFromTF, ...
                                                         kwargs)
            arguments (Input)
                self
                dSunVector_Buffer_NavFrame              (3,:)   double {isvector, isnumeric}
                dSunAttDCM_Buffer_NavframeFromTF        (3,3,:) double {ismatrix, isnumeric}
                dCameraOrigin_Buffer_NavFrame           (3,:)   double {isvector, isnumeric}
                dCameraAttDCM_Buffer_NavframeFromTF     (3,3,:)   double {ismatrix, isnumeric}
                dBodiesOrigin_Buffer_NavFrame           (3,:,:)   double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_Buffer_NavFrameFromTF     (3,3,:,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments (Input)
                kwargs.charConfigYamlFilename           (1,:)   string = ""
                kwargs.ui32TargetPort                   (1,1) uint32 {isscalar, isnumeric} = 0
                kwargs.charOutputDatatype               (1,:) string {isa(kwargs.charOutputDatatype, 'string')} = "double"
                kwargs.ui32HorizontalSize               (1,1) uint32 {isnumeric, isscalar} = -1
                kwargs.ui32VerticalSize                 (1,1) uint32 {isnumeric, isscalar} = -1
                kwargs.ui32NumOfBodies                  (1,1) uint32 {isnumeric, isscalar} = -1
                kwargs.ui32NumOfImgChannels             (1,1) uint32 {isnumeric, isscalar} = -1
            end

            % Parse configuration file if not already initialized or override
            if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                self.parseYamlConfig_(kwargs.charConfigYamlFilename);
            end
                
            % Optionally the user may instantiate the class or set the data for rendering sequence before calling this method. Default args uses class attributes.
            % TODO (PC) complete configuration setup for method. Need to add indexing of input yaml config
            if any([kwargs.ui32HorizontalSize, ...
                    kwargs.ui32VerticalSize, ...
                    kwargs.ui32NumOfBodies, ...
                    kwargs.ui32NumOfImgChannels] == -1)

                % Load configuration parameters from strConfigFromYaml
                assert(not(strcmpi(self.strConfigFromYaml, "")), "Class instance configuration not loaded from Yaml. " + ...
                    "Please provide configuration yaml as used by CORTO_interface UDP-TCP script at instantiation or as input to this method." + ...
                    "Alternatively, provide all data as input kwargs parameters.")

                ui32HorizontalSize      = self.strConfigFromYaml;
                ui32VerticalSize        = self.strConfigFromYaml;
                ui32NumOfBodies         = self.strConfigFromYaml;
                ui32NumOfImgChannels    = self.strConfigFromYaml;

            else

                % Use input parameters (must all be specified)
                ui32HorizontalSize      = kwargs.ui32HorizontalSize  ;
                ui32VerticalSize        = kwargs.ui32VerticalSize    ;
                ui32NumOfBodies         = kwargs.ui32NumOfBodies     ;
                ui32NumOfImgChannels    = kwargs.ui32NumOfImgChannels;

            end

            if kwargs.ui32TargetPort > 0
                % Temporarily override set target port
                ui32PrevPort = self.ui32TargetPort;
                self.ui32TargetPort = kwargs.ui32TargetPort;
            end

            % Input and validation checks 
            ui32NumOfImages = uint32();
        
            if ui32NumOfBodies == 1
                assert( ndims(dBodiesAttDCM_Buffer_NavFrameFromTF) == 3);
                % TODO: complete
            else
                assert( ndims(dBodiesAttDCM_Buffer_NavFrameFromTF) == 4);
                % TODO: complete
            end
                        
            % Rendering loop
            outImgArrays = zeros(ui32HorizontalSize, ui32VerticalSize, ui32NumOfImgChannels, ui32NumOfImages, char(charOutputDatatype) );

            for idImg = 1:ui32NumOfImages
                
                % Get data from buffers
                dSunVector_NavFrame             = dSunVector_Buffer_NavFrame         (:, idImg);
                dSunAttDCM_NavframeFromTF       = dSunAttDCM_Buffer_NavframeFromTF   (:,:, idImg);
                dCameraOrigin_NavFrame          = dCameraOrigin_Buffer_NavFrame      (:, idImg);
                dCameraAttDCM_NavframeFromTF    = dCameraAttDCM_Buffer_NavframeFromTF(:,:, idImg);

                if ui32NumOfBodies == 1
                    % Handle single body assuming 2D and 3D arrays as inputs
                    dBodiesOrigin_NavFrame          = dBodiesOrigin_Buffer_NavFrame      (:, idImg);
                    dBodiesAttDCM_NavFrameFromTF    = dBodiesAttDCM_Buffer_NavFrameFromTF(:,:, idImg);

                else
                    % Handle multiple bodies as 3D and 4D matrices for positions and DCMs
                    dBodiesOrigin_NavFrame          = dBodiesOrigin_Buffer_NavFrame      (:,:, idImg);
                    dBodiesAttDCM_NavFrameFromTF    = dBodiesAttDCM_Buffer_NavFrameFromTF(:,:,:, idImg);
                end

                % Call renderImage implementation ( TODO (PC) complete implementation ) 
                dImg = self.renderImage(dSunVector_NavFrame, ...
                                        dSunAttDCM_NavframeFromTF, ...
                                        dCameraOrigin_NavFrame, ...
                                        dCameraAttDCM_NavframeFromTF, ...
                                        dBodiesOrigin_NavFrame, ...
                                        dBodiesAttDCM_NavFrameFromTF, ...
                                        kwargs); % TODO: specify kwargs and how to treat image

                % Store image into output array
                outImgArrays(1:ui32HorizontalSize, 1:ui32VerticalSize, idImg) = cast(dImg, kwargs.charOutputDatatype);
                
                % Get labels data
                % TODO (PC) next upgrade, transmit through TCP? TBD
            end
        
            % Squeeze array if number of channels is equal to 1
            if ui32NumOfImgChannels == 1
                outImgArrays = squeeze(outImgArrays);
            end

            if kwargs.ui32TargetPort > 0
                % Reset target port to previous value
                self.ui32TargetPort = ui32PrevPort;
            end

        end

        % Single image rendering from disaggregated scene data
        function [dImg, self] = renderImage(self, dSunVector_NavFrame, ...
                                            dSunAttDCM_NavframeFromTF, ...
                                            dCameraOrigin_NavFrame, ...
                                            dCameraAttDCM_NavframeFromTF, ...
                                            dBodiesOrigin_NavFrame, ...
                                            dBodiesAttDCM_NavFrameFromTF, ...
                                            kwargs)
            arguments
                self
                dSunVector_NavFrame             (3,1)   double {isvector, isnumeric}
                dSunAttDCM_NavframeFromTF       (3,3)   double {ismatrix, isnumeric}
                dCameraOrigin_NavFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_NavframeFromTF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_NavFrame          (3,:)   double {ismatrix, isnumeric} = zeros(3,1)
                dBodiesAttDCM_NavFrameFromTF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame              (1,1) EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin              (3,1) double {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_NavFrameFromRenderFrame    (3,3) double {ismatrix, isnumeric} = eye(3)
                kwargs.ui32TargetPort                  (1,1) uint32 {isscalar, isnumeric} = 0
                kwargs.bApplyBayerFilter               (1,1) logical {islogical, isscalar} = false;
                kwargs.bIsImageRGB                     (1,1) logical {islogical, isscalar} = false;
            end
            
            % Input size and validation checks
            assert( size(dBodiesOrigin_NavFrame, 2) == size(dBodiesAttDCM_NavFrameFromTF, 3), 'Number of bodies position does not match number of attitude matrices')

            if kwargs.ui32TargetPort > 0
                % Temporarily override set target port
                ui32PrevPort = self.ui32TargetPort;
                self.ui32TargetPort = kwargs.ui32TargetPort;
            end

            % Determine size of vector
            dSceneDataVector = zeros(1, 7 * (2 + size(dBodiesOrigin_NavFrame, 2))); % [PQ_i] representation [SunPQ, CameraPQ, Body1PQ, ... BodyNPQ]

            % Convert disaggregated scene data to dSceneData vector representation
            dSceneDataVector(:) = self.composeSceneDataVector(dSunVector_NavFrame, dSunAttDCM_NavframeFromTF, ...
                dCameraOrigin_NavFrame, dCameraAttDCM_NavframeFromTF, dBodiesOrigin_NavFrame, dBodiesAttDCM_NavFrameFromTF, ...
                'enumRenderingFrame', kwargs.enumRenderingFrame, 'dRenderFrameOrigin', kwargs.dRenderFrameOrigin, 'dDCM_NavFrameFromRenderFrame', kwargs.dDCM_NavFrameFromRenderFrame);

            % Call renderImageFromPQ_ implementation
            [dImg, self] = self.renderImageFromPQ_(dSceneDataVector, ...
                "bApplyBayerFilter", kwargs.bApplyBayerFilter, "bIsImageRGB", kwargs.bIsImageRGB);

            % Reset target port to previous state
            if kwargs.ui32TargetPort > 0
                self.ui32TargetPort = ui32PrevPort;
            end

        end


        function [dImg, self] = renderImageFromPQ_(self, dSceneDataVector, options)
            arguments
                self       (1,1)
                dSceneDataVector (1,:) double {isvector, isnumeric}
            end
            arguments
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
                bApplyBayerFilter_   = self.bApplyBayerFilter;
                bIsImageRGB_         = self.bIsImageRGB;
            end

            % Input check
            assert( mod(length(dSceneDataVector), 7) == 0, ['Number of doubles to send to CORTOpy must be a multiple of 7 (PQ message). \n' ...
                'Required format: [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat, ... dBodyNPos, dBodyNQuat]']);
            assert( size(dSceneDataVector, 2) - 14 > 0, 'Only Sun and Camera PQ specified in dSceneData message. You should specify at least 1 body.');

            % Cast to bytes
            ui8SceneDataBuffer = typecast(dSceneDataVector, 'uint8');
            % Send to CORTOpy server
            writtenBytes = self.WriteBuffer(ui8SceneDataBuffer, false);
            fprintf('\n\tSent %d bytes. Image requested. Waiting for data...\n', writtenBytes)

            % Wait for data reception from CORTOpy
            [~, recvDataBuffer, self] = self.ReadBuffer(); 
            % Cast data to double
            recvDataVector = typecast(recvDataBuffer, 'double');

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
            [bIsServerRunning] = CORTOpyCommManager.startBlenderServerStatic(self.charBlenderModelPath, ...
                                                                             self.charCORTOpyInterfacePath, ...
                                                                             self.charStartBlenderServerCallerPath, ...
                                                                             self.bSendLogToShellPipe, ...
                                                                             self.ui32ServerPort(1), ...
                                                                             self.bIsValidServerAutoManegementConfig);

            self.bIsServerRunning = bIsServerRunning;
        end

        function [bIsServerRunning] = checkRunningBlenderServer(self)
            [bIsServerRunning] = CORTOpyCommManager.checkRunningBlenderServerStatic(self.ui32ServerPort(1));
            self.bIsServerRunning = bIsServerRunning;
        end


        function [] = terminateBlenderProcesses(self)
            if self.bIsValidServerAutoManegementConfig
                fprintf("\nAuto managed mode is enabled. Attempting to terminate Blender processes automatically... \n")
            end
            % Call static termination method
            CORTOpyCommManager.terminateBlenderProcessesStatic()
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
                
                % TODO (PC) You will need to modify the input to the class/function
                % Implement and verify
                ui32ImgHeight   = 2048;
                ui32ImgWidth    = 1536;

                dImg = zeros(ui32ImgHeight, ui32ImgWidth, 'double');
                dImg(:, :) = reshape(transpose(dImgBuffer), ui32ImgHeight, ui32ImgWidth);

                % error('Not implemented yet. Requires size of camera to be known!')
                % dImg = zeros(1536, 2048, 3, 'uint8');

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

            dImgRGB = zeros(1536, 2048, 3, 'double');

            % Decompose the ImgPackage in the 4 RGBA channels
            dR = dImgBuffer(1:4:end);
            dG = dImgBuffer(2:4:end);
            dB = dImgBuffer(3:4:end);

            % Reshape the RGB channels as matrix
            dR = (flip(reshape(dR',2048,1536),2))';
            dG = (flip(reshape(dG',2048,1536),2))';
            dB = (flip(reshape(dB',2048,1536),2))';

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

            dImgBayer = zeros(1536, 2048);

            % Generate the pattern of the bayer filter
            dBayerFilter = CORTOpyCommManager.createBayerFilter_(dImgBayer, 'bggr'); % NOTE (PC) remove this coding horror...

            % Sample the environment RGB image with a bayer filter
            dImgBayer = CORTOpyCommManager.applyBayer_to_RGB_(ImgRGB,dBayerFilter);

        end

    end % End of methods section

    
    %% STATIC PUBLIC
    methods (Static, Access = public)

        % Method to start blender server
        function [bIsServerRunning] = startBlenderServerStatic(charBlenderModelPath, ...
                                                               charCORTOpyInterfacePath, ...
                                                               charStartBlenderServerCallerPath, ...
                                                               bSendLogToShellPipe, ...
                                                               ui32NetworkPortToCheck, ...
                                                               bIsValidServerAutoManegementConfig)
            arguments
                charBlenderModelPath                    
                charCORTOpyInterfacePath            
                charStartBlenderServerCallerPath
                bSendLogToShellPipe                     
                ui32NetworkPortToCheck                  (1,1) uint32 {isnumeric, isscalar} = 51001        
                bIsValidServerAutoManegementConfig      (1,1) logical {islogical, isscalar} = false
            end

            bIsServerRunning = false;

            if CORTOpyCommManager.checkUnix_()
                % charBlenderModelPath             % Path of .blend file to load
                % charCORTOpyInterfacePath         % Path to python Blender interface script
                % charStartBlenderServerCallerPath % Path to caller bash script

                % DEVNOTE method works using the same assumption of RCS-1 code. The script is called by
                % blender instead of as standalone. Next iterations will work by opening the server and
                % setup everything calling Blender when needed for rendering
                assert(isfile(charBlenderModelPath), sprintf('Blender model file %s not found.', charBlenderModelPath))
                assert(isfile(charCORTOpyInterfacePath), sprintf('CORTO interface pyscript not found at %s.', charCORTOpyInterfacePath))
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
                        charStartBlenderServerCallerPath, charBlenderModelPath, charCORTOpyInterfacePath);

                    % Logging options
                    if bSendLogToShellPipe == true
                        system('mkfifo /tmp/blender_pipe') % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
                        charStartBlenderCommand = strcat(charStartBlenderCommand, " > /tmp/blender_pipe &");
                        charLogPipePath = "Logging to pipe: /tmp/blender_pipe";
                    else
                        charStartBlenderCommand = strcat(charStartBlenderCommand, " &");
                        charLogPipePath = "Log disabled.";
                    end

                    % Execute the command
                    system(charStartBlenderCommand);
                    pause(0.75); % Wait sockets instantiation

                    % Check server is running
                    [bIsServerRunning] = CORTOpyCommManager.checkRunningBlenderServerStatic(ui32NetworkPortToCheck);

                    if not(bIsServerRunning)
                        error("Command executed: %s.\nHowever, the server did not started correctly. Check log if available.", charStartBlenderCommand)
                    end

                    fprintf(sprintf("DONE. %s \n", charLogPipePath));

                catch ME
                    if bIsValidServerAutoManegementConfig
                        fprintf("\nAuto managed Blender server startup failed due to error: %s. \nExecution paused. Please start server manually before continuing.\n", ME.message)
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

            if CORTOpyCommManager.checkUnix_()
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

            if CORTOpyCommManager.checkUnix_()

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

        % Method to compose scene data vector (PQ data)
        function [dSceneDataVector] = composeSceneDataVector(dSunVector_NavFrame, ...
                dSunAttDCM_NavframeFromTF, ...
                dCameraOrigin_NavFrame, ...
                dCameraAttDCM_NavframeFromTF, ...
                dBodiesOrigin_NavFrame, ...
                dBodiesAttDCM_NavFrameFromTF, ...
                kwargs)
            arguments
                dSunVector_NavFrame             (3,1)   double {isvector, isnumeric}
                dSunAttDCM_NavframeFromTF       (3,3)   double {ismatrix, isnumeric}
                dCameraOrigin_NavFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_NavframeFromTF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_NavFrame          (3,:)   double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_NavFrameFromTF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame              (1,1)    EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin              (3,1)   double {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_NavFrameFromRenderFrame    (3,3)   double {ismatrix, isnumeric} = eye(3)
            end

            % Get number of bodies
            ui32NumOfBodies = size(dBodiesOrigin_NavFrame, 2);
            assert(size(dBodiesAttDCM_NavFrameFromTF, 3) == ui32NumOfBodies, 'Unmatched number of bodies in Position and Attitude DCM arrays. Please check input data.');
            
            % TODO: based on selected rendering frame, assert identity and origin
            if kwargs.enumRenderingFrame == EnumRenderingFrame.CAMERA

                assert( all(dCameraOrigin_NavFrame == 0, 'all') );
                assert( all(dCameraAttDCM_NavframeFromTF == eye(3), 'all') )
    
            elseif kwargs.enumRenderingFrame == EnumRenderingFrame.TARGET_BODY

                assert( all(dBodiesOrigin_NavFrame(:, 1) == 0, 'all') );
                assert( all(dBodiesAttDCM_NavFrameFromTF(:,:,1) == eye(3), 'all') )
    
            else
                error('Invalid or unsupported type of rendering frame')
            end

            % Convert all attitude matrices to quaternions used by Blender
            dSunQuaternion_ToNavFrame    = DCM2quat(dSunAttDCM_NavframeFromTF, false);
            dCameraQuaternion_ToNavFrame = DCM2quat(dCameraAttDCM_NavframeFromTF, false);
                
            dBodiesQuaternion_ToNavFrame = zeros(4, ui32NumOfBodies);

            for idB = 1:ui32NumOfBodies
                dBodiesQuaternion_ToNavFrame(:, idB) = DCM2quat(dBodiesAttDCM_NavFrameFromTF, false);
            end

            % Compose output vector
            dSceneDataVector = zeros(1, 14 + ui32NumOfBodies * 7);
            
            % Allocate Sun PQ
            dSceneDataVector(1:7) = [dSunVector_NavFrame; dSunQuaternion_ToNavFrame];
            % Allocate Camera PQ
            dSceneDataVector(8:14) = [dCameraOrigin_NavFrame; dCameraQuaternion_ToNavFrame];

            % Allocate bodies PQ
            ui32bodiesAllocPtr = uint32(15);
            ui32DeltaPQ = uint32(7);

            for idB = 1:ui32NumOfBodies
                dSceneDataVector(ui32bodiesAllocPtr : ui32bodiesAllocPtr + 6) = [dBodiesOrigin_NavFrame(1:3, idB); dBodiesQuaternion_ToNavFrame(1:4, idB)];
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
