/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Padroes_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Sugestão de conta do plano e centro de custo ao escolher o
                parceiro na ficha do lançamento (P17): primeiro a conta/centro
                padrão do cadastro do parceiro (04e); sem padrão, os do último
                lançamento ativo do mesmo tipo deste parceiro. Só sugere o que
                está ativo. Informa também se o parceiro tem o tipo esperado
                (Fornecedor no a pagar, Cliente no a receber).
                ORIGEM_PLANO / ORIGEM_CENTRO: PARCEIRO, ULTIMO ou vazio.
                Permissão: INCLUIR ou ALTERAR em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Padroes_Obter @IdUsuario = 2, @IdPessoa = 1, @Tipo = 'P';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Padroes_Obter]
    @IdUsuario  INT,
    @IdPessoa   INT,
    @Tipo       CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Padroes_Obter]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Item         VARCHAR(40);
    DECLARE @Plano        INT;
    DECLARE @Centro       INT;
    DECLARE @OrigemPlano  VARCHAR(10) = '';
    DECLARE @OrigemCentro VARCHAR(10) = '';

    BEGIN TRY
        SET @Tipo = UPPER(ISNULL(@Tipo, ''));
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' WHEN 'R' THEN 'FIN_RECEBER' ELSE '' END;
        IF @Item = ''
            THROW 50001, N'Tipo inválido.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'INCLUIR') = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0
            THROW 50001, N'Você não tem permissão para lançar.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.ID_PESSOA = @IdPessoa)
            THROW 50001, N'Parceiro não encontrado.', 1;

        SET @EtapaAtual = 'Padrão do parceiro';
        SELECT @Plano  = CASE WHEN v.ATIVO_EFETIVO = 1 AND pc.DT_EXCLUSAO IS NULL THEN p.ID_PLANO_CONTA_PADRAO END,
               @Centro = CASE WHEN cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL THEN p.ID_CENTRO_CUSTO_PADRAO END
        FROM CAD.Pessoa p WITH (NOLOCK)
        LEFT JOIN CAD.vw_CAD_Plano_Conta v  ON v.ID_PLANO_CONTA = p.ID_PLANO_CONTA_PADRAO
        LEFT JOIN CAD.Plano_Conta pc        WITH (NOLOCK) ON pc.ID_PLANO_CONTA = p.ID_PLANO_CONTA_PADRAO
        LEFT JOIN CAD.Centro_Custo cc       WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = p.ID_CENTRO_CUSTO_PADRAO
        WHERE p.ID_PESSOA = @IdPessoa;

        IF @Plano  IS NOT NULL SET @OrigemPlano  = 'PARCEIRO';
        IF @Centro IS NOT NULL SET @OrigemCentro = 'PARCEIRO';

        SET @EtapaAtual = 'Último lançamento';
        IF @Plano IS NULL
        BEGIN
            SELECT TOP 1 @Plano = l.ID_PLANO_CONTA
            FROM FIN.Lancamento l WITH (NOLOCK)
            INNER JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND v.ATIVO_EFETIVO = 1
            INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.DT_EXCLUSAO IS NULL
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;
            IF @Plano IS NOT NULL SET @OrigemPlano = 'ULTIMO';
        END;

        IF @Centro IS NULL
        BEGIN
            SELECT TOP 1 @Centro = l.ID_CENTRO_CUSTO
            FROM FIN.Lancamento l WITH (NOLOCK)
            INNER JOIN CAD.Centro_Custo cc WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO AND cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL
                                                         AND (cc.DT_ENCERRAMENTO IS NULL OR cc.DT_ENCERRAMENTO > CONVERT(DATE, SYSDATETIME()))
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;
            IF @Centro IS NOT NULL SET @OrigemCentro = 'ULTIMO';
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT @Plano AS ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               @OrigemPlano AS ORIGEM_PLANO,
               @Centro AS ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               @OrigemCentro AS ORIGEM_CENTRO,
               CAST(CASE WHEN (@Tipo = 'P' AND p.FORNECEDOR = 1) OR (@Tipo = 'R' AND p.CLIENTE = 1) THEN 1 ELSE 0 END AS BIT) AS TIPO_OK,
               p.ATIVO AS PARCEIRO_ATIVO
        FROM CAD.Pessoa p WITH (NOLOCK)
        LEFT JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = @Plano
        LEFT JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = @Centro
        WHERE p.ID_PESSOA = @IdPessoa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as sugestões. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
