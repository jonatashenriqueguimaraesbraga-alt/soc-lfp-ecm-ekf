# Estimação do SoC de célula LiFePO4 com ECM de 1ª ordem: contagem de Coulomb e EKF

Códigos em MATLAB do artigo parcial da disciplina PESI004 – Sistemas de Controle Automotivo (PPGESA/UFLA, 2026/2).

O repositório simula uma célula LiFePO4 18650 (1400 mAh nominais) submetida a um ensaio HPPC sintético e compara três estimativas do estado de carga (SoC):

- contagem de Coulomb (CC);
- filtro de Kalman estendido (EKF) com o Q11 da referência;
- EKF com Q11 alternativo.

## Origem dos parâmetros

R0, R1, C1, OCV(SoC) e a capacidade vêm de C. A. Villarraga Solis, dissertação de mestrado, Universidade de Brasília, 2025. Foram usadas a Tabela 7 (20 °C) e a Tabela 6 (capacidade de 1,462 Ah). As matrizes P0, Q e R do EKF foram tiradas da Tabela 11.

## Modelo

ECM de primeira ordem, com um único ramo RC, discretizado com Ts = 0,02 s:

```
SoC[k+1] = SoC[k] - (Ts*eta/Cn) * i[k]
V1[k+1]  = (1 - Ts/(R1*C1)) * V1[k] + (Ts/C1) * i[k]
Vt[k]    = OCV(SoC[k]) - V1[k] - R0 * i[k]
```

## Arquivos

| Arquivo | Função |
|---|---|
| `main.m` | Roda todo o fluxo (configuração dos SoC iniciais testados) |
| `parametros_bat.m` | Parâmetros da célula (Tabelas 6 e 7 da referência) |
| `perfil_hppc.m` | Perfil de corrente HPPC |
| `simulacao_hppc.m` | Simulação do ECM e dos sensores (ruído e bias) |
| `cc_bat.m` | Contagem de Coulomb |
| `ekf_bat.m` | Filtro de Kalman estendido (P0, Q e R da Tabela 11) |
| `resultados_ekf.m` | Cálculo do RMSE e gráficos |
| `aplicar_estilo_artigo.m`, `salvar_figuras.m` | Padrão visual e exportação das figuras |
| `figuras_artigo.m` | Gera as Figs. 2 e 3 do artigo (PDF vetorial) |

## Como executar

1. Abra a pasta do repositório no MATLAB (testado no R2023b).
2. No Command Window, rode `main`. O EKF leva alguns minutos (2,7 milhões de amostras por cenário).
3. Depois, rode `figuras_artigo`.

As figuras são salvas na subpasta `resultados ekf`, criada dentro da pasta atual.

## Autor

Jônatas Braga – PPGESA/UFLA
