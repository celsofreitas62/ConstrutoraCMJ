/*******************************************************************************
  Objeto      : [SIS].[Login_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Toda tentativa de login, certa ou errada (seção 3.6).
                RESULTADO: OK, SENHA_ERRADA, BLOQUEOU (errou e foi bloqueado
                nesta tentativa), BLOQUEADO (já estava), INATIVO, SEM_SENHA,
                INEXISTENTE, ESTACAO_BLOQUEADA (o computador errou demais
                em pouco tempo e está em espera), PROVISORIA_VENCIDA (senha
                provisória certa, mas passou de SENHA_PROVISORIA_HORAS). LOGIN_INFORMADO guarda o que foi digitado
                (para ver tentativas com nomes que não existem).
                Nunca é apagado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: resultado ESTACAO_BLOQUEADA (limite de
                        tentativas por computador) e índice por IP e data.
    v1.2 (22/11/2026) - Etapa 04a: resultado PROVISORIA_VENCIDA.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Login_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Login_Log]
    (
        ID_LOGIN_LOG     BIGINT          IDENTITY(1,1) NOT NULL,
        LOGIN_INFORMADO  NVARCHAR(100)   NOT NULL CONSTRAINT DF_Login_Log_LOGIN_INFORMADO DEFAULT (N''),
        ID_USUARIO       INT             NULL,
        RESULTADO        VARCHAR(20)     NOT NULL,
        IP               VARCHAR(45)     NOT NULL CONSTRAINT DF_Login_Log_IP              DEFAULT (''),
        ESTACAO          NVARCHAR(128)   NOT NULL CONSTRAINT DF_Login_Log_ESTACAO         DEFAULT (N''),
        DT_TENTATIVA     DATETIME2(0)    NOT NULL CONSTRAINT DF_Login_Log_DT_TENTATIVA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Login_Log           PRIMARY KEY CLUSTERED (ID_LOGIN_LOG),
        CONSTRAINT FK_Login_Log_Usuario   FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Login_Log_RESULTADO CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA', 'PROVISORIA_VENCIDA'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_DT_TENTATIVA')
    CREATE NONCLUSTERED INDEX IX_Login_Log_DT_TENTATIVA ON [SIS].[Login_Log] (DT_TENTATIVA) INCLUDE (ID_USUARIO, RESULTADO);
GO

-- v1.1/v1.2: resultados ESTACAO_BLOQUEADA e PROVISORIA_VENCIDA (troca a restrição só se ainda não aceita)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c
               WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]')
                 AND c.definition LIKE N'%PROVISORIA_VENCIDA%')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]'))
        ALTER TABLE [SIS].[Login_Log] DROP CONSTRAINT CK_Login_Log_RESULTADO;
    ALTER TABLE [SIS].[Login_Log] ADD CONSTRAINT CK_Login_Log_RESULTADO
        CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA', 'PROVISORIA_VENCIDA'));
END;
GO

-- v1.1: contagem de tentativas erradas por computador (SIS_Usuario_Login_Processar)
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_IP_DT')
    CREATE NONCLUSTERED INDEX IX_Login_Log_IP_DT ON [SIS].[Login_Log] (IP, DT_TENTATIVA) INCLUDE (RESULTADO);
GO
