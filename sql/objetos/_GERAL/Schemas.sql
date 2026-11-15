/*******************************************************************************
  Objeto      : schemas do SistemaCMJ
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cria os schemas por bloco (PADRAO_SQL regra 31).
                O schema MIG (migração) não é criado aqui: ele não entra no
                MASTER e é criado pelo pacote da migração.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'CAD')   IS NULL EXEC (N'CREATE SCHEMA [CAD] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'BANCO') IS NULL EXEC (N'CREATE SCHEMA [BANCO] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'IMOB')  IS NULL EXEC (N'CREATE SCHEMA [IMOB] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'VENDA') IS NULL EXEC (N'CREATE SCHEMA [VENDA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'FIN')   IS NULL EXEC (N'CREATE SCHEMA [FIN] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'COBR')  IS NULL EXEC (N'CREATE SCHEMA [COBR] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'OBRA')  IS NULL EXEC (N'CREATE SCHEMA [OBRA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'GER')   IS NULL EXEC (N'CREATE SCHEMA [GER] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'SIS')   IS NULL EXEC (N'CREATE SCHEMA [SIS] AUTHORIZATION [dbo];');
GO
