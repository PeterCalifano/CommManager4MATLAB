function [outArray] = ConverHexDump2Array(stringHexDump, dtype)
arguments
    stringHexDump   (1,:) string {isvector}
    dtype           (1,1) string = 'double'
end

% Combine into a single string and split into individual bytes
hexBytes = split(strjoin(stringHexDump), " ");

% Convert hex strings to numerical values
byteArray = uint8(hex2dec(hexBytes));

% Display the byte array
disp(byteArray);

outArray = typecast(byteArray', dtype);
end
