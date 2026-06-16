function feats = extractFreqFeatures(sig, fs, options)
%EXTRACTFREQFEATURES Frequency-domain features from one vibration window axis.
%
%   FEATS = EXTRACTFREQFEATURES(SIG, FS)
%   FEATS = EXTRACTFREQFEATURES(SIG, FS, 'Prefix', 'ax', 'FreqBands', [...])
%
%   SIG  - Nx1 double, preprocessed vibration signal (one axis, one window).
%   FS   - sample rate, Hz.
%
%   Name-value options:
%     Prefix    (default "sig")  - feature name prefix
%     FreqBands (default from motorFaultParams) - Mx2 [fLow fHigh] Hz, one
%               row per band. Energy in each band is computed and returned
%               as band1_energy, band2_energy, …
%
%   Features extracted:
%     spectralCentroid   - power-weighted mean frequency
%     spectralSpread     - power-weighted std of frequency
%     spectralSkewness   - 3rd spectral moment
%     spectralKurtosis   - 4th spectral moment (detects bearing tone spikes)
%     totalPower         - sum of one-sided PSD
%     band<k>_energy     - fractional energy in the k-th frequency band
%     peakFreq           - frequency of the highest spectral peak (Hz)
%     peakMagnitude      - magnitude at peakFreq

arguments
    sig (:,1) double
    fs  (1,1) double {mustBePositive}
    options.Prefix (1,1) string = "sig"
    options.FreqBands (:,2) double = []
end

p   = motorFaultParams();
pre = char(options.Prefix) + "_";

if isempty(options.FreqBands)
    bands = p.feat.freqBands;
else
    bands = options.FreqBands;
end

N   = numel(sig);
Y   = fft(sig);
half = 1:floor(N/2)+1;
mag  = abs(Y(half)) / N;
mag(2:end-1) = 2 * mag(2:end-1);  % one-sided
f   = (0:numel(half)-1) * (fs/N);

% Normalised power spectrum
pwr = mag.^2;
totalPwr = sum(pwr);

if totalPwr < 1e-30
    totalPwr = 1e-30; % guard against silent signal
end
pwr_norm = pwr / totalPwr;

% Spectral moments
sc  = sum(f .* pwr_norm');         % centroid
ss  = sqrt(sum(((f - sc).^2) .* pwr_norm')); % spread
sk  = sum(((f - sc).^3) .* pwr_norm') / max(ss^3, 1e-30);
ku  = sum(((f - sc).^4) .* pwr_norm') / max(ss^4, 1e-30);

feats.(pre + "spectralCentroid")  = sc;
feats.(pre + "spectralSpread")    = ss;
feats.(pre + "spectralSkewness")  = sk;
feats.(pre + "spectralKurtosis")  = ku;
feats.(pre + "totalPower")        = totalPwr;

% Band energies (fractional)
for k = 1:size(bands, 1)
    mask = f >= bands(k,1) & f < bands(k,2);
    bandEnergy = sum(pwr(mask)) / totalPwr;
    feats.(pre + sprintf('band%d_energy', k)) = bandEnergy;
end

% Peak frequency
[pkMag, pkIdx] = max(mag);
feats.(pre + "peakFreq")      = f(pkIdx);
feats.(pre + "peakMagnitude") = pkMag;

end
