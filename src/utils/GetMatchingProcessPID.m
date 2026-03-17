function ui32Pid = GetMatchingProcessPID(charTargetRelativePath, ui32ExistingPIDs, kwargs) %#codegen
arguments
    charTargetRelativePath      (1,:) char
    ui32ExistingPIDs            (1,:) uint32 = uint32(0)
end
arguments
    kwargs.charProcessName (1,:) char= 'blender'
end
%% SIGNATURE
% ui32Pid = GetMatchingProcessPID(charTargetRelativePath, ui32ExistingPIDs, kwargs) %#codegen
% ------------------------------------------------------------------------------
% DESCRIPTION
% Return the PID (as uint32) of a process (default 'blender') whose command-line
% contains the substring charTargetRelativePath. PIDs listed in ui32ExistingPIDs
% are excluded from consideration. The function invokes 'pgrep -a' on
% Unix-like systems and parses each line to extract the PID. Designed to be
% robust for use in scripts and to be compatible with MATLAB Coder where possible.
% ------------------------------------------------------------------------------
% INPUT
%   charTargetRelativePath  (1,:) char
%       Substring to search for within a process command line.
%   ui32ExistingPIDs        (1,:) uint32, optional (default uint32(0))
%       Array of PIDs to ignore. Zero entries are ignored.
%   kwargs.charProcessName  (1,:) char, optional (default 'blender')
%       Process name to pass to pgrep (e.g., 'blender', 'python').
% ------------------------------------------------------------------------------
% OUTPUT
%   ui32Pid  uint32
%       PID of the first matching process not in ui32ExistingPIDs.
%       Returns 0 when no suitable process is found or on error.
% ------------------------------------------------------------------------------
% EXAMPLE
%   % Find a blender process that references a particular .blend path, ignoring PID 1234
%   pid = GetMatchingProcessPID('projects/myproj/scene.blend', uint32(1234), ...
%       struct('charProcessName','blender'));
% ------------------------------------------------------------------------------
% NOTES
% - This function relies on the availability of 'pgrep' on the host system.
% - The function filters out any ui32ExistingPIDs equal to 0.
% - The first non-excluded matching PID is returned.
% ------------------------------------------------------------------------------
% CHANGELOG
%   2025-11-17  Pietro Califano     Updated and expanded documentation.
% ------------------------------------------------------------------------------

%% INITIALIZATION
ui32Pid = uint32(0);

ui32ValidPIDs = ui32ExistingPIDs(ui32ExistingPIDs ~= uint32(0));
dValidPIDs = double(ui32ValidPIDs); % Conversion once

%% QUERY RUNNING BLENDER PROCESSES
[ui32SysStatus, charSysOut] = system(sprintf('pgrep -a %s', kwargs.charProcessName));

if ui32SysStatus ~= 0
    warning("GetMatchingProcessPID:SystemCallFailed", ...
        "System call to get process list failed with status %d.", ui32SysStatus);
    return;
end

charSysOut = strtrim(charSysOut);
if isempty(charSysOut)
    return;
end

%% SPLIT LINES
cellLines = regexp(charSysOut, '\r?\n', 'split');

% Filter only lines containing the target substring
cellHits = cellLines( contains(string(cellLines), string(charTargetRelativePath)) );
if isempty(cellHits)
    return;
end

%% EXTRACT PID (FIRST NON-MATCHING PID)
for ui32Idx = 1:numel(cellHits)
    charLine = cellHits{ui32Idx};

    % Extract numeric PID at beginning of line
    cellTokens = regexp(charLine, '^\s*(\d+)\s+', 'tokens', 'once');
    if isempty(cellTokens)
        continue;
    end

    dPidTmp = str2double(cellTokens{1});
    if isnan(dPidTmp)
        continue;
    end

    if ~ismember(dPidTmp, dValidPIDs)
        ui32Pid = uint32(dPidTmp);
        return;
    end
end

if ui32Pid == 0
    warning("GetMatchingProcessPID:NoNonMatchingPID", ...
        "All matching processes are in the existing PID list or none found.");
end

end