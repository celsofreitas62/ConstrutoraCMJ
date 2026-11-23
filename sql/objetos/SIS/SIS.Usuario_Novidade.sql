/*******************************************************************************
  Objeto      : [SIS].[Usuario_Novidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Última versão cujas novidades cada usuário já viu (aviso "O que
                há de novo", pedido P22). O aviso mostra as versões instaladas
                depois desta. Usuário sem linha: na primeira consulta nasce com
                a versão atual (usuário novo não recebe o histórico inteiro).
                Na instalação da 04c, os usuários existentes nascem com a
                versão que estava instalada (Carga_SIS_Novidades.sql), para
                verem as novidades da versão nova.
                Gravada só por SIS.SIS_Novidades_Obter e
                SIS.SIS_Novidades_Marcar_Vista.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Novidade]', N'U') IS NULL
    CREATE TABLE [SIS].[Usuario_Novidade]
    (
        ID_USUARIO    INT           NOT NULL,
        VERSAO_VISTA  VARCHAR(20)   NOT NULL CONSTRAINT DF_Usuario_Novidade_VERSAO_VISTA DEFAULT (''),
        DT_VISTA      DATETIME2(0)  NOT NULL CONSTRAINT DF_Usuario_Novidade_DT_VISTA     DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Usuario_Novidade          PRIMARY KEY CLUSTERED (ID_USUARIO),
        CONSTRAINT FK_Usuario_Novidade_Usuario  FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO)
    );
GO
