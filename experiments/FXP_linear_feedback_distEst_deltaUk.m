clc
clear all
%  close all

% Options
figbase  = 50;
verbose = 0;
controlParamName = 'exp01Controls.csv';
refTrajName      = 'ref_traj_track.csv';
outputDataName = 'exp01outputBOTH.csv';
% Build data paths

addpath('../functions')
% PATH_sim_model       = pwd;  % for simulink simulations

% ---- Paths for shuffling data to labview and back. ------
%labview reads data here
controlDataPath = fullfile(PATHS.step_exp, controlParamName);
% labview saves experimental results/data here
dataOut_path    = fullfile(PATHS.step_exp, outputDataName);
% labview reads desired trajectory here
refTrajPath     = fullfile(PATHS.step_exp, refTrajName);
% location of the vi which runs the experiment.

% ---------- Load Parametric Models  -----------
% load(fullfile(PATHS.sysid, 'hysteresis/steps_hyst_model.mat'));
% load(fullfile(PATHS.sysid, 'FRF_data_current_stage2.mat'))
% r = r;
% w = theta_hyst;

umax = 5;

TOL = .01;

%%
% close all
md = 1;
% --------------- Load Plants -------------------
clear CanonPlants
with_hyst = true;
if 0
plants2 = CanonPlants.plants_drift_inv_hyst_sat();
plants = CanonPlants.plants_with_drift_inv(with_hyst);
else
plants = CanonPlants.plants_drift_inv_hyst_sat();
plants2 = CanonPlants.plants_with_drift_inv(with_hyst);
plants.gdrift = plants2.gdrift;
plants.gdrift_inv = 1/plants.gdrift;
end  
plants = CanonPlants.plants_ns14();
plants2 = CanonPlants.plants_drift_inv_hyst_sat();
gd2 = plants2.gdrift;
gd1 = plants.gdrift;
gd  = gd2 * dcgain(gd1)/dcgain(gd2);
plants.gdrift = gd;
plants.gdrift_inv = 1/gd;
figure
pzplot(plants.SYS, plants2.SYS)
%%
% plants2 = CanonPlants.plants_with_drift_inv(with_hyst);
% gd1 = plants.gdrift;
% gd2 = plants2.gdrift;
% gd = gd2*dcgain(gd1)/dcgain(gd2);
% plants.gdrift = gd;
% plants.gdrift_inv = 1/gd;

%
Ts  = plants.SYS.Ts;
if md == 2
  plants.gdrift = zpk([], [], 1, Ts);
  plants.gdrift_inv = zpk([], [], 1, Ts);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                  Design reference "trajectory"                          %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get a ref trajectory to track.
N    = 800;
r1 = 7.5;
r2 = -7.5;
trajstyle =4;
if trajstyle == 1
  yref = CanonRefTraj.ref_traj_1(r1, N);
elseif trajstyle == 2
    yref = CanonRefTraj.ref_traj_2(r1, r2, N);
elseif trajstyle == 3
  yref = CanonRefTraj.ref_traj_load('many_steps.mat');
elseif trajstyle == 4
  yref = CanonRefTraj.ref_traj_load('many_steps_rand.mat');
elseif trajstyle == 5
  yref = load('many_steps_data_rand_ymax7.mat');
  yref = yref.ref_traj_params.ref_traj;
end
rw = 8.508757290909093e-08;
rng(1);
thenoise = timeseries(mvnrnd(0, rw, length(yref.Time)), yref.Time);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
% Design control/estimator gains. This gains are what we actually         %
% use in both the simulation and experimentant system.                    %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% -------------------------------------------------------------------------
% -------------------- Constrained LQR Stuff ------------------------------
% du_max   = StageParams.du_max;
 du_max = StageParams.du_max/norm(plants.gdrift_inv, Inf)
 
% Pull out open-loop pole-zero information.
can_cntrl = CanonCntrlParams_ns14(plants.SYS);
% can_cntrl = CanonCntrlParams_01(plants.SYS);
[Q1, R0, S1] = build_control(plants.sys_recyc, can_cntrl);
gam_lin = 5;
gam_mpc = 0.5;
R1 = R0 + gam_mpc;

K_lqr = dlqr(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_lin, S1);
sys_cl = SSTools.close_loop(plants.sys_recyc, K_lqr);
if 1
    f10 = figure(10); clf
    pzplotCL(sys_cl, K_lqr, [], f10);
end

% -------------------------------------------------------------------------
% ------------------------- Observer Gain ---------------------------------

can_obs_params = CanonObsParams_01();
[sys_obsDist, L_dist] = build_obs(plants.SYS, can_obs_params);
if 1
    figure(20); clf
    pzplot(plants.PLANT);
    title('observer')
    hold on
    opts.pcolor = 'r';
    pzplotCL(sys_obsDist, [], L_dist, gcf, opts);
end

% 2). Design FeedForward gains.
[Nx, Nu] = SSTools.getNxNu(plants.sys_recyc);

