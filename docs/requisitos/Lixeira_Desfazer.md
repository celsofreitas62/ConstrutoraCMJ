# Histórico padrão: desfazer e lixeira (P20, fase 4, conversa 04b)

Criado em 22/11/2026. Desenho proposto pelo Claude e **aprovado pelo Celso em 22/11/2026** ("tudo aprovado", com o prazo padrão da lixeira em **90 dias**; a Renata muda se precisar). Pedido original: P20 em `Pedidos_Futuros.md`.

## 1. Três situações de um registro

| Situação | Botão na tela | O que acontece | Volta? |
|---|---|---|---|
| Ativo | | normal | |
| **Inativo** | **Desativar** (o antigo "Excluir"; ação `DESATIVAR`) | some das listas de escolha, continua nos lançamentos e no histórico; sem prazo | Reativar |
| **Na lixeira** | **Excluir** (ação `EXCLUIR`) | só quando **nada usa o registro** (senão a tela recusa e sugere Desativar); some de todas as telas; o registro fica desativado e marcado (`DT_EXCLUSAO`) | **Recuperar** na Lixeira, na hora |

- **Prazo da lixeira em parâmetro**: `LIXEIRA_DIAS_GUARDA` (padrão **90**). Cada tela pode ter prazo próprio (`SIS.Tabela_Config.DIAS_GUARDA`; vazio = vale o geral).
- **Esvaziar**: a rotina diária `LIXEIRA_LIMPEZA` apaga de vez o que passou do prazo, conferindo de novo se nada passou a usar o registro (se usar, não apaga e avisa). Os filhos que "vão junto" (ex.: contatos, vínculos e dados bancários da pessoa) são apagados com ele. A cópia completa fica para sempre em `SIS.Auditoria`.
- **Aviso antes de apagar**: e-mail diário (grupo de e-mail do parâmetro `LIXEIRA_AVISO_GRUPO`, padrão `LIXEIRA_AVISO`, editável na tela Grupos de e-mail) com o que será apagado em `LIXEIRA_AVISO_DIAS` dia(s) (padrão 1); não sai e-mail se não houver nada. Na tela da Lixeira, esses registros aparecem marcados "apaga amanhã". Botão **Manter mais N dias** (adia o prazo sem recuperar).
- **Enquanto estiver na lixeira, o registro continua ocupando o código/CNPJ** (as chaves únicas do banco não mudam): para cadastrar outro com o mesmo código, recuperar ou esvaziar antes. Na recuperação, os campos únicos configurados (ex.: CPF/CNPJ da pessoa) são conferidos contra os registros vivos; havendo outro igual, a recuperação é recusada e mostra qual é.
- Liga/desliga: `LIXEIRA_ATIVA` (S/N) e `LIXEIRA_LIMPEZA_ATIVA` (S/N).

## 2. Tela Sistema › Lixeira (uma tela só)

Filtros por **Módulo** e **Tela**, período e quem excluiu; agrupada por módulo com o total de cada um. Cada usuário só vê os módulos e as telas em que tem permissão de ver. Atalho "Lixeira desta tela" nas listas abre já filtrada. Botões **Recuperar** (`RECUPERAR`), **Manter mais N dias** (`ALTERAR`) e **Esvaziar agora** (`ESVAZIAR`), cada um com a sua permissão (tela `SIS_LIXEIRA`).

## 3. Aba Histórico padrão (todas as fichas) e Histórico geral

- Linha do tempo agrupada por operação (quem, quando, tela, o que mudou antes/depois), filtros por período, usuário e campo.
- **Voltar para como estava aqui** (registro + filhos que vão junto): prévia em 3 colunas (agora / naquela data / como vai ficar); grava uma **alteração nova**, com motivo obrigatório, registrada no histórico e em `SIS.Desfazer`.
- **Desfazer esta operação** (uma transação) e, no Histórico geral (tela Auditoria), **Desfazer o lote inteiro**: tudo-ou-nada, na ordem inversa; recusado se alguém mexeu depois num daqueles campos (a prévia mostra quais).
- Inclusão desfeita: o registro vai para a lixeira (ou é desativado, nas tabelas filhas), conforme `SIS.Tabela_Config.DESFAZER_INCLUSAO`.
- Nunca desfaz: campos sigilosos (senha), campos bloqueados da configuração (saldos, calculados), a marca da lixeira (usa-se a Lixeira) e exclusão definitiva (já esvaziada).

## 4. Travas (parametrizadas em `SIS.Tabela_Config`, nada fixo no código)

Por tabela: permite desfazer, permite lixeira, prazo próprio, campos bloqueados, campos únicos para conferir na recuperação, tabelas filhas que vão junto (`TABELA.COLUNA_FK`), como desfazer uma inclusão, texto que descreve o registro, coluna da empresa e da data para a trava de **mês fechado** (`FIN.Mes_Fechado`) e uma procedure de validação própria (gancho para o P16, boleto no banco).

