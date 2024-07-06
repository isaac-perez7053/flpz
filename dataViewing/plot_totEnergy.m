% Script to read variables from another file and plot them
function plot_totEnergy()

% Run the script that defines the variables. DEFINE PATH
run('../../../Downloads/Personal_Projects/abinit-9.10.3/perovskites/BaTiO3_Pm3m/flexoElec/Datasets.m');

% Check if the variables exist and have the same size
if ~exist('x_vec', 'var') || ~exist('totEnergy_vec', 'var')
    error('Required variables x_vec and/or totEnergy_vec not found after running Datasets.m');
end

if length(x_vec) ~= length(totEnergy_vec)
    error('x_vec and totEnergy_vec must have the same length.');
end

% Create the plot
figure;
plot(x_vec, totEnergy_vec, 'LineStyle', ':', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.5);

% Add labels and title with LaTeX interpreter
xlabel('$x$ (bohrs)', 'Interpreter', 'latex', 'FontSize', 18);
ylabel('Total Energy (Ha)', 'Interpreter', 'latex', 'FontSize', 18);
title('Total Energy vs. $x$', 'Interpreter', 'latex', 'FontSize', 30);

% Add grid for better readability
grid on;

% Customize the appearance
set(gca, 'FontSize', 16);
set(gcf, 'Color', 'white');

% Optional: Add a legend if needed
% legend('Total Energy', 'Interpreter', 'latex');

% Adjust figure size for better visibility
set(gcf, 'Position', [100, 100, 800, 600]);

