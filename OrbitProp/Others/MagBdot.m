function [A,T,E] = MagBdot(t,y,data)
% BdotDamping is a model that to use magnetorquer to damp undesired initial
% rotation rate after satellites are deployed from launcher. The acuation
% level required to drive magnetorquer is calculated from changing of
% magnetic field (Bdot) which is roughly calculated by product of angular
% rate and current magnetic field. 

% The Earth magnetic field is modeled using the IGRF-11 and therefore the
% model requires the igrf11magm MATLAB function.
%
% Parameters:
% data.MagBdot.A = [0.2,0.2,0.2]  -> Magnetorquer Actuation Level 

% data.MagBdot.C = 2e-4 -> Control Factor, Scalar

% data.MagBdot.w -> Body rate bias rad/s

%--- Copyright notice ---%
% Copyright 2012-2013 Cranfield University
% Written by Josep Virgili and Daniel Zhou Hao
%
% This file is part of the AstroLab
%
% AstroLab is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% AstroLab is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with AstroLab.  If not, see <http://www.gnu.org/licenses/>.

%--- CODE ---%

%--- Get magnetic field ---%
%Latitude and longitude
we = 7.292115e-5; %Earth Angular velocity in rad/s [source: SMAD 3rd edition]
Req=6378136.49;   %Equatorial Earth radius m [source: SMAD 3rd edition]
f=1/298.256;      %Flattening factor [source: SMAD 3rd edition]
lla=ecef2lla(y(1:3)',f,Req); %Compute taking assuming Earth as an ellipsoid
lat=lla(1);
lon=lla(2);
h=lla(3);
%Take into account rotation of the earth
lon = mod(lon - t*we*180/pi,365);
if lon>180
    lon = lon-360;
elseif lon<-180
    lon = lon+360;
end

%Magnetic field in T
mfield_ECEF = igrf11magm(h, lat, lon, data.MagBdot.Y)/1e9;
%Change magnetic field to body axes.
DCM = quat2dcm([y(10),y(7:9)']);
mfield = DCM*mfield_ECEF';

%  Checking if detumbling mode should be active
if norm(rad2deg(y(11:13))) < 0.01
    Bdot = [0 0 0]';
    m = [0 0 0]';
else
%  Calculate Actuation Level
   Bdot = cross(mfield,(y(11:13))); 
   m = -1*(data.MagBdot.C) * Bdot;
end

% Check if actuation level saturated
    if abs(m(1))>data.MagBdot.A(1)
        %Adjust to maximum
        m(1)=sign(m(1))*data.MagBdot.A(1);
    end
    if abs(m(2))>data.MagBdot.A(2)
        %Adjust to maximum
        m(2)=sign(m(2))*data.MagBdot.A(2);
    end
    if abs(m(3))>data.MagBdot.A(3)
        %Adjust to maximum
        m(3)=sign(m(3))*data.MagBdot.A(3);
    end
    
T = cross(m,mfield);

%Acceleration (this model don't produce linear acceleration)
A=[0;0;0];
%Extra state variables (this model doesn't need extra state variables)
E=zeros(1,length(y)-13);

%Torque is not achievable, actuators saturate, get the nearest one.
if data.MagBdot.verb; disp('Magnetic torquers saturating'); end;

end


