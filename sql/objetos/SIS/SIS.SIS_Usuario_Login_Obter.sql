/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Login_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 1º passo do login (uso exclusivo da API, nunca vai para a
                tela): devolve hash, salt, iterações e algoritmo da senha do
                login informado, para a API conferir a senha digitada.
                Sempre devolve 1 linha; ENCONTRADO = 0 para login inexistente
                ou usuário interno. Mesmo nesse caso a API calcula um hash
                qualquer, para o tempo de resposta não revelar se o login
                existe. O resultado vai para SIS_Usuario_Login_Processar.
                Não confere ativo/bloqueado: isso é do 2º passo, que registra
                a tentativa.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Usuario_Login_Obter @Login = N'admin';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Login_Obter]
    @Login NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Usuario_Login_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Consulta';

    BEGIN TRY
        SET @Login = LOWER(LTRIM(RTRIM(ISNULL(@Login, N''))));

        SELECT CAST(CASE WHEN u.ID_USUARIO IS NULL THEN 0 ELSE 1 END AS BIT) AS ENCONTRADO,
               u.ID_USUARIO,
               u.SENHA_HASH,
               u.SENHA_SALT,
               ISNULL(u.SENHA_ITERACOES, 0)  AS SENHA_ITERACOES,
               ISNULL(u.SENHA_ALGORITMO, '') AS SENHA_ALGORITMO
        FROM (SELECT 1 AS X) d
        LEFT JOIN SIS.Usuario u ON u.LOGIN = @Login AND u.INTERNO = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível conferir o login. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
