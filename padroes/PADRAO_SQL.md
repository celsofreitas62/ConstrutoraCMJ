# Padrão SQL do SistemaCMJ (T-SQL / SQL Server Express)

Regras obrigatórias para toda procedure, trigger, function, view e script T-SQL do projeto. Vieram do padrão que o autor (Celso de Freitas) usa profissionalmente há anos em produção, adaptadas para um sistema novo, sem DataFlex, com SQL Server **Express**.

Aplicar sempre, sem precisar repetir a cada pedido. Se um pedido conflitar com alguma regra, **perguntar antes de desviar**.

---

## 1. Estrutura de todo objeto

1. **Cabeçalho de governança**: todo script começa com um bloco de comentário com Autor, Refatorado por (`Claude` quando feito com o Claude), Data, Versão e **changelog por versão** (o que mudou e por quê). Ver o modelo em [GABARITOS.md](GABARITOS.md).
2. **`SET NOCOUNT ON` + `SET XACT_ABORT ON`** no início do corpo. Exceção: o processador de fila (laço por registro) omite o `XACT_ABORT` para que um registro ruim não derrube o lote (ver regra 13).
3. **`CREATE OR ALTER`** sempre (procedures, functions, views, triggers): o mesmo script serve para a 1ª criação e para qualquer revisão, em qualquer ambiente.
4. **`SET QUOTED_IDENTIFIER ON; GO` antes de todo `CREATE OR ALTER`** e antes de `CREATE INDEX` filtrado. O valor fica gravado no objeto no momento da criação; se ficar `OFF`, `FOR XML PATH`, métodos XML e índices filtrados falham depois com erro 1934.
5. **`@EtapaAtual`** (VARCHAR) atualizada antes de cada bloco relevante e usada na mensagem do `CATCH`, para saber exatamente onde falhou.

## 2. Lógica

6. **Set-based sempre**: nada de cursor/laço quando um `UPDATE`/`INSERT ... SELECT` resolve. Em trigger, proibido variável que "descobre" se foi INSERT/UPDATE/DELETE: cruzar `inserted` e `deleted` com `JOIN`.
7. **Early return**: abortar o quanto antes quando um pré-requisito falha (parâmetro nulo, lista vazia, destinatário vazio). Evitar `IF/ELSE IF/ELSE` aninhado: casos especiais saem com `RETURN`; o caso padrão fica solto no fim, sem `ELSE`.
8. **Vacina anti-NULL**: nunca concatenar sem `ISNULL(Campo, '')` (um NULL apaga a string inteira). Function nunca devolve `NULL` ao chamador. Valores numéricos protegidos com `ISNULL` antes de somar/dividir; divisão sempre com `NULLIF(divisor, 0)`.
9. **Acumuladores por delta**: saldo/total mantido por trigger usa `UNION ALL` de `inserted` (positivo) e `deleted` (negativo), agrupado pela chave, somando o delta no destino.
10. **`TOP 1` só com `ORDER BY`** e filtrando antes as linhas que realmente têm o valor procurado (`WHERE ISNULL(Campo,0) > 0`). Sem isso o SQL Server devolve qualquer linha.
11. **Argumento de `EXEC` só aceita constante, `@variável` ou `DEFAULT`**: nunca `GETDATE()`, `DATEADD(...)`, `ISNULL(...)` direto na chamada. Calcular antes numa variável.
12. **Atribuição atômica `UPDATE ... SET @Var = Coluna = Expr`**: `@Var` tem de ter **exatamente** o tipo da coluna (senão erro 425). Converter depois, fora do `UPDATE`.

## 3. Erros, transações e logs

13. **TRY/CATCH em todo bloco lógico**, gravando em `SIS.Log_Erro` (rotina com schema, etapa, `ERROR_MESSAGE()`, `ERROR_LINE()`, data/hora).
    - **Laço/fila isolado (fail-safe)**: dentro do laço, `TRY/CATCH` por registro; se um falhar, desfaz só ele, marca status de erro (`'E'`) e segue para o próximo.
    - **Blocos independentes** (ex.: limpeza + envio + arquivamento): um `TRY/CATCH` por bloco; no fim, se algum falhou, relança um erro agregado.
