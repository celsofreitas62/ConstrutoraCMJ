/*******************************************************************************
  Objeto      : FK de CAD.Empresa para BANCO.Conta
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a conta bancária padrão da empresa (BANCO.Conta é criada
                depois de CAD.Empresa, por isso a FK fica neste arquivo).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[FK_Empresa_Conta_Padrao]', N'F') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT FK_Empresa_Conta_Padrao
        FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA);
GO
