% I want to investigate methods to increase the condition number of the
% Hessian

% Build up the correct model from what is saved from sysID. Ie, put the
% thing in a 
clear
clc
close all
addpath('functions')
addpath('models')

volts2mu = 1;
TOL = 0.01;
trun = 800*40e-6;
ref_f = 2;
ref_0 = 0;
umax = 5;

clc
fname_lin = fullfile(PATHS.sim_data(), 'max_sp_data_lin_dumax_p198.mat');
fname_mpc = fullfile(PATHS.sim_data(),'max_sp_data_mpc_dumax_p198.mat');
fname_clqr = fullfile(PATHS.sim_data(),'clqr_ref_data__dumax_p198.mat');
fname_timeopt = fullfile(PATHS.sim_data(),'timeopt_ref_data_dumax_p198.mat');

matpath           = getMatPath();
dataroot          = fullfile(matpath, 'afm_mpc_journal', 'modelFitting', 'pow_amp');
expName           = 'FRF_data_current_stage2';
modFitName    = [expName, '.mat'];
modFitPath    = fullfile(dataroot, modFitName);
load(modFitPath, 'modelFit')
sys = ss(modelFit.models.G_uz2stage);

% dataroot          = fullfile(matpath, 'AFM_SS', 'System_Identification', 'data','data_xaxis');
% expName           = '22-Jun-2016_exp01';
% modFitName    = [expName, '.mat'];
% modFitPath    = fullfile(dataroot, modFitName);
% load(modFitPath, 'modelFit')
% sys = ltiFit(modFitPath, 'SS02').sys;


sys.Inputdelay = 8;
Nd =  sys.InputDelay;
sys_nodelay = sys;
sys_nodelay.InputDelay = 0;

sys = absorbDelay(sys);
Ts = sys.Ts;
PLANT = sys;


volts2mu = 1;
TOL = 0.01;
trun = 800*Ts;
ref_f = 2;
ref_0 = 0;
umax = 5;


[uss_0, uss_f, ~, ~, xss]  = yss2uss(PLANT, ref_f, 0);
dcgain_sys = 1/(PLANT.c*xss);
x0 = xss*0;


% 3). LQR generation gain.
% -------------------------------------------------------------------------
% -------------------- Constrained LQR Stuff ------------------------------
du_max   = StageParams.du_max;

% Pull out open-loop pole-zero information.
[wp_real_x, wz_real_x] = w_zp_real(sys);
rho_1 = wz_real_x(1)/wp_real_x(1);
rhos_x = [rho_1, 1., 1];
pint_x = .8;

zeta_x = [.8, .7, .4, .542 .4 ];
gams_x = [1., 1., 1., 1., 1];

rad = 0.25;


[Gvib, gdrift] = eject_gdrift(sys_nodelay);
Gvib = ss(Gvib);
sys_recyc=SSTools.deltaUkSys(Gvib);
sys_recyc.InputDelay = Nd;
sys_recyc = absorbDelay(sys_recyc);

P_x    = getCharDes(sys_recyc, gams_x, pint_x, zeta_x, rhos_x, rad);
[Chat, Dhat] = place_zeros(sys_recyc, P_x);
gam = .00000000011;
Q1 = Chat'*Chat;
S1 = Chat'*Dhat;
R1 = Dhat'*Dhat + gam; % Plus gamma.
K_lqr = dlqr(sys_recyc.a, sys_recyc.b, Q1, R1, S1);

sys_cl = SSTools.close_loop(sys_recyc, K_lqr);

% % % % Inverse LQR actually seems to work if we use mosek instead of sedumi.
% % % px = getCharDes(sys_nodelay, gams_x, pint_x, zeta_x, rhos_x, rad);
% % % K_temp = place(sys_nodelay.a, sys_nodelay.b, px);
% % % [Q0, R0, K_lqr2] = inverseLQR(sys_nodelay, K_temp, 'mosek');
% % % % Q0 = blkdiag(Q0, zeros(Nd, Nd));
% % %
% % % K_lqr2 = dlqr(sys_nodelay.a, sys_nodelay.b, Q0, R0);
% % % sys_cl2 = SSTools.close_loop(sys_nodelay, K_lqr2);
% % %
% % % figure(200); clf
% % % pzplot(sys_cl, sys_cl2)
% % % hold on
% % % plot(real(px), imag(px), 's')

