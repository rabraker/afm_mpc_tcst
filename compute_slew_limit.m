clear
clc


Imax = 100e-3; % 100mA
Ts = 40e-6;
% assert(1/Ts == 25e3);
C = 4.2e-6; % muF

Kamp = 9;  % 20v range to 180 v range

del_Vhigh_max = (Ts/C)*Imax

del_Vlow_max = del_Vhigh_max/Kamp

%%
load /media/labserver/mpc-journal/x-axis_sines_info_out_2-8-2018-01.mat

whos
saveon = 0;
G_xpow = modelFit.frf.G_xpow_cors;
freqs = modelFit.frf.freq_s;



P_pow2stage = squeeze(G_xpow(1,2, :)./G_xpow(2,2, :));
P_uz2stage = squeeze(G_xpow(1,3, :)./G_xpow(3,3, :));
P_uz2pow = squeeze(G_xpow(2,3, :)./G_xpow(3,3, :));


clc
G = ss(modelFit.models.G_uz2pow);
G.InputDelay = 0;
%%
Gc = d2c(G);
pl = pole(Gc);
Gc = zpk([], pl, 1);
Gc = Gc*(dcgain(G)/dcgain(Gc));

G_vh_I = zpk([0], [], C)*Gc
G_vh_I_z = c2d(G_vh_I, Ts);

step(G_vh_I_z)

bode(G_vh_I_z)
%%
% Gc = d2c(G);
% pl = pole(Gc)
% Gc = zpk([], pl, 1);
% Gc = Gc/dcgain(Gc);
% 
% p1 = -pl(1);
% 
% R1 = 10e3;
% R2 = 5e3;
% C1 = C/150;
% C2 = C/500;
% 
% ff = @(c1c2r1r2)fc1c2(c1c2r1r2, pl);
% 
% c1c2 = fsolve(ff, [C1; C2;R1;R2]);
% 
% C1 = c1c2(1);
% C2 = c1c2(2);
% R1 = c1c2(3);
% R2 = c1c2(4);
% 
% b = 1/C1/R1 + 1/R2/C2 + 1/R2/C1;
% c = 1/(R1*C1*R2*C2); 
% 
% GG = tf(c, [1, b, c])
% pole(GG)
% 
% figure(20)
% bode(Gc, GG)
%%
clc
step(G)
triang = raster(1/(100*Ts), Ts, 400*Ts);
triang.Data = triang.Data*10;
figure(10);
plot(triang.Time, triang.Data)

figure(11);
dtri = diff(triang.Data);
% ./diff(triang.Time);
dtri = [dtri; dtri(end)];
t = triang.Time;
plot(t, dtri)

Glpf = tf(1000*2*pi, [1, 1000*2*pi]);
y = lsim(G, triang.Data, triang.Time);

ylpf = lsim(Glpf, triang.Data, triang.Time);
dylpf = diff(ylpf);

dy = lsim(G, dtri, t);
figure(12); clf, hold on
plot(t(1:end-1), diff(y))
plot(t, dy, '--')
plot(t(1:end-1), dylpf, '--')

figure(13); clf
plot(t, dy)
hold on
plot(t, dtri)
xlabel('time [s]')
leg1 = legend('$\Delta y(k)$', '$\Delta u(k)$');
set(leg1, 'FontSize', 14)


%%



clc
step(G)
u = [0,0.5, 1,1.5, -1, 2, -2, zeros(1,20)]';
t = [0:1:length(u)-1]'*Ts;

triang = timeseries(u, t);
figure(10);
plot(triang.Time, triang.Data)

figure(11);
dtri = diff(triang.Data);
% ./diff(triang.Time);
dtri = [dtri; dtri(end)];
t = triang.Time;
plot(t, dtri)

Glpf = tf(7000*2*pi, [1, 7000*2*pi]);
y = lsim(G, triang.Data, triang.Time);

ylpf = lsim(Glpf, triang.Data, triang.Time);
dylpf = diff(ylpf);

dy = lsim(G, dtri, t);
figure(12); clf, hold on
plot(t(1:end-1), diff(y))
plot(t, dy, '--')
% plot(t(1:end-1), dylpf, '--')

figure(13); clf
plot(t, dy)
hold on
plot(t, dtri)
xlabel('time [s]')
leg1 = legend('$\Delta y(k)$', '$\Delta u(k)$');
set(leg1, 'FontSize', 14)


%%

C1 = 3.8e-6;
R2 = 1e6;

R1 = 250;
fwo = ((R1+R2)/(C1*R1*R2))/2/pi

%%

Vdiv = 2.56/(19.61+2.56);
Vdiv_gain = 1/Vdiv;
load( fullfile(PATHS.exp, 'x-axis_sines_info_out_2-8-2018-01.mat'))
Gpow = modelFit.models.G_uz2pow*Vdiv_gain;
%%
Ts = 40e-6;
ms = 1e3;
period = (60*Ts)
triang = raster(1/period, Ts, period);
triang.Data = triang.Data*6;
u = [triang.Data; zeros(400,1)];
t = [0:1:length(u)-1]'*Ts;

F4 = figure(4); clf
subplot(4,1,1)
plot(t*ms, u)
grid on
title('(LV) u(k)', 'interpreter', 'latex')

subplot(4,1,2)
plot(t(1:end-1)*ms, diff(u))
grid on
title('(LV) $\Delta u(k)$', 'interpreter', 'latex')


du_pow = lsim(Gpow, diff(u), t(1:end-1));
subplot(4,1,3)
plot(t(1:end-1)*ms, du_pow)
grid on

slewfname_in = sprintf('data/slewexp_datain_%0.2f.csv', max(diff(triang.Data)));
slewfpath_in = fullfile(PATHS.MPCJ_root, slewfname_in);

slewfname_out = sprintf('data/slewexp_dataout_%0.2f.csv', max(diff(triang.Data)));
slewfpath_out = fullfile(PATHS.MPCJ_root, slewfname_out);



%
% -----------------------RUN THE Experiment--------------------------------
if 0
    csvwrite(slewfname_in, u);
    clear vi;
    vipath = 'C:\Users\arnold\Documents\MATLAB\afm_mpc_journal\labview\play_nPoint_id_slew_OL_FIFO.vi'

    [e, vi] = setupVI(vipath, 'Abort', 0,...
                'umax', 6, 'data_out_path', slewfpath_out,...
                'traj_in_path', slewfpath_in, 'TsTicks', 1600);
    vi.Run
end
%%
data = csvread(slewfpath_out);
size(data)

u_exp = data(:,1);
y_exp = data(:,2);
upow_exp = data(:,3)*Vdiv_gain;
texp = [0:1:length(u_exp)-1]'*Ts;

figure(F4);
subplot(4,1,1), hold on;
plot(texp*ms, u_exp, '--')


subplot(4,1,3), hold on
plot(texp(1:end-1)*ms, diff(upow_exp), '--')
title('(HV) $\Delta u(k)$', 'interpreter', 'latex')


subplot(4,1,4)
plot(texp*ms, upow_exp)
title('(HV) $ u_{lpf}(k)$', 'interpreter', 'latex')
grid on

figure(5);
plot(y_exp)





