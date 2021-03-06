% This script processes the output data from a sequence of step
% inputs from different experiments (MPC, linear, PID etc) and
% calculates settle-time for each step. The settle-times for each
% experiment are built up into a latex table and saved to a file. 

clear, clc
saveon = true;
TOL = 14/512;
tol_mode = 'abs';
verbose = 0;

addpath(fullfile(getMatPath(), 'afm_mpc_journal', 'functions'))
% where the different experiments are stored.

% Reference Data 
load(fullfile(PATHS.exp, 'step-exps', 'many_steps_data_rand_ymax7.mat'))
% reft_pi = load(fullfile(root, 'many_steps_rand.mat'))

whos

Fig = figure(1000); clf
step_ref.yscaling = 5;
step_ref.plot(Fig);
step_ref.plot_settle_boundary(Fig, TOL, tol_mode);

%%

% ----------------------------------------------------------------
% --------- Load Constant sigma data --------- -------------------
% root_CS = fullfile(PATHS.exp, 'step-exps', 'many_steps_data_rand_17-Jul-2018_01');
% files_const_sig = {
% 'many_steps_ymax7_linfxp_sim_const-sig-min-gam_07-17-2018.mat',...
% 'many_steps_ymax7_mpcfxp_sim_const-sig-min-gam_07-17-2018.mat',...
% 'many_steps_ymax7_linfxp_sim_const-sig-rob-opt_07-17-2018.mat',...  
% 'many_steps_ymax7_mpcfxp_sim_const-sig-rob-opt_07-17-2018.mat',...
% 'many_steps_ymax7_lin_EXP_const-sig-min-gam_07-17-2018.mat',...
% 'many_steps_ymax7_mpc_EXP_const-sig-min-gam_07-17-2018.mat',...
% 'many_steps_ymax7_lin_EXP_const-sig-rob-opt_07-17-2018.mat',...
% 'many_steps_ymax7_mpc_EXP_const-sig-rob-opt_07-17-2018.mat'};

root_CS = fullfile(PATHS.exp, 'step-exps', 'many_steps_data_rand_30-Jul-2018_01');
files_const_sig = {
'many_steps_ymax7_linfxp_sim_const-sig-min-gam_07-30-2018.mat',...
'many_steps_ymax7_mpcfxp_sim_const-sig-min-gam_07-30-2018.mat',...
'many_steps_ymax7_linfxp_sim_const-sig-rob-opt_07-30-2018.mat',...  
'many_steps_ymax7_mpcfxp_sim_const-sig-rob-opt_07-30-2018.mat',...
'many_steps_ymax7_lin_EXP_const-sig-min-gam_07-30-2018.mat',...
'many_steps_ymax7_mpc_EXP_const-sig-min-gam_07-30-2018.mat',...
'many_steps_ymax7_lin_EXP_const-sig-rob-opt_07-30-2018.mat',...
'many_steps_ymax7_mpc_EXP_const-sig-rob-opt_07-30-2018.mat'};

% names_const_sig_rob_opt = {'LS-CSMG','MPCS-CSMG',...
%                            'LS-CSRO','MPCS-CSRO',...
%                            'LE-CSMG', 'MPCE-CSMG',...
%                             'LE-CSRO', 'MPCE-CSRO'};
names_const_sig_rob_opt = {'SLF-CS-MG','MPC-CS-MG',...
                           'SLF-CS-RG','MPC-CS-RG',...
                           'SLF-CS-MG', 'MPC-CS-MG',...
                            'SLF-CS-RG', 'MPC-CS-RG'};

 
% clrs = {[0    0.4470    0.7410],...
%     [0.8500    0.3250    0.0980],...
%     [0.9290    0.6940    0.1250],...
%       [0.4940    0.1840    0.5560],...};
clrs = {'b', 'r', 'g', 'k', 'b', 'r', 'g', 'k'}    ;
line_styles = {'-', '--', '-', '--','-', '--','-', '--','-', '--','-', '--','-', '--'};

step_exps_CS_cell = cell(1, length(names_const_sig_rob_opt));
for k=1:length(names_const_sig_rob_opt)
  dat = load(fullfile(root_CS, files_const_sig{k}));
  exp_name_str = fields(dat);
  exp_name_str = exp_name_str{1};
  dat = dat.(exp_name_str);
  
  dat.Ipow = dat.Ipow * 1000/15.15;
  dat.yscaling = 5;
  dat.yunits = '[$\mu$m]';

  dat.name = names_const_sig_rob_opt{k};
  dat.Color = clrs{k};
  dat.LineStyle = line_styles{k};
  step_exps_CS_cell{k} = dat;

