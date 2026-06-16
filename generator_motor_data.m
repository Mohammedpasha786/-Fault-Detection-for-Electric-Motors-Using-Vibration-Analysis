function fileList = generateMotorData(options)
%GENERATEMOTORDATA Simulate electric motor vibration and save to CSV files.
%
%   FILELIST = GENERATEMOTORDATA()
%   FILELIST = GENERATEMOTORDATA('OutputDir', 'data/synthetic', 'Seed', 42)
%
%   Generates synthetic 3-axis accelerometer vibration data (x, y, z) for
%   five fault classes:
%     0 - Normal
%     1 - Bearing Fault   (outer/inner-race tonal noise at BPFO, BPFI)
%     2 - Rotor Imbalance (1× shaft-speed sinusoid)
%     3 - Shaft Misalign  (2× shaft-speed + cross-axis coupling)
%     4 - Electrical Fault (supply-frequency harmonic + AM)
%
%   Each class produces PARAMS.data.numSamplesPerClass windows of length
%   PARAMS.data.durationS seconds at PARAMS.data.fs Hz, written to one
%   CSV per class in OUTPUTDIR.
%
%   Columns per CSV: time, ax, ay, az, faultClass, windowID
%
%   Name-value options:
%     OutputDir (default 'data/synthetic')
%     Seed      (default 42)  - RNG seed for reproducibility
%     Verbose   (default true)

arguments
    options.OutputDir (1,1) string = "data/synthetic"
    options.Seed (1,1) double = 42
    options.Verbose (1,1) logical = true
end

rng(options.Seed);
p = motorFaultParams();

outDir = char(options.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

fs  = p.data.fs;
dur = p.data.durationS;
N   = round(fs * dur);
t   = (0:N-1)' / fs;
nW  = p.data.numSamplesPerClass;

labels   = p.faults.labels;
classIDs = p.faults.classIDs;
fileList = strings(numel(labels), 1);

for c = 1:numel(classIDs)
    classID = classIDs(c);
    label   = labels(c);

    allRows = cell(nW, 1);

    for w = 1:nW
        % --- Baseline noise ---
        ax = p.data.noiseStd * randn(N, 1);
        ay = p.data.noiseStd * randn(N, 1);
        az = p.data.noiseStd * randn(N, 1) + 1.0; % gravity offset on z

        % --- Inject fault signature ---
        switch classID
            case 0 % Normal: only baseline
                % no addition

            case 1 % Bearing fault: harmonics of BPFO and BPFI
                A = p.fault.bearing.amplitude;
                for h = 1:p.fault.bearing.nHarmonics
                    phi = 2*pi*rand();
                    ax = ax + (A/h) * sin(2*pi * h * p.motor.bearingBPFO * t + phi);
                    phi = 2*pi*rand();
                    ay = ay + (A/h) * sin(2*pi * h * p.motor.bearingBPFI * t + phi);
                end
                % Add amplitude modulation (impact pattern)
                impact = (1 + 0.5*sin(2*pi * p.motor.bearingBPFO * t));
                ax = ax .* impact;

            case 2 % Rotor imbalance: 1× shaft speed, phase-shifted across axes
                A   = p.fault.rotor.amplitude;
                f1x = p.motor.speedRadS / (2*pi);
                phi = deg2rad(p.fault.rotor.phaseShiftDeg);
                ax  = ax + A * sin(2*pi * f1x * t);
                ay  = ay + A * sin(2*pi * f1x * t + phi);
                az  = az + (A * 0.3) * sin(2*pi * f1x * t + 2*phi);

            case 3 % Shaft misalignment: 2× shaft speed + cross-axis coupling
                A   = p.fault.misalign.amplitude;
                f2x = 2 * p.motor.speedRadS / (2*pi);
                coupling = p.fault.misalign.coupling;
                ax  = ax + A * sin(2*pi * f2x * t);
                ay  = ay + A * sin(2*pi * f2x * t + pi/4);
                az  = az + coupling * A * sin(2*pi * f2x * t + pi/2);

            case 4 % Electrical fault: supply harmonics + AM
                A    = p.fault.electrical.amplitude;
                fe   = p.motor.supplyFreqHz;
                md   = p.fault.electrical.modDepth;
                mod  = 1 + md * sin(2*pi * fe * t);
                carrier = A * sin(2*pi * 2*fe * t);
                ax  = ax + mod .* carrier;
                ay  = ay + 0.7 * mod .* carrier;
                az  = az + 0.3 * mod .* carrier;
        end

        % Assemble window rows
        classCol  = repmat(classID, N, 1);
        windowCol = repmat(w,       N, 1);
        allRows{w} = [t, ax, ay, az, classCol, windowCol];
    end

    M = vertcat(allRows{:});
    T = array2table(M, 'VariableNames', {'time','ax','ay','az','faultClass','windowID'});

    fname = fullfile(outDir, sprintf('class%d_%s.csv', classID, label));
    writetable(T, fname);
    fileList(c) = string(fname);

    if options.Verbose
        fprintf('  Written %-30s  (%d windows × %d samples)\n', fname, nW, N);
    end
end

if options.Verbose
    fprintf('generateMotorData: done. %d class files in %s\n', numel(labels), outDir);
end

end
