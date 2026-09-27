% RESULTADOS - RMSE e gráficos (rodar pelo main.m)
% Cenário s da condição inicial i e do Q11 c: s = (i-1)*n_q + c

% --- RMSE em % (para comparar com a dissertação) ---
rmse_cc  = sqrt(mean((Soc_cc  - Soc).^2, 2)) * 100;   % RMSE do CC, um por condição inicial (linha i)
rmse_ekf = sqrt(mean((Soc_ekf - Soc).^2, 2)) * 100;   % RMSE do EKF, um por cenário (linha s)

% --- Tabela de RMSE no Command Window ---
fprintf('\nSoC inicial real: %.0f %%\n', Soc0*100);
for i = 1:n_ini                                                   % Uma seção por condição inicial
    fprintf('\n--- SoC inicial assumido: %.0f %% ---\n', lista_Soc0_est(i)*100);
    fprintf('RMSE CC: %.3f %%\n', rmse_cc(i));
    for c = 1:n_q                                                 % Um RMSE de EKF por Q11
        s = (i-1)*n_q + c;                                        % Linha do cenário (condição i, Q11 c)
        fprintf('RMSE EKF (%s): %.3f %%\n', nomes_Q11{c}, rmse_ekf(s));
    end
end

% --- Gráficos: um par de figuras por condição inicial ---
for i = 1:n_ini
    s1 = (i-1)*n_q + 1;                                           % Cenário com Q11 da Tabela 11
    s2 = (i-1)*n_q + 2;                                           % Cenário com Q11 alternativo
    txt_ini = sprintf(' - SoC inicial assumido: %.0f%%', lista_Soc0_est(i)*100);   % Complemento do título

    % Gráfico 1: SoC real vs CC vs EKF
    figure;
    plot(t(idx_plot), Soc(idx_plot), 'k-', 'LineWidth', 1.5);           % SoC real
    hold on;
    plot(t(idx_plot), Soc_cc(i,idx_plot), 'r--', 'LineWidth', 1);       % CC
    plot(t(idx_plot), Soc_ekf(s1,idx_plot), 'b-', 'LineWidth', 1);      % EKF Tabela 11
    plot(t(idx_plot), Soc_ekf(s2,idx_plot), 'g-', 'LineWidth', 1);      % EKF Q11 alternativo
    hold off;
    lgd = legend('SoC (real)', 'SoC (CC)', 'SoC (EKF - Tabela 11)', 'SoC (EKF - Q_{11} alternativo)', 'Location', 'best');
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');
    aplicar_estilo_artigo(['SoC: real vs CC vs EKF' txt_ini], 'Tempo (min)', 'SoC (fração)');

    % Gráfico 2: diagnóstico (erro, P(1,1) e K(1))
    figure;
    subplot(3,1,1);
    plot(t(idx_plot), (Soc_ekf(s1,idx_plot) - Soc(idx_plot))*100, 'b-');   % Erro Tabela 11, em %
    hold on;
    plot(t(idx_plot), (Soc_ekf(s2,idx_plot) - Soc(idx_plot))*100, 'g-');   % Erro Q11 alternativo, em %
    hold off;
    lgd = legend('Tabela 11', 'Q_{11} alternativo', 'Location', 'best');
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');
    aplicar_estilo_artigo(['Erro do SoC (EKF - real)' txt_ini], 'Tempo (min)', 'Erro (%)');

    subplot(3,1,2);
    semilogy(t(idx_plot), P11_hist(s1,idx_plot), 'b-');                    % P(1,1) Tabela 11
    hold on;
    semilogy(t(idx_plot), P11_hist(s2,idx_plot), 'g-');                    % P(1,1) Q11 alternativo
    hold off;
    aplicar_estilo_artigo('P(1,1)', 'Tempo (min)', 'Variância');

    subplot(3,1,3);
    semilogy(t(idx_plot), abs(K1_hist(s1,idx_plot)), 'b-');               % K(1) Tabela 11
    hold on;
    semilogy(t(idx_plot), abs(K1_hist(s2,idx_plot)), 'g-');               % K(1) Q11 alternativo
    hold off;
    aplicar_estilo_artigo('K(1)', 'Tempo (min)', 'Ganho');
end
