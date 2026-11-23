/*******************************************************************************
  Objeto      : carga de [SIS].[Versao_Nota] (notas de cada versão)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : GERADO por sql/ferramentas/montar_notas.py a partir de
                docs/NOTAS_DA_VERSAO.md (fonte única). NÃO EDITAR À MÃO:
                corrigir o .md e gerar de novo.
                Sincroniza a tabela com o .md (as notas são do sistema, não da
                CMJ): inclui o que falta, acerta o texto do que mudou e tira o
                item que saiu do .md. Idempotente.
                Versões no arquivo: 2.1, 2.0, 1.9, 1.8.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaNota;
SELECT v.VERSAO, SIS.fn_SIS_Versao_Numero(v.VERSAO) AS VERSAO_NUMERO, v.DT_VERSAO, v.ORDEM, v.TIPO, v.PUBLICO, v.TEXTO, v.TEXTO_HTML
INTO #CargaNota
FROM (VALUES
       (CAST('2.1' AS VARCHAR(20)), CAST('2026-11-23' AS DATE), CAST(1 AS SMALLINT), CAST('NOVO' AS VARCHAR(10)), CAST('TODOS' AS VARCHAR(10)),
         CAST(N'tela Lixeira (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com Recuperar, Manter mais dias e Esvaziar agora, e a aba Prazos por tela (quanto tempo cada tela guarda na lixeira).' AS NVARCHAR(2000)), CAST(N'tela <b>Lixeira</b> (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com <b>Recuperar</b>, <b>Manter mais dias</b> e <b>Esvaziar agora</b>, e a aba <b>Prazos por tela</b> (quanto tempo cada tela guarda na lixeira).' AS NVARCHAR(4000)))
      ,('2.1', '2026-11-23', 2, 'NOVO', 'TODOS',
         N'tela Auditoria (Sistema › Monitoramento), o histórico geral do sistema, com filtros por período, usuário, tabela, registro, operação e lote, e os botões Desfazer esta operação e Desfazer o lote.',
         N'tela <b>Auditoria</b> (Sistema › Monitoramento), o histórico geral do sistema, com filtros por período, usuário, tabela, registro, operação e lote, e os botões <b>Desfazer esta operação</b> e <b>Desfazer o lote</b>.')
      ,('2.1', '2026-11-23', 3, 'MELHORIA', 'TODOS',
         N'a aba Histórico das fichas de Pessoa, Usuário e Perfil agora agrupa o que foi gravado junto, tem filtros e os botões Voltar para como estava aqui e Desfazer esta operação, sempre com prévia e motivo. O histórico da pessoa inclui contatos, dados bancários e vínculos (inclusive os já apagados); o do perfil e do usuário, as permissões.',
         N'a aba <b>Histórico</b> das fichas de Pessoa, Usuário e Perfil agora agrupa o que foi gravado junto, tem filtros e os botões <b>Voltar para como estava aqui</b> e <b>Desfazer esta operação</b>, sempre com prévia e motivo. O histórico da pessoa inclui contatos, dados bancários e vínculos (inclusive os já apagados); o do perfil e do usuário, as permissões.')
      ,('2.1', '2026-11-23', 4, 'MELHORIA', 'TODOS',
         N'a ficha de Pessoa tem os botões Desativar (sai das listas, sem prazo) e Excluir (vai para a lixeira); a lista de Pessoas tem o atalho Lixeira de Pessoas.',
         N'a ficha de Pessoa tem os botões <b>Desativar</b> (sai das listas, sem prazo) e <b>Excluir</b> (vai para a lixeira); a lista de Pessoas tem o atalho <b>Lixeira de Pessoas</b>.')
      ,('2.0', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'lixeira. O botão Excluir das telas manda o registro para a lixeira, de onde ele pode ser recuperado; depois do prazo (90 dias, ajustável por tela) ele é apagado de vez. Só vai para a lixeira o que não é usado em nenhum lugar; o resto pode ser desativado, como antes.',
         N'<b>lixeira</b>. O botão Excluir das telas manda o registro para a lixeira, de onde ele pode ser recuperado; depois do prazo (90 dias, ajustável por tela) ele é apagado de vez. Só vai para a lixeira o que não é usado em nenhum lugar; o resto pode ser desativado, como antes.')
      ,('2.0', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'aviso por e-mail, um dia antes, do que vai ser apagado de vez da lixeira, com a opção de manter por mais alguns dias.',
         N'aviso por e-mail, um dia antes, do que vai ser apagado de vez da lixeira, com a opção de manter por mais alguns dias.')
      ,('2.0', '2026-11-22', 3, 'NOVO', 'TODOS',
         N'desfazer pelo histórico. Dá para voltar um cadastro para como estava num ponto do histórico, desfazer uma alteração ou desfazer tudo o que um lote fez, sempre com prévia, motivo e registro de quem fez. Nada é desfeito se alguém mexeu depois no mesmo campo.',
         N'<b>desfazer pelo histórico</b>. Dá para voltar um cadastro para como estava num ponto do histórico, desfazer uma alteração ou desfazer tudo o que um lote fez, sempre com prévia, motivo e registro de quem fez. Nada é desfeito se alguém mexeu depois no mesmo campo.')
      ,('2.0', '2026-11-22', 4, 'MELHORIA', 'TODOS',
         N'o antigo botão Excluir passa a se chamar Desativar (o registro continua no histórico e nas movimentações).',
         N'o antigo botão Excluir passa a se chamar Desativar (o registro continua no histórico e nas movimentações).')
      ,('1.9', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'tela de Usuários (Sistema › Segurança). Cada pessoa tem o seu usuário; o administrador inclui, muda o perfil, desativa, reinicia a senha de quem esqueceu e desbloqueia quem errou a senha várias vezes. O histórico mostra quem mudou o quê.',
         N'tela de <b>Usuários</b> (Sistema › Segurança). Cada pessoa tem o seu usuário; o administrador inclui, muda o perfil, desativa, reinicia a senha de quem esqueceu e desbloqueia quem errou a senha várias vezes. O histórico mostra quem mudou o quê.')
      ,('1.9', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'tela de Perfis e permissões. O administrador marca, tela por tela, o que cada perfil pode fazer (ver, incluir, alterar, excluir, exportar e as ações especiais). Também dá para fazer exceções só para uma pessoa.',
         N'tela de <b>Perfis e permissões</b>. O administrador marca, tela por tela, o que cada perfil pode fazer (ver, incluir, alterar, excluir, exportar e as ações especiais). Também dá para fazer exceções só para uma pessoa.')
      ,('1.9', '2026-11-22', 3, 'NOVO', 'TODOS',
         N'perfis prontos Financeiro e Consulta, para começar (podem ser ajustados).',
         N'perfis prontos <b>Financeiro</b> e <b>Consulta</b>, para começar (podem ser ajustados).')
      ,('1.9', '2026-11-22', 4, 'MELHORIA', 'TODOS',
         N'a senha provisória (dada a um usuário novo ou ao reiniciar a senha) vale por 24 horas; depois disso é preciso reiniciar de novo.',
         N'a senha provisória (dada a um usuário novo ou ao reiniciar a senha) vale por 24 horas; depois disso é preciso reiniciar de novo.')
      ,('1.8', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'atualização em um clique. O administrador roda um único arquivo (atualizar.cmd), que faz um backup de segurança, atualiza o banco e o programa, confere se ficou tudo funcionando e, se algo der errado, volta sozinho para a versão anterior.',
         N'atualização em um clique. O administrador roda um único arquivo (<code>atualizar.cmd</code>), que faz um backup de segurança, atualiza o banco e o programa, confere se ficou tudo funcionando e, se algo der errado, volta sozinho para a versão anterior.')
      ,('1.8', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'o sistema guarda o histórico das atualizações (quando, de qual versão para qual, quanto tempo ficou fora do ar e estas notas).',
         N'o sistema guarda o histórico das atualizações (quando, de qual versão para qual, quanto tempo ficou fora do ar e estas notas).')
      ,('1.8', '2026-11-22', 3, 'MELHORIA', 'TODOS',
         N'o menu mostra só as telas que já estão prontas.',
         N'o menu mostra só as telas que já estão prontas.')
      ,('1.8', '2026-11-22', 4, 'NOVO', 'GERAL',
         N'ajuda técnica com instalação, licença, parâmetros, backup, comandos e recuperação.',
         N'ajuda técnica com instalação, licença, parâmetros, backup, comandos e recuperação.')
     ) v (VERSAO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML);

MERGE SIS.Versao_Nota AS d
USING #CargaNota AS o
   ON d.VERSAO = o.VERSAO AND d.ORDEM = o.ORDEM
WHEN MATCHED AND (d.TIPO <> o.TIPO OR d.PUBLICO <> o.PUBLICO OR d.TEXTO <> o.TEXTO OR d.TEXTO_HTML <> o.TEXTO_HTML
                  OR d.VERSAO_NUMERO <> o.VERSAO_NUMERO OR ISNULL(d.DT_VERSAO, '19000101') <> ISNULL(o.DT_VERSAO, '19000101')) THEN
    UPDATE SET d.VERSAO_NUMERO = o.VERSAO_NUMERO, d.DT_VERSAO = o.DT_VERSAO, d.TIPO = o.TIPO, d.PUBLICO = o.PUBLICO,
               d.TEXTO = o.TEXTO, d.TEXTO_HTML = o.TEXTO_HTML
WHEN NOT MATCHED BY TARGET THEN
    INSERT (VERSAO, VERSAO_NUMERO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML)
    VALUES (o.VERSAO, o.VERSAO_NUMERO, o.DT_VERSAO, o.ORDEM, o.TIPO, o.PUBLICO, o.TEXTO, o.TEXTO_HTML)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;

DROP TABLE IF EXISTS #CargaNota;
PRINT N'Notas das versões carregadas.';
GO
