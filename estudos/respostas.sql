-- =============================================================
-- Respostas dos exercícios do estudos/ROTEIRO.md
-- SQL Server / T-SQL
-- Existem outras soluções corretas; compare o RESULTADO, não só o código.
-- =============================================================


-- =============================================================
-- MÓDULO 1: HAVING e subqueries
-- =============================================================

-- 1.1 Departamentos com mais de 5 respondentes
SELECT departamento, COUNT(*) AS qtd
FROM respondents
GROUP BY departamento
HAVING COUNT(*) > 5
ORDER BY qtd DESC;

-- 1.2 Blocos com favorabilidade abaixo de 80%
SELECT i.bloco,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
GROUP BY i.bloco
HAVING 100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) < 80   -- alias não funciona no HAVING
ORDER BY pct_positive;

-- 1.3 Respondentes com média abaixo da média geral
SELECT respondent_id, AVG(score * 1.0) AS media_pessoa
FROM responses
GROUP BY respondent_id
HAVING AVG(score * 1.0) < (SELECT AVG(score * 1.0) FROM responses)
ORDER BY media_pessoa;

-- 1.4 Favorabilidade de quem tem menos de 1 ano de casa (IN, sem JOIN)
SELECT ROUND(100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses
WHERE respondent_id IN (SELECT respondent_id FROM respondents WHERE tempo_casa = 'Menos de 1 ano');

-- 1.5 Quantos respondentes têm favorabilidade individual >= 90% (tabela derivada)
SELECT COUNT(*) AS qtd_pessoas
FROM (
    SELECT respondent_id,
        100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses
    GROUP BY respondent_id
) AS t
WHERE t.pct_pessoa >= 90;

-- 1.6 Cada respondente com a média do seu departamento (correlacionada)
SELECT resp.respondent_id, resp.departamento,
    (SELECT AVG(r.score * 1.0) FROM responses r WHERE r.respondent_id = resp.respondent_id) AS media_pessoa,
    (SELECT AVG(r2.score * 1.0)
     FROM responses r2
     JOIN respondents resp2 ON resp2.respondent_id = r2.respondent_id
     WHERE resp2.departamento = resp.departamento) AS media_departamento
FROM respondents resp
ORDER BY resp.departamento, resp.respondent_id;


-- =============================================================
-- MÓDULO 2: CTEs
-- =============================================================

-- 2.1 Exercício 1.5 com CTE
WITH fav_pessoa AS (
    SELECT respondent_id,
        100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses
    GROUP BY respondent_id
)
SELECT COUNT(*) AS qtd_pessoas
FROM fav_pessoa
WHERE pct_pessoa >= 90;

-- 2.2 Blocos acima da média dos blocos
WITH fav_bloco AS (
    SELECT i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.bloco
)
SELECT bloco, ROUND(pct, 1) AS pct
FROM fav_bloco
WHERE pct > (SELECT AVG(pct) FROM fav_bloco)
ORDER BY pct DESC;

-- 2.3 Bloco: geral vs. Serra Alta - GO
WITH geral AS (
    SELECT i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_geral
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.bloco
),
serra_alta AS (
    SELECT i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_unidade
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    WHERE resp.unidade = 'Serra Alta - GO'
    GROUP BY i.bloco
)
SELECT g.bloco,
    ROUND(g.pct_geral, 1)                 AS pct_geral,
    ROUND(s.pct_unidade, 1)               AS pct_serra_alta,
    ROUND(s.pct_unidade - g.pct_geral, 1) AS diferenca_pp
FROM geral g
JOIN serra_alta s ON s.bloco = g.bloco
ORDER BY diferenca_pp;

-- 2.4 Perfil das pessoas por unidade (3 CTEs encadeadas)
WITH fav_pessoa AS (
    SELECT resp.respondent_id, resp.unidade,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.respondent_id, resp.unidade
),
classificacao AS (
    SELECT respondent_id, unidade,
        CASE WHEN pct_pessoa >= 90 THEN 'Muito favorável'
             WHEN pct_pessoa >= 80 THEN 'Favorável'
             ELSE 'Atenção' END AS perfil
    FROM fav_pessoa
),
contagem AS (
    SELECT unidade, perfil, COUNT(*) AS qtd
    FROM classificacao
    GROUP BY unidade, perfil
)
SELECT unidade, perfil, qtd
FROM contagem
ORDER BY unidade, perfil;


-- =============================================================
-- MÓDULO 3: Window functions I
-- =============================================================

-- 3.1 % de respondentes por faixa etária
SELECT faixa_etaria,
    COUNT(*) AS qtd,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_do_total
FROM respondents
GROUP BY faixa_etaria
ORDER BY faixa_etaria;

-- 3.2 Favorabilidade por departamento com a da unidade ao lado
-- Resposta à pergunta: a média simples dos departamentos NÃO é igual à favorabilidade real
-- da unidade quando os departamentos têm tamanhos diferentes. Para o valor real, a conta
-- tem que ser feita sobre as respostas (acumulando positivos e totais), como abaixo.
WITH fav_depto AS (
    SELECT resp.unidade, resp.departamento,
        SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) AS positivos,
        COUNT(*) AS total
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.unidade, resp.departamento
)
SELECT unidade, departamento,
    ROUND(100.0 * positivos / total, 1) AS pct_depto,
    ROUND(AVG(100.0 * positivos / total) OVER (PARTITION BY unidade), 1) AS media_simples_deptos,
    ROUND(100.0 * SUM(positivos) OVER (PARTITION BY unidade)
                / SUM(total)     OVER (PARTITION BY unidade), 1)         AS pct_real_unidade
