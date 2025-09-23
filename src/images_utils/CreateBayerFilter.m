function [dBayerFilter] = CreateBayerFilter(ui32ImgSize, charPattern)%#codegen
arguments
    ui32ImgSize (1,2) uint32 {isnumeric} % [Width, Height]
    charPattern (1,:) char
end
% This function is used to create a BayerFilter logic array that mimic the
% pattern of a bayer filter
%
%   INPUT:  
%           img_size: an empty matrix with the size of the desired
%           pattern [n x m](-)
%           pattern: pattern of the bayer filter listed as [1,2;3,4]
%
%   OUTPUT:
%           BayerFilter: a logic tensor which identify the R,G,B pixels [n x m x 3](-) 
%
%% I/O handling
ui32ResX = ui32ImgSize(1); % Width
ui32ResY = ui32ImgSize(2); % Height

dBayerFilter = zeros(ui32ResY, ui32ResX, 3);

%% Generate the BayerFilter tensor
assert(strcmpi(charPattern, 'bggr'), 'ERROR: only bggr pattern is supported.');

if strcmpi(charPattern, 'bggr')
    for ii = 1:1:ui32ResY
        if mod(ii,2) == 0
            j0 = 1;
        else
            j0 = 2;
        end
        for jj = j0:2:ui32ResX
            dBayerFilter(ii,jj,2) = 1;
        end
    end

    for ii = 1:2:ui32ResY
        for jj = 1:2:ui32ResX
            dBayerFilter(ii,jj,3) = 1;
        end
    end

    for ii = 2:2:ui32ResY
        for jj = 2:2:ui32ResX
            dBayerFilter(ii,jj,1) = 1;
        end
    end
end

end
