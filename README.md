# Auditoria e Controle de Contratações Públicas (PNCP 2025)

Pipeline analítico End-to-End (Python + MySQL + Power BI) desenvolvido para saneamento, modelagem dimensional (Star Schema) e auditoria das contratações públicas federais do PNCP referentes ao ano de 2025.

---

## 1. Diagnóstico e Auditoria dos Dados Brutos (Secção 7.4)

### 1.1. Volumetria e Unicidade de Chaves
* **`compras.csv`**: **2.042 linhas** e **2.042** valores únicos de `numero_controle_pncp` (0 duplicados).
* **`itens.csv`**: **7.077 linhas** e **0 duplicados** na chave composta (`numero_controle_pncp` + `numero_item`).
* **`resultados.csv`**: **15.896 linhas** (múltiplos fornecedores classificados por item, especialmente em certames com Sistema de Registro de Preços — SRP).

### 1.2. Dicionário de Anomalias Identificadas na Base Bruta

| Categoria de Anomalia | Arquivo / Coluna Afetada | Ocorrências | Descrição do Problema e Tratamento Aplicado |
| :--- | :--- | :---: | :--- |
| **Documentos (CNPJ/CPF)** | `compras.cnpj_orgao` | 381 | 176 com máscara (`./-`), 131 com espaços invisíveis (`\xa0`) e 74 com perda de zero à esquerda (12 ou 13 dígitos). |
| **Documentos (CNPJ/CPF/PE)** | `resultados.ni_fornecedor` | 2.976 | Mistura `PJ` (11.344), `PF` (4.531) e `PE` (21 estrangeiros). 1.633 com máscara, 990 com `\xa0`, 194 PJs e 159 PFs sem zero à esquerda. |
| **Moedas e Separadores** | `compras`, `itens` e `resultados` | 15.643 | Uso de `R$`, espaços invisíveis (`\xa0`), mistura de padrão BR (`1.234,56`) e US (`1,234.56`), além de quantidades formatadas como moeda (`R$ 24,00`). |
| **Formatos de Data** | `data_publicacao` / `data_resultado` | 17.938 | Convivência de 6 máscaras distintas (`YYYY-MM-DD`, `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`, `YYYY/MM/DD` e `YYYYMMDD`), com e sem hora. |
| **Violação Cronológica** | `resultados.data_resultado` | 234 (bruto) / **230 (fato)** | Data de homologação anterior à data de publicação do edital (`data_resultado < data_publicacao`). Tratamento: anulação da data e do ciclo, mantendo o item na fato. |
| **Encoding (`Mojibake`)** | `objeto_compra`, `municipio`, `nome_unidade`, `descricao`, `nome_fornecedor` | 202 | Textos UTF-8 lidos como Latin-1 (ex.: `AquisiÃ§Ã£o`). Revertidos via `.encode("latin-1").decode("utf-8")`. |
| **Despadronização de Órgãos** | `compras.razao_social_orgao` | 67 CNPJs | 440 grafias brutas para 363 CNPJs (variações de caixa e espaços). Após padronização em maiúsculas, consolidam-se em 352 nomes únicos. |

### 1.3. Mapeamento de Nulos Disfarçados e Vazios
* **`compras.processo`**: 77 nulos disfarçados (`NULL`: 18, `-`: 16, `N/A`: 16, `0`: 12, `SEM INFORMAÇÃO`: 10, `NÃO INFORMADO`: 5).
* **`compras.modo_disputa`**: 967 nulos disfarçados (`NÃO SE APLICA`: 904, `N/A`: 20, `NULL`: 15, `NÃO INFORMADO`: 9, `0`: 7, `SEM INFORMAÇÃO`: 6, `-`: 6).
* **`itens.categoria_item`**: 7.077 ocorrências de `NÃO SE APLICA` (100% da coluna).
* **`itens.situacao_item`**: 220 nulos disfarçados (`N/A`: 67, `NULL`: 44, `SEM INFORMAÇÃO`: 31, `-`: 29, `0`: 25, `NÃO INFORMADO`: 24).
* **`itens.criterio_julgamento`**: 1.883 ocorrências de `NÃO SE APLICA`.
* **`resultados.porte`**: 4.893 nulos disfarçados (`NÃO INFORMADO`: 4.468, `N/A`: 132, `NULL`: 115, `SEM INFORMAÇÃO`: 60, `0`: 57, `-`: 52, `NÃO SE APLICA`: 9).

### 1.4. Descarte sem Resultado (Regra 3) e Itens Rejeitados (Regra 4)
* **Itens sem resultado homologado ativo (Regra 3)**: **852 itens** (dos 7.077 totais) não possuem resultado ou possuem apenas resultados cancelados (`data_cancelamento` preenchida em 62 registos). Avaliados pela Regra 4: **6.225 itens**.
* **Itens rejeitados por inconsistência de negócio (Regra 4)**: **99 itens** barrados antes da carga na tabela fato (restando **6.126 itens válidos**). Contagem pelo 1º motivo de rejeição:
  1. Valor total estimado < R$ 1,00: **59 itens**
  2. Valor unitário estimado ausente ou <= 0: **23 itens**
  3. Valor total homologado > 1.000x o estimado: **7 itens**
  4. Valor unitário homologado ausente ou <= 0: **6 itens**
  5. Valor total (estimado ou homologado) > R$ 1 bilião (1e12 / 1 trilhão): **3 itens**
  6. Quantidade vazia ou <= 0: **1 item**