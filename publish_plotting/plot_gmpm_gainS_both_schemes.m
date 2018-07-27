% This script plots the LQR based root locus for the "lowgain"
% version of things.

addpath(fullfile(getMatPath(), 'afm_mpc_journal', 'functions'))
addpath(fullfile(getMatPath(), 'afm_mpc_journal', 'functions', 'canon'))

clear, clc
saveon = true;
plants = CanonPlants.plants_ns14();
G = plants.SYS;
G_recyc = plants.sys_recyc;
Ts = G_recyc.Ts;


pmgm_figfile = 'PMGM_vs_gamma_both.svg';
sens_ts_figfile = 'GainS_TS_vs_gamma_both.svg';
lqr_locus_figfile = 'lqr_locus_both.svg';

const_sig = false;


Qw = plants.SYS.b*plants.SYS.b'*50;
Lx = G.a*dlqr(plants.SYS.a', plants.SYS.c', Qw, 1)';
p_int_d = 0.7;
[LxLd, G_obsDist, Ident_obs, C_ydist] = DistEst.output_dist_est(G, Lx, p_int_d);

cmplx_rad = 0.9;
[Q1, R0, S1, P_x] = build_control_constsigma(G_recyc, cmplx_rad);
   

gams = logspace(log10(0.1), log10(1000), 100);
gams = unique([gams, 1.0, 3.0, 3.1, 3.8, 12,10, 2, 0.001, 0.5, 0.2, 2.9]);
[GM_s1, PM_s1, Sens_gain1, TS_s1] = gmpm_vs_gam_recyc_obs(G, G_recyc, G_obsDist, Q1, R0, S1, LxLd, gams);

can_cntrl = CanonCntrlParams_ns14();
[Q1, R0, S1] = build_control(G_recyc, can_cntrl);
[GM_s2, PM_s2, Sens_gain2, TS_s2] = gmpm_vs_gam_recyc_obs(G, G_recyc, G_obsDist, Q1, R0, S1, LxLd, gams);

%%
clc
% -------------- Plot Colors & Linestyles ----------------------
GM_colr = 'k';
PM_colr = 'r';
GM_ls1 = '-';
GM_ls2 = '--';

PM_ls1 = '-.';
PM_ls2 = ':';

width = 3.45;
height = 3;
figbase = 0;

f4 = mkfig(4+figbase, width, height); clf
f5 = mkfig(5+figbase, width, height); clf

figure(f4);
ax1 = axes('Position', [0.1100 0.1300 0.7750 0.8150], 'YAxisLocation', 'left');

[hgm1, hpm1] = plot_gmpm(gams, GM_s1, PM_s1, ax1, f4, 'GM_color', GM_colr,...
  'GM_LS', GM_ls1, 'PM_color', PM_colr, 'PM_LS', PM_ls1);
hgm1.DisplayName = 'GM (constant-$\sigma$)';
hpm1.DisplayName = 'PM (constant-$\sigma$)';


figure(f4);
[hgm2, hpm2] = plot_gmpm(gams, GM_s2, PM_s2, ax1, f4, 'GM_color', GM_colr,...
  'GM_LS', GM_ls2, 'PM_color', PM_colr, 'PM_LS', PM_ls2);
hgm2.DisplayName = 'GM (choose-$\zeta$)';
hpm2.DisplayName = 'PM (choose-$\zeta$)';

set(ax1, 'XTick', [0.01, 0.1, 1, 10, 100])
leg1 = legend([hgm1, hgm2, hpm1, hpm2]);
set(leg1, 'Location', 'NorthWest', 'Box', 'off')
%


figure(f5);
ax2 = axes('Position', [0.1100 0.1300 0.7750 0.8150], 'YAxisLocation', 'left');
[h_sens1, h_ts1] = plot_sens_ts(gams, Sens_gain1, TS_s1, ax2, f5,...
  'Ts_color', PM_colr, 'Ts_LS', PM_ls1, 'Sens_color', GM_colr, 'Sens_LS', GM_ls1);
h_sens1.DisplayName = 'Gain of S (constant-$\sigma$)';
h_ts1.DisplayName = 'Nominal settle-time (constant-$\sigma$)';

[h_sens2, h_ts2] = plot_sens_ts(gams, Sens_gain2, TS_s2, gca(), f5,...
  'Ts_color', PM_colr, 'Ts_LS', PM_ls2, 'Sens_color', GM_colr, 'Sens_LS', GM_ls2);
h_sens2.DisplayName = 'Gain of S (choose-$\zeta$)';
h_ts2.DisplayName = 'Nominal settle-time (choose-$\zeta$)';

