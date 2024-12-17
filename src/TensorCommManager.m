classdef TensorCommManager < CommManager
    %% CONSTRUCTOR
    % self = TensorCommManager(i_charServerAddress, i_ui32ServerPort, i_dCommTimeout, kwargs)
    % -------------------------------------------------------------------------------------------------------------
    %% DESCRIPTION
    % MATLAB class tailoring CommManager (base class) for PyTorchAutoForge use. Default values are assumed to
    % connect tcpcline to server without user inputs. This class augments CommManager to conveniently
    % exchange tensor data buffers (N-dim arrays) with PyTorchAutoForge tcp API.
    % -------------------------------------------------------------------------------------------------------------
    %% DATA MEMBERS
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 24-11-2024        Pietro Califano      Defined as subclass of CommManager to tailor it for PyTorchAutoForge
    % 25-11-2024        Pietro Califano      Implemented methods to convert tensor data to bytes and viceversa
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Function code
    
    properties (SetAccess = protected, GetAccess = public)
        bMULTI_TENSOR = false;
    end
    
    methods
        function self = TensorCommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
            arguments
                charServerAddress (1,:) {ischar, isstring}  = "127.0.0.1" % Assumes localhost
                ui32ServerPort    (1,1) uint32  {isscalar} = 55556
                dCommTimeout      (1,1) double  {isscalar}  = 20
            end
            
            arguments
                kwargs.bUSE_PYTHON_PROTO  (1,1) logical {islogical} = true
                kwargs.bUSE_CPP_PROTO     (1,1) logical {islogical} = false
                kwargs.bInitInPlace       (1,1) logical {islogical} = false
                kwargs.bMULTI_TENSOR      (1,1) logical {islogical} = false
            end
            
            self = self@CommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
                'bUSE_PYTHON_PROTO', kwargs.bUSE_PYTHON_PROTO, 'bUSE_CPP_PROTO', kwargs.bUSE_CPP_PROTO, 'bInitInPlace', kwargs.bInitInPlace);
            
            self.bMULTI_TENSOR = kwargs.bMULTI_TENSOR;
        end
        
        % PUBLIC METHODS
        function writtenBytes = WriteBuffer(self, dTensorArray)
            arguments
                self          (1,1)
                dTensorArray   double
            end
            
            self.assertInit();
            
            
            % TODO
            if self.bMULTI_TENSOR == true
                error('NOT IMPLEMENTED YET')
                % TODO: convert everything in a cell or struct into multiple single messages with "tensor convention"
                % Then concat all messages into a single buffer
                
            else
                ui8DataBuffer = self.TensorArray2Bytes(dTensorArray);
                
            end
            
            % Convert dTensorArray into ui8DataBuffer with "tensor convention"
            bAddDataSize = true;
            
            % Call base class method to write raw buffer
            writtenBytes = self.WriteBuffer@CommManager(ui8DataBuffer, bAddDataSize);
            
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read data to buffer
        function [dTensorArray, self] = ReadBuffer(self)
            
            self.assertInit();
            
            % Read data incoming from TCP server
            [ui32RecvBytes, ui8RecvDataBuffer, self] = self.ReadBuffer@CommManager();
            
            
            % TODO
            if self.bMULTI_TENSOR == true
                error('NOT IMPLEMENTED YET')
                % TODO: convert everything in a cell or struct into multiple single messages with "tensor convention"
                % Then concat all messages into a single buffer
                
            else
                % Read bufer length
                ui32RecvMessageBytes = typecast(ui8RecvDataBuffer(1:4), 'uint32');

                % Convert received buffer into dTensorArray with "tensor convention"
                dTensorArray = self.Bytes2TensorArray(ui32RecvMessageBytes, ui8RecvDataBuffer(5:end));
            end
            
            
        end
        
        % function [o_objdecodedMessage, self] = DecodeBuffer(self)
        %     arguments (Output)
        %         o_objdecodedMessage (1,1) {isValidDataStruct}
        %         self (1,1)
        %     end
        %
        %     error('NOT IMPLEMENTED YET')
        %     [self.recvDataStruct, self] = self.DecodeBuffer@CommManager(); % TODO
        % end
        
    end
    
    methods (Static, Access = public)
        function dTensorArray = Bytes2TensorArray(ui32RecvMessageBytes, ui8DataBuffer)
            % Static method to convert buffer of bytes to tensor array (N-dim array) (format tailored for PyTorchAutoForge)
            arguments
                ui32RecvMessageBytes (1, 1) uint32 {isscalar}
                ui8DataBuffer (1, :) uint8  {isvector}
            end
            
            % Read bytes indicating how many sizes are to unpack
            i32TensorDims = typecast(ui8DataBuffer(1:4), 'uint32');
            
            % Create shape array
            i32TensorShape = zeros(1, i32TensorDims, "uint32");
            
            for idPtr = 1:i32TensorDims
                i32TensorShape(idPtr) = typecast(ui8DataBuffer(4*idPtr+1:4*idPtr+4), 'uint32');
            end
            
            % Assign idPtr to next byte
            idPtr = 4*i32TensorDims + 4; % TBC
            
            % Check ptr is lower than total bytes
            assert(idPtr < ui32RecvMessageBytes, 'ERROR: Pointer exceeds total bytes.')
            
            % Get bytes of tensor data from buffer and do typecasting
            dTensorBuffer = typecast(ui8DataBuffer(idPtr+1:end), 'single');
            
            % Reshape tensor data according to i32TensorShape
            dTensorArray = reshape(dTensorBuffer, i32TensorShape);
            
            % Squeeze tensor if any dimension is 1
            if any(i32TensorShape == 1)
                dTensorArray = squeeze(dTensorArray);
            end
            
        end
        
        function [ui8DataBuffer, ui32TensorDims, ui32TensorShape] = TensorArray2Bytes(dTensorArray, kwargs)
            % Static method to convert tensor array (N-dim array) to buffer of bytes to transmit over TCP (format tailored for PyTorchAutoForge)
            arguments
                dTensorArray double
            end
            arguments
                kwargs.ui32NumOfBatches  (1,1) uint32 {isscalar} = 0
                kwargs.ui32NumOfChannels (1,1) uint32 {isscalar} = 0
            end
            
            % Get tensor shape
            ui32TensorShape = uint32(size(dTensorArray));
            
            % Get number of dimensions
            ui32TensorDims = uint32(length(ui32TensorShape));
            
            % If specified, add number of batches and channels to shape
            if kwargs.ui32NumOfBatches > 0
                ui32TensorShape = [kwargs.ui32NumOfBatches, ui32TensorShape];
                ui32TensorDims = ui32TensorDims + 1;
            end
            
            if kwargs.ui32NumOfChannels > 0
                ui32TensorShape = [ui32TensorShape, kwargs.ui32NumOfChannels];
                ui32TensorDims = ui32TensorDims + 1;
            end
            
            % Flatten tensor data to linear array and downcast to single
            fTensorBuffer = single(dTensorArray(:));
            
            % Convert tensor data to bytes
            ui8TensorBuffer = typecast(fTensorBuffer, 'uint8');
               
            if iscolumn(ui8TensorBuffer)
                ui8TensorBuffer = ui8TensorBuffer';
            end

            % Convert tensor shape to bytes
            ui8TensorDims = typecast(ui32TensorDims, 'uint8');
            ui8TensorShape = typecast(ui32TensorShape, 'uint8');
            
            % Construct data buffer
            ui8DataBuffer = [ui8TensorDims, ui8TensorShape, ui8TensorBuffer];

            % Add message length to buffer
            ui32MessageBytes = uint32(length(ui8DataBuffer));
            ui8DataBuffer = [typecast(ui32MessageBytes, 'uint8'), ui8DataBuffer];
            
        end
    end
    
    %% PRIVATE METHODS
    methods (Access=private)
        
        
    end
    
end
