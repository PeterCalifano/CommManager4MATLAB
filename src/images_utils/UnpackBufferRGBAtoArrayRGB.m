function dImgRGB = UnpackBufferRGBAtoArrayRGB(varImgPackage, ...
                                            ui32Height, ...
                                            ui32Width)%#codegen
arguments
    varImgPackage (1,:) {isnumeric, isfinite}
    ui32Height (1,1) uint32 = 1536
    ui32Width  (1,1) uint32 = 2048
end
% This function unpack the ImgPackage vector from Blender and put it out as
% an RGB matrix.

dImgRGB = zeros(ui32Height, ui32Width, 3);

% Decompose the ImgPackage in the 4 RGBA channels
dR = double(varImgPackage(1:4:end));
dG = double(varImgPackage(2:4:end));
dB = double(varImgPackage(3:4:end));

% Reshape the RGB channels as matrix
dR = (flip(reshape(dR', ui32Width, ui32Height), 2))';
dG = (flip(reshape(dG', ui32Width, ui32Height), 2))';
dB = (flip(reshape(dB', ui32Width, ui32Height), 2))';

% Compose the RGB tensor
dImgRGB(:,:,1) = dR;
dImgRGB(:,:,2) = dG;
dImgRGB(:,:,3) = dB;

end
