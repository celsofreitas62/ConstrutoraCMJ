/*******************************************************************************
  Objeto      : [SIS].[Perfil]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Perfis de acesso (Financeiro, Vendas, Consulta...), criados
                pelo administrador da CMJ.
                NIVEL_ADMIN (dois níveis de administrador, pedido do Celso):
                  0 = perfil comum: só o que for marcado;
                  1 = Administrador (da CMJ): todas as ações de todos os
                      módulos liberados, inclusive telas novas, MENOS as telas
                      exclusivas do administrador geral (Item.EXCLUSIVO_GERAL:
                      Licença e Parâmetros);
                  2 = Administrador geral (o criador do sistema): tudo.
                Perfis e usuários de nível 2 ficam invisíveis para quem não é
                nível 2. Só a carga cria os perfis de administrador; a tela não
                muda o nível.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - ADMINISTRADOR (BIT) vira NIVEL_ADMIN (0/1/2). Bloco de
                        ajuste converte um banco criado com a v1.0.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Perfil]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Perfil]
    (
        ID_PERFIL          INT            IDENTITY(1,1) NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Perfil_DESCRICAO       DEFAULT (N''),
        NIVEL_ADMIN        TINYINT        NOT NULL CONSTRAINT DF_Perfil_NIVEL_ADMIN     DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Perfil_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Perfil_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Perfil_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Perfil      PRIMARY KEY CLUSTERED (ID_PERFIL),
        CONSTRAINT UQ_Perfil_NOME UNIQUE (NOME),
        CONSTRAINT CK_Perfil_NOME CHECK (NOME <> N''),
        CONSTRAINT CK_Perfil_NIVEL_ADMIN CHECK (NIVEL_ADMIN IN (0, 1, 2))
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (coluna ADMINISTRADOR BIT)
IF COL_LENGTH(N'SIS.Perfil', N'NIVEL_ADMIN') IS NULL
    ALTER TABLE [SIS].[Perfil] ADD NIVEL_ADMIN TINYINT NOT NULL CONSTRAINT DF_Perfil_NIVEL_ADMIN DEFAULT (0);
GO

IF COL_LENGTH(N'SIS.Perfil', N'ADMINISTRADOR') IS NOT NULL
BEGIN
    EXEC (N'UPDATE p SET p.NIVEL_ADMIN = 1 FROM SIS.Perfil p WHERE p.ADMINISTRADOR = 1 AND p.NIVEL_ADMIN = 0;');
    IF OBJECT_ID(N'[SIS].[DF_Perfil_ADMINISTRADOR]', N'D') IS NOT NULL
        ALTER TABLE [SIS].[Perfil] DROP CONSTRAINT DF_Perfil_ADMINISTRADOR;
    ALTER TABLE [SIS].[Perfil] DROP COLUMN ADMINISTRADOR;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Perfil_NIVEL_ADMIN' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Perfil]'))
    ALTER TABLE [SIS].[Perfil] ADD CONSTRAINT CK_Perfil_NIVEL_ADMIN CHECK (NIVEL_ADMIN IN (0, 1, 2));
GO
