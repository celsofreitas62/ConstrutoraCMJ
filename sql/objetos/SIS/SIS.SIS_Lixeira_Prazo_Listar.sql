/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Prazo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazos da lixeira por tela (P20), para a tela Sistema ›
                Lixeira: tela, módulo, prazo próprio (vazio = vale o geral),
                prazo que vale e quantos registros estão na lixeira. Só as
                telas que o usuário pode ver.
                Permissão: VER em SIS_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Prazo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Prazo_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Prazo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lixeira.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT CAST(c.TABELA AS NVARCHAR(256)) AS TABELA,
               x.ITEM_CODIGO,
               i.NOME AS TELA_NOME,
               m.CODIGO AS MODULO_CODIGO,
               m.NOME AS MODULO_NOME,
               c.DIAS_GUARDA,
               SIS.fn_SIS_Lixeira_Dias(c.TABELA) AS DIAS_VALE,
               SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_DIAS_GUARDA') AS DIAS_GERAL,
               (SELECT COUNT(*) FROM SIS.Lixeira l WITH (NOLOCK) WHERE l.TABELA = c.TABELA AND l.SITUACAO = 'LIXEIRA') AS QTD_NA_LIXEIRA
        FROM SIS.Tabela_Config c WITH (NOLOCK)
        CROSS APPLY (SELECT SIS.fn_SIS_Item_Da_Tabela(c.TABELA) AS ITEM_CODIGO) x
        INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.CODIGO = x.ITEM_CODIGO
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
        WHERE c.ATIVO = 1
          AND c.PERMITE_LIXEIRA = 1
          AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, x.ITEM_CODIGO, 'VER') = 1
        ORDER BY m.ORDEM_MENU, i.ORDEM, c.TABELA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar os prazos da lixeira. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
