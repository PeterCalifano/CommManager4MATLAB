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
           [recvBytes, recvDataBuffer, self] = self.ReadBuffer@CommManager(ui8DataBuffer, bAddDataSize);

            % Convert received buffer into dTensorArray with "adaptive size convention"
            dTensorArray = Bytes2TensorArray(recvDataBuffer);

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
        function dTensorArray = Bytes2TensorArray(ui8DataBuffer)
            arguments
                ui8DataBuffer (:) uint8
            end

            % TODO
        end

        function  ui8DataBuffer = TensorArray2Bytes(dTensorArray)
            arguments
                dTensorArray double
            end

            % TODO
        end
    end

    %% PRIVATE METHODS
    methods (Access=private)


    end

end