end

step_exps_CS = ManyStepExps(TOL, tol_mode, step_ref, step_exps_CS_cell{:});
% -------------------------------------------------------------------------
% ------------- Load Choose-zeta data -------------------------------------
% root_CZ = fullfile(PATHS.exp, 'step-exps', 'many_steps_data_rand_18-Jul-2018_01');
% files_choose_zet = {
% 'many_steps_ymax7_linfxp_sim_choose-zet-min-gam_07-18-2018.mat',...
% 'many_steps_ymax7_mpcfxp_sim_choose-zet-min-gam_07-18-2018.mat',...
% 'many_steps_ymax7_linfxp_sim_choose-zet-rob-opt_07-18-2018.mat',...
% 'many_steps_ymax7_mpcfxp_sim_choose-zet-rob-opt_07-18-2018.mat',...
% 'many_steps_ymax7_lin_EXP_choose-zet-min-gam_07-18-2018.mat',...
% 'many_steps_ymax7_mpc_EXP_choose-zet-min-gam_07-18-2018.mat',...
% 'many_steps_ymax7_lin_EXP_choose-zet-rob-opt_07-18-2018.mat',...
% 'many_steps_ymax7_mpc_EXP_choose-zet-rob-opt_07-18-2018.mat',...
% };
root_CZ = fullfile(PATHS.exp, 'step-exps', 'many_steps_data_rand_30-Jul-2018_01');
files_choose_zet = {
'many_steps_ymax7_linfxp_sim_choose-zet-min-gam_07-30-2018.mat',...
'many_steps_ymax7_mpcfxp_sim_choose-zet-min-gam_07-30-2018.mat',...
'many_steps_ymax7_linfxp_sim_choose-zet-rob-opt_07-30-2018.mat',...
'many_steps_ymax7_mpcfxp_sim_choose-zet-rob-opt_07-30-2018.mat',...
'many_steps_ymax7_lin_EXP_choose-zet-min-gam_07-30-2018.mat',...
'many_steps_ymax7_mpc_EXP_choose-zet-min-gam_07-30-2018.mat',...
'many_steps_ymax7_lin_EXP_choose-zet-rob-opt_07-30-2018.mat',...
'many_steps_ymax7_mpc_EXP_choose-zet-rob-opt_07-30-2018.mat',...
};

names_choose_zet = {'SLF-CZ-MG', 'MPC-CZ-MG',...
                    'SLF-CZ-RG', 'MPC-CZ-RG',...
                    'SLF-CZ-MG', 'MPC-CZ-MG',...
                    'SLF-CZ-RG', 'MPC-CZ-RG'};

clrs = {'b', 'r', 'g', 'k', 'b', 'r', 'g', 'k'}    ;
line_styles = {'-', '--', '-', '--','-', '--','-', '--','-', '--','-', '--','-', '--'};

step_exps_CZ_cell = cell(1, length(files_choose_zet));
for k=1:length(names_choose_zet)
  dat = load(fullfile(root_CZ, files_choose_zet{k}));
  
  exp_name_str = fields(dat);
  exp_name_str = exp_name_str{1};
  dat = dat.(exp_name_str);
  dat.yscaling = 5;
  dat.yunits = '[$\mu$m]';
  dat.Ipow = dat.Ipow * 1000/15.15;
  dat.name = names_choose_zet{k};
  dat.Color = clrs{k};
  dat.LineStyle = line_styles{k};
  step_exps_CZ_cell{k} = dat;

end

% leg = legend(hands);
% set(leg, 'Location', 'NorthEast')
%%
step_exps_CZ = ManyStepExps(TOL, tol_mode, step_ref, step_exps_CZ_cell{:});

clc
% -------------------------------------------------------------------------
rgb1 = [0.230, 0.299, 0.754];
rgb2 = [0.706, 0.016, 0.150];
s_ = linspace(0,1, length(step_ref.step_diff_amps));
color_map = diverging_map(s_, rgb1, rgb2);
% ------------ Constant-Sigma LaTex table -------------------
ts_master_vec = ManyStepExps.ts_vec_from_dir(root_CS, TOL, tol_mode);