14. **`;` depois de `END CATCH`** quando ele não for a última instrução do bloco (senão "Incorrect syntax near 'THROW'").
15. **Transação explícita e mínima**: só os comandos que precisam ser atômicos. Nada de montar e-mail ou HTML dentro da transação. `@@ROWCOUNT` capturado logo após cada `UPDATE`.
16. **Tudo-ou-nada em rotina financeira**: geração de parcelas, baixa de título, processamento de retorno bancário, estorno. Se qualquer item do lote falhar, **desfaz o lote inteiro**. Nunca deixar lançamento órfão de um processo que terminou em erro.
17. **Procedure que pode ser chamada isolada ou de dentro de outra transação**: guardar `@TranCountEntrada = @@TRANCOUNT`; se `0`, `BEGIN/COMMIT/ROLLBACK`; se `> 0`, `SAVE TRANSACTION nome` e `ROLLBACK TRANSACTION nome`. Com `XACT_STATE() = -1` nenhuma escrita é permitida (nem `INSERT` de log, nem `DROP` de `#temp`): checar antes de logar.
18. **Quem recebe o erro**:
    - **Automação (job, fila, trigger de integridade)**: loga e `THROW;`.
    - **Trigger que só notifica** (enfileira e-mail): loga e **engole** o erro. Notificação nunca desfaz a gravação de negócio.
    - **Procedure chamada pela API/tela**: devolve **1 linha** com `SUCESSO` (BIT), `MENSAGEM` (VARCHAR, em português, amigável) e os dados extras (ex.: `ID_GERADO`), tanto para recusa de negócio quanto para erro técnico. A mensagem técnica real vai para `SIS.Log_Erro`. Todos os `SELECT` possíveis devolvem as mesmas colunas com os mesmos tipos (`CAST` explícito).
19. **Tabelas temporárias**: `DROP TABLE IF EXISTS` no início, no fim do `TRY` e no `CATCH`. Nunca sair (nem por early return) sem limpar. Em trigger, preferir `SELECT ... INTO #Fonte` a CTE reaproveitada entre vários `UPDATE`s.
20. **Trigger sem recursão por `WHERE`**: cada `UPDATE` feito pela trigger filtra só as linhas que ainda não estão no estado desejado ("already correct"). Se outras triggers gravarem na mesma tabela, `IF TRIGGER_NESTLEVEL(@@PROCID) > 1 RETURN;` no início e sem `DROP` da `#temp` antes desse teste.

## 4. Leitura, concorrência e tipos

21. **`WITH (NOLOCK)` em consultas de leitura/relatório**, alias antes do hint (`Tabela t WITH (NOLOCK)`). **Nunca** em escrita.
22. **`WITH (UPDLOCK, HOLDLOCK)`** (dentro da transação) quando a leitura decide se um `INSERT`/`UPDATE` pode acontecer: número de documento, venda de uma unidade já vendida, nosso número de boleto, duplicidade. Evita duas sessões passarem pela checagem ao mesmo tempo.
23. **Numeração sequencial** (nosso número, número de contrato, número de lote de remessa) via `SEQUENCE` ou tabela de numeração com leitura+incremento atômico. Nunca `MAX()+1`.
24. **Dinheiro em `DECIMAL(18,2)`** (taxas/índices em `DECIMAL(18,6)` ou mais). Nunca `FLOAT`/`REAL`/`MONEY`. Arredondamento explícito (`ROUND(x, 2)`) no ponto em que a regra de negócio manda arredondar; a última parcela absorve a diferença de centavos.
25. **Datas**: `DATE` para data de negócio (vencimento, competência, pagamento); `DATETIME2(0)` para carimbo de quando aconteceu. Data "vazia" é `NULL`, nunca uma data sentinela.
26. **Textos**: `NVARCHAR` para texto livre e nomes; `VARCHAR` para códigos ASCII (CPF/CNPJ só dígitos, CEP, linha digitável). Coluna `NVARCHAR(MAX)` devolvida para a API: avaliar `CAST` para tamanho fixo se o cliente não ler LOB.
27. **Nunca expor coluna NULL crua para a API quando a tela decide algo por "vazio x preenchido"**: `ISNULL(CAST(coluna AS VARCHAR(n)), '')`.
28. **Nomes de mês/dia**: nunca `DATENAME` em texto para o usuário (depende do idioma do servidor). Usar `CASE MONTH(...)`.

## 5. Nomenclatura e organização

