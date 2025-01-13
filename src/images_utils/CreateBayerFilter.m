function [BayerFilter] = CreateBayerFilter(img_size,pattern)
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
%% I/O handling

res_x = size(img_size,2);
res_y = size(img_size,1);
BayerFilter = zeros(res_y,res_x,3);

%% Generate the BayerFilter tensor

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
