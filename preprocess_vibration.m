function [clean, meta] = preprocessVibration(raw, options)
%PREPROCESSVIBRATION Filter, normalise, and segment raw vibration windows.
%
%   [CLEAN, META] = PREPROCESSVIBRATION(RAW)
%   [CLEAN, META] = PREPROCESSVIBRATION(RAW, 'Fs', 5000, 'Normalise', true)
%
%   RAW  - table with columns ax, ay, az (and optionally time, faultClass,
%          windowID), as produced by GENERATEMOTORDATA or read from a CSV.
%
%   Name-value options:
%     Fs          (default from motorFaultParams) sample rate, Hz
%     HpCutoff    (default from params) high-pass cutoff, Hz
%     LpCutoff    (default from params) low-pass cutoff, Hz
%     Normalise   (default true)  z-score each axis across the window
%     RemoveDC    (default true)  subtract per-window mean before filtering
%
%   CLEAN - table with same schema as RAW but columns ax, ay, az replaced
%           with filtered (and optionally normalised) signals. All original
%           columns (faultClass, windowID, time) are preserved.
%   META  - struct: fs, hpCutoff, lpCutoff, normalised, nSamples

arguments
    raw table
    options.Fs (1,1) double = 0          % 0 = read from params
    options.HpCutoff (1,1) double = 0
    options.LpCutoff (1,1) double = 0
    options.Normalise (1,1) logical = true
    options.RemoveDC (1,1) logical = true
end

p = motorFaultParams();

fs = options.Fs;       if fs == 0,       fs = p.data.fs;           end
hp = options.HpCutoff; if hp == 0,       hp = p.prep.hpCutoffHz;   end
lp = options.LpCutoff; if lp == 0,       lp = p.prep.lpCutoffHz;   end

axes = {'ax','ay','az'};
for k = 1:numel(axes)
    col = axes{k};
    if ~ismember(col, raw.Properties.VariableNames)
        error('preprocessVibration:MissingColumn', ...
            'Column "%s" not found in input table.', col);
    end
end

clean = raw;

for k = 1:numel(axes)
    col = axes{k};
    sig = double(raw.(col));

    % Remove DC offset per window
    if options.RemoveDC
        sig = sig - mean(sig);
    end

    % Bandpass filter (high-pass + low-pass)
    try
        sig = bandpass(sig, [hp, lp], fs);
    catch
        % Signal Processing Toolbox may not be present — use simple
        % Butterworth IIR via butter/filtfilt if available, else skip.
        try
            [b,a] = butter(4, [hp, lp]/(fs/2), 'bandpass');
            sig = filtfilt(b, a, sig);
        catch
            warning('preprocessVibration:NoFilter', ...
                'Could not apply bandpass filter (Signal Processing Toolbox not available). Proceeding without filtering.');
        end
    end

    % Z-score normalisation across this window
    if options.Normalise
        mu  = mean(sig);
        sig_std = std(sig);
        if sig_std > 1e-12
            sig = (sig - mu) / sig_std;
        end
    end

    clean.(col) = sig;
end

meta = struct('fs', fs, 'hpCutoff', hp, 'lpCutoff', lp, ...
    'normalised', options.Normalise, 'nSamples', height(raw));

end
