function p = motorFaultParams()
%MOTORFAULTPARAMS Centralised motor and fault simulation parameters.
%
%   P = MOTORFAULTPARAMS()
%
%   Returns a struct P with sub-structs for the motor, each fault class,
%   data generation settings, and feature extraction settings.
%   All numeric values use SI units unless noted.
%
%   Changing values here propagates to generateMotorData, preprocessVibration,
%   extractFreqFeatures, and extractEnvFeatures automatically.

%% Motor (BLDC, ~750 W, 4-pole, ~3000 RPM nominal)
p.motor.speedRPM        = 3000;           % nominal shaft speed, RPM
p.motor.speedRadS       = 3000/60 * 2*pi; % rad/s
p.motor.poles           = 4;
p.motor.supplyFreqHz    = 50;             % electrical supply frequency, Hz
p.motor.bearingBPFO     = 3.585 * p.motor.speedRPM/60; % Hz, outer-race defect freq
p.motor.bearingBPFI     = 5.415 * p.motor.speedRPM/60; % Hz, inner-race defect freq
p.motor.bearingBSF      = 2.357 * p.motor.speedRPM/60; % Hz, ball spin freq

%% Data generation
p.data.fs               = 5000;   % sample rate, Hz
p.data.durationS        = 2.0;    % seconds per sample window
p.data.numSamplesPerClass = 200;  % windows per fault class
p.data.noiseStd         = 0.02;   % baseline Gaussian noise std (g)
p.data.axes             = {'x','y','z'};

%% Fault class definitions
p.faults.labels   = ["Normal","BearingFault","RotorImbalance","ShaftMisalignment","ElectricalFault"];
p.faults.classIDs = 0:4;

%% Fault amplitudes (g, relative to baseline noise)
p.fault.bearing.amplitude   = 0.15;   % tonal amplitude at BPFO/BPFI
p.fault.bearing.nHarmonics  = 3;      % number of harmonics to inject

p.fault.rotor.amplitude     = 0.20;   % 1× shaft frequency
p.fault.rotor.phaseShiftDeg = 45;     % cross-axis phase shift, degrees

p.fault.misalign.amplitude  = 0.18;   % 2× shaft frequency
p.fault.misalign.coupling   = 0.10;   % cross-axis energy fraction

p.fault.electrical.amplitude = 0.12;  % at supply frequency harmonics
p.fault.electrical.modDepth  = 0.25;  % AM modulation depth

%% Preprocessing
p.prep.hpCutoffHz    = 10;    % high-pass filter cutoff, Hz
p.prep.lpCutoffHz    = 2000;  % low-pass filter cutoff, Hz
p.prep.windowSamples = 2048;  % FFT window length (power of 2)
p.prep.overlapFrac   = 0.5;   % window overlap fraction

%% Feature extraction
p.feat.freqBands = [0 100; 100 500; 500 1000; 1000 2000]; % Hz, energy bands
p.feat.envBandHz = [p.motor.bearingBPFO - 50, p.motor.bearingBPFO + 50]; % envelope demod band

end