29. **Nomenclatura** (aprovada pelo Celso em 14/11/2026; substitui o antigo padrão `tsp_` + PascalCase). O bloco aparece no schema **e** no nome do objeto. Palavras separadas por `_`.
    - **Tabela**: `SCHEMA.Entidade`, no singular, sem prefixo: `IMOB.Indice_Reajuste`, `VENDA.Parcela`, `FIN.Titulo_Baixa`. Nome de tabela único no banco inteiro (não repetir a mesma entidade em dois schemas).
    - **Procedure**: `SCHEMA.BLOCO_Entidade_Acao`, sem prefixo de tipo e **nunca `sp_`** (reservado do sistema): `IMOB.IMOB_Indice_Reajuste_Gravar`. Entidade antes da ação, para as procedures de uma mesma tela ficarem juntas no SSMS. Vocabulário fixo de ações: `Listar` (lista da tela), `Obter` (um registro), `Gravar` (inclui ou altera), `Excluir`, `Gerar`, `Processar`, `Baixar`, `Estornar`, `Enviar`.
    - **Function**: `SCHEMA.fn_BLOCO_Descricao` · **View**: `SCHEMA.vw_BLOCO_Descricao` · **Trigger**: `SCHEMA.tg_BLOCO_Tabela_Finalidade` · **Sequence**: `SCHEMA.seq_BLOCO_Descricao`. Ex.: `IMOB.fn_IMOB_Indice_Na_Data`, `FIN.tg_FIN_Titulo_Historico`, `COBR.seq_COBR_Nosso_Numero`.
    - **Restrições sempre com nome fixo** (nunca o nome automático `PK__Tabela__3214EC27...`, que sai diferente em cada banco): `PK_Tabela`, `FK_Tabela_Referencia`, `IX_Tabela_Campo`, `UQ_Tabela_Campo`, `CK_Tabela_Campo`, `DF_Tabela_Campo`.
    - **Por que o bloco se repete no nome**: `ERROR_PROCEDURE()` devolve o nome **sem** o schema, então o log de erro já mostra o bloco; e `WHERE name LIKE 'IMOB[_]%'` acha tudo de um bloco.
    - Colunas seguem como estão (regras 32 e 34): `ID_<TABELA>`, `DT_CRIACAO`, `USUARIO_ALTERACAO` etc.
    - Na dúvida sobre o bloco de um objeto, **perguntar ao Celso** antes de criar.
30. **Function x procedure**: vira procedure se tiver efeito colateral ou devolver mais de um valor; `fn_` só para leitura que devolve um único valor (ou tabela, em function inline).
31. **Schemas por bloco** (aprovados em 14/11/2026), sempre em maiúsculas e iguais ao prefixo do nome:
    | Schema | Conteúdo |
    |---|---|
    | `CAD` | cadastros gerais: empresa, pessoas (clientes e fornecedores), plano de contas, centros de custo |
    | `BANCO` | bancos, contas bancárias, extrato, conciliação |
    | `IMOB` | empreendimentos, blocos, unidades, índices de reajuste |
    | `VENDA` | propostas, contratos, plano de pagamento, parcelas, aditivos, distratos, assinatura digital |
    | `FIN` | títulos a pagar e a receber, baixas, estornos, caixa, transferências |
    | `COBR` | boletos Sicredi, nosso número, remessa, retorno, envio ao cliente |
    | `OBRA` | orçamento por etapa, lançamentos de custo, orçado x realizado |
    | `COMP` | compras: insumos, solicitação, cotação, pedido, recebimento (gera títulos a pagar no `FIN`); incluído em 16/11/2026 |
    | `GER` | views e procedures do painel gerencial e dos relatórios (só leitura) |
    | `SIS` | usuários, permissões, parâmetros, log de erros, fila de e-mail, agenda das rotinas |
    | `MIG` | staging da migração do Access; **não entra no arquivo MASTER** |
32. **Chave primária**: `INT IDENTITY` (ou `BIGINT` em tabelas de movimento volumosas) chamada `ID_<TABELA>`. Relacionamentos sempre por FK declarada. Sem coluna "RECNUM" nem número reaproveitável.
33. **Parâmetros do sistema** em `SIS.Parametro` (chave/valor, com descrição), lidos a cada execução: nada de valor de negócio fixo no código (dias de carência, multa, juros, conta padrão etc.).
34. **Auditoria**: tabelas de negócio têm `DT_CRIACAO`, `USUARIO_CRIACAO`, `DT_ALTERACAO`, `USUARIO_ALTERACAO`. Alterações sensíveis (valor, vencimento, baixa, estorno, cancelamento de contrato) ficam em tabela de histórico (antes/depois) gravada pela própria procedure ou por trigger. A API passa o usuário logado via `SESSION_CONTEXT` (ou parâmetro) e a trigger usa `SUSER_SNAME()` como reserva.

