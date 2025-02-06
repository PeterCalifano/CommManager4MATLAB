classdef CommManager < handle
    %% CONSTRUCTOR
    % self = CommManager(i_charServerAddress, i_ui32ServerPort, i_dCommTimeout, kwargs)
    % -------------------------------------------------------------------------------------------------------------
    %% DESCRIPTION
    % MATLAB class to wrap tcpclient (which cannot be inherited), providing conveniency methods to interact with
    % external TCP servers. See section "methods" for details.
    % -------------------------------------------------------------------------------------------------------------
    %% DATA MEMBERS
    % charServerAddress
    % ui32ServerPort
    % dCommTimeout
    % objtcpClient
    % recvDataBuffer = 0;
    % ui8CommMode = 0;
    % bufferToWrite = 0;
    % recvDataStruct = struct();
    % dataStructToWrite = struct();
    % bUSE_PYTHON_PROTO = true;
    % bUSE_CPP_PROTO = false;
    % bCommManagerReady = false;
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % CommManager
    % Disconnect
    % Initialize
    % WriteBuffer
    % DecodeBuffer
    % EncodeBuffer
    % ReadBuffer
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 12-06-2024        Pietro Califano     Initial implementation as prototype
    % 20-06-2024        Pietro Califano     Debug and updated; Added disconnection method.
    % 14-11-2024        Pietro Califano     Updated class for improved generality; removed code specific to
    %                                       robots-API usage (moved to RobotsCommManager subclass)
    % 24-11-2024        Pietro Califano     Moved to dedicated repo on GitHub for new dev. course: CommManager4MATLAB
    % 18-12-2024        Pietro Califano     Added methods to use msg-pack library for serialization/de-serialization
    % 13-01-2025        Pietro Califano     Add functionalities to support UDP communications
    % 06-02-2025        Pietro Califano     Add functionality to parse and store yaml config file
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % 1) Implement protobuf handling
    % -------------------------------------------------------------------------------------------------------------
    %% Function code
    
    %% PUBLIC DATA MEMBERS
    
    properties (SetAccess = protected, GetAccess = public)
        % CONFIGURATION data members
        charConfigYamlFilename 
        strConfigFromYaml       {isstruct} = struct()

        charServerAddress
        ui32ServerPort          {isnumeric}
        dCommTimeout
        enumCommMode
        ui8CommMode = 0; % TODO (PC) check if still needed by subclasses
        bCommManagerReady       = false;
        bLittleEndianOrdering   = true;
        charByteOrdering        = "little-ending";

        charTargetAddress = "127.0.0.1"
        ui32TargetPort = 0
        i64RecvTCPsize = int64(-1);

        % Serializers options (TODO: modify, these do nothing for now)
        bUSE_PYTHON_PROTO = true;
        bUSE_CPP_PROTO = false;

        % Buffers
        recvDataBuffer = 0;
        bufferToWrite = 0;
        recvDataStruct = struct();
        dataStructToWrite = struct();

        % MATLAB objects to handle connection
        objTCPclient
        objUDPport

        dOutputDatagramSize = 512; % Default size
    end
    
    %% PUBLIC METHODS
    methods (Access = public)
        % CONSTRUCTOR
        function self = CommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
            arguments
                charServerAddress (1,:) string          {ischar, isstring}  
                ui32ServerPort    (1,:) uint32          {isvector, isnumeric} 
                dCommTimeout      (1,1) double          {isscalar, isnumeric} = 20     
            end
            
            arguments
                kwargs.bUSE_PYTHON_PROTO        (1,1) logical       {islogical, isscalar} = true
                kwargs.bUSE_CPP_PROTO           (1,1) logical       {islogical, isscalar} = false
                kwargs.bInitInPlace             (1,1) logical       {islogical, isscalar} = false
                kwargs.enumCommMode             (1,1) EnumCommMode  {isa(kwargs.enumCommMode, 'EnumCommMode')} = EnumCommMode.TCP
                kwargs.bLittleEndianOrdering    (1,1) logical       {islogical, isscalar} = true;
                kwargs.dOutputDatagramSize      (1,1) double        {isscalar, isnumeric} = 512     
                kwargs.ui32TargetPort           (1,1) uint32        {isscalar, isnumeric} = 0
                kwargs.charTargetAddress        (1,:) string        {isscalar, isnumeric} = "127.0.0.1"
                kwargs.i64RecvTCPsize           (1,1) int64         {isscalar, isnumeric} = -1; 
            end
            
            fprintf('\nCreating communication manager object... \n')
            
            % Assign server address
            self.charServerAddress  = charServerAddress;
            self.ui32ServerPort     = ui32ServerPort;
            self.dCommTimeout       = dCommTimeout;

            % Targets for UDP
            self.charTargetAddress  = kwargs.charTargetAddress;
            self.ui32TargetPort     = kwargs.ui32TargetPort;

            % Fixed size buffer for TCP recv
            self.i64RecvTCPsize = kwargs.i64RecvTCPsize;

            % Assign server properties
            self.bUSE_PYTHON_PROTO      = kwargs.bUSE_PYTHON_PROTO;
            self.bUSE_CPP_PROTO         = kwargs.bUSE_CPP_PROTO;
            self.dOutputDatagramSize    = kwargs.dOutputDatagramSize;
            self.enumCommMode           = kwargs.enumCommMode;

            self.bLittleEndianOrdering = kwargs.bLittleEndianOrdering;
            self.charByteOrdering = 'big-endian';

            if self.bLittleEndianOrdering
                self.charByteOrdering = 'little-endian';
            end

            if self.enumCommMode == EnumCommMode.UDP_TCP
                assert(length(self.ui32ServerPort) == 2, 'UDP-TCP mode requested, but only 1 server port provided. Requires 2 different ports (TCP, UDP)')
            end

            % Set packet size for UDP
            self.dOutputDatagramSize = kwargs.dOutputDatagramSize;

            if kwargs.bInitInPlace
                fprintf("\tInstantiation of CommManager completed. Attempting to open communication...\n")
                self = self.Initialize();
            else
                fprintf("\tInstantiation of CommManager completed.\n")
            end
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to initialize tcpclient object to establish connection
        function self = Initialize(self)
            
            switch self.enumCommMode

                case EnumCommMode.TCP
                    % TCP-TCP communication (1 object)
                    fprintf('\nInitializing communication with TCP client object at HOST: %s - PORT: %s\n', ...
                        self.charServerAddress, num2str(self.ui32ServerPort(1)));

                    if length(self.ui32ServerPort) > 1
                        warning('TCP communication requested, but 2 server ports provided. Using only the first entry...')
                    end
                    
                    self.objTCPclient = tcpclient(self.charServerAddress, self.ui32ServerPort(1), "Timeout", self.dCommTimeout);

                    self.bCommManagerReady = true;
                    fprintf('Connection established correctly.');

                case EnumCommMode.UDP
                    % UDP-UDP communication (1 object)
                    error('Not implemented yet')
                    % TODO (PC)
                    fprintf('\nInitializing communication with TCP client object at HOST: %s - PORT: %s\n', ...
                        self.charServerAddress, num2str(self.ui32ServerPort(1)));

                    self.objUDPport = udpport("Datagram", "LocalPort", self.ui32ServerPort(2), ...
                                              "LocalHost", self.charServerAddress, ...
                                              "ByteOrder", self.charByteOrdering, ...
                                              "Timeout", self.dCommTimeout, ...
                                              "OutputDatagramSize", self.dOutputDatagramSize);                    % TODO (PC)

                case EnumCommMode.UDP_TCP
                    % UDP-TCP communication (2 objects)                    
                    
                    % TODO (PC)
                    fprintf('\nInitializing communication objects... \n');
                    
                    % UDP port
                    fprintf('\tUDP client object at HOST: %s - PORT: %s \n', self.charServerAddress, num2str(self.ui32ServerPort(2)));

                    self.objUDPport = udpport("Datagram", "LocalPort", self.ui32ServerPort(2), ...
                                              "LocalHost", self.charServerAddress, ...
                                              "ByteOrder", self.charByteOrdering, ...
                                              "Timeout", self.dCommTimeout, ...
                                              "OutputDatagramSize", self.dOutputDatagramSize);
                    
                    % TCP client
                    fprintf('\tTCP client object at HOST: %s - PORT: %s \n', self.charServerAddress, num2str(self.ui32ServerPort(1)));

                    self.objTCPclient = tcpclient(self.charServerAddress, ...
                                                  self.ui32ServerPort(1), ...
                                                  "Timeout", self.dCommTimeout);

                    self.bCommManagerReady = true;
                    fprintf('Connection established correctly.\n');

            end



        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to write buffer (no check on format) and send data to server
        function writtenBytes = WriteBuffer(self, dataBuffer, bAddDataSize, ui32TargetPort, charTargetAddress)
            arguments
                self                (1,1)
                dataBuffer          (1,:) uint8   {isvector, isa(dataBuffer, 'uint8')}
                bAddDataSize        (1,1) logical {islogical, isscalar}     = false
                ui32TargetPort      (1,1) uint32  {isnumeric, isscalar}     = 0
                charTargetAddress   (1,:) string  {isvector}                = "127.0.0.1"
            end
            
            self.assertInit();
            
            if not(isa(dataBuffer, 'uint8'))
                assert()
                error('Input dataBuffer is not a stream of uint8 (bytes)!')
            end
            
            fprintf("\nCommManager: Writing buffer of %d bytes...\n", whos('dataBuffer').bytes);
            
            if bAddDataSize
                dataLength = typecast(uint32(length(dataBuffer)), 'uint8');
                dataBuffer = [dataLength, dataBuffer];
            end

            if  self.enumCommMode == EnumCommMode.TCP

                    % TCP-send communication 
                    write(self.objTCPclient, dataBuffer, "uint8");
                    writtenBytes = self.objTCPclient.NumBytesWritten;

                    % Flush data from buffer
                    flush(self.objTCPclient, "output");

            elseif self.enumCommMode == EnumCommMode.UDP || self.enumCommMode == EnumCommMode.UDP_TCP

                if ui32TargetPort == 0
                    ui32TargetPort = self.ui32TargetPort;
                else
                    % OVERRIDE: Target port provided as input (default)
                end

                if not(nargin > 3) && strcmpi(charTargetAddress, "127.0.0.1")
                    charTargetAddress = self.charTargetAddress;
                else
                    % OVERRIDE: Target address provided as input (default)
                end

                assert(not(isempty(char(charTargetAddress))), 'UDP send requires a target port to be specified: cannot be empty.');
                assert(not(ui32TargetPort == 0) , 'UDP send requires a target port to be specified: cannot be 0.');

                
                % UDP-send communication
                write(self.objUDPport, dataBuffer, char(charTargetAddress), double(ui32TargetPort)); % Send data to destination
                writtenBytes = length(dataBuffer);

            end

        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read data to buffer
        function [recvBytes, recvDataBuffer, self] = ReadBuffer(self, i64BytesSizeToRead)
            arguments
                self
                i64BytesSizeToRead (1,1) int64 {isscalar, isnumeric} = -1
            end
            
            self.assertInit();

            % Read size override mode
            if i64BytesSizeToRead ~= -1
                % Store previously set read size
                i64PrevRecvTCPsize = self.i64RecvTCPsize;
                self.i64RecvTCPsize = int64(i64BytesSizeToRead);
            end

            if  self.enumCommMode == EnumCommMode.TCP || self.enumCommMode == EnumCommMode.UDP_TCP
                % TCP-recv communication
                try
                    if self.i64RecvTCPsize == -1

                        % Read first 4 bytes to get message buffer length
                        recvBytes   = read(self.objTCPclient, 4, 'uint8');
                        recvBytes   = typecast(recvBytes, 'uint32');

                        if recvBytes == 0
                            warning('Read recv buffer length from remote server, but equal to 0. Something may have gone wrong or did you forget to fix "i64RecvTCPsize" field?');
                        end

                    elseif self.i64RecvTCPsize == -5 % Special "Eager" MODE: get all bytes
                        % TODO (PC) not easy at it may seem: read is blocking, but if there exists latency
                        % between when this client reaches it and the time the server writes something to
                        % buffer, this mode would break apart entirely. 
                    else
                        recvBytes = self.i64RecvTCPsize; % Use specified size to receive
                    end

                    if recvBytes >= int64(1e20) % Check for potential overflow
                        warning('Possible overflow: Received message buffer length is greater than or equal to the maximum value of int64 (9223372036854775807).');
                    end

                    assert(recvBytes >= 0, 'Error: Received/set message buffer length is invalid (zero or negative).');

                    % Read message buffer
                    recvDataBuffer = read(self.objTCPclient, recvBytes, 'uint8');

                    if self.objTCPclient.NumBytesAvailable > 0 

                        if self.objTCPclient.NumBytesAvailable > self.i64RecvTCPsize
                            warning('Read user-specified number of bytes %d, but buffer contains %d > %d', self.i64RecvTCPsize, self.objTCPclient.NumBytesAvailable, self.i64RecvTCPsize)
                        elseif self.objTCPclient.NumBytesAvailable > recvBytes
                            warning('Read number of bytes %d as specified by message header, but buffer contains %d > %d', recvBytes, self.objTCPclient.NumBytesAvailable, recvBytes)
                        end

                    end

                catch ME
                    disp(ME.message);
                    if contains(ME.identifier, 'timeout', 'IgnoreCase', true)
                        fprintf(['\nDo you need to recv a fixed size buffer of known size and/or the first 4 bytes do not specify the length? \n' ...
                            'Please specify "i64RecvTCPsize" kwarg at class instantiation to enable this TCP recv mode!.\n']);
                    end
                    error(ME)
                end

                % Allocate buffer to property
                self.recvDataBuffer = recvDataBuffer;

                % Flush data from buffer
                flush(self.objTCPclient, "input");

                % Restore previously set TCP recv size if override mode
                if exist('i64PrevRecvTCPsize', 'var')
                    self.i64RecvTCPsize = i64PrevRecvTCPsize;
                end

            elseif self.enumCommMode == EnumCommMode.UDP 

                % TODO (PC)
                if isempty(ui32TargetPort) 
                    ui32TargetPort = self.ui32TargetPort;
                else
                    % OVERRIDE: Target port provided as input (default)
                end

                if not(nargin > 3) && strcmpi(charTargetAddress, "127.0.0.1")
                    charTargetAddress = self.charTargetAddress;
                else
                    % OVERRIDE: Target address provided as input (default)
                end

                error('Not implemented yet')

            end


        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to disconnect the client
        function [self] = Disconnect(self)
            self.objTCPclient = 0;
        end
        
    end
    
    methods (Static)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to encode input datastruct through protobuflib % TODO
        % NOTE: THIS MUST BE GENERIC FOR ANY PROTO --> which TBS by caller
        function [ui8SerializedBuffer] = SerializeBuffer(inDataStruct, bSplitMessages)
            arguments
                inDataStruct (1,1) {isValidDataStruct}
                bSplitMessages (1,1) logical {islogical} = false
            end
            
            % TODO: add "multi message mode" --> input is a cell containing multiple datastructs to be serialized as different messages
            self.assertInit();
            if bSplitMessages == false
                ui8SerializedBuffer = dumpmsgpack(inDataStruct);      
            else
                error('Not implemented yet!');  
            end    
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to decode datastruct through protobuflib  % TODO
        function [outDataStruct, self] = DeserializeBuffer(self, ui8SerializedBuffer)
            arguments
                self
                ui8SerializedBuffer (1,1)
            end
            
            self.assertInit();

            error('NOT IMPLEMENTED YET')
            self.recvDataStruct = o_objdecodedMessage; % TODO
        end
        
    end
    
    methods (Access = public)

        function self = parseYamlConfig_(self, charConfigYamlFilename)

            % Check if file exists
            assert(exist(charConfigYamlFilename, 'file'), "Yaml configuration file specified as input not found.")

            % Check if it has file extension, else add
            [~, ~, charExt] = fileparts(charConfigYamlFilename);

            if strcmpi(charExt, "")
                charConfigYamlFilename = strcat(charConfigYamlFilename, ".yaml");
            end

            % Store path to yaml file
            self.charConfigYamlFilename = charConfigYamlFilename;

            % Load file using yaml community library
            self.strConfigFromYaml = yaml.loadFile(charConfigYamlFilename);

        end
    end

    methods (Access = protected)

        % DEVNOTE: may be implemented by overloading/overriding the subsref method such that it gets called
        % at each dot indexing (properties included) automatically.
        function assertInit(self)
            assert(self.bCommManagerReady == true, 'Class not initialized correctly. You need to establish connection before use! Call instance.Initialize() or pass flag bInitInPlace as true.')
        end

        function bIsValid = isValidDataStruct(objdataStructToWrite)
            % TODO: not used, to be implemented
            bIsValid = true;
        end
    end

end
