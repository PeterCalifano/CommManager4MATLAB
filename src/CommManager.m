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
    % 24-11-2024        Pietro Califano      Moved to dedicated repo on GitHub for new dev. course: CommManager4MATLAB
    % 18-12-2024        Pietro Califano      Added methods to use msg-pack library for serialization/de-serialization
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
        % TODO (PC) improve data members definitions and order!
        charServerAddress
        ui32ServerPort
        dCommTimeout
        objTCPclient
        objUDPport
        enumCommMode
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
    methods (Access = public)
        % CONSTRUCTOR
        function self = CommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
            arguments
                charServerAddress (1,:) string          {ischar, isstring} 
                ui32ServerPort    (1,1) uint32          {isscalar}
                dCommTimeout      (1,1) double          {isscalar} = 10     
            end
            
            arguments
                kwargs.bUSE_PYTHON_PROTO    (1,1) logical       {islogical} = true
                kwargs.bUSE_CPP_PROTO       (1,1) logical       {islogical} = false
                kwargs.bInitInPlace         (1,1) logical       {islogical} = false
                kwargs.enumCommMode         (1,1) EnumCommMode  {isa(kwargs.enumCommMode, 'EnumCommMode')} = EnumCommMode.TCP
            end
            
            disp('Creating communication manager object...')
            
            % Assign server address
            self.charServerAddress  = charServerAddress;
            self.ui32ServerPort     = ui32ServerPort;
            self.dCommTimeout       = dCommTimeout;
            self.enumCommMode       = kwargs.enumCommMode;

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
            
            switch self.enumCommMode

                case EnumCommMode.TCP
                    % TCP-TCP communication
                    fprintf('\nInitializing communication calling tcpclient with HOST: %s, PORT: %s\n', ...
                        self.charServerAddress, num2str(self.ui32ServerPort));

                    self.objTCPclient = tcpclient(self.charServerAddress, self.ui32ServerPort, ...
                        "Timeout", self.dCommTimeout);

                    self.bCommManagerReady = true;
                    fprintf('Connection established correctly.');

                case EnumCommMode.UDP
                    % UDP-UDP communication
                    error('Not implemented yet')

                    % TODO (PC)

                case EnumCommMode.UDP_TCP
                    % UDP-TCP communication
                    error('Not implemented yet')
                    
                    % TODO (PC)
                    fprintf('\nInitializing communication calling tcpclient with HOST: %s, PORT: %s\n', ...
                        self.charServerAddress, num2str(self.ui32ServerPort));

                    self.objTCPclient = tcpclient(self.charServerAddress, self.ui32ServerPort, ...
                        "Timeout", self.dCommTimeout);

                    self.bCommManagerReady = true;
                    fprintf('Connection established correctly.');

            end



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

            write(self.objTCPclient, dataBuffer, "uint8");
            writtenBytes = self.objTCPclient.NumBytesAvailable;

            % Flush data from buffer
            flush(self.objTCPclient, "output");

        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read data to buffer
        function [recvBytes, recvDataBuffer, self] = ReadBuffer(self)
            
            self.assertInit();
            
            % Read first 4 bytes to get message buffer length
            recvBytes   = read(self.objTCPclient, 4, 'uint8');
            recvBytes   = typecast(recvBytes, 'uint32');
            
            % Read message buffer
            recvDataBuffer = read(self.objTCPclient, recvBytes, 'uint8');

            % Allocate buffer to property
            self.recvDataBuffer = recvDataBuffer;
            
            % Flush data from buffer
            flush(self.objTCPclient, "input");
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to disconnect the client
        function [self] = Disconnect(self)
            self.objtcpClient = 0;
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
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to disconnect the client
        function [self] = Disconnect(self)
            self.objTCPclient = 0;
        end
    end
    
    methods (Access = protected)
        % DEVNOTE: may be implemented by overloading/overriding the subsref method such that it gets called
        % at each dot indexing (properties included) automatically.
        function assertInit(self)
            assert(self.bCommManagerReady == true, 'Class not initialized correctly. You need to establish connection before use! Call instance.Initialize() or pass flag bInitInPlace as true.')
        end
        
        function bIsValid = isValidDataStruct(objdataStructToWrite)
            % TEMPORARY: to be implemented
            bIsValid = true;
        end
    end
    
end