leg2 = legend([h_sens1, h_sens2, h_ts1, h_ts2]);
set(leg2, 'Position', [0.1100 0.4663 0.6503 0.2091], 'Box', 'off')
set(ax2, 'XTick', [0.01, 0.1, 1, 10, 100])
yyaxis(ax2, 'left')
ylim([32, 52])
% P_x  = getCharDes(G_recyc, can_cntrl.gam_s, can_cntrl.pint,...

% [Chat, Dhat] = place_zeros(G_recyc, P_x);
% Q1 = Chat'*Chat;
% S1 = Chat'*Dhat;
% R0 = Dhat'*Dhat;
% 

if saveon
   saveas(f4, fullfile(PATHS.jfig, pmgm_figfile))
   saveas(f5, fullfile(PATHS.jfig, sens_ts_figfile))
end

%
clc
% Its rediculous to enter the data in a table by hand.
min_gam_labels = {'const-$\sigma$ (lin, min-$\gamma$)',  'const-$\sigma$ (MPC, min-$\gamma$)',...
  'choose-$\zeta$ (lin, min-$\gamma$)', 'choose-$\zeta$ (MPC, min-$\gamma$)'};

rob_labels = {'const-$\sigma$ (lin, rob) ', 'const-$\sigma$ (MPC, rob)',...
  'choose-$\zeta$ (lin, rob) ', 'choose-$\zeta$ (MPC, rob)',   };
labels = {rob_labels{:}, min_gam_labels{:}};


%
[~, idx] = min(Sens_gain1);
% for rob-optimal, mpc and linear take the same gamma
lin_sig__rob_data = [gams(idx), GM_s1(idx), PM_s1(idx), Sens_gain1(idx)];
mpc_sig_rob_data = [gams(idx), GM_s1(idx), PM_s1(idx), Sens_gain1(idx)];
[~, idx] = min(Sens_gain2);
lin_zet__rob_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];
mpc_zet_rob_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];
data = [lin_sig__rob_data; mpc_sig_rob_data; lin_zet__rob_data; mpc_zet_rob_data];

% minimum-gamma scheme.  For const-sigma, and rmax=14, we get gam=10 for
% linear, and gam=0.5 for Nmpc=12.
idx = find(gams == 10, 1, 'first');
lin_sig_ming_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];
idx = find(gams == 0.5, 1, 'first');
mpc_sig_ming_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];

% We have, I think, gam=2.9 for MPC and gam=3.1 for linear, in the choose zeta scheme.
idx = find(gams == 2.9, 1, 'first');
lin_zet_ming_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];
idx = find(gams == 0.2, 1, 'first');
mpc_zet_ming_data = [gams(idx), GM_s2(idx), PM_s2(idx), Sens_gain2(idx)];

data = [data; lin_sig_ming_data; mpc_sig_ming_data; lin_zet_ming_data; mpc_zet_ming_data];

%%
body = sprintf('%s\n\\hline\n', 'scheme           & $\gamma$ &GM [dB]& PM [deg] & $|\mathcal{S}|$ [dB]\\');


for row=1:size(data,1)
  row_str = sprintf('%s &', labels{row});
  for col = 1:size(data,2)
    
    if col < size(data,2)
      fmt = '%s %.1f &';
    else
      fmt = '%s %.1f';
    end
     row_str = sprintf(fmt, row_str, data(row, col));
  end
  body = sprintf('%s%s\\\\\n', body, row_str);
end

body
if saveon
  fid = fopen(fullfile(PATHS.MPCJ_root, 'latex', 'rob_data.tex'), 'w+');
  fprintf(fid, '%s', body);
  fclose(fid);
end



% ------------------------------------------------------------------
% ------------------------------------------------------------------
% ------- Function Defs. So nice matlab FINALLY allows this --------

function [h_sens, h_ts] = plot_sens_ts(gams, Sens_gain_s, TS_s, ax, Fig, varargin)
  p = inputParser();
  p.addParameter('Sens_color', 'k')
  p.addParameter('Ts_color', 'r')
  p.addParameter('Sens_LS', '-')
  p.addParameter('Ts_LS', '--')
  p.parse(varargin{:})
  Sens_opts = {'Color', p.Results.Sens_color, 'LineStyle', p.Results.Sens_LS};
  Ts_opts = {'Color', p.Results.Ts_color, 'LineStyle', p.Results.Ts_LS};
  ax.YAxis(1).Color = p.Results.Sens_color;
  
  Fig.CurrentAxes = ax;
  yyaxis left;
  
  h_sens = semilogx(gams, Sens_gain_s, Sens_opts{:});
  hold on
  grid on
  xlabel('$\gamma$')
  ylabel('Gain of $S(z)$ [dB]')
  
  yyaxis right
  h_ts = semilogx(gams, TS_s*1000, Ts_opts{:});
  ylabel('Settle-time [ms]')
  
  ax.YAxis(2).Color = p.Results.Ts_color;
  
end


function [h_gm, h_pm] = plot_gmpm(gams, GM_s, PM_s, ax1, Fig, varargin)
  %PLOT_GMPM Summary of this function goes here
  %   Detailed explanation goes here

  p = inputParser();
  p.addParameter('GM_color', 'k')
  p.addParameter('PM_color', 'r')
  p.addParameter('GM_LS', '-')
  p.addParameter('PM_LS', '--')
  p.parse(varargin{:})
  GM_opts = {'Color', p.Results.GM_color, 'LineStyle', p.Results.GM_LS};
  PM_opts = {'Color', p.Results.PM_color, 'LineStyle', p.Results.PM_LS};
  
  
  Fig.CurrentAxes = ax1;
  yyaxis left;
  h_gm = semilogx(ax1, gams, GM_s, GM_opts{:});
  h_gm.DisplayName = 'Gain Margin';
  hold on
  grid on
  xlab = xlabel('$\gamma$');
  ylabel('Gain Margin [dB]')
  ax1.YAxis(1).Color = p.Results.GM_color;
  
  Fig.CurrentAxes = ax1;
  yyaxis right
  h_pm = plot(ax1, gams, PM_s, PM_opts{:});
  h_pm.DisplayName = 'Phase Margin';
  ylabel('Phase Margin [deg]')
  
  set(xlab, 'Units', 'normalized', 'Position', [0.5, -0.051, 0],...
    'FontSize', 14);
  

  xlim([gams(1), gams(end)])
  ax1.YAxis(2).Color = p.Results.PM_color;
  
end



