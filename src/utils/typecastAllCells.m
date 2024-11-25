function [castedDataCell] = typecastAllCells(dataCell)
    arguments
        dataCell cell 
    end
%% PROTOTYPE
% [castedDataCell] = typecastAllCells(dataCell)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% dataCell
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% castedDataCell
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 15-06-2024        Pietro Califano         Function coded
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

castedDataCell = cell(length(dataCell), 1);

for idE = 1:length(dataCell)

    if not(isa(dataCell{idE}, 'double'))
        % Integer number: cast to uint32 first
        dataCell{idE} = uint32(dataCell{idE});
    end

    tmpCastedData = typecast(dataCell{idE}, 'uint8');

    if not(isrow(tmpCastedData))
        tmpCastedData = tmpCastedData';
    end
    castedDataCell{idE} = tmpCastedData;
end

end
