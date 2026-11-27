/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Caixa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Histórico dos fechamentos de caixa (tela Bancos › Fechamento
                de caixa, etapa 04g2): conta, data, saldo do sistema,
                contado, diferença com motivo, ajuste, quem fechou e a
                reabertura. Filtros: conta, empresa, período, situação
                (FECHADO, REABERTO ou todos), só com diferença.
                PODE_REABRIR: o último fechamento FECHADO da conta, para
                quem tem REABRIR. As contas que faltam fechar vêm da
                BANCO_Saldo_Listar (FECHAMENTO_ATRASADO).
                Permissão: VER em BANCO_CAIXA (recusa por THROW 50001).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Caixa_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Caixa_Listar]
    @IdUsuario       INT,
    @IdConta         INT          = NULL,
    @IdEmpresa       INT          = NULL,
    @DtDe            DATE         = NULL,
    @DtAte           DATE         = NULL,
    @Situacao        VARCHAR(10)  = NULL,
    @SoComDiferenca  BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[BANCO].[BANCO_Caixa_Listar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @PodeReabrir  BIT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os fechamentos de caixa.', 1;

        SET @EtapaAtual  = 'Consulta';
        SET @PodeReabrir = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'REABRIR');
        SET @Situacao    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Situacao, '')))), '');

        SELECT f.ID_CAIXA_FECHAMENTO, f.ID_CONTA, c.DESCRICAO AS CONTA, c.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA,
               f.DT_FECHAMENTO, f.SALDO_SISTEMA, f.SALDO_CONTADO, f.DIFERENCA, f.MOTIVO_DIFERENCA, f.OBSERVACAO,
               ISNULL(f.ID_MOVIMENTO_AJUSTE, 0) AS ID_MOVIMENTO_AJUSTE, CAST(ISNULL(m.VALOR, 0) AS DECIMAL(18,2)) AS VALOR_AJUSTE,
               CAST(CASE WHEN m.SITUACAO = 'ESTORNADO' THEN 1 ELSE 0 END AS BIT) AS AJUSTE_DESFEITO,
               f.SITUACAO, f.USUARIO_CRIACAO, f.DT_CRIACAO,
               ISNULL(CONVERT(VARCHAR(19), f.DT_REABERTURA, 120), '') AS DT_REABERTURA, ISNULL(f.USUARIO_REABERTURA, N'') AS USUARIO_REABERTURA,
               ISNULL(f.MOTIVO_REABERTURA, N'') AS MOTIVO_REABERTURA,
               CAST(CASE WHEN @PodeReabrir = 1 AND f.SITUACAO = 'FECHADO'
                              AND NOT EXISTS (SELECT 1 FROM BANCO.Caixa_Fechamento x WITH (NOLOCK)
                                              WHERE x.ID_CONTA = f.ID_CONTA AND x.SITUACAO = 'FECHADO' AND x.DT_FECHAMENTO > f.DT_FECHAMENTO)
                         THEN 1 ELSE 0 END AS BIT) AS PODE_REABRIR
        FROM BANCO.Caixa_Fechamento f WITH (NOLOCK)
        INNER JOIN BANCO.Conta c   WITH (NOLOCK) ON c.ID_CONTA = f.ID_CONTA
        INNER JOIN CAD.Empresa e   WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Movimento m WITH (NOLOCK) ON m.ID_MOVIMENTO = f.ID_MOVIMENTO_AJUSTE
        WHERE (@IdConta IS NULL OR f.ID_CONTA = @IdConta)
          AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
          AND (@DtDe IS NULL OR f.DT_FECHAMENTO >= @DtDe)
          AND (@DtAte IS NULL OR f.DT_FECHAMENTO <= @DtAte)
          AND (@Situacao IS NULL OR f.SITUACAO = @Situacao)
          AND (ISNULL(@SoComDiferenca, 0) = 0 OR f.DIFERENCA <> 0)
        ORDER BY f.DT_FECHAMENTO DESC, c.DESCRICAO, f.ID_CAIXA_FECHAMENTO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível listar os fechamentos de caixa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
