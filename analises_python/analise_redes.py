# -*- coding: utf-8 -*-
# analise_redes.py
# Trabalho final de PSI534 (Introducao as Redes Neurais Artificiais) - LSTM para estimar o SoC
# Analises sobre os registros e previsoes que JA EXISTEM (rodada 9: 10 redes + comite). Nao treina nada.
# Gera:
#   resultados/grade_hiperparametros.csv   -> RMSE de treino e validacao de cada configuracao testada
#   resultados/sementes.csv                -> treino, validacao, melhor epoca e teste (nominal) de cada semente
#   resultados/metricas_redes.csv          -> RMSE, MSE, MAE e erro maximo: redes individuais x comite
#   resultados/comite_5_10.csv             -> RMSE do comite de 5 (sementes 1-5) e de 10 redes (nominal)
#   figuras/fig_grade_hiperparametros      -> RMSE de treino e validacao por configuracao (1 coluna)
#   figuras/fig_sementes                   -> (a) treino x validacao por semente; (b) teste por semente (1 coluna)
#   figuras/fig_soc_comite_fuds            -> SoC verdadeiro, 10 redes e comite no FUDS; erro (1 coluna)
# Como rodar: abrir no VS Code (ou Spyder) e rodar. Precisa de numpy, pandas e matplotlib.
# Opcional: python analise_redes.py "C:\...\Mestrado automacao"  (pasta-base, se o script mudar de lugar)

# ===================== CONFIGURACOES (mudar so aqui) =====================
from pathlib import Path                      # para montar os caminhos das pastas
import sys                                    # para ler argumento opcional da linha de comando

PASTA_SCRIPT = Path(__file__).resolve().parent                      # pasta deste script (codigo)
PASTA_TRABALHO = PASTA_SCRIPT.parent                                # pasta trabalho_final_lstm (Redes)
PASTA_MESTRADO = PASTA_TRABALHO.parent.parent                       # pasta Mestrado automacao
if len(sys.argv) > 1:                                               # se passar um caminho ao rodar
    PASTA_MESTRADO = Path(sys.argv[1])                              # usa esse caminho como base
PASTA_LSTM = (PASTA_MESTRADO / "SISTEMAS DE CONTROLE AUTOMOTIVO" / "resultados ekf"
              / "resultados_lstm_v10_10s")                          # fonte (SO LEITURA: nada e gravado la)
PASTA_PREV = PASTA_LSTM / "previsoes"                               # previsoes das 10 redes e do comite
PASTA_RES = PASTA_TRABALHO / "resultados"                           # onde salvar os .csv
PASTA_FIG = PASTA_TRABALHO / "figuras"                              # onde salvar as figuras

PERFIS = ["val100", "fuds", "us06"]                                 # perfis de teste
NOME_PERFIL = {"val100": "val100", "fuds": "FUDS", "us06": "US06"}  # nome nas tabelas e figuras
CENARIOS = ["nominal", "ref_bias", "ref_ruido"]                     # cenarios de sensor
NOME_CENARIO = {"nominal": "Nominal", "ref_bias": "Bias 0,15 A", "ref_ruido": "Ruído 0,2 A²"}
N_SORTEIOS = 20                                                     # sorteios de ruido por cenario
N_SEMENTES = 10                                                     # redes treinadas (sementes 1 a 10)
SEMENTES_COMITE5 = [1, 2, 3, 4, 5]                                  # comite da rodada 8 (comparacao)
PERFIL_FIG = "fuds"                                                 # perfil da figura do SoC (fixado antes)
SORTEIO_FIG = 1                                                     # sorteio da figura do SoC (fixado antes)
# ==========================================================================

import numpy as np                            # contas com vetores
import pandas as pd                           # leitura e escrita de tabelas .csv
import matplotlib                             # biblioteca de graficos
matplotlib.use("Agg")                         # desenha sem abrir janela (so salva arquivo)
import matplotlib.pyplot as plt               # funcoes de grafico
import matplotlib.ticker as mticker           # para trocar ponto por virgula nos eixos

