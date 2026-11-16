/*******************************************************************************
  Objeto      : [SIS].[tg_SIS_Auditoria_Protecao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Ninguém altera nem apaga a auditoria (seção 3.7), nem o
                administrador. Qualquer UPDATE ou DELETE em SIS.Auditoria é
                recusado com o erro 50010 e nada muda.
                (TRUNCATE não dispara trigger: fica bloqueado pelo DENY no
                papel da API, etapa 02d, e por ninguém ter ALTER na tabela.)

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação: ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER TRIGGER [SIS].[tg_SIS_Auditoria_Protecao]
ON [SIS].[Auditoria]
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    THROW 50010, N'A auditoria não pode ser alterada nem apagada.', 1;
END;
GO
