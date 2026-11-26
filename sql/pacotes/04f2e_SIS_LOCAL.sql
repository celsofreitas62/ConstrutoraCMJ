/*******************************************************************************
  Pacote      : 04f2e - nota da versao 2.5 e registro da versao do banco; banco 2.5
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 26/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f2d já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/04c_Homologacao_Versoes.sql e 03h_Homologacao_Atualizacao.sql.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao_Nota.sql
-- =============================================================================
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
                Versões no arquivo: 2.5, 2.4, 2.3, 2.2, 2.1, 2.0, 1.9, 1.8.
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
       (CAST('2.5' AS VARCHAR(20)), CAST('2026-11-26' AS DATE), CAST(1 AS SMALLINT), CAST('NOVO' AS VARCHAR(10)), CAST('TODOS' AS VARCHAR(10)),
         CAST(N'telas Contas a pagar e Contas a receber (Financeiro), com os contadores no topo (vencidas, vencem hoje, a vencer e total em aberto; clique para filtrar), busca, filtros por situação, período (vencimento, emissão ou competência), empresa, parceiro, centro de custo, conta do plano e documento, visão por parcela ou por lançamento e o total do filtro.' AS NVARCHAR(2000)), CAST(N'telas <b>Contas a pagar</b> e <b>Contas a receber</b> (Financeiro), com os contadores no topo (vencidas, vencem hoje, a vencer e total em aberto; clique para filtrar), busca, filtros por situação, período (vencimento, emissão ou competência), empresa, parceiro, centro de custo, conta do plano e documento, visão por parcela ou por lançamento e o total do filtro.' AS NVARCHAR(4000)))
      ,('2.5', '2026-11-26', 2, 'NOVO', 'TODOS',
         N'Meus filtros: cada usuário salva os filtros que usa sempre (ex.: "Vencidos da CMJ") e pode marcar um para a tela já abrir com ele. Sem filtro marcado, a tela abre com os últimos filtros usados.',
         N'<b>Meus filtros</b>: cada usuário salva os filtros que usa sempre (ex.: "Vencidos da CMJ") e pode marcar um para a tela já abrir com ele. Sem filtro marcado, a tela abre com os últimos filtros usados.')
      ,('2.5', '2026-11-26', 3, 'NOVO', 'TODOS',
         N'Exportar Excel das contas a pagar e a receber com todas as linhas do filtro.',
         N'<b>Exportar Excel</b> das contas a pagar e a receber com todas as linhas do filtro.')
      ,('2.5', '2026-11-26', 4, 'NOVO', 'TODOS',
         N'ficha do lançamento: incluir e alterar contas a pagar e a receber com as parcelas (botão "Gerar parcelas" pelo nº de parcelas, 1º vencimento e intervalo), cancelar com motivo, excluir para a lixeira, copiar um lançamento, e as abas Parcelas, Baixas, Anexos e Histórico. Clique na linha da lista para abrir; "+ Incluir" abre um novo.',
         N'<b>ficha do lançamento</b>: incluir e alterar contas a pagar e a receber com as parcelas (botão "Gerar parcelas" pelo nº de parcelas, 1º vencimento e intervalo), cancelar com motivo, excluir para a lixeira, copiar um lançamento, e as abas Parcelas, Baixas, Anexos e Histórico. Clique na linha da lista para abrir; "+ Incluir" abre um novo.')
      ,('2.5', '2026-11-26', 5, 'NOVO', 'TODOS',
         N'pendências dos lançamentos: o sistema aponta sozinho o que falta resolver nas contas em aberto (sem centro de custo, sem conta do plano, sem número de documento, conta a pagar acima de um valor sem anexo, cliente sem cadastro completo para cobrança, parcela vencida há muitos dias), e você também pode marcar pendências ("aguardando nota fiscal", "conferir com o contador"...) com responsável e previsão. Algumas pendências podem impedir o pagamento até serem resolvidas. As regras e os tipos de pendência são configuráveis.',
         N'<b>pendências dos lançamentos</b>: o sistema aponta sozinho o que falta resolver nas contas em aberto (sem centro de custo, sem conta do plano, sem número de documento, conta a pagar acima de um valor sem anexo, cliente sem cadastro completo para cobrança, parcela vencida há muitos dias), e você também pode marcar pendências ("aguardando nota fiscal", "conferir com o contador"...) com responsável e previsão. Algumas pendências podem impedir o pagamento até serem resolvidas. As regras e os tipos de pendência são configuráveis.')
      ,('2.5', '2026-11-26', 6, 'NOVO', 'TODOS',
         N'na lista de contas, os contadores Com pendência e Minhas pendências, o filtro por pendência e uma etiqueta na linha que mostra as pendências ao passar o mouse (vermelha quando a previsão já passou). Na ficha, o quadro Pendências diz como resolver cada uma e leva direto ao campo certo.',
         N'na lista de contas, os contadores <b>Com pendência</b> e <b>Minhas pendências</b>, o filtro por pendência e uma etiqueta na linha que mostra as pendências ao passar o mouse (vermelha quando a previsão já passou). Na ficha, o quadro <b>Pendências</b> diz como resolver cada uma e leva direto ao campo certo.')
      ,('2.5', '2026-11-26', 7, 'NOVO', 'TODOS',
         N'tela Tipos de pendência (Financeiro), para criar os tipos que a empresa usa e dizer quais bloqueiam o pagamento.',
         N'tela <b>Tipos de pendência</b> (Financeiro), para criar os tipos que a empresa usa e dizer quais bloqueiam o pagamento.')
      ,('2.5', '2026-11-26', 8, 'MELHORIA', 'TODOS',
         N'a conferência de CPF/CNPJ ficou mais rápida nas listas.',
         N'a conferência de CPF/CNPJ ficou mais rápida nas listas.')
      ,('2.5', '2026-11-26', 9, 'NOVO', 'TODOS',
         N'aba Movimentação na ficha do Parceiro: o que ele tem a pagar e a receber em aberto, o vencido, o total pago ou recebido nos últimos 12 meses com a média por mês e a data do último pagamento; a lista das parcelas abre o lançamento, e os botões "+ Contas a pagar" e "+ Contas a receber" já trazem o parceiro escolhido.',
         N'aba <b>Movimentação</b> na ficha do Parceiro: o que ele tem a pagar e a receber em aberto, o vencido, o total pago ou recebido nos últimos 12 meses com a média por mês e a data do último pagamento; a lista das parcelas abre o lançamento, e os botões "+ Contas a pagar" e "+ Contas a receber" já trazem o parceiro escolhido.')
      ,('2.5', '2026-11-26', 10, 'NOVO', 'TODOS',
         N'tela Parâmetros de uso (Sistema › Configuração), para os administradores ajustarem os avisos ao lançar, as pendências automáticas, a trava de datas e a lista de contas. Antes de gravar, a tela mostra o efeito (ex.: quantos lançamentos passam a ter uma pendência) e, quando a mudança afrouxa uma proteção, pede o motivo, que fica no histórico do parâmetro.',
         N'tela <b>Parâmetros de uso</b> (Sistema › Configuração), para os administradores ajustarem os avisos ao lançar, as pendências automáticas, a trava de datas e a lista de contas. Antes de gravar, a tela mostra o efeito (ex.: quantos lançamentos passam a ter uma pendência) e, quando a mudança afrouxa uma proteção, pede o motivo, que fica no histórico do parâmetro.')
      ,('2.5', '2026-11-26', 11, 'NOVO', 'TODOS',
         N'avisos contra erro de digitação ao gravar um lançamento: o sistema mostra o que parece erro (valor fora da média, documento repetido, datas distantes...) e só grava depois de você marcar "Estou ciente"; o que é bloqueio não deixa gravar.',
         N'<b>avisos contra erro de digitação</b> ao gravar um lançamento: o sistema mostra o que parece erro (valor fora da média, documento repetido, datas distantes...) e só grava depois de você marcar "Estou ciente"; o que é bloqueio não deixa gravar.')
      ,('2.4', '2026-11-25', 1, 'NOVO', 'TODOS',
         N'telas de Empresas (Cadastros), com busca na Receita pelo CNPJ e no CEP, logomarca, anexos (contrato social, certidões com validade) e as abas das contas bancárias e dos centros de custo da empresa.',
         N'telas de <b>Empresas</b> (Cadastros), com busca na Receita pelo CNPJ e no CEP, logomarca, anexos (contrato social, certidões com validade) e as abas das contas bancárias e dos centros de custo da empresa.')
      ,('2.4', '2026-11-25', 2, 'NOVO', 'TODOS',
         N'rodapé dos e-mails por empresa: um texto livre com os contatos (e-mails, telefones, site), com prévia de como vai aparecer.',
         N'<b>rodapé dos e-mails por empresa</b>: um texto livre com os contatos (e-mails, telefones, site), com prévia de como vai aparecer.')
      ,('2.4', '2026-11-25', 3, 'NOVO', 'TODOS',
         N'telas de Contas bancárias e de Bancos (Bancos). Depois que a conta tem movimento, a empresa, o tipo e o saldo inicial não mudam mais; o saldo inicial também não muda em mês fechado.',
         N'telas de <b>Contas bancárias</b> e de <b>Bancos</b> (Bancos). Depois que a conta tem movimento, a empresa, o tipo e o saldo inicial não mudam mais; o saldo inicial também não muda em mês fechado.')
      ,('2.4', '2026-11-25', 4, 'NOVO', 'TODOS',
         N'tela de Centros de custo (Cadastros), com a data de encerramento (obra entregue): depois dela, lançamento novo no centro é bloqueado ou avisado, conforme a configuração.',
         N'tela de <b>Centros de custo</b> (Cadastros), com a <b>data de encerramento</b> (obra entregue): depois dela, lançamento novo no centro é bloqueado ou avisado, conforme a configuração.')
      ,('2.4', '2026-11-25', 5, 'NOVO', 'TODOS',
         N'Plano de contas em árvore (grupo › subgrupo › conta), com busca, quantidade de lançamentos em cada item e a ficha ao lado para incluir, alterar, desativar e ver o histórico.',
         N'<b>Plano de contas em árvore</b> (grupo › subgrupo › conta), com busca, quantidade de lançamentos em cada item e a ficha ao lado para incluir, alterar, desativar e ver o histórico.')
      ,('2.4', '2026-11-25', 6, 'NOVO', 'TODOS',
         N'escolha com busca de conta do plano, centro de custo e conta bancária: digite parte do nome ou o número e escolha na lista.',
         N'<b>escolha com busca</b> de conta do plano, centro de custo e conta bancária: digite parte do nome ou o número e escolha na lista.')
      ,('2.4', '2026-11-25', 7, 'NOVO', 'TODOS',
         N'na ficha do Parceiro, a conta do plano e o centro de custo padrão, que já vão vir escolhidos nos lançamentos dele.',
         N'na ficha do Parceiro, a <b>conta do plano</b> e o <b>centro de custo padrão</b>, que já vão vir escolhidos nos lançamentos dele.')
      ,('2.3', '2026-11-25', 1, 'NOVO', 'TODOS',
         N'o cadastro de Pessoas passa a se chamar Parceiros (o nome pode ser trocado em parâmetro). Cada parceiro pode ter vários tipos ao mesmo tempo (cliente, fornecedor, funcionário, corretor e outros que a empresa criar).',
         N'o cadastro de Pessoas passa a se chamar <b>Parceiros</b> (o nome pode ser trocado em parâmetro). Cada parceiro pode ter vários <b>tipos</b> ao mesmo tempo (cliente, fornecedor, funcionário, corretor e outros que a empresa criar).')
      ,('2.3', '2026-11-25', 2, 'NOVO', 'TODOS',
         N'tela Tipos de parceiro (Cadastros), para criar e organizar os tipos.',
         N'tela <b>Tipos de parceiro</b> (Cadastros), para criar e organizar os tipos.')
      ,('2.3', '2026-11-25', 3, 'NOVO', 'TODOS',
         N'na lista de Parceiros, o filtro por tipo, a marcação Pendências de cadastro (clientes com parcela em aberto cujo cadastro ainda não serve para boleto) e a coluna Cobrança, que diz o que falta.',
         N'na lista de Parceiros, o filtro por tipo, a marcação <b>Pendências de cadastro</b> (clientes com parcela em aberto cujo cadastro ainda não serve para boleto) e a coluna <b>Cobrança</b>, que diz o que falta.')
      ,('2.3', '2026-11-25', 4, 'NOVO', 'TODOS',
         N'na ficha, o CEP preenche o endereço e o CNPJ preenche razão social, nome fantasia e endereço (pela internet; pergunta antes de trocar o que já foi digitado).',
         N'na ficha, o <b>CEP preenche o endereço</b> e o <b>CNPJ preenche razão social, nome fantasia e endereço</b> (pela internet; pergunta antes de trocar o que já foi digitado).')
      ,('2.3', '2026-11-25', 5, 'NOVO', 'TODOS',
         N'aba Anexos na ficha do parceiro (contratos, documentos, certidões), com validade e aviso de vencido.',
         N'aba <b>Anexos</b> na ficha do parceiro (contratos, documentos, certidões), com validade e aviso de vencido.')
      ,('2.3', '2026-11-25', 6, 'MELHORIA', 'TODOS',
         N'nos contatos, a finalidade (cobrança, compras ou financeiro); escolher cobrança já marca o contato para receber boletos.',
         N'nos contatos, a <b>finalidade</b> (cobrança, compras ou financeiro); escolher cobrança já marca o contato para receber boletos.')
      ,('2.3', '2026-11-25', 7, 'MELHORIA', 'TODOS',
         N'endereço com número e complemento em campos próprios, como o banco exige no boleto.',
         N'endereço com <b>número e complemento</b> em campos próprios, como o banco exige no boleto.')
      ,('2.2', '2026-11-25', 1, 'NOVO', 'TODOS',
         N'tela Versões (Sistema › Monitoramento). A aba Notas mostra, versão por versão, o que é novo, o que melhorou e o que foi corrigido, com busca e exportação; a aba Histórico (só administrador) mostra quando cada atualização foi feita, de qual versão para qual e quanto tempo o sistema ficou fora do ar.',
         N'tela <b>Versões</b> (Sistema › Monitoramento). A aba <b>Notas</b> mostra, versão por versão, o que é novo, o que melhorou e o que foi corrigido, com busca e exportação; a aba <b>Histórico</b> (só administrador) mostra quando cada atualização foi feita, de qual versão para qual e quanto tempo o sistema ficou fora do ar.')
      ,('2.2', '2026-11-25', 2, 'NOVO', 'TODOS',
         N'aviso O que há de novo. Depois de uma atualização, cada usuário vê uma vez, logo depois de entrar, o resumo das novidades, com os botões Entendi e Ver todas as versões.',
         N'aviso <b>O que há de novo</b>. Depois de uma atualização, cada usuário vê uma vez, logo depois de entrar, o resumo das novidades, com os botões <b>Entendi</b> e <b>Ver todas as versões</b>.')
      ,('2.2', '2026-11-25', 3, 'NOVO', 'TODOS',
         N'a versão mostrada no topo das telas passa a abrir a tela de Versões.',
         N'a versão mostrada no topo das telas passa a abrir a tela de Versões.')
      ,('2.2', '2026-11-25', 4, 'NOVO', 'TODOS',
         N'quando o sistema é atualizado, a nota da versão é enviada por e-mail ao grupo de aviso de versões.',
         N'quando o sistema é atualizado, a nota da versão é enviada por e-mail ao grupo de aviso de versões.')
      ,('2.2', '2026-11-25', 5, 'MELHORIA', 'TODOS',
         N'a tela de casos da migração mostra o rótulo abatimento de parcela nos créditos que abatem a parcela.',
         N'a tela de casos da migração mostra o rótulo <b>abatimento de parcela</b> nos créditos que abatem a parcela.')
      ,('2.1', '2026-11-23', 1, 'NOVO', 'TODOS',
         N'tela Lixeira (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com Recuperar, Manter mais dias e Esvaziar agora, e a aba Prazos por tela (quanto tempo cada tela guarda na lixeira).',
         N'tela <b>Lixeira</b> (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com <b>Recuperar</b>, <b>Manter mais dias</b> e <b>Esvaziar agora</b>, e a aba <b>Prazos por tela</b> (quanto tempo cada tela guarda na lixeira).')
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : registro da versão do banco em [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : ÚLTIMA instrução do MASTER (depois da finalização): grava a
                versão que acabou de ser instalada. É a ÚNICA fonte da versão do
                banco: o montar_master.py lê o número daqui para o cabeçalho
                do MASTER, e a API exige o mesmo número
                (Infra/VersaoBanco.cs, VersaoExigida).
                REGRA: toda mudança que vai para o MASTER sobe este número e o
                da API juntos.
                Em banco de desenvolvimento (_LOCAL) grava com ORIGEM
                PACOTE_LOCAL. Rodar de novo grava outra linha (histórico).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d): versão 1.1 do banco.
    Versões do banco: 1.1 (20/11/2026) limite de login por computador e versão;
                      1.2 (20/11/2026) primeiro acesso da instalação;
                      1.3 (20/11/2026) SIS_Registro_Existe (anexos com o login da API);
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API);
                      1.5 (20/11/2026) backup do servidor (SIS.Backup, avisos de atraso).
                      1.6 (20/11/2026) restauração de backup pela tela (SIS.Backup_Restauracao).
                      1.7 (22/11/2026) ajuda exclusiva do administrador geral (SIS_Ajuda_Geral_Obter, tela SIS_AJUDA_GERAL).
                      1.8 (22/11/2026) atualização em um clique (SIS.Atualizacao, SIS_Atualizacao_Registrar).
                      1.9 (22/11/2026) telas de Usuários e Perfis (senha provisória que vence, perfis Financeiro e Consulta).
                      2.0 (22/11/2026) histórico padrão: desfazer pela auditoria e lixeira (P20, etapa 04b).
                      2.1 (23/11/2026) telas da lixeira, do histórico e da auditoria (P20, etapa 04b2).
                      2.2 (25/11/2026) versões e aviso O que há de novo (P22, etapas 04c e 04c2).
                      2.3 (25/11/2026) Parceiros: tipos, CEP/CNPJ, pendências de cobrança e anexos (P10, P12; etapas 04d e 04d2).
                      2.4 (25/11/2026) empresas, contas bancárias, bancos, centros de custo, plano de contas em árvore e escolha com busca (P11; etapa 04e).
                      2.5 (26/11/2026) contas a pagar e a receber, pendências dos lançamentos (P17, P27), movimentação do Parceiro e parâmetros de uso (etapas 04f a 04f2e).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '2.5';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 04f2e concluído sem erro.';
GO

SET NOEXEC OFF;
GO
