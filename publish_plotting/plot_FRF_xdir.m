% The script will automatically save the resulting FRF's into a .mat file
% with the same name as sinesOut_FileName, replacing only .csv with .mat.
clear

% plotting options
lw = 1.3;
saveon = true; 

addpath('/home/arnold/gradschool/sysID/matlab/functions')
addpath('/home/arnold/matlab/afm_mpc_journal/functions/canon')
addpath('/home/arnold/matlab/afm_mpc_journal/functions')


[plants, frf_data] = CanonPlants.plants_ns14(9, 2);
G = absorbDelay(ss(plants.G_uz2stage));

% Gains for current sensing 
R_sense = 0.1;
R3 = 68.4e3;
R4 = 10.15e6;
I_gain = (1/R_sense)*(R3/(R3+R4));
I_gain = 1/15.15; % Measured

% Gains for amplifier output voltage

R2 = 1.732e6;
R1 = 29.7e6;
Vdiv_gain = R2/(R1+R2);
%Scale the Fourier coefficients of powV  by 1/Vdiv_gain and of powI by
%1/Rsense.


width = 3.5;
height = 2.5;
F2 = mkfig(2, width, height); clf
% F2.PaperPosition = [1.3376    2.3454    5.8247    6.3093];

ax1 = axes('Position', [0.1300 0.5257 0.85 0.3993]);
ax2 = axes('Position', [0.1300 0.1100 0.85 0.3643]);


h1 = frfBode(frf_data.G_uz2stage, frf_data.freqs_Hz, [ax1, ax2],  'Hz',...
  '-r', 'LineWidth', 1);
h1.DisplayName = '$G_{\textrm{vib}}$ (FRF)';

F2.CurrentAxes = ax1;
ylim([-100, 15])
title('Control signal to stage output')

h2 = frfBode(G, frf_data.freqs_Hz, [ax1, ax2], 'Hz', '--k', 'LineWidth', 1);
h2.DisplayName = '$\hat{G}_{\textrm{vib}}$ (model)';

xlim([frf_data.freqs_Hz(1), frf_data.freqs_Hz(end)])
ylim([-2500, 15])
leg1 = legend([h1, h2]);
set(leg1, 'Position', [0.1897 0.5967 0.3396 0.1147], 'Box', 'off',...
  'FontSize', 8, 'Interpreter', 'latex');
set(ax1, 'XTickLabel', [], 'YLim', [-80, 20])
if saveon
  saveas(F2, fullfile(PATHS.jfig, 'G_uz2stage_Eres.svg'))
end
%%
% ----------------------------------------------------------------------- %
% Find the TF-bound
clc
Ts = G.Ts;
nm1 = plants.g_deluz2pow_1norm;
derz = tf([1 -1], 1, Ts)*nm1;
derz_frf = squeeze(freqresp(derz, frf_data.freqs_Hz*2*pi));

derz_inf = tf([1 -1], 1, Ts);
derz_frf_inf = squeeze(freqresp(derz_inf, frf_data.freqs_Hz*2*pi));
Derz_Guz2I_inf = frf_data.G_uz2powI./derz_frf_inf;
mag_max = max(abs(Derz_Guz2I_inf));
derz_frf_inf = derz_frf_inf*mag_max;
% derz_frf = derz_frf*mag_max;
% I_max = 0.1; %Amps
% fprintf('Mag-max = %.3f, deltaUk_max = %.3f\n', mag_max, I_max/mag_max);
     
width = 3.5;
hieght = 3;
F3 = mkfig(3, width, height); clf
ax3 = gca();


h4 = semilogx(ax3, frf_data.freqs_Hz, 20*log10(abs(frf_data.G_uz2powI)), '-k', 'LineWidth', lw);
h4.DisplayName = '$G_{I_x,u_x}$';
hold on, grid on


h10_bnd = semilogx(frf_data.freqs_Hz, 20*log10(abs(derz_frf)),...
          ':k', 'LineWidth', lw);
h10_bnd.DisplayName = '$(z-1) ||g_{I_X,\Delta u_X}||_1$ ';

h11_bnd = semilogx(frf_data.freqs_Hz, 20*log10(abs(derz_frf_inf)),...
          '--k', 'LineWidth', lw);
h11_bnd.DisplayName = '$(z-1) ||G_{I_X,\Delta u_X}(z)||_{\infty}$ ';


xlim([frf_data.freqs_Hz(1), frf_data.freqs_Hz(end)])
ylim([-80, 10])
% leg = legend([h3,h4, h10_bnd, h11_bnd]);
leg = legend([h4, h10_bnd, h11_bnd]);
set(leg, 'location', 'SouthEast', 'FontSize', 8, 'Box', 'off')
xlabel('Frequency [Hz]')
ylabel('Mag [dB]')

tighten_axis(F3, ax3)
if saveon
  saveas(F3, fullfile(PATHS.jfig, 'G_pow_and_current.svg'));
end









