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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Checar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Checar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Confere os dígitos de CPF (11) ou CNPJ (14, inclusive o CNPJ
                alfanumérico) e devolve 1 linha com VALIDO (1/0). Fonte única
                da regra: CAD.fn_CAD_Documento_Valido (escalar) chama esta.
                Função em linha: dentro de consultas de muitas linhas não
                força o cálculo linha a linha (a escalar, por não poder ser
                incorporada ao plano, deixava a lista de lançamentos a receber
                lenta: 200 s; etapa 04f2c).
                Mesma regra da escalar v1.0: documento limpo (sem . - / espaço
                e tabulação, maiúsculo); todos os caracteres iguais = inválido.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- SELECT * FROM CAD.fn_CAD_Documento_Checar(N'529.982.247-25');      -- 1
    -- SELECT * FROM CAD.fn_CAD_Documento_Checar(N'25.686.528/0001-97');  -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Checar] (@Documento NVARCHAR(30))
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(CASE
                  WHEN d.D = '' OR REPLACE(d.D, LEFT(d.D, 1), '') = '' THEN 0
                  WHEN LEN(d.D) = 11 AND d.D NOT LIKE '%[^0-9]%'
                       THEN CASE WHEN c.V1 = ASCII(SUBSTRING(d.D, 10, 1)) - 48 AND c.V2 = ASCII(SUBSTRING(d.D, 11, 1)) - 48 THEN 1 ELSE 0 END
                  WHEN LEN(d.D) = 14 AND LEFT(d.D, 12) NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2 AND RIGHT(d.D, 2) NOT LIKE '%[^0-9]%'
                       THEN CASE WHEN j.V1 = ASCII(SUBSTRING(d.D, 13, 1)) - 48 AND j.V2 = ASCII(SUBSTRING(d.D, 14, 1)) - 48 THEN 1 ELSE 0 END
                  ELSE 0 END AS BIT) AS VALIDO
    FROM (SELECT CONVERT(VARCHAR(30), UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, N''))),
                 N'.', N''), N'-', N''), N'/', N''), N' ', N''), NCHAR(9), N''))) AS D) d
    CROSS APPLY (
        SELECT CASE WHEN s.S1 % 11 < 2 THEN 0 ELSE 11 - s.S1 % 11 END AS V1,
               CASE WHEN s.S2 % 11 < 2 THEN 0 ELSE 11 - s.S2 % 11 END AS V2
        FROM (SELECT SUM(CASE WHEN q.N <= 9 THEN q.X * (11 - q.N) ELSE 0 END) AS S1,
                     SUM(q.X * (12 - q.N)) AS S2
              FROM (SELECT v.N, ASCII(SUBSTRING(d.D, v.N, 1)) - 48 AS X
                    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v (N)) q) s
    ) c
    CROSS APPLY (
        SELECT CASE WHEN s.S1 % 11 < 2 THEN 0 ELSE 11 - s.S1 % 11 END AS V1,
               CASE WHEN s.S2 % 11 < 2 THEN 0 ELSE 11 - s.S2 % 11 END AS V2
        FROM (SELECT SUM(CASE WHEN q.N <= 12 THEN q.X * CASE WHEN q.N <= 4 THEN 6 - q.N ELSE 14 - q.N END ELSE 0 END) AS S1,
                     SUM(q.X * CASE WHEN q.N <= 5 THEN 7 - q.N ELSE 15 - q.N END) AS S2
              FROM (SELECT v.N, ASCII(SUBSTRING(d.D, v.N, 1)) - 48 AS X
                    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) v (N)) q) s
    ) j
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Valido.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Confere os dígitos verificadores de CPF (11 dígitos) e de CNPJ (14
                posições, aceitando o CNPJ alfanumérico: as 12 primeiras posições
                podem ter letras, valor = código ASCII - 48; os 2 dígitos finais são
                numéricos). Recusa todos os caracteres iguais. Vazio ou outro tamanho
                devolve 0. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (26/11/2026) - Etapa 04f2c: a regra passou para CAD.fn_CAD_Documento_Checar
                        (em linha, rápida em consultas grandes); esta chama aquela.

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Valido('529.982.247-25'), CAD.fn_CAD_Documento_Valido('12.ABC.345/01DE-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Valido] (@Documento NVARCHAR(30))
RETURNS BIT
AS
BEGIN
    RETURN ISNULL((SELECT c.VALIDO FROM CAD.fn_CAD_Documento_Checar(@Documento) c), CAST(0 AS BIT));
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Pessoa_Pendencia_Cobranca.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : P10 - cadastro apto para cobrança (boleto). Devolve uma linha
                com APTO (1/0) e PENDENCIA (texto do que falta, separado por
                "; "; vazio = apto). Exigências em parâmetros
                COBRANCA_APTO_EXIGE_DOCUMENTO / _ENDERECO / _EMAIL / _TELEFONE.
                E-mail: contato ativo principal ou de finalidade COBRANCA, com
                formato válido. Usada pela lista e ficha de Parceiros (aviso)
                e, na fase 6, pela trava da emissão do boleto.
                Função em linha (sem custo por linha nas listas).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
    v1.1 (26/11/2026) - Etapa 04f2c: totalmente em linha (parâmetros lidos
                        direto de SIS.Parametro e documento conferido por
                        CAD.fn_CAD_Documento_Checar); com funções escalares,
                        usada por lançamento, a lista a receber levava 200 s.

  Homologação (LOCAL):
    -- SELECT p.ID_PESSOA, f.* FROM CAD.Pessoa p CROSS APPLY CAD.fn_CAD_Pessoa_Pendencia_Cobranca(p.ID_PESSOA) f WHERE f.APTO = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca] (@IdPessoa INT)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN x.PENDENCIA = N'' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS APTO,
           x.PENDENCIA
    FROM (
        SELECT CONCAT_WS(N'; ',
                 CASE WHEN cfg.EXIGE_DOCUMENTO = 1
                           AND (p.CPF_CNPJ = '' OR dv.VALIDO = 0
                                OR LEN(p.CPF_CNPJ) <> CASE p.TIPO_PESSOA WHEN 'F' THEN 11 ELSE 14 END)
                      THEN CASE p.TIPO_PESSOA WHEN 'F' THEN N'CPF ausente ou inválido' ELSE N'CNPJ ausente ou inválido' END END,
                 CASE WHEN cfg.EXIGE_ENDERECO = 1
                           AND (LEN(p.CEP) <> 8 OR p.LOGRADOURO = N'' OR p.NUMERO = N'' OR p.BAIRRO = N'' OR p.CIDADE = N'' OR LEN(p.UF) <> 2)
                      THEN N'endereço incompleto (CEP, logradouro, número, bairro, cidade e UF)' END,
                 CASE WHEN cfg.EXIGE_EMAIL = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO = 'EMAIL'
                                             AND (c.PRINCIPAL = 1 OR c.FINALIDADE = 'COBRANCA')
                                             AND c.VALOR LIKE N'_%@_%._%' AND c.VALOR NOT LIKE N'% %' AND c.VALOR NOT LIKE N'%@%@%')
                      THEN N'sem e-mail principal ou de cobrança válido' END,
                 CASE WHEN cfg.EXIGE_TELEFONE = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO IN ('CELULAR', 'TELEFONE', 'WHATSAPP'))
                      THEN N'sem telefone' END) AS PENDENCIA
        FROM CAD.Pessoa p
        CROSS APPLY CAD.fn_CAD_Documento_Checar(p.CPF_CNPJ) dv
        CROSS JOIN (SELECT MAX(CASE WHEN pa.CHAVE = 'COBRANCA_APTO_EXIGE_DOCUMENTO' AND UPPER(LTRIM(RTRIM(pa.VALOR))) = N'S' THEN 1 ELSE 0 END) AS EXIGE_DOCUMENTO,
                           MAX(CASE WHEN pa.CHAVE = 'COBRANCA_APTO_EXIGE_ENDERECO'  AND UPPER(LTRIM(RTRIM(pa.VALOR))) = N'S' THEN 1 ELSE 0 END) AS EXIGE_ENDERECO,
                           MAX(CASE WHEN pa.CHAVE = 'COBRANCA_APTO_EXIGE_EMAIL'     AND UPPER(LTRIM(RTRIM(pa.VALOR))) = N'S' THEN 1 ELSE 0 END) AS EXIGE_EMAIL,
                           MAX(CASE WHEN pa.CHAVE = 'COBRANCA_APTO_EXIGE_TELEFONE'  AND UPPER(LTRIM(RTRIM(pa.VALOR))) = N'S' THEN 1 ELSE 0 END) AS EXIGE_TELEFONE
                    FROM SIS.Parametro pa WITH (NOLOCK)
                    WHERE pa.CHAVE LIKE 'COBRANCA[_]APTO[_]EXIGE[_]%') cfg
        WHERE p.ID_PESSOA = @IdPessoa
    ) x
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Lancamento_Pendencias.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Lancamento_Pendencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - pendências em aberto de um lançamento, uma linha por
                pendência. Fonte única da lista, dos contadores, da ficha e,
                mais adiante, do check-up diário (P25).
                AUTOMATICA: calculada na hora (nada gravado), só para
                  lançamento em aberto (ativo, fora da lixeira, com parcela
                  ABERTA ou PARCIAL) emitido a partir de FIN_PEND_A_PARTIR_DE;
                  some sozinha quando o problema é corrigido. Regras ligadas
                  por parâmetro (nível 1):
                    SEM_CENTRO      FIN_PEND_SEM_CENTRO (S/N)
                    SEM_PLANO       FIN_PEND_SEM_PLANO (S/N)
                    SEM_DOCUMENTO   FIN_PEND_SEM_DOCUMENTO (P, R, A ou N)
                    SEM_ANEXO       FIN_PEND_PAGAR_SEM_ANEXO_VALOR (a pagar
                                    com valor total acima; 0 = desligada)
                    NAO_APTO        FIN_PEND_RECEBER_NAO_APTO (a receber; P10)
                    VENCIDA         FIN_PEND_VENCIDA_DIAS (0 = desligada; uma
                                    linha por lançamento, com a parcela mais
                                    antiga)
                  Automáticas nunca bloqueiam a baixa.
                MANUAL: FIN.Lancamento_Pendencia ABERTA e ativa, de lançamento
                  ativo fora da lixeira (pago ou não). BLOQUEIA_BAIXA vem do
                  tipo; ATRASADA = previsão já passou.
                Função em linha: nas listas entra por CROSS APPLY sem custo
                por linha.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c). Parâmetros lidos direto de
                        SIS.Parametro (sem função escalar por linha).

  Homologação (LOCAL):
    -- SELECT TOP 50 l.ID_LANCAMENTO, f.* FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Lancamento_Pendencias] (@IdLancamento BIGINT)
