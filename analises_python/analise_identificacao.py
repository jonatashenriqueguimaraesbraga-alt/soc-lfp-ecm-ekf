# -*- coding: utf-8 -*-
# analise_identificacao.py
# Trabalho final de PSI525 (Identificacao de Sistemas) - LSTM como sensor virtual do SoC
# Analises sobre as previsoes que JA EXISTEM (rodada 9: 10 redes + comite). Nao treina nada.
# Gera:
#   resultados/tabela_dados.csv          -> tamanho dos conjuntos de treino, validacao e teste
#   resultados/metricas_identificacao.csv -> RMSE, MAE, erro maximo e FIT do comite (media e desvio em 20 sorteios)
#   resultados/erro_por_faixa_soc.csv    -> RMSE do comite por faixa de SoC (limites de validade, so nominal)
#   resultados/residuos_resumo.csv       -> resumo da FAC e da FCC dos residuos (sorteio 1, nominal)
#   figuras/fig_perfis_entrada.(pdf/png) -> exemplos de sinais de entrada (treino e teste)
#   figuras/fig_soc_erro_teste.(pdf/png) -> SoC verdadeiro x comite e residuo, simulacao livre
#   figuras/fig_residuos_fac_fcc.(pdf/png) -> FAC do residuo e FCC residuo x corrente
# Como rodar: abrir este arquivo no VS Code (ou Spyder) e rodar. Precisa de numpy, pandas e matplotlib.

# ===================== CONFIGURACOES (mudar so aqui) =====================
from pathlib import Path                      # para montar os caminhos das pastas
import sys                                    # para ler argumento opcional da linha de comando

PASTA_SCRIPT = Path(__file__).resolve().parent                      # pasta deste script (codigo)
PASTA_TRABALHO = PASTA_SCRIPT.parent                                # pasta trabalho_final_lstm
PASTA_MESTRADO = PASTA_TRABALHO.parent.parent                       # pasta Mestrado automacao
if len(sys.argv) > 1:                                               # se passar um caminho ao rodar
    PASTA_MESTRADO = Path(sys.argv[1])                              # usa esse caminho como base
PASTA_EKF = PASTA_MESTRADO / "SISTEMAS DE CONTROLE AUTOMOTIVO" / "resultados ekf"   # fonte dos dados (so leitura)
PASTA_PREV = PASTA_EKF / "resultados_lstm_v10_10s" / "previsoes"   # previsoes das 10 redes e do comite
PASTA_RES = PASTA_TRABALHO / "resultados"                           # onde salvar os .csv
PASTA_FIG = PASTA_TRABALHO / "figuras"                              # onde salvar as figuras

PERFIS = ["val100", "fuds", "us06"]                                 # perfis de teste
NOME_PERFIL = {"val100": "val100", "fuds": "FUDS", "us06": "US06"}  # nome para tabelas e figuras
CENARIOS = ["nominal", "ref_bias", "ref_ruido"]                     # cenarios de sensor
NOME_CENARIO = {"nominal": "Nominal", "ref_bias": "Bias 0,15 A", "ref_ruido": "Ruído 0,2 A²"}  # nomes curtos
N_SORTEIOS = 20                                                     # sorteios de ruido de sensor por cenario
COL_COMITE = "Soc_lstm_media"                                       # coluna do comite (media das 10 redes)
SORTEIO_FIG = 1                                                     # sorteio usado nas figuras (fixado antes)
LAG_MAX_S = 600                                                     # maior atraso das funcoes de correlacao (s)
FAIXAS_SOC = [(80, 100.01, "acima de 80%"), (30, 80, "30 a 80%"), (0, 30, "abaixo de 30%")]  # faixas de SoC
JANELA_PERFIL_MIN = 30                                              # minutos mostrados de cada perfil de entrada
# ==========================================================================

import numpy as np                            # contas com vetores
import pandas as pd                           # leitura e escrita de tabelas .csv
import matplotlib                             # biblioteca de graficos
matplotlib.use("Agg")                         # desenha sem abrir janela (so salva arquivo)
import matplotlib.pyplot as plt               # funcoes de grafico

# ---------- estilo das figuras (parecido com o aplicar_estilo_artigo do MATLAB) ----------
import matplotlib.ticker as mticker      # para trocar ponto por virgula nos eixos

