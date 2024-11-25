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
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Function code

    properties (SetAccess = protected, GetAccess = public)

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
            end

            self = self@CommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
                'bUSE_PYTHON_PROTO', kwargs.bUSE_PYTHON_PROTO, 'bUSE_CPP_PROTO', kwargs.bUSE_CPP_PROTO, 'bInitInPlace', kwargs.bInitInPlace);

        end

        % PUBLIC METHODS
        function writtenBytes = WriteBuffer(self, dTensorArray)
            arguments
                self          (1,1)
                dTensorArray   double
            end

            self.assertInit();


            % TODO

            % Convert dTensorArray into ui8DataBuffer with "adaptive size convention"
            ui8DataBuffer = TensorArray2Bytes(dTensorArray);
            bAddDataSize = true;

            % Call base class method to write raw buffer
            writtenBytes = self.WriteBuffer@CommManager(ui8DataBuffer, bAddDataSize);


        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Method to read data to buffer
        function [dTensorArray, self] = ReadBuffer(self)

            self.assertInit();

            % Read data incoming from TCP server
           [ui32RecvBytes, ui8RecvDataBuffer, self] = self.ReadBuffer@CommManager(ui8DataBuffer, bAddDataSize);

            % Convert received buffer into dTensorArray with "adaptive size convention"
            dTensorArray = Bytes2TensorArray(ui32RecvBytes, ui8RecvDataBuffer);

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
        function dTensorArray = Bytes2TensorArray(ui32RecvBytes, ui8DataBuffer)
            % Static method to convert buffer of bytes to tensor array (N-dim array) (format tailored for PyTorchAutoForge)
            arguments
                ui32RecvBytes (1, 1) uint32 {isscalar}
                ui8DataBuffer (1, :) uint8  {isvector}
            end

            % Read bytes indicating how many sizes are to unpack
            i32TensorDims = typecast(ui8DataBuffer(1:4), 'int32');
            
            % Create shape array
            i32TensorShape = zeros(1, i32TensorDims, "uint32");

            for idPtr = 1:i32TensorDims
                i32TensorShape(idPtr) = typecast(ui8DataBuffer(4*idPtr+1:4*idPtr+4), 'uint32');
            end
            
            % Assign idPtr to next byte
            idPtr = 4*i32TensorDims + 4; % TBC

            % Check ptr is lower than total bytes
            assert(idPtr < ui32RecvBytes, 'ERROR: Pointer exceeds total bytes.')

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

            % Convert tensor shape to bytes
            ui8TensorDims = typecast(ui32TensorDims, 'uint8');
            ui8TensorShape = typecast(ui32TensorShape, 'uint8');
            
            % Construct data buffer
            ui8DataBuffer = [ui8TensorDims, ui8TensorShape, ui8TensorBuffer];

        end
    end

    %% PRIVATE METHODS
    methods (Access=private)


    end

end
