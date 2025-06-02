classdef BlenderPyCommManager < CommManager
    %% CONSTRUCTOR
    % TODO
    % -------------------------------------------------------------------------------------------------------------
    %% DESCRIPTION
    % TODO
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
    % 11-02-2025    Pietro Califano     Minor bug fixes, implementation of methods to compute attitude as
    %                                   required by Blender, extensive testing for release version.
    % 10-05-2025    Pietro Califano     Review of major upgrades (validation of output using internal 
    %                                   shape model and frontend emulator, yaml configuration update)
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % Functions and classes in SimulationGears_for_SpaceNav repository. Specifically, CCameraIntrinsics.
    % See public repo: git@github.com:PeterCalifano/SimulationGears_for_SpaceNav.git
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Function code

    properties (SetAccess = protected, GetAccess = public)
        
        % ui32BlenderRecvPort % Get from yaml file else from input
        % ui32ServerPort % Get from yaml if specified else from input % Defined in superclass
        
        % Configuration
        bUseTmuxShell                       (1,1) logical {islogical, isscalar} = true 

        charBlenderModelPath                (1,1) string {mustBeA(charBlenderModelPath, ["string", "char"])}
        charBlenderPyInterfacePath          (1,1) string {mustBeA(charBlenderPyInterfacePath, ["string", "char"])}  
        charStartBlenderServerCallerPath    (1,1) string {mustBeA(charStartBlenderServerCallerPath, ["string", "char"])}
        
        charOutputDatatype              {mustBeMember(charOutputDatatype, ["double", "single", "uint8", "uint32", "uint16", "source"])} = "source";
        charOutputPath; % Currently read only, this cannot be set from MATLAB
        bAutomaticConvertToTargetFixed  (1,1) logical {islogical, isscalar} = false;

        % Bytes to image conversion params
        objCameraIntrinsics = CCameraIntrinsics();
        enumCommDataType (1,1) {mustBeA(enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.DOUBLE

        % Runtime flags
        bIsValidServerAutoManegementConfig      (1,1) logical {islogical, isscalar} = false
        bIsServerRunning                        (1,1) logical {islogical, isscalar} = false
        ui32ServerPID                           uint32 {mustBeScalarOrEmpty} = []


        % Shape model objects for debug and labels generator in sequences
        objShapeModel               {mustBeA(objShapeModel, ["CShapeModel", "double"])} = [];
        objLabelsGeneratorModule    {mustBeA(objLabelsGeneratorModule, ["CLabelsGenerator", "double"])} = [];
    end


    %% PUBLIC methods
    methods (Access = public)
        % CONSTRUCTOR
        function self = BlenderPyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs, settings)
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
                kwargs.charOutputDatatype               (1,:) string {mustBeA(kwargs.charOutputDatatype, ["string", "char"]), ...
                                                                  mustBeMember(kwargs.charOutputDatatype, ["double", "single", "uint8", "uint32", "uint16", "source"])} = "source";
                kwargs.i64RecvTCPsize                   (1,1) int64         {isscalar, isnumeric} = -1; % SPECIAL MODE: -5, -10 (auto compute)
                kwargs.charConfigYamlFilename           (1,:) string        {mustBeA(kwargs.charConfigYamlFilename , ["string", "char"])}  = ""
                kwargs.bAutoManageBlenderServer         (1,1) logical       {isscalar, islogical} = false
                kwargs.charStartBlenderServerCallerPath (1,:) string        {mustBeA(kwargs.charStartBlenderServerCallerPath , ["string", "char"])} = ""
                kwargs.charBlenderModelPath             (1,:) string        {mustBeA(kwargs.charBlenderModelPath , ["string", "char"])} = ""
                kwargs.charBlenderPyInterfacePath       (1,:) string        {mustBeA(kwargs.charBlenderPyInterfacePath , ["string", "char"])} = ""
                kwargs.objCameraIntrisincs              (1,1)               {mustBeA(kwargs.objCameraIntrisincs, "CCameraIntrinsics")} = CCameraIntrinsics()
                kwargs.enumCommDataType                 (1,1)               {mustBeA(kwargs.enumCommDataType, 'EnumCommDataType')} = EnumCommDataType.UNSET
                kwargs.bUseTmuxShell                    (1,1) logical       {islogical, isscalar} = false;
                kwargs.bAutomaticConvertToTargetFixed   (1,1) logical       {islogical, isscalar} = false;
                kwargs.bDEBUG_MODE                      (1,1) logical       {islogical, isscalar} = false;
                kwargs.objShapeModel                     = []
                kwargs.charDatasetSaveFolder            (1,:) string {mustBeA(kwargs.charDatasetSaveFolder, ["string", "char"])} = ""
            end
            arguments
                settings.enumImgBitDepth                (1,1) string {mustBeMember(settings.enumImgBitDepth, ["8", "16", "32"]), ...
                                                                        mustBeA(settings.enumImgBitDepth, ["string", "char"])} = "8"
                settings.enumOutputImgFormat            (1,1) string {mustBeMember(settings.enumOutputImgFormat, ["PNG", "OPEN_EXR"]), ...
                                                                mustBeA(settings.enumOutputImgFormat, ["string", "char"])} = "PNG"
                settings.bSaveGeomVisibilityBoolMask    (1,1) logical {islogical} = false
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
            self.bDEBUG_MODE    = kwargs.bDEBUG_MODE;
            self.objShapeModel  = kwargs.objShapeModel;

            % Store paths
            self.charStartBlenderServerCallerPath = kwargs.charStartBlenderServerCallerPath;
            self.charBlenderModelPath = kwargs.charBlenderModelPath;
            self.charBlenderPyInterfacePath = kwargs.charBlenderPyInterfacePath;
            self.bIsValidServerAutoManegementConfig = bIsValidServerAutoManegementConfig;
            self.ui32ServerPort = ui32ServerPort;
            self.bUseTmuxShell = kwargs.bUseTmuxShell;
            self.charOutputDatatype = kwargs.charOutputDatatype;

            self.bAutomaticConvertToTargetFixed = kwargs.bAutomaticConvertToTargetFixed;

            % Parse yaml configuration file if provided
            if not(strcmpi(kwargs.charConfigYamlFilename, ""))

                % Read data from yaml file used server side
                self.parseYamlConfig_(kwargs.charConfigYamlFilename);
                self.charOutputPath = self.strConfigFromYaml.Server_params.output_path;
                
                if not(strcmpi(kwargs.charDatasetSaveFolder, ""))

                    % Check if last folder is "images", modify path if not
                    [charRoot, charDirName] = fileparts(kwargs.charDatasetSaveFolder);
            
                    if not(strcmpi(charDirName, "images"))
                        % No "images" folder: append to path
                        kwargs.charDatasetSaveFolder = fullfile(kwargs.charDatasetSaveFolder, "images");

                    elseif strcmpi(charDirName, "images") && not(strcmp(charDirName, "images"))
                        % "images" is present, but wrong case, overwrite
                        kwargs.charDatasetSaveFolder = fullfile(charRoot, "images");
                    end

                    % Set output path if user provided it 
                    self.charOutputPath = kwargs.charDatasetSaveFolder;

                    % Update output path if server is not running yet
                    if bIsValidServerAutoManegementConfig || not(self.checkRunningBlenderServer())
                    
                        % Write output path and server ports configuration
                        self.strConfigFromYaml.Server_params.output_path = self.charOutputPath;
                        self.strConfigFromYaml.Server_params.port_B2M = int32(ui32ServerPort(1));

                        if not(strcmpi(self.objShapeModel.charModelName, ""))

                            try
                                % Try to convert to enumTargetName as constraint
                                enumTargetName = EnumScenarioName.(self.objShapeModel.charModelName);
                                self.strConfigFromYaml.BlenderModel_params.bodies_names{1} = char(enumTargetName);

                            catch ME
                                fprintf(2, "Error occurred when assigning body name: %s. \nACHTUNG: model name in shape model object " + ...
                                    "likely did not match any scenario in EnumScenarioName and may be incorrect. " + ...
                                    "Make sure the blender model you're using contains that object!", ME.message);
                                pause(1);
                            end

                        end

                        if kwargs.ui32TargetPort > 0
                            self.strConfigFromYaml.Server_params.port_M2B = int32(kwargs.ui32TargetPort);
                        end

                        % Configure file overwriting from template
                        [charRootDir, charFilename, ~] = fileparts(kwargs.charConfigYamlFilename);
                        if contains(charFilename, ".templ")
                            charFilename = strrep(charFilename, ".templ", "");
                        end
                        
                        % Write bit encoding and output format to config
                        if strcmpi(settings.enumOutputImgFormat, "open_exr") && str2double(settings.enumImgBitDepth) < 16
                            warning('OPEN_EXR image output format supports either 16 or 32 bit FP output. Changed to FP16.')
                            settings.enumImgBitDepth = "16";
                        end

                        self.strConfigFromYaml.Camera_params.bit_encoding                          = int32(str2double(settings.enumImgBitDepth));
                        self.strConfigFromYaml.RenderingEngine_params.file_format                  = settings.enumOutputImgFormat;
                        self.strConfigFromYaml.RenderingEngine_params.bSaveGeomVisibilityBoolMask  = settings.bSaveGeomVisibilityBoolMask;
                        
                        % Complete configuration and serialize file
                        kwargs.charConfigYamlFilename = fullfile(charRootDir, strcat(charFilename, ".yml") );
                        self.serializeYamlConfig_(kwargs.charConfigYamlFilename, self.strConfigFromYaml);
                    
                    end

                    % TODO: in next version make the class able to rewrite yaml after loading such that
                    % parameters can be updated. In Linux, order of operations (first modify, then start server)
                    % with automatic management can be leveraged to make everything seamless.
                end

            end

            % Start server if in auto management mode
            if bIsValidServerAutoManegementConfig
                % TODO: add storage of PID to ensure only that process will be killed!
                [self.bIsServerRunning] = self.startBlenderServer();
            end

            % Determine transmission dtype
            % Input kwargs overrides all
            if not(kwargs.enumCommDataType == EnumCommDataType.UNSET)
                self.enumCommDataType  = kwargs.enumCommDataType;

                if not(strcmpi(kwargs.charConfigYamlFilename, ""))
                    warning('Both datatype option and yaml configuration file specified. Input datatype overrides specification. Please remove it if this is unintended.')
                end

            elseif not(strcmpi(kwargs.charConfigYamlFilename, ""))
                self.enumCommDataType = EnumCommDataType.(upper(self.strConfigFromYaml.Server_params.image_dtype));
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
                dFOV_x              = self.strConfigFromYaml.Camera_params.FOV_x; % [deg] Horizontal Field of View
                dFOV_y              = self.strConfigFromYaml.Camera_params.FOV_y; % [deg] Vertical Field of View
                dSensor_size_x      = self.strConfigFromYaml.Camera_params.sensor_size_x; % [px] Horizontal resolution
                dSensor_size_y      = self.strConfigFromYaml.Camera_params.sensor_size_y; % [px] Vertical resolution
                ui32NumOfChannels   = self.strConfigFromYaml.Camera_params.n_channels;

                dPrincipalPoint_uv = [dSensor_size_x, dSensor_size_y]./2;
            
                % TODO: add assert on rounding! Must be integer

                % self.ui32NumOfChannels = self.strConfigFromYaml.Camera_params.n_channels;
                dFocalLength_uv = [(dSensor_size_x / 2) / tand(dFOV_x / 2), (dSensor_size_y / 2) / tand(dFOV_y / 2)];

                if ui32NumOfChannels == 3
                    ui32NumOfChannels = ui32NumOfChannels + 1;
                end

                % Construct camera intrinsics object
                self.objCameraIntrinsics = CCameraIntrinsics( dFocalLength_uv, dPrincipalPoint_uv, [dSensor_size_x, dSensor_size_y], ui32NumOfChannels );

            else
                % Assume Milani/RCS-1 NavCam parameters
                warning('No camera object nor yaml configuration file specified. Assuming Milani NavCam parameters.')

                dFOV_x = 19.72; % [deg]
                dFOV_y = 14.86;
                dSensor_size_x = 2048; % [px]
                dSensor_size_y = 1536; 
                ui32NumOfChannels = uint32(4); % RGBA

                ui32ImageSize = [dSensor_size_x; dSensor_size_y];
                dFocalLength_uv = CCameraIntrinsics.computeFocalLenghInPix([dFOV_x; dFOV_y], ui32ImageSize, "deg");
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
            if bIsValidServerAutoManegementConfig && bInitInPlace == false && kwargs.bInitInPlace == true
                self.Initialize(); % TODO check this call is ok
            end

        end
        
        % DESTRUCTOR
        function delete(self)
            % If auto management of Blender server, call termination method
            % TODO modify to kill ONLY the process of the server that was opened!
            % How to do it is easy: modify the text grep uses to identify processes with the target port
            % used for UDP send or the TCP listen.
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
        function [outImgArrays, objSceneFigs, self] = renderImageSequence(self, dSunVector_Buffer_RenderFrame , ...
                                                         dCameraOrigin_Buffer_RenderFrame, ...
                                                         dCameraAttDCM_Buffer_RenderFrameFromOF, ...
                                                         dBodiesOrigin_Buffer_RenderFrame, ...
                                                         dBodiesAttDCM_Buffer_RenderFrameFromOF, ...
                                                         kwargs)
            arguments (Input)
                self
                dSunVector_Buffer_RenderFrame              (3,:)       double {isvector, isnumeric}
                dCameraOrigin_Buffer_RenderFrame           (3,:)       double {isvector, isnumeric}
                dCameraAttDCM_Buffer_RenderFrameFromOF     (3,3,:)     double {ismatrix, isnumeric}
                dBodiesOrigin_Buffer_RenderFrame           (3,:,:)     double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_Buffer_RenderFrameFromOF     (3,3,:,:)   double {ismatrix, isnumeric} = eye(3)
            end
            arguments (Input)
                kwargs.ui32TargetPort                   (1,1) uint32 {isscalar, isnumeric} = 0
                kwargs.charOutputDatatype               (1,:) string {mustBeA(kwargs.charOutputDatatype, ["string", "char"]), ...
                                                           mustBeMember(kwargs.charOutputDatatype, ["double", "single", "uint8", "uint32", "uint16", "source"])} = self.charOutputDatatype
                kwargs.ui32NumOfBodies                  (1,1) uint32 {isnumeric, isscalar} = 1
                kwargs.objCameraIntrinsics              (1,1) {mustBeA(kwargs.objCameraIntrinsics, "CCameraIntrinsics")} = CCameraIntrinsics()
                kwargs.enumRenderingFrame               (1,1) EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.CUSTOM_FRAME % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.bEnableFramesPlot                (1,1) logical {islogical} = false;
                kwargs.bConvertCamQuatToBlenderQuat     (1,1) logical {isscalar, islogical} = true;
                kwargs.bDisplayImage                    (1,1) logical {islogical} = false;
                kwargs.bAutomaticConvertToTargetFixed   (1,1) logical {islogical} = self.bAutomaticConvertToTargetFixed;
                kwargs.ui32FirstImgID                   (1,1) uint32 {isnumeric, isscalar} = 1
                kwargs.objDatasetForLabels              {mustBeA(kwargs.objDatasetForLabels, ["SReferenceImagesDataset", "SImagesDatasetFormatESA", ...
                    "SSequencesCloudImagesDataset", "SPoses3PointCloudImagesDataset", "double"])} = []
            end
                
            % Determine number of images from camera origin array
            ui32NumOfImages = uint32(size(dCameraOrigin_Buffer_RenderFrame, 2));

            % Determine number of bodies and check validity
            % Default number of body is 1. Overridden by yaml configuration if any.
            ui32NumOfBodies     = kwargs.ui32NumOfBodies;
            if not(strcmpi(self.charConfigYamlFilename, ""))
                ui32NumOfBodies = uint32(self.strConfigFromYaml.BlenderModel_params.num_bodies);
            end

            if (ui32NumOfBodies == 1 && ui32NumOfImages > 1) || (ui32NumOfImages == 1 && ui32NumOfBodies > 1)
                assert( ndims(dBodiesAttDCM_Buffer_RenderFrameFromOF) == 3);
            elseif ui32NumOfBodies == 1 && ui32NumOfImages == 1
                assert( ismatrix(dBodiesAttDCM_Buffer_RenderFrameFromOF));
            elseif ui32NumOfBodies > 1 && ui32NumOfImages > 1
                assert( ndims(dBodiesAttDCM_Buffer_RenderFrameFromOF) == 4);
            else
                error('Invalid size of dBodiesAttDCM_Buffer_RenderFrameFromOF')
            end

            % Assert validity of other buffers
            assert(size(dSunVector_Buffer_RenderFrame, 2) == ui32NumOfImages, ...
                'dSunVector_Buffer_RenderFrame must have the same number of columns as images.');

            assert(size(dCameraAttDCM_Buffer_RenderFrameFromOF, 3) == ui32NumOfImages, ...
                'dCameraAttDCM_Buffer_RenderFrameFromOF must have the same 3rd dimension as images.');

            assert(size(dBodiesOrigin_Buffer_RenderFrame, 3) == kwargs.ui32NumOfBodies, ...
                'dBodiesOrigin_Buffer_RenderFrame must have the same 3rd dimension as number of bodies.');

            assert(size(dBodiesAttDCM_Buffer_RenderFrameFromOF, 4) == kwargs.ui32NumOfBodies, ...
                'dBodiesAttDCM_Buffer_RenderFrameFromOF must have the same 4th dimension as number of bodies.');


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

            %outImgArrays = zeros(objCameraIntrinsics_.ImageSize(2), objCameraIntrinsics_.ImageSize(1), ...
            %    ui32NumOfImages, char( kwargs.charOutputDatatype) );
            
            % Placeholder for output images
            % outImgArrays = zeros(objCameraIntrinsics_.ImageSize(2), objCameraIntrinsics_.ImageSize(1), 1, kwargs.charOutputDatatype);

            % BlenderPyCommManager.computeSunBlenderQuatFromPosition(dSunVector_RenderFrame);

            if kwargs.enumRenderingFrame == "CUSTOM_FRAME"
                fprintf("\nScene data specified with respect to a custom frame. No check or transformation of the inputs is performed at rendering time.\n")
            end


            if self.bDEBUG_MODE && not(isempty(self.objShapeModel))
                try
                    % Define target and frontend emulator for DEBUG
                    objEmulatorSettings = SFrontEndTrackerEmulatorSettings("enumRandProcessType", "NONE", "enumTrackLossModel", ...
                        "NONE", "ui32MAX_NUM_FEATURES", 1e3, 'bUseMexMethods', true);

                    objTargetEmulator = CTargetEmulator(self.objShapeModel, 1e3, SPose3());
                    objFrontEndEmulator = CFrontEndTracker_Emulator(self.objCameraIntrinsics, ...
                                                                objTargetEmulator, ...
                                                                objEmulatorSettings);
                catch ME
                    warning('Debug mode failed to activate due to error: %s.', string(ME.message))
                end

            end

            objSceneFigs = gobjects(ui32NumOfImages, 1);

            for idImg = kwargs.ui32FirstImgID:ui32NumOfImages
                
                % Get data from buffers>
                dSunVector_RenderFrame             = dSunVector_Buffer_RenderFrame         (:, idImg);
                dCameraOrigin_RenderFrame          = dCameraOrigin_Buffer_RenderFrame      (:, idImg);
                dCameraAttDCM_RenderFrameFromOF    = dCameraAttDCM_Buffer_RenderFrameFromOF(:,:, idImg);

                if ui32NumOfBodies == 1
                    % Handle single body assuming 2D and 3D arrays as inputs
                    dBodiesOrigin_RenderFrame          = dBodiesOrigin_Buffer_RenderFrame      (:, idImg);
                    dBodiesAttDCM_RenderFrameFromOF    = dBodiesAttDCM_Buffer_RenderFrameFromOF(:,:, idImg);

                else
                    % Handle multiple bodies as 3D and 4D matrices for positions and DCMs
                    dBodiesOrigin_RenderFrame          = dBodiesOrigin_Buffer_RenderFrame      (:,:, idImg);
                    dBodiesAttDCM_RenderFrameFromOF    = dBodiesAttDCM_Buffer_RenderFrameFromOF(:,:,:, idImg);
                end

                % Update objects for debug mode
                if self.bDEBUG_MODE
                    objTargetEmulator   = objTargetEmulator.SetPose3(SPose3( dBodiesOrigin_RenderFrame(:,1), dBodiesAttDCM_RenderFrameFromOF(:,:,1) ));
                    objTargetEmulator   = objTargetEmulator.SampleMeshPoints();

                    objFrontEndEmulator = objFrontEndEmulator.updateTargetEmulator(objTargetEmulator);
                end


                try
                    if kwargs.bEnableFramesPlot
                        fprintf("\nProducing requested visualization of scene frames to render...\n")

                        % Convert DCMs to quaternion
                        dSceneEntityQuatArray_RenderFrameFromOF = transpose( dcm2quat(dBodiesAttDCM_RenderFrameFromOF) );
                        dCameraQuat_RenderFrameFromCam          = transpose( dcm2quat(dCameraAttDCM_RenderFrameFromOF) );

                        % if kwargs.bConvertCamQuatToBlenderQuat
                        % DEVNOTE: removed because plot function operates using the same convention as
                        % this function, contrarily to Blender. Assuming that the plot is correct, the
                        % downstream operations should be correct too.
                        %     dCameraQuat_RenderFrameFromCam = BlenderPyCommManager.convertCamQuatToBlenderQuatStatic(dCameraQuat_RenderFrameFromCam);
                        % end

                        % Construct figure with plot
                        [objSceneFigs(idImg)] = PlotSceneFrames_Quat(dBodiesOrigin_RenderFrame, ...
                                                                    dSceneEntityQuatArray_RenderFrameFromOF, ...
                                                                    dCameraOrigin_RenderFrame, ...
                                                                    dCameraQuat_RenderFrameFromCam, 'bUseBlackBackground', true, ...
                                                                    "charFigTitle", "Visualization with Blender camera quaternion");

                        % Add Light direction to plot
                        % If Sun specified, move light there
                        objLight = light("Style", "Infinite", "Position", dSunVector_RenderFrame);
                        camlight(objLight);

                        % Normalize position to avoid unreadable plots
                        dScaleDistanceSun = norm(dCameraOrigin_RenderFrame);
                        dSunPosition_RenderFrame = dScaleDistanceSun * dSunVector_RenderFrame./norm(dSunVector_RenderFrame);

                        hold on;
                        dLineScale = 1.2;
                        objSunDirPlot = plot3([0, dLineScale * dSunPosition_RenderFrame(1)], ...
                            [0, dLineScale * dSunPosition_RenderFrame(2)], ...
                            [0, dLineScale * dSunPosition_RenderFrame(3)], ...
                            '-', 'Color', '#f48037', 'LineWidth', 2, 'DisplayName', 'To Sun'); %#ok<NASGU>
                        axis equal
                    end

                catch ME
                    warning("Failed to reproduce visualization of scene frames due to error.")
                    fprintf("\n%s", string(ME.message))
                end

                fprintf("\nSending data to render image %d of %d...\n", idImg, ui32NumOfImages)
                % Call renderImage implementation 
                dImg = self.renderImage(dSunVector_RenderFrame, ...
                                    dCameraOrigin_RenderFrame, ...
                                    dCameraAttDCM_RenderFrameFromOF, ...
                                    dBodiesOrigin_RenderFrame, ...
                                    dBodiesAttDCM_RenderFrameFromOF, ...
                                    "enumRenderingFrame", kwargs.enumRenderingFrame, ...
                                    "ui32TargetPort", kwargs.ui32TargetPort, ...
                                    "bConvertCamQuatToBlenderQuat", kwargs.bConvertCamQuatToBlenderQuat, ...
                                    "bAutomaticConvertToTargetFixed", kwargs.bAutomaticConvertToTargetFixed); % TODO: specify kwargs and how to treat image

                % Store image into output array
                %outImgArrays(1:self.objCameraIntrinsics.ImageSize(2), 1:self.objCameraIntrinsics.ImageSize(1), %idImg) = cast(dImg, kwargs.charOutputDatatype);
                if strcmpi(kwargs.charOutputDatatype, "source")
                    kwargs.charOutputDatatype = class(dImg);
                end

                outImgArrays = cast(dImg, kwargs.charOutputDatatype);
                fprintf("Completed image %d of %d.\n", idImg, ui32NumOfImages)

                if kwargs.bDisplayImage
                    figure(95)
                    clf;
                    %imshow( outImgArrays(:,:,idImg) )
                    imshow( dImg )
                    axis image

                    % DEBUG MODE using tracing to cross-validate scene geometry and rendered image
                    % ACHTUNG: it slows down the process a lot!
                    if self.bDEBUG_MODE

                        try
                            % Get projected keypoints on image plane and plot
                            objKeypointsVisibilityPlot = figure(98);
                            set(objKeypointsVisibilityPlot, 'Position', [0, 480, 480, 480]);

                            objFrontEndEmulator = objFrontEndEmulator.acquireFrame(SPose3(dCameraOrigin_RenderFrame, dCameraAttDCM_RenderFrameFromOF), ...
                                                                                       dBodiesAttDCM_RenderFrameFromOF(:,:,1)' * dSunVector_RenderFrame, ...
                                                                                        idImg);

                            imshow(dImg)
                            hold on;

                            % TODO add implementation to retrieve legend objects to function and test here!
                            [objKeypointsVisibilityPlot] = CPointProjectionPlotter.PlotProjectedPoints({objFrontEndEmulator.dVisibleKeypointsGT_uv}, ...
                                                                                            self.objCameraIntrinsics, ...
                                                                                            "bUseBlackBackground", true, ...
                                                                                            "cellPlotNames", {'Visible GT ShadowRay'}, ...
                                                                                            "cellPlotColors", {'#FF5500'}, ...
                                                                                            "objSceneFig", objKeypointsVisibilityPlot, ...
                                                                                            "bEnableLegend", true, ...
                                                                                            "bEnforcePlotOpts", true); %#ok<NASGU>

                        catch ME
                            warning('Cross-validation using frontend emulator failed to run due to error: %s. Debug mode forcefully disabled.', string(ME.message))
                            self.bDEBUG_MODE = false;
                        end
                    end
                end


                % Get labels data
                if not(isempty(self.objLabelsGeneratorModule)) && not(isempty(self.objShapeModel)) && not(isempty(kwargs.objDatasetForLabels))

                    % Make binary mask using global Otsu thresholding
                    if ndims(outImgArrays) == 3
                        outImgArraysAsGrayscale = rgb2gray(outImgArrays);
                    else
                        outImgArraysAsGrayscale = outImgArrays;
                    end

                    bBinaryMask = imbinarize(outImgArraysAsGrayscale, "global");

                    % Generate labels
                    self.objLabelsGeneratorModule = self.objLabelsGeneratorModule.makeLabels(kwargs.objDatasetForLabels, ...
                                                                                        self.objShapeModel, ...
                                                                                        idImg, ...
                                                                                        "bBinaryImgArray", bBinaryMask, ...
                                                                                        "dImgArray", dImg, ...
                                                                                        "bMakeGeometricLabels", true, ...
                                                                                        "bMakeAuxiliaryLabels", true, ...
                                                                                        "bSaveInPlace", true);
                end

                pause(0.01)

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
        function [dImg, self] = renderImage(self, ...
                                            dSunVector_RenderFrame, ...
                                            dCameraOrigin_RenderFrame, ...
                                            dCameraAttDCM_RenderFrameFromOF, ...
                                            dBodiesOrigin_RenderFrame, ...
                                            dBodiesAttDCM_RenderFrameFromOF, ...
                                            kwargs)
            arguments
                self
                dSunVector_RenderFrame             (3,1)   double {isvector, isnumeric}
                dCameraOrigin_RenderFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_RenderFrameFromOF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_RenderFrame          (3,:)   double {ismatrix, isnumeric} = zeros(3,1)
                dBodiesAttDCM_RenderFrameFromOF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame               (1,1) EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin               (3,1) double  {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_RenderFrameFromRenderFrame     (3,3) double  {ismatrix, isnumeric} = eye(3)
                kwargs.ui32TargetPort                   (1,1) uint32  {isscalar, isnumeric} = 0
                kwargs.bConvertCamQuatToBlenderQuat     (1,1) logical {isscalar, islogical} = true;
                kwargs.bAutomaticConvertToTargetFixed   (1,1) logical {isscalar, islogical} = self.bAutomaticConvertToTargetFixed;  
            end
            
            % Input size and validation checks
            assert( size(dBodiesOrigin_RenderFrame, 2) == size(dBodiesAttDCM_RenderFrameFromOF, 3), 'Number of bodies position does not match number of attitude matrices')

            if kwargs.ui32TargetPort > 0
                % Temporarily override set target port
                ui32PrevPort = self.ui32TargetPort;
                self.ui32TargetPort = kwargs.ui32TargetPort;
            end

            % Determine size of vector
            dSceneDataVector = zeros(1, 7 * (2 + size(dBodiesOrigin_RenderFrame, 2))); % [PQ_i] representation [SunPQ, CameraPQ, Body1PQ, ... BodyNPQ]

            % Convert disaggregated scene data to dSceneData vector representation
            dSceneDataVector(:) = self.composeSceneDataVector(dSunVector_RenderFrame, dCameraOrigin_RenderFrame, ...
                dCameraAttDCM_RenderFrameFromOF, dBodiesOrigin_RenderFrame, dBodiesAttDCM_RenderFrameFromOF, ...
                'enumRenderingFrame', kwargs.enumRenderingFrame, ...
                'dRenderFrameOrigin', kwargs.dRenderFrameOrigin, ...
                'dDCM_RenderFrameFromRenderFrame', kwargs.dDCM_RenderFrameFromRenderFrame, ...
                'bConvertCamQuatToBlenderQuat', kwargs.bConvertCamQuatToBlenderQuat, ...
                'bAutomaticConvertToTargetFixed', kwargs.bAutomaticConvertToTargetFixed);

            
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


        % SETTERS
        function self = plugLabelsGenerator(self, objLabelsGeneratorModule)
            arguments
                self
                objLabelsGeneratorModule (1,1) CLabelsGenerator {mustBeA(objLabelsGeneratorModule, "CLabelsGenerator")}
            end

            self.objLabelsGeneratorModule = objLabelsGeneratorModule;

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
                                                                             self.bUseTmuxShell, ...
                                                                             self.ui32ServerPort(1), ...
                                                                             self.bIsValidServerAutoManegementConfig);

            self.bIsServerRunning = bIsServerRunning;
            pause(2);
        end

        function [charStartBlenderCommand] = getBlenderStartCommand_(self)
            % Method to compose command to manually start server with provided paths
                % setup everything calling Blender when needed for rendering
                assert(isfile(self.charBlenderModelPath), sprintf('Blender model file %s not found.', self.charBlenderModelPath))
                assert(isfile(self.charBlenderPyInterfacePath), sprintf('CORTO interface pyscript not found at %s.', self.charBlenderPyInterfacePath))
                assert(isfile(self.charStartBlenderServerCallerPath), sprintf('Bash script to start CORTO interface pyscript not found at %s.', self.charStartBlenderServerCallerPath))

                % Check if path has extesion
                [charFileRoot, charFileName, charFileExt] = fileparts(self.charStartBlenderServerCallerPath);

                if isempty(charFileExt) == true
                    self.charStartBlenderServerCallerPath = fullfile(charFileRoot, charFileName, charFileExt);
                end

                % Construct command to run
                charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
                    self.charStartBlenderServerCallerPath, self.charBlenderModelPath, self.charBlenderPyInterfacePath);

                if self.bUseTmuxShell
                    % Logging options
                    charStartBlenderCommand = char(sprintf("tmux new-session -d -s %s '%s; exec bash' & echo $!",...
                        strcat("bpy_", num2str(self.ui32ServerPort(1)), "_render"), charStartBlenderCommand)) ;
                end

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
            BlenderPyCommManager.terminateBlenderProcessesStatic({num2str(self.ui32ServerPID)})
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

            assert(length(dR) == ui32ImgWidth * ui32ImgHeight, sprintf(['Incorrect size of image buffer (R-channel). Actual %d. ' ...
                'Expected %d. Something may have gone wrong in the configuration.'], length(dR), ui32ImgWidth * ui32ImgHeight)) 
            assert(length(dG) == ui32ImgWidth * ui32ImgHeight, sprintf(['Incorrect size of image buffer (G-channel). Actual %d. ' ...
                'Expected %d. Something may have gone wrong in the configuration.'], length(dG), ui32ImgWidth * ui32ImgHeight))
            assert(length(dB) == ui32ImgWidth * ui32ImgHeight, sprintf(['Incorrect size of image buffer (B-channel). Actual %d. ' ...
                'Expected %d. Something may have gone wrong in the configuration.'], length(dB), ui32ImgWidth * ui32ImgHeight))

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
        function [bIsServerRunning, ui32ServerPID] = startBlenderServerStatic(charBlenderModelPath, ...
                                                               charBlenderPyInterfacePath, ...
                                                               charStartBlenderServerCallerPath, ...
                                                               bUseTmuxShell, ...
                                                               ui32NetworkPortToCheck, ...
                                                               bIsValidServerAutoManegementConfig)
            arguments
                charBlenderModelPath                            string {mustBeA(charBlenderModelPath             , ["string", "char"])}        
                charBlenderPyInterfacePath                      string {mustBeA(charBlenderPyInterfacePath       , ["string", "char"])}      
                charStartBlenderServerCallerPath                string {mustBeA(charStartBlenderServerCallerPath , ["string", "char"])}
                bUseTmuxShell                           (1,1)   logical {islogical, isscalar} = true
                ui32NetworkPortToCheck                  (1,1)   uint32 {isnumeric, isscalar} = 51001        
                bIsValidServerAutoManegementConfig      (1,1)   logical {islogical, isscalar} = false
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
                        fprintf("\nAuto managed mode is enabled. Attempting to start Blender server automagically... \n")
                    end

                    % Construct command to run
                    charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
                        charStartBlenderServerCallerPath, charBlenderModelPath, charBlenderPyInterfacePath);

                    % Logging options

                    if bUseTmuxShell == true
                                           
                        % system('mkfifo /tmp/blender_pipe'); % Open a shell and write cat /tmp/blender_pipe to display log being written by Blender
                        charTmuxSessionName = strcat("bpy", num2str(ui32NetworkPortToCheck), "_render");

                        charStartBlenderCommand = char(sprintf("tmux new-session -d -s %s '%s; exec bash' & echo $!",...
                                                charTmuxSessionName, charStartBlenderCommand)) ;

                        charLogPipePath = sprintf("Using new tmux session: %s", charTmuxSessionName);
                        
                    else
                        charStartBlenderCommand = char(strcat(charStartBlenderCommand, " & echo $!"));
                        charLogPipePath = "Log disabled.";
                    end

                    % Execute the command
                    [ui32Status, charStdout] = system(charStartBlenderCommand);
                    

                    % Check server is running
                    bIsServerRunning = false; 
                    ui32MaxWaitCounter = 0;
                    ui32ServerPID = [];

                    while not(bIsServerRunning) % Wait sockets instantiation
                        fprintf("\nChecking Blender server availability...")
                        [bIsServerRunning, ui32ServerPID] = BlenderPyCommManager.checkRunningBlenderServerStatic(ui32NetworkPortToCheck);
                        pause(1);
                        ui32MaxWaitCounter = ui32MaxWaitCounter + 1;

                        if ui32MaxWaitCounter == 10
                            error("\nMax wait time for server start reached. Command used: %s. Check log or tmux shell.", charStartBlenderCommand)
                        end
                    end

                    if not(bIsServerRunning)
                        error("\nAttempt to start server using command: \t\n%s.\nHowever, the server did not started correctly. Check log or tmux shell.", charStartBlenderCommand)
                    end

                    if ui32Status == 0
                        % Get PID of background process
                        ui32ServerPID = str2double(strtrim(charStdout));
                        fprintf('\nBlender server started, PID = %d\n', ui32ServerPID);
                    else
                        error('Something has gone wrong while starting server: system() return status mode %d.', ui32Status)
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
        function [bIsServerRunning, ui32ServerPID] = checkRunningBlenderServerStatic(ui32NetworkPort)
            arguments
                ui32NetworkPort (1,1) uint32 {isnumeric, isscalar}
            end

            if BlenderPyCommManager.checkUnix_()
                % ui32BlenderRecvPort % Required in self

                charCMD = sprintf( [ ...
                    'netstat -tulpnv ', ...
                    '| grep LISTEN ', ...
                    '| grep %d ', ...
                    '| awk ''{print $7}'' ', ...
                    '| grep /blender$ ', ...
                    '| cut -d/ -f1' ], ui32NetworkPort );

                [~, charNetstatOutMsg] = system(sprintf('netstat -tulpnv | grep LISTEN | grep %d', ui32NetworkPort)); % Get the process ID(s) of blender
                [~, charNetstatOutPIDs] = system(charCMD); % Get the process ID(s) of blender

                % Fetch process ID associated to the server

                % 2) Trim whitespace and keep only lines that are *all* digits
                charOutPIDlines = splitlines(charNetstatOutPIDs);
                ui32ServerPID = [];
                for id = 1:numel(charOutPIDlines)

                    charPID = strtrim(charOutPIDlines{id});

                    if ~isempty(charPID) && all(isstrprop(charPID, 'digit'))
                        ui32ServerPID(end+1) = str2double(charPID);  %#ok<AGROW>
                    end
                end

                % Check if port in output message
                if contains(charNetstatOutMsg, sprintf("%d", ui32NetworkPort)) && not(isempty(ui32ServerPID))
                    bIsServerRunning = true;
                    fprintf('Blender PID(s) on port %d: %s\n', ui32NetworkPort, mat2str(ui32ServerPID));
                else
                    bIsServerRunning = false;
                    warning('No Blender PID found on port %d.', ui32NetworkPort);
                end
            end

        end
        
        % Method to terminate server if running
        function [] = terminateBlenderProcessesStatic(cellPIDs)
            arguments
                cellPIDs {iscell} = {}
            end

            if BlenderPyCommManager.checkUnix_()

                % Split the PIDs into a cell array of strings
                if iscell(cellPIDs) && not(isempty(cellPIDs))
                    cellPIDs_ = cellPIDs;
                else
                    % Find all blender processes and kill all
                    [~, charResultingPIDs] = system('pgrep -f blender'); % Get the process ID(s) of blender

                    % Trim whitespaces
                    charResultingPIDs = strtrim(charResultingPIDs);
                    cellPIDs_ = strsplit(charResultingPIDs);
                end

                if not(isempty(cellPIDs_))
                    % Kill the process
                    for cellPID = cellPIDs_
                        fprintf('Killing process %s...', cellPID{:})
                        [bFlag] = system(sprintf('kill -9 %s', cellPID{:}));
                        fprintf(' status flag: %s\n', bFlag);
                    end
                end

            end

        end
        
        % Compose scene data vector PQ 
        function [dSceneDataVector] = composeSceneDataVector( dSunVector_RenderFrame, ...
                                                              dCameraOrigin_RenderFrame, ...
                                                              dCameraAttDCM_RenderFrameFromOF, ...
                                                              dBodiesOrigin_RenderFrame, ...
                                                              dBodiesAttDCM_RenderFrameFromOF, ...
                                                              kwargs)
            arguments
                dSunVector_RenderFrame             (3,1)   double {isvector, isnumeric}
                dCameraOrigin_RenderFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_RenderFrameFromOF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_RenderFrame          (3,:)   double {ismatrix, isnumeric} = zeroes(3,1)
                dBodiesAttDCM_RenderFrameFromOF    (3,3,:) double {ismatrix, isnumeric} = eye(3)
            end
            arguments % kwargs arguments
                kwargs.enumRenderingFrame               (1,1)    EnumRenderingFrame {isa(kwargs.enumRenderingFrame, 'EnumRenderingFrame')} = EnumRenderingFrame.TARGET_BODY % TARGET_BODY, CAMERA, CUSTOM_FRAME
                kwargs.dRenderFrameOrigin               (3,1)    double {isvector, isnumeric} = zeros(3,1) %TODO (PC) need to design this carefully, what if single body? Maybe, default is renderframe = 1st body, NavFrameFromRenderFrame = eye(3)
                kwargs.dDCM_RenderFrameFromRenderFrame  (3,3)    double {ismatrix, isnumeric} = eye(3)
                kwargs.bConvertCamQuatToBlenderQuat     (1,1)    logical {islogical, isscalar} = false;
                kwargs.bAutomaticConvertToTargetFixed   (1,1)    logical {islogical, isscalar} = false;
            end
            % Method to compose scene data vector (PQ data). Input attitude matrices are the matrices that
            % project a vector A_OF in OF frame onto the basis composing NavFrame reference frame.

            % Get number of bodies
            ui32NumOfBodies = size(dBodiesOrigin_RenderFrame, 2);
            assert(size(dBodiesAttDCM_RenderFrameFromOF, 3) == ui32NumOfBodies, 'Unmatched number of bodies in Position and Attitude DCM arrays. Please check input data.');
            
            if kwargs.bAutomaticConvertToTargetFixed && not(kwargs.enumRenderingFrame == EnumRenderingFrame.TARGET_BODY)
                % Automatically convert data to target fixed frame before applying composition
                % NOTE: NavFrame becomes "target fixed frame" if this options executes. The first body is
                % assumed as the fixed one.
               
                fprintf( "\tInput data in %s frame. Autoconversion to TARGET_BODY frame enabled...\n", char(kwargs.enumRenderingFrame) )
                [dSunVector_RenderFrame, dCameraOrigin_RenderFrame, ...
                dCameraAttDCM_RenderFrameFromOF, dBodiesOrigin_RenderFrame, ...
                dBodiesAttDCM_RenderFrameFromOF] = BlenderPyCommManager.ConvertSceneToBodyFixedFrame(dSunVector_RenderFrame, ...
                                                                                                  dCameraOrigin_RenderFrame, ...
                                                                                                  dCameraAttDCM_RenderFrameFromOF, ...
                                                                                                  dBodiesOrigin_RenderFrame, ...
                                                                                                  dBodiesAttDCM_RenderFrameFromOF);

                % Override enumRenderingFrame
                kwargs.enumRenderingFrame = EnumRenderingFrame.TARGET_BODY;
            end


            % TODO: based on selected rendering frame, assert identity and origin
            if kwargs.enumRenderingFrame == EnumRenderingFrame.CAMERA
                fprintf('\n\tUsing CAMERA frame as Rendering frame...\n')
                assert( all(dCameraOrigin_RenderFrame == 0, 'all') );
                assert( all(dCameraAttDCM_RenderFrameFromOF == eye(3), 'all') )
    
            elseif kwargs.enumRenderingFrame == EnumRenderingFrame.TARGET_BODY
                fprintf('\n\tUsing TARGET_BODY frame as Rendering frame...')
                assert( all(dBodiesOrigin_RenderFrame(:, 1) == 0, 'all') );
                assert( all(dBodiesAttDCM_RenderFrameFromOF(:,:,1) == eye(3), 'all') )
    
            elseif kwargs.enumRenderingFrame == EnumRenderingFrame.CUSTOM_FRAME
                % No check, assume inputs are already in place
                fprintf('\n\tUsing CUSTOM_FRAME frame as Rendering frame...')
            else
                error('Invalid or unsupported type of rendering frame')
            end

            % Convert all attitude matrices to quaternions used by Blender
            dSunQuaternion_OFfromNavFrame    = BlenderPyCommManager.computeSunBlenderQuatFromPosition(dSunVector_RenderFrame);
                
            if kwargs.bConvertCamQuatToBlenderQuat

                % Transpose DCM to adjust to Blender rotation definition of DCM (TBC) and transform to Quat
                dCameraBlendQuaternion_OFfromNavFrame = BlenderPyCommManager.convertCamQuatToBlenderQuatStatic(...
                    DCM2quat( transpose( dCameraAttDCM_RenderFrameFromOF ) , false) );
            
            else
                % DEVNOTE: ACHTUNG: Blender require attitude matrix to be defined from NavFrame TO OF!
                dCameraBlendQuaternion_OFfromNavFrame = DCM2quat(transpose(dCameraAttDCM_RenderFrameFromOF), false);
            end
            
            dBodiesQuaternion_OFfromNavFrame = zeros(4, ui32NumOfBodies);

            for idB = 1:ui32NumOfBodies
                % DEVNOTE: the quaternion corresponding to the matrix NavFrameFromTF must be first
                % transposed to be the one required by Blender due to the convention for its/my definition
                % of rotation matrices.
                dBodiesQuaternion_OFfromNavFrame(:, idB) = transpose( DCM2quat(transpose( dBodiesAttDCM_RenderFrameFromOF ) , false) ) ;

            end

            % Compose output vector
            dSceneDataVector = zeros(1, 14 + ui32NumOfBodies * 7);
            
            % Allocate Sun PQ
            dSceneDataVector(1:7) = [dSunVector_RenderFrame; dSunQuaternion_OFfromNavFrame];
            % Allocate Camera PQ
            dSceneDataVector(8:14) = [dCameraOrigin_RenderFrame; dCameraBlendQuaternion_OFfromNavFrame];

            % Allocate bodies PQ
            ui32bodiesAllocPtr = uint32(15);
            ui32DeltaPQ = uint32(7);

            for idB = 1:ui32NumOfBodies
                dSceneDataVector(ui32bodiesAllocPtr : ui32bodiesAllocPtr + 6) = [dBodiesOrigin_RenderFrame(1:3, idB); dBodiesQuaternion_OFfromNavFrame(1:4, idB)];
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

            % Conversion loop (TODO)
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
        
        function [dSunVector_RenderFrame, dCameraOrigin_RenderFrame, ...
                dCameraAttDCM_RenderFrameFromOF, dBodiesOrigin_RenderFrame, ...
                dBodiesAttDCM_RenderFrameFromOF] = ConvertSceneToBodyFixedFrame(dSunVector_RenderFrame, ...
                                                                            dCameraOrigin_RenderFrame, ...
                                                                            dCameraAttDCM_RenderFrameFromOF, ...
                                                                            dBodiesOrigin_RenderFrame, ...
                                                                            dBodiesAttDCM_RenderFrameFromOF, ...
                                                                            ui32TargetBodyID)
            arguments
                dSunVector_RenderFrame             (3,1)   double {isvector, isnumeric}
                dCameraOrigin_RenderFrame          (3,1)   double {isvector, isnumeric}
                dCameraAttDCM_RenderFrameFromOF    (3,3)   double {ismatrix, isnumeric}
                dBodiesOrigin_RenderFrame          (3,:)   double {ismatrix, isnumeric}
                dBodiesAttDCM_RenderFrameFromOF    (3,3,:) double {ismatrix, isnumeric} 
                ui32TargetBodyID                (1,1) uint32 {isscalar, isnumeric} = 1
            end
            
            assert(size(dBodiesOrigin_RenderFrame,2) <= ui32TargetBodyID && ui32TargetBodyID > 0, 'Invalid target body index!')

            % Roto-translation pose to apply
            dNewOriginPosition_RenderFrame         = dBodiesOrigin_RenderFrame(:, ui32TargetBodyID);
            dNewFrameDCM_NewFrameFromNavFrame   = transpose( dBodiesAttDCM_RenderFrameFromOF(:, :, ui32TargetBodyID) );

            % Set target pose to Identity.
            dBodiesOrigin_RenderFrame(:, ui32TargetBodyID) = zeros(3,ui32TargetBodyID);
            dBodiesAttDCM_RenderFrameFromOF(:,:, ui32TargetBodyID) = eye(3);

            % Roto-translate camera pose
            dCameraOrigin_RenderFrame       = dNewFrameDCM_NewFrameFromNavFrame * (dCameraOrigin_RenderFrame - dNewOriginPosition_RenderFrame);
            dCameraAttDCM_RenderFrameFromOF = dNewFrameDCM_NewFrameFromNavFrame * dCameraAttDCM_RenderFrameFromOF;

            % Roto-translate Sun position
            dSunVector_RenderFrame = dNewFrameDCM_NewFrameFromNavFrame * (dSunVector_RenderFrame - dNewOriginPosition_RenderFrame);

            % Roto-translate bodies poses
            for idB = 1:size(dBodiesOrigin_RenderFrame, 2)
                
                if idB ~= ui32TargetBodyID
                    dBodiesOrigin_RenderFrame(:, idB) = dNewFrameDCM_NewFrameFromNavFrame * (dBodiesOrigin_RenderFrame(:, idB) - dNewOriginPosition_RenderFrame);
                    dBodiesAttDCM_RenderFrameFromOF(:,:,idB) = dNewFrameDCM_NewFrameFromNavFrame * dBodiesAttDCM_RenderFrameFromOF(:,:,idB);
                end
            end

        end

        function [dSunBlenderQuat_OFfromNavFrame, dSunDCM_OFfromNavFrame] = computeSunBlenderQuatFromPosition(dSunPositionArray_RenderFrame)
            arguments
                dSunPositionArray_RenderFrame (3,:) double {isvector, isnumeric}
            end
            % Function to construct quaternion determining Sun direction as required by Blender, from position
            % NOTE: quaternion must be the one corresponding to the DCM from NavFrame (World) to "Sun frame"

            ui32NumOfQuats = size(dSunPositionArray_RenderFrame, 2);
            dSunBlenderQuat_OFfromNavFrame = zeros(4, ui32NumOfQuats);
            dSunDCM_OFfromNavFrame = zeros(3, 3, ui32NumOfQuats);

            % Compute unit direction
            dUnitVectorToSunArray = dSunPositionArray_RenderFrame./vecnorm(dSunPositionArray_RenderFrame, 2, 1);
        
            % Compute Z axis in NavFrame
            dZaxisArray_RenderFrame = dUnitVectorToSunArray;

            if all(dZaxisArray_RenderFrame == [1; 0; 0]) == true
                dAuxVectorArray_RenderFrame =  repmat(randn(3,1), 1, ui32NumOfQuats); % Auxiliary vector, can be arbitrary not aligned
                dAuxVectorArray_RenderFrame = dAuxVectorArray_RenderFrame./vecnorm(dAuxVectorArray_RenderFrame, 2, 1);
            else
                dAuxVectorArray_RenderFrame =  repmat([1; 0; 0], 1, ui32NumOfQuats); % Auxiliary vector, can be arbitrary not aligned
            end

            % Compute X axis in NavFrame
            dXaxisArray_RenderFrame = cross(dAuxVectorArray_RenderFrame, dZaxisArray_RenderFrame);
            dXaxisArray_RenderFrame = dXaxisArray_RenderFrame ./ vecnorm(dXaxisArray_RenderFrame, 2, 1);

            assert(not(any(isnan(dXaxisArray_RenderFrame))), 'ERROR: failed to define Sun quaternion: nan detected.')

            % Compute Y axis in NavFrame
            dYaxisArray_RenderFrame = cross(dZaxisArray_RenderFrame, dXaxisArray_RenderFrame);

            for idR = 1:ui32NumOfQuats

                % Construct DCM ( TODO: validate matrix)
                % NOTE: matrix has axes of OF frame expressed in NavFrame as rows, such that dot product
                % on each project a vector from NavFrame basis to OF basis.
                dSunDCM_OFfromNavFrame(:,:, idR) = [dXaxisArray_RenderFrame(:,idR)'; dYaxisArray_RenderFrame(:,idR)'; dZaxisArray_RenderFrame(:,idR)']; 

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
    
        % Method to compose command to manually start server with provided paths
        function [charStartBlenderCommand] = GetBlenderStartCommandStatic(charBlenderModelPath, ...
                                                                        charBlenderPyInterfacePath, ...
                                                                        charStartBlenderServerCallerPath, ...
                                                                        ui32ServerPort, ...
                                                                        bUseTmuxShell)
            arguments
                charBlenderModelPath                            string {mustBeA(charBlenderModelPath             , ["string", "char"])}        
                charBlenderPyInterfacePath                      string {mustBeA(charBlenderPyInterfacePath       , ["string", "char"])}      
                charStartBlenderServerCallerPath                string {mustBeA(charStartBlenderServerCallerPath , ["string", "char"])}
                ui32ServerPort                                  (1,1)   uint32 {isnumeric, isscalar}   
                bUseTmuxShell                                   (1,1)   logical {islogical, isscalar} = true
            end

            % Method to compose command to manually start blender server with provided paths
            assert(isfile(charBlenderModelPath), sprintf('Blender model file %s not found.', charBlenderModelPath))
            assert(isfile(charBlenderPyInterfacePath), sprintf('CORTO interface pyscript not found at %s.', charBlenderPyInterfacePath))
            assert(isfile(charStartBlenderServerCallerPath), sprintf('Bash script to start CORTO interface pyscript not found at %s.', charStartBlenderServerCallerPath));

            % Construct command to run
            charStartBlenderCommand = sprintf('bash %s -m "%s" -p "%s"', ...
                charStartBlenderServerCallerPath, charBlenderModelPath, charBlenderPyInterfacePath);

            if bUseTmuxShell
                % Construct tmux_shell
                charStartBlenderCommand = char(sprintf("tmux new-session -d -s %s '%s; exec bash' & echo $!",...
                    strcat("bpy", num2str(ui32ServerPort), "_render"), charStartBlenderCommand)) ;
            end
        end
    end
end
