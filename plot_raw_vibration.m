function fig = plotRawVibration(data, options)
%PLOTRAWVIBRATION Plot time-domain + FFT of one vibration window.
%
%   FIG = PLOTRAWVIBRATION(DATA)
%   FIG = PLOTRAWVIBRATION(DATA, 'Fs', 5000, 'Title', 'Bearing Fault')
%
%   DATA  - table with columns ax, ay, az (and optionally time).
%           If 'time' column is absent, a time vector is synthesised from Fs.
%
%   Name-value options:
%     Fs      (default from motorFaultParams) sample rate, Hz
%     Title   (default "") figure title string
%     MaxRows (default 2048) max samples to plot (avoids slow rendering)

arguments
    data table
    options.Fs (1,1) double = 0
    options.Title (1,1) string = ""
    options.MaxRows (1,1) double = 2048
end

p  = motorFaultParams();
fs = options.Fs; if fs == 0, fs = p.data.fs; end

nr = min(height(data), options.MaxRows);
data = data(1:nr, :);

if ismember('time', data.Properties.VariableNames)
    t = data.time;
else
    t = (0:nr-1)' / fs;
end

axes_names = {'ax','ay','az'};
colors = lines(3);

fig = figure('Name', char(options.Title));
tiledlayout(3, 2, 'TileSpacing', 'compact');

for k = 1:3
    col = axes_names{k};
    sig = double(data.(col));
    N   = numel(sig);

    % --- Time domain ---
    nexttile;
    plot(t, sig, 'Color', colors(k,:), 'LineWidth', 0.8);
    xlabel('Time (s)'); ylabel(sprintf('%s (g)', col));
    title(sprintf('%s - time domain', col));
    grid on;

    % --- Frequency domain (one-sided magnitude) ---
    nexttile;
    Y   = abs(fft(sig)) / N;
    f   = (0:N-1) * (fs/N);
    half = 1:floor(N/2);
    Y(half(2:end)) = 2 * Y(half(2:end)); % double for one-sided
    plot(f(half), Y(half), 'Color', colors(k,:), 'LineWidth', 0.8);
    xlabel('Frequency (Hz)'); ylabel('|X(f)| (g)');
    title(sprintf('%s - FFT', col));
    xlim([0, min(2500, fs/2)]);
    grid on;
end

if options.Title ~= ""
    sgtitle(options.Title);
end

end
