import pandas as pd
from src import config

f = pd.read_csv(config.PASTA_PROCESSED / "fato_item_contratado.csv",
                keep_default_na=False, na_values=[""])
print(len(f), "linhas no CSV\n")

cols = ["quantidade", "valor_unitario_estimado", "valor_total_estimado",
        "valor_unitario_homologado", "valor_total_homologado"]
print("Nulos por coluna:")
print(f[cols].isna().sum(), "\n")

# arredonda como o MySQL grava: unitarios com 4 casas, totais com 2
ue = f["valor_unitario_estimado"].round(4)
te = f["valor_total_estimado"].round(2)
uh = f["valor_unitario_homologado"].round(4)
th = f["valor_total_homologado"].round(2)

regras = {
    "unit_estimado > 0":      ue > 0,
    "total_estimado >= 1":    te >= 1,
    "unit_homologado > 0":    uh > 0,
    "total_homologado > 0":   th > 0,
    "quantidade > 0":         f["quantidade"] > 0,
}
for nome, ok in regras.items():
    print(f"Viola '{nome}': {int((~ok).sum())} linhas")

ok_todas = (ue > 0) & (te >= 1) & (uh > 0) & (th > 0)
ruins = f[~ok_todas]
print(f"\nTotal violando chk_fato_valores: {len(ruins)}")
print(ruins[["numero_controle_pncp", "numero_item", "quantidade",
             "valor_unitario_estimado", "valor_total_estimado",
             "valor_unitario_homologado", "valor_total_homologado"]].head(15).to_string())