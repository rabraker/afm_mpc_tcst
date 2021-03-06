clear all


% Options
figbase  = 50;
verbose = 0;
controlParamName = 'exp01Controls.csv';
refTrajName      = 'ref_traj_track.csv';
outputDataName = 'exp01outputBOTH.csv';
% Build data paths

addpath(fullfile(PATHS.step_exp(), 'functions'));
addpath(fullfile(PATHS.step_exp(), 'functions' , 'canon'));
addpath(fullfile(PATHS.step_exp(), '/models'));
% PATH_sim_model       = pwd;  % for simulink simulations

% ---- Paths for shuffling data to labview and back. ------
%labview reads data here
controlDataPath = fullfile(PATHS.step_exp, controlParamName);
% labview saves experimental results/data here
data_out_path    = fullfile(PATHS.step_exp, outputDataName);
% labview reads desired trajectory here
refTrajPath     = fullfile(PATHS.step_exp, refTrajName);
% location of the vi which runs the experiment.

% folder into which to save results. Point
% process_settle_time_data.m here...
experiment_directory = ['many_steps_sweep_gamma', date, '_03'];
step_exp_root = fullfile(PATHS.exp, 'step-exps');
[status, message ] = mkdir(step_exp_root, experiment_directory);
save_root = fullfile(step_exp_root, experiment_directory);
%%
fprintf('\n\n\n\n')
TOL = 14/512; % max volts by pixels
% TOL = .01;
tol_mode = 'abs';
% which simulations to run

do_sim_lin = true;
do_sim_mpcfp = true;

plotstate = false;
plotpoles = false;
plotdriftpoles = false;
plotdriftbode = false;
saveon = false;

% We need four modes in this script:
% 1). Constant sigma, minimum-gamma 
% 2). Constant sigma, rob-optimal
% 3). Choose zeta, minimum-gamma
% 4). Choose zeta, rob-optimal
%
% For all cases, drift and hysteresis compensation remains
% unchanged. 

md = 1;
% !!!!!! These gamas should match the data in table II !!!!!!
if md == 1
  % 1). Constant sigma
  gam_lin_min = .5;
  gam_mpc_min = 0.5;
  gam_rob = 129.2;
%   gam_s = [gam_mpc_min, gam_lin_min, 40, 80, gam_rob, 200, 400];
  gam_s = [gam_mpc_min, gam_lin_min, 40, 80, gam_rob, 200, 300, 400, 600,];
%   gam_s = sort([20:20:40])
gam_s = linspace(2, 10, 40);
gam_s = [0.001, 7.5]
  exp_id_str = 'const-sig';
elseif md ==2
% 3). Choose zeta, minimum-gamma
  gam_lin_min = 2.5;
  gam_mpc_min = 0.2;
  gam_rob = 61.4;
%   gam_s = [  40, 80, gam_rob, 200, 300, 400, 600,];
  gam_s = unique([gam_mpc_min, gam_lin_min, gam_rob, [20:20:200]]);
  gam_s = linspace(2.6, 5, 40);
  exp_id_str = 'choose-zet';
end


% ------- Load Plants -----
[plants, frf_data] = CanonPlants.plants_ns14(9, 2);
Ts  = plants.SYS.Ts;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                  Design reference "trajectory"                          %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Get a ref trajectory to track.
N  = 800;
r1 =45.41/5;;
r2 = -7;
trajstyle = 4;
if trajstyle == 1
  step_ref = StepRef([r1], N);
  yref = step_ref.yref;
  yref.Data = yref.Data*1;
  step_descr = 'single_step';
elseif trajstyle == 2
  step_ref = StepRef([r1, r2], N);
  yref = step_ref.yref;
  yref.Data = yref.Data*1;
  step_descr = 'two_step';  
elseif trajstyle == 4
  step_root = fullfile(PATHS.exp, 'step-exps');
  load(fullfile(step_root, 'many_steps_data_rand_ymax7_n6p5.mat'), 'step_ref');
  yref = step_ref.yref;
  step_descr = 'many_steps_ymax7';
