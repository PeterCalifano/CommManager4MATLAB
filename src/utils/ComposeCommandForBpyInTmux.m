function [charStartBlenderCommand, bHasTmux] = ComposeCommandForBpyInTmux(charStartBlenderCommand, ui32ServerPort)
arguments
    charStartBlenderCommand
ui32ServerPort (1,1) uint32 = 30001
end

bHasTmux = false;
try
    [~, bHasTmux] = system("command -v tmux >/dev/null 2>&1 && echo 1 || echo 0");
    bHasTmux = logical(bHasTmux);
catch
end

if bHasTmux
    charStartBlenderCommand = strcat(charStartBlenderCommand, " -k"); % Add "keep" flag
    % Wrap command around tmux shell
    charStartBlenderCommand = char(sprintf("tmux new-session -d -s %s '%s; exec bash' & echo $!",...
        strcat("bpy_", num2str(ui32ServerPort), "_render"), charStartBlenderCommand)) ;
end

end

