-- ============================================================================
-- 01_criar_banco.sql - Modelagem Dimensional Star Schema (MySQL)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS pncp_controladoria
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE pncp_controladoria;

-- Remove tabelas na ordem inversa (Fato antes das Dimensoes) para permitir recarga limpa
DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;

-- 1. DIMENSAO ORGAO (363 linhas esperadas)
CREATE TABLE dim_orgao (
    sk_orgao INT NOT NULL,
    cnpj_orgao VARCHAR(14) NOT NULL,
    nome_orgao VARCHAR(255) NOT NULL,
    poder VARCHAR(50) NOT NULL,
    CONSTRAINT pk_dim_orgao PRIMARY KEY (sk_orgao),
    CONSTRAINT uq_dim_orgao_cnpj UNIQUE (cnpj_orgao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. DIMENSAO FORNECEDOR (2.652 linhas esperadas)
CREATE TABLE dim_fornecedor (
    sk_fornecedor INT NOT NULL,
    ni_fornecedor VARCHAR(30) NOT NULL,
    nome_fornecedor VARCHAR(255) NULL,
    tipo_pessoa VARCHAR(10) NULL,
    porte VARCHAR(50) NULL,
    CONSTRAINT pk_dim_fornecedor PRIMARY KEY (sk_fornecedor),
    CONSTRAINT uq_dim_fornecedor_ni UNIQUE (ni_fornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. DIMENSAO MODALIDADE (7 linhas esperadas)
CREATE TABLE dim_modalidade (
    sk_modalidade INT NOT NULL,
    modalidade_id INT NOT NULL,
    nome_modalidade VARCHAR(100) NOT NULL,
    CONSTRAINT pk_dim_modalidade PRIMARY KEY (sk_modalidade),
    CONSTRAINT uq_dim_modalidade_id UNIQUE (modalidade_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. DIMENSAO LOCALIDADE (27 linhas esperadas)
CREATE TABLE dim_localidade (
    sk_localidade INT NOT NULL,
    uf_sigla CHAR(2) NOT NULL,
    uf_nome VARCHAR(100) NOT NULL,
    regiao VARCHAR(50) NOT NULL,
    CONSTRAINT pk_dim_localidade PRIMARY KEY (sk_localidade),
    CONSTRAINT uq_dim_localidade_uf UNIQUE (uf_sigla)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. TABELA FATO ITEM CONTRATADO (6.126 linhas esperadas)
CREATE TABLE fato_item_contratado (
    sk_fato INT NOT NULL AUTO_INCREMENT,
    numero_controle_pncp VARCHAR(50) NOT NULL,
    numero_item INT NOT NULL,
    sk_orgao INT NOT NULL,
    sk_fornecedor INT NOT NULL,
    sk_modalidade INT NOT NULL,
    sk_localidade INT NOT NULL,
    data_publicacao DATE NOT NULL,
    data_homologacao DATE NULL,
    descricao_item TEXT NULL,
    perfil_gasto VARCHAR(50) NOT NULL,
    quantidade DECIMAL(18,4) NOT NULL,
    valor_unitario_estimado DECIMAL(18,4) NOT NULL,
    valor_total_estimado DECIMAL(18,2) NOT NULL,
    valor_unitario_homologado DECIMAL(18,4) NOT NULL,
    valor_total_homologado DECIMAL(18,2) NOT NULL,
    comparavel TINYINT NOT NULL,
    economia_valor DECIMAL(18,2) NULL,
    dias_ciclo INT NULL,
    CONSTRAINT pk_fato_item_contratado PRIMARY KEY (sk_fato),
    CONSTRAINT uq_fato_item_pncp UNIQUE (numero_controle_pncp, numero_item),
    CONSTRAINT fk_fato_orgao FOREIGN KEY (sk_orgao) REFERENCES dim_orgao (sk_orgao),
    CONSTRAINT fk_fato_fornecedor FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor (sk_fornecedor),
    CONSTRAINT fk_fato_modalidade FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade (sk_modalidade),
    CONSTRAINT fk_fato_localidade FOREIGN KEY (sk_localidade) REFERENCES dim_localidade (sk_localidade),
    CONSTRAINT chk_fato_quantidade CHECK (quantidade > 0),
    CONSTRAINT chk_fato_valores CHECK (
        valor_unitario_estimado > 0
        AND valor_total_estimado >= 1
        AND valor_unitario_homologado > 0
        AND valor_total_homologado >= 0
    ),
    CONSTRAINT chk_fato_comparavel CHECK (comparavel IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;