LARG_COLUNA = 3.30                            # largura de 1 coluna do modelo SBA/IFAC (pol, ~8,4 cm)
LARG_PAGINA = 6.90                            # largura das 2 colunas (pol, ~17,5 cm) para figure*
FONTE = 8                                     # 8 pt no tamanho final (modelo SBA pede rotulos de 8 a 12 pt)
plt.rcParams.update({                         # ajustes gerais de todas as figuras
    "font.family": "serif",                   # fonte com serifa
    "font.serif": ["Times New Roman", "Liberation Serif", "DejaVu Serif"],  # Times no Windows
    "mathtext.fontset": "stix",               # simbolos matematicos parecidos com Times
    "font.size": FONTE,                       # texto geral
    "axes.titlesize": FONTE,                  # titulo dos paineis
    "axes.labelsize": FONTE,                  # rotulos dos eixos
    "xtick.labelsize": FONTE,                 # numeros do eixo x
    "ytick.labelsize": FONTE,                 # numeros do eixo y
    "legend.fontsize": FONTE,                 # legenda
    "axes.grid": True,                        # grade ligada
    "grid.alpha": 0.35,                       # grade clara
    "axes.facecolor": "white",                # fundo branco nos eixos
    "figure.facecolor": "white",              # fundo branco na figura
    "axes.edgecolor": "black",                # borda preta (box on)
    "axes.linewidth": 0.6,                    # borda fina
    "legend.frameon": True,                   # legenda com moldura
    "legend.facecolor": "white",              # fundo branco na legenda
    "legend.framealpha": 1.0,                 # legenda opaca (nao deixa a curva aparecer por tras)
    "axes.unicode_minus": True,               # sinal de menos correto
    "pdf.fonttype": 42,                       # fontes embutidas no PDF (exigencia comum de congresso)
    "savefig.dpi": 300,                       # resolucao do PNG
})


def virgula(ax):                              # numeros dos eixos com virgula decimal (texto em portugues)
    fmt = mticker.FuncFormatter(lambda v, pos: f"{v:g}".replace(".", ",").replace("-", "\u2212"))
    ax.xaxis.set_major_formatter(fmt)         # eixo x
    ax.yaxis.set_major_formatter(fmt)         # eixo y


COR_VERD = (0.45, 0.80, 0.50)                 # verde-claro do valor verdadeiro (padrao da AF)
CORES = {"val100": (0.00, 0.35, 0.75), "fuds": (0.85, 0.33, 0.10), "us06": (0.45, 0.20, 0.60)}  # cor por perfil
ESTILO = {"val100": "-", "fuds": "--", "us06": "-."}               # tipo de linha por perfil


def arq_prev(perfil, cenario, r):             # monta o caminho de uma previsao
    return PASTA_PREV / f"previsao_dados_lstm_teste_{perfil}_p3_{cenario}_r{r}_1s.csv"


def arq_dado(pasta, nome):                    # monta o caminho de um arquivo de dados
    return PASTA_EKF / pasta / nome


def salvar_fig(fig, nome):                    # salva PDF (artigo) e PNG (slides)
    PASTA_FIG.mkdir(parents=True, exist_ok=True)      # cria a pasta se nao existir
    fig.savefig(PASTA_FIG / f"{nome}.pdf", bbox_inches="tight", pad_inches=0.02)   # vetorial para o LaTeX
    fig.savefig(PASTA_FIG / f"{nome}.png", bbox_inches="tight", pad_inches=0.02)   # imagem para os slides
    plt.close(fig)                            # fecha para liberar memoria


def metricas(y, yh):                          # metricas de um arquivo (SoC em fracao 0-1)
    e = (y - yh) * 100                        # residuo xi = y - y_chapeu, em pontos percentuais
    rmse = np.sqrt(np.mean(e ** 2))           # raiz do erro quadratico medio
    mae = np.mean(np.abs(e))                  # erro absoluto medio
    emax = np.max(np.abs(e))                  # erro maximo em modulo
    dp_y = np.std(y * 100)                    # desvio padrao da saida verdadeira
    fit = 100 * (1 - np.sqrt(np.sum(e ** 2)) / np.sqrt(np.sum((y * 100 - np.mean(y * 100)) ** 2)))  # FIT (%)
    return rmse, mae, emax, fit, dp_y