# ---------- estilo das figuras (padrao IEEE: 1 coluna = 3,5 pol; texto de 8 pt no tamanho final) ----------
LARG_COLUNA = 3.45                            # largura de 1 coluna do IEEEtran (pol, ~8,8 cm)
FONTE = 8                                     # 8 pt no tamanho final (IEEE pede 8 a 10 pt)
plt.rcParams.update({
    "font.family": "serif",                   # fonte com serifa, como o texto do IEEEtran
    "font.serif": ["Times New Roman", "Liberation Serif", "DejaVu Serif"],
    "mathtext.fontset": "stix",               # simbolos matematicos parecidos com Times
    "font.size": FONTE, "axes.titlesize": FONTE, "axes.labelsize": FONTE,
    "xtick.labelsize": FONTE, "ytick.labelsize": FONTE, "legend.fontsize": FONTE,
    "axes.grid": True, "grid.alpha": 0.35,    # grade clara
    "axes.edgecolor": "black", "axes.linewidth": 0.6,
    "legend.frameon": True, "legend.facecolor": "white", "legend.framealpha": 1.0,
    "axes.unicode_minus": True,               # sinal de menos correto
    "pdf.fonttype": 42,                       # fontes embutidas no PDF
    "savefig.dpi": 300,                       # resolucao do PNG
})
COR = {"val100": "#1b6ca8", "fuds": "#2a9d55", "us06": "#c8553d"}   # uma cor por perfil (igual nas figuras)
MARCA = {"val100": "o", "fuds": "s", "us06": "^"}                   # marcador por perfil (ajuda em P&B)


def virgula(ax, eixo="xy"):                   # numeros dos eixos com virgula decimal
    fmt = mticker.FuncFormatter(lambda v, pos: f"{v:g}".replace(".", ",").replace("-", "\u2212"))
    if "x" in eixo: ax.xaxis.set_major_formatter(fmt)
    if "y" in eixo: ax.yaxis.set_major_formatter(fmt)


def salvar_fig(fig, nome):                    # salva em PDF (vetorial, para o LaTeX) e PNG (para conferir)
    PASTA_FIG.mkdir(parents=True, exist_ok=True)
    for ext in ("pdf", "png"):
        fig.savefig(PASTA_FIG / f"{nome}.{ext}", bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)
    print("  figura salva:", nome)


def taxa_txt(t):                              # 0.0003 -> "3×10⁻⁴" (rotulo do eixo)
    exp = int(np.floor(np.log10(t)))
    man = t / 10 ** exp
    base = f"10$^{{{exp}}}$".replace("-", "\u2212")
    return base if abs(man - 1) < 1e-9 else f"{man:g}×{base}"


# =============== 1. Grade de hiperparametros (registro do treino, validacao com semente 1) ===============
def grade():
    g = pd.read_csv(PASTA_LSTM / "escolha_hiperparametros.csv")
    g = g[g["etapa"].isin(["A_neuronios", "B_taxa"])]                # tira a etapa C (repete a escolhida)
    g = g.drop_duplicates(subset=["n_ocultos", "taxa_aprendizado"])  # 128/0,001 aparece nas etapas A e B
    g = g.sort_values(["etapa", "n_ocultos", "taxa_aprendizado"]).reset_index(drop=True)
    g[["etapa", "n_ocultos", "taxa_aprendizado", "rmse_treino_pct", "rmse_val_pct", "melhor_epoca"]].to_csv(
        PASTA_RES / "grade_hiperparametros.csv", index=False, float_format="%.3f")

    fig, ax = plt.subplots(figsize=(LARG_COLUNA, 2.05))
    x = np.arange(len(g))
    w = 0.38
    ax.bar(x - w / 2, g["rmse_treino_pct"], w, color="#bdbdbd", edgecolor="black", lw=0.4, label="Treino")
    ax.bar(x + w / 2, g["rmse_val_pct"], w, color="#4d4d4d", edgecolor="black", lw=0.4, label="Validação")
    ax.set_yscale("log")
    ax.set_ylim(0.2, 40)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: f"{v:g}".replace(".", ",")))
    rot = [f"{n}\n{taxa_txt(t)}" for n, t in zip(g["n_ocultos"], g["taxa_aprendizado"])]
    ax.set_xticks(x)
    ax.set_xticklabels(rot)
    ax.set_xlabel("Neurônios na camada LSTM e taxa de aprendizado")
    ax.set_ylabel("RMSE (%)")
    n_a = (g["etapa"] == "A_neuronios").sum()                        # separa as duas etapas da busca
    ax.axvline(n_a - 0.5, color="black", lw=0.6, ls="--")
    ax.text((n_a - 1) / 2, 26, "Etapa 1: neurônios", ha="center", va="center")
    ax.text(n_a + (len(g) - n_a - 1) / 2, 26, "Etapa 2: taxa", ha="center", va="center")
    ax.grid(axis="x", visible=False)
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, 1.01), ncol=2)   # legenda acima do grafico
    salvar_fig(fig, "fig_grade_hiperparametros")
    return g


