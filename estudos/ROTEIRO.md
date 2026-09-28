# Roteiro de estudos: Subqueries, CTEs, Window Functions e Datas (T-SQL)

Roteiro para aprender do zero, usando os dados da PCO deste repositório, que você
já conhece. Assim a atenção fica no recurso novo, não nos dados.

- **Ritmo:** cerca de 3h por semana, 6 semanas.
- **Banco:** SQL Server (T-SQL).
- **Respostas:** `estudos/respostas.sql`. Tente resolver antes de olhar.
- **Dados novos:** `data/admissoes.csv` (datas de admissão e de resposta, sintéticas
  e coerentes com `tempo_casa`). Importe com `estudos/setup_admissoes.sql` antes do Módulo 4.

| Semana | Módulo | Tema |
|---|---|---|
| 1 | 0 + 1 | Ordem de execução, `HAVING` e subqueries |
| 2 | 2 | CTEs (`WITH`) |
| 3 | 3 | Window functions I: agregação e ranking |
| 4 | 4 | Funções de data |
| 5 | 5 | Window functions II: ordem, acumulado, `LAG`/`LEAD` |
| 6 | 6 | Desafio integrador |

**Como estudar cada módulo:**
1. Leia a explicação.
2. Rode os exemplos e **mude algo** (outra coluna, outro filtro) para ver o que acontece.
3. Faça os exercícios sem consultar as respostas.
4. Só avance quando conseguir cumprir o checklist do fim do módulo.

---

## Módulo 0: Ordem de execução do SQL (20 min)

O SQL não executa na ordem em que você escreve. A ordem lógica é:

```
1. FROM / JOIN    → junta as tabelas
2. WHERE          → filtra LINHAS
3. GROUP BY       → agrupa
4. HAVING         → filtra GRUPOS
5. SELECT         → calcula colunas (inclusive window functions)
6. ORDER BY       → ordena
7. TOP            → corta o resultado
```

Essa ordem explica vários erros comuns:
- Não dá para usar um alias do `SELECT` no `WHERE`, porque o `WHERE` roda antes.
- Não dá para filtrar um `COUNT(*)` no `WHERE`, porque o agrupamento ainda não aconteceu. Use `HAVING`.
- Window functions são calculadas no passo 5. Por isso não podem ir no `WHERE`. A solução está no Módulo 3.

**Armadilha de divisão inteira.** No SQL Server, `INT / INT` e `AVG` de coluna `INT`
retornam inteiro, e as casas decimais são descartadas.

```sql
SELECT AVG(score)       AS media_errada,   -- retorna 4
       AVG(score * 1.0) AS media_certa     -- retorna 4.3...
FROM responses;
```

É por isso que as fórmulas de percentual usam `100.0 *` no início.

---

## Módulo 1: `HAVING` e subqueries (semana 1)

### 1.1 `HAVING`: filtrar depois de agrupar

`WHERE` filtra linhas antes do `GROUP BY`. `HAVING` filtra os grupos depois dele.

```sql
-- Unidades com mais de 10 respondentes
SELECT unidade, COUNT(*) AS qtd
FROM respondents
GROUP BY unidade
HAVING COUNT(*) > 10;
```

Os dois podem aparecer na mesma query:

```sql
-- Entre quem tem cargo de gestão, departamentos com 3 ou mais pessoas
SELECT departamento, COUNT(*) AS qtd
FROM respondents
WHERE tipo_cargo = N'Cargo de Gestão'   -- filtra pessoas
GROUP BY departamento
HAVING COUNT(*) >= 3;                   -- filtra departamentos
```

### 1.2 Subquery: uma query dentro de outra

Uma subquery é um `SELECT` entre parênteses usado dentro de outra query. Ela pode aparecer em três lugares.

**a) Subquery escalar**, que retorna um único valor. Você já usou uma no cálculo de percentual.

```sql
-- Itens com média acima da média geral
SELECT item_id, AVG(score * 1.0) AS media_item
FROM responses
GROUP BY item_id
HAVING AVG(score * 1.0) > (SELECT AVG(score * 1.0) FROM responses);
```

**b) Subquery com `IN`**, que retorna uma lista de valores.

```sql
-- Respostas apenas dos itens do bloco Liderança, sem JOIN
SELECT AVG(score * 1.0) AS media_lideranca
FROM responses
WHERE item_id IN (SELECT item_id FROM items WHERE bloco = N'Liderança (Imediata)');
```

