/*******************************************************************************
  Objeto      : [CAD].[Empresa].PASTA_OFX
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Pasta onde a empresa guarda os extratos OFX do banco (pedido do
                Celso, 17/11/2026). Caminho editável no cadastro da empresa; vazio =
                a empresa não importa OFX. A conta é identificada pelo conteúdo do
                arquivo (banco/agência/conta), não pelo nome.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'CAD.Empresa', N'PASTA_OFX') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD PASTA_OFX NVARCHAR(260) NOT NULL CONSTRAINT DF_Empresa_PASTA_OFX DEFAULT (N'');
GO
