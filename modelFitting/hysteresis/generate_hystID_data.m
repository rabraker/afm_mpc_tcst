clear, clc

dry_run = true;
saveon = false;

Ts = 40e-6;
u_max = 9;
n_space = 8000;
n_up = 5;
step_sz = u_max/n_up;

imps = [0;step_sz*ones(n_up, 1); -step_sz*ones(2*n_up-1,1)];


for k = 2*n_up-2:-1:1
  if mod(k,2) == 1
    sgn = -1;
  else
    sgn = 1;
  end
  imps = [imps; sgn * step_sz * ones(k, 1)];
  
end
% imps = [imps; -sum(imps)]
% ref_s = cumsum(imps)
N_imp = length(imps)


impulse_idx= (1:n_space:N_imp*n_space)';
u_vec = zeros((N_imp)*(n_space), 1);
u_vec(impulse_idx) = imps;
u_vec = cumsum(u_vec);
% u_vec(u_vec <=-8) = -7.0;
% u_vec = repmat(cumsum(u_vec), 3,1);

t_vec = (0:length(u_vec)-1)'*Ts;
figure(1); clf
plot(t_vec, u_vec);
grid on



reset_piezo('t1', 15, 't_final', 25, 'umax', 9, 'k1', 0.55,...
            'verbose', true, 'dry_run', dry_run)
if ~dry_run
  clear vi;
  vipath_reset = 'C:\Users\arnold\Documents\MATLAB\afm_mpc_journal\labview\reset_piezo.vi';
      [e, vi] = setupVI(vipath_reset, 'Abort', 0,...
    'umax', 10, 'TsTicks', 1600, 'u_in', u_vec);
  vi.Run;
  stage_dat = vi.GetControlValue('stage_data_out');

  u_exp = stage_dat(:,1);
  yx_exp = stage_dat(:,2); % - dat(1,2);
  t_exp = (0:length(u_exp)-1)'*Ts;

  figure(201); clf
  plot(t_exp, u_exp)
  hold on
  plot(t_exp, yx_exp - yx_exp(1))
  grid on
  if saveon
    hystData.t_exp = t_exp;
    hystData.u_exp = u_exp;
    hystData.y_exp = yx_exp;
    % hystData.u_reset = u_reset;
    save('hystID_data_4-30-2018_01.mat', 'hystData')
  end
end

