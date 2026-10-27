-- ============================================================================
-- 02_perguntas.sql - Respostas as 6 Perguntas de Negocio da Controladoria
-- Banco de Dados: pncp_controladoria (MySQL)
-- ============================================================================

USE pncp_controladoria;

-- ============================================================================
-- PERGUNTA 1: Economia global do Poder Publico
-- Qual e o percentual e o valor financeiro nominal economizado pelo governo
-- (diferenca entre valor estimado e valor homologado)?
-- ============================================================================
SELECT
    COUNT(*) AS total_itens_fato,
    SUM(f.comparavel) AS itens_comparaveis,
    ROUND(100.0 * SUM(f.comparavel) / COUNT(*), 2) AS pct_itens_comparaveis,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado_total,
    ROUND(
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END),
        2
    ) AS valor_estimado_comparavel,
    ROUND(
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_homologado ELSE 0 END),
        2
    ) AS valor_homologado_comparavel,
    ROUND(SUM(f.economia_valor), 2) AS economia_nominal_rs,
    ROUND(
        100.0 * SUM(f.economia_valor)
        / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0),
        2
    ) AS economia_pct,
    SUM(CASE WHEN f.economia_valor < 0 THEN 1 ELSE 0 END) AS itens_com_sobrepreco
FROM fato_item_contratado f;


-- ============================================================================
-- PERGUNTA 2: Concentracao e risco de fornecedores
-- Quem sao os maiores fornecedores em volume financeiro e qual percentual
-- do orcamento publico esta concentrado neles?
-- ============================================================================

-- 2A) Ranking dos 10 maiores fornecedores em volume homologado
SELECT
    d.ni_fornecedor,
    d.nome_fornecedor,
    d.tipo_pessoa,
    d.porte,
    COUNT(*) AS qtd_itens_vencidos,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado,
    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS participacao_orcamento_pct
FROM fato_item_contratado f
INNER JOIN dim_fornecedor d ON f.sk_fornecedor = d.sk_fornecedor
GROUP BY d.sk_fornecedor, d.ni_fornecedor, d.nome_fornecedor, d.tipo_pessoa, d.porte
ORDER BY volume_homologado DESC
LIMIT 10;

-- 2B) Resumo executivo da concentracao acumulada no Top 10 Fornecedores
SELECT
    ROUND(SUM(top10.volume_fornecedor), 2) AS volume_top10_fornecedores,
    ROUND(
        (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS volume_total_orcamento,
    ROUND(
        100.0 * SUM(top10.volume_fornecedor)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS concentracao_top10_pct
FROM (
    SELECT SUM(f.valor_total_homologado) AS volume_fornecedor
    FROM fato_item_contratado f
    GROUP BY f.sk_fornecedor
    ORDER BY volume_fornecedor DESC
    LIMIT 10
) AS top10;


-- ============================================================================
-- PERGUNTA 3: Eficacia por modalidade
-- Quais modalidades licitatorias trazem maior desagio/economia e quais
-- concentram o maior volume de recursos?
-- ============================================================================
SELECT
    m.modalidade_id,
    m.nome_modalidade,
    COUNT(*) AS total_itens,
    SUM(f.comparavel) AS itens_comparaveis,
    ROUND(100.0 * SUM(f.comparavel) / COUNT(*), 2) AS pct_itens_comparaveis,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado,
    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS participacao_volume_pct,
    ROUND(
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END),
        2
    ) AS valor_estimado_comparavel,
    ROUND(SUM(f.economia_valor), 2) AS economia_nominal_rs,
    ROUND(
        100.0 * SUM(f.economia_valor)
        / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0),
        2
    ) AS economia_pct,
    ROUND(
        (100.0 * SUM(f.economia_valor)
         / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0))
        - (SELECT 100.0 * SUM(economia_valor)
                  / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0)
           FROM fato_item_contratado),
        1
    ) AS desagio_vs_media_geral_pp
FROM fato_item_contratado f
INNER JOIN dim_modalidade m ON f.sk_modalidade = m.sk_modalidade
GROUP BY m.sk_modalidade, m.modalidade_id, m.nome_modalidade
ORDER BY volume_homologado DESC;