end
dist_traj = yref;
dist_traj.Data = dist_traj.Data*0 + .25*0;
rw = 2e-07;
rng(1);
thenoise = timeseries(mvnrnd(0, rw, length(yref.Time))*0, yref.Time);


F_yudu = figure(60); clf
subplot(3,1,1)
hold on, grid on;
step_ref.plot(F_yudu, '-k', 'LineWidth', 0.5);

F_y = figure(61); clf
hold on, grid on
if max(abs(yref.Data)) > 0
  step_ref.plot(F_y);
  step_ref.plot_settle_boundary(F_y, TOL, tol_mode);
  % legend([h1(1)])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
% Design control/estimator gains. This gains are what we actually         %
% use in both the simulation and experimentant system.                    %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 3). LQR generation gain.
% -------------------------------------------------------------------------
% -------------------- Constrained LQR Stuff ------------------------------

% Adjust the du_max to account for the gain of gdrift_inv.
du_max_orig = StageParams.du_max;
du_max = du_max_orig/norm(plants.gdrift_inv, Inf);

if md == 1 
  cmplx_rad = 0.9;
  [Q1, R0, S1, P_x] = build_control_constsigma(plants.sys_recyc, cmplx_rad);
elseif md ==2
  can_cntrl = CanonCntrlParams_ns14();
  % % % % can_cntrl = can_cntrl.aggressive_params();
  [Q1, R0, S1, P_x] = build_control(plants.sys_recyc, can_cntrl);
else
  error('expected md =(1|2) but recieved md = %d', md);
end

% ------------------------- Observer Gain ---------------------------------
can_obs_params = CanonObsParams_01();
can_obs_params.beta = 50;
[sys_obsDist, L_dist] = build_obs(plants.SYS, can_obs_params);

% 2). Design FeedForward gains.
[Nx, Nu] = SSTools.getNxNu(plants.sys_recyc);

% -------------------------------------------------------------------
% -------------------- Setup Fixed stuff -----------------------------
A_obs_cl = sys_obsDist.a - L_dist*sys_obsDist.c;

% -------------------- MPC Parameters -----------------------------
N_mpc = 22;
maxIter = 20;

% column spec: [gamma, lin_sim, mpc_sim]
ts_sum_sim_results = zeros(length(gam_s), 3); 

