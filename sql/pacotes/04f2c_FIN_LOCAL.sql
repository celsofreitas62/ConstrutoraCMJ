/*******************************************************************************
  Pacote      : 04f2c - pendencias dos lancamentos (P27): tipos, pendencias manuais, regras automaticas e parametros; banco continua 2.4 ate a 04f2e
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 26/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f2a já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04f2c_Homologacao_Pendencias.sql, 04f e 04b.
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
-- Arquivo: sql/objetos/FIN/FIN.Pendencia_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Pendencia_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Tipos de pendência manual dos lançamentos (P27). Cadastrados
                pela CMJ na tela Financeiro › Tipos de pendência.
                APLICA_A      P = só contas a pagar, R = só a receber, A = ambos.
                BLOQUEIA_BAIXA 1 = enquanto houver pendência aberta deste tipo
                              o lançamento não pode ser baixado (a baixa, na
                              04g, confere por FIN.fn_FIN_Pendencia_Bloqueia);
                              0 = só avisa.
                ORIENTACAO    texto de ajuda: o que fazer para resolver.
                SISTEMA = 1: tipo usado pelo próprio sistema (MIGRACAO, "Veio
                da migração – conferir"); não pode ser excluído nem ter o
                código mudado.
                As pendências automáticas (sem centro, sem conta etc.) não
                usam esta tabela: são calculadas na hora por
                FIN.fn_FIN_Lancamento_Pendencias.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c, P27).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Pendencia_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Pendencia_Tipo]
    (
        ID_PENDENCIA_TIPO  INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(20)    NOT NULL,
        DESCRICAO          NVARCHAR(60)   NOT NULL,
        ORIENTACAO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Pendencia_Tipo_ORIENTACAO      DEFAULT (N''),
        APLICA_A           CHAR(1)        NOT NULL CONSTRAINT DF_Pendencia_Tipo_APLICA_A        DEFAULT ('A'),
        BLOQUEIA_BAIXA     BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_BLOQUEIA_BAIXA  DEFAULT (0),
        SISTEMA            BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_SISTEMA         DEFAULT (0),
        ORDEM              INT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_ORDEM           DEFAULT (100),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_ATIVO           DEFAULT (1),
        DT_EXCLUSAO        DATETIME2(0)   NULL,
        USUARIO_EXCLUSAO   NVARCHAR(100)  NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pendencia_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pendencia_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pendencia_Tipo          PRIMARY KEY CLUSTERED (ID_PENDENCIA_TIPO),
        CONSTRAINT UQ_Pendencia_Tipo_CODIGO   UNIQUE (CODIGO),
        CONSTRAINT CK_Pendencia_Tipo_CODIGO   CHECK (CODIGO <> ''),
        CONSTRAINT CK_Pendencia_Tipo_DESC     CHECK (DESCRICAO <> N''),
        CONSTRAINT CK_Pendencia_Tipo_APLICA_A CHECK (APLICA_A IN ('P', 'R', 'A'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Lancamento_Pendencia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Lancamento_Pendencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Pendências manuais dos lançamentos (P27): "aguardando nota
                fiscal", "conferir com o contador", "veio da migração –
                conferir" etc. Uma linha por pendência; ID_PARCELA preenchido
                quando a pendência é só de uma parcela.
                SITUACAO  ABERTA ou RESOLVIDA (com quem, quando e a nota da
                          resolução). Reabrir volta para ABERTA e limpa a
                          resolução (o histórico guarda o antes/depois).
                ATIVO = 0: pendência lançada por engano (desativada); não
                          conta em lugar nenhum.
                ORIGEM    MANUAL (pela tela) ou MIGRACAO (rodada da virada).
                Filha de FIN.Lancamento na lixeira e no histórico
                (SIS.Tabela_Config). Auditoria pela trigger padrão.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c, P27).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Lancamento_Pendencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Lancamento_Pendencia]
    (
        ID_LANCAMENTO_PENDENCIA BIGINT         IDENTITY(1,1) NOT NULL,
        ID_LANCAMENTO           BIGINT         NOT NULL,
        ID_PARCELA              BIGINT         NULL,
        ID_PENDENCIA_TIPO       INT            NOT NULL,
        OBSERVACAO              NVARCHAR(1000) NOT NULL CONSTRAINT DF_Lancamento_Pendencia_OBSERVACAO      DEFAULT (N''),
        ID_USUARIO_RESPONSAVEL  INT            NULL,
        DT_PREVISAO             DATE           NULL,
        SITUACAO                VARCHAR(10)    NOT NULL CONSTRAINT DF_Lancamento_Pendencia_SITUACAO        DEFAULT ('ABERTA'),
        DT_RESOLUCAO            DATETIME2(0)   NULL,
        USUARIO_RESOLUCAO       NVARCHAR(100)  NULL,
        RESOLUCAO               NVARCHAR(1000) NOT NULL CONSTRAINT DF_Lancamento_Pendencia_RESOLUCAO       DEFAULT (N''),
        ORIGEM                  VARCHAR(15)    NOT NULL CONSTRAINT DF_Lancamento_Pendencia_ORIGEM          DEFAULT ('MANUAL'),
        ATIVO                   BIT            NOT NULL CONSTRAINT DF_Lancamento_Pendencia_ATIVO           DEFAULT (1),
        DT_CRIACAO              DATETIME2(0)   NOT NULL CONSTRAINT DF_Lancamento_Pendencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lancamento_Pendencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO            DATETIME2(0)   NULL,
        USUARIO_ALTERACAO       NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lancamento_Pendencia             PRIMARY KEY CLUSTERED (ID_LANCAMENTO_PENDENCIA),
        CONSTRAINT FK_Lancamento_Pendencia_Lancamento  FOREIGN KEY (ID_LANCAMENTO)          REFERENCES [FIN].[Lancamento] (ID_LANCAMENTO),
        CONSTRAINT FK_Lancamento_Pendencia_Parcela     FOREIGN KEY (ID_PARCELA)             REFERENCES [FIN].[Parcela] (ID_PARCELA),
        CONSTRAINT FK_Lancamento_Pendencia_Tipo        FOREIGN KEY (ID_PENDENCIA_TIPO)      REFERENCES [FIN].[Pendencia_Tipo] (ID_PENDENCIA_TIPO),
        CONSTRAINT FK_Lancamento_Pendencia_Responsavel FOREIGN KEY (ID_USUARIO_RESPONSAVEL) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Lancamento_Pendencia_SITUACAO    CHECK (SITUACAO IN ('ABERTA', 'RESOLVIDA')),
        CONSTRAINT CK_Lancamento_Pendencia_ORIGEM      CHECK (ORIGEM IN ('MANUAL', 'MIGRACAO')),
        CONSTRAINT CK_Lancamento_Pendencia_RESOLVIDA   CHECK (SITUACAO = 'ABERTA' OR DT_RESOLUCAO IS NOT NULL)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lancamento_Pendencia_Lancamento' AND object_id = OBJECT_ID(N'[FIN].[Lancamento_Pendencia]'))
    CREATE NONCLUSTERED INDEX IX_Lancamento_Pendencia_Lancamento
        ON [FIN].[Lancamento_Pendencia] (ID_LANCAMENTO)
        INCLUDE (ID_PENDENCIA_TIPO, SITUACAO, ATIVO, ID_USUARIO_RESPONSAVEL, DT_PREVISAO);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lancamento_Pendencia_Aberta' AND object_id = OBJECT_ID(N'[FIN].[Lancamento_Pendencia]'))
    CREATE NONCLUSTERED INDEX IX_Lancamento_Pendencia_Aberta
        ON [FIN].[Lancamento_Pendencia] (ID_PENDENCIA_TIPO, ID_LANCAMENTO)
        INCLUDE (ID_USUARIO_RESPONSAVEL, DT_PREVISAO)
        WHERE SITUACAO = 'ABERTA' AND ATIVO = 1;
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
        ('PENDENCIA',        N'Pendências (incluir, resolver, reabrir)', 210)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

UPDATE a
   SET a.NOME = N'Excluir (vai para a lixeira) / cancelar', a.DT_ALTERACAO = SYSDATETIME(), a.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Acao a
WHERE a.CODIGO = 'EXCLUIR' AND a.NOME = N'Excluir / cancelar registro';
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
         N'As pendências automáticas só olham os lançamentos em aberto com emissão a partir desta data. 01/01/2022 (início dos dados migrados) = todos.', 1, N'')
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
-- Arquivo: sql/objetos/FIN/Carga_FIN_Pendencia_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga dos tipos de pendência de fábrica em [FIN].[Pendencia_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 (aprovado em 26/11/2026).
                MIGRACAO ("Veio da migração – conferir") é do sistema
                (SISTEMA = 1): sempre garantido e reativado.
                Os demais são sugestões e entram só quando a tabela nasce
                vazia (como os perfis de fábrica): se a CMJ alterar, desativar
                ou excluir um deles, uma atualização nunca o traz de volta.
                Idempotente.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo)
BEGIN
    INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, USUARIO_CRIACAO)
    SELECT v.CODIGO, v.DESCRICAO, v.ORIENTACAO, v.APLICA_A, v.BLOQUEIA, 0, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('AGUARDA_NF' AS VARCHAR(20)), CAST(N'Aguardando nota fiscal' AS NVARCHAR(60)),
             CAST(N'Anexar a nota fiscal ao lançamento e resolver a pendência. Enquanto estiver aberta, o lançamento não pode ser pago.' AS NVARCHAR(400)),
             CAST('P' AS CHAR(1)), CAST(1 AS BIT), CAST(10 AS INT)),
            ('AGUARDA_CONTRATO', N'Aguardando contrato', N'Anexar o contrato assinado e resolver a pendência.', 'A', 0, 20),
            ('CONFERIR_VALOR', N'Conferir valor', N'Conferir o valor com o documento ou com o parceiro e corrigir o lançamento, se for o caso.', 'A', 0, 30),
            ('CONFERIR_CONTADOR', N'Conferir com o contador', N'Confirmar com o contador a forma de lançar (conta, retenções, competência).', 'A', 0, 40)
         ) v (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA, ORDEM);
END;
GO

INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, USUARIO_CRIACAO)
SELECT 'MIGRACAO', N'Veio da migração – conferir',
       N'Lançamento que veio do Access com algum caso a conferir (o motivo está na observação). Conferir com o Access, corrigir o que for preciso e resolver a pendência.',
       'A', 0, 1, 90, N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo t WHERE t.CODIGO = 'MIGRACAO');

UPDATE FIN.Pendencia_Tipo
   SET SISTEMA = 1, ATIVO = 1, DT_EXCLUSAO = NULL, USUARIO_EXCLUSAO = NULL, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'instalacao'
WHERE CODIGO = 'MIGRACAO' AND (SISTEMA = 0 OR ATIVO = 0 OR DT_EXCLUSAO IS NOT NULL);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Tabela_Config.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Tabela_Config] e do grupo de e-mail da lixeira
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração do desfazer e da lixeira por tabela (P20,
                docs/requisitos/Lixeira_Desfazer.md). Inclui o que falta e
                acerta a parte técnica (filhas, campos, descrição) das que já
                existem; o prazo próprio (DIAS_GUARDA) é da CMJ e nunca é
                mudado por aqui.
                Grupo de e-mail LIXEIRA_AVISO (aviso do que será apagado):
                nasce com o e-mail interno do sistema; a CMJ ajusta na tela
                Grupos de e-mail.
                Idempotente.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
    v1.1 (25/11/2026) - Etapa 04d: CAD.Pessoa_Tipo (filha da Pessoa) e CAD.Parceiro_Tipo.
    v1.2 (25/11/2026) - Etapa 04f: FIN.Lancamento (lixeira, parcelas vão junto,
                        trava própria FIN_Lancamento_Trava_Conferir: só manual,
                        sem baixa, mês fechado de conta contábil) e FIN.Parcela
                        (desfazer; inclusão de parcela não é desfeita).
                        PROC_VALIDAR entra também pela carga.
    v1.3 (26/11/2026) - Etapa 04f2c (P27): FIN.Lancamento_Pendencia (filha
                        do lançamento) e FIN.Pendencia_Tipo (lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaConfig;

SELECT v.TABELA, v.DESFAZER, v.LIXEIRA, v.BLOQUEADOS, v.UNICOS, v.FILHAS, v.INCLUSAO, v.EXCLUSAO, v.DESCRICAO
INTO #CargaConfig
FROM (VALUES
        (CAST(N'CAD.Pessoa' AS NVARCHAR(256)), CAST(1 AS BIT), CAST(1 AS BIT), CAST(N'' AS NVARCHAR(1000)), CAST(N'CPF_CNPJ' AS NVARCHAR(400)),
         CAST(N'CAD.Pessoa_Contato.ID_PESSOA,CAD.Pessoa_Vinculo.ID_PESSOA,CAD.Pessoa_Dado_Bancario.ID_PESSOA,CAD.Pessoa_Tipo.ID_PESSOA' AS NVARCHAR(1000)),
         CAST('LIXEIRA' AS VARCHAR(10)), CAST('RECUSAR' AS VARCHAR(10)),
         CAST(N't.NOME + CASE WHEN t.CPF_CNPJ <> '''' THEN N'' ('' + CONVERT(NVARCHAR(20), t.CPF_CNPJ) + N'')'' ELSE N'''' END' AS NVARCHAR(1000))),
        (N'CAD.Pessoa_Contato',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(20), t.TIPO) + N'': '' + t.VALOR'),
        (N'CAD.Pessoa_Tipo',          1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Tipo '' + CAST(t.ID_PARCEIRO_TIPO AS NVARCHAR(10))'),
        (N'CAD.Parceiro_Tipo',        1, 1, N'SISTEMA', N'CODIGO', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Pessoa_Vinculo',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Vínculo '' + CONVERT(NVARCHAR(30), t.TIPO)'),
        (N'CAD.Pessoa_Dado_Bancario', 1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Conta '' + CONVERT(NVARCHAR(20), t.AGENCIA) + N'' / '' + CONVERT(NVARCHAR(30), t.CONTA)'),
        (N'CAD.Empresa',              1, 1, N'', N'CNPJ', N'', 'LIXEIRA', 'RECUSAR', N't.RAZAO_SOCIAL'),
        (N'CAD.Centro_Custo',         1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N'CONVERT(NVARCHAR(30), t.CODIGO) + N'' - '' + t.DESCRICAO'),
        (N'CAD.Plano_Grupo',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Subgrupo',       1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Conta',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Conta',              1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Banco',              1, 0, N'', N'', N'', 'RECUSAR', 'RECUSAR', N'CONVERT(NVARCHAR(10), t.CODIGO) + N'' - '' + t.NOME'),
        (N'SIS.Usuario',              1, 0, N'SENHA_HASH,SENHA_SALT,SENHA_ITERACOES,SENHA_ALGORITMO,DT_SENHA,TROCAR_SENHA,TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN,BLOQUEADO,DT_BLOQUEIO,INTERNO',
         N'', N'SIS.Usuario_Permissao.ID_USUARIO', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(100), t.LOGIN) + N'' - '' + t.NOME'),
        (N'SIS.Usuario_Permissao',    1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'SIS.Perfil',               1, 0, N'NIVEL_ADMIN', N'', N'SIS.Perfil_Permissao.ID_PERFIL', 'DESATIVAR', 'RECUSAR', N't.NOME'),
        (N'SIS.Perfil_Permissao',     1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'FIN.Lancamento',           1, 1, N'TIPO,ORIGEM,ID_ORIGEM,ID_LOTE,CODIGO_ACCESS,ORIGEM_ACCESS,ID_PEDIDO_COMPRA', N'', N'FIN.Parcela.ID_LANCAMENTO,FIN.Lancamento_Pendencia.ID_LANCAMENTO', 'LIXEIRA', 'RECUSAR',
         N'CASE t.TIPO WHEN ''P'' THEN N''A pagar '' ELSE N''A receber '' END + CASE WHEN t.DOCUMENTO <> N'''' THEN N''doc. '' + t.DOCUMENTO + N'' - '' ELSE N'''' END + t.HISTORICO + N'' ('' + CONVERT(NVARCHAR(30), t.VALOR_TOTAL) + N'')'''),
        (N'FIN.Parcela',              1, 0, N'VALOR_BAIXADO,SITUACAO,ID_LANCAMENTO,CODIGO_ACCESS,ID_LOTE', N'', N'', 'RECUSAR', 'RECUSAR',
         N'N''Parcela '' + CONVERT(NVARCHAR(5), t.NUMERO) + N''/'' + CONVERT(NVARCHAR(5), t.QTD_PARCELAS) + N'' venc. '' + CONVERT(NVARCHAR(10), t.DT_VENCIMENTO, 103)')
        ,(N'FIN.Lancamento_Pendencia', 1, 0, N'ID_LANCAMENTO,ORIGEM', N'', N'', 'DESATIVAR', 'RECUSAR',
         N'N''Pendência '' + CASE t.SITUACAO WHEN ''RESOLVIDA'' THEN N''resolvida'' ELSE N''aberta'' END + N'' (tipo '' + CAST(t.ID_PENDENCIA_TIPO AS NVARCHAR(10)) + N'')'''),
        (N'FIN.Pendencia_Tipo',       1, 1, N'SISTEMA', N'CODIGO', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO')
     ) v (TABELA, DESFAZER, LIXEIRA, BLOQUEADOS, UNICOS, FILHAS, INCLUSAO, EXCLUSAO, DESCRICAO);

INSERT INTO SIS.Tabela_Config (TABELA, PERMITE_DESFAZER, PERMITE_LIXEIRA, CAMPOS_BLOQUEADOS, CAMPOS_UNICOS, TABELAS_FILHAS, DESFAZER_INCLUSAO, DESFAZER_EXCLUSAO, DESCRICAO_SQL, USUARIO_CRIACAO)
SELECT c.TABELA, c.DESFAZER, c.LIXEIRA, c.BLOQUEADOS, c.UNICOS, c.FILHAS, c.INCLUSAO, c.EXCLUSAO, c.DESCRICAO, N'instalacao'
FROM #CargaConfig c
WHERE OBJECT_ID(c.TABELA, N'U') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config t WHERE t.TABELA = c.TABELA);

UPDATE t
   SET t.PERMITE_DESFAZER = c.DESFAZER, t.PERMITE_LIXEIRA = c.LIXEIRA, t.CAMPOS_BLOQUEADOS = c.BLOQUEADOS, t.CAMPOS_UNICOS = c.UNICOS,
       t.TABELAS_FILHAS = c.FILHAS, t.DESFAZER_INCLUSAO = c.INCLUSAO, t.DESFAZER_EXCLUSAO = c.EXCLUSAO, t.DESCRICAO_SQL = c.DESCRICAO,
       t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN #CargaConfig c ON c.TABELA = t.TABELA
WHERE t.PERMITE_DESFAZER <> c.DESFAZER OR t.PERMITE_LIXEIRA <> c.LIXEIRA OR t.CAMPOS_BLOQUEADOS <> c.BLOQUEADOS OR t.CAMPOS_UNICOS <> c.UNICOS
   OR t.TABELAS_FILHAS <> c.FILHAS OR t.DESFAZER_INCLUSAO <> c.INCLUSAO OR t.DESFAZER_EXCLUSAO <> c.EXCLUSAO OR t.DESCRICAO_SQL <> c.DESCRICAO;

UPDATE t
   SET t.PROC_VALIDAR = v.PROC_VALIDAR, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN (VALUES (CAST(N'FIN.Lancamento' AS NVARCHAR(256)), CAST(N'FIN.FIN_Lancamento_Trava_Conferir' AS NVARCHAR(256))),
                   (N'FIN.Parcela', N'FIN.FIN_Lancamento_Trava_Conferir')) v (TABELA, PROC_VALIDAR) ON v.TABELA = t.TABELA
WHERE t.PROC_VALIDAR <> v.PROC_VALIDAR;

DROP TABLE IF EXISTS #CargaConfig;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'LIXEIRA_AVISO', N'Aviso da lixeira', N'Recebem o aviso diário do que será apagado de vez da lixeira (Sistema › Lixeira).', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'LIXEIRA_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'LIXEIRA_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);
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
GO

PRINT N'Pacote 04f2c concluído sem erro.';
GO

SET NOEXEC OFF;
GO
