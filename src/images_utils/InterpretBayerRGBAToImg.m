function [dImgBayesFiltered] = InterpretRawBufferToImg(varImgPackage, ...
                                                    ui32Height, ...
                                                    ui32Width)%#codegen
arguments
    varImgPackage   (1,:) {isnumeric, isfinite}
    ui32Height      (1,1) uint32 = 1536
    ui32Width       (1,1) uint32 = 2048
end

% Enforce constness
% ui32Height = coder.const(ui32Height);
% ui32Width  = coder.const(ui32Width );

% Init output array
dImgBayesFiltered = zeros(ui32Height, ui32Width);

% Unpack 1D buffer to RGB array
dArrayRGB = UnpackBufferRGBAtoArrayRGB(varImgPackage, ...
                                    ui32Height, ...
                                    ui32Width);

% Generate the pattern of the bayer filter
dBayerFilterKernel = CreateBayerFilter([ui32Width, ui32Height], 'bggr');

% Sample the environment RGB image with a bayer filter
dImgBayesFiltered(:,:) = ApplyBayer_to_RGB(dArrayRGB, dBayerFilterKernel);

end