def correlacao(a, b, lag_max):                # correlacao cruzada normalizada r_ab(k) para k = -lag_max..lag_max
    a = a - a.mean()                          # tira a media de a
    b = b - b.mean()                          # tira a media de b
    n = len(a)                                # numero de amostras
    den = np.sqrt(np.sum(a ** 2) * np.sum(b ** 2))   # normalizacao (r = 1 quando a = b e k = 0)
    lags = np.arange(-lag_max, lag_max + 1)   # vetor de atrasos
    r = np.empty(len(lags))                   # vetor de resultados
    for i, k in enumerate(lags):              # para cada atraso k
        if k >= 0:                            # atraso positivo: a(t) com b(t-k)
            r[i] = np.sum(a[k:] * b[:n - k]) / den
        else:                                 # atraso negativo: a(t) com b(t+|k|)
            r[i] = np.sum(a[:n + k] * b[-k:]) / den
    return lags, r                            # devolve atrasos e correlacoes


# ===================== 1) TABELA DOS DADOS (projeto de testes) =====================
def tabela_dados():
    treino = [arq_dado("dados_lstm", "dados_lstm_treino_hppc_p3_nominal_r1_1s.csv")]          # HPPC
    treino += [arq_dado("dados_lstm", f"dados_lstm_treino_aleatorio_s{s}_p3_nominal_r{s+1}_1s.csv") for s in (11, 12, 13)]   # degraus antigos
    treino += [arq_dado("dados_lstm_extra", f"dados_lstm_treino_aleatorio_s{s}_p3_nominal_r{s+1}_1s.csv") for s in range(101, 121)]  # degraus extra
    treino += [arq_dado("dados_lstm_v10", f"dados_lstm_treino_aleatorio_s{s}_p3_nominal_r{s+1}_1s.csv") for s in range(141, 181)]    # lentos e rapidos
    treino += [arq_dado("dados_lstm_v10", "dados_lstm_treino_dst_p3_nominal_r1_1s.csv")]      # DST
    valid = [arq_dado("dados_lstm", "dados_lstm_validacao_aleatorio_s21_p3_nominal_r22_1s.csv")]   # validacao antiga
    valid += [arq_dado("dados_lstm_extra", f"dados_lstm_validacao_aleatorio_s{s}_p3_nominal_r{s+1}_1s.csv") for s in (201, 202, 203)]
    valid += [arq_dado("dados_lstm_v10", f"dados_lstm_validacao_aleatorio_s{s}_p3_nominal_r{s+1}_1s.csv") for s in range(207, 213)]
    linhas = []                               # linhas da tabela
    for nome, lista in (("Treino", treino), ("Validacao", valid)):   # para cada conjunto
        faltam = [f.name for f in lista if not f.exists()]          # confere se todos existem
        if faltam:                            # avisa se faltar arquivo
            print(f"AVISO: faltam {len(faltam)} arquivos de {nome}: {faltam[:3]}")
        dfs = [pd.read_csv(f) for f in lista if f.exists()]         # le os arquivos
        n = sum(len(d) for d in dfs)          # total de amostras (1 por segundo)
        imax = max(d.I_medido.max() for d in dfs)                   # maior corrente medida
        socmin = min(d.Soc.min() for d in dfs) * 100                # menor SoC
        linhas.append([nome, len(dfs), n, n / 3600, imax, socmin])  # guarda a linha
    for p in PERFIS:                          # teste: um perfil de cada (sorteio 1 nominal; os 20 tem o mesmo tamanho)
        d = pd.read_csv(arq_prev(p, "nominal", 1))                  # previsao tem o SoC verdadeiro
        linhas.append([f"Teste {NOME_PERFIL[p]}", 1, len(d), len(d) / 3600, np.nan, d.Soc.min() * 100])
    tab = pd.DataFrame(linhas, columns=["conjunto", "n_perfis", "n_amostras", "duracao_h", "I_max_A", "SoC_min_pct"])  # monta tabela
    tab.to_csv(PASTA_RES / "tabela_dados.csv", index=False)         # salva
    print(tab.round(2).to_string(index=False))                      # mostra na tela
    return treino                             # devolve a lista de treino para a figura