S = step_exps_CS.TS_dat2tex('do_color', true, 'ts_vec', ts_master_vec, 'colormap', color_map);
fprintf('%s', S); % just display it.

if saveon
  ManyStepExps.write_tex_data(S, fullfile(PATHS.MPCJ_root, 'latex', 'manystepsdata.tex'));
end


% ------------ Choose-Zeta LaTex table -------------------
S = step_exps_CZ.TS_dat2tex('do_color', true, 'ts_vec', ts_master_vec, 'colormap', color_map);
fprintf('%s', S); % just display it.
if saveon
  ManyStepExps.write_tex_data(S, fullfile(PATHS.MPCJ_root, 'latex', 'manystepsdata_choosezeta.tex'));
end

% create a figure which is only a colormap legend
fig100 = mkfig(100, 7, 0.75); clf
ax = gca();
set(ax, 'Visible', 'off');
colormap(ax, color_map);
cb = colorbar(ax);
set(cb, 'Position', [0.03, 0.5, 0.94, 0.25], 'Orientation', 'horizontal',...
  'Units', 'normalized', 'AxisLocation', 'in', 'FontSize', 9)
cb.Label.String = 'settle-time [ms]';
ts_min = min(ts_master_vec)*1000;
ts_max = max(ts_master_vec)*1000;
caxis([ts_min, ts_max+.001]); % +.001 to get 93 to display
set(cb, 'Ticks', [3, 25, 50, 75, 93])
saveas(fig100, fullfile(PATHS.jfig(), 'ts_colorbar.svg'))



%%
% Lets try lucy's suggestion of plotting the settle-times vs |delta-ref|
clc
width = 3.5; 
height = 3.5;
Fig15 = mkfig(15, width, height); clf
% ax1 = axes('Position', [0.13, 0.17, 0.85, 0.8]);

lft = 0.455;
bt = 0.3;
top_pad = 0.07 + 10/72;
rt_pad = 0.07 ;
wd = width - lft - rt_pad;
ht = height - bt - top_pad;
ax1 = axes('Units', 'inches', 'Position', [lft bt wd ht]);
ms = {'d', '+', 'o', 'x'};
colrs = {'k', 'k', 'k', 'k'};
msize = 5;
hands1 = gobjects(1, 4);
hands2 = gobjects(1, 4);
idx = [5:8];
j = 1;
for k=1:4
  hands1 (k) = plot(abs(step_exps_CZ.step_ref.step_diff_amps(2:end))*step_exps_CZ.step_ref.yscaling,...
    step_exps_CZ.TS_mat(:, idx(k))*1000, ms{k}, 'Color', colrs{k}, 'MarkerSize', msize);
  hands1(k).DisplayName = step_exps_CZ.step_exps{idx(k)}.name;
  hold on
  
end

set(ax1, 'YScale', 'log')
set(ax1, 'YTick', [2,5, 10,20, 50, 100], 'YLim', [0.001, 100])
set(ax1, 'YLim', [0.001, 100])

grid on
ax_pos = ax1.Position;
% ax2 = axes('Units', 'inches', 'Position', ax_pos);
% Fig15.CurrentAxes = ax2;

for k=1:4
  hands2 (k) = plot(ax1, abs(step_exps_CS.step_ref.step_diff_amps(2:end))*step_exps_CS.step_ref.yscaling,...
    step_exps_CS.TS_mat(:, idx(k))*1000, ms{k}, 'Color', 'r', 'MarkerSize', msize);
  hands2(k).DisplayName = step_exps_CS.step_exps{idx(k)}.name;
  hold on
end
ylm1 = ylim();
set(ax1, 'Visible', 'on', 'YLim', [2, ylm1(2)]);

grid on
leg1 = legend([hands1, hands2]);
set(leg1, 'Box', 'on', 'FontSize', 8)
leg_ht = 1.2388;
leg_wd = 0.63;
% pos1 = [0.6 height-leg_ht, leg_ht, leg_wd];
set(leg1, 'Units', 'inches', 'NumColumns', 2, 'Position', [0.46323 2.7045 2.4402 0.59062])


Fig15.CurrentAxes = ax1;
xlab = xlabel('$|r_i - r_{i-1}|$');
ylab = ylabel('settle time [ms]');
htit = title('(experiment)', 'FontSize', 10);

tick_pad_inches = ax1.FontSize/72 + 0.0;  % 1/72 = pt
set(xlab, 'Units', 'inches', 'HorizontalAlignment', 'center',...
  'Position', [wd/2, -tick_pad_inches, 0])

