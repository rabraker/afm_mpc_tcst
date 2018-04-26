function [Y, U, dU] = sim_AFM(sim_struct, ref_traj)
% [Y, U, dU] = sim_MPC_fp(sim_struct, ref_f)
% 
% Inputs
% ------
%  sim_struct : a structure which must have the following feilds
%
%    sim_struct.K_lqr;
%    sim_struct.PLANT;
%    sim_struct.trun;
%    sim_struct.mpcProb1;
%    sim_struct.du_max;
%    sim_struct.mpc_on;
%    sim_struct.Nx;
% 
%  ref_f : (scalar) the setpoint to track
% Outputs
% -------
%  Y : (timeseries) Plant Output
%  U : (timeseries) Accumulated deltaU
%  dU : (timeseries) deltaU(k) Control (ie, output of MPC block)
%
% ------------------------------------------------------------------- %
% Pull out all the data stored in sim_struct to expose it to
% simulink. There must be a better way...
  VSS_LINEAR_CONTROL=Simulink.Variant('VSS_CONTROL_MODE==1');
  VSS_MPC_CONTROL=Simulink.Variant('VSS_CONTROL_MODE == 2');
  VSS_STATE_DIRECT=Simulink.Variant('VSS_STATE_MODE==1');
  VSS_STATE_OBS=Simulink.Variant('VSS_STATE_MODE==2');
  VSS_STATE_DIST_OBS=Simulink.Variant('VSS_STATE_MODE==3');
  
  
  options = simset('SrcWorkspace','current');
  % Expose the sim struct to simulink.
  
  PLANT = sim_struct.PLANT;
  trun = ref_traj.Time(end);
  
  x0 = SSTools.getNxNu(PLANT)*0;
  uss_0 = 0;
  
  Ts = PLANT.Ts;
  if sim_struct.mpc_on
    mpcProb1 = sim_struct.mpcProb1;
    VSS_CONTROL_MODE='mpc';
  else
    VSS_CONTROL_MODE='linear';
  end
  
  VSS_STATE_MODE = sim_struct.state_mode;
  if VSS_STATE_MODE > 1
    sim_struct.x0_obs = sim_struct.sys_obs.b*0;
  end

  if VSS_STATE_MODE == 3
    [ ndist, Ns_obs] = size(sim_struct.sys_obs.c);
    Ident_obs = eye(Ns_obs);
    
    % the last row
    C_ydist = Ident_obs(end-ndist+1:end, :);
    % all rows but the last 1
    Ident_obs = Ident_obs(1:end-ndist, :);
  end
  
  if isfield(sim_struct, 'thenoise')
    thenoise = sim_struct.thenoise;
  else
    thenoise = timeseries(ref_traj.Time*0, ref_traj.Time);
  end
  sim('AFMss_fp', [], options)
    
  % provides Y, U, dU
end
