function estimate = ExtendedKalmanFilter(accSampled,gyrSampled,magSampled,magnetic, debug_flag)

prior_est = [1;0;0;0];
prior_P = eye(4, 4);

calAcc.R = 1e-2 * eye(3);

calGyr.R = 1e-5 * eye(3);

calMag.R = 0.5 * eye(3);

acc = accSampled{:,:}';
gyro = gyrSampled{:,:}'; 
mag = magSampled{:,:}';


% gyroscope time update

dT = [0; seconds(diff(accSampled.Time))];

% transpose measurements to get column vectors for matrix operations
% gyro = [data.gyr_X, data.gyr_Y, data.gyr_Z]';
% acc = [data.acc_X, data.acc_Y, data.acc_Z]';
% mag = [data.mag_X, data.mag_Y, data.mag_Z]';
Time = [seconds(accSampled.Time)];

    
if debug_flag
    estimate = repmat(struct('Time', nan, ...
        'final_q',nan, ...
        'final_P', nan, ...
        'prior_est', nan, ...
        'prior_P', nan, ...        
        'acc_error', nan, ...
        'post_acc_est', nan, ...
        'post_acc_P', nan, ...
        'mag_error', nan, ...
        'post_mag_est', nan, ...
        'post_mag_P', nan ), height(accSampled), 1 );
    
else
    estimate = repmat(struct('Time', nan, ...
        'final_q',nan, 'final_P', nan), height(accSampled), 1 );
end

g = [0; 0; 9.81];
dip_angle = 67.095;
% mag_field = [cosd(dip_angle); 0 ; sind(dip_angle)];

mag_field =  magnetic.vector./norm(magnetic.vector);

% unit_mag = mag/norm(mag);

for index = 1:1:height(accSampled)
    % -------------  MOTION UPDATE -----------------------
    F = eye(4) + dT(index)/ 2.* Somega(gyro(:,index));
    prior_est = F* prior_est;
    Gu= dT(index)./ 2 *Sq(prior_est);
    prior_est = prior_est / norm(prior_est);
    prior_P = F*prior_P*F' + Gu*calGyr.R*Gu';
    
    % -------------- MEASUREMENT UPDATES ------------------
    
    % Accelerometer measurement update
    dRdq_acc = dRqdq(prior_est);
    H_acc = [dRdq_acc(:,:,1)'*g, dRdq_acc(:,:,2)'*g,...
        dRdq_acc(:,:,3)'*g, dRdq_acc(:,:,4)'*g];
    
    % transpose rotation matrix of body frame to navigation frame to get from
    % navigation to body frame
    
    acc_error = acc(:,index) - quat2rotmat(prior_est)' * g;
    
    [post_acc_P, post_acc_est] = ...
        MeasurementUpdate(acc_error, prior_est, prior_P, calAcc.R, H_acc);
    
    % magnetometer measurement update
    
    % normalize magnetometer readings
    mag(:,index)= mag(:,index)/norm(mag(:,index));
    
    dRdq_mag = dRqdq(post_acc_est);
    H_mag = [dRdq_mag(:,:,1)'*mag_field, ...
             dRdq_mag(:,:,2)'*mag_field, ...
             dRdq_mag(:,:,3)'*mag_field, ...
             dRdq_mag(:,:,4)'*mag_field];
    
    mag_error = mag(:,index) - quat2rotmat(post_acc_est)' * mag_field;
    
    [post_mag_P, post_mag_est] = ...
        MeasurementUpdate(mag_error, post_acc_est, post_acc_P, calMag.R , H_mag);
    
    % Renormalize quaternion and covariance
    
    final_q  = post_mag_est/norm(post_mag_est);
    final_q = final_q * sign(final_q(1));
    J = (1/norm(post_mag_est)^3)*(post_mag_est*post_mag_est');
    final_P = J*post_mag_P*J';
    
    prior_est = final_q;
    prior_P = final_P; 
    
%     prior_est = post_mag_est;
%     prior_P = post_mag_P;
    
    %     --------------- SAVING ESTIMATE COMPONENTS ---------
    x.Time =Time(index);
    x.final_q = final_q;
    x.final_P = final_P;
    
    if debug_flag
        x.prior_P = prior_P;
        
        x.acc_error = acc_error;
        x.post_acc_est = post_acc_est;
        x.post_acc_P = post_acc_P;
        
        x.mag_error = mag_error;
        x.post_mag_est = post_mag_est;
        x.post_mag_P = post_mag_P;
    end
    
    estimate(index) = x;
    
end

estimate = struct2table(estimate);
estimate.Time = seconds(estimate.Time);
estimate = table2timetable(estimate);
    
end