## 6. Ambientes, testes e entrega

35. **Dois bancos**: `SISTEMACMJ_LOCAL` (desenvolvimento/teste, na instância `.\SQL2025` do notebook do Celso) e `SISTEMACMJ` (produção, no servidor da empresa). Desenvolvo e testo no LOCAL; o usuário promove para produção.
36. **`@bRunLocal BIT = NULL`** em toda procedure que envia e-mail ou mexe com integração externa: `SET @bRunLocal = ISNULL(@bRunLocal, CASE WHEN DB_NAME() LIKE '%[_]LOCAL' THEN 1 ELSE 0 END);`. Em modo teste o e-mail vai só para o endereço de teste e **nada persistente de controle** (checkpoint, "já notificado", número de remessa) é avançado.
37. **Script de produção**: sem `EXEC` de teste no final; instruções de homologação/teste ficam comentadas no cabeçalho. Execução sempre pelo **SSMS (Abrir arquivo + F5)**, nunca por comando de terminal. **Exceção aprovada pelo Celso (22/11/2026)**: o MASTER dentro da **atualização em um clique** (`atualizar.cmd` do pacote, conversa 03h) roda pelo `sqlcmd` (`-f 65001`, regra 55), depois de um backup de segurança e com volta automática se falhar.
38. **Arquivo `.sql` entregue**: CRLF em 100% das linhas. Se for ASCII puro, **sem BOM**; com acento, UTF-8 **com** BOM (o SSMS lê certo). Conferir antes de entregar. Nunca gerar `.sql` com `Out-File`/`>` do PowerShell 5.1.
39. **Scripts idempotentes**: `CREATE TABLE` protegido por `IF OBJECT_ID(...) IS NULL`; `INSERT` de parâmetros/carga inicial só insere o que falta (nunca sobrescreve o que o usuário já alterou).
40. **Antes de assumir nome/tipo de campo, ler o DDL real** em `sql/` (fonte de verdade do schema). Nunca adivinhar.

## 7. Regras complementares (também do padrão de origem)

