# fp_matlab — Filtro de partículas × EKF (trabalho final de Concepção)

Pasta independente: tudo o que o FP precisa está aqui. Os dados (.csv a 1 s) continuam em
`SISTEMAS DE CONTROLE AUTOMOTIVO\resultados ekf\dados_lstm_v10`.

## Arquivos
Cópias sem mudança do trabalho de controle (o EKF é o mesmo):
`parametros_bat.m`, `coef_rc.m`, `ekf_passo.m`, `cc_passo.m`, `metricas_erro.m`, `aplicar_estilo_artigo.m`.

Novos:
- `fp_passo.m` — um passo do FP (predição, peso pela tensão, Neff, média ponderada, low variance).
- `low_variance.m` — reamostragem low variance (mesmo algoritmo do trabalho 6, devolve índices).
- `fp_bat.m` — FP num perfil inteiro (inicialização da nuvem e laço).
- `ekf_perfil.m`, `cc_perfil.m` — EKF e CC num perfil inteiro.
- `carregar_validacao.m` — lê um perfil de validação e soma bias ou ruído na corrente.
- `teste_rapido_fp.m` — um perfil, um sorteio, figuras e tempo por amostra.
- `validacao_fp.m` — escolhas do FP só na validação, em 3 etapas: `sigma0` → `diversidade` → `N`.
- `carregar_teste.m` — lê um perfil de teste (val100, FUDS, US06) já com o cenário aplicado.
- `figuras_artigo_fp.m` — figuras do artigo (padrão Jöst 2024 / Yang 2016): A = corrente, SoC e erro (FUDS nominal, SoC0 90%) com zoom; B = bias (FUDS, SoC0 100%); C = RMSE e tempo × N (validação). PDF vetorial + PNG 300 dpi em `resultados\figuras_artigo\`.
- `video_nuvem_fp.m` — vídeo MP4 (16:9) da nuvem de partículas no FUDS nominal, SoC0 90%, sorteio 1, + Fig. D (nuvem em t = 0 s, 1 s e 10 min). Confere que o FP é idêntico ao do teste final.
- `teste_final_fp.m` — CC, EKF, FP (σ0 = 5, N = 100) e FP com R = (30 mV)² nos perfis de teste, 20 sorteios.

## Ordem
1. `teste_rapido_fp` (s207, nominal, SoC0 90%, N = 500, σ0 = 5 p.p.).
2. `validacao_fp` com `etapa = 'sigma0'`.
3. Preencher `sigma0_escolhido_pp`, rodar `etapa = 'diversidade'`.
4. Preencher `diversidade_escolhida`, rodar `etapa = 'N'`.
5. `teste_final_fp` (escolhas congeladas: σ0 = 5 p.p., sem diversidade, N = 100).

Resultados em `fp_matlab\resultados\` (.csv, .mat e .png com o nome da etapa/configuração).