# ===================== 2) METRICAS DE VALIDACAO (simulacao livre) =====================
def tabela_metricas():
    linhas = []                               # uma linha por arquivo
    for p in PERFIS:                          # cada perfil
        for c in CENARIOS:                    # cada cenario de sensor
            for r in range(1, N_SORTEIOS + 1):   # cada sorteio
                f = arq_prev(p, c, r)         # caminho do arquivo
                if not f.exists():            # pula se nao existir
                    continue
                d = pd.read_csv(f)            # le previsao
                rmse, mae, emax, fit, dp_y = metricas(d.Soc.values, d[COL_COMITE].values)   # metricas do comite
                linhas.append([p, c, r, rmse, mae, emax, fit, dp_y])  # guarda
    todos = pd.DataFrame(linhas, columns=["perfil", "cenario", "sorteio", "rmse", "mae", "emax", "fit", "dp_y"])
    todos.to_csv(PASTA_RES / "metricas_identificacao_todos.csv", index=False)   # salva por arquivo
    res = todos.groupby(["perfil", "cenario"]).agg(            # media e desvio nos sorteios
        n=("rmse", "size"),
        rmse_media=("rmse", "mean"), rmse_dp=("rmse", "std"),
        mae_media=("mae", "mean"), mae_dp=("mae", "std"),
        emax_media=("emax", "mean"), emax_dp=("emax", "std"),
        fit_media=("fit", "mean"), fit_dp=("fit", "std"),
        dp_y=("dp_y", "mean")).reset_index()
    res["ordem_p"] = res.perfil.map({p: i for i, p in enumerate(PERFIS)})       # ordem das linhas
    res["ordem_c"] = res.cenario.map({c: i for i, c in enumerate(CENARIOS)})
    res = res.sort_values(["ordem_c", "ordem_p"]).drop(columns=["ordem_p", "ordem_c"])
    res.to_csv(PASTA_RES / "metricas_identificacao.csv", index=False)           # salva resumo
    print(res.round(2).to_string(index=False))                                  # mostra na tela


# ===================== 3) ERRO POR FAIXA DE SoC (limites de validade) =====================
def tabela_faixas():
    linhas = []                               # uma linha por perfil, faixa e sorteio
    for p in PERFIS:
        for r in range(1, N_SORTEIOS + 1):
            f = arq_prev(p, "nominal", r)     # so cenario nominal
            if not f.exists():
                continue
            d = pd.read_csv(f)                # le previsao
            y = d.Soc.values * 100            # SoC verdadeiro em %
            e = y - d[COL_COMITE].values * 100   # residuo em p.p.
            for lo, hi, nome in FAIXAS_SOC:   # cada faixa
                m = (y >= lo) & (y < hi)      # amostras dentro da faixa (pelo SoC verdadeiro)
                if m.sum() == 0:              # val100 nao passa de 66%: pula faixas vazias
                    continue
                linhas.append([p, nome, r, m.sum(), np.sqrt(np.mean(e[m] ** 2)), np.max(np.abs(e[m]))])
    t = pd.DataFrame(linhas, columns=["perfil", "faixa", "sorteio", "n_amostras", "rmse", "emax"])
    res = t.groupby(["perfil", "faixa"], sort=False).agg(n_amostras=("n_amostras", "mean"),
                                                          rmse_media=("rmse", "mean"), rmse_dp=("rmse", "std"),
                                                          emax_media=("emax", "mean")).reset_index()
    res.to_csv(PASTA_RES / "erro_por_faixa_soc.csv", index=False)   # salva
    print(res.round(2).to_string(index=False))                      # mostra


# ===================== 4) FIGURA DOS SINAIS DE ENTRADA (1 coluna) =====================
def fig_perfis(treino):
    lento = arq_dado("dados_lstm_v10", "dados_lstm_treino_aleatorio_s141_p3_nominal_r142_1s.csv")    # degraus lentos
    rapido = arq_dado("dados_lstm_v10", "dados_lstm_treino_aleatorio_s161_p3_nominal_r162_1s.csv")   # degraus rapidos
    fuds = arq_dado("dados_lstm_v10", "dados_lstm_teste_fuds_p3_nominal_r1_1s.csv")                  # teste urbano
    us06 = arq_dado("dados_lstm_v10", "dados_lstm_teste_us06_p3_nominal_r1_1s.csv")                  # teste rodovia
    paineis = [(lento, "(a) Treino: degraus lentos"), (rapido, "(b) Treino: degraus rápidos"),
               (fuds, "(c) Teste: FUDS"), (us06, "(d) Teste: US06")]       # o que vai em cada painel
    fig, ax = plt.subplots(2, 2, figsize=(LARG_COLUNA, 2.9), sharex=True, sharey=True)   # 2 x 2 em 1 coluna
    for a, (f, tit) in zip(ax.flat, paineis):                                 # cada painel
        d = pd.read_csv(f)                                                    # le dados
        m = d.t_min <= JANELA_PERFIL_MIN                                      # so os primeiros minutos
        a.plot(d.t_min[m], d.I_medido[m], color=(0.0, 0.35, 0.75), lw=0.5)   # corrente medida
        a.set_title(tit)                                                      # titulo do painel
        a.set_xlim(0, JANELA_PERFIL_MIN)                                      # eixo x
        a.set_xticks([0, 10, 20, 30])                                         # poucas marcas (legivel)
        a.set_ylim(-0.2, 3.0)                                                 # mesma escala nos 4
        virgula(a)                                                            # virgula decimal
    for a in ax[1]:
        a.set_xlabel("Tempo (min)")                                           # rotulo x embaixo
    for a in ax[:, 0]:
        a.set_ylabel("Corrente (A)")                                          # rotulo y a esquerda
    fig.tight_layout(pad=0.3, h_pad=0.4, w_pad=0.4)                           # ajusta espacos
    salvar_fig(fig, "fig_perfis_entrada")                                     # salva


