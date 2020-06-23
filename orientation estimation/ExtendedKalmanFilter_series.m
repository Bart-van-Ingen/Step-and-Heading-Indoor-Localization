function estimate = ExtendedKalmanFilter_series(est, accSampled,gyrSampled,magSampled,magnetic, debug_flag)

Types = categorical({'GYR','ACC', 'MAG'});

accSampled.Type(:) = Types(2);
magSampled.Type(:) = Types(3);
gyrSampled.Type(:) = Types(1);

combined_raw = [accSampled; magSampled; gyrSampled];
combined_raw = sortrows(combined_raw);

P = 0.01 * eye(4);

calAcc_R = 0.012 * eye(3);

calGyr_R = 0.0033 * eye(3);

calMag_R = 0.01 * eye(3);

combined = [combined_raw.X, combined_raw.Y, combined_raw.Z]';
type = [combined_raw.Type];

dT = [0; seconds(diff(gyrSampled.Time))];
Time = [seconds(combined_raw.Time)];

    
estimate = repmat(struct('Time', nan, ...
                         'est',nan, ...
                         'P', nan,...
                         'error', nan),...
                         height(combined_raw), 1 );


g = [0; 0; -9.81];

mag_vector = mean(magnetic{:,:});
mag_field =  transpose(mag_vector./norm(mag_vector));

counter = 0;

for index = 1:1:height(combined_raw)
    
    if mod(round(index/height(combined_raw),2)*100,10) == 0  && ...
            round(index/height(combined_raw)*100) ~= 0
        disp(['percentage complete: ' num2str(round(index/height(combined_raw),2)*100)])
    end
    
    y = combined(:,index) ;
    
    switch type(index)
        
        case Types(1)
            counter = counter +1;
            
            % -------------  MOTION UPDATE -----------------------
            F = eye(4) + 0.5*(dT(counter)* Somega(y));
            est = F* est;
            Gu= dT(counter)./ 2 *Sq(est);
            est = est / norm(est);
            P = F*P*F' + Gu*calGyr_R*Gu';

            if debug_flag
                x.prior_est = est;
            end
    % -------------- MEASUREMENT UPDATES ------------------
       
            
        case Types(2)
            % Accelerometer measurement update
            dRdq_acc = dRqdq(est);
            H_acc = [-dRdq_acc(:,:,1)'*g,...
                     -dRdq_acc(:,:,2)'*g,...
                     -dRdq_acc(:,:,3)'*g,...
                     -dRdq_acc(:,:,4)'*g];

            H = [H_acc];

            y_hat = [-quat2rotmat(est)' * g];

            R = [calAcc_R];

            error = y - y_hat;

            S = H*P*H' + R;
            K = (P*H') / S;
            P = P - K*S*K';
            est = est + K* error;

            est  = est/norm(est);
        %     est = est * sign(est(1));
            J = (1/norm(est)^3)*(est*est');
%             P = J*P*J';

         case Types(3)
            dRdq_mag = dRqdq(est);
            H_mag = [dRdq_mag(:,:,1)'*mag_field, ...
                     dRdq_mag(:,:,2)'*mag_field, ...
                     dRdq_mag(:,:,3)'*mag_field, ...
                     dRdq_mag(:,:,4)'*mag_field];

            H = [ H_mag];

            y_hat = [ quat2rotmat(est)' * mag_field];

            R = [ calMag_R];

            error = y - y_hat;

            S = H*P*H' + R;
            K = (P*H') / S;
            P = P - K*S*K';
            est = est + K* error;

            est  = est/norm(est);
        %     est = est * sign(est(1));
            J = (1/norm(est)^3)*(est*est');
%             P = J*P*J';
    end
        
%     --------------- SAVING ESTIMATE COMPONENTS ---------
    x.Time =Time(index);
    x.est = est;
    x.P = P;
    x.error = error;

    
    estimate(index) = x;
    
end

estimate = struct2table(estimate);
estimate.Time = seconds(estimate.Time);
estimate = table2timetable(estimate);
    
end