classdef PIHyst
  %PIHYST Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    r;
    w;
    rp
    wp;
    umax;
    n;
  end
  
  methods 
    function self = PIHyst(umax, n)
      self.r = linspace(0, umax, n)';
      self.w = ones(n, 1);
      self.n = n;
      self.umax = umax;
    end
    
    function invert_hyst_PI2(self)
      [rp, wp] = PIHyst.invert_hyst_PI(self.r, self.w);
    end
  end
  methods (Static)
    function [rp, wp, dp, wsp] = invert_hyst_sat_PI(r, w, d, ws)
      [rp, wp] = PIHyst.invert_hyst_PI(r, w);
      d = d(:);
      ws = ws(:);
      wsp = ws*0;
      dp = d*0;
      wsp(1) = 1/ws(1);
      
      for i=2:length(ws)
        s1 = sum(ws(1:i));
        s2 = sum(ws(1:i-1));
        wsp(i) = -ws(i)/(s1*s2);
      end
      for i=1:length(d)
        dp(i) = sum( ws(1:i).*(d(i)-d(1:i)));
      end
    end
    function [rp, wp] = invert_hyst_PI(r, w)
    % [rp, wp] = invert_hyst_PI(r, w)
    %
    % Given a set of PI hysteresis operator parameters r and w, computes the
    % paramters r_prime and w_prime of the inverse operator. 
    
      r = r(:);
      w = w(:);
      rp = r*0;
      wp = w*0;
      
      wp(1) = 1/w(1);
      
      for i=2:length(w)
        s1 = sum(w(1:i));
        s2 = sum(w(1:i-1));
        wp(i) = -w(i)/(s1*s2);
      end
      
      for i=1:length(r)
        rp(i) = sum( w(1:i).*(r(i)-r(1:i)));
      end
    end
    
    function [y, x_vec_k ] = hyst_play_op(u, r, w, y0)
    % [y, y_vec_k ] = hyst_play_op(u, r, w, y0)
    %
    % Given a control vector u, PI parameters r and w and a hysteresis
    % initial condition y0, computes the output vector y. Also computed are is
    % the internal state sequence, x_vec_k.
      
      n = length(r);
      w = w(:);
      x_vec_k = zeros(length(u), length(r));
      y = 0*u;
      
      x_vec_k(1, :) = y0(:)';
      
      for k=2:length(u)
        uk = u(k);
        for j = 1:length(r)
          x_vec_k(k, j) = max(uk - r(j), min(uk+r(j), x_vec_k(k-1, j)));
        end
        y(k) = w'*x_vec_k(k,:)';
      end
    end

    function [y, x_vec_k ] = inverse_hyst_play_sat_op(u, rp, wp, dp,wsp, y0)
      % [y, y_vec_k ] = hyst_play_sat_op(u, r, w, d, ws, y0)
      %
      % Given a control vector u, PI parameters r and w and a hysteresis
      % initial condition y0, computes the output vector y. Also computed are is
      % the internal state sequence, x_vec_k.
      
      n = length(rp);
      wsp = wsp(:);
      wp = wp(:);
      dp = dp(:);
      
      x_vec_k = zeros(length(u), length(rp));
      
      z = PIHyst.sat_op(u, dp, wsp);
      y = PIHyst.hyst_play_op(z, rp, wp, y0);
    end
    
    function y = sat_op(u_vec, d, ws)
      y = u_vec*0;
      ws = ws(:);
      for k=1:length(u_vec)
        u_k = u_vec(k);
        Sd_vec = 0*d;
        for i=1:length(d)
          if d(i) == 0
            Sd_vec(i) = u_k;
          else
            Sd_vec(i) = max(u_k - d(i), 0);
          end
        end
        y(k) = ws'*Sd_vec;
      end
      
    end
  
    
    function [y, x_vec_k ] = hyst_play_sat_op(u, r, w, d,ws, y0)
      % [y, y_vec_k ] = hyst_play_sat_op(u, r, w, d, ws, y0)
      %
      % Given a control vector u, PI parameters r and w and a hysteresis
      % initial condition y0, computes the output vector y. Also computed are is
      % the internal state sequence, x_vec_k.
      
      n = length(r);
      ws = ws(:);
      w = w(:);
      d = d(:);
      
      x_vec_k = zeros(length(u), length(r));
      z_k_vec = PIHyst.hyst_play_op(u, r, w, y0);
      y = PIHyst.sat_op(z_k_vec, d, ws);
    end
    
    function u = gen_reset_u(t1, t_final, Ts, k1, umax, omega)
    % u = gen_reset_u(t1, t_final, Ts, k1, umax, omega)
    % Generates a control u(k) that is a decaying sinusoid modulated from 0 to
    % t1 by a decaying ramp, and from t1 to t_final by a decaying exponential.
    %
    % Inputs
    % ------
    %  t1, t_final:  double
    %
    %  Ts: sample rate
    %  k1: ramp rate, such that from 0 to t1, a(t) = umax - t*k1
    %  umax: max control amplitude. 
    %  omega: (optional) natural frequency of the sinusoid. Default is 
    %          omega = 1
    %  phi: (optional) phase of the sinusoid. Default is phi = 0;
    %
    % Outputs
    % -------
    %  u : a vector of the control inputs from 0 to t_final
    % 
    % More About
    % ----------
    %   The returned control vector u(k) is supposed to reset the hysteresis
    %   to the relaxed inititial state. This was taken from  
    %    
    %    "Hysteresis and creep modeling and compensation for a piezoelectric
    %    actuator using a fractional-order Maxwell resistive capacitor
    %    approach," Yangfang Liu et al., IOP Smart Materials and Structures,
    %    2013. 
    %
    % 
      n1 = floor(t1/Ts);
      n_final = floor(t_final/Ts);
      
      T1 = (0:n1)'*Ts;
      T2 = (n1+1:n_final)'*Ts;
      T = [T1; T2];
      
      if (umax - k1*t1 < 0)
        delta = 0.1; % arbitrary;
        k1_orig = k1;
        k1 = (umax - delta)/t1;
        warning('umax -k1*t1 <0. Reseting k1 from %f to %f\n', k1_orig, k1)
      end
      
      k2 = k1/(umax - k1*t1);
      if k2 < 0
        error('Need k2 positive, but with the chosen parameters, k2 <0')
      end
      
      a1 = umax - k1*T1;
      a2 = a1(end)*exp(k2*(t1-T2));
      a = [a1; a2];
      if ~exist('omega', 'var')
        omega = 1*2*pi;
      end
      u = a.*sin(omega*T);
    end
    

  end
  
end

