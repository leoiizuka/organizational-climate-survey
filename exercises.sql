-- =============================================================
-- Organizational Climate Survey (PCO) — SQL practice exercises
-- SQL Server / T-SQL
-- =============================================================

-- 1. Filter items by block
SELECT * FROM items WHERE bloco = 'Qualidade de Vida';

-- 2. Filter respondents by education level
SELECT * FROM respondents WHERE escolaridade = 'Superior completo';

-- 3. Overall average score
SELECT AVG(score) FROM responses;

-- 4. Count of the lowest score (1) across all responses
SELECT COUNT(*) FROM responses WHERE score = 1;

-- 5. Respondent count by age group
SELECT faixa_etaria, COUNT(*) FROM respondents GROUP BY faixa_etaria;

-- 6. Overall count of Positive / Neutral / Negative responses (no JOIN)
SELECT
    CASE WHEN score >= 5 THEN 'Positive'
         WHEN score >= 3 THEN 'Neutral'
         ELSE 'Negative' END AS category,
    COUNT(*) AS qty,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM responses), 1) AS percentage
FROM responses
GROUP BY
    CASE WHEN score >= 5 THEN 'Positive'
         WHEN score >= 3 THEN 'Neutral'
         ELSE 'Negative' END;

-- 7. % positive favorability by department (responses + respondents JOIN)
SELECT resp.departamento,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN respondents resp ON resp.respondent_id = r.respondent_id
GROUP BY resp.departamento
ORDER BY pct_positive DESC;

-- 8. % positive favorability by role, within the "Treinamento e Desenvolvimento" block
--    (3-table JOIN + WHERE)
SELECT resp.cargo, i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_positive
FROM responses r
JOIN respondents resp ON resp.respondent_id = r.respondent_id
JOIN items i ON i.item_id = r.item_id
WHERE i.bloco = 'Treinamento e Desenvolvimento'
GROUP BY resp.cargo, i.bloco;

-- 9. Favorability crossing tenure (tempo_casa) with block (one row per combination)
SELECT resp.tempo_casa, i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_positive
FROM responses r
JOIN respondents resp ON resp.respondent_id = r.respondent_id
JOIN items i ON i.item_id = r.item_id
GROUP BY resp.tempo_casa, i.bloco;

-- 10. Top 5 departments with the BEST overall favorability
SELECT TOP 5 resp.departamento,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_positive
FROM responses r
JOIN respondents resp ON resp.respondent_id = r.respondent_id
GROUP BY resp.departamento
ORDER BY pct_positive DESC;

-- =============================================================
-- Additional queries (favorability by unit, item ranking, cross-tabs)
-- =============================================================

-- Favorability by block (2-table JOIN)
SELECT i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
GROUP BY i.bloco
ORDER BY pct_positive;

-- Favorability by business unit (unidade)
SELECT resp.unidade,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN respondents resp ON resp.respondent_id = r.respondent_id
GROUP BY resp.unidade
ORDER BY pct_positive DESC;

-- Top 5 worst-scoring items (ranking)
SELECT TOP 5 i.item_id, i.bloco, i.texto,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
GROUP BY i.item_id, i.bloco, i.texto
ORDER BY pct_positive ASC;

-- Cross-tab: block x business unit
SELECT resp.unidade, i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
JOIN respondents resp ON resp.respondent_id = r.respondent_id
GROUP BY resp.unidade, i.bloco
ORDER BY resp.unidade, i.bloco;

-- Same cross-tab, filtered to one block (note the N'...' prefix for accented text)
SELECT resp.unidade, i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
JOIN respondents resp ON resp.respondent_id = r.respondent_id
WHERE i.bloco = N'Remuneração e Benefícios'
GROUP BY resp.unidade, i.bloco
ORDER BY pct_positive;