# ===================== 5) FIGURA SoC E RESIDUO (largura da pagina) =====================
def fig_soc_erro():
    fig, ax = plt.subplots(2, 3, figsize=(LARG_PAGINA, 3.0), sharex="col",
                           gridspec_kw={"height_ratios": [2, 1]})             # SoC em cima, residuo embaixo
    letras = ["(a)", "(b)", "(c)"]                                            # letra de cada coluna
    for j, p in enumerate(PERFIS):                                            # uma coluna por perfil
        d = pd.read_csv(arq_prev(p, "nominal", SORTEIO_FIG))                  # sorteio fixado antes
        t = d.t_min.values                                                    # tempo em min
        y = d.Soc.values * 100                                                # SoC verdadeiro (%)
        yh = d[COL_COMITE].values * 100                                       # SoC do modelo LSTM (comite) (%)
        e = y - yh                                                            # residuo xi (p.p.)
        rmse = np.sqrt(np.mean(e ** 2))                                       # RMSE do sorteio mostrado
        passo = max(1, len(t) // 600)                                         # so para desenhar (~600 pontos)
        ax[0, j].plot(t[::passo], y[::passo], color=COR_VERD, lw=2.2, label="Verdadeiro, $y$")      # faixa verde por baixo
        ax[0, j].plot(t[::passo], yh[::passo], color=(0.0, 0.35, 0.75), lw=0.8, label="Modelo LSTM, $\\hat{y}$")  # modelo por cima
        ax[0, j].set_title(f"{letras[j]} {NOME_PERFIL[p]} (RMSE = {rmse:.2f}%)".replace(".", ","))   # RMSE no titulo
        ax[1, j].plot(t[::passo], e[::passo], color=(0.85, 0.33, 0.10), lw=0.7)   # residuo
        ax[1, j].axhline(0, color="k", lw=0.5)                                # linha do zero
        ax[1, j].set_xlabel("Tempo (min)")                                    # rotulo x
        lim = 1.08 * np.max(np.abs(e))                                        # 8% de folga no painel de erro
        ax[1, j].set_ylim(-lim, lim)
        ax[0, j].set_ylim(min(y.min(), yh.min()) - 5, 105)                    # folga no SoC
        virgula(ax[0, j]); virgula(ax[1, j])                                  # virgula decimal
    ax[0, 0].legend(loc="lower left")                                         # legenda so no 1o painel (area vazia)
    ax[0, 0].set_ylabel("Estado de carga (%)")                                # rotulos y com palavras
    ax[1, 0].set_ylabel("Resíduo $\\xi$ (p.p.)")
    fig.tight_layout(pad=0.3, h_pad=0.3, w_pad=0.8)
    salvar_fig(fig, "fig_soc_erro_teste")


# ===================== 6) ANALISE DE RESIDUOS (FAC e FCC, 1 coluna) =====================
def fig_residuos():
    fig, ax = plt.subplots(2, 1, figsize=(LARG_COLUNA, 3.6))                  # FAC em cima, FCC embaixo
    linhas = []                                                               # resumo numerico
    limites = {}                                                              # faixa de 95% de cada perfil
    for p in PERFIS:
        prev = pd.read_csv(arq_prev(p, "nominal", SORTEIO_FIG))               # previsao do sorteio 1
        pasta = "dados_lstm" if p == "val100" else "dados_lstm_v10"           # onde esta o arquivo de entrada
        dado = pd.read_csv(arq_dado(pasta, f"dados_lstm_teste_{p}_p3_nominal_r{SORTEIO_FIG}_1s.csv"))  # entrada medida
        xi = (prev.Soc.values - prev[COL_COMITE].values) * 100                # residuo xi(k)
        u = dado.I_medido.values                                              # entrada u1(k) = corrente
        n = len(xi)                                                           # numero de amostras
        lim = 1.96 / np.sqrt(n)                                               # faixa de confianca de 95%
        limites[p] = lim                                                      # guarda para desenhar
        lags, fac = correlacao(xi, xi, LAG_MAX_S)                             # FAC do residuo
        _, fcc = correlacao(xi, u, LAG_MAX_S)                                 # FCC residuo x corrente
        k = lags >= 0                                                         # FAC: so atrasos positivos
        ax[0].plot(lags[k], fac[k], ESTILO[p], color=CORES[p], lw=0.9, label=NOME_PERFIL[p])
        ax[1].plot(lags, fcc, ESTILO[p], color=CORES[p], lw=0.9, label=NOME_PERFIL[p])
        fora_fac = np.mean(np.abs(fac[lags >= 1]) > lim) * 100                # % dos atrasos fora da faixa (FAC)
        fora_fcc = np.mean(np.abs(fcc) > lim) * 100                           # % dos atrasos fora da faixa (FCC)
        cruza = np.where(np.abs(fac[lags >= 0]) < lim)[0]                     # primeiro atraso dentro da faixa
        t_desc = int(cruza[0]) if len(cruza) else np.nan                      # tempo de descorrelacao (s)
        linhas.append([p, n, lim, fac[lags == 1][0], fac[lags == 60][0], fac[lags == LAG_MAX_S][0],
                       fora_fac, t_desc, np.max(np.abs(fcc)), lags[np.argmax(np.abs(fcc))], fora_fcc])
    l_longo = max(limites["fuds"], limites["us06"])                           # faixa dos perfis longos (~0,018)
    for a in ax:
        a.axhspan(-l_longo, l_longo, color=(0.6, 0.6, 0.6), alpha=0.45, lw=0)   # faixa cinza: FUDS e US06
        a.axhline(limites["val100"], color="k", ls=":", lw=0.8)               # linhas pontilhadas: val100 (~0,042)
        a.axhline(-limites["val100"], color="k", ls=":", lw=0.8)
        a.axhline(0, color="k", lw=0.5)
        a.set_xlabel("Atraso $k$ (s)")
        virgula(a)
    ax[1].legend(loc="upper right", ncol=1, handlelength=2.2)   # legenda na area vazia da FCC
    ax[0].set_ylabel("Autocorrelação\nde $\\xi$")                           # rotulos com palavras
    ax[1].set_ylabel("Correlação cruzada\nde $\\xi$ e corrente")
    ax[0].set_title("(a) Função de autocorrelação (FAC) do resíduo")
    ax[1].set_title("(b) Função de correlação cruzada (FCC) resíduo–corrente")
    fig.tight_layout(pad=0.3, h_pad=0.6)
    salvar_fig(fig, "fig_residuos_fac_fcc")
    res = pd.DataFrame(linhas, columns=["perfil", "n", "faixa_95", "fac_lag1", "fac_lag60s", f"fac_lag{LAG_MAX_S}s",
                                        "pct_atrasos_fora_fac", "t_descorrelacao_s", "fcc_max_abs",
                                        "lag_fcc_max_s", "pct_atrasos_fora_fcc"])
    res.to_csv(PASTA_RES / "residuos_resumo.csv", index=False)
    print(res.round(3).to_string(index=False))


# ===================== RODA TUDO =====================
if __name__ == "__main__":
    PASTA_RES.mkdir(parents=True, exist_ok=True)      # cria pasta de resultados
    print("== 1) Dados ==");      treino = tabela_dados()
    print("== 2) Metricas ==");   tabela_metricas()
    print("== 3) Faixas de SoC =="); tabela_faixas()
    print("== 4) Figura entradas =="); fig_perfis(treino)
    print("== 5) Figura SoC =="); fig_soc_erro()
    print("== 6) Residuos =="); fig_residuos()
    print("Pronto. Resultados em", PASTA_RES, "e figuras em", PASTA_FIG)
