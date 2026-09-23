# Organizational Climate Survey — SQL Practice

Hands-on SQL practice using a synthetic organizational climate survey (PCO —
*Pesquisa de Clima Organizacional*) dataset, built in **T-SQL** on SQL Server.

> **The data is 100% synthetic.** Company, business units, departments, and
> respondents are entirely invented. No real client data was used — the scores
> were randomly generated. Only the general *shape* of the results (e.g.
> Compensation scoring lower, Organizational Image scoring higher) was inspired
> by patterns typical of real climate surveys, to keep the exercises realistic.

---

## What this covers

A step-by-step progression through the core SQL skills used to analyze survey
data: filtering, aggregation, conditional classification, multi-table joins,
grouped percentages, and ranking.

- Single-table `SELECT` / `WHERE`
- `CASE WHEN` for classifying scores into Positive / Neutral / Negative
- `JOIN` across 2 and 3 tables (`responses`, `items`, `respondents`)
- `GROUP BY` with one and two columns (cross-tabs)
- Favorability percentage: `100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*)`
- `TOP N` + `ORDER BY` ranking queries

`exercises.sql` has 10 solved exercises, graduated from easiest to hardest,
plus a few extra queries (favorability by business unit, item ranking,
block × unit cross-tabs).

---

## Data model

Three normalized tables, joined together rather than one pre-aggregated table
— the whole point is to practice `JOIN` + `GROUP BY`.

**respondents** (1 row per person, 100 rows)
`respondent_id, sexo, faixa_etaria, tempo_casa, escolaridade, regime, nivel, setor, unidade, departamento, cargo, tipo_cargo, subordinacao`

**items** (1 row per survey question, 62 rows)
`item_id, bloco, texto`

**responses** (1 row per answer — person × question, 6,200 rows)
`respondent_id, item_id, score` — score from 1 to 6 (Strongly disagree → Strongly agree)

Classification used:

| Score | Category |
|---|---|
| 5 or 6 | Positive |
| 3 or 4 | Neutral |
| 1 or 2 | Negative |

Column names and category values inside the CSVs stay in Portuguese, matching
the original survey instrument. Only documentation and query comments are in
English.

---

## How to run

Requires SQL Server (Express or Developer) and SSMS or the MSSQL extension for
VS Code.

1. Create a database and import the 3 CSVs from `data/` (SSMS: **Tasks → Import
   Flat File**, or `CREATE TABLE` manually — see `GUIDE.md`).
2. Run the queries in `exercises.sql` in order.
3. `GUIDE.md` has the full roadmap this project followed, with two worked
   examples if you get stuck.

---

## Structure

```
organizational-climate-survey/
├── data/
│   ├── respondents.csv
│   ├── items.csv
│   └── responses.csv
├── exercises.sql        10 solved exercises, easy to hard
├── GUIDE.md              step-by-step roadmap + worked examples
├── LICENSE
└── README.md
```

---

**Leonardo Iizuka** — psychologist transitioning into data, currently
practicing SQL as part of a move toward people analytics and data analysis.
