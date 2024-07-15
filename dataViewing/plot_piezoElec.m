function plot_piezoElec()
% Clear workspace and command window
clc;
% Run the script that defines the variables. DEFINE PATH
run('../../../Downloads/Personal_Projects/abinit-9.10.3/perovskites/CaTiO3_Pm3m/flexoElec/script/Datasets.m');

% Check if x_vec exists
if ~exist('x_vec', 'var')
    error('Required variable x_vec not found after running Datasets.m');
end

% Find all piezoelectric (chi) matrices
chi_vars = who('chi*');
chi_vars = sort_numeric(chi_vars);
n = length(chi_vars);
if n == 0
    error('No chi matrices found after running Datasets.m');
end

% Check dimensions (shouldn't be an issue)
for i = 1:n
    if ~isequal(size(eval(chi_vars{i})), [18, 1])
        error(['Matrix ' chi_vars{i} ' does not have the expected dimensions of 18x1']);
    end
end

% Prompt user for component selection
disp('Enter the components you want to plot (1-18, separated by spaces):');
user_input = input('Components: ', 's');
selected_components = str2num(user_input);
if isempty(selected_components) || any(selected_components < 1 | selected_components > 18)
    error('Invalid input. Please enter numbers between 1 and 18.');
end

% Prepare data for plotting
plot_data = zeros(n, length(selected_components));
for i = 1:n
    chi = eval(chi_vars{i});
    plot_data(i, :) = chi(selected_components);
end

% Create the plot
figure;
hold on;
for i = 1:length(selected_components)
    plot(x_vec, plot_data(:, i), 'LineStyle', ':', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
end

% Add labels and title with LaTeX interpreter
xlabel('$x$ (bohrs)', 'Interpreter', 'latex', 'FontSize', 14);
ylabel('$\chi_{i,j} (\frac{C}{m^2})$', 'Interpreter', 'latex', 'FontSize', 14);
title('Selected $\chi$ Components vs. $x$', 'Interpreter', 'latex', 'FontSize', 16);

% Add grid for better readability
grid on;

% Customize the appearance
set(gca, 'FontSize', 16);
set(gcf, 'Color', 'white');

% Add a legend
legend_labels = arrayfun(@(x) sprintf('\\chi_{%d}', x), selected_components, 'UniformOutput', false);
legend(legend_labels, 'Interpreter', 'tex', 'Location', 'best');

% Adjust figure size for better visibility
set(gcf, 'Position', [100, 100, 800, 600]);

hold off;
end

function sorted_vars = sort_numeric(var_names)
    % Extract numbers from variable names
    numbers = cellfun(@(x) str2double(regexp(x, '\d+', 'match')), var_names);
    
    % Sort based on the extracted numbers
    [~, idx] = sort(numbers);
    sorted_vars = var_names(idx);
end
