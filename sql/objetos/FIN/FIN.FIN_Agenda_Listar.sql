/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Lista da tela inicial (agenda financeira, P03, etapa 04h1):
                as parcelas a pagar e a receber do período (@De a @Ate), linha
                a linha, pela mesma regra do calendário (fn_FIN_Agenda_Base):
                em aberto pelo saldo e, com a opção ligada, também o já pago ou
                recebido. @SoAtraso = 1: só o "Em atraso" (em aberto, vencidas
                antes de hoje, sem olhar o período). @Tipo P/R filtra o lado;
                @Texto procura no parceiro, histórico, documento e número do
                lançamento. Paginada (FIN_LISTA_POR_PAGINA); TOTAL_LINHAS em
                todas as linhas. A linha abre o lançamento (ID_LANCAMENTO).
                PROJECAO fica 0 até as ocorrências mensais (P02): as linhas
                projetadas virão marcadas, só leitura, calculadas na hora.
                Os valores de cada parcela aparecem para quem vê a tela (são
                os mesmos das listas de contas a pagar e a receber); os
                totais somados ficam no FIN_Agenda_Resumo (P04).
                @IncluiRealizado NULL = preferência do usuário.
                Permissão: VER em FIN_AGENDA. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Listar @IdUsuario = 2, @De = '2026-11-27', @Ate = '2026-11-27';
    -- EXEC FIN.FIN_Agenda_Listar @IdUsuario = 2, @De = NULL, @Ate = NULL, @SoAtraso = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Listar]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @SoAtraso         BIT           = 0,
    @Tipo             CHAR(1)       = NULL,
    @IdEmpresa        INT           = NULL,
    @IncluiRealizado  BIT           = NULL,
    @Texto            NVARCHAR(100) = NULL,
    @Pagina           INT           = 1,
    @PorPagina        INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Agenda_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias    INT;
    DECLARE @VerPagar   BIT;
    DECLARE @VerReceber BIT;
    DECLARE @Termo      NVARCHAR(110);
    DECLARE @Digitos    VARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a agenda financeira.', 1;

        SET @EtapaAtual = 'Período';
        SET @SoAtraso = ISNULL(@SoAtraso, 0);
        IF @SoAtraso = 1
        BEGIN
            SET @De  = '19000101';
            SET @Ate = DATEADD(DAY, -1, @Hoje);
            SET @IncluiRealizado = 0;
        END
        ELSE
        BEGIN
            IF @De IS NULL OR @Ate IS NULL
                THROW 50001, N'Informe o período.', 1;
            IF @Ate < @De
                THROW 50001, N'A data final não pode ser antes da inicial.', 1;
            SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700);
            IF @MaxDias NOT BETWEEN 31 AND 7400 SET @MaxDias = 3700;
            IF DATEDIFF(DAY, @De, @Ate) + 1 > @MaxDias
                THROW 50001, N'Período longo demais para a agenda. Escolha um período menor.', 1;
        END;

        SET @EtapaAtual = 'Permissões e filtros';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @Tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Tipo, '')))), '');
        IF @Tipo = 'P' SET @VerReceber = 0;
        IF @Tipo = 'R' SET @VerPagar = 0;
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Termo     = N'%' + REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Digitos   = NULLIF(CONVERT(VARCHAR(100), CAD.fn_CAD_Somente_Digitos(ISNULL(@Texto, N''))), '');
        SET @PorPagina = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @Pagina = CASE WHEN ISNULL(@Pagina, 1) < 1 THEN 1 ELSE @Pagina END;

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_PARCELA,
               b.ID_LANCAMENTO,
               b.TIPO,
               b.DT_VENCIMENTO,
               p.NUMERO,
               p.QTD_PARCELAS,
               b.SITUACAO,
               b.PREVISAO,
               CAST(0 AS BIT)                                                                 AS PROJECAO,
               CAST(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
               CAST(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN DATEDIFF(DAY, b.DT_VENCIMENTO, @Hoje) ELSE 0 END AS INT) AS DIAS_ATRASO,
               b.VALOR,
               b.ABERTO                                                                       AS SALDO_ABERTO,
               b.REALIZADO                                                                    AS VALOR_REALIZADO,
               b.VALOR_AGENDA,
               b.ID_EMPRESA,
               ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)                           AS EMPRESA_NOME,
               ISNULL(l.ID_PESSOA, 0)                                                         AS ID_PESSOA,
               ISNULL(NULLIF(pe.NOME_FANTASIA, N''), ISNULL(pe.NOME, N''))                    AS PESSOA_NOME,
               l.HISTORICO,
               l.DOCUMENTO,
               ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'')                                  AS CENTRO_CODIGO,
               ISNULL(cc.DESCRICAO, N'')                                                      AS CENTRO_DESCRICAO,
               CAST(COUNT(*) OVER () AS INT)                                                  AS TOTAL_LINHAS,
               @Pagina                                                                        AS PAGINA,
               @PorPagina                                                                     AS POR_PAGINA
        FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) b
        INNER JOIN FIN.Parcela p           WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l        WITH (NOLOCK) ON l.ID_LANCAMENTO = b.ID_LANCAMENTO
        INNER JOIN CAD.Empresa e           WITH (NOLOCK) ON e.ID_EMPRESA = b.ID_EMPRESA
        LEFT  JOIN CAD.Pessoa pe           WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.Centro_Custo cc     WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        WHERE (@Texto IS NULL
               OR l.HISTORICO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.DOCUMENTO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME      COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
               OR (@Digitos IS NOT NULL AND LEN(@Digitos) >= 5 AND pe.CPF_CNPJ LIKE @Digitos + '%')
               OR CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) = @Texto)
        ORDER BY b.DT_VENCIMENTO, b.TIPO, ISNULL(NULLIF(pe.NOME_FANTASIA, N''), ISNULL(pe.NOME, N'')), b.ID_LANCAMENTO, p.NUMERO
        OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista da agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
