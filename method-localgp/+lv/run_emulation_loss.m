function run_emulation_loss( which_objective, which_data, id )


%% Prepare workspace

% Random seed
rng default

% Load data
load( fullfile('Simulations', 'Design4D', 'Simulations4D') );


%% Variables

% Training data
x_train = XTrain4D.Variables;
y_train = YTrain4D.Variables;

[n_train, d] = size(x_train);

% Inferential data
switch which_data
    case 'test'
        % Inferential data
        y_test = YTest4D.Variables;
        data   = y_test(id,:);
    case 'hao'
        % Use hao data
        tmp  = load('DataHao');
        data = tmp.data(id,:);
end

% Standardize simulations
[y_train, y_train_mean, y_train_std] = zscore(y_train);

% Shift data
data = (data - y_train_mean) ./ y_train_std;


%% Losses

% Initialize loss
loss_euclid_train = NaN(n_train, 1);
loss_mahal_train  = NaN(n_train, 1);
cov_mat = cov(y_train);

% Calculate losses
for i = 1:n_train
    % Euclidean
    loss_euclid_train(i,1) = norm( y_train(i,:) - data ).^2;
    % Mahalanobis
    loss_mahal_train(i,1)  = ( y_train(i,:) - data ) * (cov_mat \ ( y_train(i,:) - data )');
end


%% Optimize

% Bounds
lb = 0.1 * ones(1,d);
ub =   5 * ones(1,d);

% Options for localgp
nn_searcher = createns(x_train);
gp_options  = {'K', 100, ...
    'Searcher', nn_searcher, ...
    'KernelFunction', 'ardsquaredexponential', ...
    'Sigma', 1e-2};

% Objective
switch which_objective
    case 'loss'
        loss_euclid_fcn = @(x_new) localgp(x_new, x_train, loss_euclid_train, gp_options{:});
        loss_mahal_fcn  = @(x_new) localgp(x_new, x_train, loss_mahal_train,  gp_options{:});
    case 'log_loss'
        loss_euclid_fcn = @(x_new) log( localgp(x_new, x_train, loss_euclid_train, gp_options{:}) + 1 );
        loss_mahal_fcn  = @(x_new) log( localgp(x_new, x_train, loss_mahal_train,  gp_options{:}) + 1 );
    otherwise
        error('which_objective can only be loss or log_loss')
end

% Starting point
x0 = mean([ub; lb]);

% Global search
gs = GlobalSearch('NumTrialPoints', 2000, 'NumStageOnePoints', 400);
prob_euclid = createOptimProblem('fmincon', ...
    'objective', loss_euclid_fcn, ...
    'x0', x0, ...
    'lb', lb, ...
    'ub', ub);
prob_mahal = createOptimProblem('fmincon', ...
    'objective', loss_mahal_fcn, ...
    'x0', x0, ...
    'lb', lb, ...
    'ub', ub);
[x_best_euclid, f_best_euclid] = run(gs, prob_euclid);
[x_best_mahal,  f_best_mahal]  = run(gs, prob_mahal);

% Gradient
hess_euclid = hessian(loss_euclid_fcn, x_best_euclid);
hess_mahal  = hessian(loss_mahal_fcn,  x_best_mahal);


%% Save

% Process filename parts
data_string_save      = capitalize( which_data );
objective_string_save = capitalize( split(which_objective, '_') );
objective_string_save = horzcat( objective_string_save{:} );

% Filename
save_name = sprintf('EmulationLoss_Objective%s_MethodGS_Data%s_Row%d', ...
    objective_string_save, data_string_save, id);

% Save
save( fullfile('Results', 'EmulationLoss', 'SigmaInit1e-2', save_name), ...
      'x_best_euclid', 'f_best_euclid', 'hess_euclid', ...
      'x_best_mahal',  'f_best_mahal',  'hess_mahal' )


end


