function [GM_s, PM_s] = gmpm_vs_gam_recyc(G, G_recyc, Q, R0, S, gams)
  % For the deltaUk system with disturbance observer, computes the gain margin,
  % phase margin, low-frequency Sensitivity function gain, and unconstrainted
  % settling time for a unit step input.

  
  GM_s = gams*0;
  PM_s = gams*0;
  Sens_gain = gams*0;
  TS_s = gams*0;
  w_eval = 10;
  Ts = G.Ts;
  
  for k=1:length(gams)
  
    K_lqr = dlqr(G_recyc.a, G_recyc.b, Q, R0+gams(k), S);
%     [Sens, ~, Hyr, ~, Loop] = ss_loops_delta_dist(G, G_recyc, G_obsDist, K_lqr, LxLd);
    
    Loop = ss(G_recyc.a, G_recyc.b, K_lqr, 0, G.Ts);
    
%     TS_s(k) = settle_time(t, y, 1, 0.01, [], 20);
    
%     zr = z(imag(z) == 0);
    % Int_prox = zpk([], [zr(end)], 1, Ts);
    % Sens_gain2(k) = dcgain(minreal(Sens*Int_prox));
%     Der = zpk([1], [], 1, Ts);
%     der_gain = abs(freqresp(Der, w_eval));
%     Sens_gain(k) = 20*log10(abs(freqresp(Sens, w_eval))/der_gain);
    
    [gm, pm] = margin(Loop);
% [S] = allmargin(Loop);
    
    GM_s(k) = 20*log10(gm);
    PM_s(k) = pm;
  end
  
  
  
end