**c) Subquery no `FROM`** (tabela derivada), que retorna uma tabela inteira. Ela
**precisa de um alias**, como o `AS t` abaixo.

```sql
-- Passo 1 (dentro): favorabilidade de cada pessoa
-- Passo 2 (fora): média dessas favorabilidades por unidade
SELECT t.unidade, AVG(t.pct_pessoa) AS media_pct_pessoas
FROM (
    SELECT resp.respondent_id, resp.unidade,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.respondent_id, resp.unidade
) AS t
GROUP BY t.unidade;
```

Use esse formato sempre que precisar **agregar duas vezes**, por exemplo primeiro por pessoa e depois por unidade.

### 1.3 Subquery correlacionada

É uma subquery que **usa uma coluna da query de fora**. Ela é recalculada para cada linha.

```sql
-- Cada item com a média do SEU bloco ao lado
SELECT i.item_id, i.bloco,
       (SELECT AVG(r2.score * 1.0)
        FROM responses r2
        JOIN items i2 ON i2.item_id = r2.item_id
        WHERE i2.bloco = i.bloco) AS media_do_bloco   -- i.bloco vem da query de fora
FROM items i;
```

Funciona, mas é verbosa. No Módulo 3 você vai fazer a mesma coisa em uma linha com `AVG() OVER`.

### Exercícios 1

1. Departamentos com mais de 5 respondentes.
2. Blocos com favorabilidade (% positivo) abaixo de 80%.
3. Respondentes (`respondent_id`) cuja média de score é menor que a média geral.
4. Usando `IN` e sem JOIN: favorabilidade geral das pessoas com `tempo_casa = 'Menos de 1 ano'`.
5. Tabela derivada: quantos respondentes têm favorabilidade individual de 90% ou mais?
6. Subquery correlacionada: cada respondente com a média de score do **seu departamento** ao lado.

**Checklist:** você sabe explicar a diferença entre `WHERE` e `HAVING`, e sabe quando usar subquery no `WHERE`, no `FROM` e no `SELECT`.

---

## Módulo 2: CTEs (semana 2)

### 2.1 O que é

Uma CTE (*Common Table Expression*) é uma subquery **com nome**, escrita **antes** da
query principal. Ela faz o mesmo que a tabela derivada, mas a leitura segue de cima
para baixo. É como criar uma aba auxiliar no Excel.

```sql
WITH fav_pessoa AS (
    SELECT resp.respondent_id, resp.unidade,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.respondent_id, resp.unidade
)
SELECT unidade, AVG(pct_pessoa) AS media_pct_pessoas
FROM fav_pessoa
GROUP BY unidade;
```

É a mesma query da seção 1.2c, mais fácil de ler.

### 2.2 Regras

- A CTE só existe **durante a query logo abaixo dela**. Depois ela some.
- Se houver outro comando antes do `WITH`, termine esse comando com `;`. Por isso você vai ver `;WITH` em códigos na internet.
- Não pode ter `ORDER BY` dentro da CTE (a não ser com `TOP`). Ordene na query final.

### 2.3 Várias CTEs encadeadas

Separe as CTEs por vírgula. Cada uma pode usar as anteriores.

```sql
WITH fav_pessoa AS (
    SELECT respondent_id,
           100.0 * SUM(CASE WHEN score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_pessoa
    FROM responses
    GROUP BY respondent_id
),
classificacao AS (
    SELECT respondent_id,
           CASE WHEN pct_pessoa >= 90 THEN 'Muito favorável'
                WHEN pct_pessoa >= 80 THEN 'Favorável'
                ELSE 'Atenção' END AS perfil
    FROM fav_pessoa
)
SELECT perfil, COUNT(*) AS qtd
FROM classificacao
GROUP BY perfil;
```

Escreva uma etapa, rode, confira e só então escreva a próxima. **É assim que se
constrói query complexa.**

### 2.4 Usar a mesma CTE duas vezes

```sql
WITH fav_unidade AS (
    SELECT resp.unidade,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.unidade
)
SELECT unidade, pct
FROM fav_unidade
WHERE pct < (SELECT AVG(pct) FROM fav_unidade);   -- a CTE usada de novo
```

### Exercícios 2

1. Reescreva o exercício 1.5 usando CTE.
2. Blocos com favorabilidade acima da média dos blocos (uma CTE, usada duas vezes).
3. Duas CTEs, uma com a favorabilidade por bloco **geral** e outra com a favorabilidade
   por bloco **só da unidade `Serra Alta - GO`**. Junte as duas e mostre a diferença
   em pontos percentuais.
