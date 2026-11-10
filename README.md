# Estimação do estado de carga (SoC) de uma célula LiFePO4: contagem de Coulomb, EKF, filtro de partículas e LSTM

Códigos dos trabalhos finais de quatro disciplinas do Programa de Pós-Graduação em Engenharia de Sistemas e Automação (PPGESA/UFLA, 2026/2). Todos usam a mesma célula simulada e a mesma cadeia de avaliação.

| Disciplina | Artigo | Pasta |
|---|---|---|
| PESI004 – Sistemas de Controle Automotivo | CC × EKF × LSTM | `matlab_cc_ekf/` e `lstm_colab/` |
| Concepção de Veículos Inteligentes | EKF × filtro de partículas | `filtro_particulas/` (usa os dados gerados em `matlab_cc_ekf/`) |
| PSI525 – Identificação de Sistemas Dinâmicos | LSTM como modelo caixa-preta (sensor virtual do SoC) | `lstm_colab/` e `analises_python/analise_identificacao.py` |
| PSI534 – Introdução às Redes Neurais Artificiais | Projeto da rede LSTM, inicializações e comitê | `lstm_colab/` e `analises_python/analise_redes.py` |

## Célula e modelo

- Célula LiFePO4 18650 de 1400 mAh. Parâmetros de C. A. Villarraga Solís, dissertação de mestrado (2025): Tabela 7 (ECM a 20 °C), Tabela 6 (capacidade de 1,462 Ah) e Tabela 11 (P0, Q e R do EKF).
- A célula simulada usa o ECM de **três** ramos RC da Tabela 7, com passo de 0,02 s. Os estimadores usam **um** ramo RC, com passo de 1 s.
- Os ramos RC são discretizados na forma exata: `V[k+1] = a·V[k] + R·(1−a)·i[k]`, com `a = exp(−T/(R·C))`.
- Sensores simulados a cada 1 s: ruído de base na corrente (14,6 mA) e na tensão (2,83 mV), mais os cenários de *bias* de 0,15 A e de ruído de variância 0,2 A² da referência.
- Perfis de teste: val100 (validação da referência), FUDS e US06. A corrente dos ciclos FUDS, US06 e DST (`matlab_cc_ekf/perfis_padrao/`) vem dos ensaios públicos do CALCE (University of Maryland), escalada para a célula e sem regeneração.

Todos os resultados são de simulação. Os parâmetros da LSTM e as covariâncias dos filtros serão ajustados de novo com dados de ensaio.

## Pastas

### `matlab_cc_ekf/` (MATLAB, testado no R2025b)
| Arquivo | Função |
|---|---|
| `configuracao.m` | Todos os ajustes (modo AF/AP, passos, sensores, P0/Q/R, SoC inicial) |
| `parametros_bat.m`, `coef_rc.m` | Parâmetros da célula (Tabelas 5, 6 e 7) e coeficientes dos ramos RC |
| `perfil_*.m` | Perfis de corrente (HPPC, val100, val60, degraus, aleatórios, ciclos padrão) |
| `simulacao_dados.m`, `ecm3_passo.m`, `sensores_simulados.m` | Célula de três ramos RC e sensores |
| `cc_bat.m`, `cc_passo.m` | Contagem de Coulomb |
| `ekf_bat.m`, `ekf_passo.m`, `ecm_passo.m` | EKF de um ramo RC |
| `metricas_erro.m` | RMSE, erro máximo, convergência e tempo (mesma função usada para a LSTM) |
| `gerar_dados_lstm_v10.m`, `rodar_cenarios.m`, `exportar_csv.m` | Gera os .csv de treino, validação e teste (corrente, tensão e SoC a 1 s) |
| `comparacao_final.m` | Comparação final CC × EKF × LSTM (tabela e figuras do artigo de Controle) |
| `main.m` | Roda um perfil com CC e EKF e mostra os gráficos |
| `carregar_dados_reais.m` | Leitura de dados de ensaio no mesmo formato (etapa futura) |

Arquivos `*_hppc.m`, `simulacao_bat.m`, `figuras_artigo.m` e `figuras_slides.m` são da apresentação parcial (ECM de um ramo, passo de 0,02 s).

### `lstm_colab/` (Python, Google Colab)
`L2_LSTM_SoC.ipynb`: rede com uma camada LSTM e saída linear em PyTorch. Entradas: corrente e tensão medidas; saída: SoC a cada 1 s. Escolha de neurônios e taxa de aprendizado pela validação, treino com 10 sementes e comitê (média das 10 redes). Os .csv gerados no MATLAB são lidos de uma pasta do Google Drive (ajustar o caminho na primeira célula).

### `filtro_particulas/` (MATLAB)
Filtro de partículas com reamostragem de baixa variância e comparação com o EKF e a CC. Ordem de execução e descrição de cada arquivo em `LEIA.md`. O caminho da pasta de dados fica no início de `teste_rapido_fp.m`, `validacao_fp.m`, `teste_final_fp.m` e `video_nuvem_fp.m`.

### `analises_python/`
Análises feitas sobre as previsões já salvas da LSTM (não treinam a rede):
- `analise_identificacao.py`: FIT em simulação livre, erro por faixa de SoC e análise de resíduos (FAC e FCC).
- `analise_redes.py`: busca de hiperparâmetros, efeito das sementes e comitês de 5 e 10 redes.

Precisam de `numpy`, `pandas` e `matplotlib`; os caminhos ficam no bloco de configurações no início de cada arquivo.

## Ordem para reproduzir
1. MATLAB: `gerar_dados_lstm_v10` (gera os .csv de treino, validação e teste).
2. Colab: `L2_LSTM_SoC.ipynb` (treina as redes e salva as previsões).
3. MATLAB: `comparacao_final` (CC × EKF × LSTM).
4. MATLAB: pasta `filtro_particulas/`, na ordem do `LEIA.md`.
5. Python: `analise_identificacao.py` e `analise_redes.py`.

## Autor
Jônatas H. G. Braga – PPGESA/UFLA. Orientador: Prof. André Murilo de Almeida Pinto.
