/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Enfileirar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Única porta de entrada da fila de e-mails (PADRAO_EMAIL seção
                1). Chamada pelas orquestradoras e rotinas, nunca pela tela.
                Só faz INSERT: quem envia é o serviço.
                - Destinatários: ";" ou "," como separador; endereços
                  inválidos são descartados (e registrados no log); sem
                  nenhum válido, não grava e devolve @IdEmail = NULL.
                - @ChaveOrigem repetida: não grava de novo; devolve o
                  @IdEmail que já existe (o mesmo aviso nunca sai duas
                  vezes).
                - Banco _LOCAL (teste): o e-mail vai só para o parâmetro
                  EMAIL_TESTE, com "[TESTE]" no assunto e o endereço pedido
                  guardado em PARA_ORIGINAL (MODO_TESTE = 1). Proteção
                  extra, além do @bRunLocal das orquestradoras.
                  Exceção: tipo listado em EMAIL_LOCAL_LIBERADOS (separado
                  por vírgula) sai de verdade mesmo no _LOCAL (v1.1).
                - Assunto sem quebra de linha (texto puro, regra 14).
                - @Anexos: JSON '[{"caminho":"C:\\...\\a.pdf","nome":"a.pdf",
                  "cid":""}]'.
                - ID_LOTE vem do contexto da sessão, se houver.
                Se quem chamou já está numa transação, o INSERT entra nela
                (sai junto com a operação de negócio, ou não sai).
                Erro interno: grava em SIS.Log_Erro e devolve @IdEmail NULL
                (falha de e-mail não desfaz a operação de negócio), salvo se
                a transação de quem chamou ficou condenada (aí repassa o
                erro).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (17/11/2026) - Exceção controlada à proteção do banco _LOCAL (pedido
                        do Celso, 03c): tipos listados no parâmetro
                        EMAIL_LOCAL_LIBERADOS (ex.: COMUNICADO) saem para os
                        destinatários reais. Vazio = tudo desviado, como antes.

  Homologação (LOCAL):
    -- DECLARE @Id BIGINT;
    -- EXEC SIS.SIS_Email_Enfileirar @Para = N'x@y.com', @Assunto = N'Teste', @CorpoHTML = N'<p>oi</p>',
    --      @Tipo = 'TESTE', @Origem = N'manual', @IdEmail = @Id OUTPUT; SELECT @Id;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Enfileirar]
    @Para         NVARCHAR(MAX),
    @Assunto      NVARCHAR(400),
    @CorpoHTML    NVARCHAR(MAX),
    @Tipo         VARCHAR(30),
    @Origem       NVARCHAR(256),
    @ChaveOrigem  NVARCHAR(200) = NULL,
    @Cc           NVARCHAR(MAX) = NULL,
    @Cco          NVARCHAR(MAX) = NULL,
    @Grupo        VARCHAR(30)   = NULL,
    @Conta        VARCHAR(10)   = 'INTERNA',
    @Anexos       NVARCHAR(MAX) = NULL,
    @IdEmail      BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Enfileirar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Destinatários';
    DECLARE @ParaOk      NVARCHAR(MAX);
    DECLARE @CcOk        NVARCHAR(MAX);
    DECLARE @CcoOk       NVARCHAR(MAX);
    DECLARE @Invalidos   NVARCHAR(MAX);
    DECLARE @ParaOrig    NVARCHAR(MAX) = N'';
    DECLARE @Teste       BIT           = CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 1 ELSE 0 END;
    DECLARE @IdLote      BIGINT        = TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE'));
    DECLARE @MinhaTran   BIT           = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    SET @IdEmail = NULL;

    BEGIN TRY
        SET @ChaveOrigem = NULLIF(LTRIM(RTRIM(@ChaveOrigem)), N'');
        SET @Tipo        = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Conta       = UPPER(LTRIM(RTRIM(ISNULL(@Conta, 'INTERNA'))));
        SET @Assunto     = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Assunto, N''), NCHAR(13) + NCHAR(10), N' '), NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' ')));

        IF @ChaveOrigem IS NOT NULL
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            IF @IdEmail IS NOT NULL RETURN;
        END;

        -- Separa válidos e inválidos (sem repetir, na ordem em que vieram)
        WITH e AS
        (
            SELECT x.LISTA, LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
            FROM (VALUES (1, ISNULL(@Para, N'')), (2, ISNULL(@Cc, N'')), (3, ISNULL(@Cco, N''))) x (LISTA, TEXTO)
            CROSS APPLY STRING_SPLIT(REPLACE(x.TEXTO, N',', N';'), N';', 1) s
            WHERE LTRIM(RTRIM(s.value)) <> N''
            GROUP BY x.LISTA, LTRIM(RTRIM(s.value))
        )
        SELECT @ParaOk    = STRING_AGG(CASE WHEN e.LISTA = 1 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcOk      = STRING_AGG(CASE WHEN e.LISTA = 2 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcoOk     = STRING_AGG(CASE WHEN e.LISTA = 3 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @Invalidos = STRING_AGG(CASE WHEN SIS.fn_SIS_Email_Valido(e.EMAIL) = 0 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM)
        FROM e;

        SET @ParaOk = ISNULL(@ParaOk, N'');
        SET @CcOk   = ISNULL(@CcOk, N'');
        SET @CcoOk  = ISNULL(@CcoOk, N'');

        IF ISNULL(@Invalidos, N'') <> N''
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'Endereços inválidos descartados (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N'): ' + @Invalidos, 4000), 0, SYSDATETIME());

        IF @ParaOk = N''
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'E-mail não enfileirado: nenhum destinatário válido (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N' / ' + @Assunto + N').', 4000), 0, SYSDATETIME());
            RETURN;
        END;

        SET @EtapaAtual = 'Modo teste';
        IF @Teste = 1
           AND EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOCAL_LIBERADOS'), N''), N',') l
                       WHERE UPPER(LTRIM(RTRIM(l.value))) = UPPER(@Tipo))
            SET @Teste = 0;   -- tipo liberado: sai para os destinatários reais

        IF @Teste = 1
        BEGIN
            SET @ParaOrig = @ParaOk
                          + CASE WHEN @CcOk  <> N'' THEN N' | cc: '  + @CcOk  ELSE N'' END
                          + CASE WHEN @CcoOk <> N'' THEN N' | cco: ' + @CcoOk ELSE N'' END;
            SET @ParaOk   = ISNULL(SIS.fn_SIS_Parametro('EMAIL_TESTE'), N'');
            SET @CcOk     = N'';
            SET @CcoOk    = N'';
            SET @Assunto  = N'[TESTE] ' + @Assunto;

            IF SIS.fn_SIS_Email_Valido(@ParaOk) = 0
            BEGIN
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, 0, N'E-mail não enfileirado: parâmetro EMAIL_TESTE vazio ou inválido.', 0, SYSDATETIME());
                RETURN;
            END;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @MinhaTran = 1 BEGIN TRANSACTION;

        INSERT INTO SIS.Email_Fila (CHAVE_ORIGEM, TIPO, CONTA, GRUPO, PARA, CC, CCO, PARA_ORIGINAL, ASSUNTO, CORPO_HTML, ORIGEM, ID_LOTE, MODO_TESTE)
        VALUES (@ChaveOrigem, @Tipo, @Conta, LTRIM(RTRIM(ISNULL(@Grupo, ''))), LEFT(@ParaOk, 2000), LEFT(@CcOk, 2000), LEFT(@CcoOk, 2000),
                LEFT(@ParaOrig, 4000), LEFT(@Assunto, 400), ISNULL(@CorpoHTML, N''), LEFT(ISNULL(@Origem, N''), 256), @IdLote, @Teste);

        SET @IdEmail = SCOPE_IDENTITY();

        IF ISNULL(@Anexos, N'') <> N''
            INSERT INTO SIS.Email_Fila_Anexo (ID_EMAIL, CAMINHO, NOME_EXIBICAO, CID, ORDEM)
            SELECT @IdEmail,
                   LTRIM(RTRIM(j.caminho)),
                   ISNULL(NULLIF(LTRIM(RTRIM(j.nome)), N''), RIGHT(LTRIM(RTRIM(j.caminho)), CHARINDEX(N'\', REVERSE(N'\' + LTRIM(RTRIM(j.caminho)))) - 1)),
                   LTRIM(RTRIM(ISNULL(j.cid, ''))),
                   CAST(k.[key] AS SMALLINT) + 1
            FROM OPENJSON(@Anexos) k
            CROSS APPLY OPENJSON(k.value) WITH (caminho NVARCHAR(1000) '$.caminho', nome NVARCHAR(260) '$.nome', cid VARCHAR(60) '$.cid') j
            WHERE LTRIM(RTRIM(ISNULL(j.caminho, N''))) <> N'';

        IF @MinhaTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @MinhaTran = 1 AND @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Mesma chave gravada ao mesmo tempo por outra sessão: devolve a que ficou
        IF ERROR_NUMBER() IN (2601, 2627) AND @ChaveOrigem IS NOT NULL AND XACT_STATE() <> -1
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            RETURN;
        END;

        IF XACT_STATE() = -1 THROW;

        SET @IdEmail = NULL;
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
    END CATCH;
END;
GO
