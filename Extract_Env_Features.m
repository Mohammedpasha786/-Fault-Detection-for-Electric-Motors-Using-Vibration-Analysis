function feats = extractEnvFeatures(sig, fs, options)
%EXTRACTENVFEATURES Envelope spectrum features for bearing fault detection.
%
%   FEATS = EXTRACTENVFEATURES(SIG, FS)
%   FEATS = EXTRACTENVFEATURES(SIG, FS, 'Prefix', 'ax')
%
%   SIG  - Nx1 double, vibration signal (one axis, one window). Should be
%          bandpass-filtered around the resonance frequency before calling
%          (PREPROCESSVIBRATION does this).
%   FS   - sample rate, Hz.
%
%   Procedure (classic high-frequency resonance technique):
%     1. Rectify and compute the analytic envelope via the Hilbert transform.
%     2. FFT the envelope to get the envelope spectrum.
%     3. Extract energy at BPFO, BPFI, and their first harmonics, plus
%        a broadband noise floor estimate.
%
%   Name-value options:
%     Prefix       (default "sig")
%     BPFOHz       (default from motorFaultParams) outer-race defect frequency
%     BPFIHz       (default from motorFaultParams) inner-race defect frequency
%     BandwidthHz  (default 10) Hz either side of each defect freq to sum

arguments
    sig (:,1) double
    fs  (1,1) double {mustBePositive}
    options.Prefix (1,1) string = "sig"
    options.BPFOHz (1,1) double = 0
    options.BPFIHz (1,1) double = 0
    options.BandwidthHz (1,1) double = 10
end

p   = motorFaultParams();
pre = char(options.Prefix) + "_env_";

bpfo = options.BPFOHz; if bpfo == 0, bpfo = p.motor.bearingBPFO; end
bpfi = options.BPFIHz; if bpfi == 0, bpfi = p.motor.bearingBPFI; end
bw   = options.BandwidthHz;

% --- Analytic envelope via Hilbert transform ---
try
    env = abs(hilbert(sig));
catch
    % Fallback: rectification
    env = abs(sig);
end
env = env - mean(env);   % remove DC

% --- Envelope spectrum ---
N    = numel(env);
Yenv = abs(fft(env)) / N;
half = 1:floor(N/2)+1;
Yenv(2:end-1) = 2 * Yenv(2:end-1);
fenv = (0:numel(half)-1) * (fs/N);
Yenv = Yenv(half);

totalEnvPwr = sum(Yenv.^2);
if totalEnvPwr < 1e-30
    totalEnvPwr = 1e-30;
end

% Helper: fractional energy in a band around a frequency
bandEnergy = @(fc) sum(Yenv(fenv >= fc-bw & fenv <= fc+bw).^2) / totalEnvPwr;

% BPFO energy (1× and 2×)
feats.(pre + "bpfo1x")  = bandEnergy(bpfo);
feats.(pre + "bpfo2x")  = bandEnergy(2*bpfo);

% BPFI energy (1× and 2×)
feats.(pre + "bpfi1x")  = bandEnergy(bpfi);
feats.(pre + "bpfi2x")  = bandEnergy(2*bpfi);

% Noise floor: median energy in bands away from defect frequencies
noiseFreqs = linspace(50, fs/4, 20);
noiseFreqs(abs(noiseFreqs-bpfo) < 3*bw | abs(noiseFreqs-bpfi) < 3*bw) = [];
noisePwr = arrayfun(bandEnergy, noiseFreqs);
feats.(pre + "noiseFloor") = median(noisePwr);

% Signal-to-noise ratios at defect frequencies
feats.(pre + "bpfoSNR") = feats.(pre + "bpfo1x") / max(feats.(pre + "noiseFloor"), 1e-12);
feats.(pre + "bpfiSNR") = feats.(pre + "bpfi1x") / max(feats.(pre + "noiseFloor"), 1e-12);

end
