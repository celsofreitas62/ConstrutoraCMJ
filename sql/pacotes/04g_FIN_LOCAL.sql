/*******************************************************************************
  Pacote      : 04g - baixa, caixa e transferencia: baixa e estorno (04g1), acoes, parametros, fechamento de caixa; banco continua 2.5 ate a 04g5
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 26/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f2e já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04g_Homologacao_Baixa.sql.
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
-- Arquivo: sql/objetos/SIS/Carga_SIS_Acao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que as telas podem ter. Só insere o que falta
                (regra 39). Ação nova de um módulo futuro entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (16/11/2026) - Ação EXECUTAR (rotinas e comandos; etapa 02d).
    v1.2 (20/11/2026) - Ação RESTAURAR (restauração de backup pela tela; etapa 03d2).
    v1.3 (22/11/2026) - Etapa 04b (P20): DESATIVAR (o antigo "Excluir", que só
                        desativava), DESFAZER (pelo histórico), RECUPERAR e
                        ESVAZIAR (lixeira); EXCLUIR passa a mandar para a
                        lixeira (nome acertado).
    v1.4 (25/11/2026) - Etapa 04f: LANCAR_RETROATIVO (lançar fora da trava de
                        datas do financeiro, com motivo; decisão de 18/11/2026).
    v1.5 (26/11/2026) - Etapa 04f2c (P27): PENDENCIA (incluir, resolver e
                        reabrir pendências dos lançamentos).
    v1.6 (26/11/2026) - Etapa 04g: LIBERAR_PENDENCIA (baixar parcela com
                        pendência que bloqueia, com justificativa) e
                        DESCONTO_LIMITE (desconto na baixa acima do
                        limite do parâmetro, com motivo).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Acao (CODIGO, NOME, ORDEM)
SELECT v.CODIGO, v.NOME, v.ORDEM
FROM (VALUES
        (CAST('VER' AS VARCHAR(20)), CAST(N'Ver / consultar' AS NVARCHAR(60)), CAST(10 AS SMALLINT)),
        ('INCLUIR',          N'Incluir',                     20),
        ('ALTERAR',          N'Alterar',                     30),
        ('EXCLUIR',          N'Excluir / cancelar registro', 40),
        ('EXPORTAR',         N'Exportar para Excel',         50),
        ('IMPORTAR',         N'Importar arquivo',            60),
        ('BAIXAR',           N'Baixar (pagar/receber)',      70),
        ('ESTORNAR',         N'Estornar',                    80),
        ('CANCELAR',         N'Cancelar (contrato, boleto)', 90),
        ('REABRIR',          N'Reabrir (mês, contrato)',    100),
        ('APROVAR',          N'Aprovar',                    110),
        ('ENVIAR',           N'Enviar (e-mail, remessa)',   120),
        ('DESBLOQUEAR',      N'Desbloquear usuário',        130),
        ('REDEFINIR_SENHA',  N'Definir senha provisória',   140),
        ('EXECUTAR',         N'Executar (rotina, comando)', 150),
        ('RESTAURAR',        N'Restaurar backup do banco',  160),
        ('DESATIVAR',        N'Desativar / reativar',        45),
        ('DESFAZER',         N'Desfazer pelo histórico',    170),
        ('RECUPERAR',        N'Recuperar da lixeira',       180),
        ('ESVAZIAR',         N'Esvaziar a lixeira (apagar de vez)', 190),
        ('LANCAR_RETROATIVO', N'Lançar fora da trava de datas (com motivo)', 200),
        ('PENDENCIA',        N'Pendências (incluir, resolver, reabrir)', 210),
        ('LIBERAR_PENDENCIA', N'Baixar com pendência que bloqueia (com justificativa)', 220),
        ('DESCONTO_LIMITE', N'Desconto na baixa acima do limite (com motivo)', 230)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

UPDATE a
   SET a.NOME = N'Excluir (vai para a lixeira) / cancelar', a.DT_ALTERACAO = SYSDATETIME(), a.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Acao a
WHERE a.CODIGO = 'EXCLUIR' AND a.NOME = N'Excluir / cancelar registro';
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga dos parâmetros do financeiro em [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas (aprovada em 18/11/2026) e proteções contra
                erro de digitação nos lançamentos (P17, aprovado em 25/11/2026).
                Regras FIN_REGRA_*: AVISO (pede confirmação, que fica
                registrada), BLOQUEIO (não deixa gravar) ou NAO (desligada).
                Só insere o que falta (regra 39): nunca sobrescreve o valor
                que a CMJ já alterou. NIVEL_MINIMO e OPCOES são da instalação
                e são acertados sempre. Os parâmetros de uso têm NIVEL_MINIMO
                1 (os dois administradores alteram em "Parâmetros de uso").
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (25/11/2026) - Etapa 04f2a: parâmetros da lista (dias "a vencer",
                        situação e visão ao abrir, canceladas em "todas").
    v1.2 (26/11/2026) - Etapa 04f2c (P27): regras das pendências automáticas
                        FIN_PEND_* (todas só para lançamentos em aberto;
                        data de corte e valor do anexo alteráveis pela
                        administradora, pedido do Celso em 26/11/2026).
    v1.3 (26/11/2026) - Etapa 04g: baixa (juros, multa, carência, cálculo
                        no a pagar, limite de desconto) e fechamento de caixa
                        (tipos de conta, aviso na transferência entre
                        empresas). Aprovado pelo Celso em 26/11/2026.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;

SELECT v.CHAVE, v.VALOR, v.TIPO, v.DESCRICAO, v.NIVEL, v.OPCOES
INTO #CargaParametro
FROM (VALUES
        (CAST('FIN_TRAVA_DATAS_ATIVA' AS VARCHAR(60)), CAST(N'S' AS NVARCHAR(4000)), CAST('SN' AS VARCHAR(10)),
         CAST(N'Liga a trava de datas dos lançamentos (datas muito antigas ou futuras são recusadas; quem tem a permissão "Lançar fora da trava de datas" grava informando o motivo).' AS NVARCHAR(400)),
         CAST(1 AS TINYINT), CAST(N'' AS NVARCHAR(200))),
        ('FIN_DIAS_TOLERANCIA_MES_ANTERIOR', N'5', 'INTEIRO',
         N'Data anterior ao 1º dia do mês atual é recusada, menos até este dia do mês, quando o mês anterior ainda é aceito.', 1, N''),
        ('FIN_EMISSAO_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de emissão do documento pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_BAIXA_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de pagamento, recebimento, transferência ou movimento bancário pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_VENCIMENTO_ANOS_FUTURO', N'35', 'INTEIRO',
         N'Até quantos anos à frente um vencimento pode ser lançado.', 1, N''),
        ('FIN_DATA_AVISO_DIAS', N'3', 'INTEIRO',
         N'Data de emissão (ou vencimento no passado) a mais destes dias de hoje, mesmo dentro do permitido: a tela pede para confirmar a data.', 1, N''),
        ('FIN_REGRA_DUPLIC_DOCUMENTO', N'BLOQUEIO', 'TEXTO',
         N'Mesmo parceiro e mesmo número de documento já lançado (no mesmo tipo, a pagar ou a receber). Vale para documento com número.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_DUPLIC_VALOR', N'AVISO', 'TEXTO',
         N'Possível duplicidade: mesmo parceiro, mesmo valor de parcela e vencimento próximo (dias em FIN_DUPLIC_VALOR_DIAS).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_DUPLIC_VALOR_DIAS', N'5', 'INTEIRO',
         N'Diferença de dias no vencimento para considerar possível duplicidade.', 1, N''),
        ('FIN_REGRA_VALOR_FORA_PADRAO', N'AVISO', 'TEXTO',
         N'Valor fora do padrão: maior que FIN_VALOR_FORA_PADRAO_VEZES vezes a média dos lançamentos do mesmo parceiro e conta do plano.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_VALOR_FORA_PADRAO_VEZES', N'3', 'DECIMAL',
         N'Quantas vezes acima da média o valor precisa estar para o aviso de valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MIN_HIST', N'3', 'INTEIRO',
         N'Quantos lançamentos anteriores (mesmo parceiro e conta) são necessários para calcular a média do valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MESES', N'12', 'INTEIRO',
         N'Quantos meses para trás entram na média do valor fora do padrão.', 1, N''),
        ('FIN_REGRA_VENC_ANTES_EMISSAO', N'AVISO', 'TEXTO',
         N'Vencimento de alguma parcela antes da data de emissão do documento.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_COMPETENCIA_DISTANTE', N'AVISO', 'TEXTO',
         N'Mês de competência distante do mês de emissão (mais que FIN_COMPETENCIA_MESES meses).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_COMPETENCIA_MESES', N'3', 'INTEIRO',
         N'Diferença máxima, em meses, entre a competência e a emissão antes do aviso.', 1, N''),
        ('FIN_REGRA_TIPO_PARCEIRO', N'AVISO', 'TEXTO',
         N'Parceiro sem o tipo Fornecedor (contas a pagar) ou Cliente (contas a receber); o aviso oferece marcar o tipo.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_TIPO_CONTA', N'AVISO', 'TEXTO',
         N'Conta do plano de receita usada em contas a pagar, ou de despesa em contas a receber.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_LISTA_POR_PAGINA', N'100', 'INTEIRO',
         N'Quantas linhas por página nas listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_DIAS_A_VENCER', N'7', 'INTEIRO',
         N'Quantos dias à frente contam como "a vencer" no contador e no filtro das listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_SITUACAO_INICIAL', N'EM_ABERTO', 'TEXTO',
         N'Situação já escolhida ao abrir as listas de contas a pagar e a receber (TODAS = sem filtro).', 1, N'EM_ABERTO;VENCIDA;HOJE;A_VENCER;TODAS'),
        ('FIN_LISTA_VISAO_INICIAL', N'PARCELA', 'TEXTO',
         N'Visão ao abrir as listas: PARCELA (uma linha por vencimento) ou LANCAMENTO (uma linha por lançamento).', 1, N'PARCELA;LANCAMENTO'),
        ('FIN_LISTA_OCULTA_CANCELADAS', N'S', 'SN',
         N'S = a situação "Todas" não mostra as parcelas canceladas (aparecem só escolhendo "Cancelada").', 1, N''),
        ('FIN_PEND_SEM_CENTRO', N'S', 'SN',
         N'Pendência automática: lançamento em aberto sem centro de custo.', 1, N''),
        ('FIN_PEND_SEM_PLANO', N'S', 'SN',
         N'Pendência automática: lançamento em aberto sem conta do plano de contas.', 1, N''),
        ('FIN_PEND_SEM_DOCUMENTO', N'P', 'TEXTO',
         N'Pendência automática: lançamento em aberto sem número de documento. P = só contas a pagar, R = só a receber, A = ambos, N = desligada.', 1, N'P;R;A;N'),
        ('FIN_PEND_PAGAR_SEM_ANEXO_VALOR', N'1000.00', 'DECIMAL',
         N'Pendência automática: conta a pagar em aberto com valor total acima deste, sem nenhum anexo (nota, boleto, contrato). 0 = desligada.', 1, N''),
        ('FIN_PEND_RECEBER_NAO_APTO', N'S', 'SN',
         N'Pendência automática: conta a receber em aberto de parceiro com o cadastro não apto para cobrança (falta CPF/CNPJ, endereço completo ou e-mail de cobrança).', 1, N''),
        ('FIN_PEND_VENCIDA_DIAS', N'30', 'INTEIRO',
         N'Pendência automática: parcela em aberto vencida há mais destes dias. 0 = desligada.', 1, N''),
        ('FIN_PEND_A_PARTIR_DE', N'2022-01-01', 'DATA',
         N'As pendências automáticas só olham os lançamentos em aberto com emissão a partir desta data. 01/01/2022 (início dos dados migrados) = todos.', 1, N''),
        ('FIN_BAIXA_MULTA_PERC', N'2.00', 'DECIMAL',
         N'Baixa com atraso: multa sugerida, em % do saldo da parcela (uma vez). 0 = sem multa.', 1, N''),
        ('FIN_BAIXA_JUROS_MES_PERC', N'1.00', 'DECIMAL',
         N'Baixa com atraso: juros sugeridos, em % ao mês, proporcionais aos dias de atraso (pro rata). 0 = sem juros.', 1, N''),
        ('FIN_BAIXA_CARENCIA_DIAS', N'0', 'INTEIRO',
         N'Baixa: dias depois do vencimento sem multa nem juros. Passou da carência, conta desde o vencimento.', 1, N''),
        ('FIN_BAIXA_CALCULA_PAGAR', N'N', 'SN',
         N'Calcular juros e multa também nas contas a pagar (N = o valor informado pelo fornecedor é digitado).', 1, N''),
        ('FIN_BAIXA_DESCONTO_LIMITE_PERC', N'5.00', 'DECIMAL',
         N'Desconto máximo na baixa a receber, em % do saldo da parcela. Acima disso, só com a ação "Desconto acima do limite" e motivo. 0 = sem limite.', 1, N''),
        ('FIN_CAIXA_FECHAMENTO_TIPOS', N'CAIXA', 'TEXTO',
         N'Tipos de conta que usam o fechamento de caixa, separados por vírgula (CAIXA, CORRENTE, POUPANCA, APLICACAO, PERMUTA). Vazio = nenhum.', 1, N''),
        ('FIN_TRANSF_ENTRE_EMPRESAS', N'AVISO', 'TEXTO',
         N'Transferência entre contas de empresas diferentes do grupo: AVISO (pede confirmação), BLOQUEIO (não deixa) ou NAO (sem aviso).', 1, N'AVISO;BLOQUEIO;NAO')
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, NIVEL, OPCOES);

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, c.NIVEL, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = c.NIVEL, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> c.NIVEL OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

-- Parâmetros de uso de outras etapas que os dois administradores também alteram
UPDATE p
   SET p.NIVEL_MINIMO = 1
FROM SIS.Parametro p
WHERE p.CHAVE IN ('CENTRO_ENCERRADO_BLOQUEIA')
  AND p.NIVEL_MINIMO <> 1;

DROP TABLE IF EXISTS #CargaParametro;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] do módulo FIN
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Tela "Arquivo morto" (só consulta: VER e EXPORTAR, sem incluir,
                alterar ou excluir). Nasce DESABILITADA, como toda tela de módulo
                novo. As telas de lançamento, baixa e conciliação entram na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
    v1.1 (25/11/2026) - Etapa 04f: telas "Contas a pagar" (FIN_PAGAR) e
                        "Contas a receber" (FIN_RECEBER), mesma tela com o tipo
                        no endereço, permissões separadas; nascem desabilitadas.
    v1.2 (26/11/2026) - Etapa 04f2c (P27): tela "Tipos de pendência"
                        (FIN_PENDENCIA_TIPO, nasce desabilitada); ação PENDENCIA
                        nas telas de pagar e receber, dada (só quando nasce) a
                        quem já tinha ALTERAR; FIN.Lancamento_Pendencia nas
                        tabelas das duas telas.
    v1.3 (26/11/2026) - Etapa 04g: ações BAIXAR e ESTORNAR nas telas de
                        pagar e receber, dadas (só quando nascem) a quem já
                        tinha ALTERAR; LIBERAR_PENDENCIA e
                        DESCONTO_LIMITE nascem sem ninguém (os
                        administradores dão pela tela Perfis e permissões);
                        FIN.Baixa nas tabelas das duas telas.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_ARQUIVO_MORTO', N'Arquivo morto', 'TELA', 'fin/arquivo-morto.html', 90, 0, 0, 'FIN.Arquivo_Morto'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_ARQUIVO_MORTO' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('FIN_ARQUIVO_MORTO', 'EXPORTAR')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, v.CODIGO, v.NOME, 'TELA', v.CAMINHO, v.ORDEM, 0, 0, 'FIN.Lancamento,FIN.Parcela'
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40)), CAST(N'Contas a pagar' AS NVARCHAR(80)), CAST('fin/lancamentos.html?tipo=P' AS VARCHAR(200)), CAST(10 AS SMALLINT)),
             ('FIN_RECEBER', N'Contas a receber', 'fin/lancamentos.html?tipo=R', 20)) v (CODIGO, NOME, CAMINHO, ORDEM)
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('CANCELAR'), ('EXCLUIR'), ('EXPORTAR'), ('DESFAZER'), ('LANCAR_RETROATIVO')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- Etapa 04f2c (P27): tabelas das telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia';
GO

-- Tela Financeiro › Tipos de pendência
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_PENDENCIA_TIPO', N'Tipos de pendência', 'TELA', 'fin/pendencia-tipos.html', 80, 0, 0, 'FIN.Pendencia_Tipo'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_PENDENCIA_TIPO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('EXCLUIR'), ('DESATIVAR'), ('EXPORTAR'), ('DESFAZER')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_PENDENCIA_TIPO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- Ação PENDENCIA nas telas de pagar e receber: quem tinha ALTERAR recebe, só quando a ação nasce
DECLARE @NovosPendencia TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM INTO @NovosPendencia (ID_ITEM_ACAO, ID_ITEM)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'PENDENCIA'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- Etapa 04g: baixa e estorno nas telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa';
GO

-- BAIXAR e ESTORNAR: quem tinha ALTERAR recebe, só quando a ação nasce na tela
DECLARE @NovosBaixa TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL, ACAO VARCHAR(20) NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM, '' INTO @NovosBaixa (ID_ITEM_ACAO, ID_ITEM, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('BAIXAR' AS VARCHAR(20))), ('ESTORNAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT DISTINCT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT DISTINCT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- LIBERAR_PENDENCIA e DESCONTO_LIMITE: nascem sem ninguém
INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('LIBERAR_PENDENCIA' AS VARCHAR(20))), ('DESCONTO_LIMITE')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Caixa_Fechamento.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Caixa_Fechamento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Fechamento de caixa por conta e data (aprovado em 26/11/2026,
                04g). Guarda o saldo do sistema no fim do dia, o saldo contado
                e a diferença (motivo obrigatório quando houver; pode gerar um
                movimento de AJUSTE, ID_MOVIMENTO_AJUSTE). Fechado (SITUACAO
                FECHADO) bloqueia baixa, estorno e transferência na conta com
                data até DT_FECHAMENTO. Reabrir (REABERTO) exige a ação REABRIR
                e motivo; o registro fica para a auditoria. Tipos de conta que
                usam o fechamento: parâmetro FIN_CAIXA_FECHAMENTO_TIPOS.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Caixa_Fechamento]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Caixa_Fechamento]
    (
        ID_CAIXA_FECHAMENTO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA             INT            NOT NULL,
        DT_FECHAMENTO        DATE           NOT NULL,
        SALDO_SISTEMA        DECIMAL(18,2)  NOT NULL,
        SALDO_CONTADO        DECIMAL(18,2)  NOT NULL,
        DIFERENCA            AS (CAST(SALDO_CONTADO - SALDO_SISTEMA AS DECIMAL(18,2))) PERSISTED,
        MOTIVO_DIFERENCA     NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_MOTIVO_DIFERENCA DEFAULT (N''),
        ID_MOVIMENTO_AJUSTE  BIGINT         NULL,
        OBSERVACAO           NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_OBSERVACAO DEFAULT (N''),
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Caixa_Fechamento_SITUACAO DEFAULT ('FECHADO'),
        DT_REABERTURA        DATETIME2(0)   NULL,
        USUARIO_REABERTURA   NVARCHAR(100)  NULL,
        MOTIVO_REABERTURA    NVARCHAR(400)  NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Caixa_Fechamento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Caixa_Fechamento           PRIMARY KEY CLUSTERED (ID_CAIXA_FECHAMENTO),
        CONSTRAINT FK_Caixa_Fechamento_Conta     FOREIGN KEY (ID_CONTA)            REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Caixa_Fechamento_Movimento FOREIGN KEY (ID_MOVIMENTO_AJUSTE) REFERENCES [BANCO].[Movimento] (ID_MOVIMENTO),
        CONSTRAINT CK_Caixa_Fechamento_SITUACAO  CHECK (SITUACAO IN ('FECHADO', 'REABERTO')),
        CONSTRAINT CK_Caixa_Fechamento_MOTIVO    CHECK (SALDO_CONTADO = SALDO_SISTEMA OR LEN(MOTIVO_DIFERENCA) > 0),
        CONSTRAINT CK_Caixa_Fechamento_REABERTO  CHECK (SITUACAO = 'FECHADO' OR (DT_REABERTURA IS NOT NULL AND LEN(ISNULL(MOTIVO_REABERTURA, N'')) > 0))
    );

    CREATE UNIQUE INDEX UQ_Caixa_Fechamento_FECHADO ON [BANCO].[Caixa_Fechamento] (ID_CONTA, DT_FECHAMENTO) WHERE SITUACAO = 'FECHADO';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
    v1.1 (26/11/2026) - Etapa 04f2c (P27): FIN.Pendencia_Tipo e
                        FIN.Lancamento_Pendencia.
    v1.2 (26/11/2026) - Etapa 04g: BANCO.Caixa_Fechamento.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Pendencia_Tipo',   @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento_Pendencia', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Caixa_Fechamento', @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.fn_BANCO_Caixa_Recusa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[fn_BANCO_Caixa_Recusa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Fechamento de caixa (04g): a conta aceita movimento nesta data?
                Devolve '' quando aceita, ou a mensagem de recusa quando há um
                fechamento FECHADO na conta com data igual ou posterior. Fonte
                única da regra: baixa, estorno, transferência e ajuste chamam.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
  Homologação (LOCAL):
    -- SELECT BANCO.fn_BANCO_Caixa_Recusa(1, '2026-11-26');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [BANCO].[fn_BANCO_Caixa_Recusa] (@IdConta INT, @Data DATE)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Fechado DATE, @Conta NVARCHAR(100);

    SELECT @Fechado = MAX(f.DT_FECHAMENTO)
    FROM BANCO.Caixa_Fechamento f
    WHERE f.ID_CONTA = @IdConta AND f.SITUACAO = 'FECHADO';

    IF @Fechado IS NULL OR @Data IS NULL OR @Data > @Fechado RETURN N'';

    SELECT @Conta = c.DESCRICAO FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;

    RETURN N'O caixa da conta ' + ISNULL(@Conta, N'') + N' está fechado até '
         + CONVERT(NVARCHAR(10), @Fechado, 103) + N': reabra o fechamento para movimentar em '
         + CONVERT(NVARCHAR(10), @Data, 103) + N'.';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Baixa_Sugerir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Baixa_Sugerir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Baixa (04g): sugestão de juros, multa e limite de desconto de
                uma parcela numa data de pagamento. Fonte única do cálculo
                (tela e FIN_Baixa_Gravar). Função em linha (parâmetros lidos
                direto de SIS.Parametro, lição de desempenho da 04f2c).
                  - calcula só a receber, ou também a pagar quando
                    FIN_BAIXA_CALCULA_PAGAR = S;
                  - atraso = dias entre o vencimento e o pagamento; dentro da
                    carência (FIN_BAIXA_CARENCIA_DIAS) não há encargo; passou,
                    conta desde o vencimento;
                  - multa (FIN_BAIXA_MULTA_PERC) sobre o principal pago, uma
                    vez só: se a parcela já pagou multa numa baixa parcial,
                    não sugere de novo;
                  - juros (FIN_BAIXA_JUROS_MES_PERC) ao mês, pro rata dia
                    (mês de 30 dias), sobre o principal pago;
                  - DESCONTO_LIMITE: só a receber; % do saldo
                    (FIN_BAIXA_DESCONTO_LIMITE_PERC); NULL = sem limite.
                @Principal NULL = o saldo da parcela.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
  Homologação (LOCAL):
    -- SELECT * FROM FIN.fn_FIN_Baixa_Sugerir(1, '2026-11-26', NULL);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Baixa_Sugerir] (@IdParcela BIGINT, @DtPagamento DATE, @Principal DECIMAL(18,2))
RETURNS TABLE
AS
RETURN
    WITH Par AS
    (
        SELECT ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_MULTA_PERC'           THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS MULTA_PERC,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_JUROS_MES_PERC'       THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS JUROS_PERC,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_CARENCIA_DIAS'        THEN TRY_CONVERT(INT, p.VALOR) END), 0)                                  AS CARENCIA,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_CALCULA_PAGAR'        THEN UPPER(LEFT(p.VALOR, 1)) END), N'N')                                 AS CALCULA_PAGAR,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_DESCONTO_LIMITE_PERC' THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS DESC_PERC
        FROM SIS.Parametro p
        WHERE p.CHAVE IN ('FIN_BAIXA_MULTA_PERC', 'FIN_BAIXA_JUROS_MES_PERC', 'FIN_BAIXA_CARENCIA_DIAS', 'FIN_BAIXA_CALCULA_PAGAR', 'FIN_BAIXA_DESCONTO_LIMITE_PERC')
    ),
    Base AS
    (
        SELECT p.ID_PARCELA, l.TIPO, p.DT_VENCIMENTO, p.SALDO,
               CAST(ISNULL(@Principal, p.SALDO) AS DECIMAL(18,2)) AS PRINCIPAL,
               CASE WHEN @DtPagamento > p.DT_VENCIMENTO THEN DATEDIFF(DAY, p.DT_VENCIMENTO, @DtPagamento) ELSE 0 END AS DIAS_ATRASO,
               CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA GROUP BY b.ID_PARCELA HAVING SUM(b.MULTA) > 0)
                    THEN 1 ELSE 0 END AS JA_PAGOU_MULTA,
               x.MULTA_PERC, x.JUROS_PERC, x.CARENCIA, x.DESC_PERC,
               CASE WHEN l.TIPO = 'R' OR x.CALCULA_PAGAR = N'S' THEN 1 ELSE 0 END AS CALCULA_TIPO
        FROM FIN.Parcela p
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        CROSS JOIN Par x
        WHERE p.ID_PARCELA = @IdParcela
    )
    SELECT b.ID_PARCELA, b.TIPO, b.DT_VENCIMENTO, b.SALDO, b.PRINCIPAL, b.DIAS_ATRASO,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA THEN 1 ELSE 0 END AS BIT) AS CALCULA,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA AND b.JA_PAGOU_MULTA = 0
                     THEN ROUND(b.PRINCIPAL * b.MULTA_PERC / 100.0, 2) ELSE 0 END AS DECIMAL(18,2)) AS MULTA,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA
                     THEN ROUND(b.PRINCIPAL * b.JUROS_PERC / 100.0 / 30.0 * b.DIAS_ATRASO, 2) ELSE 0 END AS DECIMAL(18,2)) AS JUROS,
           CAST(CASE WHEN b.TIPO = 'R' AND b.DESC_PERC > 0 THEN ROUND(b.SALDO * b.DESC_PERC / 100.0, 2) END AS DECIMAL(18,2)) AS DESCONTO_LIMITE,
           b.MULTA_PERC, b.JUROS_PERC, b.CARENCIA
    FROM Base b;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Baixa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Baixa (pagamento ou recebimento) de uma ou várias parcelas, total
                ou parcial (etapa 04g, desenho aprovado em 26/11/2026). Todas as
                parcelas do mesmo tipo (pagar ou receber). Tudo-ou-nada.
                @Itens: JSON [{"idParcela":1,"principal":100.00,"juros":0,
                "multa":0,"correcao":0,"desconto":0,"abatimento":0,
                "retencao":0,"tarifa":0}]. principal = quanto da parcela fica
                quitado (abate o saldo; o abatimento faz parte dele, sem
                dinheiro). Gera um lote (origem BAIXA), UM BANCO.Movimento pelo
                total líquido (entra no receber, sai no pagar; sem movimento
                quando o líquido é zero, ex.: só abatimento) e um movimento
                TARIFA pela soma das tarifas. Cheque nasce não compensado (a
                compensação entra com a conciliação).
                Regras (mesmo contrato do FIN_Lancamento_Gravar: BLOQUEIO,
                MOTIVO, AVISO; @SomenteConferir = 1 é a prévia):
                  BLOQUEIO  parcela inexistente/repetida/cancelada/sem saldo,
                            lançamento cancelado/na lixeira/de previsão, tipos
                            misturados, valor acima do saldo ou negativo,
                            conta inativa, forma inválida, mês fechado (conta
                            contábil, mês do pagamento), caixa fechado
                            (BANCO.fn_BANCO_Caixa_Recusa); trava de datas,
                            pendência que bloqueia e desconto acima do limite
                            para quem não tem a permissão;
                  MOTIVO    trava de datas com LANCAR_RETROATIVO, pendência
                            que bloqueia com LIBERAR_PENDENCIA (justificativa)
                            e desconto acima do limite com DESCONTO_LIMITE:
                            grava só com @Motivo;
                  AVISO     encargo diferente do calculado (ENCARGO_AJUSTADO),
                            conta de outra empresa (CONTA_OUTRA_EMPRESA),
                            pagamento antes da emissão (PAGTO_ANTES_EMISSAO):
                            grava só com o código em @AvisosConfirmados.
                Avisos e motivos ficam em SIS.Aviso_Confirmado (TABELA
                FIN.Baixa).
                Permissão: BAIXAR em FIN_PAGAR / FIN_RECEBER.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID (1ª baixa), ID_MOVIMENTO,
                ID_LOTE, PENDENTE, AVISOS (JSON: codigo, nivel, mensagem,
                idReferencia = ID_PARCELA, campo).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Gravar @IdUsuario = 2, @DtPagamento = '2026-11-26', @IdConta = 1, @Forma = 'PIX',
    --      @Itens = N'[{"idParcela":1,"principal":100}]', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Gravar]
    @IdUsuario          INT,
    @DtPagamento        DATE            = NULL,
    @IdConta            INT             = NULL,
    @Forma              VARCHAR(12)     = NULL,
    @Itens              NVARCHAR(MAX)   = NULL,
    @Documento          NVARCHAR(40)    = NULL,
    @Observacao         NVARCHAR(400)   = NULL,
    @AvisosConfirmados  NVARCHAR(1000)  = NULL,
    @Motivo             NVARCHAR(400)   = NULL,
    @SomenteConferir    BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Baixa_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Tipo        CHAR(1);
    DECLARE @Item        VARCHAR(40);
    DECLARE @Avisos      NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente    BIT = 0;
    DECLARE @IdEmpresaConta INT;
    DECLARE @ContaAtiva  BIT;
    DECLARE @Liquido     DECIMAL(18,2);
    DECLARE @Tarifa      DECIMAL(18,2);
    DECLARE @IdLote      BIGINT;
    DECLARE @IdMovimento BIGINT;
    DECLARE @IdPrimeira  BIGINT;
    DECLARE @N           INT;
    DECLARE @Historico   NVARCHAR(200);

    CREATE TABLE #I (ORDEM INT NOT NULL, ID_PARCELA BIGINT NULL, PRINCIPAL DECIMAL(18,2) NULL, JUROS DECIMAL(18,2) NULL, MULTA DECIMAL(18,2) NULL,
                     CORRECAO DECIMAL(18,2) NULL, DESCONTO DECIMAL(18,2) NULL, ABATIMENTO DECIMAL(18,2) NULL, RETENCAO DECIMAL(18,2) NULL,
                     TARIFA DECIMAL(18,2) NULL, ID_LANCAMENTO BIGINT NULL, TIPO CHAR(1) NULL, ID_EMPRESA INT NULL, ID_PLANO_CONTA INT NULL,
                     NUMERO SMALLINT NULL, QTD SMALLINT NULL, SALDO DECIMAL(18,2) NULL, SITUACAO VARCHAR(10) NULL, SITUACAO_LANC VARCHAR(10) NULL,
                     PREVISAO BIT NULL, DT_EMISSAO DATE NULL, PESSOA NVARCHAR(150) NULL, DOCUMENTO NVARCHAR(40) NULL,
                     SUG_JUROS DECIMAL(18,2) NULL, SUG_MULTA DECIMAL(18,2) NULL, CALCULA BIT NULL, DESC_LIMITE DECIMAL(18,2) NULL,
                     ID_BAIXA BIGINT NULL);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Forma             = UPPER(LTRIM(RTRIM(ISNULL(@Forma, ''))));
        SET @Documento         = LTRIM(RTRIM(ISNULL(@Documento, N'')));
        SET @Observacao        = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Motivo            = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @AvisosConfirmados = ISNULL(@AvisosConfirmados, N'');

        ---------------------------------------------------------------------
        -- 1) Itens
        ---------------------------------------------------------------------
        IF ISJSON(ISNULL(@Itens, N'')) = 1
            INSERT INTO #I (ORDEM, ID_PARCELA, PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO, RETENCAO, TARIFA)
            SELECT CONVERT(INT, j.[key]) + 1, x.idParcela, x.principal, ISNULL(x.juros, 0), ISNULL(x.multa, 0), ISNULL(x.correcao, 0),
                   ISNULL(x.desconto, 0), ISNULL(x.abatimento, 0), ISNULL(x.retencao, 0), ISNULL(x.tarifa, 0)
            FROM OPENJSON(@Itens) j
            CROSS APPLY OPENJSON(j.[value]) WITH (idParcela BIGINT '$.idParcela', principal DECIMAL(18,2) '$.principal', juros DECIMAL(18,2) '$.juros',
                                                  multa DECIMAL(18,2) '$.multa', correcao DECIMAL(18,2) '$.correcao', desconto DECIMAL(18,2) '$.desconto',
                                                  abatimento DECIMAL(18,2) '$.abatimento', retencao DECIMAL(18,2) '$.retencao', tarifa DECIMAL(18,2) '$.tarifa') x;

        UPDATE i
           SET i.ID_LANCAMENTO = l.ID_LANCAMENTO, i.TIPO = l.TIPO, i.ID_EMPRESA = l.ID_EMPRESA, i.ID_PLANO_CONTA = l.ID_PLANO_CONTA,
               i.NUMERO = p.NUMERO, i.QTD = p.QTD_PARCELAS, i.SALDO = p.SALDO, i.SITUACAO = p.SITUACAO, i.SITUACAO_LANC = l.SITUACAO,
               i.PREVISAO = l.PREVISAO, i.DT_EMISSAO = l.DT_EMISSAO, i.DOCUMENTO = l.DOCUMENTO,
               i.PESSOA = ISNULL(NULLIF(pe.NOME_FANTASIA, N''), pe.NOME)
        FROM #I i
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = i.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        LEFT  JOIN CAD.Pessoa pe    ON pe.ID_PESSOA = l.ID_PESSOA;

        SELECT TOP 1 @Tipo = i.TIPO FROM #I i WHERE i.TIPO IS NOT NULL ORDER BY i.ORDEM;
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;

        IF NOT EXISTS (SELECT 1 FROM #I)
            SET @Recusa = N'Escolha pelo menos uma parcela para baixar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I WHERE ID_LANCAMENTO IS NULL)
            SET @Recusa = N'Parcela não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'BAIXAR') = 0
            SET @Recusa = CASE @Tipo WHEN 'P' THEN N'Você não tem permissão para baixar contas a pagar.' ELSE N'Você não tem permissão para baixar contas a receber.' END;
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I WHERE TIPO <> @Tipo)
            SET @Recusa = N'Baixe as contas a pagar e as contas a receber separadamente.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I GROUP BY ID_PARCELA HAVING COUNT(*) > 1)
            SET @Recusa = N'A mesma parcela foi escolhida mais de uma vez.';
        IF @Recusa = N'' AND @DtPagamento IS NULL
            SET @Recusa = CASE @Tipo WHEN 'P' THEN N'Informe a data do pagamento.' ELSE N'Informe a data do recebimento.' END;

        SELECT @IdEmpresaConta = c.ID_EMPRESA, @ContaAtiva = c.ATIVO FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;
        IF @Recusa = N'' AND @ContaAtiva IS NULL
            SET @Recusa = N'Escolha a conta (banco ou caixa).';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        UPDATE i
           SET i.SUG_JUROS = s.JUROS, i.SUG_MULTA = s.MULTA, i.CALCULA = s.CALCULA, i.DESC_LIMITE = s.DESCONTO_LIMITE
        FROM #I i
        CROSS APPLY FIN.fn_FIN_Baixa_Sugerir(i.ID_PARCELA, @DtPagamento, i.PRINCIPAL) s;

        ---------------------------------------------------------------------
        -- 2) Regras
        ---------------------------------------------------------------------
        IF @ContaAtiva = 0
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CONTA_INATIVA', 'BLOQUEIO', N'A conta escolhida está desativada.', 'idConta');

        IF @Forma NOT IN ('PIX', 'BOLETO', 'TED', 'DOC', 'DEBITO', 'DINHEIRO', 'CHEQUE', 'PERMUTA', 'CARTAO', 'OUTRA')
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('FORMA', 'BLOQUEIO', N'Escolha a forma de pagamento.', 'forma');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'PARCELA_SITUACAO', 'BLOQUEIO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
               + CASE WHEN i.SITUACAO_LANC = 'CANCELADO' OR i.SITUACAO = 'CANCELADA' THEN N': está cancelada.'
                      WHEN SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', i.ID_LANCAMENTO) = 1 THEN N': o lançamento está na lixeira.'
                      WHEN i.PREVISAO = 1 THEN N': é uma previsão (tire a marca de previsão no lançamento antes de baixar).'
                      ELSE N': não tem saldo em aberto.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.SITUACAO_LANC = 'CANCELADO' OR i.SITUACAO = 'CANCELADA' OR i.PREVISAO = 1 OR i.SALDO <= 0
           OR SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', i.ID_LANCAMENTO) = 1;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'VALOR', 'BLOQUEIO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
               + CASE WHEN ISNULL(i.PRINCIPAL, 0) <= 0 THEN N': informe o valor a baixar.'
                      WHEN i.PRINCIPAL > i.SALDO THEN N': o valor ' + FORMAT(i.PRINCIPAL, 'N2', 'pt-BR') + N' passa do saldo em aberto ' + FORMAT(i.SALDO, 'N2', 'pt-BR') + N'.'
                      WHEN i.ABATIMENTO > i.PRINCIPAL THEN N': o abatimento passa do valor baixado.'
                      ELSE N': juros, multa, correção, desconto, abatimento, retenção e tarifa não podem ser negativos, e o valor líquido não pode ficar negativo.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.SALDO > 0
          AND (ISNULL(i.PRINCIPAL, 0) <= 0 OR i.PRINCIPAL > i.SALDO OR i.ABATIMENTO > i.PRINCIPAL
               OR i.JUROS < 0 OR i.MULTA < 0 OR i.CORRECAO < 0 OR i.DESCONTO < 0 OR i.ABATIMENTO < 0 OR i.RETENCAO < 0 OR i.TARIFA < 0
               OR i.PRINCIPAL + i.JUROS + i.MULTA + i.CORRECAO - i.DESCONTO - i.ABATIMENTO - i.RETENCAO < 0);

        -- mês fechado (conta contábil; regime de caixa: mês do pagamento)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES))
               + N' está fechado para a empresa ' + ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) + N' (conta contábil).', 'dtPagamento'
        FROM #I i
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = i.ID_EMPRESA AND m.MES = DATEFROMPARTS(YEAR(@DtPagamento), MONTH(@DtPagamento), 1) AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = i.ID_PLANO_CONTA AND pc.CONTABIL = 1
        INNER JOIN CAD.Empresa e      ON e.ID_EMPRESA = i.ID_EMPRESA;

        -- caixa fechado
        IF BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtPagamento) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtPagamento), 'dtPagamento');

        -- trava de datas
        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtPagamento) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_BAIXA', CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
                    FIN.fn_FIN_Data_Recusa('BAIXA', @DtPagamento), 'dtPagamento');

        -- pendência que bloqueia a baixa (P27): liberação com justificativa
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'PENDENCIA_BLOQUEIA',
               CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LIBERAR_PENDENCIA') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               LEFT(N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
                    + N': pendência que bloqueia a baixa (' + b.MOTIVO + N')'
                    + CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LIBERAR_PENDENCIA') = 1 THEN N'. Para liberar, informe a justificativa.'
                           ELSE N'. Resolva a pendência ou peça a quem pode liberar.' END, 400),
               i.ID_PARCELA, 'itens'
        FROM #I i
        CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(i.ID_LANCAMENTO, i.ID_PARCELA) b
        WHERE b.BLOQUEIA = 1;

        -- desconto acima do limite (só a receber)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'DESCONTO_LIMITE',
               CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESCONTO_LIMITE') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N': desconto de ' + FORMAT(i.DESCONTO, 'N2', 'pt-BR')
               + N' passa do limite de ' + FORMAT(i.DESC_LIMITE, 'N2', 'pt-BR')
               + CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESCONTO_LIMITE') = 1 THEN N'. Informe o motivo.' ELSE N'. Peça a quem pode dar desconto maior.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.DESC_LIMITE IS NOT NULL AND i.DESCONTO > i.DESC_LIMITE;

        -- avisos
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'ENCARGO_AJUSTADO', 'AVISO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N': juros e multa informados ('
               + FORMAT(i.JUROS + i.MULTA, 'N2', 'pt-BR') + N') diferentes do calculado (' + FORMAT(i.SUG_JUROS + i.SUG_MULTA, 'N2', 'pt-BR') + N').',
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.CALCULA = 1 AND i.JUROS + i.MULTA <> i.SUG_JUROS + i.SUG_MULTA;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'CONTA_OUTRA_EMPRESA', 'AVISO', N'A conta escolhida é de outra empresa do grupo que não a do lançamento.', 'idConta'
        FROM #I i WHERE i.ID_EMPRESA <> @IdEmpresaConta;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT TOP 1 'PAGTO_ANTES_EMISSAO', 'AVISO',
               N'A data ' + CASE @Tipo WHEN 'P' THEN N'do pagamento' ELSE N'do recebimento' END + N' é anterior à emissão do lançamento ('
               + CONVERT(NVARCHAR(10), i.DT_EMISSAO, 103) + N').', i.ID_PARCELA, 'dtPagamento'
        FROM #I i WHERE @DtPagamento < i.DT_EMISSAO ORDER BY i.ORDEM;

        ---------------------------------------------------------------------
        -- 3) Resultado das regras
        ---------------------------------------------------------------------
        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r
                              ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF (EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5)
           OR EXISTS (SELECT 1 FROM #Regra r WHERE r.NIVEL = 'AVISO'
                        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@AvisosConfirmados, N',') s WHERE LTRIM(RTRIM(s.value)) = r.CODIGO))
            SET @Pendente = 1;

        IF @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Pendente = 0 THEN N'Nada a confirmar.'
                             WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5
                                  THEN N'Informe o motivo (justificativa) para gravar a baixa.'
                             ELSE N'Confira os avisos antes de gravar.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE,
                   @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- 4) Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @N       = (SELECT COUNT(*) FROM #I);
        SELECT @Liquido = SUM(i.PRINCIPAL + i.JUROS + i.MULTA + i.CORRECAO - i.DESCONTO - i.ABATIMENTO - i.RETENCAO), @Tarifa = SUM(i.TARIFA) FROM #I i;
        SET @Historico = LEFT(CASE @Tipo WHEN 'P' THEN N'Pagamento' ELSE N'Recebimento' END
                         + CASE WHEN @N = 1 THEN (SELECT N' - ' + ISNULL(i.PESSOA, N'') + N' - parc. ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD)
                                                  + CASE WHEN i.DOCUMENTO <> N'' THEN N' - doc. ' + i.DOCUMENTO ELSE N'' END FROM #I i)
                                ELSE N' de ' + CONVERT(NVARCHAR(10), @N) + N' parcelas' END, 200);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'BAIXA', @Descricao = @Historico,
             @TabelaReferencia = N'FIN.Baixa', @IdLote = @IdLote OUTPUT;

        -- trava as parcelas e confere o saldo de novo (concorrência)
        IF EXISTS (SELECT 1 FROM #I i INNER JOIN FIN.Parcela p WITH (UPDLOCK, HOLDLOCK) ON p.ID_PARCELA = i.ID_PARCELA
                   WHERE p.SALDO < i.PRINCIPAL OR p.SITUACAO = 'CANCELADA')
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Uma das parcelas foi alterada por outra pessoa. Abra a baixa de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @Liquido <> 0
        BEGIN
            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (@IdConta, @DtPagamento, CASE @Tipo WHEN 'P' THEN -@Liquido ELSE @Liquido END, 'BAIXA', @Historico, @Documento, @IdLote, ISNULL(@Usuario, N'sistema'));
            SET @IdMovimento = SCOPE_IDENTITY();
        END;

        IF @Tarifa > 0
            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (@IdConta, @DtPagamento, -@Tarifa, 'TARIFA', LEFT(N'Tarifa - ' + @Historico, 200), @Documento, @IdLote, ISNULL(@Usuario, N'sistema'));

        DECLARE @Ids TABLE (ID_BAIXA BIGINT NOT NULL, ID_PARCELA BIGINT NOT NULL);

        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO,
                               TARIFA, RETENCAO, ID_MOVIMENTO, COMPENSADO, OBSERVACAO, ID_LOTE, USUARIO_CRIACAO)
        OUTPUT inserted.ID_BAIXA, inserted.ID_PARCELA INTO @Ids (ID_BAIXA, ID_PARCELA)
        SELECT i.ID_PARCELA, @DtPagamento, @IdConta, @Forma, i.PRINCIPAL, i.JUROS, i.MULTA, i.CORRECAO, i.DESCONTO, i.ABATIMENTO,
               i.TARIFA, i.RETENCAO, @IdMovimento, CASE WHEN @Forma = 'CHEQUE' THEN 0 ELSE 1 END, @Observacao, @IdLote, ISNULL(@Usuario, N'sistema')
        FROM #I i
        ORDER BY i.ORDEM;

        UPDATE i SET i.ID_BAIXA = d.ID_BAIXA FROM #I i INNER JOIN @Ids d ON d.ID_PARCELA = i.ID_PARCELA;
        SELECT TOP 1 @IdPrimeira = i.ID_BAIXA FROM #I i ORDER BY i.ORDEM;

        -- avisos confirmados e motivos (na baixa da parcela citada; os gerais na primeira)
        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Baixa', ISNULL(i.ID_BAIXA, @IdPrimeira), r.CODIGO, r.NIVEL, r.MENSAGEM,
               CASE WHEN r.NIVEL = 'MOTIVO' THEN @Motivo ELSE N'' END, r.ID_REFERENCIA, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r
        LEFT JOIN #I i ON i.ID_PARCELA = r.ID_REFERENCIA
        WHERE r.NIVEL IN ('AVISO', 'MOTIVO');

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = @N;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @N = 1 THEN CASE @Tipo WHEN 'P' THEN N'Pagamento gravado.' ELSE N'Recebimento gravado.' END
                         ELSE CONVERT(NVARCHAR(10), @N) + CASE @Tipo WHEN 'P' THEN N' pagamentos gravados.' ELSE N' recebimentos gravados.' END END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPrimeira AS ID, @IdMovimento AS ID_MOVIMENTO, @IdLote AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #I;
        DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #I;
        DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a baixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Baixa_Estornar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Estornar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Estorna uma baixa (etapa 04g, aprovado em 26/11/2026). Nada é
                apagado: cada baixa estornada ganha uma baixa com os valores
                negativos (ID_BAIXA_ESTORNADA) e o movimento bancário ganha um
                movimento inverso; original e inverso ficam com SITUACAO
                ESTORNADO (o saldo soma os dois e zera). Pagamento em lote (um
                movimento para várias baixas) estorna inteiro, com a tarifa do
                mesmo lote. A parcela volta ao saldo anterior (gatilho do saldo).
                @DtEstorno (padrão hoje): data do estorno no banco/caixa;
                confere trava de datas (motivo com LANCAR_RETROATIVO), mês
                fechado (conta contábil) e caixa fechado nessa data.
                Motivo obrigatório (vai em OBSERVACAO das baixas de estorno e
                em SIS.Aviso_Confirmado, código ESTORNO).
                @SomenteConferir = 1: devolve, sem gravar, quantas baixas e o
                valor que serão estornados (prévia da tela).
                Permissão: ESTORNAR em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID (baixa informada), QTD_BAIXAS,
                VALOR (líquido estornado), PENDENTE, AVISOS.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Estornar @IdUsuario = 2, @IdBaixa = 1, @Motivo = N'Baixa em dobro', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Estornar]
    @IdUsuario        INT,
    @IdBaixa          BIGINT,
    @Motivo           NVARCHAR(400)  = NULL,
    @DtEstorno        DATE           = NULL,
    @SomenteConferir  BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Baixa_Estornar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Tipo         CHAR(1);
    DECLARE @Item         VARCHAR(40);
    DECLARE @IdMovimento  BIGINT;
    DECLARE @IdLoteOrig   BIGINT;
    DECLARE @OrigemLote   VARCHAR(30);
    DECLARE @IdConta      INT;
    DECLARE @Estornada    BIGINT;
    DECLARE @IdLote       BIGINT;
    DECLARE @Qtd          INT;
    DECLARE @Valor        DECIMAL(18,2);
    DECLARE @Avisos       NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente     BIT = 0;
    DECLARE @PodeRetro    BIT;

    CREATE TABLE #B (ID_BAIXA BIGINT NOT NULL PRIMARY KEY, ID_EMPRESA INT NULL, ID_PLANO_CONTA INT NULL, LIQUIDO DECIMAL(18,2) NOT NULL);
    CREATE TABLE #M (ID_MOVIMENTO BIGINT NOT NULL PRIMARY KEY);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Motivo    = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @DtEstorno = ISNULL(@DtEstorno, CONVERT(DATE, SYSDATETIME()));

        SELECT @Tipo = l.TIPO, @IdMovimento = b.ID_MOVIMENTO, @IdLoteOrig = b.ID_LOTE, @IdConta = b.ID_CONTA, @Estornada = b.ID_BAIXA_ESTORNADA
        FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE b.ID_BAIXA = @IdBaixa;
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;
        SELECT @OrigemLote = x.ORIGEM FROM SIS.Lote x WHERE x.ID_LOTE = @IdLoteOrig;

        IF @Tipo IS NULL
            SET @Recusa = N'Baixa não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ESTORNAR') = 0
            SET @Recusa = N'Você não tem permissão para estornar baixas.';
        IF @Recusa = N'' AND @Estornada IS NOT NULL
            SET @Recusa = N'Este registro já é um estorno.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_BAIXA_ESTORNADA = @IdBaixa)
            SET @Recusa = N'Esta baixa já foi estornada.';
        IF @Recusa = N'' AND @SomenteConferir = 0 AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo do estorno.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, 0 AS QTD_BAIXAS,
                   CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        -- o que vai junto: as baixas do mesmo movimento (pagamento em lote) ainda não estornadas
        INSERT INTO #B (ID_BAIXA, ID_EMPRESA, ID_PLANO_CONTA, LIQUIDO)
        SELECT b.ID_BAIXA, l.ID_EMPRESA, l.ID_PLANO_CONTA, b.VALOR_LIQUIDO
        FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE (b.ID_BAIXA = @IdBaixa OR (@IdMovimento IS NOT NULL AND b.ID_MOVIMENTO = @IdMovimento))
          AND b.ID_BAIXA_ESTORNADA IS NULL
          AND NOT EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA);

        -- movimentos: o da baixa e a tarifa do mesmo lote de baixa
        INSERT INTO #M (ID_MOVIMENTO)
        SELECT m.ID_MOVIMENTO
        FROM BANCO.Movimento m
        WHERE m.SITUACAO = 'ATIVO'
          AND (m.ID_MOVIMENTO = @IdMovimento
               OR (@OrigemLote = 'BAIXA' AND m.ID_LOTE = @IdLoteOrig AND m.TIPO = 'TARIFA'));

        SELECT @Qtd = COUNT(*), @Valor = SUM(LIQUIDO) FROM #B;

        -- regras na data do estorno
        SET @PodeRetro = SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO');
        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_BAIXA', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END, FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno), 'dtEstorno');

        IF BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtEstorno) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtEstorno), 'dtEstorno');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES)) + N' está fechado (conta contábil).', 'dtEstorno'
        FROM #B b
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = b.ID_EMPRESA AND m.MES = DATEFROMPARTS(YEAR(@DtEstorno), MONTH(@DtEstorno), 1) AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = b.ID_PLANO_CONTA AND pc.CONTABIL = 1;

        IF @Qtd > 1
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('ESTORNO_LOTE', 'INFO', N'Esta baixa faz parte de um pagamento em lote: as ' + CONVERT(NVARCHAR(10), @Qtd)
                    + N' baixas do mesmo movimento serão estornadas juntas (' + FORMAT(@Valor, 'N2', 'pt-BR') + N').', '');

        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, @Qtd AS QTD_BAIXAS,
                   @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @SomenteConferir = 1
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia do estorno.' AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, @Qtd AS QTD_BAIXAS,
                   @Valor AS VALOR, CAST(CASE WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') THEN 1 ELSE 0 END AS BIT) AS PENDENTE,
                   CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'ESTORNO_BAIXA', @Descricao = @Motivo,
             @TabelaReferencia = N'FIN.Baixa', @IdReferencia = @IdBaixa, @IdLote = @IdLote OUTPUT;

        -- concorrência: alguém estornou no meio
        IF EXISTS (SELECT 1 FROM #B b INNER JOIN FIN.Baixa x WITH (UPDLOCK, HOLDLOCK) ON x.ID_BAIXA_ESTORNADA = b.ID_BAIXA)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'A baixa foi estornada por outra pessoa. Abra a ficha de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdBaixa AS ID, 0 AS QTD_BAIXAS, CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        DECLARE @Mov TABLE (ID_ORIGINAL BIGINT NOT NULL, ID_INVERSO BIGINT NOT NULL);

        MERGE BANCO.Movimento AS t
        USING (SELECT m.ID_MOVIMENTO, m.ID_CONTA, m.VALOR, m.TIPO, m.HISTORICO, m.DOCUMENTO
               FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO) AS s
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (s.ID_CONTA, @DtEstorno, -s.VALOR, s.TIPO, LEFT(N'Estorno: ' + s.HISTORICO, 200), s.DOCUMENTO, 'ESTORNADO', @IdLote, ISNULL(@Usuario, N'sistema'))
        OUTPUT s.ID_MOVIMENTO, inserted.ID_MOVIMENTO INTO @Mov (ID_ORIGINAL, ID_INVERSO);

        UPDATE m
           SET m.SITUACAO = 'ESTORNADO', m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO;

        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO,
                               TARIFA, RETENCAO, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO, ID_BAIXA_ESTORNADA, OBSERVACAO, ID_LOTE, USUARIO_CRIACAO)
        SELECT b.ID_PARCELA, @DtEstorno, b.ID_CONTA, b.FORMA, -b.VALOR_PRINCIPAL, -b.JUROS, -b.MULTA, -b.CORRECAO, -b.DESCONTO, -b.ABATIMENTO,
               -b.TARIFA, -b.RETENCAO, mv.ID_INVERSO, b.COMPENSADO, b.DT_COMPENSACAO, b.ID_BAIXA, LEFT(N'Estorno: ' + @Motivo, 400), @IdLote, ISNULL(@Usuario, N'sistema')
        FROM FIN.Baixa b
        INNER JOIN #B x ON x.ID_BAIXA = b.ID_BAIXA
        LEFT  JOIN @Mov mv ON mv.ID_ORIGINAL = b.ID_MOVIMENTO;

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Baixa', b.ID_BAIXA, 'ESTORNO', 'MOTIVO', N'Baixa estornada em ' + CONVERT(NVARCHAR(10), @DtEstorno, 103) + N'.', @Motivo, NULL, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #B b
        UNION ALL
        SELECT N'FIN.Baixa', @IdBaixa, r.CODIGO, r.NIVEL, r.MENSAGEM, @Motivo, NULL, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r WHERE r.NIVEL = 'MOTIVO';

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = @Qtd;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Qtd = 1 THEN N'Baixa estornada.' ELSE CONVERT(NVARCHAR(10), @Qtd) + N' baixas estornadas.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdBaixa AS ID, @Qtd AS QTD_BAIXAS, @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível estornar a baixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdBaixa AS ID, 0 AS QTD_BAIXAS, CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Baixa_Preparar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Preparar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Janela de baixa (04g): dados das parcelas escolhidas para a
                data de pagamento, com a sugestão de juros, multa e limite de
                desconto (FIN.fn_FIN_Baixa_Sugerir), a pendência que bloqueia
                (FIN.fn_FIN_Pendencia_Bloqueia), a conta prevista e o que o
                usuário pode fazer (liberar pendência, desconto acima do
                limite, data fora da trava). Só leitura.
                @Parcelas: IDs separados por vírgula. @DtPagamento NULL = hoje.
                Permissão: BAIXAR em FIN_PAGAR / FIN_RECEBER (parcelas de tipo
                sem permissão não aparecem; nenhuma = erro 50001).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Preparar @IdUsuario = 2, @Parcelas = N'1,2', @DtPagamento = '2026-11-26';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Preparar]
    @IdUsuario    INT,
    @Parcelas     NVARCHAR(4000),
    @DtPagamento  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PodeP BIT = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'BAIXAR');
    DECLARE @PodeR BIT = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'BAIXAR');
    SET @DtPagamento = ISNULL(@DtPagamento, CONVERT(DATE, SYSDATETIME()));

    IF @PodeP = 0 AND @PodeR = 0
        THROW 50001, N'Você não tem permissão para baixar contas a pagar nem a receber.', 1;

    SELECT p.ID_PARCELA, p.ID_LANCAMENTO, l.TIPO, l.ID_EMPRESA, ISNULL(NULLIF(pe.NOME_FANTASIA, N''), pe.NOME) AS PESSOA,
           l.DOCUMENTO, l.HISTORICO, p.NUMERO, p.QTD_PARCELAS, p.DT_VENCIMENTO, p.VALOR, p.VALOR_BAIXADO, p.SALDO, p.SITUACAO,
           l.SITUACAO AS SITUACAO_LANCAMENTO, l.PREVISAO, p.ID_CONTA_PREVISTA,
           s.DIAS_ATRASO, s.CALCULA, s.MULTA, s.JUROS, s.DESCONTO_LIMITE, s.MULTA_PERC, s.JUROS_PERC, s.CARENCIA,
           b.BLOQUEIA AS BLOQUEIA_BAIXA, b.MOTIVO AS MOTIVO_BLOQUEIO,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'LIBERAR_PENDENCIA') AS PODE_LIBERAR_PENDENCIA,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'DESCONTO_LIMITE') AS PODE_DESCONTO_LIMITE,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'LANCAR_RETROATIVO') AS PODE_RETROATIVO
    FROM (SELECT DISTINCT TRY_CONVERT(BIGINT, LTRIM(RTRIM(v.value))) AS ID FROM STRING_SPLIT(@Parcelas, N',') v) x
    INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = x.ID
    INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
    LEFT  JOIN CAD.Pessoa pe    ON pe.ID_PESSOA = l.ID_PESSOA
    CROSS APPLY FIN.fn_FIN_Baixa_Sugerir(p.ID_PARCELA, @DtPagamento, NULL) s
    CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(p.ID_LANCAMENTO, p.ID_PARCELA) b
    WHERE (l.TIPO = 'P' AND @PodeP = 1) OR (l.TIPO = 'R' AND @PodeR = 1)
    ORDER BY p.DT_VENCIMENTO, pe.NOME, p.NUMERO;
END;
GO

PRINT N'Pacote 04g concluído sem erro.';
GO

SET NOEXEC OFF;
GO