FROM fav_depto
ORDER BY unidade, pct_depto DESC;

-- 3.3 Ranking dos itens (repare nos empates: RANK pula posições, DENSE_RANK não)
WITH fav_item AS (
    SELECT item_id,
        100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct
    FROM responses
    GROUP BY item_id
)
SELECT item_id, pct,
    RANK()       OVER (ORDER BY pct DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY pct DESC) AS dense_rnk
FROM fav_item
ORDER BY pct DESC;

-- 3.4 Melhor item de cada bloco
WITH fav_item AS (
    SELECT i.item_id, i.bloco, i.texto,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_item
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.item_id, i.bloco, i.texto
),
ranqueado AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY bloco ORDER BY pct_item DESC) AS posicao
    FROM fav_item
)
SELECT bloco, item_id, texto, ROUND(pct_item, 1) AS pct_item
FROM ranqueado
WHERE posicao = 1
ORDER BY pct_item DESC;

-- 3.5 Os 2 piores blocos de cada unidade
WITH fav AS (
    SELECT resp.unidade, i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.unidade, i.bloco
),
ranqueado AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY unidade ORDER BY pct ASC) AS posicao
    FROM fav
)
SELECT unidade, posicao, bloco, ROUND(pct, 1) AS pct
FROM ranqueado
WHERE posicao <= 2
ORDER BY unidade, posicao;

-- 3.6 Quartil 1 (mais desfavoráveis) por tempo de casa
WITH fav_pessoa AS (
    SELECT respondent_id,
        100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses
    GROUP BY respondent_id
),
quartis AS (
    SELECT respondent_id, pct_pessoa,
        NTILE(4) OVER (ORDER BY pct_pessoa ASC) AS quartil
    FROM fav_pessoa
)
SELECT resp.tempo_casa, COUNT(*) AS qtd_no_quartil_1
FROM quartis q
JOIN respondents resp ON resp.respondent_id = q.respondent_id
WHERE q.quartil = 1   -- aqui pode filtrar: o NTILE foi calculado na CTE anterior
GROUP BY resp.tempo_casa
ORDER BY qtd_no_quartil_1 DESC;


-- =============================================================
-- MÓDULO 4: Funções de data
-- =============================================================

-- 4.1 Admissões por ano
SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
FROM admissoes
GROUP BY YEAR(data_admissao)
ORDER BY ano;

-- 4.2 Respostas por dia da semana, de segunda a sexta
-- DATEPART(WEEKDAY) depende do DATEFIRST (primeiro dia da semana). SET DATEFIRST 1 = segunda.
SET LANGUAGE Brazilian;
SET DATEFIRST 1;
SELECT DATEPART(WEEKDAY, data_resposta) AS num_dia,
    DATENAME(WEEKDAY, data_resposta)    AS dia_semana,
    COUNT(*) AS respostas
FROM admissoes
GROUP BY DATEPART(WEEKDAY, data_resposta), DATENAME(WEEKDAY, data_resposta)
ORDER BY num_dia;

-- 4.3 Respostas por hora
SELECT DATEPART(HOUR, data_resposta) AS hora, COUNT(*) AS respostas
FROM admissoes
GROUP BY DATEPART(HOUR, data_resposta)
ORDER BY respostas DESC;

-- 4.4 Período da pesquisa
SELECT MIN(data_resposta) AS primeira_resposta,
    MAX(data_resposta)    AS ultima_resposta,
    DATEDIFF(DAY, MIN(data_resposta), MAX(data_resposta)) + 1 AS dias_corridos   -- +1 conta o 1º dia
FROM admissoes;