isfxp = false;
sims_fpl = SimAFM(plants.PLANT, K_lqr, Nx, sys_obsDist, L_dist, du_max, false,...
           'thenoise', thenoise);
if 1
  sims_fpl.r = plants.hyst_sat.r;
  sims_fpl.w = plants.hyst_sat.w;
  sims_fpl.rp = plants.hyst_sat.rp;
  sims_fpl.wp = plants.hyst_sat.wp;
  sims_fpl.gdrift_inv = plants.gdrift_inv;
  sims_fpl.gdrift = plants.gdrift;
  sims_fpl.d = plants.hyst_sat.d;
  sims_fpl.ws = plants.hyst_sat.ws;
  sims_fpl.dp = plants.hyst_sat.dp;
  sims_fpl.wsp = plants.hyst_sat.wsp;
end

[y_lin_fp_sim, U_full_fp_sim, U_nom_fp_sim, dU_fp_sim, Xhat_fp] = sims_fpl.sim(yref);

linOpts = stepExpOpts('pstyle', '-r', 'TOL', TOL, 'y_ref', yref.Data(1),...
                      'controller', K_lqr, 'name',  'Simulation');

sim_exp = stepExpDu(y_lin_fp_sim, U_full_fp_sim, dU_fp_sim, linOpts);

F1 = figure(59); clf
h1 = plot(sim_exp, F1);
subplot(3,1,1)
plot(yref.time, yref.Data, '--k', 'LineWidth', .05);
xlm = xlim();

F61 = figure(61); clf
plotState(Xhat_fp, F61);

% -------------------- Setup Fixed stuff -----------------------------

A_obs_cl = sys_obsDist.a - L_dist*sys_obsDist.c;
fprintf('A_cl needs n_int = %d\n', ceil(log2(max(max(abs(A_obs_cl))))) + 1)
fprintf('L needs n_int = %d\n', ceil(log2(max(abs(L_dist)))) + 1)
fprintf('Nx needs n_int = %d\n', ceil(log2(max(abs(Nx)))) + 1)
fprintf('K needs n_int = %d\n', ceil(log2(max(abs(K_lqr)))) + 1)
fprintf('B needs n_int = %d\n', ceil(log2(max(abs(sys_obsDist.b))))+2)

nw = 32;
nf = 26;

du_max_fxp = fi(du_max, 1, 32, 26);
K_fxp = fi(K_lqr, 1, nw,32-10);
Nx_fxp = fi(Nx, 1, 32, 30);
L_fxp = fi(L_dist, 1, 32, 30);

sys_obs_fxp.a = fi(sys_obsDist.a -L_dist*sys_obsDist.c, 1, nw, nw-7);
sys_obs_fxp.b = fi(sys_obsDist.b, 1, nw, 29);
sys_obs_fxp.c = fi(sys_obsDist.c, 1, nw, 28);

% --------------------  Fixed Linear stuff -----------------------------

sims_fxpl = SimAFM(plants.PLANT, K_fxp, Nx_fxp, sys_obs_fxp, L_fxp, du_max_fxp,...
  true, 'nw', nw, 'nf', nf, 'thenoise', thenoise);

sims_fxpl.r = plants.hyst_sat.r;
sims_fxpl.w = plants.hyst_sat.w;
sims_fxpl.rp = fi(plants.hyst_sat.rp, 1, 16, 11);
sims_fxpl.wp = fi(plants.hyst_sat.wp, 1, 16, 11);
sims_fxpl.d = plants.hyst_sat.d;
sims_fxpl.ws = plants.hyst_sat.ws;
sims_fxpl.dp = fi(plants.hyst_sat.dp, 1, 16, 11);
sims_fxpl.wsp = fi(plants.hyst_sat.wsp, 1, 16, 11);

sims_fxpl.gdrift_inv = plants.gdrift_inv;
sims_fxpl.gdrift = plants.gdrift;

[y_fxpl, U_full_fxpl, U_nom_fxpl, dU_fxpl, Xhat_fxpl] = sims_fxpl.sim(yref);
fxpl_Opts = stepExpOpts('pstyle', '--k', 'TOL', TOL, 'y_ref', r1,...
                      'controller', K_lqr, 'name',  'FXP lin Sim.');
sim_exp_fxpl = stepExpDu(y_fxpl, U_full_fxpl, dU_fxpl, fxpl_Opts);

h2 = plot(sim_exp_fxpl, F1, 'umode', 'both');
legend([h1(1), h2(1)])
%
fprintf('Max of U_nom = %.2f\n', max(U_nom_fxpl.Data));
fprintf('Max of U_full = %.2f\n', max(U_full_fxpl.Data));

[~, F61] = plotState(Xhat_fxpl, F61, [], [], '--');
fprintf('max of Xhat = %.2f\n', max(abs(Xhat_fxpl.Data(:))));



sims_fxpl.sys_obs_fp = sys_obsDist;
sims_fxpl.sys_obs_fp.a = sys_obsDist.a - L_dist*sys_obsDist.c;

