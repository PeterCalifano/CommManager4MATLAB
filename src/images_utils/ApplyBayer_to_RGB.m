function [dImgBayerFiltered] = ApplyBayer_to_RGB(dImageRGB, dBayerFilter)
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
%% I/O handling
dImgBayerFiltered = zeros(size(dImageRGB,1), size(dImageRGB,2), 'double');

%% Generate the img_bayer matrix 
dImgBayerFiltered(:,:) = double(sum(double(dImageRGB).*double(dBayerFilter),3));

end
