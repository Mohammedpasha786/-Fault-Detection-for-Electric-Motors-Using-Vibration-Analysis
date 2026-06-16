function [mdl, trainInfo] = trainFaultClassifier(featureTable, options)
%TRAINFAULTCLASSIFIER Train a multiclass fault classifier from feature table.
%
%   [MDL, TRAININFO] = TRAINFAULTCLASSIFIER(FEATURETABLE)
%   [MDL, TRAININFO] = TRAINFAULTCLASSIFIER(FEATURETABLE, 'Type', 'svm')
%
%   FEATURETABLE - table as returned by BUILDFEATURETABLE. Must contain a
%                  'faultLabel' column (categorical).
%
%   Name-value options:
%     Type         (default "ensemble") - "ensemble" (fitcensemble, Bag of
%                   trees) or "svm" (fitcecoc with RBF kernels). Ensemble
%                   requires no toolbox config; SVM requires Statistics and
%                   Machine Learning Toolbox.
%     TrainFrac    (default 0.8) - fraction of data used for training;
%                   remainder becomes the held-out test set.
%     Seed         (default 1)   - RNG seed for reproducible split
%     NumTrees     (default 100) - for ensemble type only
%     Verbose      (default true)
%
%   MDL       - trained CompactClassificationEnsemble or
%               CompactClassificationECOC object (compact for deployment)
%   TRAININFO - struct: trainAcc, testAcc, confMat, classNames,
%               featureNames, testIdx, predLabels, trueLabels

arguments
    featureTable table
    options.Type (1,1) string {mustBeMember(options.Type, ["ensemble","svm"])} = "ensemble"
    options.TrainFrac (1,1) double = 0.8
    options.Seed (1,1) double = 1
    options.NumTrees (1,1) double = 100
    options.Verbose (1,1) logical = true
end

rng(options.Seed);

% --- Separate features from labels ---
excludeCols = {'faultClass','faultLabel'};
featCols = featureTable.Properties.VariableNames;
featCols(ismember(featCols, excludeCols)) = [];

X = table2array(featureTable(:, featCols));
y = featureTable.faultLabel;

if any(any(~isfinite(X)))
    warning('trainFaultClassifier:NonFiniteFeatures', ...
        'Feature matrix contains NaN/Inf values. Replacing with column medians.');
    for k = 1:size(X,2)
        bad = ~isfinite(X(:,k));
        if any(bad)
            X(bad, k) = median(X(~bad, k));
        end
    end
end

% --- Stratified train/test split ---
classes = categories(y);
trainIdx = false(height(featureTable), 1);
for k = 1:numel(classes)
    mask = y == classes{k};
    idx  = find(mask);
    nTrain = round(options.TrainFrac * numel(idx));
    idx  = idx(randperm(numel(idx)));
    trainIdx(idx(1:nTrain)) = true;
end
testIdx = ~trainIdx;

Xtr = X(trainIdx, :);  ytr = y(trainIdx);
Xte = X(testIdx,  :);  yte = y(testIdx);

% --- Train ---
if options.Verbose
    fprintf('Training %s classifier  (%d train / %d test samples)...\n', ...
        options.Type, sum(trainIdx), sum(testIdx));
end

switch options.Type
    case "ensemble"
        try
            mdl = fitcensemble(Xtr, ytr, ...
                'Method', 'Bag', ...
                'NumLearningCycles', options.NumTrees, ...
                'Learners', templateTree('MaxNumSplits', 20));
        catch ME
            if contains(ME.identifier, 'Undefined')
                error('trainFaultClassifier:ToolboxMissing', ...
                    'fitcensemble requires the Statistics and Machine Learning Toolbox.');
            end
            rethrow(ME);
        end

    case "svm"
        try
            t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto', ...
                'Standardize', true);
            mdl = fitcecoc(Xtr, ytr, 'Learners', t);
        catch ME
            if contains(ME.identifier, 'Undefined')
                error('trainFaultClassifier:ToolboxMissing', ...
                    'fitcecoc requires the Statistics and Machine Learning Toolbox.');
            end
            rethrow(ME);
        end
end

% --- Evaluate ---
predTrain = predict(mdl, Xtr);
predTest  = predict(mdl, Xte);

trainAcc = mean(predTrain == ytr);
testAcc  = mean(predTest  == yte);

if options.Verbose
    fprintf('  Train accuracy: %.1f%%\n', 100*trainAcc);
    fprintf('  Test  accuracy: %.1f%%\n', 100*testAcc);
end

% Confusion matrix (counts)
confMat = confusionmat(yte, predTest, 'Order', categories(y));

trainInfo = struct( ...
    'trainAcc',     trainAcc, ...
    'testAcc',      testAcc, ...
    'confMat',      confMat, ...
    'classNames',   {categories(y)}, ...
    'featureNames', {featCols}, ...
    'testIdx',      testIdx, ...
    'predLabels',   predTest, ...
    'trueLabels',   yte);

end
