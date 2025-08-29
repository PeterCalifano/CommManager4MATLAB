
%% tmux probing
sess = 'tmux_probe';
system(sprintf('tmux kill-session -t %s 2>/dev/null', sess));   % clean slate
system(sprintf('tmux new-session -d -s %s 2>&1', sess));        % just create

% Send a trivial command and a marker that we can capture
system(sprintf('tmux send-keys -t %s "echo TMUX_OK; uname -a; sleep 1; echo DONE" C-m', sess));
pause(1.0);
[~, pane_out] = system(sprintf('tmux capture-pane -pt %s:0 2>&1', sess));
disp(pane_out);

return

%% Server start test
sess   = 'bpy30007_render';
script_dir = '/home/peterc/devDir/rendering-sw/corto_PeterCdev/server_api';
blend  = '/home/peterc/devDir/projects-DART/data/rcs-1/phase-C/blender/Apophis_RGB.blend';
iface  = '/home/peterc/devDir/rendering-sw/corto_PeterCdev/server_api/BlenderPy_UDP_TCP_interface_withCaching.py';
logf   = ['/tmp/' sess '.log'];

system(sprintf('tmux kill-session -t %s 2>/dev/null', sess));
system(sprintf('tmux new-session -d -s %s 2>&1', sess));

% Use a *login* bash, cd into the script folder, and exec your script.
% All stdout/stderr goes to /tmp/<sess>.log so you can read errors.
runline = sprintf( ...
  'exec bash -lc ''cd "%s"; exec bash ./StartBlenderServer.sh -m "%s" -p "%s"'' >"%s" 2>&1', ...
  script_dir, blend, iface, logf);

disp(runline);  % sanity
system(sprintf('tmux send-keys -t %s "%s" C-m', sess, runline));

pause(1.0);
[~, pane_out] = system(sprintf('tmux capture-pane -pt %s:0 2>&1', sess));
disp(pane_out);
type(logf);  % show any errors from the script/Blender
