function [] = CheckExistsTmuxSession(charTmuxSessionName)
arguments
    charTmuxSessionName (1,:) char {mustBeText}
end
% Function to detect if tmux window with same name is already opened

% Check if tmux session already exists
charTmuxHasSessionCmd = sprintf('tmux has-session -t %s > /dev/null 2>&1', charTmuxSessionName);
[ui32TmuxStatusTmp, ~] = system(charTmuxHasSessionCmd);

if ui32TmuxStatusTmp == 0
    % Session exists: ask user what to do
    fprintf(2, 'A tmux session named "%s" is already running.\n', charTmuxSessionName);

    bKillSession = false;
    while true
        charUserAnswer = input('Kill existing session and continue? [y/N]: ', 's');
        charUserAnswer = strtrim(lower(charUserAnswer));

        if isempty(charUserAnswer) || any(charUserAnswer == "n")
            % Default: do not kill
            error('tmux session "%s" already exists. Aborting as per default behaviour.', ...
                charTmuxSessionName);
        elseif any(charUserAnswer == "y")
            bKillSession(1) = true;
            break;
        else
            fprintf('Invalid answer. Please enter y or n.\n');
        end
    end


    if bKillSession
        charTmuxKillCmd = sprintf('tmux kill-session -t %s', charTmuxSessionName);
        [ui32KillStatusTmp, charKillOutTmp] = system(charTmuxKillCmd);
        charKillOutTmp = strtrim(charKillOutTmp);
        if ui32KillStatusTmp ~= 0
            error('Failed to kill existing tmux session "%s". tmux return: %s', charTmuxSessionName, charKillOutTmp);
        end
    end

end