-- 4.5 Anos completos de casa na data da resposta
SELECT respondent_id, data_admissao, CAST(data_resposta AS DATE) AS data_resposta,
    DATEDIFF(YEAR, data_admissao, data_resposta)
    - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, data_admissao, data_resposta), data_admissao)
                > CAST(data_resposta AS DATE)
           THEN 1 ELSE 0 END AS anos_completos
FROM admissoes
ORDER BY anos_completos DESC;

-- 4.6 Checagem de qualidade: faixa calculada vs. faixa informada
WITH anos AS (
    SELECT respondent_id,
        DATEDIFF(YEAR, data_admissao, data_resposta)
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, data_admissao, data_resposta), data_admissao)
                    > CAST(data_resposta AS DATE)
               THEN 1 ELSE 0 END AS anos_completos
    FROM admissoes
),
faixa AS (
    SELECT respondent_id,
        CASE WHEN anos_completos < 1 THEN 'Menos de 1 ano'
             WHEN anos_completos < 3 THEN 'De 1 a 3 anos'
             WHEN anos_completos < 5 THEN 'De 3 a 5 anos'
             ELSE 'Acima de 5 anos' END AS faixa_calculada
    FROM anos
)
SELECT COUNT(*) AS divergencias   -- esperado: 0
FROM faixa f
JOIN respondents resp ON resp.respondent_id = f.respondent_id
WHERE f.faixa_calculada <> resp.tempo_casa;

-- 4.7 Completam 5 anos de casa nos 6 meses seguintes à resposta
SELECT respondent_id, data_admissao,
    DATEADD(YEAR, 5, data_admissao) AS completa_5_anos
FROM admissoes
WHERE DATEADD(YEAR, 5, data_admissao) >  CAST(data_resposta AS DATE)
  AND DATEADD(YEAR, 5, data_admissao) <= DATEADD(MONTH, 6, CAST(data_resposta AS DATE))
ORDER BY completa_5_anos;

-- 4.8 Formato brasileiro e último dia do mês
SELECT respondent_id,
    CONVERT(VARCHAR(10), data_admissao, 103) AS admissao_br,
    EOMONTH(data_admissao)                   AS ultimo_dia_mes
FROM admissoes;


-- =============================================================
-- MÓDULO 5: Window functions II
-- =============================================================

-- 5.1 e 5.2 Respostas por dia, acumulado e % de adesão
WITH por_dia AS (
    SELECT CAST(data_resposta AS DATE) AS dia, COUNT(*) AS respostas
    FROM admissoes
    GROUP BY CAST(data_resposta AS DATE)
)
SELECT dia, respostas,
    SUM(respostas) OVER (ORDER BY dia ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado,
    100.0 * SUM(respostas) OVER (ORDER BY dia ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / (SELECT COUNT(*) FROM respondents) AS pct_adesao
FROM por_dia
ORDER BY dia;
-- O dia em que passou de 50% é o primeiro com pct_adesao > 50.

-- 5.3 Admissões por ano e variação vs. ano anterior
WITH por_ano AS (
    SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
    FROM admissoes
    GROUP BY YEAR(data_admissao)
)
SELECT ano, admissoes,
    LAG(admissoes) OVER (ORDER BY ano)             AS ano_anterior,
    admissoes - LAG(admissoes) OVER (ORDER BY ano) AS variacao
FROM por_ano
ORDER BY ano;

-- 5.4 Dias desde a admissão anterior no mesmo departamento
SELECT resp.departamento, a.respondent_id, a.data_admissao,
    DATEDIFF(DAY,
        LAG(a.data_admissao) OVER (PARTITION BY resp.departamento ORDER BY a.data_admissao),
        a.data_admissao) AS dias_desde_anterior
FROM admissoes a
JOIN respondents resp ON resp.respondent_id = a.respondent_id
ORDER BY resp.departamento, a.data_admissao;

-- 5.5 Média móvel de 3 anos
WITH por_ano AS (
    SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
    FROM admissoes
    GROUP BY YEAR(data_admissao)
)
SELECT ano, admissoes,
    ROUND(AVG(admissoes * 1.0) OVER (ORDER BY ano ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS media_movel_3
FROM por_ano
ORDER BY ano;

-- 5.6 Respostas do dia seguinte (LEAD)
WITH por_dia AS (
    SELECT CAST(data_resposta AS DATE) AS dia, COUNT(*) AS respostas
    FROM admissoes
    GROUP BY CAST(data_resposta AS DATE)
)
SELECT dia, respostas,
    LEAD(respostas) OVER (ORDER BY dia) AS respostas_dia_seguinte
FROM por_dia
ORDER BY dia;


-- =============================================================
-- MÓDULO 6: Desafio integrador
-- =============================================================

-- D1 Favorabilidade por faixa de tempo de casa calculada pelas datas
WITH anos AS (
    SELECT respondent_id,
        DATEDIFF(YEAR, data_admissao, data_resposta)
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, data_admissao, data_resposta), data_admissao)
                    > CAST(data_resposta AS DATE)
               THEN 1 ELSE 0 END AS anos_completos
    FROM admissoes
),
faixa AS (
    SELECT respondent_id,
        CASE WHEN anos_completos < 1 THEN 1
             WHEN anos_completos < 3 THEN 2
             WHEN anos_completos < 5 THEN 3
             ELSE 4 END AS ordem_faixa,   -- número só para ordenar corretamente
        CASE WHEN anos_completos < 1 THEN 'Menos de 1 ano'
             WHEN anos_completos < 3 THEN 'De 1 a 3 anos'
             WHEN anos_completos < 5 THEN 'De 3 a 5 anos'
             ELSE 'Acima de 5 anos' END AS faixa
    FROM anos
)
SELECT f.ordem_faixa, f.faixa,
    COUNT(DISTINCT f.respondent_id) AS pessoas,
    ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM faixa f
JOIN responses r ON r.respondent_id = f.respondent_id
GROUP BY f.ordem_faixa, f.faixa
ORDER BY f.ordem_faixa;

-- D2 Pior bloco de cada unidade vs. favorabilidade geral do bloco
WITH geral AS (
    SELECT i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_geral
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.bloco
),
por_unidade AS (
    SELECT resp.unidade, i.bloco,
        100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_unidade
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.unidade, i.bloco
),
ranqueado AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY unidade ORDER BY pct_unidade ASC) AS posicao
    FROM por_unidade
)
SELECT r.unidade, r.bloco,
    ROUND(r.pct_unidade, 1)               AS pct_unidade,
    ROUND(g.pct_geral, 1)                 AS pct_geral_bloco,
    ROUND(r.pct_unidade - g.pct_geral, 1) AS diferenca_pp