if saveon
  saveas(Fig15, fullfile(PATHS.jfig, 'ts_vs_delref.svg'))
end
%%
% Again try lucy's suggestion of plotting the settle-times vs |delta-ref|.
% This time for the simulations.
Fig16 = mkfig(16, width, height); clf

ax3 = axes('Units', 'inches', 'Position', [lft bt wd ht]);

ms = {'d', '+', 'o', 'x'};
msize = 5;
hands1 = gobjects(1, 4);
hands2 = gobjects(1, 4);
% -----!!!! idx is main difference to the previous plotting section.
idx = [1:4];
for k=1:4
  hands1 (k) = plot(abs(step_exps_CZ.step_ref.step_diff_amps(2:end))*step_exps_CZ.step_ref.yscaling,...
    step_exps_CZ.TS_mat(:, idx(k))*1000, ms{k}, 'Color', 'k', 'MarkerSize', msize);
  hands1(k).DisplayName = step_exps_CZ.step_exps{idx(k)}.name;
  hold on
end

set(ax3, 'YScale', 'log')
set(ax3, 'YTick', [2,5, 10,20, 50, 100], 'YLim', [0.001, 100])
ylm1 = ylim();
grid on


for k=1:4
  hands2 (k) = plot(ax3, abs(step_exps_CS.step_ref.step_diff_amps(2:end))*step_exps_CS.step_ref.yscaling,...
    step_exps_CS.TS_mat(:, idx(k))*1000, ms{k}, 'Color', 'r', 'MarkerSize', msize);
  hands2(k).DisplayName = step_exps_CS.step_exps{idx(k)}.name;
  hold on
end
ylm2 = ylim();
set(ax3, 'Visible', 'on', 'YLim', [2, ylm2(2)]);

grid on
leg1 = legend([hands1, hands2]);
set(leg1, 'Units', 'inches', 'Box', 'on', 'FontSize', 8, 'NumColumns', 2)
% pos1 = [0.1020 0.80 0.35 0.18];
set(leg1, 'Position',  [0.45358 2.7045 2.4186 0.59062])


Fig16.CurrentAxes = ax3;
xlab = xlabel('$|r_i - r_{i-1}|$');
ylab = ylabel('settle time [ms]');
htit = title('(simulation)', 'FontSize', 10);

tick_pad_inches = ax3.FontSize/72 + 0.0;  % 1/72 = pt
set(xlab, 'Units', 'inches', 'HorizontalAlignment', 'center',...
  'Position', [wd/2, -tick_pad_inches, 0])

if saveon
  saveas(Fig16, fullfile(PATHS.jfig, 'ts_vs_delref_sim.svg'))
end

%% -------------------------------------------------------------------------
% ------------ Constant-Sigma Plot steps, experimental-only zoom in--------
width = 3.4;
height = 3.5 + 2.5;

Fig = mkfig(10, width, height); clf

% ax1 = axes('Position', [0.1300 0.75 0.7750 0.25], 'Units', 'normalized');
% ax2 = axes('Position', [0.1300 0.1100 0.36 0.55], 'Units', 'normalized'); 
% ax3 = axes('Position', [0.5703 0.1100 .36 0.55], 'Units', 'normalized');

ax1 = axes('Units', 'inches', 'Position', [0.4415 2.6250+1.25+1.25 2.85 0.8750]);
ax2 = axes('Units', 'inches', 'Position', [0.4415 0.3850+2.5 1.3 1.9250]);
ax3 = axes('Units', 'inches', 'Position', [1.99 0.3850+2.5 1.3 1.9250]);

ax4 = axes('Units', 'inches', 'Position', [0.4415 0.3850+1.25 1.3 1.], 'Box', 'on');
ax5 = axes('Units', 'inches', 'Position', [1.99 0.3850+1.25 1.3 1.], 'Box', 'on');

ax6 = axes('Units', 'inches', 'Position', [0.4415 0.3 1.3 1.1], 'Box', 'on');
ax7 = axes('Units', 'inches', 'Position', [1.99 0.3 1.3 1.1], 'Box', 'on');


step_ref.plot(ax1);
step_ref.plot_settle_boundary(ax1, TOL, tol_mode);
step_exps_CS.ploty_selected([5:8], ax1);
ax1.YLabel.String = 'y [$\mu$m]';
% ax1.XLabel.String = 't [ms]';
set(ax1, 'YLim', [-7.5, 7.5]*5);