4. Três CTEs encadeadas: favorabilidade por pessoa → classificar em Muito favorável/Favorável/Atenção
   (mesmos cortes do exemplo 2.3) → contar pessoas de cada perfil **por unidade**.

**Checklist:** você consegue pegar qualquer tabela derivada e reescrevê-la como CTE, e
sabe montar uma query em etapas.

---

## Módulo 3: Window functions I, agregação e ranking (semana 3)

### 3.1 A ideia central

`GROUP BY` **junta** as linhas: 62 itens viram 11 blocos. Uma window function **calcula
sobre um grupo, mas mantém todas as linhas**: os 62 itens continuam lá, cada um com o
valor do seu bloco ao lado.

```
função(...) OVER (PARTITION BY coluna ORDER BY coluna)
                  └ define os grupos    └ define a ordem (Módulos 3.3 e 5)
```

- `OVER ()` vazio: o grupo é **a tabela inteira**.
- `OVER (PARTITION BY bloco)`: um grupo **para cada bloco**.

```sql
SELECT item_id, bloco,
       COUNT(*) OVER ()                    AS total_itens,      -- 62 em todas as linhas
       COUNT(*) OVER (PARTITION BY bloco)  AS itens_no_bloco    -- 5, 6, 9...
FROM items;
```

### 3.2 Window function sobre um resultado agrupado

Como o `SELECT` roda depois do `GROUP BY`, a window function pode usar agregações.
É o jeito mais simples de calcular **% do total**:

```sql
SELECT unidade,
       COUNT(*) AS qtd,
       100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS pct_do_total
FROM respondents
GROUP BY unidade;
```

`SUM(COUNT(*)) OVER ()` significa: some as contagens de todos os grupos.

Para comparar cada item com a média do seu bloco (a correlacionada do Módulo 1, agora simples):

```sql
WITH fav_item AS (
    SELECT i.item_id, i.bloco,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_item
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.item_id, i.bloco
)
SELECT item_id, bloco, pct_item,
       AVG(pct_item) OVER (PARTITION BY bloco)            AS media_bloco,
       pct_item - AVG(pct_item) OVER (PARTITION BY bloco) AS diferenca
FROM fav_item
ORDER BY bloco, diferenca;
```

### 3.3 Funções de ranking

Estas funções **exigem `ORDER BY` dentro do `OVER`**.

| Função | Empate | Exemplo com notas 90, 80, 80, 70 |
|---|---|---|
| `ROW_NUMBER()` | Ignora e numera sempre em sequência | 1, 2, 3, 4 |
| `RANK()` | Mesma posição, pula a seguinte | 1, 2, 2, 4 |
| `DENSE_RANK()` | Mesma posição, não pula | 1, 2, 2, 3 |
| `NTILE(4)` | Divide em 4 grupos de tamanho igual (quartis) | 1, 2, 3, 4 |

```sql
WITH fav_depto AS (
    SELECT resp.departamento,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct
    FROM responses r
    JOIN respondents resp ON resp.respondent_id = r.respondent_id
    GROUP BY resp.departamento
)
SELECT departamento, pct,
       ROW_NUMBER() OVER (ORDER BY pct DESC) AS row_num,
       RANK()       OVER (ORDER BY pct DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY pct DESC) AS dense_rnk
FROM fav_depto;
```

### 3.4 O padrão mais pedido em entrevista: Top N por grupo

"O pior item **de cada** bloco", "os 2 melhores blocos **de cada** unidade". `TOP`
não resolve isso, porque corta o resultado inteiro, e não cada grupo.

A receita tem dois passos:
1. Numere dentro de cada grupo com `ROW_NUMBER() OVER (PARTITION BY grupo ORDER BY métrica)`.
2. Filtre `posicao = 1` (ou `<= N`) **fora**, em uma CTE, porque window function não pode ir no `WHERE` (Módulo 0).

```sql
WITH fav_item AS (
    SELECT i.item_id, i.bloco, i.texto,
           100.0 * SUM(CASE WHEN r.score >= 5 THEN 1 ELSE 0 END) / COUNT(*) AS pct_item
    FROM responses r
    JOIN items i ON i.item_id = r.item_id
    GROUP BY i.item_id, i.bloco, i.texto
),
ranqueado AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY bloco ORDER BY pct_item ASC) AS posicao
    FROM fav_item
)
SELECT bloco, item_id, texto, pct_item
FROM ranqueado
WHERE posicao = 1;   -- pior item de cada bloco
```

