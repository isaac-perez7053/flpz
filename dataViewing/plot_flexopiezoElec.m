function plot_flexopiezoElec()
% Clear workspace and command window
clc;
% Run the script that defines the variables. DEFINE PATH
run('../../../Downloads/Personal_Projects/abinit-9.10.3/perovskites/CaTiO3_Pm3m/flexoElec/script/Datasets_vec1.m');

% Check if x_vec exists
if ~exist('x_vec', 'var')
    error('Required variable x_vec not found after running Datasets.m');
end

% Find all mu matrices
mu_vars = who('mu*');
mu_vars = sort_numeric(mu_vars);
n_mu = length(mu_vars);
if n_mu == 0
    error('No mu matrices found after running Datasets.m');
end

% Find all chi matrices
chi_vars = who('chi*');
chi_vars = sort_numeric(chi_vars);
n_chi = length(chi_vars);
if n_chi == 0
    error('No chi matrices found after running Datasets.m');
end

% Check dimensions
for i = 1:n_mu
    if ~isequal(size(eval(mu_vars{i})), [54, 1])
        error(['Matrix ' mu_vars{i} ' does not have the expected dimensions of 54x1']);
    end
end

for i = 1:n_chi
    if ~isequal(size(eval(chi_vars{i})), [18, 1])
        error(['Matrix ' chi_vars{i} ' does not have the expected dimensions of 18x1']);
    end
end

% Prompt user for mu component selection
disp('Enter the mu components you want to plot (1-54, separated by spaces):');
mu_input = input('Mu Components: ', 's');
mu_selected = str2num(mu_input);
if isempty(mu_selected) || any(mu_selected < 1 | mu_selected > 54)
    error('Invalid input for mu. Please enter numbers between 1 and 54.');
end

% Prompt user for chi component selection
disp('Enter the chi components you want to plot (1-18, separated by spaces):');
chi_input = input('Chi Components: ', 's');
chi_selected = str2num(chi_input);
if isempty(chi_selected) || any(chi_selected < 1 | chi_selected > 18)
    error('Invalid input for chi. Please enter numbers between 1 and 18.');
end

% Prepare data for plotting
mu_data = zeros(n_mu, length(mu_selected));
for i = 1:n_mu
    mu = eval(mu_vars{i});
    mu_data(i, :) = mu(mu_selected);
end

chi_data = zeros(n_chi, length(chi_selected));
for i = 1:n_chi
    chi = eval(chi_vars{i});
    chi_data(i, :) = chi(chi_selected);
end

% Create the plot
figure;
yyaxis left;
hold on;
mu_plots = zeros(1, length(mu_selected));
for i = 1:length(mu_selected)
    mu_plots(i) = plot(x_vec, mu_data(:, i), 'LineStyle', ':', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
end
ylabel('$\mu_{i,j} (\frac{nC}{m})$', 'Interpreter', 'latex', 'FontSize', 14);
ax1 = gca;
ax1.YColor = 'b';

yyaxis right;
hold on;
chi_plots = zeros(1, length(chi_selected));
for i = 1:length(chi_selected)
    chi_plots(i) = plot(x_vec, chi_data(:, i), 'LineStyle', '--', 'Marker', 's', 'MarkerSize', 8, 'LineWidth', 1.5);
end
ylabel('$\chi_{i,j} (\frac{C}{m^2})$', 'Interpreter', 'latex', 'FontSize', 14);
ax2 = gca;
ax2.YColor = 'r';

% Add labels and title with LaTeX interpreter
xlabel('$x$ (bohrs)', 'Interpreter', 'latex', 'FontSize', 14);
title('Selected $\mu$ and $\chi$ Components vs. $x$', 'Interpreter', 'latex', 'FontSize', 16);

% Add grid for better readability
grid on;

% Customize the appearance
set(gca, 'FontSize', 16);
set(gcf, 'Color', 'white');

% Add legends
mu_legend = arrayfun(@(x) sprintf('\x03BC_{%d}', x), mu_selected, 'UniformOutput', false);
chi_legend = arrayfun(@(x) sprintf('\x03C7_{%d}', x), chi_selected, 'UniformOutput', false);
legend([mu_plots, chi_plots], [mu_legend, chi_legend], 'Interpreter', 'tex', 'Location', 'best');

% Adjust figure size for better visibility
set(gcf, 'Position', [100, 100, 1000, 600]);

hold off;
end

function sorted_vars = sort_numeric(var_names)
    % Extract numbers from variable names
    numbers = cellfun(@(x) str2double(regexp(x, '\d+', 'match')), var_names);
    
    % Sort based on the extracted numbers
    [~, idx] = sort(numbers);
    sorted_vars = var_names(idx);
end

% Components of interest are Mu 1 2 3 22 and Chi 1 2 3 11