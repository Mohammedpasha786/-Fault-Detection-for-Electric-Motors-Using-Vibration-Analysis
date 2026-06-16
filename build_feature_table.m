function featureTable = buildFeatureTable(dataDir, options)
%BUILDFEATURETABLE Load all class CSVs, extract features, return labelled table.
%
%   FEATURETABLE = BUILDFEATURETABLE()
%   FEATURETABLE = BUILDFEATURETABLE('DataDir', 'data/synthetic')
%
%   For each class CSV produced by GENERATEMOTORDATA, this function:
%     1. Groups rows by windowID.
%     2. Preprocesses each window (PREPROCESSVIBRATION).
%     3. Extracts time, frequency, and envelope features for each of the
%        three accelerometer axes (ax, ay, az).
%     4. Appends a 'faultClass' and 'faultLabel' column.
%
%   Returns a table with one row per window and one column per feature,
%   ready for training with TRAINCLASSIFIER or FITCSVM.
%
%   Name-value options:
%     DataDir  (default 'data/synthetic')
%     Verbose  (default true)
%     MaxWindows (default Inf) - cap windows per class (useful for quick tests)

arguments
    options.DataDir (1,1) string = "data/synthetic"
    options.Verbose (1,1) logical = true
    options.MaxWindows (1,1) double = Inf
end

p       = motorFaultParams();
fs      = p.data.fs;
labels  = p.faults.labels;
ids     = p.faults.classIDs;
axNames = {'ax','ay','az'};

featureTable = table();

for c = 1:numel(ids)
    classID = ids(c);
    label   = labels(c);
    fname   = fullfile(char(options.DataDir), ...
        sprintf('class%d_%s.csv', classID, label));

    if ~isfile(fname)
        warning('buildFeatureTable:FileNotFound', ...
            'CSV not found: %s  (run generateMotorData first)', fname);
        continue
    end

    raw = readtable(fname, 'TextType', 'string');

    windows = unique(raw.windowID);
    nW = min(numel(windows), options.MaxWindows);

    if options.Verbose
        fprintf('  Class %-22s: %d windows\n', label, nW);
    end

    for wi = 1:nW
        w    = windows(wi);
        wdat = raw(raw.windowID == w, :);

        % Preprocess
        try
            wdat = preprocessVibration(wdat);
        catch ME
            warning('buildFeatureTable:PrepFailed', ...
                'Preprocessing failed for class %d window %d: %s', classID, w, ME.message);
            continue
        end

        % Initialise flat feature struct for this window
        rowFeats = struct();

        for k = 1:numel(axNames)
            ax  = axNames{k};
            sig = double(wdat.(ax));
            pre = string(ax);

            tf  = extractTimeFeatures(sig, 'Prefix', pre);
            ff  = extractFreqFeatures(sig, fs, 'Prefix', pre);
            ef  = extractEnvFeatures(sig,  fs, 'Prefix', pre);

            rowFeats = mergeStructs(rowFeats, tf);
            rowFeats = mergeStructs(rowFeats, ff);
            rowFeats = mergeStructs(rowFeats, ef);
        end

        rowFeats.faultClass = classID;
        rowFeats.faultLabel = label;

        featureTable = [featureTable; struct2table(rowFeats)]; %#ok<AGROW>
    end
end

% Ensure faultLabel is categorical for classifiers
if ~isempty(featureTable)
    featureTable.faultLabel = categorical(featureTable.faultLabel);
end

if options.Verbose
    fprintf('buildFeatureTable: %d windows × %d features\n', ...
        height(featureTable), width(featureTable)-2);
end

end

% ------------------------------------------------------------------
function s = mergeStructs(s, t)
%MERGESTRUCTS Append fields of struct T into struct S.
fields = fieldnames(t);
for k = 1:numel(fields)
    s.(fields{k}) = t.(fields{k});
end
end
