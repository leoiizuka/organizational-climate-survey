# SQL Practice — Organizational Climate Survey (synthetic data)

Synthetic dataset, structured like a real PCO (the same standard instrument used in
practice — 62 items, 11 blocks/categories), but with a fully invented company, business
units, departments, and respondents. No real client data was used — the numbers were
randomly generated; only the general *shape* of the results (e.g. Compensation scoring
lowest, Organizational Image scoring highest, etc.) was inspired by typical PCO patterns,
to keep the exercise realistic.

## Files

- `respondents.csv`, `items.csv`, `responses.csv` — the 3 CSVs to import into SQL Server.
- `pco_pratica.db` — the same data already loaded into SQLite, as a quick alternative if
  you want to test outside SQL Server (opens with the free DB Browser for SQLite).

## How to import the CSVs into SQL Server (Azure Data Studio or SSMS)

Both Microsoft T-SQL tools (Azure Data Studio and SQL Server Management Studio) have an
import wizard that creates the table automatically from the CSV:

1. Connect to your server and, with the database selected, right-click the database →
   **Import Wizard** (Azure Data Studio) or **Tasks → Import Flat File** (SSMS).
2. Point to `respondents.csv`, name the table `respondents`, let the wizard detect the
   column types (all text, except `respondent_id` which is an integer), and finish.
3. Repeat for `items.csv` (table `items`) and `responses.csv` (table `responses`).

If you'd rather create the tables yourself before importing (more control over the
types), the T-SQL `CREATE TABLE` statements are:

```sql
CREATE TABLE respondents (
  respondent_id INT PRIMARY KEY,
  sexo NVARCHAR(20), faixa_etaria NVARCHAR(20), tempo_casa NVARCHAR(20),
  escolaridade NVARCHAR(20), regime NVARCHAR(20), nivel NVARCHAR(20),
  setor NVARCHAR(20), unidade NVARCHAR(30), departamento NVARCHAR(40),
  cargo NVARCHAR(40), tipo_cargo NVARCHAR(40), subordinacao NVARCHAR(60)
);

CREATE TABLE items (
  item_id INT PRIMARY KEY,
  bloco NVARCHAR(50),
  texto NVARCHAR(500)
);

CREATE TABLE responses (
  respondent_id INT,
  item_id INT,
  score INT
);
```

Then just use the Import Wizard pointing to the right CSV and choosing "use existing
table" instead of creating a new one.

## Structure (relational model — the reason for 3 tables instead of 1 is precisely to
practice JOIN)

**respondents** (1 row per person, 100 rows)
`respondent_id, sexo, faixa_etaria, tempo_casa, escolaridade, regime, nivel, setor, unidade, departamento, cargo, tipo_cargo, subordinacao`

**items** (1 row per survey question, 62 rows)
`item_id, bloco, texto`

**responses** (1 row per answer — person × question, 6,200 rows)
`respondent_id, item_id, score` — score from 1 to 6 (Strongly disagree → Strongly agree)

Classification used:
- **Positive** = score 5 or 6
- **Neutral** = score 3 or 4
- **Negative** = score 1 or 2

## Suggested roadmap (in order — each step builds on the previous one)

1. **Check the data**: `SELECT COUNT(*) FROM respondents;` / `items` / `responses`. Look
   at a few respondents and items with `SELECT TOP 10 * FROM ...;` (in T-SQL, `TOP` comes
   right after `SELECT`, unlike SQLite/Postgres's `LIMIT` which comes at the end).
2. **Overall favorability** (replicates the "General Summary" tab): from `responses`,
   classify each score as positive/neutral/negative
   (`CASE WHEN score >= 5 THEN 'Positive' WHEN score >= 3 THEN 'Neutral' ELSE 'Negative' END`)
   and calculate the % of each category over the total number of responses.
3. **Favorability by block** (replicates "Summary by Block"): same logic as step 2, but
   `JOIN` `responses` with `items` (via `item_id`) and `GROUP BY bloco`.
4. **Favorability by item**: same idea, but `GROUP BY item_id` — which specific questions
   have the most negative responses?
5. **Favorability by demographic group** (replicates the "Gender", "Business Unit",
   "Department" tabs, etc.): now join all 3 tables — `responses JOIN items JOIN
   respondents` — and `GROUP BY` `sexo`, then `unidade`, then `departamento`, always
   calculating the % positive.
6. **Finer cross-tabs**: favorability by block *within* each group (e.g. how does
   "Remuneração e Benefícios" break down by `unidade`?) — `GROUP BY` with two columns.
7. **Ranking**: what are the 5 items with the worst favorability? Which groups (e.g.
   business unit, department) have the lowest overall favorability? (`ORDER BY` + `TOP 5`,
   instead of `LIMIT`)
8. **Optional, more advanced**: a window function (`AVG(...) OVER (PARTITION BY bloco)`)
   to compare each item against its block's average without needing a subquery.

## Two worked examples to get you started (the rest is up to you)

Simple count by response category, overall:

```sql
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
```

Favorability by block (joins `responses` with `items`):

```sql
SELECT
  i.bloco,
  ROUND(100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive
FROM responses r
JOIN items i ON i.item_id = r.item_id
GROUP BY i.bloco
ORDER BY pct_positive;
```

From here on, step 5 onward (joining `respondents`) is up to you.
