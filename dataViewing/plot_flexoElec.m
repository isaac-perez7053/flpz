function plot_flexoElec()
% Clear workspace and command window
clc;

% Run the script that defines the variables. DEFINE PATH
run('../../../Downloads/Personal_Projects/abinit-9.10.3/perovskites/BaTiO3_Pm3m/flexoElec/Datasets.m');

% Check if x_vec exists
if ~exist('x_vec', 'var')
    error('Required variable x_vec not found after running Datasets.m');
end

% Find all mu matrices
mu_vars = who('mu*');
n = length(mu_vars);

if n == 0
    error('No mu matrices found after running Datasets.m');
end

% Check dimensions. Shouldn't be something to worry about. 
for i = 1:n
    if ~isequal(size(eval(mu_vars{i})), [54, 1])
        error(['Matrix ' mu_vars{i} ' does not have the expected dimensions of 54x1']);
    end
end

% Prompt user for component selection
disp('Enter the components you want to plot (1-54, separated by spaces):');
user_input = input('Components: ', 's');
selected_components = str2num(user_input);

if isempty(selected_components) || any(selected_components < 1 | selected_components > 54)
    error('Invalid input. Please enter numbers between 1 and 54.');
end

% Prepare data for plotting
plot_data = zeros(n, length(selected_components));
for i = 1:n
    mu = eval(mu_vars{i});
    plot_data(i, :) = mu(selected_components);
end

% Create the plot
figure;
hold on;

for i = 1:length(selected_components)
    plot(x_vec, plot_data(:, i), 'LineStyle', ':', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
end

% Add labels and title with LaTeX interpreter
xlabel('$x$ (bohrs)', 'Interpreter', 'latex', 'FontSize', 14);
ylabel('$\mu_{i,j} (\frac{nC}{m})$', 'Interpreter', 'latex', 'FontSize', 14);
title('Selected $\mu$ Components vs. $x$', 'Interpreter', 'latex', 'FontSize', 16);

% Add grid for better readability
grid on;

% Customize the appearance
set(gca, 'FontSize', 16);
set(gcf, 'Color', 'white');

% Add a legend
legend(cellstr(num2str(selected_components', 'Component %d')), 'Interpreter', 'latex', 'Location', 'best');

% Adjust figure size for better visibility
set(gcf, 'Position', [100, 100, 800, 600]);

hold off;