%

figure(2); clf
[y,t,x] = step(sys_cl, 800*Ts);
subplot(2,1,1)
plot(t,y)
grid on

subplot(2,1,2)
plot(t, (x*K_lqr'))
grid on

f3 = figure(3); clf

plot(real(P_x), imag(P_x), 'ob')
hold on
% [ax, C_hand] = lqr_locus(sys_recyc, Q1, 1, S1, .001, 1000);
% C_hand.Label.Interpreter = 'latex';
% C_hand.Label.FontSize = 14;
% C_hand.Location = 'eastoutside';
% C_hand.Position = [0.8406    0.1121    0.0473    0.8715];
% ax.Position =  [0.0862 0.1123 0.7369 0.8713];
% C_hand.Label.String = '$\gamma$';
% C_hand.Label.Units = 'normalized';
% C_hand.Label.Rotation = 0;
% C_hand.Label.Position = [2.5214    0.5549         0];
% 
% xlim([-0.3, 1])
% ylim([-0.35, 0.35])
% C_hand.Label.String = '$R_o + \gamma$';
% 
% xlabel('Re')
% ylabel('Im')
% 
% 
% if 0
%   saveas(f3, fullfile(PATHS.jfig, 'lqr_locus.svg'))
% end


% ------------------ Linear + delU Saturation Case ---------------------- %
% Iterate over a bunch of gammas and try to find the maximum setpoint for
% each one. This code is pretty niave. We start at a very low setpoint and
% slowly increase the setpoint until the settling time is reported as NaN.
% A bisection search would probably be faster. This is complicated though
% by the fact that instability seems to occur in the "middle": if the
% setpoint is large enough, we dont have the stability problem, which is
% weird.
% ref_s = linspace(0.01, 15, 200);


%%
clc
% *Optimal, open-loop* trajectory generation over all setpoints. This
% provides the basiline for comparison of the other methods.
% ref_s = [1.5];

gamma = 2;
gam_s = linspace(gamma, 100, 50);
% gam_s = [1, 100, 1000, 2500, 5000, 10000];
ref_s = 0.1:0.5:11.5;


N_mpc_s = [4, 8, 12, 16, 20]; % original
% N_mpc_s = [12, 18, 24];
N_traj =800;
trun = Ts*N_traj;

clear StepDataMPC
%
logfile = sprintf('logs/log-lin-mpc-parfor_judge_dynamic_%s.log', date);
LG = EchoFile(logfile);
logger = @LG.echo_file;
logger = @fprintf;
ProgBar = @(max_iter, varargin)ProgressBarFile(max_iter, varargin{:}, 'logger', logger);
%
% warning('ON', 'MATLAB:mir_warning_maybe_uninitialized_temporary');
step_params_lin = StepParamsLin(sys_recyc, ref_s, du_max,Q1, gam_s, PLANT, trun);
step_data_lin = StepDataLin(step_params_lin, 'savedata', true,...
    'file', fname_lin', 'logger', logger,...
    'Progbar', ProgBar);

step_params_mpc = StepParamsMPC(sys_recyc, ref_s, du_max,Q1, gam_s, PLANT,...
                    trun, N_mpc_s,'condensed');
step_data_mpc = StepDataMPC(step_params_mpc, 'savedata', true,...
    'file', fname_mpc', 'logger', logger,...
    'Progbar', ProgBar);


% step_params_timeopt = StepParamsTimeOpt(sys, ref_s, du_max, sys_nodelay, 10);
step_params_clqr  = StepParamsCLQR(sys_recyc, ref_s, du_max,Q1, gamma, PLANT, N_traj, 'condensed');
step_data_clqr = StepDataCLQR(step_params_clqr, 'savedata', true,...
    'file', fname_clqr);

step_params_timeopt = StepParamsTimeOpt(sys_recyc, ref_s, du_max, sys_nodelay, Nd);
step_data_timeopt = StepDataTimeOpt(step_params_timeopt, 'savedata', true,...
    'file', fname_timeopt);
% ======================================================================= %
%                                                                         %
%                        BUILD TRAJECTORIES                               %
%                                                                         %
% ======================================================================= %

% ------------- Generate/Load CLQR max Trajectories --------------------- %
step_data_timeopt = step_data_timeopt.build_timeopt_trajs('force', 0,...
                    'verbose', 3, 'max_iter', 50);

                
% ------------- Generate/Load CLQR max Trajectories --------------------- %
tic
try
    step_data_clqr = build_clqr_trajs(step_data_clqr, 'force', 0, 'verbose', 1);
    logger('Finished building clqr_data. Total time = %.2f\n', toc);
catch ME
    errMsg = getReport(ME, 'extended', 'hyperlinks', 'off');
    logger('Failed to build clqr_data: \n%s', errMsg);
    fprintf('Failed to build clqr_data: \n%s', errMsg);
end

% ------------- Generate LIN max setpoints ------------------------------ %
threshold = 125; % percent
Judge = MaxSpJudgeCLQR(step_data_clqr, threshold);

try
    step_data_lin.max_ref_judge = Judge;
    step_data_lin = step_data_lin.build_max_setpoints('force', 0, 'verbose', 2);
    
    logger('Finished building max setpoints, linear. Total time = %.2f\n\n', toc);
catch ME
    errMsg = getReport(ME, 'extended', 'hyperlinks', 'off');
     logger('Failed to build max setpoints, linear: \n\n%s', errMsg);
     fprintf('Failed to build max setpoints, linear: \n\n%s', errMsg);
 end

% ---------------------- Generate  mpc max setpoints -------------------- %

tic
try
    step_data_mpc.max_ref_judge = Judge;
    step_data_mpc = step_data_mpc.build_max_setpoints('force', 0, 'verbose', 1);
   logger('Finished building max setpoints, mpc. Total time = %.2f\n\n', toc);
catch ME
    errMsg = getReport(ME,  'extended','hyperlinks', 'off');
    logger('Failed to build max setpoints, mpc: %s\n\n', errMsg); 
    fprintf('Failed to build max setpoints, mpc: %s\n\n', errMsg); 
end

%%
% expose variables for plotting.


ref_s = step_data_clqr.params.ref_s;
gam_s = step_data_clqr.params.gam_s;
ref_s_to = step_data_timeopt.params.ref_s;


F200=figure(200);clf; hold on;
colrs =  get(gca, 'colororder');
ax = gca;

hcl = step_data_clqr.plot_ref_vs_settle(ax,[], 'LineWidth', 2);
hto = step_data_timeopt.plot_ref_vs_settle(ax, 'LineWidth', 2);
legend([hcl, hto]);
grid on
saveon = 0;
%
if saveon
    saveas(F200, 'latex/figures/clqrTimeOpt_sp_vs_ts_CCTA_dumaxp6.svg')
end
%
% ----------------- Plot maximum reference vs gamma -----------------------
F10 = figure(10); clf; hold on;
colrs =  get(gca, 'colororder');
hands_mxsp = []
hands_mxsp(1) = plot(step_data_lin.params.gam_s, step_data_lin.results{1}.max_setpoints,...
                     '-', 'Color', colrs(1, :),...
            'LineWidth', 2);
set(hands_mxsp(1), 'DisplayName', 'LQR Lin + Sat');        
for k = 1:length(step_data_mpc.params.N_mpc_s)

    hands_mxsp(k+1) = plot(step_data_mpc.params.gam_s, step_data_mpc.results{k}.max_setpoints,...
                       '-', 'Color', colrs(k+1, :), 'LineWidth', 2);

    stit = sprintf('MPC, N=%.0f', step_data_mpc.params.N_mpc_s(k));
    set(hands_mxsp(k+1), 'DisplayName', stit);
end
leg1 = legend(hands_mxsp);
set(leg1, 'Position', [0.6775 0.4829 0.2181 0.2213]);

xlabel('$\gamma$', 'interpreter', 'latex', 'FontSize', 14);
ylabel('Max Ref', 'interpreter', 'latex', 'FontSize', 14);
grid on
if saveon
    saveas(F10, 'latex/figures/maxref_vs_gamma_dumaxp6.svg')
end

%%
% ======================================================================= %
%                                                                         %
% ------------------Settle-By-Maximum-Acheivable-Reference -------------- %
%                                                                         %
% ======================================================================= %

% ---------------------------- For MPC ---------------------------------- %
rmax_s = [1, 2.5, 5.0, 10];
for jj = 1:length(N_mpc_s)
    N_mpc = N_mpc_s(jj);
    F=figure(300 + jj);clf; hold on;
    colrs =  get(gca, 'colororder');
    ax = gca;

    
    hto = step_data_timeopt.plot_ref_vs_settle(ax, 'LineWidth', 2,...
                            'Color', colrs(1, :));
    hcl = step_data_clqr.plot_ref_vs_settle(ax,[], 'LineWidth', 2,...
                         'Color', colrs(2, :));
    hands = [hcl; hto];

    
    for kk = 1:length(rmax_s)
        step_data_mpc = step_data_mpc.ts_by_ref_max(rmax_s(kk), jj);
        figure(F);
        [~, h] = step_data_mpc.plot_ts_by_ref_max_judge(rmax_s(kk),...
                       jj, ax, 'LineWidth', 1.25, 'Color', colrs(kk + 2,:));
        hands = [hands; h];
    end
    title(sprintf('N = %.0f', N_mpc))
    legend(hands);
end

% ------------------------- For LINEAR ---------------------------------- %
clc
F=figure(300);clf; hold on;
colrs =  get(gca, 'colororder');
ax = gca;
hto = step_data_timeopt.plot_ref_vs_settle(ax, 'LineWidth', 2,...
                        'Color', colrs(1, :));
hcl = step_data_clqr.plot_ref_vs_settle(ax,[], 'LineWidth', 2,...
                     'Color', colrs(2, :));
hands = [hcl; hto];
for kk = 1:length(rmax_s)
    step_data_lin = step_data_lin.ts_by_ref_max(rmax_s(kk), 1);
    figure(F)
    [~, h] = step_data_lin.plot_ts_by_ref_max_judge(rmax_s(kk),...
                   [], ax, 'LineWidth', 1.25, 'Color', colrs(kk + 2,:));
    hands = [hands; h];
end
legend(hands);
title('Linear')


%
% ======================================================================= %
%                                                                         %
%               Settle Time Percent Increase over time-Optimal            %
%                       by-Maximum-Acheivable-Reference                   %
%                                                                         %
% ======================================================================= %
clear StepDataCLQR
ts_timeopt = step_data_timeopt.results.settle_times_opt_cell{1};

% -----------------------CLQR vs Time-Optimal---------------------------- %
F = figure(399);
ax = gca();
step_data_clqr.plot_ts_perc_increase_by_rmax(1, ts_timeopt, ax);
title('CLQR')


%%% plot(ref_s(kref), (ts_mpc/ts_clqr)*100, 'xk')
% ------------------------- For LINEAR ---------------------------------- %
clc
clear StepDataQuad
F=figure(400);clf; hold on;
ax = gca();

hands = [];
for kk = 1:length(rmax_s)
    figure(F)
    step_data_lin = step_data_lin.ts_by_ref_max(rmax_s(kk), 1);
    [~, h] = step_data_lin.plot_ts_perc_increase_by_rmax(rmax_s(kk),...
                   1, ts_timeopt, ax, 'LineWidth', 1.25, 'Color', colrs(kk, :));
    hands = [hands; h];

end
title('Linear (Percent Increase)')
legend(hands)

for jj = 1:length(N_mpc_s)
    N_mpc = N_mpc_s(jj);
    F=figure(400 + jj);clf; hold on;
    colrs =  get(gca, 'colororder');
    ax = gca;

    hands = [];
    
    for kk = 1:length(rmax_s)
        step_data_mpc = step_data_mpc.ts_by_ref_max(rmax_s(kk), jj);
        figure(F);
        [~, h] = step_data_mpc.plot_ts_perc_increase_by_rmax(rmax_s(kk),...
                       jj, ts_timeopt, ax, 'LineWidth', 1.25, 'Color', colrs(kk + 2,:));
        hands = [hands; h];
    end
    title(sprintf('N = %.0f (Percent Increase)', N_mpc))
    legend(hands);
    grid on; zoom on;
end
%
clc
clear StepDataCLQR
clear StepDataQuad
for kk = 1:length(rmax_s)
    
   F = figure(500 + kk); clf; hold on;
   ax = gca();
   hands = [];
   
   % CLQR: this guy doesn't change, no need to regenerate.
   [~, h] = step_data_clqr.plot_ts_perc_increase_by_rmax(1, ts_timeopt, ax, 'Color', colrs(1, :));
   h.DisplayName = 'CLQR';
   hands = [hands;h];
   
   
   % -- Linear
   step_data_lin = step_data_lin.ts_by_ref_max(rmax_s(kk), 1);
   [~, h] = step_data_lin.plot_ts_perc_increase_by_rmax(rmax_s(kk),...
                   1, ts_timeopt, ax, 'LineWidth', 1.5, 'Color', colrs(2, :));
   h.DisplayName = sprintf('Linear ($\\gamma = %.0f$)', step_data_lin.ts_by_rmax_results{1}.gamma);
   hands = [hands;h];
   
   step_data_mpc.ts_by_rmax_results = {};
   for jj = 1:length(N_mpc_s)
        step_data_mpc = step_data_mpc.ts_by_ref_max(rmax_s(kk), jj);
        figure(F);
        [~, h] = step_data_mpc.plot_ts_perc_increase_by_rmax(rmax_s(kk),...
                       jj, ts_timeopt, ax, 'LineWidth', 1.5, 'Color', colrs(jj + 2,:));
        h.DisplayName = sprintf('MPC ($N=%.0f$ $\\gamma = %.0f$', N_mpc_s(jj),...
                        step_data_mpc.ts_by_rmax_results{jj}.gamma);
        hands = [hands; h];
    end
   
   legend(hands)
   title(sprintf('r-max = %.2f', rmax_s(kk)));
    
end
%%
tilefigs(1)
%%

figure(10)
xlm = xlim;
h1 = plot(xlm, [rmax_s', rmax_s'], ':k', 'LineWidth', 2)
if saveon+1
    saveas(F10, 'latex/figures/maxref_vs_gamma_dumaxp6.svg')
end


%%

figure(504)
grid on
xlim([0, 10])
saveas(gcf, 'latex/figures/perc_increase_rmax10.svg')


figure(503)
grid on
xlim([0, 5])
saveas(gcf, 'latex/figures/perc_increase_rmax5.svg')

figure(502)
grid on
xlim([0, 2.5])
saveas(gcf, 'latex/figures/perc_increase_rmax2p5.svg')




%%
% group0 =  [figure(300), figure(301), figure(302), figure(303), figure(304),...
%           figure(305)];
% tilefigs([1], group0);
% %%
% group1 = [figure(400), figure(401), figure(402), figure(403), figure(404),...
%           figure(405)];
% tilefigs(2, group1)      


group2 = [figure(501), figure(502),figure(503),figure(504)];      
tilefigs(3, group2);




