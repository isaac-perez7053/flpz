function plot_flexocoupleElec()
    % Clear workspace and command window
    clc;

    % Run the script that defines the variables. DEFINE PATH
    run('../../../Downloads/Personal_Projects/abinit-9.10.3/perovskites/CaTiO3_Pm3m/flexoElec/script/Datasets.m');

    % Check if a_vec and b_vec exist (assuming these are your perturbation amplitudes)
    if ~exist('a_vec', 'var') || ~exist('b_vec', 'var')
        error('Required variables a_vec and b_vec not found after running Datasets.m');
    end

    % Find all mu matrices
    mu_vars = who('mu*');
    n = length(mu_vars);
    if n == 0
        error('No mu matrices found after running Datasets.m');
    end

    % Check dimensions
    for i = 1:n
        if ~isequal(size(eval(mu_vars{i})), [54, 1])
            error(['Matrix ' mu_vars{i} ' does not have the expected dimensions of 54x1']);
        end
    end

    % Prompt user for component selection
    disp('Enter the component you want to plot (1-54):');
    selected_component = input('Component: ');
    if isempty(selected_component) || selected_component < 1 || selected_component > 54
        error('Invalid input. Please enter a number between 1 and 54.');
    end

    % Prepare data for plotting
    [A, B] = meshgrid(a_vec, b_vec);
    Z = zeros(length(b_vec), length(a_vec));

    for i = 1:length(a_vec)
        for j = 1:length(b_vec)
            mu_index = sub2ind([length(a_vec), length(b_vec)], i, j);
            mu = eval(mu_vars{mu_index});
            Z(j,i) = mu(selected_component);
        end
    end

    % Create the surface plot
    figure;
    surf(A, B, Z);

    % Add labels and title with LaTeX interpreter
    xlabel('Perturbation Amplitude $a$', 'Interpreter', 'latex', 'FontSize', 14);
    ylabel('Perturbation Amplitude $b$', 'Interpreter', 'latex', 'FontSize', 14);
    zlabel(['$\mu_{' num2str(selected_component) '} (\frac{nC}{m})$'], 'Interpreter', 'latex', 'FontSize', 14);
    title(['Flexoelectric Tensor Component $\mu_{' num2str(selected_component) '}$ vs. Perturbation Amplitudes'], 'Interpreter', 'latex', 'FontSize', 16);

    % Customize the appearance
    colorbar;
    shading interp;
    set(gca, 'FontSize', 12);
    set(gcf, 'Color', 'white');

    % Adjust figure size for better visibility
    set(gcf, 'Position', [100, 100, 800, 600]);
end