# =============== 2. Sementes: treino, validacao e teste de cada rede ===============
def sementes():
    s = pd.read_csv(PASTA_LSTM / "treino_sementes.csv").sort_values("semente_treino")
    t = pd.read_csv(PASTA_LSTM / "metricas_LSTM_por_semente_treino.csv")   # RMSE medio (20 sorteios) por semente
    t = t[t["cenario_sensor"] == "nominal"].set_index("perfil")
    for p in PERFIS:
        s[f"teste_{p}_pct"] = [t.loc[f"{p}_p3", f"{k:.1f}"] for k in s["semente_treino"]]
    s.to_csv(PASTA_RES / "sementes.csv", index=False, float_format="%.3f")

    m = pd.read_csv(PASTA_LSTM / "metricas_MC_todos_LSTM.csv")
    com = m[(m["metodo"] == "LSTM (comitê de 10)") & (m["cenario_sensor"] == "nominal")]
    rmse_com = {p: com[com["perfil"] == f"{p}_p3"]["rmse_pct"].mean() for p in PERFIS}

    fig, (a1, a2) = plt.subplots(2, 1, figsize=(LARG_COLUNA, 3.9), sharex=True)
    x = s["semente_treino"].to_numpy()
    w = 0.38
    a1.bar(x - w / 2, s["rmse_treino_pct"], w, color="#bdbdbd", edgecolor="black", lw=0.4, label="Treino")
    a1.bar(x + w / 2, s["rmse_val_pct"], w, color="#4d4d4d", edgecolor="black", lw=0.4, label="Validação")
    a1.set_ylabel("RMSE (%)")
    a1.set_title("(a) Treino e validação", loc="left")
    a1.set_ylim(0, 7)
    a1.legend(loc="upper left", ncol=2)
    a1.grid(axis="x", visible=False)
    virgula(a1, "y")

    for p in PERFIS:
        a2.plot(x, s[f"teste_{p}_pct"], ls="none", marker=MARCA[p], ms=4, color=COR[p],
                mec="black", mew=0.3, label=NOME_PERFIL[p])
        a2.axhline(rmse_com[p], color=COR[p], ls="--", lw=0.9)
    a2.plot([], [], color="gray", ls="--", lw=0.9, label="Comitê")     # entrada da legenda para as linhas
    a2.set_yscale("log")
    a2.set_ylim(0.1, 100)
    a2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: f"{v:g}".replace(".", ",")))
    a2.set_ylabel("RMSE no teste (%)")
    a2.set_xlabel("Semente (inicialização dos pesos)")
    a2.set_title("(b) Teste, cenário nominal (média de 20 sorteios)", loc="left")
    a2.set_xticks(x)
    a2.legend(loc="upper left", ncol=4, columnspacing=0.8, handletextpad=0.3)
    fig.tight_layout(h_pad=0.6)
    salvar_fig(fig, "fig_sementes")
    return s, rmse_com


# =============== 3. Metricas: redes individuais x comite ===============
def metricas():
    m = pd.read_csv(PASTA_LSTM / "metricas_MC_todos_LSTM.csv")
    m["mse"] = m["rmse_pct"] ** 2                                     # MSE de cada execucao, em (p.p.)²
    linhas = []
    for c in CENARIOS:
        for p in PERFIS:
            ind = m[(m["metodo"] == "LSTM") & (m["cenario_sensor"] == c) & (m["perfil"] == f"{p}_p3")]
            com = m[(m["metodo"] == "LSTM (comitê de 10)") & (m["cenario_sensor"] == c) & (m["perfil"] == f"{p}_p3")]
            linhas.append({
                "cenario": NOME_CENARIO[c], "perfil": NOME_PERFIL[p],
                "n_ind": len(ind), "n_com": len(com),
                "ind_rmse_media": ind["rmse_pct"].mean(), "ind_rmse_dp": ind["rmse_pct"].std(),
                "ind_rmse_min_semente": ind.groupby("semente_treino")["rmse_pct"].mean().min(),
                "com_rmse_media": com["rmse_pct"].mean(), "com_rmse_dp": com["rmse_pct"].std(),
                "com_mse_media": com["mse"].mean(), "com_mae_media": com["mae_pct"].mean(),
                "com_erro_max_media": com["erro_max_pct"].mean(),
            })
    r = pd.DataFrame(linhas)
    r.to_csv(PASTA_RES / "metricas_redes.csv", index=False, float_format="%.3f")
    return r