RETURNS TABLE
AS
RETURN
(
    WITH cfg AS (   -- parâmetros lidos direto da tabela (função escalar por linha deixava a lista lenta)
        SELECT MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_CENTRO'       AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_CENTRO,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_PLANO'        AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_PLANO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_DOCUMENTO' THEN CONVERT(VARCHAR(1), UPPER(LTRIM(p.VALOR))) END), 'N') AS SEM_DOCUMENTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR' THEN TRY_CONVERT(DECIMAL(18,2), REPLACE(p.VALOR, N',', N'.')) END), 0) AS ANEXO_VALOR,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_RECEBER_NAO_APTO' AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS NAO_APTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_VENCIDA_DIAS' THEN TRY_CONVERT(INT, p.VALOR) END), 0) AS VENCIDA_DIAS,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_A_PARTIR_DE' THEN TRY_CONVERT(DATE, p.VALOR, 23) END), CAST('19000101' AS DATE)) AS A_PARTIR_DE,
               CAST(SYSDATETIME() AS DATE) AS HOJE
        FROM SIS.Parametro p WITH (NOLOCK)
        WHERE p.CHAVE LIKE 'FIN[_]PEND[_]%'
    ),
    lanc AS (
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_PESSOA, l.ID_CENTRO_CUSTO, l.ID_PLANO_CONTA, l.DOCUMENTO, l.VALOR_TOTAL, l.DT_EMISSAO
        FROM FIN.Lancamento l
        WHERE l.ID_LANCAMENTO = @IdLancamento
          AND l.SITUACAO = 'ATIVO'
          AND l.DT_EXCLUSAO IS NULL
    ),
    aberto AS (
        SELECT l.*, c.*
        FROM lanc l
        CROSS JOIN cfg c
        WHERE l.DT_EMISSAO >= c.A_PARTIR_DE
          AND EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
    )
    SELECT a.ID_LANCAMENTO, CAST(NULL AS BIGINT) AS ID_PARCELA, CAST(NULL AS BIGINT) AS ID_LANCAMENTO_PENDENCIA,
           CAST('AUTOMATICA' AS VARCHAR(10)) AS ORIGEM, CAST('SEM_CENTRO' AS VARCHAR(20)) AS CODIGO,
           CAST(N'Sem centro de custo' AS NVARCHAR(400)) AS DESCRICAO,
           CAST(N'Informe o centro de custo (obra) na ficha do lançamento.' AS NVARCHAR(400)) AS ORIENTACAO,
           CAST(0 AS BIT) AS BLOQUEIA_BAIXA, CAST(0 AS BIT) AS ATRASADA,
           CAST(NULL AS INT) AS ID_PENDENCIA_TIPO, CAST(NULL AS INT) AS ID_USUARIO_RESPONSAVEL, CAST(NULL AS DATE) AS DT_PREVISAO
    FROM aberto a
    WHERE a.SEM_CENTRO = 1 AND a.ID_CENTRO_CUSTO IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_PLANO', N'Sem conta do plano de contas',
           N'Informe a conta do plano de contas na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.SEM_PLANO = 1 AND a.ID_PLANO_CONTA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_DOCUMENTO', N'Sem número de documento',
           N'Informe o número do documento (nota fiscal, boleto, contrato) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.DOCUMENTO = N'' AND (a.SEM_DOCUMENTO = 'A' OR a.SEM_DOCUMENTO = a.TIPO)

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_ANEXO',
           N'Sem anexo (valor acima de ' + SIS.fn_SIS_Formatar_Moeda(a.ANEXO_VALOR) + N')',
           N'Anexe a nota fiscal, o boleto ou o contrato na aba Anexos.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'P' AND a.ANEXO_VALOR > 0 AND a.VALOR_TOTAL > a.ANEXO_VALOR
      AND NOT EXISTS (SELECT 1 FROM SIS.Anexo x
                      WHERE x.TABELA_REFERENCIA = N'FIN.Lancamento' AND x.ID_REFERENCIA = a.ID_LANCAMENTO AND x.SITUACAO = 'ATIVO')

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO',
           N'Parceiro não apto para cobrança: ' + ISNULL(f.PENDENCIA, N''),
           N'Complete o cadastro do parceiro (Cadastros › Parceiros, filtro "Pendências de cadastro").', 0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) c.APTO, c.PENDENCIA FROM CAD.fn_CAD_Pessoa_Pendencia_Cobranca(a.ID_PESSOA) c) f   -- TOP: busca só o parceiro do lançamento
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND f.APTO = 0

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO', N'Sem parceiro para a cobrança',
           N'Informe o parceiro (cliente) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND a.ID_PESSOA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, v.ID_PARCELA, NULL, 'AUTOMATICA', 'VENCIDA',
           CASE WHEN v.QTD = 1 THEN N'Parcela vencida há mais de ' ELSE CONVERT(NVARCHAR(10), v.QTD) + N' parcelas vencidas há mais de ' END
             + CONVERT(NVARCHAR(10), a.VENCIDA_DIAS) + N' dias (desde ' + CONVERT(NVARCHAR(10), v.DT_VENCIMENTO, 103) + N')',
           CASE a.TIPO WHEN 'P' THEN N'Pague, renegocie ou corrija o vencimento.' ELSE N'Cobre o cliente, renegocie ou corrija o vencimento.' END,
           0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) p.ID_PARCELA, p.DT_VENCIMENTO, COUNT(*) OVER () AS QTD
                 FROM FIN.Parcela p
                 WHERE p.ID_LANCAMENTO = a.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
                   AND p.DT_VENCIMENTO < DATEADD(DAY, -a.VENCIDA_DIAS, a.HOJE)
                 ORDER BY p.DT_VENCIMENTO, p.NUMERO) v
    WHERE a.VENCIDA_DIAS > 0

    UNION ALL
    SELECT lp.ID_LANCAMENTO, lp.ID_PARCELA, lp.ID_LANCAMENTO_PENDENCIA, 'MANUAL', t.CODIGO,
           t.DESCRICAO + CASE WHEN lp.OBSERVACAO <> N'' THEN N': ' + LEFT(lp.OBSERVACAO, 300) ELSE N'' END,
           t.ORIENTACAO, t.BLOQUEIA_BAIXA,
           CASE WHEN lp.DT_PREVISAO < c.HOJE THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
           lp.ID_PENDENCIA_TIPO, lp.ID_USUARIO_RESPONSAVEL, lp.DT_PREVISAO
    FROM lanc l
    CROSS JOIN cfg c
    INNER JOIN FIN.Lancamento_Pendencia lp ON lp.ID_LANCAMENTO = l.ID_LANCAMENTO AND lp.SITUACAO = 'ABERTA' AND lp.ATIVO = 1
    INNER JOIN FIN.Pendencia_Tipo t ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Pendencia_Bloqueia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Pendencia_Bloqueia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - a baixa pode ser feita? Devolve sempre 1 linha:
                BLOQUEIA (1 = há pendência manual aberta de tipo que bloqueia
                a baixa) e MOTIVO (as pendências, separadas por "; ").
                Vale a pendência do lançamento inteiro (ID_PARCELA vazio) ou
                da parcela informada. Com @IdParcela NULL: qualquer pendência
                que bloqueia o lançamento. As automáticas nunca bloqueiam.
                Usada pela baixa (04g) e pela ficha (aviso).

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- SELECT * FROM FIN.fn_FIN_Pendencia_Bloqueia(123, NULL);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Pendencia_Bloqueia] (@IdLancamento BIGINT, @IdParcela BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN COUNT(*) > 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS BLOQUEIA,
           CAST(ISNULL(STRING_AGG(CONVERT(NVARCHAR(MAX), t.DESCRICAO + CASE WHEN lp.OBSERVACAO <> N'' THEN N' (' + LEFT(lp.OBSERVACAO, 100) + N')' ELSE N'' END), N'; '), N'') AS NVARCHAR(1000)) AS MOTIVO
    FROM FIN.Lancamento_Pendencia lp
    INNER JOIN FIN.Pendencia_Tipo t ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO AND t.BLOQUEIA_BAIXA = 1
    WHERE lp.ID_LANCAMENTO = @IdLancamento
      AND lp.SITUACAO = 'ABERTA'
      AND lp.ATIVO = 1
      AND (@IdParcela IS NULL OR lp.ID_PARCELA IS NULL OR lp.ID_PARCELA = @IdParcela)
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Pendencia_Tipo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Tipo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - tipos de pendência (tela Financeiro › Tipos de
                pendência e escolha do tipo na ficha do lançamento).
                @Tipo P/R: só os tipos que valem para contas a pagar ou a
                receber (APLICA_A = @Tipo ou A). Não lista o que está na
                lixeira. QTD_ABERTAS: pendências abertas do tipo.
                Permissão: VER em FIN_PENDENCIA_TIPO, FIN_PAGAR ou FIN_RECEBER.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Tipo_Listar @IdUsuario = 2;
    -- EXEC FIN.FIN_Pendencia_Tipo_Listar @IdUsuario = 2, @Tipo = 'R', @SomenteAtivos = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Tipo_Listar]
    @IdUsuario      INT,
    @Busca          NVARCHAR(60) = NULL,
    @SomenteAtivos  BIT          = 0,
    @Tipo           CHAR(1)      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_PENDENCIA_TIPO;
        RETURN;
    END;

    SET @Busca = NULLIF(LTRIM(RTRIM(ISNULL(@Busca, N''))), N'');
    SET @Tipo  = NULLIF(UPPER(ISNULL(@Tipo, '')), '');

    SELECT t.ID_PENDENCIA_TIPO, t.CODIGO, t.DESCRICAO, t.ORIENTACAO, t.APLICA_A, t.BLOQUEIA_BAIXA, t.SISTEMA, t.ORDEM, t.ATIVO,
           ISNULL(q.QTD, 0) AS QTD_ABERTAS
    FROM FIN.Pendencia_Tipo t WITH (NOLOCK)
    OUTER APPLY (SELECT COUNT(*) AS QTD
                 FROM FIN.Lancamento_Pendencia lp WITH (NOLOCK)
                 WHERE lp.ID_PENDENCIA_TIPO = t.ID_PENDENCIA_TIPO AND lp.SITUACAO = 'ABERTA' AND lp.ATIVO = 1) q
    WHERE t.DT_EXCLUSAO IS NULL
      AND (@SomenteAtivos = 0 OR t.ATIVO = 1)
      AND (@Tipo IS NULL OR t.APLICA_A IN ('A', @Tipo))
      AND (@Busca IS NULL OR t.DESCRICAO LIKE N'%' + @Busca + N'%' OR t.CODIGO LIKE @Busca + '%')
    ORDER BY t.ORDEM, t.DESCRICAO;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Pendencia_Tipo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Tipo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - inclui ou altera um tipo de pendência (@IdPendenciaTipo
                NULL = novo). Tipo do sistema (MIGRACAO): código não muda e
                não pode ser desativado; descrição, orientação, onde vale e o
                bloqueio da baixa podem. Desativar: o tipo some da escolha,
                as pendências já lançadas continuam valendo.
                Permissão: INCLUIR / ALTERAR em FIN_PENDENCIA_TIPO e DESATIVAR
                para mudar o ativo. Excluir = lixeira (SIS_Lixeira_Excluir).
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = 2, @Codigo = 'TESTE', @Descricao = N'Teste', @AplicaA = 'A', @BloqueiaBaixa = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Tipo_Gravar]
    @IdUsuario        INT,
    @IdPendenciaTipo  INT            = NULL,
    @Codigo           VARCHAR(20),
    @Descricao        NVARCHAR(60),
    @Orientacao       NVARCHAR(400)  = NULL,
    @AplicaA          CHAR(1)        = 'A',
    @BloqueiaBaixa    BIT            = 0,
    @Ordem            INT            = NULL,
    @Ativo            BIT            = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Pendencia_Tipo_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @Sistema     BIT           = 0;
    DECLARE @CodigoAtual VARCHAR(20);
    DECLARE @AtivoAtual  BIT;
    DECLARE @Abertas     INT           = 0;

    BEGIN TRY
        SET @Codigo        = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao     = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Orientacao    = LTRIM(RTRIM(ISNULL(@Orientacao, N'')));
        SET @AplicaA       = UPPER(ISNULL(@AplicaA, 'A'));
        SET @BloqueiaBaixa = ISNULL(@BloqueiaBaixa, 0);
        SET @Ativo         = ISNULL(@Ativo, 1);

        SELECT @Sistema = t.SISTEMA, @CodigoAtual = t.CODIGO, @AtivoAtual = t.ATIVO
        FROM FIN.Pendencia_Tipo t WHERE t.ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', CASE WHEN @IdPendenciaTipo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar tipos de pendência.';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND @CodigoAtual IS NULL
            SET @Recusa = N'Tipo de pendência não encontrado.';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'FIN.Pendencia_Tipo', @IdPendenciaTipo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Codigo <> @CodigoAtual
            SET @Recusa = N'O código de um tipo do sistema não pode ser mudado.';
        IF @Recusa = N'' AND @Sistema = 1 AND @Ativo = 0
            SET @Recusa = N'Um tipo do sistema não pode ser desativado.';
        IF @Recusa = N'' AND (@Codigo = '' OR @Codigo LIKE '%[^A-Z0-9_]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números e "_" (ex.: AGUARDA_MEDICAO).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND @AplicaA NOT IN ('P', 'R', 'A')
            SET @Recusa = N'Escolha onde o tipo vale: contas a pagar, a receber ou ambos.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo t WHERE t.CODIGO = @Codigo AND t.ID_PENDENCIA_TIPO <> ISNULL(@IdPendenciaTipo, 0))
            SET @Recusa = N'Já existe um tipo de pendência com este código (confira também a lixeira).';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND @Ativo <> @AtivoAtual
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar tipos de pendência.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPendenciaTipo AS ID;
            RETURN;
        END;

        IF @IdPendenciaTipo IS NOT NULL AND @Ativo = 0 AND @AtivoAtual = 1
            SELECT @Abertas = COUNT(*) FROM FIN.Lancamento_Pendencia x
            WHERE x.ID_PENDENCIA_TIPO = @IdPendenciaTipo AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdPendenciaTipo IS NULL
        BEGIN
            INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Descricao, @Orientacao, @AplicaA, @BloqueiaBaixa, 0, ISNULL(@Ordem, 100), @Ativo, ISNULL(@Usuario, N''));
            SET @IdPendenciaTipo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE FIN.Pendencia_Tipo
               SET CODIGO = @Codigo, DESCRICAO = @Descricao, ORIENTACAO = @Orientacao, APLICA_A = @AplicaA,
                   BLOQUEIA_BAIXA = @BloqueiaBaixa, ORDEM = ISNULL(@Ordem, ORDEM), ATIVO = @Ativo,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Tipo de pendência gravado.'
                    + CASE WHEN @Abertas > 0 THEN N' Atenção: ' + CONVERT(NVARCHAR(10), @Abertas)
                                + N' pendência(s) abertas continuam com este tipo; ele só não aparece mais para novas pendências.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdPendenciaTipo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o tipo de pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPendenciaTipo AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Pendencia_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - quadro de pendências da ficha do lançamento: as
                automáticas (calculadas na hora, FIN.fn_FIN_Lancamento_Pendencias)
                e as manuais ativas (abertas e, com @IncluirResolvidas = 1,
                também as resolvidas). Ordem: manuais abertas (por
                previsão), automáticas e, por último, as resolvidas.
                PODE_ALTERAR = 1 na manual aberta quando o usuário tem a ação
                PENDENCIA; PODE_REABRIR na resolvida.
                Permissão: VER em FIN_PAGAR / FIN_RECEBER (conforme o tipo).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Listar @IdUsuario = 2, @IdLancamento = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Listar]
    @IdUsuario          INT,
    @IdLancamento       BIGINT,
    @IncluirResolvidas  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Tipo  CHAR(1);
    DECLARE @Item  VARCHAR(40);
    DECLARE @Pode  BIT;

    SELECT @Tipo = l.TIPO FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;
    SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;

    IF @Tipo IS NULL OR SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
        THROW 50001, N'Você não tem permissão para ver este lançamento.', 1;

    SET @Pode = CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'PENDENCIA') = 1
                      AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 0 THEN 1 ELSE 0 END;

    SELECT x.ID_LANCAMENTO_PENDENCIA, x.ORIGEM, x.CODIGO, x.DESCRICAO, x.ORIENTACAO, x.SITUACAO, x.BLOQUEIA_BAIXA, x.ATRASADA,
           x.ID_PENDENCIA_TIPO, x.ID_PARCELA, x.PARCELA, x.OBSERVACAO, x.ID_USUARIO_RESPONSAVEL, x.RESPONSAVEL, x.DT_PREVISAO,
           x.DT_RESOLUCAO, x.USUARIO_RESOLUCAO, x.RESOLUCAO, x.DT_CRIACAO, x.USUARIO_CRIACAO,
           CAST(CASE WHEN x.ORIGEM = 'MANUAL' AND x.SITUACAO = 'ABERTA' THEN @Pode ELSE 0 END AS BIT) AS PODE_ALTERAR,
           CAST(CASE WHEN x.ORIGEM = 'MANUAL' AND x.SITUACAO = 'RESOLVIDA' THEN @Pode ELSE 0 END AS BIT) AS PODE_REABRIR
    FROM (
        SELECT CAST(NULL AS BIGINT) AS ID_LANCAMENTO_PENDENCIA, f.ORIGEM, f.CODIGO, f.DESCRICAO, f.ORIENTACAO,
               CAST('ABERTA' AS VARCHAR(10)) AS SITUACAO, f.BLOQUEIA_BAIXA, f.ATRASADA, f.ID_PENDENCIA_TIPO,
               f.ID_PARCELA, ISNULL(CONVERT(NVARCHAR(5), p.NUMERO) + N'/' + CONVERT(NVARCHAR(5), p.QTD_PARCELAS), N'') AS PARCELA,
               CAST(N'' AS NVARCHAR(1000)) AS OBSERVACAO, CAST(NULL AS INT) AS ID_USUARIO_RESPONSAVEL, CAST(N'' AS NVARCHAR(100)) AS RESPONSAVEL,
               CAST(NULL AS DATE) AS DT_PREVISAO, CAST(NULL AS DATETIME2(0)) AS DT_RESOLUCAO, CAST(N'' AS NVARCHAR(100)) AS USUARIO_RESOLUCAO,
               CAST(N'' AS NVARCHAR(1000)) AS RESOLUCAO, CAST(NULL AS DATETIME2(0)) AS DT_CRIACAO, CAST(N'' AS NVARCHAR(100)) AS USUARIO_CRIACAO,
               1 AS ORDEM_GRUPO
        FROM FIN.fn_FIN_Lancamento_Pendencias(@IdLancamento) f
        LEFT JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = f.ID_PARCELA
        WHERE f.ORIGEM = 'AUTOMATICA'

        UNION ALL
        SELECT lp.ID_LANCAMENTO_PENDENCIA, CAST('MANUAL' AS VARCHAR(10)), t.CODIGO, t.DESCRICAO, t.ORIENTACAO,
               lp.SITUACAO, t.BLOQUEIA_BAIXA,
               CAST(CASE WHEN lp.SITUACAO = 'ABERTA' AND lp.DT_PREVISAO < CAST(SYSDATETIME() AS DATE) THEN 1 ELSE 0 END AS BIT),
               lp.ID_PENDENCIA_TIPO, lp.ID_PARCELA,
               ISNULL(CONVERT(NVARCHAR(5), p.NUMERO) + N'/' + CONVERT(NVARCHAR(5), p.QTD_PARCELAS), N''),
               lp.OBSERVACAO, lp.ID_USUARIO_RESPONSAVEL, ISNULL(u.NOME, N''), lp.DT_PREVISAO,
               lp.DT_RESOLUCAO, ISNULL(lp.USUARIO_RESOLUCAO, N''), lp.RESOLUCAO, lp.DT_CRIACAO, lp.USUARIO_CRIACAO,
               CASE WHEN lp.SITUACAO = 'ABERTA' THEN 0 ELSE 2 END
        FROM FIN.Lancamento_Pendencia lp WITH (NOLOCK)
        INNER JOIN FIN.Pendencia_Tipo t WITH (NOLOCK) ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO
        LEFT JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = lp.ID_PARCELA
        LEFT JOIN SIS.Usuario u WITH (NOLOCK) ON u.ID_USUARIO = lp.ID_USUARIO_RESPONSAVEL
        WHERE lp.ID_LANCAMENTO = @IdLancamento
          AND lp.ATIVO = 1
          AND (lp.SITUACAO = 'ABERTA' OR ISNULL(@IncluirResolvidas, 1) = 1)
    ) x
    ORDER BY x.ORDEM_GRUPO, CASE WHEN x.DT_PREVISAO IS NULL THEN 1 ELSE 0 END, x.DT_PREVISAO, x.DT_RESOLUCAO DESC, x.CODIGO;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Pendencia_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - inclui (@IdLancamentoPendencia NULL) ou altera uma
                pendência manual do lançamento: tipo, parcela (opcional),
                observação, responsável e previsão. @Ativo = 0: desativa a
                pendência lançada por engano (não conta mais em lugar
                nenhum; o histórico guarda).
                Regras: lançamento ativo e fora da lixeira; tipo ativo e que
                vale para o tipo do lançamento (a pagar / a receber); parcela
                do próprio lançamento; responsável = usuário ativo; uma só
                pendência aberta do mesmo tipo por lançamento e parcela;
                pendência resolvida não é alterada (reabrir antes).
                Permissão: PENDENCIA em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = 2, @IdLancamento = 1, @IdPendenciaTipo = 1, @Observacao = N'NF 123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Gravar]
    @IdUsuario              INT,
    @IdLancamentoPendencia  BIGINT          = NULL,
    @IdLancamento           BIGINT,
    @IdParcela              BIGINT          = NULL,
    @IdPendenciaTipo        INT,
    @Observacao             NVARCHAR(1000)  = NULL,
    @IdUsuarioResponsavel   INT             = NULL,
    @DtPrevisao             DATE            = NULL,
    @Ativo                  BIT             = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Pendencia_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @Usuario       NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @TipoLanc      CHAR(1);
    DECLARE @SituacaoLanc  VARCHAR(10);
    DECLARE @AplicaA       CHAR(1);
    DECLARE @TipoAtivo     BIT;
    DECLARE @TipoAtual     INT;
    DECLARE @LancAtual     BIGINT;
    DECLARE @SituacaoAtual VARCHAR(10);
    DECLARE @AtivoAtual    BIT;
    DECLARE @Linhas        INT;

    BEGIN TRY
        SET @Observacao = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Ativo      = ISNULL(@Ativo, 1);
        IF @IdUsuarioResponsavel = 0 SET @IdUsuarioResponsavel = NULL;
        IF @IdParcela = 0 SET @IdParcela = NULL;

        IF @IdLancamentoPendencia IS NOT NULL
            SELECT @LancAtual = lp.ID_LANCAMENTO, @SituacaoAtual = lp.SITUACAO, @AtivoAtual = lp.ATIVO, @TipoAtual = lp.ID_PENDENCIA_TIPO
            FROM FIN.Lancamento_Pendencia lp WHERE lp.ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia;

        IF @IdLancamentoPendencia IS NOT NULL AND @IdLancamento IS NULL
            SET @IdLancamento = @LancAtual;

        SELECT @TipoLanc = l.TIPO, @SituacaoLanc = l.SITUACAO FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;
        SELECT @AplicaA = t.APLICA_A, @TipoAtivo = CASE WHEN t.ATIVO = 1 AND t.DT_EXCLUSAO IS NULL THEN 1 ELSE 0 END
        FROM FIN.Pendencia_Tipo t WHERE t.ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        IF @TipoLanc IS NULL
            SET @Recusa = N'Lançamento não encontrado.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @TipoLanc WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'PENDENCIA') = 0
            SET @Recusa = N'Você não tem permissão para lançar ou alterar pendências.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND (@LancAtual IS NULL OR @LancAtual <> @IdLancamento)
            SET @Recusa = N'Pendência não encontrada neste lançamento.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NULL AND @SituacaoLanc = 'CANCELADO'
            SET @Recusa = N'O lançamento está cancelado.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND @AtivoAtual = 0
            SET @Recusa = N'Esta pendência foi desativada.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND @SituacaoAtual = 'RESOLVIDA'
            SET @Recusa = N'A pendência já está resolvida: reabra-a antes de alterar.';

        IF @Recusa = N'' AND @Ativo = 1
        BEGIN
            IF @AplicaA IS NULL
                SET @Recusa = N'Escolha o tipo da pendência.';
            IF @Recusa = N'' AND @TipoAtivo = 0 AND ISNULL(@TipoAtual, 0) <> @IdPendenciaTipo
                SET @Recusa = N'Este tipo de pendência está desativado.';
            IF @Recusa = N'' AND @AplicaA NOT IN ('A', @TipoLanc)
                SET @Recusa = CASE @TipoLanc WHEN 'P' THEN N'Este tipo de pendência vale só para contas a receber.'
                                             ELSE N'Este tipo de pendência vale só para contas a pagar.' END;
            IF @Recusa = N'' AND @IdParcela IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParcela AND p.ID_LANCAMENTO = @IdLancamento)
                SET @Recusa = N'A parcela escolhida não é deste lançamento.';
            IF @Recusa = N'' AND @IdUsuarioResponsavel IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuarioResponsavel AND u.ATIVO = 1)
                SET @Recusa = N'O responsável escolhido não é um usuário ativo.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Lancamento_Pendencia x
                                         WHERE x.ID_LANCAMENTO = @IdLancamento AND x.ID_PENDENCIA_TIPO = @IdPendenciaTipo
                                           AND ISNULL(x.ID_PARCELA, 0) = ISNULL(@IdParcela, 0)
                                           AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1
                                           AND x.ID_LANCAMENTO_PENDENCIA <> ISNULL(@IdLancamentoPendencia, 0))
                SET @Recusa = N'Já existe uma pendência aberta deste tipo neste lançamento' + CASE WHEN @IdParcela IS NULL THEN N'.' ELSE N' e parcela.' END;
        END;

        IF @Recusa = N'' AND @Ativo = 0 AND @IdLancamentoPendencia IS NULL
            SET @Recusa = N'Pendência não encontrada.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdLancamentoPendencia IS NULL
        BEGIN
            INSERT INTO FIN.Lancamento_Pendencia (ID_LANCAMENTO, ID_PARCELA, ID_PENDENCIA_TIPO, OBSERVACAO, ID_USUARIO_RESPONSAVEL, DT_PREVISAO,
                                                  SITUACAO, ORIGEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@IdLancamento, @IdParcela, @IdPendenciaTipo, @Observacao, @IdUsuarioResponsavel, @DtPrevisao,
                    'ABERTA', 'MANUAL', 1, ISNULL(@Usuario, N''));
            SET @IdLancamentoPendencia = SCOPE_IDENTITY();
            SET @Linhas = 1;
        END
        ELSE IF @Ativo = 0
        BEGIN
            UPDATE FIN.Lancamento_Pendencia
               SET ATIVO = 0, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND ATIVO = 1 AND SITUACAO = 'ABERTA';
            SET @Linhas = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            UPDATE FIN.Lancamento_Pendencia
               SET ID_PARCELA = @IdParcela, ID_PENDENCIA_TIPO = @IdPendenciaTipo, OBSERVACAO = @Observacao,
                   ID_USUARIO_RESPONSAVEL = @IdUsuarioResponsavel, DT_PREVISAO = @DtPrevisao,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND ATIVO = 1 AND SITUACAO = 'ABERTA';
            SET @Linhas = @@ROWCOUNT;
        END;

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas <> 1 THEN N'A pendência foi alterada por outra pessoa. Abra a ficha de novo.'
                         WHEN @Ativo = 0 THEN N'Pendência desativada.'
                         ELSE N'Pendência gravada.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamentoPendencia AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Pendencia_Resolver.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Resolver]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - resolve uma pendência manual aberta, com a nota da
                resolução (obrigatória), quem e quando. Para voltar atrás:
                FIN_Lancamento_Pendencia_Reabrir.
                Permissão: PENDENCIA em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Resolver @IdUsuario = 2, @IdLancamentoPendencia = 1, @Resolucao = N'NF anexada';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Resolver]
    @IdUsuario              INT,
    @IdLancamentoPendencia  BIGINT,
    @Resolucao              NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Pendencia_Resolver]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @TipoLanc   CHAR(1);
    DECLARE @IdLanc     BIGINT;
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Ativo      BIT;
    DECLARE @Linhas     INT;

    BEGIN TRY
        SET @Resolucao = LTRIM(RTRIM(ISNULL(@Resolucao, N'')));

        SELECT @IdLanc = lp.ID_LANCAMENTO, @Situacao = lp.SITUACAO, @Ativo = lp.ATIVO, @TipoLanc = l.TIPO
        FROM FIN.Lancamento_Pendencia lp
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = lp.ID_LANCAMENTO
        WHERE lp.ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia;

        IF @IdLanc IS NULL OR @Ativo = 0
            SET @Recusa = N'Pendência não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @TipoLanc WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'PENDENCIA') = 0
            SET @Recusa = N'Você não tem permissão para resolver pendências.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLanc) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @Situacao = 'RESOLVIDA'
            SET @Recusa = N'A pendência já está resolvida.';
        IF @Recusa = N'' AND LEN(@Resolucao) < 3
            SET @Recusa = N'Informe como a pendência foi resolvida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE FIN.Lancamento_Pendencia
           SET SITUACAO = 'RESOLVIDA', DT_RESOLUCAO = SYSDATETIME(), USUARIO_RESOLUCAO = @Usuario, RESOLUCAO = @Resolucao,
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND SITUACAO = 'ABERTA' AND ATIVO = 1;
        SET @Linhas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pendência resolvida.' ELSE N'A pendência foi alterada por outra pessoa. Abra a ficha de novo.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamentoPendencia AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível resolver a pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Pendencia_Reabrir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Reabrir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - reabre uma pendência manual resolvida (volta a ABERTA e
                limpa a resolução; o histórico do lançamento guarda quem
                resolveu, quando e a nota). Lançamento cancelado ou na
                lixeira não reabre.
                Permissão: PENDENCIA em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Reabrir @IdUsuario = 2, @IdLancamentoPendencia = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Reabrir]
    @IdUsuario              INT,
    @IdLancamentoPendencia  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Pendencia_Reabrir]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @TipoLanc     CHAR(1);
    DECLARE @SituacaoLanc VARCHAR(10);
    DECLARE @IdLanc       BIGINT;
    DECLARE @IdTipo       INT;
    DECLARE @IdParcela    BIGINT;
    DECLARE @Situacao     VARCHAR(10);
    DECLARE @Ativo        BIT;
    DECLARE @Linhas       INT;

    BEGIN TRY
        SELECT @IdLanc = lp.ID_LANCAMENTO, @Situacao = lp.SITUACAO, @Ativo = lp.ATIVO, @IdTipo = lp.ID_PENDENCIA_TIPO,
               @IdParcela = lp.ID_PARCELA, @TipoLanc = l.TIPO, @SituacaoLanc = l.SITUACAO
        FROM FIN.Lancamento_Pendencia lp
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = lp.ID_LANCAMENTO
        WHERE lp.ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia;

        IF @IdLanc IS NULL OR @Ativo = 0
            SET @Recusa = N'Pendência não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @TipoLanc WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'PENDENCIA') = 0
            SET @Recusa = N'Você não tem permissão para reabrir pendências.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLanc) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @SituacaoLanc = 'CANCELADO'
            SET @Recusa = N'O lançamento está cancelado.';
        IF @Recusa = N'' AND @Situacao = 'ABERTA'
            SET @Recusa = N'A pendência já está aberta.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Lancamento_Pendencia x
                                     WHERE x.ID_LANCAMENTO = @IdLanc AND x.ID_PENDENCIA_TIPO = @IdTipo
                                       AND ISNULL(x.ID_PARCELA, 0) = ISNULL(@IdParcela, 0)
                                       AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1)
            SET @Recusa = N'Já existe outra pendência aberta deste tipo neste lançamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE FIN.Lancamento_Pendencia
           SET SITUACAO = 'ABERTA', DT_RESOLUCAO = NULL, USUARIO_RESOLUCAO = NULL, RESOLUCAO = N'',
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND SITUACAO = 'RESOLVIDA' AND ATIVO = 1;
        SET @Linhas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pendência reaberta.' ELSE N'A pendência foi alterada por outra pessoa. Abra a ficha de novo.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamentoPendencia AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível reabrir a pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Pendencia_Responsavel_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Responsavel_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - usuários que podem ser responsáveis por uma pendência
                (escolha na ficha do lançamento): ativos e não internos (o
                usuário de teste e o de consulta do Claude ficam de fora).
                Só ID, nome e login: nada de e-mail, perfil ou senha.
                Permissão: VER em FIN_PAGAR ou FIN_RECEBER.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Responsavel_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Responsavel_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_USUARIO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST('' AS VARCHAR(40)) AS LOGIN;
        RETURN;
    END;

    SELECT u.ID_USUARIO, u.NOME, u.LOGIN
    FROM SIS.Usuario u WITH (NOLOCK)
    WHERE u.ATIVO = 1
      AND u.INTERNO = 0
    ORDER BY u.NOME;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lista das telas Contas a pagar (@Tipo P) e Contas a receber
                (@Tipo R) e da aba Movimentação do Parceiro (@Tipo NULL com
                @IdPessoa: os dois tipos que o usuário pode ver).
                @Visao PARCELA (padrão): uma linha por vencimento.
                @Visao LANCAMENTO: uma linha por lançamento (vencimento = o
                primeiro das parcelas filtradas; valores = todas as parcelas).
                @Situacao: EM_ABERTO (aberta + parcial), ABERTA, PARCIAL, PAGA,
                CANCELADA, VENCIDA (em aberto e vencida), HOJE (em aberto
                vencendo hoje), A_VENCER (em aberto, de amanhã até
                FIN_LISTA_DIAS_A_VENCER dias) ou vazio (todas; sem as
                canceladas quando FIN_LISTA_OCULTA_CANCELADAS = S).
                @CampoData escolhe a data do período (@VencDe/@VencAte):
                VENCIMENTO (padrão), EMISSAO ou COMPETENCIA (mês).
                Filtros opcionais por período, empresa, centro,
                parceiro, conta do plano, lote, documento, texto e valor.
                Paginação (@Pagina, @PorPagina; padrão FIN_LISTA_POR_PAGINA:
                a página é escolhida antes de buscar os detalhes) e
                totais do filtro inteiro em cada linha (TOTAL_*). Não lista o
                que está na lixeira. Permissão: VER em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (25/11/2026) - Etapa 04f2a: situações HOJE e A_VENCER, período por
                        emissão ou competência (@CampoData) e canceladas fora
                        de "todas" pelo parâmetro FIN_LISTA_OCULTA_CANCELADAS.
    v1.2 (26/11/2026) - Etapa 04f2c (P27): filtro de pendências (@Pendencia
                        COM, AUTOMATICA, MANUAL, MINHAS, ATRASADA ou BLOQUEIA;
                        @PendenciaCodigo = tipo manual ou regra automática) e
                        colunas QTD_PENDENCIAS, PENDENCIAS (texto), PENDENCIA_
                        BLOQUEIA e PENDENCIA_ATRASADA, calculadas só para as
                        linhas da página (FIN.fn_FIN_Lancamento_Pendencias).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'R', @Situacao = 'EM_ABERTO';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'P', @Visao = 'LANCAMENTO', @Texto = N'cimento';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'R', @Situacao = 'A_VENCER', @CampoData = 'EMISSAO', @VencDe = '2026-01-01';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'P', @Pendencia = 'COM', @Visao = 'LANCAMENTO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Listar]
    @IdUsuario      INT,
    @Tipo           CHAR(1)        = NULL,
    @Visao          VARCHAR(12)    = 'PARCELA',
    @Situacao       VARCHAR(12)    = NULL,
    @VencDe         DATE           = NULL,
    @VencAte        DATE           = NULL,
    @CampoData      VARCHAR(12)    = 'VENCIMENTO',
    @IdEmpresa      INT            = NULL,
    @IdCentroCusto  INT            = NULL,
    @IdPessoa       INT            = NULL,
    @IdPlanoConta   INT            = NULL,
    @IdLote         BIGINT         = NULL,
    @IdLancamento   BIGINT         = NULL,
    @Documento      NVARCHAR(40)   = NULL,
    @Texto          NVARCHAR(100)  = NULL,
    @ValorDe        DECIMAL(18,2)  = NULL,
    @ValorAte       DECIMAL(18,2)  = NULL,
    @Ordem          VARCHAR(12)    = 'VENCIMENTO',
    @Pagina         INT            = 1,
    @PorPagina      INT            = NULL,
    @Pendencia      VARCHAR(12)    = NULL,
    @PendenciaCodigo VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @VeP        BIT;
    DECLARE @VeR        BIT;
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Termo      NVARCHAR(102);
    DECLARE @Digitos    VARCHAR(100);
    DECLARE @Linhas     INT = 0;
    DECLARE @TotValor   DECIMAL(18,2) = 0;
    DECLARE @TotBaixado DECIMAL(18,2) = 0;
    DECLARE @TotSaldo   DECIMAL(18,2) = 0;
    DECLARE @DiasAVencer INT;
    DECLARE @OcultaCanc  BIT;

    DROP TABLE IF EXISTS #F;
    DROP TABLE IF EXISTS #G;
    DROP TABLE IF EXISTS #T;
    DROP TABLE IF EXISTS #Pg;
    DROP TABLE IF EXISTS #PendL;

    BEGIN TRY
        SET @Tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Tipo, '')))), '');
        SET @VeP  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VeR  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        IF (@Tipo = 'P' AND @VeP = 0) OR (@Tipo = 'R' AND @VeR = 0) OR (@Tipo IS NULL AND @VeP = 0 AND @VeR = 0)
            THROW 50001, N'Você não tem permissão para ver estes lançamentos.', 1;
        IF @Tipo IS NOT NULL AND @Tipo NOT IN ('P', 'R')
            THROW 50001, N'Tipo inválido.', 1;

        SET @Visao     = CASE WHEN UPPER(ISNULL(@Visao, '')) = 'LANCAMENTO' THEN 'LANCAMENTO' ELSE 'PARCELA' END;
        SET @Situacao  = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Situacao, '')))), '');
        SET @Ordem     = UPPER(ISNULL(@Ordem, 'VENCIMENTO'));
        SET @CampoData = CASE UPPER(ISNULL(@CampoData, '')) WHEN 'EMISSAO' THEN 'EMISSAO' WHEN 'COMPETENCIA' THEN 'COMPETENCIA' ELSE 'VENCIMENTO' END;
        SET @DiasAVencer = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_DIAS_A_VENCER'), 7);
        IF @DiasAVencer NOT BETWEEN 1 AND 365 SET @DiasAVencer = 7;
        SET @OcultaCanc  = ISNULL(SIS.fn_SIS_Parametro_SN('FIN_LISTA_OCULTA_CANCELADAS'), 1);
        SET @Pagina    = CASE WHEN ISNULL(@Pagina, 1) < 1 THEN 1 ELSE @Pagina END;
        SET @PorPagina = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @Documento = NULLIF(LTRIM(RTRIM(ISNULL(@Documento, N''))), N'');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Termo     = N'%' + REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Digitos   = NULLIF(CONVERT(VARCHAR(100), CAD.fn_CAD_Somente_Digitos(ISNULL(@Texto, N''))), '');
        SET @Pendencia       = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Pendencia, '')))), '');
        SET @PendenciaCodigo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@PendenciaCodigo, '')))), '');
        IF @PendenciaCodigo IS NOT NULL AND @Pendencia IS NULL SET @Pendencia = 'COM';

        SET @EtapaAtual = 'Filtro';
        SELECT p.ID_PARCELA, p.ID_LANCAMENTO, p.NUMERO, p.DT_VENCIMENTO, p.VALOR, p.VALOR_BAIXADO, p.SALDO, l.DT_EMISSAO,
               ISNULL(pe.NOME, N'') AS PESSOA_NOME
        INTO #F
        FROM FIN.Parcela p WITH (NOLOCK)
        INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        LEFT  JOIN CAD.Pessoa pe    WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        WHERE l.DT_EXCLUSAO IS NULL
          AND ((l.TIPO = 'P' AND @VeP = 1) OR (l.TIPO = 'R' AND @VeR = 1))
          AND (@Tipo IS NULL OR l.TIPO = @Tipo)
          AND ((@Situacao IS NULL AND (@OcultaCanc = 0 OR p.SITUACAO <> 'CANCELADA'))
               OR (@Situacao = 'EM_ABERTO' AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
               OR (@Situacao = 'VENCIDA'   AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje)
               OR (@Situacao = 'HOJE'      AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO = @Hoje)
               OR (@Situacao = 'A_VENCER'  AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= DATEADD(DAY, @DiasAVencer, @Hoje))
               OR p.SITUACAO = @Situacao)
          AND (@VencDe IS NULL
               OR (@CampoData = 'VENCIMENTO'  AND p.DT_VENCIMENTO >= @VencDe)
               OR (@CampoData = 'EMISSAO'     AND l.DT_EMISSAO >= @VencDe)
               OR (@CampoData = 'COMPETENCIA' AND l.DT_COMPETENCIA >= DATEFROMPARTS(YEAR(@VencDe), MONTH(@VencDe), 1)))
          AND (@VencAte IS NULL
               OR (@CampoData = 'VENCIMENTO'  AND p.DT_VENCIMENTO <= @VencAte)
               OR (@CampoData = 'EMISSAO'     AND l.DT_EMISSAO <= @VencAte)
               OR (@CampoData = 'COMPETENCIA' AND l.DT_COMPETENCIA <= @VencAte))
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
          AND (@IdLote        IS NULL OR l.ID_LOTE = @IdLote OR p.ID_LOTE = @IdLote)
          AND (@IdLancamento  IS NULL OR l.ID_LANCAMENTO = @IdLancamento)
          AND (@Documento     IS NULL OR l.DOCUMENTO LIKE @Documento + N'%')
          AND (@ValorDe       IS NULL OR p.VALOR >= @ValorDe)
          AND (@ValorAte      IS NULL OR p.VALOR <= @ValorAte)
          AND (@Texto IS NULL
               OR l.HISTORICO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.DOCUMENTO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.OBSERVACAO COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME      COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
               OR (@Digitos IS NOT NULL AND LEN(@Digitos) >= 5 AND pe.CPF_CNPJ LIKE @Digitos + '%')
               OR CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) = @Texto)
        OPTION (RECOMPILE);

        -- P27: filtro de pendências (calcula só para os lançamentos que já passaram pelo filtro)
        IF @Pendencia IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Pendências';
            SELECT DISTINCT l.ID_LANCAMENTO
            INTO #PendL
            FROM (SELECT DISTINCT ID_LANCAMENTO FROM #F) l
            CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pd
            WHERE (@Pendencia = 'COM'
                   OR (@Pendencia = 'AUTOMATICA' AND pd.ORIGEM = 'AUTOMATICA')
                   OR (@Pendencia = 'MANUAL'     AND pd.ORIGEM = 'MANUAL')
                   OR (@Pendencia = 'MINHAS'     AND pd.ORIGEM = 'MANUAL' AND pd.ID_USUARIO_RESPONSAVEL = @IdUsuario)
                   OR (@Pendencia = 'ATRASADA'   AND pd.ATRASADA = 1)
                   OR (@Pendencia = 'BLOQUEIA'   AND pd.BLOQUEIA_BAIXA = 1))
              AND (@PendenciaCodigo IS NULL OR pd.CODIGO = @PendenciaCodigo)
              -- só os candidatos: em aberto (automáticas) ou com pendência manual aberta
              AND (EXISTS (SELECT 1 FROM FIN.Parcela p2 WITH (NOLOCK) WHERE p2.ID_LANCAMENTO = l.ID_LANCAMENTO AND p2.SITUACAO IN ('ABERTA', 'PARCIAL'))
                   OR EXISTS (SELECT 1 FROM FIN.Lancamento_Pendencia x WITH (NOLOCK) WHERE x.ID_LANCAMENTO = l.ID_LANCAMENTO AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1));

            DELETE f FROM #F f WHERE NOT EXISTS (SELECT 1 FROM #PendL x WHERE x.ID_LANCAMENTO = f.ID_LANCAMENTO);
        END;

        -- linhas da página primeiro (só com o que já está em #F); detalhes depois, só para elas
        SET @EtapaAtual = 'Página';
        CREATE TABLE #Pg (ORDEM INT NOT NULL, ID_LANCAMENTO BIGINT NOT NULL, ID_PARCELA BIGINT NULL, DT_VENCIMENTO DATE NULL,
                          QTD INT NULL, VALOR DECIMAL(18,2) NULL, BAIXADO DECIMAL(18,2) NULL, SALDO DECIMAL(18,2) NULL,
                          EM_ABERTO INT NULL, CANCELADAS INT NULL, PRIMEIRA_VENCIDA DATE NULL);

        IF @Visao = 'PARCELA'
        BEGIN
            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(f.VALOR), 0), @TotBaixado = ISNULL(SUM(f.VALOR_BAIXADO), 0), @TotSaldo = ISNULL(SUM(f.SALDO), 0) FROM #F f;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, ID_PARCELA, DT_VENCIMENTO)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.ID_PARCELA, x.DT_VENCIMENTO
            FROM (SELECT f.ID_LANCAMENTO, f.ID_PARCELA, f.DT_VENCIMENTO, f.VALOR, f.PESSOA_NOME, f.DT_EMISSAO, f.NUMERO
                  FROM #F f
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN f.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN f.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN f.DT_EMISSAO END DESC,
                           f.DT_VENCIMENTO, f.ID_LANCAMENTO, f.NUMERO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END
        ELSE
        BEGIN
            SELECT g.ID_LANCAMENTO, MIN(g.DT_VENCIMENTO) AS DT_VENCIMENTO, MAX(g.PESSOA_NOME) AS PESSOA_NOME, MAX(g.DT_EMISSAO) AS DT_EMISSAO
            INTO #G
            FROM #F g
            GROUP BY g.ID_LANCAMENTO;

            SELECT p.ID_LANCAMENTO, COUNT(*) AS QTD, SUM(p.VALOR) AS VALOR, SUM(p.VALOR_BAIXADO) AS BAIXADO, SUM(p.SALDO) AS SALDO,
                   SUM(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN p.SITUACAO = 'CANCELADA' THEN 1 ELSE 0 END) AS CANCELADAS,
                   MIN(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN p.DT_VENCIMENTO END) AS PRIMEIRA_VENCIDA
            INTO #T
            FROM FIN.Parcela p WITH (NOLOCK)
            INNER JOIN #G g ON g.ID_LANCAMENTO = p.ID_LANCAMENTO
            GROUP BY p.ID_LANCAMENTO;

            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(t.VALOR), 0), @TotBaixado = ISNULL(SUM(t.BAIXADO), 0), @TotSaldo = ISNULL(SUM(t.SALDO), 0) FROM #T t;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, DT_VENCIMENTO, QTD, VALOR, BAIXADO, SALDO, EM_ABERTO, CANCELADAS, PRIMEIRA_VENCIDA)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.DT_VENCIMENTO, x.QTD, x.VALOR, x.BAIXADO, x.SALDO, x.EM_ABERTO, x.CANCELADAS, x.PRIMEIRA_VENCIDA
            FROM (SELECT g.ID_LANCAMENTO, g.DT_VENCIMENTO, t.QTD, t.VALOR, t.BAIXADO, t.SALDO, t.EM_ABERTO, t.CANCELADAS, t.PRIMEIRA_VENCIDA
                  FROM #G g
                  INNER JOIN #T t ON t.ID_LANCAMENTO = g.ID_LANCAMENTO
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN t.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN g.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN g.DT_EMISSAO END DESC,
                           g.DT_VENCIMENTO, g.ID_LANCAMENTO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, pg.ID_PARCELA, l.TIPO,
               CAST(p.NUMERO AS SMALLINT) AS NUMERO,
               CAST(ISNULL(p.QTD_PARCELAS, pg.QTD) AS SMALLINT) AS QTD_PARCELAS,
               pg.DT_VENCIMENTO,
               CAST(ISNULL(p.VALOR, pg.VALOR) AS DECIMAL(18,2)) AS VALOR,
               CAST(ISNULL(p.VALOR_BAIXADO, pg.BAIXADO) AS DECIMAL(18,2)) AS VALOR_BAIXADO,
               CAST(ISNULL(p.SALDO, pg.SALDO) AS DECIMAL(18,2)) AS SALDO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL THEN p.SITUACAO
                         WHEN pg.CANCELADAS = pg.QTD THEN 'CANCELADA'
                         WHEN pg.EM_ABERTO = 0 THEN 'PAGA'
                         WHEN pg.BAIXADO > 0 THEN 'PARCIAL'
                         ELSE 'ABERTA' END AS VARCHAR(10)) AS SITUACAO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN 1
                         WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
               CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN DATEDIFF(DAY, p.DT_VENCIMENTO, @Hoje)
                    WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN DATEDIFF(DAY, pg.PRIMEIRA_VENCIDA, @Hoje) ELSE 0 END AS DIAS_ATRASO,
               l.DT_EMISSAO, l.DT_COMPETENCIA, l.DOCUMENTO, l.HISTORICO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME,
               l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(p.ID_LOTE, l.ID_LOTE) AS ID_LOTE, l.ORIGEM, l.PREVISAO, l.SITUACAO AS LANCAMENTO_SITUACAO,
               @Linhas AS TOTAL_LINHAS, @TotValor AS TOTAL_VALOR, @TotBaixado AS TOTAL_BAIXADO, @TotSaldo AS TOTAL_SALDO,
               ISNULL(pd.QTD, 0) AS QTD_PENDENCIAS, CAST(ISNULL(pd.TEXTO, N'') AS NVARCHAR(1000)) AS PENDENCIAS,
               CAST(ISNULL(pd.BLOQUEIA, 0) AS BIT) AS PENDENCIA_BLOQUEIA, CAST(ISNULL(pd.ATRASADA, 0) AS BIT) AS PENDENCIA_ATRASADA
        FROM #Pg pg
        INNER JOIN FIN.Lancamento l         WITH (NOLOCK) ON l.ID_LANCAMENTO = pg.ID_LANCAMENTO
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN FIN.Parcela p            WITH (NOLOCK) ON p.ID_PARCELA = pg.ID_PARCELA
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        OUTER APPLY (SELECT COUNT(*) AS QTD,
                            STRING_AGG(CONVERT(NVARCHAR(MAX), f.DESCRICAO), N'; ') AS TEXTO,
                            MAX(CAST(f.BLOQUEIA_BAIXA AS INT)) AS BLOQUEIA, MAX(CAST(f.ATRASADA AS INT)) AS ATRASADA
                     FROM FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f) pd
        ORDER BY pg.ORDEM;

        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
        DROP TABLE IF EXISTS #PendL;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
        DROP TABLE IF EXISTS #PendL;
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os lançamentos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Resumo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Contadores do topo das telas Contas a pagar (@Tipo P) e Contas
                a receber (@Tipo R): quantidade e saldo das parcelas em aberto
                vencidas, vencendo hoje, a vencer (de amanhã até
                FIN_LISTA_DIAS_A_VENCER dias) e o total em aberto. Respeita os
                filtros de empresa, centro, parceiro e conta do plano (não os
                de situação e período: cada contador é uma situação). Devolve
                também os parâmetros que a tela usa ao abrir (situação e visão
                iniciais, linhas por página, dias a vencer). Não conta o que
                está na lixeira. Permissão: VER em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).
    v1.1 (26/11/2026) - Etapa 04f2c (P27): QTD_COM_PENDENCIA (lançamentos com
                        alguma pendência aberta, automática ou manual) e
                        QTD_MINHAS_PENDENCIAS (manuais com o usuário como
                        responsável), com os mesmos filtros.

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = 2, @Tipo = 'R';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Resumo]
    @IdUsuario      INT,
    @Tipo           CHAR(1),
    @IdEmpresa      INT = NULL,
    @IdCentroCusto  INT = NULL,
    @IdPessoa       INT = NULL,
    @IdPlanoConta   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Resumo]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje        DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @DiasAVencer INT;
    DECLARE @Limite      DATE;
    DECLARE @PorPagina   INT;
    DECLARE @SitInicial  NVARCHAR(20);
    DECLARE @VisInicial  NVARCHAR(20);
    DECLARE @QtdPend     INT = 0;
    DECLARE @QtdMinhas   INT = 0;

    BEGIN TRY
        SET @Tipo = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        IF @Tipo NOT IN ('P', 'R')
            THROW 50001, N'Tipo inválido.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estes lançamentos.', 1;

        SET @EtapaAtual  = 'Parâmetros';
        SET @DiasAVencer = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_DIAS_A_VENCER'), 7);
        IF @DiasAVencer NOT BETWEEN 1 AND 365 SET @DiasAVencer = 7;
        SET @Limite      = DATEADD(DAY, @DiasAVencer, @Hoje);
        SET @PorPagina   = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100);
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @SitInicial  = UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_LISTA_SITUACAO_INICIAL'), N'EM_ABERTO'));
        IF @SitInicial NOT IN (N'EM_ABERTO', N'VENCIDA', N'HOJE', N'A_VENCER', N'TODAS') SET @SitInicial = N'EM_ABERTO';
        SET @VisInicial  = UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_LISTA_VISAO_INICIAL'), N'PARCELA'));
        IF @VisInicial NOT IN (N'PARCELA', N'LANCAMENTO') SET @VisInicial = N'PARCELA';

        SET @EtapaAtual = 'Pendências';
        SELECT @QtdPend   = COUNT(DISTINCT l.ID_LANCAMENTO),
               @QtdMinhas = COUNT(DISTINCT CASE WHEN pd.ORIGEM = 'MANUAL' AND pd.ID_USUARIO_RESPONSAVEL = @IdUsuario THEN l.ID_LANCAMENTO END)
        FROM FIN.Lancamento l WITH (NOLOCK)
        CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pd
        WHERE l.DT_EXCLUSAO IS NULL
          AND l.TIPO = @Tipo
          AND l.SITUACAO = 'ATIVO'
          AND (EXISTS (SELECT 1 FROM FIN.Parcela p2 WITH (NOLOCK) WHERE p2.ID_LANCAMENTO = l.ID_LANCAMENTO AND p2.SITUACAO IN ('ABERTA', 'PARCIAL'))
               OR EXISTS (SELECT 1 FROM FIN.Lancamento_Pendencia x WITH (NOLOCK) WHERE x.ID_LANCAMENTO = l.ID_LANCAMENTO AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1))
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
        OPTION (RECOMPILE);

        SET @EtapaAtual = 'Consulta';
        SELECT CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END), 0) AS INT)                                        AS QTD_VENCIDAS,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2))                        AS VALOR_VENCIDAS,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO = @Hoje THEN 1 ELSE 0 END), 0) AS INT)                                        AS QTD_HOJE,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO = @Hoje THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2))                        AS VALOR_HOJE,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= @Limite THEN 1 ELSE 0 END), 0) AS INT)         AS QTD_A_VENCER,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= @Limite THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)) AS VALOR_A_VENCER,
               CAST(COUNT(*) AS INT)                                                                                                   AS QTD_EM_ABERTO,
               CAST(ISNULL(SUM(p.SALDO), 0) AS DECIMAL(18,2))                                                                          AS VALOR_EM_ABERTO,
               @DiasAVencer                                                                                                            AS DIAS_A_VENCER,
               @PorPagina                                                                                                              AS POR_PAGINA,
               CAST(@SitInicial AS VARCHAR(12))                                                                                        AS SITUACAO_INICIAL,
               CAST(@VisInicial AS VARCHAR(12))                                                                                        AS VISAO_INICIAL,
               ISNULL(@QtdPend, 0)                                                                                                     AS QTD_COM_PENDENCIA,
               ISNULL(@QtdMinhas, 0)                                                                                                   AS QTD_MINHAS_PENDENCIAS
        FROM FIN.Parcela p WITH (NOLOCK)
        INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.DT_EXCLUSAO IS NULL
          AND l.TIPO = @Tipo
          AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o resumo dos lançamentos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha do lançamento (Contas a pagar / a receber): dados do
                documento com os nomes do que foi escolhido, as parcelas
                (PARCELAS, JSON, com QTD_BAIXAS e TRAVADA), as baixas (BAIXAS,
                JSON, só consulta até a etapa 04g) e os avisos já confirmados
                (AVISOS_CONFIRMADOS, JSON). Situação para a tela: TEM_BAIXA,
                NA_LIXEIRA, MES_FECHADO, PODE_ALTERAR (permissão + situação +
                origem), PODE_CANCELAR e PODE_EXCLUIR.
                Permissão: VER em FIN_PAGAR / FIN_RECEBER (conforme o tipo).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (26/11/2026) - Etapa 04f2c (P27): PENDENCIAS (JSON, as abertas,
                        automáticas e manuais), QTD_PENDENCIAS, PODE_PENDENCIA,
                        BLOQUEIA_BAIXA e MOTIVO_BLOQUEIO (FIN.fn_FIN_Pendencia_Bloqueia).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Obter @IdUsuario = 2, @IdLancamento = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Obter]
    @IdUsuario     INT,
    @IdLancamento  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tipo       CHAR(1);
    DECLARE @Item       VARCHAR(40);
    DECLARE @TemBaixa   BIT = 0;
    DECLARE @NaLixeira  BIT = 0;
    DECLARE @MesFechado BIT = 0;
    DECLARE @Editavel   BIT = 0;

    BEGIN TRY
        SELECT @Tipo = l.TIPO FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;
        IF @Tipo IS NULL
            THROW 50001, N'Lançamento não encontrado.', 1;

        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este lançamento.', 1;

        SET @EtapaAtual = 'Situação';
        IF EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                   WHERE p.ID_LANCAMENTO = @IdLancamento)
            SET @TemBaixa = 1;
        SET @NaLixeira = SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento);
        IF EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (NOLOCK)
                   INNER JOIN FIN.Mes_Fechado m  WITH (NOLOCK) ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
                   INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
                   WHERE l.ID_LANCAMENTO = @IdLancamento)
            SET @MesFechado = 1;
        SELECT @Editavel = CASE WHEN l.SITUACAO = 'ATIVO' AND l.ORIGEM IN ('MANUAL', 'MIGRACAO') AND @NaLixeira = 0 AND @MesFechado = 0 THEN 1 ELSE 0 END
        FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME, ISNULL(pe.CPF_CNPJ, '') AS PESSOA_CPF_CNPJ,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(CONVERT(VARCHAR(15), v.TIPO), '') AS PLANO_TIPO,
               l.ID_HISTORICO_PADRAO, ISNULL(h.DESCRICAO, N'') AS HISTORICO_PADRAO_DESCRICAO,
               l.DOCUMENTO, l.DT_EMISSAO, l.DT_COMPETENCIA, l.HISTORICO, l.OBSERVACAO, l.VALOR_TOTAL,
               l.ORIGEM, l.ID_ORIGEM, l.ID_LOTE, l.SITUACAO, l.PREVISAO, l.INTEGRACAO,
               l.DT_CANCELAMENTO, ISNULL(l.USUARIO_CANCELAMENTO, N'') AS USUARIO_CANCELAMENTO, l.MOTIVO_CANCELAMENTO,
               l.CODIGO_ACCESS, l.DT_CRIACAO, l.USUARIO_CRIACAO, l.DT_ALTERACAO, ISNULL(l.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               @TemBaixa AS TEM_BAIXA, @NaLixeira AS NA_LIXEIRA, @MesFechado AS MES_FECHADO,
               CAST(CASE WHEN @Editavel = 1 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_ALTERAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'CANCELAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_CANCELAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND l.ORIGEM = 'MANUAL' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'EXCLUIR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_EXCLUIR,
               ISNULL((SELECT p.ID_PARCELA AS id, p.NUMERO AS numero, p.QTD_PARCELAS AS qtdParcelas, p.DT_VENCIMENTO AS vencimento,
                              p.VALOR AS valor, p.VALOR_BAIXADO AS valorBaixado, p.SALDO AS saldo, p.SITUACAO AS situacao,
                              p.ID_CONTA_PREVISTA AS idContaPrevista, ISNULL(c.DESCRICAO, N'') AS contaPrevista, p.ID_LOTE AS idLote,
                              (SELECT COUNT(*) FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) AS qtdBaixas,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) THEN 1 ELSE 0 END AS BIT) AS travada
                       FROM FIN.Parcela p WITH (NOLOCK)
                       LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = p.ID_CONTA_PREVISTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY p.NUMERO
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS PARCELAS,
               ISNULL((SELECT b.ID_BAIXA AS id, p.NUMERO AS parcela, b.DT_PAGAMENTO AS data, b.ID_CONTA AS idConta, c.DESCRICAO AS conta,
                              b.FORMA AS forma, b.VALOR_PRINCIPAL AS principal, b.JUROS AS juros, b.MULTA AS multa, b.CORRECAO AS correcao,
                              b.DESCONTO AS desconto, b.ABATIMENTO AS abatimento, b.TARIFA AS tarifa, b.RETENCAO AS retencao,
                              b.VALOR_LIQUIDO AS liquido, b.COMPENSADO AS compensado, b.DT_COMPENSACAO AS dataCompensacao,
                              b.ID_BAIXA_ESTORNADA AS idBaixaEstornada,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa x WITH (NOLOCK) WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA) THEN 1 ELSE 0 END AS BIT) AS estornada,
                              b.OBSERVACAO AS observacao, b.USUARIO_CRIACAO AS usuario
                       FROM FIN.Baixa b WITH (NOLOCK)
                       INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                       INNER JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = b.ID_CONTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY b.DT_PAGAMENTO, b.ID_BAIXA
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS BAIXAS,
               ISNULL((SELECT a.CODIGO_REGRA AS codigo, a.NIVEL AS nivel, a.MENSAGEM AS mensagem, a.MOTIVO AS motivo,
                              a.ID_REFERENCIA AS idReferencia, a.USUARIO_CRIACAO AS usuario, a.DT_CRIACAO AS data
                       FROM SIS.Aviso_Confirmado a WITH (NOLOCK)
                       WHERE a.TABELA = N'FIN.Lancamento' AND a.ID_REGISTRO = l.ID_LANCAMENTO
                       ORDER BY a.DT_CRIACAO DESC, a.ID_AVISO_CONFIRMADO DESC
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS AVISOS_CONFIRMADOS,
               ISNULL((SELECT pd.ID_LANCAMENTO_PENDENCIA AS id, pd.ORIGEM AS origem, pd.CODIGO AS codigo, pd.DESCRICAO AS descricao,
                              pd.ORIENTACAO AS orientacao, pd.BLOQUEIA_BAIXA AS bloqueiaBaixa, pd.ATRASADA AS atrasada,
                              pd.ID_PARCELA AS idParcela, pd.ID_USUARIO_RESPONSAVEL AS idResponsavel, pd.DT_PREVISAO AS previsao
                       FROM FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pd
                       ORDER BY CASE pd.ORIGEM WHEN 'MANUAL' THEN 0 ELSE 1 END, pd.DT_PREVISAO, pd.CODIGO
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS PENDENCIAS,
               (SELECT COUNT(*) FROM FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pc) AS QTD_PENDENCIAS,
               CAST(CASE WHEN @NaLixeira = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'PENDENCIA') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_PENDENCIA,
               bq.BLOQUEIA AS BLOQUEIA_BAIXA, bq.MOTIVO AS MOTIVO_BLOQUEIO
        FROM FIN.Lancamento l WITH (NOLOCK)
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        LEFT  JOIN FIN.Historico_Padrao h   WITH (NOLOCK) ON h.ID_HISTORICO_PADRAO = l.ID_HISTORICO_PADRAO
        CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(l.ID_LANCAMENTO, NULL) bq
        WHERE l.ID_LANCAMENTO = @IdLancamento;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o lançamento. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

PRINT N'Pacote 04f2c concluído sem erro.';
GO

SET NOEXEC OFF;
GO
