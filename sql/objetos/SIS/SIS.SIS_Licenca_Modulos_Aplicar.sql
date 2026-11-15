/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Modulos_Aplicar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Acerta SIS.Modulo.LIBERADO_LICENCA pela licença ativa:
                liberado = módulo listado na licença ativa e dentro da
                validade; SIS sempre liberado. Sem licença ativa (ou vencida),
                só SIS fica liberado.
                Chamada por SIS_Licenca_Gravar, pelo fim do MASTER (módulo
                novo instalado já sai certo) e pela rotina diária (validade).
                Só altera os módulos que estão diferentes (regra 20).
                Automação: em erro, registra e relança.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Licenca_Modulos_Aplicar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Modulos_Aplicar]
    @Usuario NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Licenca_Modulos_Aplicar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Aplicar módulos';
    DECLARE @Hoje       DATE          = CAST(SYSDATETIME() AS DATE);

    BEGIN TRY
        SET @Usuario = ISNULL(NULLIF(LTRIM(RTRIM(@Usuario)), N''), SIS.fn_SIS_Usuario_Atual());

        UPDATE m
           SET m.LIBERADO_LICENCA  = x.LIBERADO,
               m.DT_ALTERACAO      = SYSDATETIME(),
               m.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Modulo m
        CROSS APPLY (SELECT CAST(CASE WHEN m.CODIGO = 'SIS' THEN 1
                                      WHEN EXISTS (SELECT 1
                                                   FROM SIS.Licenca l
                                                   CROSS APPLY STRING_SPLIT(l.MODULOS, ',') s
                                                   WHERE l.ATIVA = 1
                                                     AND (l.DT_VALIDADE IS NULL OR l.DT_VALIDADE >= @Hoje)
                                                     AND LTRIM(RTRIM(s.value)) = m.CODIGO) THEN 1
                                      ELSE 0 END AS BIT) AS LIBERADO) x
        WHERE m.LIBERADO_LICENCA <> x.LIBERADO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