fxplin_dat_path = 'Z:\mpc-journal\step-exps\FXP_lin_Controls01.csv';
traj_path = 'Z:\mpc-journal\step-exps\traj_data.csv';
sims_fxpl.write_control_data(fxplin_dat_path, yref, traj_path)
%----------------------------------------------------
% Build the u-reset.
return
%%
if 1
  dry_run = false;
  reset_piezo('t1', 15, 't_final', 25, 'umax', 9, 'k1', 0.55,...
            'verbose', true, 'dry_run', dry_run)
end
%%
% Save the controller to .csv file for implementation
clear vi; clear e;
% delay before we start tracking, to let any transients out. Somewhere of a
% debugging setting.
SettleTicks = 20000;
Iters = length(yref.Data)-1;

Iters = min(Iters, length(yref.Data)-1);
% Iters = 300;


[num, den] = tfdata(plants.gdrift_inv);
num = num{1};
den = den{1};

umax = 7;
ymax = max(yref.Data)*1.3
% ymax = 0.5;
clear e;
clear vi;
% -----------------------RUN THE Experiment--------------------------------
vipath =['C:\Users\arnold\Documents\matlab\afm_mpc_journal\',...
  'labview\fixed-point-host\play_FXP_AFMss_LinearDistEst_singleAxis.vi'];

if 1
[e, vi] = setupVI(vipath, 'SettleTicks', SettleTicks, 'Iters', Iters,...
   'num', num, 'den', den, 'TF Order', (length(den)-1),...
   'r_s', plants.hyst_sat.rp, 'w_s', plants.hyst_sat.wp, 'N_hyst', 1*length(plants.hyst_sat.rp),...
   'sat_ds', plants.hyst_sat.dp, 'sat_ws', plants.hyst_sat.wsp, 'N_sat', 1*length(plants.hyst_sat.dp),...
   'du_max', du_max,'dry_run', false,...
   'read_file', true, 'umax', umax, 'ymax', ymax, 'outputDataPath', dataOut_path,...
   'traj_path', traj_path, 'control_data_path', fxplin_dat_path);
else
[e, vi] = setupVI(vipath, 'SettleTicks', SettleTicks, 'Iters', Iters,...
   'num', num, 'den', den, 'TF Order', (length(den)-1),...
   'r_s', plants.hyst.rp, 'w_s', plants.hyst.wp, 'N_hyst', 1*length(plants.hyst.rp),...
   'du_max', du_max,'dry_run', false,...
   'read_file', true, 'umax', umax, 'ymax', ymax, 'outputDataPath', dataOut_path,...
   'traj_path', traj_path, 'control_data_path', fxplin_dat_path);
  
end
vi.Run
% -------------------------------------------------------------------------
%
% Now, read in data, and save to structure, and plot.
% AFMdata = csvread(dataOut_path);
AFMdata = vi.GetControlValue('result_data');

t_exp = (0:size(AFMdata,1)-1)'*Ts;
y_exp = timeseries(AFMdata(:,1), t_exp);
u_exp = timeseries(AFMdata(:, 2), t_exp);
du_exp = timeseries(AFMdata(:,3), t_exp);
ufull_exp = timeseries(AFMdata(:,4), t_exp);

Ipow_exp = timeseries(AFMdata(:,5), t_exp);
xhat_exp = timeseries(AFMdata(:,6:end), t_exp);
yy = xhat_exp.Data*sys_obsDist.c';

expOpts = stepExpOpts(linOpts, 'pstyle', '--m', 'name',  'AFM Stage');

afm_exp = stepExpDu(y_exp, ufull_exp, du_exp, expOpts);
H2 = plot(afm_exp, F1);
subplot(3,1,1)
plot(y_exp.Time, yy, ':k')
subplot(3,1,2)

% plot(u_exp.Time, u_exp.data, '--b')

figure(1000); clf
plot(Ipow_exp.Time, (Ipow_exp.Data/15)*1000)
ylabel('current [mA]')
grid on
title('Current')
%%
% save('many_steps_data/many_steps_fxplin_noinv.mat', 'y_exp', 'u_exp',...
%   'du_exp', 'ufull_exp', 'Ipow_exp', 'yref', 'y_lin_fp_sim')

experiment_directory = ['many_steps_data_rand_', date, '_01'];
step_exp_root = fullfile(PATHS.exp, 'step-exps');
save_root = fullfile(step_exp_root, experiment_directory);
[status, message ] = mkdir(step_exp_root, experiment_directory);

save(fullfile(save_root, 'many_steps_linfxp_invHystinvSatinvDrift_ns14.mat'), 'y_exp', 'u_exp',...
  'du_exp', 'Ipow_exp')

% save('many_steps_data/many_steps_fxplin_invHystDrift.mat', 'y_exp', 'u_exp',...
%   'du_exp', 'ufull_exp', 'Ipow_exp', 'yref', 'y_lin_fp_sim')


% save('many_steps_data/many_steps_rand_fxplin_invHystDrift.mat', 'y_exp', 'u_exp',...
%   'du_exp', 'ufull_exp', 'Ipow_exp', 'yref', 'y_lin_fp_sim')






















