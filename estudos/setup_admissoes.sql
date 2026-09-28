-- =============================================================
-- Setup da tabela "admissoes" (necessária a partir do Módulo 4)
-- Dados sintéticos: datas de admissão coerentes com respondents.tempo_casa,
-- respostas entre 06/10/2025 e 23/10/2025 (dias úteis, horário comercial).
-- =============================================================

CREATE TABLE admissoes (
    respondent_id INT PRIMARY KEY,
    data_admissao DATE,
    data_resposta DATETIME2(0)
);

-- Opção 1: Import Wizard (SSMS: Tasks -> Import Flat File / Azure Data Studio: Import Wizard)
--          apontando para data/admissoes.csv e escolhendo a tabela existente.

-- Opção 2: BULK INSERT (troque o caminho pelo local do seu clone)
BULK INSERT admissoes
FROM 'C:\caminho\para\organizational-climate-survey\data\admissoes.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

-- Conferência: deve retornar 100
SELECT COUNT(*) FROM admissoes;