41. **UPDATE com "flag de força"** (`WHERE (filtro normal) OR (FORCAR = 'S')`): o `JOIN` com a fonte do cálculo é sempre `INNER JOIN`, nunca `LEFT JOIN`. Com `LEFT JOIN`, a linha sem dado na fonte entra pelo `OR` e o cálculo vira `NULL`, apagando um valor que devia ficar intocado. Regra de negócio "sem dado = sem alteração".
42. **Colunas `NOT NULL`**: todo `INSERT`/`UPDATE` envolve **cada** valor em `ISNULL(@Var, padrão)` (`0`, `''`, data mínima ou `GETDATE()` conforme o caso), mesmo quando a variável "parece" sempre preenchida: protege contra o branch esquecido (`IF` sem `ELSE`) que só aparece com um dado diferente do testado (erro 515).
43. **Datas inválidas vindas do legado (Access)**: nunca comparar data convertida para texto. Comparar contra um **piso técnico** (`< '1900-01-01'` ou fora de faixa razoável) e tratar como `NULL` na migração. Em fallback de vários níveis (campo A → campo B → ...), o último nível é sempre um valor seguro e incondicional, nunca outro campo sem validação.
44. **Unificar histórico ativo + arquivado**: se alguma tabela tiver arquivo morto/histórico separado, toda consulta de saldo, consumo ou posição faz `UNION ALL` das duas, para não "perder" o que foi arquivado recentemente.
45. **Checkpoint incremental** para tabelas grandes que precisam ser cruzadas a toda execução (ex.: conferência de retorno bancário, resumos do dashboard): tabela-resumo + tabela de checkpoint de 1 linha (maior ID já processado) + procedure que lê só `ID > @checkpoint`, faz `MERGE` (só atualizando se o registro novo for mais recente) e avança o checkpoint. Checkpoint sempre por identificador automático, nunca por data de negócio. Em modo teste (`@bRunLocal = 1`) calcula, mas **não grava** resumo nem checkpoint.
46. **Liga/desliga por parâmetro** (feature flag): rotina nova que substitui um mecanismo antigo (ou que só deve começar a agir num dia combinado) lê um parâmetro `S`/`N` em `SIS.Parametro` como primeira instrução e sai cedo se `N`. Ativar em produção vira um `UPDATE`, sem novo deploy.
47. **Rastreamento passo a passo (trace)** em automação crítica difícil de reproduzir (retorno bancário, geração de remessa, geração de parcelas): tabela `SIS.Log_Passo` (`RUN_ID` GUID, etapa, status, detalhe, data/hora), gravando inclusive nas saídas antecipadas. Dentro de transação arriscada, acumular numa **variável de tabela** (imune a `ROLLBACK`) e gravar na tabela real só na saída. Na tabela de alto tráfego, filtrar antes com `UPDATE(Coluna)` para não custar em todo `UPDATE`.
48. **Trigger que reage a um campo de pedido** (ex.: `ENVIAR_EMAIL = 'S'`, `GERAR_BOLETO = 'S'`): filtrar só pelo valor final em `inserted` (`WHERE i.Campo = 'S'`), **sem comparar com `deleted`**. O pedido pode ser "reafirmado" com o mesmo valor (uma tentativa anterior que não foi processada) e a comparação com `deleted` descartaria em silêncio. Seguro porque a rotina sempre grava outro valor ao terminar (`''` processado, `'X'` falhou).
49. **Chave composta vinda de duas fontes**: tratar cada campo de forma independente (`CampoA IN (fonte1.A, fonte2.A) AND CampoB IN (fonte1.B, fonte2.B)`), nunca escolher a fonte inteira com `COALESCE`. Só com o `JOIN` já ancorado por uma chave exata.
50. **Outro banco**: se algum dia o sistema precisar ler outro banco, sempre via `SYNONYM` local (`CREATE SYNONYM SIS.syn_X FOR OutroBanco.schema.X`), nunca nome de 3 partes no corpo das procedures. Entre ambientes só mudam os `CREATE SYNONYM`.
51. **Caminho de arquivo com acento** (anexos, PDFs, arquivos do banco): usar o nome exatamente como foi lido do disco, nunca redigitado (Unicode composto x decomposto quebra a localização do arquivo sem aparecer na tela). Preferir nomes gerados pelo sistema sem acento e sem espaço.
52. **Testar pelo caminho real**: uma procedure chamada pela API só está pronta depois de testada **pela tela/endpoint de verdade**, não só pelo SSMS. Conferir que todo caminho devolve o mesmo formato de resultado (`sp_describe_first_result_set` deve listar as colunas).
53. **Integração HTTP externa** (API do Sicredi, se adotada): o SQL nunca chama HTTP. O serviço da aplicação processa uma fila com `ID_REQUISICAO` único (idempotência), status `PENDENTE/PROCESSANDO/ENVIADO/ERRO`, captura atômica (`UPDLOCK, READPAST`), retentativa só para falha temporária (timeout, 429, 5xx) com espera progressiva, e reconciliação antes de reenviar quando a resposta for incerta. Nunca logar chave de API, token ou cabeçalho de autenticação.
54. **Credenciais** (SQL, SMTP, banco): nunca em texto puro no código, em tabela comum, em linha de comando ou em log. Usar a configuração protegida do serviço (segredos do .NET / variável de ambiente / DPAPI no Windows). Senha passada ao `sqlcmd` só via variável `SQLCMDPASSWORD`, nunca `-P`.
55. **`sqlcmd -i` de script com caractere especial** (acento, símbolo): sempre com `-f 65001`, senão o texto é gravado corrompido no objeto sem dar erro. Para leitura XML, `-I` (QUOTED_IDENTIFIER).
56. **Desativar em vez de apagar**: dado de negócio não é apagado fisicamente; usa situação (`CANCELADO`, `EXCLUIDO`) + histórico. Quando for inevitável remover/corrigir em massa: script com chave `@Executar BIT = 0` (0 = só mostra a prévia), tabela de backup antes da alteração e script `_DESFAZER` correspondente, tudo na mesma transação.
57. **Ordem de publicação**: 1) script SQL, 2) serviço/API, 3) telas HTML/JS. Nunca publicar tela ou API que lê coluna nova antes de o SQL rodar no banco.