Permissões: `DESFAZER` em cada tela (e em `SIS_AUDITORIA` para o lote), `RECUPERAR`, `ALTERAR` e `ESVAZIAR` na Lixeira. O Administrador tem tudo; os perfis de fábrica Financeiro e Consulta não recebem `DESFAZER` (liberável por perfil). Na criação da ação `DESATIVAR`, quem já tinha `EXCLUIR` (que desativava) recebe `DESATIVAR`.

## 5. Alcance e partes

- Tabelas: Pessoas (com contatos, vínculos e dados bancários), Empresas, Centros de custo, Plano de contas (grupo, subgrupo, conta), Contas bancárias; desfazer também em Usuários e Perfis (permissões sim, senha nunca). O financeiro entra quando as telas dele forem feitas (04f/04g); a trava de mês fechado já fica pronta.
- **04b-A (banco)**: tabelas `SIS.Tabela_Config`, `SIS.Lixeira`, `SIS.Desfazer`, colunas da lixeira, procedures, rotina diária, permissões, teste SQL; banco e programa **2.0**.
- **04b-B (telas)**: aba Histórico padrão (`js/historico.js`) em Pessoa, Usuário e Perfil; telas Lixeira e Histórico geral; botões Desativar/Excluir; testes das telas; publicação.

## 6. Feito na 04b-A (22/11/2026)

Banco e programa **2.0**, pacote `sql/pacotes/04b_SIS_LOCAL.sql`, MASTER v2.0, teste `sql/testes/SIS/04b_Homologacao_Lixeira_Desfazer.sql` (66/0 no LOCAL, 65/0 no ensaio). Procedures para as telas (04b2):

| Tela | Procedure | Devolve |
|---|---|---|
| Botão Excluir (qualquer ficha) | `SIS.SIS_Lixeira_Excluir @IdUsuario, @Item, @Tabela, @IdRegistro, @Motivo` | SUCESSO, MENSAGEM, ID_LIXEIRA, DT_APAGAR |
| Botão Desativar | as `*_Excluir` de cada cadastro (permissão `DESATIVAR`) | como antes |
| Lixeira: lista | `SIS.SIS_Lixeira_Listar @IdUsuario, @Modulo, @Item, @DtInicio, @DtFim, @Usuario, @Texto, @Situacao` | linhas (APAGA_LOGO = "apaga amanhã") |
| Lixeira: recuperar / manter / esvaziar | `SIS_Lixeira_Recuperar`, `SIS_Lixeira_Manter @Dias`, `SIS_Lixeira_Esvaziar @Ids` | 1 linha |
| Lixeira: prazos por tela | `SIS_Lixeira_Prazo_Listar`, `SIS_Lixeira_Prazo_Gravar @Tabela, @Dias` | |
| Aba Histórico / Auditoria | `SIS_Historico_Desfazer_Previa` e `SIS_Historico_Desfazer` (`@Modo` REGISTRO com `@IdAuditoria` ou `@DataHora`, OPERACAO com `@IdAuditoria`, LOTE com `@IdLote` e `@Item = 'SIS_AUDITORIA'`; `@Motivo` obrigatório no desfazer) | prévia: linhas com ACAO, SITUACAO, PODE_DESFAZER, RESUMO |

Observação de teste: dentro de uma transação só (testes SQL), "operação" e "ponto do histórico por operação" juntam tudo; o teste usa o ponto por data/hora e lotes. O modo por operação será conferido pela tela (04b2).

## 7. Feito na 04b2 (23/11/2026)

Banco e programa **2.1** (pacote `sql/pacotes/04b2_SIS_LOCAL.sql`, MASTER v2.1, teste `sql/testes/SIS/04b2_Homologacao_Historico.sql` 10/0 no LOCAL e no ensaio).

| Peça | O que é |
|---|---|
| `SIS.SIS_Historico_Listar` | aba Histórico de todas as fichas: o registro e as filhas que vão junto (inclusive já apagadas), com `TRANSACAO`, `PRINCIPAL` e `DESCRICAO` (tela › ação nas permissões) |
| `SIS_Auditoria_Registro_Listar` / `SIS_Auditoria_Listar` v1.1 | devolvem `TRANSACAO` (e `TELA_NOME` na geral) |
| `Endpoints/HistoricoEndpoints.cs` | `/api/sis/historico` (+ `/previa`, `/desfazer`), `/api/sis/lixeira` (+ `/excluir`, `/{id}/recuperar`, `/{id}/manter`, `/esvaziar`, `/prazos`), `/api/sis/auditoria`; `SENHA_*` nunca sai |
| `js/historico.js` | componente único: aba Histórico (filtros, agrupada por operação, Voltar para como estava aqui, Desfazer esta operação) e a prévia do desfazer (também usada pela Auditoria) |
| `sis/lixeira.html` | Lixeira (Registros + Prazos por tela; `?item=` abre filtrada) |
| `sis/auditoria.html` | histórico geral com desfazer operação e lote (`?lote=`, `?tabela=`, `?id=`) |
| Ficha de Pessoa | Desativar/Reativar (DESATIVAR), Excluir (lixeira); na lixeira abre só para consulta |

Testes das telas 15/0, com o passo novo "desfazer a gravação pela aba Histórico" (confere o modo OPERACAO pelo caminho real, pendência da 04b-A).