gams2 = linspace(gam_mpc_min, gam_lin_min+10, 30)
gams_sim = unique([gam_s, gams2]);
Fts = figure(100); clf; hold on;
%%
for idx_gam = 1:length(gam_s)
  
  gam_iter = gam_s(idx_gam);
  fprintf('===========================================================\n');
  fprintf('Starting simulations for gamma = %f\n', gam_iter);
  fprintf('===========================================================\n');
  clear sim_exp_fxpl sim_exp_fxpm afm_exp_mpc afm_exp_lin;
  
  ts_sum_sim_results(idx_gam, 1) = gam_iter;
  if gam_iter < gam_lin_min
    do_sim_lin = false;
    do_exp_lin = false;
  else
    do_sim_lin = true;
    do_exp_lin = true;
  end    
  
  K_lqr = dlqr(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_iter, S1);
  K_mpc = dlqr(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_iter, S1)*1;
  
  Qp = dare(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_iter, S1);
 
  if 1
    verbose = 0;
    analyze_margins(plants, sys_obsDist,  K_mpc, K_lqr, L_dist, verbose);
  end
  

  % --------------------  Floating point Linear stuff ---------------------
  if do_sim_lin
    sims_fpl = SimAFM(plants.PLANT, K_lqr, Nx, sys_obsDist, L_dist, du_max,...
      false,  'thenoise', thenoise);
    
    
    [y_fpl, U_full_fpl, U_nom_fpl, dU_fpl, Xhat_fpl] = sims_fpl.sim(yref, dist_traj);
    name = sprintf('FXP lin Sim. (%s)', exp_id_str);
    
    fxpl_Opts = stepExpDuOpts('pstyle', '-r', 'TOL', TOL, 'step_ref', step_ref,...
      'controller', K_lqr, 'name',  name);
    sim_exp_fpl = stepExpDu(y_fpl, U_full_fpl, dU_fpl, fxpl_Opts);
    Ts_vec_fpl = sim_exp_fpl.settle_time(TOL, tol_mode, 0);

    h2 = plot(sim_exp_fpl, F_yudu, 'umode', 'both');
    legend([h2(1)])
    figure(F_y)
    h22 = sim_exp_fpl.ploty(F_y);
    legend([h22]);
    
    try [~, F_state] = plotState(Xhat_fpl, F_state, [], [], '--r'); end

    ts_sum_sim_results(idx_gam, 2) = sum(Ts_vec_fpl);
  else
    ts_sum_sim_results(idx_gam, 2) = NaN;
  end
  
  figure(Fts)
  plot(gam_iter, ts_sum_sim_results(idx_gam, 2), 'x')
  hold on, grid on, drawnow()
  % --------------------------------------------------------------------- %
  % --------------------- MPC, fgm floating-point ----------------------- %
  if do_sim_mpcfp

    
    fgm_fp = FGMprob_1(plants.sys_recyc, N_mpc, Q1, Qp, R0+gam_iter, S1, du_max,...
      maxIter);
    fprintf('condition of H = %.1f\n', fgm_fp.kappa);
    %fgm_fp.ML = fi(fgm_fp.ML, 1, 32, 26);
    
    sims_fpm = SimAFM(plants.PLANT, fgm_fp, Nx, sys_obsDist, L_dist, du_max,...
      false, 'thenoise', thenoise);
  
    
    [y_fpm, U_full_fpm, U_nom_fpm, dU_fpm, Xhat_fpm, Xerr_fpm] = sims_fpm.sim(yref, dist_traj);
    name = sprintf('FP MPC Sim. (%s)', exp_id_str);
    fpm_Opts = stepExpDuOpts('pstyle', '--g', 'TOL', TOL, 'step_ref', step_ref,...
      'controller', fgm_fp, 'name',  name);
    
    sim_exp_fpm = stepExpDu(y_fpm, U_full_fpm, dU_fpm, fpm_Opts);
    
    h3 = plot(sim_exp_fpm, F_yudu, 'umode', 'both');
    
    try
      hand_vec = make_legend_vec(h2(1), h3(1));
      legend(hand_vec);
    end
   
    h32 = sim_exp_fpm.ploty(F_y);
    try
      legend(make_legend_vec(h22, h32));
    end
    
    Ts_vec_fpm = sim_exp_fpm.settle_time(TOL, tol_mode, 0);
    % fprintf('Total MPC FP settle-time = %.3f [ms]\n', sum(Ts_vec_fpm)*1000);
    
    figure(1000);
    hold on
    Ipow = lsim(plants.G_uz2powI, U_full_fpm.Data, U_full_fpm.Time);
    sim_exp_fpm.Ipow = timeseries(Ipow, U_full_fpm.Time);
    
    hmpc_Ipow = plot(U_full_fpm.Time, Ipow, '--g');
    hmpc_Ipow.DisplayName = 'MPC Current';
    
    fprintf('\n-------------------------------------------------\n')
    if do_sim_lin
      [ts_mat, names] = pretty_print_ts_data(TOL, tol_mode, sim_exp_fpl, sim_exp_fpm);
    else
      [ts_mat, names] = pretty_print_ts_data(TOL, tol_mode, sim_exp_fpm);
    end
    Ts_vec_fpm = sim_exp_fpm.settle_time(TOL, tol_mode, 0);
    ts_sum_sim_results(idx_gam, 3) = sum(Ts_vec_fpm);
    figure(Fts);
    plot(gam_iter, ts_sum_sim_results(idx_gam, 3), 'o')
  else
    ts_sum_sim_results(idx_gam, 3) = NaN;
  end

  if saveon
    gam_str = sprintf('_gam_%.2f', gam_iter);
    if do_sim_lin
    save(fullfile(save_root, [step_descr, '_linfp_sim_', exp_id_str, '_',...
      datestr(now, 'mm-dd-yyyy'), gam_str, '.mat']), 'sim_exp_fpl');
    end
    
    save(fullfile(save_root, [step_descr, '_mpcfp_sim_', exp_id_str, '_',...
      datestr(now, 'mm-dd-yyyy'), gam_str, '.mat']), 'sim_exp_fpm');
  end  
  
 