---

## 8. Instalação no cliente: arquivo MASTER (decidido em 14/11/2026)

58. **Um único arquivo de instalação**: tudo o que vai para o servidor do cliente (schemas, tabelas, sequences, functions, views, procedures, triggers, parâmetros e carga inicial) fica em `sql/MASTER/SISTEMACMJ_MASTER_Instalacao.sql`, para o Celso rodar de uma vez no SSMS da empresa (Abrir arquivo + F5).
59. **Ordem dentro do MASTER**: 1) conferência do banco (`IF DB_NAME() <> 'SISTEMACMJ'` aborta com `SET NOEXEC ON`), 2) schemas, 3) tabelas e restrições, 4) sequences, 5) functions, 6) views, 7) procedures, 8) triggers, 9) parâmetros e carga inicial. Cada parte com cabeçalho de comentário. O MASTER é **idempotente** (regras 3 e 39): roda de novo sem erro e sem perder dado; alteração de tabela já existente entra protegida (`IF COL_LENGTH(...) IS NULL ALTER TABLE ... ADD ...`).
60. **Fluxo**: cada objeto é criado e testado à vontade no `SISTEMACMJ_LOCAL`, a partir do seu arquivo de trabalho em `sql/objetos/<BLOCO>/`. **Só entra no MASTER depois de aprovado pelo Celso.** O MASTER nunca contém `EXEC` de teste nem objeto do schema `MIG`.
61. **Versão do banco** (20/11/2026): o número fica em UM lugar, `sql/objetos/SIS/Carga_SIS_Versao.sql` (última instrução do MASTER, grava em `SIS.Versao_Banco`), e a API exige o mesmo número (`api/.../Infra/VersaoBanco.cs`, `VersaoExigida`). **Toda mudança que vai para o MASTER sobe os dois juntos.** Banco em versão diferente: a API só responde `/api/saude` e mostra o aviso nas telas. Desde a 1.8 (22/11/2026) a versão do programa (`<Version>` do `SistemaCMJ.Api.csproj`) acompanha a do banco (banco 1.8 = programa 1.8.0), e cada versão tem a sua nota em `docs/NOTAS_DA_VERSAO.md` (o publicar recusa sem ela).
62. **Montagem** (20/11/2026): o MASTER é gerado por `sql/ferramentas/montar_master.py` e a migração do servidor (só o schema MIG) por `sql/ferramentas/montar_migracao.py` (`sql/MASTER/SISTEMACMJ_MIGRACAO_Instalacao.sql`); nunca editar os gerados à mão. Antes de entregar, ensaiar no banco `SISTEMACMJ` do notebook (do zero e por cima) e comparar com o LOCAL. Objeto que depende de tabela criada em tempo de execução (ex.: `MIG.Movimento`) precisa de tratamento no montador, porque no LOCAL o erro não aparece.

## Específico do SQL Server Express

- **Não existe SQL Server Agent** no Express: nada de Job. Toda rotina agendada (e-mails diários, processar fila, importar retorno, vencimentos) é disparada pelo **serviço da aplicação** (agendador interno) ou pelo Agendador de Tarefas do Windows chamando a procedure.
- **Database Mail não é suportado no Express**: o SQL **monta** o e-mail (assunto + HTML + destinatários) e grava numa **fila** (`SIS.Email_Fila`); quem **envia** por SMTP é o serviço da aplicação. Isso é o mesmo padrão "fila + processador" já consagrado, só que o processador fica fora do banco. Ver [PADRAO_EMAIL.md](PADRAO_EMAIL.md).
- **Limite de 50 GB por banco no SQL Server 2025 Express** (10 GB na 2022 e anteriores; dados, o log não conta): arquivos (PDF de boleto, comprovantes, contratos, arquivos CNAB) ficam **em disco**, numa pasta do servidor, e o banco guarda só caminho, nome, tamanho e hash.
- Memória/CPU limitadas: índices bem escolhidos nas colunas de filtro dos relatórios (vencimento, situação, obra, cliente, competência) e consultas de dashboard pré-agregadas quando necessário.
- **Backup**: sem Agent, o backup também é agendado fora (Agendador do Windows + `sqlcmd` com `BACKUP DATABASE`), com cópia para outro disco/máquina e teste de restauração.
