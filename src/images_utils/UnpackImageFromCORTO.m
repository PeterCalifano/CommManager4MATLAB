function dImgRGB = UnpackImageFromCORTO(dImgBuffer, bApplyBayerFilter)%#codegen
arguments
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
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% First author: Milani GNC Team (M. Pugliatti, A. Rizza, F. Piccolo) for milani-gnc prototype
% 13-01-2025    Pietro Califano     Adapted from legacy code of milani-gnc
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------

% This function unpack the ImgPackage vector from Blender and put it out as an RGB matrix. 

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
    dImgRGB = ApplyBayerFilter(dImgRGB);
end

%% LOCAL FUNCTIONS
    function dImgBayer = ApplyBayerFilter(ImgRGB)
        % This function convert the RGB image of the environment into one generted
        % by the Milani NavCam with a 'bgrr' pattern

        dImgBayer = zeros(1536,2048);

        % Generate the pattern of the bayer filter
        dBayerFilter = CreateBayerFilter(dImgBayer,'bggr');

        % Sample the environment RGB image with a bayer filter
        sBW = ApplyBayer_to_RGB(ImgRGB,dBayerFilter);

        %Output handling
        dImgBayer = sBW;

    end

    function [img_bayer] = ApplyBayer_to_RGB(RGB,BayerFilter)
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
            fprintf('\n Not implemented yet \n')
        end
    end


end