% "best"
el1 = annotation('ellipse');
set(el1, 'Units', 'inches', 'Position', [0.6112 2.7300+2.5 0.1358 0.1750], 'Color', 'r');
a1 = annotation('arrow');
set(a1, 'Units', 'inches', 'X', [0.6792 0.6792], 'Y', [2.75, 2.1]+2.5); 
% "worst"
el2 = annotation('ellipse');
set(el2, 'Units', 'inches', 'Position', [2.68 2.9750+2.5 0.13 0.160], 'Color', 'r');
a2 = annotation('arrow');
set(a2, 'Units', 'inches', 'X', [2.75 2.6], 'Y', [2.9, 2.2]+2.6);

% Even though we want to zoom in, its maybe easiest to stick with our framework
% and plot the whole thing, then adjust xlim and ylim.

step_ref.plot(ax2);
step_ref.plot_settle_boundary(ax2, TOL, tol_mode);
step_exps_CS.ploty_selected([5:8], ax2);
set(ax2, 'XLim', [0.20, 0.244]); % ;
set(ax2, 'YLim', [-4.3, -3.8]*5);
ax2.YLabel.String = 'y [$\mu$m]';

step_ref.plot(ax3);
step_ref.plot_settle_boundary(ax3, TOL, tol_mode);
hands = step_exps_CS.ploty_selected([5:8], ax3);

set(ax3, 'XLim', [1.9998, 2.0438]);

set(ax3, 'YLim', [-.05, .1]*5);

leg = legend(hands);
set(leg, 'FontSize', 7, 'Box', 'off',...
  'Position', [0.6239 0.6766 0.3634 0.1307])


hold(ax4, 'on')
step_exps_CS.plotdu_selected([5:8], ax4);
set(ax4, 'XLim', [0.20, 0.215]);
grid(ax4, 'on')
ax4.YLabel.String='$\Delta u_k$';

hold(ax5, 'on')
step_exps_CS.plotdu_selected([5:8], ax5);
set(ax5, 'XLim', [2.0, 2.01]);
% set(ax5, 'XTick', [2.1, 2.125, 2.15])
grid(ax5, 'on')
ax4.YLabel.String = '$\Delta u_k$';


ax4.XLabel.String = '';
ax5.XLabel.String = '';

hold(ax6, 'on');
hands_Ipow = step_exps_CS.plotIpow_selected(5:8, ax6);
set(ax6, 'XLim', [0.20, 0.215]);
grid(ax6, 'on')
ax6.YLabel.String='$I_{pow}$ [mA]';
xlabel(ax6, 'time [s]')

hands_Ipow = step_exps_CS.plotIpow_selected(5:8, ax7);
set(ax7, 'XLim', [2.1, 2.115]);
xlabel(ax7, 'time [s]')
% set(ax5, 'XTick', [2.1, 2.125, 2.15])
grid(ax7, 'on')


if saveon
  saveas(Fig, fullfile(PATHS.jfig, 'step_exps_const_sig_y.svg'))
end
%% Now, the choos-zeta scenario
% ----------------------------------------------------------------


width = 3.4;
height = 4.75+1.25;
Fig = mkfig(11, width, height); 
%
clf, clc
% subplot(2,2,[1,2])
ax1 = axes('Units', 'inches', 'Position', [0.4415, 2.6250+1.25+1.25 2.85 0.8750]);
ax2 = axes('Units', 'inches', 'Position', [0.4415, 0.3850+2.5 1.3 1.9250]);
ax3 = axes('Units', 'inches', 'Position', [1.99 0.3850+2.5 1.3 1.9250]);

ax4 = axes('Units', 'inches', 'Position', [0.4415, 0.3850+1.25, 1.3, 1.], 'Box', 'on');
ax5 = axes('Units', 'inches', 'Position', [1.99, 0.3850+1.25, 1.3, 1.], 'Box', 'on');

ax6 = axes('Units', 'inches', 'Position', [0.4415 0.3 1.3 1.1], 'Box', 'on');
ax7 = axes('Units', 'inches', 'Position', [1.99 0.3 1.3 1.1], 'Box', 'on');


step_ref.plot(ax1);
step_ref.plot_settle_boundary(ax1, TOL, tol_mode);
step_exps_CZ.ploty_selected([5:8], ax1);
ax1.YLabel.String = 'y [$\mu$m]';
% ax1.XLabel.String = 't [ms]';
set(ax1, 'YLim', [-7.5, 7.7]*5);

