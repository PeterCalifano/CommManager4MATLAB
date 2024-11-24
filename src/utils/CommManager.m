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
% 12-06-2024        Pietro Califano      Initial implementation as prototype
% 20-06-2024        Pietro Califano      Debug and updated; Added disconnection method.
% 14-11-2024        Pietro Califano      Updated class for improved generality; removed code specific to
%                                        robots-API usage (moved to RobotsCommManager subclass)
% 24-11-2024        Pietro Califano      Moved to dedicated repo on GitHub for new course: CommManager4MATLAB
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
        charServerAddress
        ui32ServerPort
        dCommTimeout
        objtcpClient
        recvDataBuffer = 0;
        ui8CommMode = 0;
        bufferToWrite = 0;
        recvDataStruct = struct();
        dataStructToWrite = struct();
        bUSE_PYTHON_PROTO = true;
        bUSE_CPP_PROTO = false;
        bCommManagerReady = false;
    end

    %% PUBLIC METHODS
    methods (Access=public)
        % CONSTRUCTOR
        function self = CommManager(i_charServerAddress, i_ui32ServerPort, i_dCommTimeout, kwargs)
            arguments
                i_charServerAddress (1,:) {ischar, isstring} 
                i_ui32ServerPort    (1,1) uint32   {isscalar}
                i_dCommTimeout      (1,1) double  {isscalar} = 10     
            end

            arguments
                kwargs.bUSE_PYTHON_PROTO  (1,1) logical {islogical} = true
                kwargs.bUSE_CPP_PROTO     (1,1) logical {islogical} = false
                kwargs.bInitInPlace       (1,1) logical {islogical} = false
            end

            disp('Creating communication manager object...')

            % Assign server address
            self.charServerAddress = i_charServerAddress;
            self.ui32ServerPort    = i_ui32ServerPort;
            self.dCommTimeout      = i_dCommTimeout;

            % Assign server properties
            self.bUSE_PYTHON_PROTO = kwargs.bUSE_PYTHON_PROTO;
            self.bUSE_CPP_PROTO    = kwargs.bUSE_CPP_PROTO;

            if kwargs.bInitInPlace
                self = self.Initialize();
            end
            
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to initialize tcpclient object to establish connection
        function self = Initialize(self)
            
            fprintf('\nInitializing communication calling tcpclient with HOST: %s, PORT: %s\n', ...
                self.charServerAddress, num2str(self.ui32ServerPort));

            self.objtcpClient = tcpclient(self.charServerAddress, self.ui32ServerPort, ...
                "Timeout", self.dCommTimeout);
            
            self.bCommManagerReady = true;
            fprintf('Connection established corrected.');

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to write buffer (no check on format) and send data to server
        function writtenBytes = WriteBuffer(self, dataBuffer, bAddDataSize)
            arguments
                self  (1,1)
                dataBuffer   (1,:)
                bAddDataSize (1,1) = false
            end

            self.assertInit();

            if not(isa(dataBuffer, 'uint8'))
                error('Input dataBuffer is not a stream of uint8 (bytes)!')
            end

            fprintf("\nCommManager: Writing buffer of %d bytes...\n", whos('dataBuffer').bytes);

            if bAddDataSize
                dataLength = typecast(uint32(length(dataBuffer)), 'uint8');
                dataBuffer = [dataLength, dataBuffer];
            end

            write(self.objtcpClient, dataBuffer, "uint8");
            writtenBytes = self.objtcpClient.NumBytesAvailable;

            % Flush data from buffer
            flush(self.objtcpClient, "output");

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read data to buffer
        function [recvBytes, recvDataBuffer, self] = ReadBuffer(self)

            self.assertInit();

            % Read first 4 bytes to get message buffer length
            recvBytes   = read(self.objtcpClient, 4, 'uint8');
            recvBytes   = typecast(recvBytes, 'uint32');

            % Read message buffer
            recvDataBuffer = read(self.objtcpClient, recvBytes, 'uint8');

            % Allocate buffer to property
            self.recvDataBuffer = recvDataBuffer;

            % Flush data from buffer
            flush(self.objtcpClient, "input");
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to encode input datastruct through protobuflib % TODO
        % NOTE: THIS MUST BE GENERIC FOR ANY PROTO --> which TBS by caller
        function [encodedMessage] = EncodeBuffer(i_objdataStructToWrite)
            arguments
                i_objdataStructToWrite (1,1) {isValidDataStruct}
            end

            self.assertInit();

            error('NOT IMPLEMENTED YET')
            commManager.bufferToWrite;  % TODO

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to decode datastruct through protobuflib  % TODO
        function [o_objdecodedMessage, self] = DecodeBuffer(self)
            arguments (Output)
                o_objdecodedMessage (1,1) {}
                self (1,1)
            end
            self.assertInit();

            error('NOT IMPLEMENTED YET')
            self.recvDataStruct = o_objdecodedMessage; % TODO
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to disconnect the client
        function [self] = Disconnect(self)
            self.objtcpClient = 0;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to write message from datastruct


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read message from datastruct


    end


    methods (Access = protected)
        % DEVNOTE: may be implemented by overloading/overriding the subsref method such that it gets called
        % at each dot indexing (properties included) automatically.
        function assertInit(self)
            assert(self.bCommManagerReady == true, 'Class not initialized correctly. You need to establish connection before use! Call instance.Initialize() or pass flag bInitInPlace as true.')
        end
    end

end