end

%%

num_observations = 5;
% column spec: [gamma, lin_exp, mpc_exp]
ts_sum_exp_results = zeros(length(gam_s), 3, num_observations); 
sims_fxpm.sys_obs_fp = sys_obsDist;
sims_fxpm.sys_obs_fp.a = sys_obsDist.a - L_dist*sys_obsDist.c;


traj_path = 'Z:\mpc-journal\step-exps\traj_data.csvtraj_data.csv';
for idx_observation = 1:num_observations
for idx_gam = 1:length(gam_s)
  gam_iter = gam_s(idx_gam);
  fprintf('===========================================================\n');
  fprintf('Starting Experiments for gamma = %f, observation=%d\n',...
    gam_iter, idx_observation);
  fprintf('===========================================================\n');
  clear afm_exp_mpc afm_exp_lin;
  
  
  ts_sum_exp_results(idx_gam, 1, idx_observation) = gam_iter;
  if gam_iter < gam_lin_min
    do_exp_lin = false;
  else
    do_exp_lin = true;
  end    
  
  K_lqr = dlqr(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_iter, S1);
  Qp = dare(plants.sys_recyc.a, plants.sys_recyc.b, Q1, R0+gam_iter, S1);
 
  fgm_fxp = FGMprob_fxp_1(plants.sys_recyc, N_mpc, Q1, Qp, R0+gam_iter, S1, du_max,...
    maxIter, nw_fgm, nf_fgm);
  %fgm_fxp.ML = fi(fgm_fp.ML, 1, 32, 26);
  fgm_fxp.x_nw = 32;
  fgm_fxp.x_nf = 27;
    
  % We have to rebuild these. This is a bit awkward, but i need the stuff
  % inside an instance of SimAFM, because a method there writes the control
  % data.
  K_fxp = fi(K_lqr, 1, nw,32-10);
  sims_fxpm = SimAFM(plants.PLANT, fgm_fxp, Nx_fxp, sys_obs_fxp, L_fxp, du_max_fxp,...
    true, 'nw', nw, 'nf', nf, 'thenoise', thenoise);
  sims_fxpl = SimAFM(plants.PLANT, K_fxp, Nx_fxp, sys_obs_fxp, L_fxp, du_max_fxp,...
    true, 'nw', nw, 'nf', nf, 'thenoise', thenoise);
  sims_fxpm.sys_obs_fp = sys_obsDist;
  sims_fxpm.sys_obs_fp.a = sys_obsDist.a - L_dist*sys_obsDist.c;
  sims_fxpl.sys_obs_fp = sys_obsDist;
  sims_fxpl.sys_obs_fp.a = sys_obsDist.a - L_dist*sys_obsDist.c;
  
  if do_exp_lin
    fprintf('------------ Running Linear Experiment, gamma = %.2f ----------------', gam_iter);
    %--------------------------------------------------------------------------
    % --------------------------- LINEAR Experiment ---------------------------
    
    % Build the u-reset.
    if 1
      dry_run = false;
      reset_piezo('t1', 15, 't_final', 25, 'umax', 9, 'k1', 0.55,...
        'verbose', false, 'dry_run', dry_run)
      fprintf('...finished running piezo-reset.\n')
    end

    fxplin_dat_path = 'Z:\mpc-journal\step-exps\LinControls01.csv';
    traj_path = 'Z:\mpc-journal\step-exps\traj_data.csv';
    sims_fxpl.write_control_data(fxplin_dat_path, yref, traj_path)
    
    SettleTicks = 20000;
    Iters = length(yref.Data)-1;

    % create and pack data. Then save it.
    [num, den] = tfdata(plants.gdrift_inv);
    num = num{1};
    den = den{1};
    
    umax = 11;
    ymax = max(yref.Data)*1.3;

    clear e;
    clear vi;
    % -----------------------RUN THE Experiment--------------------------------
    vipath =['C:\Users\arnold\Documents\matlab\afm_mpc_journal\',...
      'labview\fixed-point-host\play_FXP_AFMss_LinearDistEst_singleAxis.vi'];
    
    [e, vi] = setup_VI(vipath, false, 'SettleTicks', SettleTicks, 'Iters', Iters,...
      'num', num, 'den', den, 'TF Order', 1*(length(den)-1),...
      'r_s', plants.hyst_sat.rp, 'w_s', plants.hyst_sat.wp, 'N_hyst', 1*length(plants.hyst_sat.rp),...
      'sat_ds', plants.hyst_sat.dp, 'sat_ws', plants.hyst_sat.wsp, 'N_sat', 1*length(plants.hyst_sat.dp),...
      'du_max', du_max,'dry_run', false,...
      'read_file', true, 'umax', umax, 'ymax', ymax, 'outputDataPath', data_out_path,...
      'traj_path', traj_path, 'control_data_path', fxplin_dat_path);
    
    vi.Run
    
    
    % Now, read in data, and save to structure, and plot.
    [y_exp, ~, du_exp, ufull_exp, Ipow_exp, xhat_exp, yy] =  load_exp_data(data_out_path, sys_obsDist);
    
    expOpts = stepExpDuOpts('TOL', TOL, 'step_ref', step_ref, 'controller', K_lqr,...
      'pstyle', '-b', 'name', sprintf('AFM Stage (Linear) (%s)', exp_id_str));
    
    afm_exp_lin = stepExpDu(y_exp, ufull_exp, du_exp, expOpts);
    afm_exp_lin.Ipow = Ipow_exp;
    
    Ts_vec_afm_lin = afm_exp_lin.settle_time(TOL, tol_mode, 0);
    fprintf('Total AFM lin FXP settle-time = %.3f [ms]\n', sum(Ts_vec_afm_lin)*1000);
    
    H_linexp = plot(afm_exp_lin, F_yudu, 'umode', 'both');
    subplot(3,1,1)
    
    try; legend(make_legend_vec(h1(1), h2(1), h3(1), H_linexp(1), H_mpcexp(1) )); end;
    
    plot(y_exp.Time, yy, ':k')
    
    H_linexp2 = afm_exp_lin.ploty(F_y);
    
    try; legend(make_legend_vec(h12, h22, h32,  H_mpcexp2, H_linexp2 )); end;
   

    [ts_mat, names] = pretty_print_ts_data(TOL, tol_mode, afm_exp_lin);

    ts_sum_exp_results(idx_gam, 2, idx_observation) = sum(Ts_vec_afm_lin);
  else
    ts_sum_exp_results(idx_gam, 2, idx_observation) = NaN;
  end
  
  %--------------------------------------------------------------------------
  % -------------- MPC Experiment -------------------------------------------
  fprintf('------------ Running MPC Experiment, gamma = %.2f ----------------', gam_iter);
  
  if 1 % Build the u-reset.
    dry_run = false;
    reset_piezo('t1', 15, 't_final', 25, 'umax', 9, 'k1', 0.55,...
      'verbose', false, 'dry_run', dry_run);
     fprintf('...finished running piezo-reset.\n')
  end
  
  if ispc & do_sim_mpcfxp
    mpc_dat_path = 'Z:\mpc-journal\step-exps\MPCControls01.csv';
    sims_fxpm.write_control_data(mpc_dat_path, yref, traj_path)
  end
  
  SettleTicks = 20000;
  Iters = length(yref.Data)-1;
  % create and pack data. Then save it.
  
  [num, den] = tfdata(plants.gdrift_inv);
  num = num{1};
  den = den{1};
  
  umax = 10.3;
  ymax = max(yref.Data)*1.3;
  clear e;
  clear vi;
  % -----------------------RUN THE Experiment--------------------------------
  vipath =['C:\Users\arnold\Documents\MATLAB\afm_mpc_journal',...
    '\labview\fixed-point-host\play_FXP_AFMss_MPC_distEst_singleAxisN22.vi'];
  if 1
    [e, vi] = setup_VI(vipath, false, 'SettleTicks', SettleTicks, 'Iters', Iters,...
      'num', num, 'den', den, 'TF Order', 1*(length(den)-1),...
      'r_s', plants.hyst_sat.rp, 'w_s', plants.hyst_sat.wp, 'N_hyst', 1*length(plants.hyst_sat.rp),...
      'sat_ds', plants.hyst_sat.dp, 'sat_ws', plants.hyst_sat.wsp, 'N_sat', 1*length(plants.hyst_sat.dp),...
      'du_max', du_max,'dry_run', false,...
      'umax', umax, 'ymax', ymax, 'outputDataPath', data_out_path,...
      'traj_path', traj_path, 'control_data_path', mpc_dat_path);
  end
  vi.Run
  
  ticks_bench = vi.GetControlValue('Loop Ticks (benchmark)');
  fprintf('Actual loop ticks: %d\n', ticks_bench);
  % Now, read in data, and save to structure, and plot.
  [y_exp, ~, du_exp, ufull_exp, Ipow_exp, xhat_exp, yy] =  load_exp_data(data_out_path, sys_obsDist);
   
  expOpts = stepExpDuOpts('TOL', TOL, 'step_ref', step_ref, 'controller', fgm_fxp,...
    'pstyle', '--m', 'name', sprintf('AFM Stage (MPC, %s), ', exp_id_str));
  
  afm_exp_mpc = stepExpDu(y_exp, ufull_exp, du_exp, expOpts);
  afm_exp_mpc.Ipow = Ipow_exp;
  

  Ts_vec_afm_mpc = afm_exp_mpc.settle_time(TOL, tol_mode, 1);
  fprintf('Total AFM mpc FXP settle-time = %.3f [ms]\n', sum(Ts_vec_afm_mpc)*1000);

  
  H_mpcexp = plot(afm_exp_mpc, F_yudu, 'umode', 'both');
  try;  legend( make_legend_vec(h1(1), h2(1), h3(1),  H_mpcexp(1) )); end;
  subplot(3,1,1)
  plot(y_exp.Time, yy, ':k')
  
  H_mpcexp2 = afm_exp_mpc.ploty(F_y);
  
  try; legend(make_legend_vec(h12, h22, h32, H_mpcexp2)); end;
  
  fprintf('Max of experimental Xhat = %.2f\n', max(abs(xhat_exp.data(:))));
  
  % Pretty print.
  if do_sim_lin && do_exp_lin
    [ts_mat, names] = pretty_print_ts_data(TOL, tol_mode, afm_exp_lin, afm_exp_mpc);
  else
    [ts_mat, names] = pretty_print_ts_data(TOL, tol_mode, afm_exp_mpc);
  end
  ts_sum_exp_results(idx_gam, 3, idx_observation) = sum(Ts_vec_afm_mpc);

  % -------------- End MPC Experiment -----------------------------------
  if saveon
    gam_str = sprintf('_gam_%.2f', gam_iter);
    obs_id_str = sprintf('_obsID_%d', idx_observation);
    
    if do_exp_lin
    save(fullfile(save_root, [step_descr, '_lin_EXP_', exp_id_str, '_',...
      datestr(now, 'mm-dd-yyyy'), gam_str, obs_id_str, '.mat']), 'afm_exp_lin')    
    end
    
    save(fullfile(save_root, [step_descr, '_mpc_EXP_', exp_id_str, '_',...
      datestr(now, 'mm-dd-yyyy'), gam_str, obs_id_str, '.mat']), 'afm_exp_mpc');
  end  
  
  ts_mat_tmp = [ts_sum_sim_results(1:idx_gam, 2:end),...
               ts_sum_exp_results(1:idx_gam, 2:end, idx_observation)]*1000;
  [ts_sum_sim_results(1:idx_gam, 1) ts_mat_tmp]
