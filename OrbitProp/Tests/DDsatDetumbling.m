% DDsatDetumbling is a test script for OrbitProp
%
% In this case this example shows a detumbling example for DDsat using
% magnetic torquers

%--- CODE ---%

%Clean up
clc
clear all
close all

%Add paths
addpath('..')
OrbitToPath

%--- Initial state vector and model configuration ---%
%Earth parameters


Re = 6378136.49; %Equatorial Earth radius m [source: SMAD 3rd edition]
mu=398600.441e9;  %GM Earth m3/s2 [source: SMAD 3rd edition]
we = 7.292115e-5; %Earth Angular velocity in rad/s [source: SMAD 3rd edition]

%Initial conditions
h = 320*1e3; %Initial altitude in m
i = 79; %Inclination
v0 = sqrt(mu/(Re+h)); %Initial velocity
x0 = [Re+h,0,0,0,v0*cosd(i),v0*sind(i)]; %Initial vector state
%Atmosphere co-rotation velocity
Vco = norm(cross([0;0;we],x0(1:3))); 

tf = 0:1:15 * 60; %Integration time
rx=deg2rad(rand()*360);
ry=deg2rad(rand()*360);
rz=deg2rad(rand()*360);
q0=angle2quat(rx,ry,rz,'XYZ'); %Initial attitude quaterion

%Initial angular rate (make it random!)
w1=20*(rand()-0.5);
w2=20*(rand()-0.5);
w3=20*(rand()-0.5);
w0=deg2rad([w1,w2,w3]); %Format initial angular rate

%Format the initial 
x0=[x0,q0,w0];

%Spacecarft propetries
data.sc_prop.I=[0.0042,0,0;
                0,0.0104,0;
                0,0,0.0104]; %Inertia
            
%Models
data.models={@GravJ4};
data.models(end+1)={@MagDamping};

%Configure MagDamping
data.MagDamping.c = 2e-4;
data.MagDamping.A = [0.2,0.2,0.2];
data.MagDamping.Y = 2012;
data.MagDamping.w = [0,deg2rad(-360/90/60),0];
data.MagDamping.verb=1;

%--- Integrate ---%
[t,x] = OrbitProp(x0,tf(1),tf(2:end),data);
%--- POST-PROCESS ---%

%--- Rate plot ---%
figure
plot(t/60,rad2deg(x(:,11)),t/60,rad2deg(x(:,12)),t/60,rad2deg(x(:,13)));
xlabel('Time [min]')
ylabel('Angular rates [deg/s]')
legend('Roll','Pitch','Yaw')
title('Angular rates')

%Calculate Torque
Torque=[];

for i=1:length(t)
 [A,Torque(end+1,1:3),E] = MagDamping(t(i),x(i,:)',data);
end

%--- Torque Plot ---%
figure
plot(t/60,Torque(:,1),t/60,Torque(:,2),t/60,Torque(:,3))
xlabel('Time [mins]');
ylabel('Torque [Nm]');
legend('x Torquer','y Torquer','z Torquer');
title('Torque Plot');


%--- Power & Energy Plots ---%
Al = []; %Actuation level
PT = []; %Total Power
PP = []; %Partial Power
% Power per actuation level Am2 of actuators (parameter that needs
% adjusting to every case)
px = 0.57/0.2;
py = 0.2/0.2;
pz = 0.2/0.2;
p = [px,py,pz];

for i=1:length(t)
    %--- Get magnetic field ---%
    %Latitude and longitude
    we = 7.292115e-5; %Earth Angular velocity in rad/s [source: SMAD 3rd edition]
    Req=6378136.49;   %Equatorial Earth radius m [source: SMAD 3rd edition]
    f=1/298.256;      %Flattening factor [source: SMAD 3rd edition]
    lla=ecef2lla(x(i,1:3),f,Req); %Compute taking assuming Earth as an ellipsoid
    lat=lla(1);
    lon=lla(2);
    h=lla(3);
    %Take into account rotation of the earth
    lon = mod(lon - t(i)*we*180/pi,365);
    if lon>180
        lon = lon-360;
    elseif lon<-180
        lon = lon+360;
    end
    
    %Magnetic field in T
    mfield_ECEF = igrf11magm(h, lat, lon, data.MagDamping.Y)/1e9;
    %Change magnetic field to body axes.
    DCM = quat2dcm([x(i,10),x(i,7:9)]);
    mfield = DCM*mfield_ECEF';
    
    %Preliminary actuation levels m_p
    m_p=(cross(mfield,Torque(i,:))/norm(mfield)^2)';
    %Check different scalar values
    k_max=(data.MagDamping.A'-m_p)./mfield; %Scalar value for maximum actuation level on one axis
    k_min=(-data.MagDamping.A'-m_p)./mfield; %Scalar value for minus maximum actuation level on one axis
    k_0=-m_p./mfield; %Scalar value for 0 actuation level on one axis
    
    %Scan through the different scalar values
    err=1e-3/100;
    m_v=[];
    p_v=[];
    for k=[k_max',k_min',k_0']
        m=m_p+k*mfield;
        
        if abs(m(1))>data.MagDamping.A(1)*(1+err)
            %Solution is not real
            continue
        end
        if abs(m(2))>data.MagDamping.A(2)*(1+err)
            %Solution is not real
            continue
        end
        if abs(m(3))>data.MagDamping.A(3)*(1+err)
            %Solution is not real
            continue
        end
        
       m_v(end+1,1:3) = m;
       p_v(end+1) = sum(abs(m_v(end,:)).*p);
    end
           
   
   % Select the solution has the minmum total power
   [PT(end+1),I] = min(p_v);
   PP(end+1,1:3)= abs(m_v(I,1:3)).*p;
   Al(end+1,1:3) = m_v(I,1:3);
   
end

%Power plot
figure
plot(t/60,PT,t/60,PP(:,1),t/60,PP(:,2),t/60,PP(:,3))
xlabel('Time [mins]');
ylabel('Total Power [W]');
legend('Total Power','x power','y power','z power');
title('Power Plot');

%Actuation level plot
figure
plot(t/60,Al(:,1),t/60,Al(:,2),t/60,Al(:,3))
xlabel('Time [mins]');
ylabel('Actuation Level [Am2]');
legend('x actuation level','y actuation','z actuation');
title('Actuation Level Plot');
