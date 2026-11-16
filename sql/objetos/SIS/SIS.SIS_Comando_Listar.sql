/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (exclusiva do
                administrador geral), por grupo e ordem, com o último pedido
                de cada comando (situação, quando e por quem).
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMANDO, c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO,
               CAST(CASE c.GRUPO WHEN 'INSTALACAO'  THEN N'Instalação'
                                 WHEN 'ATUALIZACAO' THEN N'Atualização'
                                 WHEN 'BACKUP'      THEN N'Backup'
                                 WHEN 'SERVICO'     THEN N'Serviço do sistema'
                                 ELSE N'Diagnóstico' END AS NVARCHAR(40)) AS GRUPO_NOME,
               c.ORDEM, c.PERIGOSO, c.ACEITA_PARAMETRO, c.PARAMETRO_DESCRICAO,
               u.ID_PEDIDO AS ULTIMO_PEDIDO, u.STATUS AS ULTIMO_STATUS, u.DT_PEDIDO AS ULTIMO_DT_PEDIDO,
               u.USUARIO_PEDIDO AS ULTIMO_USUARIO, u.DT_FIM AS ULTIMO_DT_FIM
        FROM SIS.Comando c
        OUTER APPLY (SELECT TOP (1) f.ID_PEDIDO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.DT_FIM
                     FROM SIS.Comando_Fila f WHERE f.ID_COMANDO = c.ID_COMANDO ORDER BY f.ID_PEDIDO DESC) u
        WHERE c.ATIVO = 1
        ORDER BY CASE c.GRUPO WHEN 'INSTALACAO' THEN 1 WHEN 'ATUALIZACAO' THEN 2 WHEN 'BACKUP' THEN 3 WHEN 'SERVICO' THEN 4 ELSE 5 END,
                 c.ORDEM, c.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os comandos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
