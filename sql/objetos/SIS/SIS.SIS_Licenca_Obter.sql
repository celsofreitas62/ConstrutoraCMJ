/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Licença ativa, para a API conferir a assinatura ao iniciar e a
                cada login, e para a tela "Licença" mostrar o que está liberado.
                Sempre devolve 1 linha: ENCONTRADA = 0 quando não há licença.
                EMPRESAS_JSON: [{"CNPJ":"...","RAZAO_SOCIAL":"...",
                "NOME_FANTASIA":"...","PRINCIPAL":true}].
                Sem conferência de permissão: a API precisa ler antes de haver
                usuário logado, e nada aqui é segredo (a chave é assinada,
                não é senha).
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Licenca_Obter;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Obter]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Licenca_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Consulta';

    BEGIN TRY
        SELECT CAST(CASE WHEN l.ID_LICENCA IS NULL THEN 0 ELSE 1 END AS BIT) AS ENCONTRADA,
               l.ID_LICENCA,
               ISNULL(l.CHAVE_LICENCA, N'')     AS CHAVE_LICENCA,
               ISNULL(l.ID_SERVIDOR, '')        AS ID_SERVIDOR,
               l.DT_EMISSAO,
               l.DT_VALIDADE,
               ISNULL(l.MODULOS, '')            AS MODULOS,
               l.DT_CRIACAO                     AS DT_INSTALACAO,
               ISNULL(l.USUARIO_CRIACAO, N'')   AS USUARIO_INSTALACAO,
               ISNULL((SELECT e.CNPJ, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.PRINCIPAL
                       FROM SIS.Licenca_Empresa e WITH (NOLOCK)
                       WHERE e.ID_LICENCA = l.ID_LICENCA
                       ORDER BY e.PRINCIPAL DESC, e.RAZAO_SOCIAL
                       FOR JSON PATH), N'[]')   AS EMPRESAS_JSON
        FROM (SELECT 1 AS X) d
        LEFT JOIN SIS.Licenca l WITH (NOLOCK) ON l.ATIVA = 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível ler a licença. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
