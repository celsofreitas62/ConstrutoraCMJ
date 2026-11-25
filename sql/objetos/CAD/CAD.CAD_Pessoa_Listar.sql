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
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04d (P12, P10): filtro @IdParceiroTipo, @PendenciaCobranca (clientes
                        com parcela a receber em aberto e cadastro não apto), colunas TIPOS,
                        APTO_COBRANCA, PENDENCIA_COBRANCA e TITULO_ABERTO.


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
    @Limite        INT           = 500,
    @IdParceiroTipo INT          = NULL,
    @PendenciaCobranca BIT       = 0
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
               p.ATIVO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               ISNULL((SELECT STRING_AGG(t.DESCRICAO, N', ') WITHIN GROUP (ORDER BY t.ORDEM, t.DESCRICAO)
                       FROM CAD.Pessoa_Tipo x WITH (NOLOCK)
                       INNER JOIN CAD.Parceiro_Tipo t WITH (NOLOCK) ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                       WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1), N'') AS TIPOS,
               CASE WHEN p.CLIENTE = 1 THEN f.APTO END AS APTO_COBRANCA,
               CASE WHEN p.CLIENTE = 1 THEN f.PENDENCIA ELSE N'' END AS PENDENCIA_COBRANCA,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (NOLOCK)
                                      INNER JOIN FIN.Parcela pa WITH (NOLOCK) ON pa.ID_LANCAMENTO = l.ID_LANCAMENTO
                                      WHERE l.ID_PESSOA = p.ID_PESSOA AND l.TIPO = 'R' AND l.SITUACAO = 'ATIVO'
                                        AND pa.SITUACAO IN ('ABERTA', 'PARCIAL')) THEN 1 ELSE 0 END AS BIT) AS TITULO_ABERTO
        FROM CAD.Pessoa p WITH (NOLOCK)
        CROSS APPLY CAD.fn_CAD_Pessoa_Pendencia_Cobranca(p.ID_PESSOA) f
        WHERE (ISNULL(@SomenteAtivos, 1) = 0 OR p.ATIVO = 1)
          AND p.DT_EXCLUSAO IS NULL
          AND (@IdParceiroTipo IS NULL
               OR EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WITH (NOLOCK) WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ID_PARCEIRO_TIPO = @IdParceiroTipo AND x.ATIVO = 1))
          AND (ISNULL(@PendenciaCobranca, 0) = 0
               OR (p.CLIENTE = 1 AND f.APTO = 0
                   AND EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (NOLOCK)
                               INNER JOIN FIN.Parcela pa WITH (NOLOCK) ON pa.ID_LANCAMENTO = l.ID_LANCAMENTO
                               WHERE l.ID_PESSOA = p.ID_PESSOA AND l.TIPO = 'R' AND l.SITUACAO = 'ATIVO'
                                 AND pa.SITUACAO IN ('ABERTA', 'PARCIAL'))))
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
