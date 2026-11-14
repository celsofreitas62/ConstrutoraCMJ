# Mapa: Padrão de origem → SistemaCMJ

O padrão deste projeto vem do padrão SQL/e-mail que o Celso mantém profissionalmente (regras numeradas 1 a 75 + 11 regras de e-mail). Este mapa mostra onde cada regra de origem está aqui, para nada se perder. Informações internas da empresa de origem (servidores, endereços, logins, tabelas do ERP) **não** foram trazidas: não pertencem a este projeto.

Legenda: **SQL n** = [PADRAO_SQL.md](PADRAO_SQL.md) · **EMAIL n** = [PADRAO_EMAIL.md](PADRAO_EMAIL.md) · **BP n** = [BOAS_PRATICAS.md](BOAS_PRATICAS.md) · **N/A** = não se aplica (motivo).

## Regras SQL

| Origem | Assunto | Aqui |
|---|---|---|
| 1 | Cabeçalho de governança e changelog | SQL 1, GABARITOS §1 |
| 2 | `NOCOUNT` + `XACT_ABORT` | SQL 2 |
| 3 | Set-based, sem rastreador I/U/D | SQL 6 |
| 4 | Acumulador por delta | SQL 9 |
| 5 | `WITH (NOLOCK)` em leitura | SQL 21 |
| 6 | Early return, sem `ELSE` aninhado | SQL 7 |
| 7 | TRY/CATCH + log de erro | SQL 13 |
| 8 | Limpeza de `#temp` | SQL 19 |
| 9, 10 | Anti-NULL e matemática protegida | SQL 8 |
| 11 | ID centralizado | SQL 23 (SEQUENCE / tabela de numeração) |
| 12 | Tipagem espelhada | SQL 24-26 |
| 13 | Laço isolado (fail-safe) | SQL 13 |
| 14 | Trigger sem recursão por `WHERE` | SQL 20 |
| 15 | Unificar histórico ativo + arquivado | SQL 44 |
| 16 | `INNER JOIN` em UPDATE com flag de força | SQL 41 |
| 17 | `CREATE OR ALTER` | SQL 3 |
| 18 | `#temp` em vez de CTE em trigger | SQL 19 |
| 19 | Schema padrão | SQL 31 (schemas por módulo, a confirmar) |
| 20 | Fail-safe por bloco | SQL 13 |
| 21 | Data sentinela / piso técnico | SQL 25, SQL 43 |
| 22 | Nomenclatura e fn x tsp | SQL 29-30 (sem prefixo de pacote: não há DataFlex) |
| 23 | Tipo exato em `SET @v = col = expr` | SQL 12 |
| 24 | `EXEC` só com constante/variável | SQL 11 |
| 25 | `;` após `END CATCH` | SQL 14 |
| 26 | Checkpoint incremental | SQL 45 |
| 27, 33 | Dicionário do ERP | N/A (não há ERP integrado) |
| 28 | Não alterar tabela do DataFlex | N/A (sem DataFlex; tabelas são do próprio projeto) |
| 29, 52 | Como devolver erro ao chamador | SQL 18 |
| 30 | `CAST` de colunas `MAX` | SQL 26 |
| 31 | Trigger de notificação não propaga erro | SQL 18 |
| 32 | Modo teste não grava checkpoint | SQL 36, SQL 45 |
| 34 | Nunca `DATENAME` em texto | SQL 28 |
| 35 | Feature flag por parâmetro | SQL 46 |
| 36 | Savepoint quando chamada aninhada | SQL 17 |
| 37 | Trace passo a passo | SQL 47 |
| 38 | Flag "reafirmado" em trigger | SQL 48 |
| 39 | Tudo-ou-nada (estoque) | SQL 16 (aplicado ao financeiro) |
| 41 | `Find gt` do DataFlex | N/A (sem DataFlex; na migração do Access, conferir `>` x `>=` caso a caso) |
| 42 | `ISNULL` em toda coluna `NOT NULL` | SQL 42 |
| 43, 44 | Chamada SQL e e-mail pelo DataFlex | N/A (sem DataFlex) |
| 45 | Assunto texto puro | EMAIL 14 |
| 46 | `TOP 1` com `ORDER BY` e filtro | SQL 10 |
| 47 | Anexo com acento (NFC/NFD) | SQL 51, EMAIL 24 |
| 48 | `SYNONYM` entre bancos | SQL 50 |
| 48 (2ª) | Chave composta de duas fontes | SQL 49 |
| 49 | `UPDLOCK, HOLDLOCK` | SQL 22 |
| 50 | `@bRunLocal` autodetectado | SQL 36, EMAIL 9 |
| 51, 62 | `QUOTED_IDENTIFIER ON` na criação | SQL 4 |
| 53 | NULL cru para a API | SQL 27 |
| 54 | Acentos no corpo do e-mail | EMAIL 13 |
| 55 | Grupo único misto interno/externo | EMAIL 10 |
| 56 | E-mail sempre por fila | EMAIL 1 |
| 58 | Chamada HTTP externa via executor/fila | SQL 53 |
| 60 | Sem emoji | EMAIL 15 |
| 61 | `SESSION_CONTEXT` para identidade em trigger | SQL 34, GABARITOS §5 |
| 63, 69, 70, 71 | Limites do conector DataFlex/ODBC | N/A (sem DataFlex); princípio mantido: testar pelo caminho real = SQL 52 |
| 64 | BOM do PowerShell | SQL 38, BP 9 |
| 65 | Sem RECNUM | SQL 32 |
| 66 | Automação em estação + credencial DPAPI | SQL 54 (credenciais); agendamento no serviço da aplicação |
| 67 | `sqlcmd -f 65001` | SQL 55 |
| 68 | Date x DateTime no DataFlex | SQL 25 (`DATE` x `DATETIME2(0)`) |
| 72-75 | DataDictionary do DataFlex | N/A (sem DataFlex) |

## Regras de e-mail (Premium)

| Origem | Assunto | Aqui |
|---|---|---|
| 1 | CSS incorporado, container | EMAIL 16 |
| 2 | Cabeçalho azul/vermelho | EMAIL 17 (azul da CMJ a definir) |
| 3 | Tabela zebrada, alinhamentos | EMAIL 18 |
| 4 | Assunto com emoji + documento rastreador | EMAIL 22 (documento rastreador mantido; emoji substituído pela regra 60) |
| 5 | Rodapé de rastreio | EMAIL §4 |
| 6 | Erro técnico só para a T.I. | EMAIL 5 |
| 7 | Auto-cura do Database Mail | EMAIL 3 (retentativa no serviço; Express não tem Database Mail) |
| 8 | Anti-acento HTML | EMAIL 12-13 |
| 9 | Unificar colunas por largura | EMAIL 20 |
| 10 | `@bRunLocal` | EMAIL 9 |
| 11 | Conta interna x externa | EMAIL 10 |

## Gabaritos

Os quatro modelos de origem (orquestrador de e-mail, procedure pura, trigger, function de lookup) estão reescritos em [GABARITOS.md](GABARITOS.md) com a mesma estrutura, mais o modelo de procedure chamada pela tela (`SUCESSO`/`MENSAGEM`).
