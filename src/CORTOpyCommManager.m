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
    % 
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


    methods (Access = public)
        % PUBLIC methods
        function self = CORTOpyCommManager(charServerAddress, ui32ServerPort, dCommTimeout, kwargs)
           arguments
                charServerAddress (1,:) {ischar, isstring}              = "127.0.0.1" % Assumes localhost
                ui32ServerPort    (1,2) uint32  {isvector, isnumeric}   = [30001, 51000]; % [TCP, UDP] Assumes ports used by CORTOpy interface
                dCommTimeout      (1,1) double  {isscalar, isnumeric}   = 45
           end
           % TODO: adjust kwargs required for CORTOpy
           arguments
               kwargs.bInitInPlace             (1,1) logical       {islogical, isscalar} = false
               kwargs.enumCommMode             (1,1) EnumCommMode  {isa(kwargs.enumCommMode, 'EnumCommMode')} = EnumCommMode.UDP_TCP
               kwargs.bLittleEndianOrdering    (1,1) logical       {islogical, isscalar} = true;
               kwargs.dOutputDatagramSize      (1,1) double        {isscalar, isnumeric} = 512
               kwargs.ui32TargetPort           (1,1) uint32        {isscalar, isnumeric} = 0
               kwargs.charTargetAddress        (1,:) string        {isscalar, isnumeric} = "127.0.0.1"
               kwargs.i32RecvTCPsize           (1,1) int32         {isscalar, isnumeric} = -1; % SPECIAL MODE: -5
           end

           % Initialize base class 
           self = self@CommManager(charServerAddress, ui32ServerPort, dCommTimeout, ...
               'bUSE_PYTHON_PROTO', kwargs.bUSE_PYTHON_PROTO, 'bUSE_CPP_PROTO', ...
               kwargs.bUSE_CPP_PROTO, 'bInitInPlace', kwargs.bInitInPlace, ...
               'charTargetAddress', kwargs.charTargetAddress, 'bLittleEndianOrdering', kwargs.bLittleEndianOrdering, ...
               'dOutputDatagramSize', kwargs.dOutputDatagramSize, 'enumCommMode', kwargs.enumCommMode, ...
               'i32RecvTCPsize', kwargs.i32RecvTCPsize, 'ui32TargetPort',  kwargs.ui32TargetPort);
            
        end


        function [dImg, self] = getImageArray(self, dSceneData)
            arguments
                self       (1,1)
                dSceneData (1,:) double {isvector, isnumeric}
            end
            
            % Input check
            assert( mod(dSceneData, 7) == 0, ['Number of doubles to send to CORTOpy must be a multiple of 7 (PQ message). \n' ...
                'Required format: [dSunPos, dSunQuat, dSCPos, dSCquat, dBody1Pos, dBody1Quat, ... dBodyNPos, dBodyNQuat]']);
            assert( size(dSceneData, 2) - 14 > 0, 'Only Sun and Camera PQ specified in dSceneData message. You should specify at least 1 body.');
            
            % Cast to bytes
            ui8SceneDataBuffer = typecast(dBuffer, 'uint8');
            % Send to CORTOpy server
            writtenBytes = self.WriteBuffer(ui8SceneDataBuffer, false);
            fprintf('\n\tSent %d bytes. Image requested. Waiting for data...\n', writtenBytes)

            % Wait for data reception from CORTOpy
            [~, recvDataBuffer, self] = self.ReadBuffer(); % TODO (PC) check endianness of recv
            % Cast data to double
            recvDataVector = typecast(recvDataBuffer, 'double');

            % Cast buffer to double and display image % TODO (PC): TBC if to keep here. May be moved to
            % acquireFrame of frontend algorithm branch?
            dImg = UnpackImageFromCORTO(recvDataVector);

        end
    end

    methods (Static, Access = public)
        % TODO (PC) make this function generic. Currently only for Milani NavCam!
        function dImg = UnpackImageFromCORTO(dImgBuffer, bApplyBayerFilter, bIsImageRGB)
            arguments
                dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
                bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
                bIsImageRGB         (1,1) logical {islogical, isscalar} = false;
            end


            if bIsImageRGB
                % Call external function
                dImg = UnpackImageFromCORTO_(dImgBuffer, bApplyBayerFilter);
            else
                % TODO (PC) You will need to modiy the input to the class/function 
                error('Not implemented yet. Requires size of camera to be known!')
            % dImg = zeros(1536, 2048, 3, 'uint8');

            end
        end

    end
    
    methods (Access = protected)
    % Internal implementations
        function dImgRGB = UnpackImageFromCORTO_(self, dImgBuffer, bApplyBayerFilter)
            arguments
                self                (1,1)
                dImgBuffer          (:,1) double {isvector, isnumeric, isa(dImgBuffer, 'double')}
                bApplyBayerFilter   (1,1) logical {islogical, isscalar} = false;
            end
            %% SIGNATURE
            % dImgRGB = UnpackImageFromCORTO(dImgBuffer, bApplyBayerFilter)%#codegen
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
                dImgRGB = self.ApplyBayerFilter(dImgRGB);
            end

        end
        
        % TODO (PC): rework these functions!
        function dImgBayer = ApplyBayerFilter(self, ImgRGB)
            % This function convert the RGB image of the environment into one generted
            % by the Milani NavCam with a 'bgrr' pattern

            dImgBayer = zeros(1536, 2048);

            % Generate the pattern of the bayer filter
            dBayerFilter = self.CreateBayerFilter(dImgBayer, 'bggr'); % NOTE (PC) remove this coding horror...

            % Sample the environment RGB image with a bayer filter
            dImgBayer = self.ApplyBayer_to_RGB(ImgRGB,dBayerFilter);

        end

        function [img_bayer] = ApplyBayer_to_RGB(RGB, BayerFilter)
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

        function [BayerFilter] = CreateBayerFilter(img_size,pattern)
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

    end % End of methods section



end