% "best"
a1 = annotation('ellipse');
set(a1, 'Units', 'inches', 'Position', [0.6120 2.7300+2.5 0.1360 0.1750], 'Color', 'r');
a2 = annotation('arrow');
set(a2, 'Units', 'inches', 'X', [0.68, 0.68], 'Y', [2.7475, 2.1]+2.5);
% "worst"
a3 = annotation('ellipse');
set(a3, 'Units', 'inches', 'Position', [2.7840 3.3950+2.5 0.1360 0.1050], 'Color', 'r')
a4 = annotation('arrow');
set(a4, 'Units', 'inches', 'X', [2.8180 2.4820], 'Y', [3.3950 2.2750]+2.5);

% Even though we want to zoom in, its maybe easiest to stick with our framework
% and plot the whole thing, then adjust xlim and ylim.

step_ref.plot(ax2);
step_ref.plot_settle_boundary(ax2, TOL, tol_mode);
step_exps_CZ.ploty_selected([5:8], ax2);
set(ax2, 'XLim', [0.20, 0.244]); % ;
set(ax2, 'YLim', [-4.3, -3.8]*5);
ax2.YLabel.String = 'y [$\mu$m]';

step_ref.plot(ax3);
step_ref.plot_settle_boundary(ax3, TOL, tol_mode);
hands = step_exps_CZ.ploty_selected([5:8], ax3);

set(ax3, 'XLim', [2.1, 2.15]);
set(ax3, 'XTick', [2.1, 2.125, 2.15])
set(ax3, 'YLim', [6.8, 7.5]*5);

leg = legend(hands);
set(leg, 'FontSize', 7, 'Box', 'off',...
  'Position', [0.6487 0.6049 0.3383 0.1307])

hold(ax4, 'on')
step_exps_CZ.plotdu_selected([5:8], ax4);
set(ax4, 'XLim', [0.20, 0.215]);
grid(ax4, 'on')
ax4.YLabel.String='$\Delta u_k$';

hold(ax5, 'on')
step_exps_CZ.plotdu_selected([5:8], ax5);
set(ax5, 'XLim', [2.1, 2.115]);
% set(ax5, 'XTick', [2.1, 2.125, 2.15])
grid(ax5, 'on')

ax4.XLabel.String = '';
ax5.XLabel.String = '';

hold(ax6, 'on');
hands_Ipow = step_exps_CZ.plotIpow_selected(5:8, ax6);
set(ax6, 'XLim', [0.20, 0.215]);
grid(ax6, 'on')
ax6.YLabel.String='$I_{pow}$ [mA]';
xlabel(ax6, 'time [s]')

hands_Ipow = step_exps_CZ.plotIpow_selected(5:8, ax7);
set(ax7, 'XLim', [2.1, 2.115]);
xlabel(ax7, 'time [s]')
% set(ax5, 'XTick', [2.1, 2.125, 2.15])
grid(ax7, 'on')




if saveon
  saveas(Fig, fullfile(PATHS.jfig, 'step_exps_choose_zet_y.svg'))
end

%%
% Now, plot current draw
clc
height = 2.5;
F12 = mkfig(12, width, height);
ax = gca();

hands_Ipow = step_exps_CS.plotIpow_selected(5:8, ax);

ylim([-130, 110])
grid on
ylabel('Current [mA]')
xlabel('time [s]')

leg3 = legend(hands_Ipow);
set(leg3, 'NumColumns', 2, 'Units', 'inches',...
  'Position', [0.8089 0.2993 2.5049 0.3319], 'Box', 'off')
tighten_axis(F12, ax)


F13 = mkfig(13, width, height);
ax = gca();

hands_Ipow = step_exps_CZ.plotIpow_selected(5:8, ax);

ylim([-130, 110])
grid on
ylabel('Current [mA]')
xlabel('time [s]')

leg4 = legend(hands_Ipow);
set(leg4, 'NumColumns', 2, 'Units', 'inches',...
  'Position', [0.7956 0.2993 2.5181 0.3319], 'Box', 'off')
tighten_axis(F13, ax)



%%
saveas(F12, fullfile(PATHS.jfig, 'step_exps_const_sig_Ipow.svg'))
saveas(F13, fullfile(PATHS.jfig, 'step_exps_choose_zet_Ipow.svg'))