### Exercícios 3

1. Percentual de respondentes por `faixa_etaria` sobre o total (`SUM(COUNT(*)) OVER ()`).
2. Favorabilidade por departamento, com a favorabilidade da **unidade** ao lado. Dica:
   primeiro agrupe por unidade e departamento, depois use `AVG ... OVER (PARTITION BY unidade)`.
   Pense se a média simples dos departamentos é igual à favorabilidade real da unidade.
3. Ranking dos **itens** por favorabilidade com `RANK` e `DENSE_RANK`. Observe como cada
   função trata os empates (cada item tem 100 respostas, então há muitos percentuais iguais).
4. O **melhor** item de cada bloco.
5. Os 2 blocos com **pior** favorabilidade em cada unidade.
6. Divida os respondentes em 4 quartis (`NTILE(4)`) pela favorabilidade individual.
   Quantas pessoas do quartil 1 (os mais desfavoráveis) há em cada faixa de `tempo_casa`?

**Checklist:** você sabe explicar por que `GROUP BY` reduz linhas e `OVER` não, e
consegue escrever "Top N por grupo" sem consultar.

---

## Módulo 4: Funções de data (semana 4)

Antes, rode `estudos/setup_admissoes.sql`. Ele cria a tabela abaixo.

**admissoes** (1 linha por pessoa)
`respondent_id, data_admissao (DATE), data_resposta (DATETIME2: data + hora)`

### 4.1 Tipos de data

| Tipo | Guarda | Exemplo |
|---|---|---|
| `DATE` | Só a data | `2025-10-06` |
| `DATETIME2` | Data e hora | `2025-10-06 14:32:10` |
| `TIME` | Só a hora | `14:32:10` |

Escreva datas no formato `'AAAA-MM-DD'`, que funciona em qualquer configuração de idioma.

```sql
SELECT GETDATE()                  AS agora,       -- data e hora atuais
       CAST(GETDATE() AS DATE)    AS hoje,        -- remove a hora
       CAST('2025-10-06' AS DATE) AS data_fixa;
```

### 4.2 Extrair partes

```sql
SELECT data_resposta,
       YEAR(data_resposta)              AS ano,
       MONTH(data_resposta)             AS mes,
       DAY(data_resposta)               AS dia,
       DATEPART(QUARTER, data_resposta) AS trimestre,
       DATEPART(HOUR, data_resposta)    AS hora,
       DATEPART(WEEKDAY, data_resposta) AS dia_semana_num
FROM admissoes;
```

`DATENAME` retorna o **nome** da parte. O idioma depende da sessão:

```sql
SET LANGUAGE Brazilian;
SELECT DATENAME(WEEKDAY, data_resposta) AS dia_semana,   -- Segunda-Feira
       DATENAME(MONTH, data_resposta)   AS mes           -- Outubro
FROM admissoes;
```

### 4.3 Diferença entre datas: `DATEDIFF`

`DATEDIFF(unidade, data_inicial, data_final)`

```sql
SELECT respondent_id,
       DATEDIFF(DAY,   data_admissao, data_resposta) AS dias_de_casa,
       DATEDIFF(MONTH, data_admissao, data_resposta) AS meses_de_casa
FROM admissoes;
```

**Armadilha:** `DATEDIFF` conta **quantas viradas** de unidade existem entre as datas,
e não o tempo completo.

```sql
SELECT DATEDIFF(YEAR, '2024-12-31', '2025-01-01');   -- retorna 1, mas passou 1 dia
```

Para anos **completos** (idade, tempo de casa), subtraia 1 quando o aniversário ainda não chegou:

```sql
SELECT respondent_id, data_admissao, data_resposta,
       DATEDIFF(YEAR, data_admissao, data_resposta)
       - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, data_admissao, data_resposta), data_admissao)
                   > CAST(data_resposta AS DATE)
              THEN 1 ELSE 0 END AS anos_completos
FROM admissoes;
```

### 4.4 Somar e subtrair: `DATEADD`

`DATEADD(unidade, quantidade, data)`. Use quantidade negativa para voltar no tempo.

```sql
SELECT data_admissao,
       DATEADD(DAY,   90, data_admissao) AS fim_experiencia,   -- 90 dias depois
       DATEADD(YEAR,   5, data_admissao) AS completa_5_anos,
       DATEADD(MONTH, -1, data_admissao) AS um_mes_antes
FROM admissoes;
```

