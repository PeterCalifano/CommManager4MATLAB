function [outputArg1,outputArg2] = LoadDataRCS1(charTrajKernelName)
arguments
charTrajKernelName (1, :) char {mustBeMember(charTrajKernelName, ["SSTO_14", "SSTO_12", "SSTO_08", ""])}

end


% Call user environment configuration script
run("LoadUserConfig.m");


if strcmpi(string(usrname(1:end-1)), "peterc") % For Windows, use this "hostname\username" format
    kernel_folder = 'kernels';
    traj_kernel_folder = fullfile(kernel_folder, 'trajectories');
    mk_file =  'kernels.tm';
end

abskpath = strcat(Kernels_path, kernel_folder);
absktrajpath = strcat(Kernels_path, traj_kernel_folder);

curr_dir = pwd;
cd(abskpath)
cspice_furnsh(mk_file)

fprintf('\nMetakernel loaded succesfully.\n')

cd(absktrajpath)
trajectory = 6;

switch charTrajKernelName
    case 1
        cspice_furnsh SSTO_14.bsp

        traj_str = 'SSTO-14';
        et0 = cspice_str2et('01 Apr 2029 00:00:00 UTC');
        etEnd = cspice_str2et('10 Apr 2029 23:58:00 UTC');
    
    case 2

        cspice_furnsh SSTO_12.bsp
        traj_str = 'SSTO-12';
        et0 = cspice_str2et('01 Apr 2029 00:00:00 UTC');
        etEnd = cspice_str2et('10 Apr 2029 23:58:00 UTC');
    case 3
        cspice_furnsh SSTO_08.bsp
        traj_str = 'SSTO-08';
        et0 = cspice_str2et('01 Apr 2029 00:00:00 UTC');
        etEnd = cspice_str2et('10 Apr 2029 23:58:00 UTC');
    case 4 
        cspice_furnsh SSTO_06.bsp
        traj_str = 'SSTO-06';
        et0 = cspice_str2et('01 Apr 2029 00:00:00 UTC');
        etEnd = cspice_str2et('10 Apr 2029 23:58:00 UTC');
    case 5
        cspice_furnsh SSTO_1.bsp
        traj_str = 'SSTO-1';
        et0 = cspice_str2et('01 Apr 2029 00:00:00 UTC');
        etEnd = cspice_str2et('10 Apr 2029 23:58:00 UTC');
    case 6
        cspice_furnsh RTO_4t1_j11p0.bsp
        traj_str = 'RTO-4t1j11p0';
        et0 = cspice_str2et('01 Feb 2029 00:00:00 UTC');
        etEnd = cspice_str2et('13 Feb 2029 00:20:33 UTC');
    case 7
        cspice_furnsh RTO_3t1_j11p0.bsp
        traj_str = 'RTO-3t1j11p0';
        et0 = cspice_str2et('01 Feb 2029 00:00:00 UTC');
        etEnd = cspice_str2et('12 Feb 2029 15:14:00 UTC');
    case 8
        cspice_furnsh RTO_3t1_j6p5.bsp
        traj_str = 'RTO-3t1j6p5';
        et0 = cspice_str2et('01 Feb 2029 00:00:00 UTC');
        etEnd = cspice_str2et('11 Feb 2029 05:32:00 UTC');
end
cd(curr_dir)

% Check loaded kernels
num_kernels = cspice_ktotal('ALL'); % Get the total number of loaded kernels
fprintf('Number of loaded kernels: %d\n', num_kernels);

%% Camera parameters

cam.f_mm = 12.96; %[mm]
cam.px_size = [2.2 2.2]; %[µm]
cam.res = [2048, 1536]; 
cam.fov_u = 19.72; %[deg]
cam.fov_v = 14.86; %[deg]

f_px_u = cam.f_mm / (cam.px_size(1)*1e-3);
f_px_v = cam.f_mm / (cam.px_size(2)*1e-3);

%% Trajectories

% time vector
etStep = 60; % [s] one hour
etVec = et0:etStep:etEnd;

% Sun to Apophis vector
xx_s2a = cspice_spkezr('20099942', etVec,'SUN_APOPHIS','NONE','SUN');
rr_s2a = xx_s2a(1:3,:); 
rr_a2s_dir = -rr_s2a/norm(rr_s2a);
% Sun to Earth vector
xx_s2e = cspice_spkezr('EARTH', etVec,'SUN_APOPHIS','NONE','SUN');
rr_s2e = xx_s2e(1:3,:); 
% Earth to spacecraft vector
xx_e2sc = cspice_spkezr('-19920605', etVec,'SUN_APOPHIS','NONE','EARTH');
rr_e2sc = xx_e2sc(1:3,:); 

% Compute Earth to Apophis vector
rr_e2a = rr_s2a - rr_s2e;
% Compute Apophis to spacecraft vector
rr_a2sc = rr_e2sc - rr_e2a;
rr_a2sc_dir = rr_a2sc/norm(rr_a2sc);

% Compute Apophis to spacecraft in Sun fixed
xx_a2sc_SunFixed = cspice_spkezr('-19920605', etVec, 'SUN_APOPHIS', 'NONE', 'APOPHIS');
rr_a2sc_SunFixed = xx_a2sc_SunFixed(1:3,:);
% Verify equivalence with xx_a2sc
err = rr_a2sc_SunFixed - rr_a2sc;
if max(vecnorm(err)) > 1e-7 
    fprintf('Not the same')
end

% Apophis to spacecraft in Apophis fixed
xx_a2sc_ApoFixed = cspice_spkezr('-19920605', etVec, 'APOPHIS_FIXED', 'NONE', 'APOPHIS');
rr_a2sc_ApoFixed = xx_a2sc_ApoFixed(1:3,:);
% Apophis to Sun in Apophis fixed
xx_a2s_ApoFixed = cspice_spkezr('SUN', etVec, 'APOPHIS_FIXED', 'NONE', 'APOPHIS');
rr_a2s_ApoFixed = xx_a2s_ApoFixed(1:3,:);


end

