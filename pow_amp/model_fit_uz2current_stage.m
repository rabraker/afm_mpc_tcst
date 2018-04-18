clear
clc

% modelFit_file = 'FRF_data_current_stage.mat';
modelFit_file = 'FRF_data_current_stage2.mat';

load(modelFit_file)
whos

freqs = modelFit.frf.freq_s(:);

% G_uz2current_frf = modelFit.frf.G_uz2current;
G_uz2stage_frf = modelFit.frf.G_uz2stage;
G_uz2current_frf = modelFit.frf.G_uz2powI;


%%

% Visualize everything
F1 = figure(1); clf
frfBode(G_uz2stage_frf, freqs, F1, 'g', 'Hz');
frfBode(G_uz2current_frf, freqs, F1, 'r', 'Hz');



omegas = freqs*2*pi;
Ts = modelFit.frf.Ts;


ejw = exp(1j*Ts*modelFit.frf.w_s(:));

der_frf_ct = (1j*modelFit.frf.w_s(:));
der_frf = ejw - 1;
G_uz2current_int_frf = G_uz2current_frf./der_frf;


F2 = figure(2); clf;
frfBode(G_uz2current_int_frf, freqs, F2, 'r', 'Hz');

ss_opts = frf2ss_opts('Ts', Ts);

f2ss = frf2ss(G_uz2current_int_frf, omegas, 4, ss_opts); % 12
sys = f2ss.realize(12); % 12

g_der = zpk([1], [], 1, Ts); % 
frfBode(sys, freqs, F2, '--k', 'Hz');
sys.InputDelay = 3
frfBode(sys*g_der, freqs, F1, '--k', 'Hz');
%%
sos_fos = SosFos(sys, 'iodelay', sys.InputDelay);
LG = LogCostZPK(G_uz2current_int_frf, freqs*2*pi, sos_fos);
LG.solve_lsq(2)

[sys3, p] = LG.sos_fos.realize();
sys3.InputDelay = max(round(p, 0), 0)
frfBode(sys3*g_der, freqs, F1, '--b', 'Hz')
frfBode(sys3, freqs, F2, '--b', 'Hz')

plotPZ_freqs(sys3*g_der, F1)

%%


modelFit.models.G_uz2current1 = sys3*g_der;

save(modelFit_file, 'modelFit')