### 4.5 Montar e arredondar datas

```sql
SELECT data_admissao,
       DATEFROMPARTS(YEAR(data_admissao), MONTH(data_admissao), 1) AS primeiro_dia_mes,
       EOMONTH(data_admissao)                                       AS ultimo_dia_mes,
       DATETRUNC(MONTH, data_admissao)                              AS inicio_mes   -- só SQL Server 2022+
FROM admissoes;
```

### 4.6 Formatar para exibir

```sql
SELECT CONVERT(VARCHAR(10), data_admissao, 103) AS padrao_br,       -- 06/10/2025
       FORMAT(data_admissao, 'MMM/yyyy', 'pt-BR') AS mes_ano        -- out/2025
FROM admissoes;
```

Formate só na **exibição**. Para filtrar, calcular e ordenar, use a data original:
`'06/10/2025'` é texto e ordena errado.

### 4.7 Filtrar períodos

Com `DATETIME2`, `BETWEEN '2025-10-06' AND '2025-10-10'` **perde** as respostas do dia
10 depois da meia-noite. Use `>=` no início e `<` no dia seguinte ao fim:

```sql
-- Respostas da primeira semana (6 a 10/out, inclusive)
SELECT COUNT(*) AS respostas
FROM admissoes
WHERE data_resposta >= '2025-10-06'
  AND data_resposta <  '2025-10-11';
```

### 4.8 Agrupar por período

```sql
SELECT YEAR(data_admissao) AS ano, MONTH(data_admissao) AS mes, COUNT(*) AS admissoes
FROM admissoes
GROUP BY YEAR(data_admissao), MONTH(data_admissao)
ORDER BY ano, mes;
```

### Exercícios 4

1. Quantidade de admissões por ano.
2. Quantidade de respostas por dia da semana (nome em português), ordenada de segunda a sexta.
3. Quantidade de respostas por hora do dia. Em que horário as pessoas mais responderam?
4. Primeira resposta, última resposta e quantos dias corridos a pesquisa ficou aberta.
5. Tempo de casa em anos completos na data da resposta, para cada pessoa.
6. **Checagem de qualidade:** recalcule a faixa de tempo de casa a partir das datas
   (`Menos de 1 ano`, `De 1 a 3 anos`, `De 3 a 5 anos`, `Acima de 5 anos`), usando anos
   completos, e conte quantas pessoas têm faixa diferente da coluna `tempo_casa` de `respondents`.
7. Pessoas que completam 5 anos de casa nos 6 meses seguintes à sua resposta.
8. Data de admissão no formato `dd/mm/aaaa` e último dia do mês de admissão.

**Checklist:** você sabe calcular tempo de casa corretamente, filtrar um período sem
perder registros e agrupar por mês e ano.

---

## Módulo 5: Window functions II, ordem, acumulado e `LAG`/`LEAD` (semana 5)

### 5.1 `ORDER BY` dentro do `OVER` gera acumulado

Com `ORDER BY`, uma agregação passa a considerar as linhas **do início até a atual**:

```sql
WITH por_ano AS (
    SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
    FROM admissoes
    GROUP BY YEAR(data_admissao)
)
SELECT ano, admissoes,
       SUM(admissoes) OVER (ORDER BY ano) AS acumulado
FROM por_ano;
```

### 5.2 Frame: quais linhas entram na conta

O frame define a janela exata de linhas:

```
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW   → do início até a linha atual (acumulado)
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW           → a atual e as 2 anteriores (média móvel de 3)
ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING   → da atual até o fim
```

```sql
WITH por_ano AS (
    SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
    FROM admissoes
    GROUP BY YEAR(data_admissao)
)
SELECT ano, admissoes,
       AVG(admissoes * 1.0) OVER (ORDER BY ano ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS media_movel_3
FROM por_ano;
```

**Boa prática:** escreva `ROWS BETWEEN ...` explicitamente. Sem isso, o padrão é `RANGE`,
que trata valores empatados no `ORDER BY` como uma única linha e pode dar acumulados
inesperados.

### 5.3 `LAG` e `LEAD`: olhar a linha anterior ou a próxima

- `LAG(coluna)`: valor da linha **anterior**.
- `LEAD(coluna)`: valor da **próxima** linha.
- `LAG(coluna, 2)`: valor de 2 linhas atrás.