end
end

ts_sum_exp_results(:,2:end,:)*1000
%
save(fullfile(save_root, ['ts_total', exp_id_str, '_',...
  datestr(now, 'mm-dd-yyyy'), '.mat']), 'ts_sum_sim_results', 'ts_sum_exp_results');

%%
function handle_vec =  make_legend_vec(varargin)
  
%   handle_vec = gobjects();
handle_vec = [];
  for k = 1:length(varargin)
    hand = varargin{k};
    if isvalid(hand)
      handle_vec = [handle_vec, hand];
    end
  end
  
end


function [y, u, du, ufull, Ipow, xhat, yhat] =  load_exp_data(data_out_path, sys_obsDist)
  Ts = sys_obsDist.Ts;
  AFMdata = csvread(data_out_path);

  t_exp = (0:size(AFMdata,1)-1)'*Ts;
  y = timeseries(AFMdata(:,1), t_exp);
  u = timeseries(AFMdata(:, 2), t_exp);
  du = timeseries(AFMdata(:,3), t_exp);
  ufull = timeseries(AFMdata(:,4), t_exp);
  
  Ipow = timeseries(AFMdata(:,5), t_exp);
  xhat = timeseries(AFMdata(:,6:end), t_exp);
  yhat = xhat.Data*sys_obsDist.c';
  
  