# =============== 4. Comite de 5 x comite de 10 (nominal, a partir das previsoes) ===============
def comite_5_10():
    linhas = []
    for p in PERFIS:
        r5, r10 = [], []
        for k in range(1, N_SORTEIOS + 1):
            arq = PASTA_PREV / f"previsao_dados_lstm_teste_{p}_p3_nominal_r{k}_1s.csv"
            if not arq.exists():
                continue
            d = pd.read_csv(arq)
            y = d["Soc"].to_numpy() * 100
            c5 = d[[f"Soc_lstm_s{i}" for i in SEMENTES_COMITE5]].mean(axis=1).to_numpy() * 100
            c10 = d[[f"Soc_lstm_s{i}" for i in range(1, N_SEMENTES + 1)]].mean(axis=1).to_numpy() * 100
            r5.append(np.sqrt(np.mean((y - c5) ** 2)))
            r10.append(np.sqrt(np.mean((y - c10) ** 2)))
        linhas.append({"perfil": NOME_PERFIL[p], "sorteios": len(r5),
                       "rmse_comite5": np.mean(r5), "rmse_comite10": np.mean(r10)})
    r = pd.DataFrame(linhas)
    r.to_csv(PASTA_RES / "comite_5_10.csv", index=False, float_format="%.3f")
    return r


# =============== 5. Figura: SoC no FUDS, 10 redes e comite ===============
def fig_soc():
    d = pd.read_csv(PASTA_PREV / f"previsao_dados_lstm_teste_{PERFIL_FIG}_p3_nominal_r{SORTEIO_FIG}_1s.csv")
    t = d["t_min"].to_numpy() / 60                                  # tempo em horas
    y = d["Soc"].to_numpy() * 100
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(LARG_COLUNA, 3.6), sharex=True,
                                 gridspec_kw={"height_ratios": [1.6, 1]})
    for i in range(1, N_SEMENTES + 1):
        yi = d[f"Soc_lstm_s{i}"].to_numpy() * 100
        rot = "Redes individuais (10)" if i == 1 else None
        a1.plot(t, yi, color="#9e9e9e", lw=0.5, label=rot)
        a2.plot(t, y - yi, color="#9e9e9e", lw=0.5)
    yc = d["Soc_lstm_media"].to_numpy() * 100
    a1.plot(t, y, color="black", lw=1.2, label="Verdadeiro")
    a1.plot(t, yc, color=COR["fuds"], lw=1.0, ls="--", label="Comitê")
    a2.plot(t, y - yc, color=COR["fuds"], lw=0.8)
    a1.set_ylabel("SoC (%)")
    a1.set_ylim(-5, 110)
    a1.legend(loc="lower left")
    a2.set_ylabel("Erro (p.p.)")
    a2.set_xlabel("Tempo (h)")
    a2.set_ylim(-25, 25)
    virgula(a1); virgula(a2)
    fig.tight_layout(h_pad=0.4)
    salvar_fig(fig, "fig_soc_comite_fuds")


if __name__ == "__main__":
    PASTA_RES.mkdir(parents=True, exist_ok=True)
    print("Fonte (so leitura):", PASTA_LSTM)
    g = grade(); print(g[["n_ocultos", "taxa_aprendizado", "rmse_treino_pct", "rmse_val_pct"]].round(2))
    s, rc = sementes(); print(s.round(2).to_string()); print("comite nominal:", {k: round(v, 2) for k, v in rc.items()})
    r = metricas(); print(r.round(2).to_string())
    c = comite_5_10(); print(c.round(2).to_string())
    fig_soc()
    print("Pronto.")