A primeira linha não tem anterior, então retorna `NULL`.

```sql
WITH por_ano AS (
    SELECT YEAR(data_admissao) AS ano, COUNT(*) AS admissoes
    FROM admissoes
    GROUP BY YEAR(data_admissao)
)
SELECT ano, admissoes,
       LAG(admissoes) OVER (ORDER BY ano)             AS ano_anterior,
       admissoes - LAG(admissoes) OVER (ORDER BY ano) AS variacao
FROM por_ano;
```

É o mesmo padrão do "crescimento mês a mês" que você vai usar no Projeto 1 (Olist).

### 5.4 `PARTITION BY` + `ORDER BY` juntos

O acumulado ou o `LAG` **reinicia em cada grupo**:

```sql
-- Para cada pessoa, a admissão anterior no MESMO departamento
SELECT resp.departamento, a.respondent_id, a.data_admissao,
       LAG(a.data_admissao) OVER (PARTITION BY resp.departamento ORDER BY a.data_admissao) AS admissao_anterior
FROM admissoes a
JOIN respondents resp ON resp.respondent_id = a.respondent_id
ORDER BY resp.departamento, a.data_admissao;
```

### Exercícios 5

1. Respostas por dia da pesquisa, com o total acumulado.
2. Mesmo do anterior, mais a coluna **% de adesão acumulada** (acumulado / 100 pessoas).
   Em que dia a pesquisa passou de 50% de adesão?
3. Admissões por ano com a variação em relação ao ano anterior (`LAG`).
4. Para cada pessoa, quantos dias depois da admissão anterior **no mesmo departamento** ela foi contratada.
5. Admissões por ano com a média móvel de 3 anos.
6. Com `LEAD`: para cada dia da pesquisa, quantas respostas houve no dia seguinte.

**Checklist:** você sabe fazer acumulado, variação em relação ao período anterior e
média móvel, com e sem `PARTITION BY`.

---

## Módulo 6: Desafio integrador (semana 6)

Resolva cada desafio **em etapas com CTEs**, conferindo o resultado de cada etapa.

1. **Favorabilidade por tempo de casa real:** calcule a faixa a partir das datas
   (Módulo 4) e mostre a favorabilidade de cada faixa, ordenada da menor para a maior
   faixa, e não em ordem alfabética.
2. **Pior bloco de cada unidade:** para cada unidade, o bloco com pior favorabilidade e
   quantos pontos percentuais ele está abaixo da favorabilidade geral desse bloco.
3. **Adesão por unidade:** respostas por dia e por unidade, com o acumulado **dentro
   de cada unidade** e o % de adesão da unidade (acumulado / total de pessoas da unidade).
4. **Recém-contratados vs. veteranos:** compare a favorabilidade por bloco entre quem
   tem menos de 1 ano de casa e quem tem 5 anos ou mais, lado a lado, com a diferença.
   Ordene pelos blocos com maior diferença.

**Depois do desafio:**
- Crie um arquivo `exercises_intermediate.sql` no repositório com suas soluções dos
  desafios, comentadas, e atualize o README com a nova seção "What this covers".
- Comece o Projeto 1 (Olist).

---

## Resumo de sintaxe (cola)

```sql
-- HAVING
SELECT col, COUNT(*) FROM t GROUP BY col HAVING COUNT(*) > 5;

-- CTE
WITH a AS (SELECT ...), b AS (SELECT ... FROM a) SELECT ... FROM b;

-- Window
SUM(x)        OVER ()                                   -- total geral
AVG(x)        OVER (PARTITION BY g)                     -- média do grupo
ROW_NUMBER()  OVER (PARTITION BY g ORDER BY x DESC)     -- posição no grupo
SUM(x)        OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  -- acumulado
LAG(x)        OVER (ORDER BY d)                         -- valor anterior

-- Datas
YEAR(d)  MONTH(d)  DAY(d)  DATEPART(HOUR, d)  DATENAME(WEEKDAY, d)
DATEDIFF(DAY, inicio, fim)   DATEADD(MONTH, 3, d)   EOMONTH(d)
DATEFROMPARTS(2025, 10, 1)   CONVERT(VARCHAR(10), d, 103)
WHERE d >= '2025-10-01' AND d < '2025-11-01'           -- mês inteiro
```

**Referência oficial:** documentação do Transact-SQL da Microsoft (learn.microsoft.com).
Pesquise pelos termos "OVER clause", "WITH common_table_expression" e "Date and time data
types and functions".