FROM ranqueado r
JOIN geral g ON g.bloco = r.bloco
WHERE r.posicao = 1
ORDER BY diferenca_pp;

-- D3 Adesão diária por unidade
WITH por_dia AS (
    SELECT resp.unidade, CAST(a.data_resposta AS DATE) AS dia, COUNT(*) AS respostas
    FROM admissoes a
    JOIN respondents resp ON resp.respondent_id = a.respondent_id
    GROUP BY resp.unidade, CAST(a.data_resposta AS DATE)
),
tamanho AS (
    SELECT unidade, COUNT(*) AS pessoas
    FROM respondents
    GROUP BY unidade
)
SELECT d.unidade, d.dia, d.respostas,
    SUM(d.respostas) OVER (PARTITION BY d.unidade ORDER BY d.dia
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado,
    ROUND(100.0 * SUM(d.respostas) OVER (PARTITION BY d.unidade ORDER BY d.dia
                                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                / t.pessoas, 1) AS pct_adesao_unidade
FROM por_dia d
JOIN tamanho t ON t.unidade = d.unidade
ORDER BY d.unidade, d.dia;

-- D4 Recém-contratados (< 1 ano) vs. veteranos (5+ anos) por bloco
WITH anos AS (
    SELECT respondent_id,
        DATEDIFF(YEAR, data_admissao, data_resposta)
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, data_admissao, data_resposta), data_admissao)
                    > CAST(data_resposta AS DATE)
               THEN 1 ELSE 0 END AS anos_completos
    FROM admissoes
),
comparacao AS (
    SELECT i.bloco,
        -- "Agregação condicional": cada CASE conta só o grupo de interesse (NULL é ignorado)
        100.0 * SUM(CASE WHEN a.anos_completos < 1  AND r.score >= 5 THEN 1 ELSE 0 END)
              / NULLIF(SUM(CASE WHEN a.anos_completos < 1  THEN 1 ELSE 0 END), 0) AS pct_recem,
        100.0 * SUM(CASE WHEN a.anos_completos >= 5 AND r.score >= 5 THEN 1 ELSE 0 END)
              / NULLIF(SUM(CASE WHEN a.anos_completos >= 5 THEN 1 ELSE 0 END), 0) AS pct_veteranos
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    JOIN anos a ON a.respondent_id = r.respondent_id
    GROUP BY i.bloco
)
SELECT bloco,
    ROUND(pct_recem, 1)                     AS pct_recem_contratados,
    ROUND(pct_veteranos, 1)                 AS pct_veteranos,
    ROUND(pct_recem - pct_veteranos, 1)     AS diferenca_pp
FROM comparacao
ORDER BY ABS(pct_recem - pct_veteranos) DESC;