-- ============================================================================
-- PERGUNTA 4: Tempo do ciclo de compras
-- Qual a duracao media (em dias) entre o lancamento do edital e a sua
-- homologacao final, segmentada por orgao?
-- ============================================================================

-- 4A) Indicadores globais do ciclo de compras (Prova Real)
SELECT
    COUNT(*) AS total_itens_fato,
    COUNT(f.dias_ciclo) AS itens_com_ciclo_valido,
    COUNT(*) - COUNT(f.dias_ciclo) AS itens_sem_ciclo,
    ROUND(AVG(f.dias_ciclo), 1) AS ciclo_medio_dias,
    MAX(f.dias_ciclo) AS ciclo_maximo_dias
FROM fato_item_contratado f;

-- 4B) Ranking do ciclo medio por Nome de Orgao (apenas orgaos com 5 ou mais itens com ciclo)
SELECT
    o.nome_orgao,
    COUNT(DISTINCT o.cnpj_orgao) AS qtd_unidades_compradoras,
    COUNT(*) AS total_itens,
    COUNT(f.dias_ciclo) AS itens_com_ciclo,
    COUNT(*) - COUNT(f.dias_ciclo) AS itens_sem_ciclo,
    ROUND(AVG(f.dias_ciclo), 1) AS ciclo_medio_dias,
    MAX(f.dias_ciclo) AS ciclo_maximo_dias
FROM fato_item_contratado f
INNER JOIN dim_orgao o ON f.sk_orgao = o.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(f.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;


-- ============================================================================
-- PERGUNTA 5: Distribuicao regional
-- Quais estados e regioes concentram as maiores despesas e quais apresentam
-- os melhores indicadores de desconto?
-- ============================================================================

-- 5A) Consolidado por Regiao Geografica
SELECT
    l.regiao,
    COUNT(DISTINCT f.sk_orgao) AS qtd_unidades_compradoras,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado,
    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS participacao_volume_pct,
    ROUND(
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END),
        2
    ) AS valor_estimado_comparavel,
    ROUND(SUM(f.economia_valor), 2) AS economia_nominal_rs,
    ROUND(
        100.0 * SUM(f.economia_valor)
        / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0),
        2
    ) AS economia_pct
FROM fato_item_contratado f
INNER JOIN dim_localidade l ON f.sk_localidade = l.sk_localidade
GROUP BY l.regiao
ORDER BY volume_homologado DESC;

-- 5B) Detalhamento por Unidade da Federacao (UF)
SELECT
    l.uf_sigla,
    l.uf_nome,
    l.regiao,
    COUNT(DISTINCT f.sk_orgao) AS qtd_unidades_compradoras,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado,
    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        2
    ) AS participacao_volume_pct,
    ROUND(
        SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END),
        2
    ) AS valor_estimado_comparavel,
    ROUND(SUM(f.economia_valor), 2) AS economia_nominal_rs,
    ROUND(
        100.0 * SUM(f.economia_valor)
        / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0),
        2
    ) AS economia_pct
FROM fato_item_contratado f
INNER JOIN dim_localidade l ON f.sk_localidade = l.sk_localidade
GROUP BY l.sk_localidade, l.uf_sigla, l.uf_nome, l.regiao
ORDER BY volume_homologado DESC;


-- ============================================================================
-- PERGUNTA 6: Perfil dos gastos
-- Como os recursos se distribuem entre bens, servicos e obras e engenharia?
-- ============================================================================
SELECT
    f.perfil_gasto,
    COUNT(*) AS qtd_itens,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume_homologado,
    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado),
        1
    ) AS participacao_volume_pct,
    ROUND(SUM(f.valor_total_homologado) / COUNT(*), 2) AS ticket_medio_item,
    ROUND(SUM(f.economia_valor), 2) AS economia_nominal_rs,
    ROUND(
        100.0 * SUM(f.economia_valor)
        / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0),
        2
    ) AS economia_pct
FROM fato_item_contratado f
GROUP BY f.perfil_gasto
ORDER BY volume_homologado DESC;