/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdEmpresa NULL) ou altera uma empresa do grupo. Pela tela o
                CNPJ é obrigatório e conferido (dígitos verificadores, aceita o
                alfanumérico); não pode repetir. CEP com 8 dígitos, UF com 2 letras,
                e-mail válido. Conta padrão: qualquer conta ativa (escolha no cadastro,
                decisão do Celso).
                CNPJ para notas de compra e DDA (@CnpjCompras): opcional; NULL
                mantém o que está gravado (na inclusão, fica vazio); '' apaga.
                Permissão: INCLUIR ou ALTERAR em CAD_EMPRESA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - @CnpjCompras (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Gravar @IdUsuario = 2, @RazaoSocial = N'Construtora Teste Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'CONSTRUTORA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Gravar]
    @IdUsuario               INT,
    @IdEmpresa               INT           = NULL,
    @RazaoSocial             NVARCHAR(150),
    @NomeFantasia            NVARCHAR(100) = NULL,
    @Cnpj                    VARCHAR(20),
    @Tipo                    VARCHAR(12)   = 'OUTRA',
    @InscricaoEstadual       VARCHAR(20)   = NULL,
    @InscricaoMunicipal      VARCHAR(20)   = NULL,
    @RegimeTributario        VARCHAR(20)   = NULL,
    @Cep                     VARCHAR(10)   = NULL,
    @Logradouro              NVARCHAR(150) = NULL,
    @Numero                  NVARCHAR(20)  = NULL,
    @Complemento             NVARCHAR(60)  = NULL,
    @Bairro                  NVARCHAR(60)  = NULL,
    @Cidade                  NVARCHAR(60)  = NULL,
    @Uf                      CHAR(2)       = NULL,
    @Email                   NVARCHAR(256) = NULL,
    @Telefone                VARCHAR(30)   = NULL,
    @IdContaBancariaPadrao   INT           = NULL,
    @CnpjCompras             VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @RazaoSocial        = LTRIM(RTRIM(ISNULL(@RazaoSocial, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @Cnpj               = CAD.fn_CAD_Documento_Limpo(@Cnpj);
        SET @Tipo               = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, 'OUTRA'))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @RegimeTributario   = UPPER(LTRIM(RTRIM(ISNULL(@RegimeTributario, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Email              = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Telefone           = CAD.fn_CAD_Somente_Digitos(@Telefone);
        IF @CnpjCompras IS NOT NULL SET @CnpjCompras = CAD.fn_CAD_Documento_Limpo(@CnpjCompras);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', CASE WHEN @IdEmpresa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar empresas.';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Empresa', @IdEmpresa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'Empresa não encontrada.';
        IF @Recusa = N'' AND @RazaoSocial = N''
            SET @Recusa = N'Informe a razão social.';
        IF @Recusa = N'' AND (LEN(@Cnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@Cnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CNPJ = @Cnpj AND e.ID_EMPRESA <> ISNULL(@IdEmpresa, 0))
            SET @Recusa = N'Já existe uma empresa cadastrada com este CNPJ.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND (LEN(@CnpjCompras) <> 14 OR CAD.fn_CAD_Documento_Valido(@CnpjCompras) = 0)
            SET @Recusa = N'CNPJ para notas de compra e DDA inválido. Confira os números.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND @CnpjCompras = @Cnpj
            SET @Recusa = N'O CNPJ para notas de compra e DDA é igual ao CNPJ da empresa: deixe em branco.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')
            SET @Recusa = N'Tipo de empresa inválido.';
        IF @Recusa = N'' AND @RegimeTributario NOT IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')
            SET @Recusa = N'Regime tributário inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @Email <> N'' AND SIS.fn_SIS_Email_Valido(@Email) = 0
            SET @Recusa = N'E-mail inválido.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdEmpresa IS NULL
        BEGIN
            INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL, REGIME_TRIBUTARIO,
                                     CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, EMAIL, TELEFONE, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@RazaoSocial, @NomeFantasia, @Cnpj, ISNULL(@CnpjCompras, ''), @Tipo, @InscricaoEstadual, @InscricaoMunicipal, @RegimeTributario,
                    @Cep, @Logradouro, @Numero, @Complemento, @Bairro, @Cidade, @Uf, @Email, @Telefone, @IdContaBancariaPadrao, @Usuario);
            SET @IdEmpresa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE e
               SET e.RAZAO_SOCIAL = @RazaoSocial, e.NOME_FANTASIA = @NomeFantasia, e.CNPJ = @Cnpj, e.CNPJ_COMPRAS = ISNULL(@CnpjCompras, e.CNPJ_COMPRAS), e.TIPO = @Tipo,
                   e.INSCRICAO_ESTADUAL = @InscricaoEstadual, e.INSCRICAO_MUNICIPAL = @InscricaoMunicipal, e.REGIME_TRIBUTARIO = @RegimeTributario,
                   e.CEP = @Cep, e.LOGRADOURO = @Logradouro, e.NUMERO = @Numero, e.COMPLEMENTO = @Complemento, e.BAIRRO = @Bairro,
                   e.CIDADE = @Cidade, e.UF = @Uf, e.EMAIL = @Email, e.TELEFONE = @Telefone, e.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Empresa e
            WHERE e.ID_EMPRESA = @IdEmpresa;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Empresa gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a empresa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO
