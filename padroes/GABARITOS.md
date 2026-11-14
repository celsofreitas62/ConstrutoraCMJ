# Gabaritos de Objetos T-SQL do SistemaCMJ

Esqueletos estruturais para copiar o **formato de construção**, nunca as regras de negócio. Todos seguem [PADRAO_SQL.md](PADRAO_SQL.md) e [PADRAO_EMAIL.md](PADRAO_EMAIL.md). Os nomes de tabela são ilustrativos: conferir o DDL real em `sql/` antes de usar.

---

## 1. Cabeçalho padrão (todo objeto)

```sql
/*******************************************************************************
  Objeto      : [FIN].[FIN_Titulo_Baixar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 13/11/2026
  Descrição   : Baixa (total ou parcial) de um título a pagar/receber.

  Changelog:
    v1.0 (13/11/2026) - Criação.
    v1.1 (dd/mm/aaaa) - <o que mudou e por quê>.

  Homologação (rodar manualmente no LOCAL):
    -- EXEC FIN.FIN_Titulo_Baixar @IdTitulo = 1, @ValorPago = 100.00, @DataPagto = '2026-11-13', @Usuario = 'teste';
*******************************************************************************/
SET QUOTED_IDENTIFIER ON;
GO
```

## 2. Procedure chamada pela API (tela)

Devolve sempre **1 linha** `SUCESSO` / `MENSAGEM` / dados extras, com os mesmos tipos em todos os caminhos.

```sql
CREATE OR ALTER PROCEDURE [FIN].[FIN_Titulo_Baixar]
    @IdTitulo   INT,
    @ValorPago  DECIMAL(18,2),
    @DataPagto  DATE,
    @Usuario    NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Titulo_Baixar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @IdBaixa    INT;

    BEGIN TRY
        -- Early returns de negócio (recusa amigável, sem erro técnico)
        IF ISNULL(@ValorPago, 0) <= 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe um valor pago maior que zero.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_BAIXA;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            -- Leitura que decide a escrita: trava a linha até o COMMIT
            IF NOT EXISTS (SELECT 1 FROM FIN.Titulo t WITH (UPDLOCK, HOLDLOCK)
                           WHERE t.ID_TITULO = @IdTitulo AND t.SITUACAO = 'A')
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Título não encontrado ou já liquidado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_BAIXA;
                RETURN;
            END;

            INSERT INTO FIN.Titulo_Baixa (ID_TITULO, DT_PAGAMENTO, VALOR_PAGO, USUARIO_CRIACAO)
            VALUES (@IdTitulo, @DataPagto, @ValorPago, @Usuario);
            SET @IdBaixa = SCOPE_IDENTITY();

            -- ... atualiza saldo/situação do título (set-based, filtro "already correct")

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Baixa registrada.' AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID_BAIXA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar a baixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_BAIXA;
    END CATCH;
END;
GO
```

## 3. Procedure de negócio/cálculo (motor transacional, tudo-ou-nada)

Ex.: gerar as parcelas de um contrato de venda. Calcula fora da transação, grava tudo dentro, notifica depois.

```sql
CREATE OR ALTER PROCEDURE [VENDA].[VENDA_Contrato_Gerar_Parcelas]
    @IdContrato INT,
    @Usuario    NVARCHAR(100),
    @bRunLocal  BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @bRunLocal = ISNULL(@bRunLocal, CASE WHEN DB_NAME() LIKE '%[_]LOCAL' THEN 1 ELSE 0 END);

    DECLARE @NomeProc   NVARCHAR(128) = N'[VENDA].[VENDA_Contrato_Gerar_Parcelas]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Início';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @QtdGerada  INT = 0;

    DROP TABLE IF EXISTS #Parcelas;

    BEGIN TRY
        SET @EtapaAtual = 'Cálculo das parcelas';
        -- 1) Calcula tudo em #Parcelas (fora da transação): entrada, mensais, intermediárias,
        --    chaves; arredonda cada uma em 2 casas; a última absorve a diferença de centavos.
        -- ...
        IF NOT EXISTS (SELECT 1 FROM #Parcelas)
        BEGIN
            DROP TABLE IF EXISTS #Parcelas;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @TranCountEntrada = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION GerarParcelas;

            INSERT INTO FIN.Titulo (...)
            SELECT ... FROM #Parcelas p;
            SET @QtdGerada = @@ROWCOUNT;

        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Parcelas;

        -- 2) Notificação fora da transação (só enfileira)
        IF @QtdGerada > 0
            EXEC FIN.FIN_Email_Orquestrador @TipoEmail = 'CONTRATO_PARCELAS', @IdReferencia = @IdContrato, @bRunLocal = @bRunLocal;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (@TranCountEntrada = 0 AND @@TRANCOUNT > 0)
            ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 AND @TranCountEntrada > 0
            ROLLBACK TRANSACTION GerarParcelas;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Parcelas;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        THROW;
    END CATCH;
END;
GO
```

## 4. Orquestradora de e-mail (monta e enfileira)

```sql
CREATE OR ALTER PROCEDURE [FIN].[FIN_Email_Orquestrador]
    @TipoEmail     VARCHAR(30),
    @IdReferencia  INT  = NULL,
    @bRunLocal     BIT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @bRunLocal = ISNULL(@bRunLocal, CASE WHEN DB_NAME() LIKE '%[_]LOCAL' THEN 1 ELSE 0 END);

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Email_Orquestrador]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Destinatários';
    DECLARE @Para         NVARCHAR(MAX) = N'';
    DECLARE @Assunto      NVARCHAR(400) = N'';
    DECLARE @CorpoHTML    NVARCHAR(MAX) = N'';
    DECLARE @Linhas       NVARCHAR(MAX) = N'';
    DECLARE @Grupo        VARCHAR(30)   = '';

    BEGIN TRY
        IF @TipoEmail = 'VENC_PAGAR' SET @Grupo = 'FIN_PAGAR';
        -- ... demais rotas

        SET @Para = SIS.fn_SIS_Emails_Do_Grupo(@Grupo);           -- nunca devolve NULL
        IF @bRunLocal = 1 SET @Para = SIS.fn_SIS_Parametro('EMAIL_TESTE');
        IF ISNULL(@Para, N'') = N''
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, N'Grupo ' + @Grupo + N' sem e-mail válido.', 0, SYSDATETIME());
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem do HTML';
        SELECT @Linhas = STRING_AGG(CAST(
                 N'<tr style="background:' + CASE WHEN x.RN % 2 = 0 THEN N'#f5f5f5' ELSE N'#ffffff' END + N'">'
               + N'<td style="padding:6px;border:1px solid #eeeeee;text-align:center">' + ISNULL(CONVERT(NVARCHAR(10), x.DT_VENCIMENTO, 103), N'-') + N'</td>'
               + N'<td style="padding:6px;border:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(x.FAVORECIDO) + N'</td>'
               + N'<td style="padding:6px;border:1px solid #eeeeee;text-align:right">' + SIS.fn_SIS_Formatar_Moeda(x.VALOR) + N'</td>'
               + N'</tr>' AS NVARCHAR(MAX)), N'') WITHIN GROUP (ORDER BY x.RN)
        FROM ( /* consulta da rota com WITH (NOLOCK) e ROW_NUMBER() AS RN */ ) x;

        IF ISNULL(@Linhas, N'') = N'' RETURN;   -- nada a avisar, nenhum e-mail

        SET @Assunto = CASE WHEN @bRunLocal = 1 THEN N'[TESTE] ' ELSE N'' END
                     + N'CMJ - Contas a pagar vencendo hoje';

        SET @CorpoHTML = N'<div style="font-family:Arial,Segoe UI,sans-serif;max-width:700px;margin:auto;background:#ffffff;box-shadow:0 1px 4px #cccccc">'
            + N'<div style="background:#1F4E79;color:#ffffff;padding:14px;font-weight:bold;text-transform:uppercase">Contas a pagar - vencimento hoje</div>'
            + N'<div style="padding:16px"><table style="border-collapse:collapse;width:100%;font-size:13px">'
            + N'<tr style="background:#1F4E79;color:#ffffff"><th style="padding:6px">Vencimento</th><th style="padding:6px">Favorecido</th><th style="padding:6px">Valor</th></tr>'
            + @Linhas + N'</table></div>'
            + N'<div style="background:#f9f9f9;color:#777777;font-size:11px;padding:10px">'
            + N'Gerado automaticamente pelo sistema SistemaCMJ: ' + @NomeProc + N'<br>'
            + N'Emitido em: ' + FORMAT(SYSDATETIME(), 'dd/MM/yyyy HH:mm') + N'<br>'
            + N'Grupo de Destinatários: ' + @Grupo + N'<br>'
            + N'<b>' + SIS.fn_SIS_Parametro('EMPRESA_RAZAO_SOCIAL') + N'</b></div></div>';

        SET @EtapaAtual = 'Enfileiramento';
        INSERT INTO SIS.Email_Fila (ID_EMAIL, CHAVE_ORIGEM, PARA, ASSUNTO, CORPO_HTML, ANEXOS, STATUS, ORIGEM, DT_CRIACAO)
        VALUES (NEWID(), NULL, @Para, @Assunto, @CorpoHTML, NULL, 'PENDENTE', @NomeProc, SYSDATETIME());
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
```

## 5. Trigger (AFTER INSERT, UPDATE, set-based)

```sql
CREATE OR ALTER TRIGGER [FIN].[tg_FIN_Titulo_Historico]
ON [FIN].[Titulo]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF TRIGGER_NESTLEVEL(@@PROCID) > 1 RETURN;

    DECLARE @NomeProc NVARCHAR(128) = N'[FIN].[tg_FIN_Titulo_Historico]';
    DECLARE @Usuario  NVARCHAR(100) = ISNULL(CAST(SESSION_CONTEXT(N'USUARIO') AS NVARCHAR(100)), SUSER_SNAME());

    BEGIN TRY
        -- Só registra o que mudou de verdade (inserted x deleted), sem variável de I/U/D
        INSERT INTO FIN.Titulo_Historico (ID_TITULO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, DT_ALTERACAO)
        SELECT i.ID_TITULO, 'VALOR', CAST(d.VALOR AS NVARCHAR(50)), CAST(i.VALOR AS NVARCHAR(50)), @Usuario, SYSDATETIME()
        FROM inserted i
        INNER JOIN deleted d ON d.ID_TITULO = i.ID_TITULO
        WHERE ISNULL(d.VALOR, -1) <> ISNULL(i.VALOR, -1);
        -- ... demais campos sensíveis (vencimento, situação)
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, 'Histórico', ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;   -- trigger de integridade/auditoria propaga; trigger que só notifica NÃO propaga
    END CATCH;
END;
GO
```

## 6. Function escalar de lookup

```sql
CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Emails_Do_Grupo] (@Grupo VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    SET @Grupo = ISNULL(@Grupo, '');
    IF @Grupo = '' RETURN N'';

    DECLARE @Emails NVARCHAR(MAX);

    SELECT @Emails = STRING_AGG(CONVERT(NVARCHAR(MAX), LTRIM(RTRIM(ISNULL(d.EMAIL, N'')))), N'; ')
    FROM SIS.Grupo_Email_Destinatario d WITH (NOLOCK)
    INNER JOIN SIS.Grupo_Email g WITH (NOLOCK) ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL
    WHERE g.CODIGO = @Grupo
      AND ISNULL(d.ATIVO, 0) = 1
      AND ISNULL(d.EMAIL, N'') <> N'';

    RETURN ISNULL(@Emails, N'');
END;
GO
```
