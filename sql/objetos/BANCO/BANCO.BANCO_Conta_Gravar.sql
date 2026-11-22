/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdConta NULL) ou altera uma conta da empresa. Conta de banco
                (corrente, poupança, aplicação) exige banco, agência e número; caixa e
                permuta não usam banco. Descrição única dentro da empresa. Saldo
                inicial diferente de zero exige a data.
                Permissão: INCLUIR ou ALTERAR em BANCO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Descricao = N'Caixa Construtora', @Tipo = 'CAIXA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Gravar]
    @IdUsuario         INT,
    @IdConta           INT           = NULL,
    @IdEmpresa         INT,
    @Descricao         NVARCHAR(60),
    @Tipo              VARCHAR(10),
    @IdBanco           INT           = NULL,
    @Agencia           VARCHAR(10)   = NULL,
    @AgenciaDv         VARCHAR(2)    = NULL,
    @Numero            VARCHAR(20)   = NULL,
    @NumeroDv          VARCHAR(2)    = NULL,
    @LimiteCredito     DECIMAL(18,2) = 0,
    @SaldoInicial      DECIMAL(18,2) = 0,
    @DtSaldoInicial    DATE          = NULL,
    @Concilia          BIT           = 0,
    @MostraSaldo       BIT           = 1,
    @ContaContabilRef  VARCHAR(30)   = NULL,
    @Ordem             SMALLINT      = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao        = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo             = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Agencia          = CAD.fn_CAD_Somente_Digitos(@Agencia);
        SET @AgenciaDv        = UPPER(LTRIM(RTRIM(ISNULL(@AgenciaDv, ''))));
        SET @Numero           = CAD.fn_CAD_Somente_Digitos(@Numero);
        SET @NumeroDv         = UPPER(LTRIM(RTRIM(ISNULL(@NumeroDv, ''))));
        SET @LimiteCredito    = ISNULL(@LimiteCredito, 0);
        SET @SaldoInicial     = ISNULL(@SaldoInicial, 0);
        SET @Concilia         = ISNULL(@Concilia, 0);
        SET @MostraSaldo      = ISNULL(@MostraSaldo, 1);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));
        SET @Ordem            = ISNULL(@Ordem, 0);
        IF @Tipo IN ('CAIXA', 'PERMUTA')
            SELECT @IdBanco = NULL, @Agencia = '', @AgenciaDv = '', @Numero = '', @NumeroDv = '';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', CASE WHEN @IdConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar contas bancárias.';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'BANCO.Conta', @IdConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta)
            SET @Recusa = N'Conta não encontrada.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa como titular da conta.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição da conta (ex.: Sicredi Orion).';
        IF @Recusa = N'' AND @Tipo NOT IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')
            SET @Recusa = N'Tipo de conta inválido.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA')
           AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco AND b.ATIVO = 1)
            SET @Recusa = N'Escolha o banco da conta.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA') AND (@Agencia = '' OR @Numero = '')
            SET @Recusa = N'Informe a agência e o número da conta.';
        IF @Recusa = N'' AND @SaldoInicial <> 0 AND @DtSaldoInicial IS NULL
            SET @Recusa = N'Informe a data do saldo inicial.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.DESCRICAO = @Descricao AND c.ID_CONTA <> ISNULL(@IdConta, 0))
            SET @Recusa = N'Esta empresa já tem uma conta com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdConta IS NULL
        BEGIN
            INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, NUMERO, NUMERO_DV, LIMITE_CREDITO,
                                     SALDO_INICIAL, DT_SALDO_INICIAL, CONCILIA, MOSTRA_SALDO, CONTA_CONTABIL_REF, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Descricao, @Tipo, @IdBanco, @Agencia, @AgenciaDv, @Numero, @NumeroDv, @LimiteCredito,
                    @SaldoInicial, @DtSaldoInicial, @Concilia, @MostraSaldo, @ContaContabilRef, @Ordem, @Usuario);
            SET @IdConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_EMPRESA = @IdEmpresa, c.DESCRICAO = @Descricao, c.TIPO = @Tipo, c.ID_BANCO = @IdBanco,
                   c.AGENCIA = @Agencia, c.AGENCIA_DV = @AgenciaDv, c.NUMERO = @Numero, c.NUMERO_DV = @NumeroDv,
                   c.LIMITE_CREDITO = @LimiteCredito, c.SALDO_INICIAL = @SaldoInicial, c.DT_SALDO_INICIAL = @DtSaldoInicial,
                   c.CONCILIA = @Concilia, c.MOSTRA_SALDO = @MostraSaldo, c.CONTA_CONTABIL_REF = @ContaContabilRef, c.ORDEM = @Ordem,
                   c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Conta c
            WHERE c.ID_CONTA = @IdConta;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Conta gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a conta. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO
