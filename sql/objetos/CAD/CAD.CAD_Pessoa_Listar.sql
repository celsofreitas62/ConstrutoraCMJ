/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Pessoas" e busca de pessoa nos outros cadastros. @Busca procura
                por parte do nome ou do nome fantasia, pelo início do CPF/CNPJ (com ou
                sem pontuação) e pelo código da pessoa. @Papel: CLIENTE, FORNECEDOR,
                FUNCIONARIO ou CORRETOR (vazio = todos). CPF sai MASCARADO na lista
                (LGPD); completo só no CAD_Pessoa_Obter.
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Listar @IdUsuario = 2, @Busca = N'silva';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Listar]
    @IdUsuario     INT,
    @Busca         NVARCHAR(100) = NULL,
    @Papel         VARCHAR(12)   = NULL,
    @SomenteAtivos BIT           = 1,
    @Limite        INT           = 500
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Doc        VARCHAR(30);
    DECLARE @BuscaId    INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Papel  = UPPER(LTRIM(RTRIM(ISNULL(@Papel, ''))));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 5000 THEN @Limite ELSE 500 END;
        IF @Papel NOT IN ('', 'CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR')
            THROW 50001, N'Papel inválido para o filtro.', 1;

        SET @Like    = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Doc     = CAD.fn_CAD_Documento_Limpo(@Busca);
        SET @BuscaId = TRY_CONVERT(INT, @Busca);

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, CASE WHEN p.TIPO_PESSOA = 'F' THEN 1 ELSE 0 END) AS DOCUMENTO,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.CIDADE, p.UF,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO = 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS EMAIL_PRINCIPAL,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO <> 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS TELEFONE_PRINCIPAL,
               p.ATIVO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Pessoa p WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 1) = 0 OR p.ATIVO = 1)
          AND (   @Papel = ''
               OR (@Papel = 'CLIENTE' AND p.CLIENTE = 1) OR (@Papel = 'FORNECEDOR' AND p.FORNECEDOR = 1)
               OR (@Papel = 'FUNCIONARIO' AND p.FUNCIONARIO = 1) OR (@Papel = 'CORRETOR' AND p.CORRETOR = 1))
          AND (   @Busca = N''
               OR p.NOME LIKE @Like
               OR p.NOME_FANTASIA LIKE @Like
               OR (LEN(@Doc) >= 3 AND p.CPF_CNPJ LIKE @Doc + '%')
               OR p.ID_PESSOA = @BuscaId)
        ORDER BY p.NOME, p.ID_PESSOA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as pessoas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
