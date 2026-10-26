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
  5. Valor total (estimado ou homologado) > R$ 1 trilhão (1e12): **3 itens**
  6. Quantidade vazia ou <= 0: **1 item**

---

## 2. Modelagem Dimensional (Star Schema)

![Star Schema do PNCP](docs/img/star_schema.png)

A tabela fato `fato_item_contratado` (6.126 linhas, uma por item contratado) se relaciona com quatro dimensões por chaves substitutas (`sk_*`). Todas as relações são de um para muitos (1 dimensão : N itens).

| Tabela | Tipo | Linhas | Chave natural (única) |
| :--- | :---: | :---: | :--- |
| `fato_item_contratado` | Fato | 6.126 | `numero_controle_pncp` + `numero_item` |
| `dim_orgao` | Dimensão | 363 | `cnpj_orgao` |
| `dim_fornecedor` | Dimensão | 2.652 | `ni_fornecedor` |
| `dim_modalidade` | Dimensão | 7 | `modalidade_id` |
| `dim_localidade` | Dimensão | 27 | `uf_sigla` |

O script de criação do banco é o `sql/01_criar_banco.sql`. Ele remove as tabelas existentes (fato primeiro, depois as dimensões) antes de recriá-las, o que permite repetir a carga sem limpeza manual.

---

## 3. Carga no MySQL

### 3.1. Pré-requisitos
* Servidor MySQL em execução.
* Arquivo `.env` com as credenciais de conexão (senha correta).
* Dependências Python instaladas, incluindo o conector do MySQL:

```powershell
python -m pip install mysql-connector-python
```

### 3.2. Execução

```powershell
python -m src.carregar
```

O script cria o banco e as tabelas, carrega as 4 dimensões, carrega a fato (as dimensões vêm primeiro por causa das chaves estrangeiras) e confere as contagens.

### 3.3. Conferência esperada

```text
Carga:
   dim_orgao: 363 linhas
   dim_fornecedor: 2652 linhas
   dim_modalidade: 7 linhas
   dim_localidade: 27 linhas
   fato_item_contratado: 6126 linhas
Conferencia:
   fato_item_contratado: 6126 (esperado 6126) -> OK
   dim_orgao: 363 (esperado 363) -> OK
   dim_fornecedor: 2652 (esperado 2652) -> OK
   dim_modalidade: 7 (esperado 7) -> OK
   dim_localidade: 27 (esperado 27) -> OK
```

---

## 4. Decisões de Modelagem e Qualidade dos Dados

### 4.1. Regra de integridade `chk_fato_valores` e itens com valor simbólico

A tabela `fato_item_contratado` possui uma restrição `CHECK` (`chk_fato_valores`)
que garante valores monetários consistentes antes de qualquer análise:

- `valor_unitario_estimado > 0`
- `valor_total_estimado >= 1`
- `valor_unitario_homologado > 0`
- `valor_total_homologado >= 0`

Na primeira tentativa de carga, o MySQL rejeitou o lote com o erro 3819
(`Check constraint 'chk_fato_valores' is violated`). Um diagnóstico sobre o CSV
(`src/diagnostico.py`) mostrou que apenas **3 dos 6.126 itens** violavam a regra,
todos pela mesma condição (`valor_total_homologado > 0`, na versão original da regra):

| numero_controle_pncp | Valor total estimado | Valor unit. homologado | Valor total homologado |
|---|---|---|---|
| 00394452000103-1-009745/2025 | R$ 10.000,00 | R$ 0,0001 | R$ 0,00 |
| 00394502000144-1-004219/2025 | R$ 745.000,00 | R$ 0,0001 | R$ 0,00 |
| 00394452000103-1-019179/2025 | R$ 100,00 | R$ 0,0001 | R$ 0,00 |

**Causa:** são itens homologados com valor unitário simbólico de R$ 0,0001. Como o
valor total é armazenado como `DECIMAL(18,2)`, o produto (0,0001 × 1) é arredondado
para 0,00 e a regra `> 0` o rejeitava.

**Decisão:** a restrição foi relaxada de `valor_total_homologado > 0` para
`valor_total_homologado >= 0`. Os itens foram mantidos porque fazem parte do
conjunto de referência (6.126 itens) e descartá-los alteraria o universo analisado.
A regra continua barrando valores negativos, e `valor_unitario_homologado > 0`
segue valendo.

**Ressalva para as análises:** nesses 3 itens a economia aparente
(`valor_total_estimado - valor_total_homologado`) é praticamente igual ao valor
estimado inteiro, o que pode inflar indicadores de economia. As consultas que
calculam economia devem tratá-los à parte (por exemplo, filtrando
`valor_total_homologado > 0`) ou mencioná-los como ressalva. Os registros também
são candidatos a verificação manual, pois podem indicar valor simbólico legítimo
ou erro de preenchimento no PNCP.