end

function analyze_margins(plants, sys_obsDist,  K_mpc, K_lqr, L_dist, verbose)
    [Sens, Hyd, Hyr, Hyeta, Loop] = ss_loops_delta_dist(plants.SYS, plants.sys_recyc,...
    sys_obsDist, K_lqr, L_dist);
  [Sens_mpc, Hyd_mpc, Hyr_mpc, Hyeta_mpc, Loop_mpc] = ss_loops_delta_dist(plants.SYS,...
    plants.sys_recyc, sys_obsDist, K_mpc, L_dist);
  
  
  F_clbode = figure(25);clf; hold on, grid on
  Hbode_sens = bodeplot(Sens, Sens_mpc);
  setoptions(Hbode_sens, 'FreqUnits', 'Hz')
  legend('S: linear', 'S: mpc')
  grid on, hold on;
  
 
  [Gm_lin, Pm_lin] = margin(Loop);
  [Gm_mpc, Pm_mpc] = margin(Loop_mpc);
  fprintf('-------- MARGINS ------------------\n')
  fprintf('Linear: GM = %.2f [], PM = %.2f [deg]\n', Gm_lin, Pm_lin)
  fprintf('MPC: GM = %.2f [], PM = %.2f [deg]\n', Gm_mpc, Pm_mpc)

  if verbose >=2  
    figure(101)
    rlocus(Loop);
    title('Klin')
    
    
    figure(102);
    rlocus(Loop_mpc);
    title('Kmpc')
  end
  if verbose >=1
    figure(103)
    nyquist(Loop_mpc)
    title('Kmpc')
    xlim([-2, .1])
    ylim([-1, 1])
    
    figure(104)
    nyquist(Loop)
    title('Klin')
    xlim([-2, 0.1])
    ylim([-1, 1])
  end
  
  
end


