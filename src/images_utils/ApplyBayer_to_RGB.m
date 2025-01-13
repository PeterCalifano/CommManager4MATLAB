function [img_bayer] = ApplyBayer_to_RGB(RGB,BayerFilter)
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
img_bayer = double(zeros(size(RGB,1),size(RGB,2)));

%% Generate the img_bayer matrix 
img_bayer = double(sum(double(RGB).*double(BayerFilter),3));

end