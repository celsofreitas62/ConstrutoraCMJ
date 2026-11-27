/*******************************************************************************
  Objeto      : [FIN].[FIN_Transferencia_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Transferência entre duas contas (etapa 04g2, desenho aprovado
                em 26/11/2026). Gera um lote (origem TRANSFERENCIA), a
                FIN.Transferencia e dois BANCO.Movimento TIPO TRANSFERENCIA
                (saída na origem, entrada no destino). Tudo-ou-nada.
                Regras (mesmo contrato da baixa: BLOQUEIO, MOTIVO, AVISO;
                @SomenteConferir = 1 é a prévia), sempre nas duas pontas:
                  BLOQUEIO  conta inexistente, desativada ou na lixeira;
                            caixa fechado (BANCO.fn_BANCO_Caixa_Recusa); mês
                            fechado da empresa da conta; trava de datas para
                            quem não tem LANCAR_RETROATIVO; entre empresas
                            com FIN_TRANSF_ENTRE_EMPRESAS = BLOQUEIO;
                  MOTIVO    trava de datas com LANCAR_RETROATIVO;
                  AVISO     entre empresas do grupo (ENTRE_EMPRESAS, com
                            FIN_TRANSF_ENTRE_EMPRESAS = AVISO); saldo da
                            origem na data, mais o limite, menor que o valor
                            (SALDO_INSUFICIENTE).
                Avisos e motivos em SIS.Aviso_Confirmado (TABELA
                FIN.Transferencia).
                Permissão: INCLUIR em BANCO_TRANSFERENCIA.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID, ID_LOTE, PENDENTE,
                AVISOS (JSON: codigo, nivel, mensagem, idReferencia, campo).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = 2, @DtTransferencia = '2026-11-27', @IdContaOrigem = 1,
    --      @IdContaDestino = 2, @Valor = 100, @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Transferencia_Gravar]
    @IdUsuario          INT,
    @DtTransferencia    DATE            = NULL,
    @IdContaOrigem      INT             = NULL,
    @IdContaDestino     INT             = NULL,
    @Valor              DECIMAL(18,2)   = NULL,
    @Historico          NVARCHAR(200)   = NULL,
    @Documento          NVARCHAR(40)    = NULL,
    @AvisosConfirmados  NVARCHAR(1000)  = NULL,
    @Motivo             NVARCHAR(400)   = NULL,
    @SomenteConferir    BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Transferencia_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Avisos       NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente     BIT = 0;
    DECLARE @EntreEmp     VARCHAR(10);
    DECLARE @IdLote       BIGINT;
    DECLARE @Id           BIGINT;
    DECLARE @NomeOrigem   NVARCHAR(60);
    DECLARE @NomeDestino  NVARCHAR(60);
    DECLARE @HistOrigem   NVARCHAR(200);
    DECLARE @HistDestino  NVARCHAR(200);
    DECLARE @Saldo        DECIMAL(18,2);
    DECLARE @Limite       DECIMAL(18,2);
    DECLARE @TemSaldo     BIT;

    CREATE TABLE #C (PONTA VARCHAR(7) NOT NULL PRIMARY KEY, ID_CONTA INT NULL, ID_EMPRESA INT NULL, DESCRICAO NVARCHAR(60) NULL,
                     ATIVO BIT NULL, NA_LIXEIRA BIT NULL);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Historico         = LTRIM(RTRIM(ISNULL(@Historico, N'')));
        SET @Documento         = LTRIM(RTRIM(ISNULL(@Documento, N'')));
        SET @Motivo            = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @AvisosConfirmados = ISNULL(@AvisosConfirmados, N'');

        INSERT INTO #C (PONTA, ID_CONTA, ID_EMPRESA, DESCRICAO, ATIVO, NA_LIXEIRA)
        SELECT v.PONTA, c.ID_CONTA, c.ID_EMPRESA, c.DESCRICAO, c.ATIVO, CAST(CASE WHEN c.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT)
        FROM (VALUES (CAST('ORIGEM' AS VARCHAR(7)), @IdContaOrigem), ('DESTINO', @IdContaDestino)) v (PONTA, ID)
        LEFT JOIN BANCO.Conta c ON c.ID_CONTA = v.ID;

        SELECT @NomeOrigem  = ISNULL(DESCRICAO, N'') FROM #C WHERE PONTA = 'ORIGEM';
        SELECT @NomeDestino = ISNULL(DESCRICAO, N'') FROM #C WHERE PONTA = 'DESTINO';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'INCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para incluir transferências.';
        IF @Recusa = N'' AND @DtTransferencia IS NULL
            SET @Recusa = N'Informe a data da transferência.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #C WHERE PONTA = 'ORIGEM' AND ID_CONTA IS NULL)
            SET @Recusa = N'Escolha a conta de origem (de onde sai o dinheiro).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #C WHERE PONTA = 'DESTINO' AND ID_CONTA IS NULL)
            SET @Recusa = N'Escolha a conta de destino (para onde vai o dinheiro).';
        IF @Recusa = N'' AND @IdContaOrigem = @IdContaDestino
            SET @Recusa = N'A conta de origem e a de destino precisam ser diferentes.';
        IF @Recusa = N'' AND ISNULL(@Valor, 0) <= 0
            SET @Recusa = N'Informe o valor da transferência.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #C; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Regras (nas duas pontas)
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Regras';

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'CONTA_INATIVA', 'BLOQUEIO',
               N'A conta ' + c.DESCRICAO + CASE WHEN c.NA_LIXEIRA = 1 THEN N' está na lixeira.' ELSE N' está desativada.' END,
               c.ID_CONTA, CASE c.PONTA WHEN 'ORIGEM' THEN 'idContaOrigem' ELSE 'idContaDestino' END
        FROM #C c WHERE c.ATIVO = 0 OR c.NA_LIXEIRA = 1;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(c.ID_CONTA, @DtTransferencia), c.ID_CONTA, 'dtTransferencia'
        FROM #C c WHERE BANCO.fn_BANCO_Caixa_Recusa(c.ID_CONTA, @DtTransferencia) <> N'';

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES))
               + N' está fechado na empresa da conta ' + c.DESCRICAO + N'.', c.ID_CONTA, 'dtTransferencia'
        FROM #C c
        INNER JOIN FIN.Mes_Fechado m ON m.ID_EMPRESA = c.ID_EMPRESA AND m.FECHADO = 1
                                    AND m.MES = DATEFROMPARTS(YEAR(@DtTransferencia), MONTH(@DtTransferencia), 1);

        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtTransferencia) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_TRANSFERENCIA',
                    CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'LANCAR_RETROATIVO') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
                    REPLACE(FIN.fn_FIN_Data_Recusa('BAIXA', @DtTransferencia), N'de pagamento', N'da transferência'), 'dtTransferencia');

        SET @EntreEmp = UPPER(ISNULL(NULLIF(LTRIM(RTRIM(SIS.fn_SIS_Parametro('FIN_TRANSF_ENTRE_EMPRESAS'))), N''), N'AVISO'));
        IF @EntreEmp IN ('AVISO', 'BLOQUEIO')
           AND (SELECT COUNT(DISTINCT ID_EMPRESA) FROM #C) > 1
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'ENTRE_EMPRESAS', @EntreEmp,
                   CASE WHEN @EntreEmp = 'BLOQUEIO'
                        THEN N'Transferência entre contas de empresas diferentes não é permitida (parâmetro FIN_TRANSF_ENTRE_EMPRESAS).'
                        ELSE N'As contas são de empresas diferentes do grupo (' + ISNULL(NULLIF(eo.NOME_FANTASIA, N''), eo.RAZAO_SOCIAL) + N' → ' + ISNULL(NULLIF(ed.NOME_FANTASIA, N''), ed.RAZAO_SOCIAL)
                             + N'). Confira com a contabilidade (empréstimo entre empresas).' END,
                   'idContaDestino'
            FROM #C o
            INNER JOIN #C d ON d.PONTA = 'DESTINO'
            LEFT  JOIN CAD.Empresa eo ON eo.ID_EMPRESA = o.ID_EMPRESA
            LEFT  JOIN CAD.Empresa ed ON ed.ID_EMPRESA = d.ID_EMPRESA
            WHERE o.PONTA = 'ORIGEM';

        SELECT @Saldo = s.SALDO, @Limite = s.LIMITE_CREDITO, @TemSaldo = s.TEM_SALDO
        FROM BANCO.fn_BANCO_Conta_Saldo(@IdContaOrigem, @DtTransferencia) s;
        IF @TemSaldo = 1 AND @Saldo + ISNULL(@Limite, 0) < @Valor
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
            VALUES ('SALDO_INSUFICIENTE', 'AVISO',
                    N'O saldo da conta ' + @NomeOrigem + N' em ' + CONVERT(NVARCHAR(10), @DtTransferencia, 103) + N' é de '
                    + FORMAT(@Saldo, 'N2', 'pt-BR') + CASE WHEN ISNULL(@Limite, 0) > 0 THEN N' (limite ' + FORMAT(@Limite, 'N2', 'pt-BR') + N')' ELSE N'' END
                    + N', menor que o valor transferido. A conta ficará negativa.', @IdContaOrigem, 'valor');

        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r
                              ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #C; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF (EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5)
           OR EXISTS (SELECT 1 FROM #Regra r WHERE r.NIVEL = 'AVISO'
                        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@AvisosConfirmados, N',') s WHERE LTRIM(RTRIM(s.value)) = r.CODIGO))
            SET @Pendente = 1;

        IF @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Pendente = 0 THEN N'Nada a confirmar.'
                             WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5
                                  THEN N'Informe o motivo (justificativa) para gravar a transferência.'
                             ELSE N'Confira os avisos antes de gravar.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_LOTE, @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #C; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Gravação
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Gravação';
        SET @Usuario     = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'sistema');
        SET @HistOrigem  = LEFT(N'Transferência para ' + @NomeDestino + CASE WHEN @Historico <> N'' THEN N': ' + @Historico ELSE N'' END, 200);
        SET @HistDestino = LEFT(N'Transferência de ' + @NomeOrigem + CASE WHEN @Historico <> N'' THEN N': ' + @Historico ELSE N'' END, 200);

        BEGIN TRANSACTION;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'TRANSFERENCIA', @Descricao = @HistOrigem,
             @TabelaReferencia = N'FIN.Transferencia', @IdReferencia = NULL, @IdLote = @IdLote OUTPUT;

        INSERT INTO FIN.Transferencia (DT_TRANSFERENCIA, ID_CONTA_ORIGEM, ID_CONTA_DESTINO, VALOR, HISTORICO, DOCUMENTO, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
        VALUES (@DtTransferencia, @IdContaOrigem, @IdContaDestino, @Valor, @Historico, @Documento, 'ATIVA', @IdLote, @Usuario);
        SET @Id = SCOPE_IDENTITY();

        INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_TRANSFERENCIA, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
        VALUES (@IdContaOrigem,  @DtTransferencia, -@Valor, 'TRANSFERENCIA', @HistOrigem,  @Documento, @Id, 'ATIVO', @IdLote, @Usuario),
               (@IdContaDestino, @DtTransferencia,  @Valor, 'TRANSFERENCIA', @HistDestino, @Documento, @Id, 'ATIVO', @IdLote, @Usuario);

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Transferencia', @Id, r.CODIGO, r.NIVEL, r.MENSAGEM, CASE WHEN r.NIVEL = 'MOTIVO' THEN @Motivo ELSE N'' END,
               r.ID_REFERENCIA, @IdUsuario, @Usuario
        FROM #Regra r
        WHERE r.NIVEL IN ('AVISO', 'MOTIVO');

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = 1;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Transferência gravada.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID, @IdLote AS ID_LOTE,
               CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #C; DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #C; DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a transferência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
