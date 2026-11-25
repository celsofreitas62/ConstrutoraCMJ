/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Ficha completa de uma pessoa (uma linha), com CPF/CNPJ completo e
                formatado, e os ativos de contatos, vínculos e dados bancários em
                colunas JSON (CONTATOS, VINCULOS, DADOS_BANCARIOS), no mesmo formato
                que o CAD_Pessoa_Gravar recebe. DOCUMENTO_REPETIDO: quantas outras
                pessoas têm o mesmo documento (só aviso).
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): coluna NA_LIXEIRA (registro na lixeira: a ficha abre só para consulta).
    v1.2 (25/11/2026) - Etapa 04d (P12, P10, P17): TIPOS (JSON com id, código, descrição, sistema),
                        finalidade nos contatos, conta/centro padrão e APTO_COBRANCA/PENDENCIA_COBRANCA.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Obter @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Obter]
    @IdUsuario  INT,
    @IdPessoa   INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.ID_PESSOA = @IdPessoa)
            THROW 50001, N'Pessoa não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA, p.CPF_CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, 0) AS DOCUMENTO_FORMATADO,
               p.RG, p.ORGAO_EMISSOR, p.INSCRICAO_ESTADUAL, p.INSCRICAO_MUNICIPAL, p.DT_NASCIMENTO,
               p.NACIONALIDADE, p.PROFISSAO, p.ESTADO_CIVIL, p.REGIME_BENS,
               p.CEP, p.LOGRADOURO, p.NUMERO, p.COMPLEMENTO, p.BAIRRO, p.CIDADE, p.UF,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.OBSERVACAO, p.ATIVO, p.CODIGO_ACCESS,
               p.DT_CRIACAO, p.USUARIO_CRIACAO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               CAST(CASE WHEN p.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               p.ID_PLANO_CONTA_PADRAO, p.ID_CENTRO_CUSTO_PADRAO,
               ISNULL((SELECT CONVERT(NVARCHAR(12), c.CODIGO) + N' - ' + c.DESCRICAO FROM CAD.vw_CAD_Plano_Conta c WHERE c.ID_PLANO_CONTA = p.ID_PLANO_CONTA_PADRAO), N'') AS PLANO_CONTA_PADRAO,
               ISNULL((SELECT CONVERT(NVARCHAR(30), cc.CODIGO) + N' - ' + cc.DESCRICAO FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = p.ID_CENTRO_CUSTO_PADRAO), N'') AS CENTRO_CUSTO_PADRAO,
               f.APTO AS APTO_COBRANCA, f.PENDENCIA AS PENDENCIA_COBRANCA,
               ISNULL((SELECT t.ID_PARCEIRO_TIPO AS id, t.CODIGO AS codigo, t.DESCRICAO AS descricao, t.SISTEMA AS sistema
                       FROM CAD.Pessoa_Tipo x WITH (NOLOCK)
                       INNER JOIN CAD.Parceiro_Tipo t WITH (NOLOCK) ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                       WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1
                       ORDER BY t.ORDEM, t.DESCRICAO
                       FOR JSON PATH), N'[]') AS TIPOS,
               CASE WHEN p.CPF_CNPJ = '' THEN 0
                    ELSE (SELECT COUNT(*) FROM CAD.Pessoa o WITH (NOLOCK) WHERE o.CPF_CNPJ = p.CPF_CNPJ AND o.ID_PESSOA <> p.ID_PESSOA) END AS DOCUMENTO_REPETIDO,
               ISNULL((SELECT pc.ID_PESSOA_CONTATO AS id, pc.TIPO AS tipo, pc.VALOR AS valor, pc.NOME_CONTATO AS nome,
                              pc.PRINCIPAL AS principal, pc.RECEBE_COBRANCA AS recebeCobranca, pc.FINALIDADE AS finalidade
                       FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1
                       ORDER BY pc.TIPO, pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO
                       FOR JSON PATH), N'[]') AS CONTATOS,
               ISNULL((SELECT pv.ID_PESSOA_VINCULADA AS idPessoaVinculada, v.NOME AS nome, pv.TIPO AS tipo, pv.OBSERVACAO AS observacao
                       FROM CAD.Pessoa_Vinculo pv WITH (NOLOCK)
                       INNER JOIN CAD.Pessoa v WITH (NOLOCK) ON v.ID_PESSOA = pv.ID_PESSOA_VINCULADA
                       WHERE pv.ID_PESSOA = p.ID_PESSOA AND pv.ATIVO = 1
                       ORDER BY pv.TIPO, v.NOME
                       FOR JSON PATH), N'[]') AS VINCULOS,
               ISNULL((SELECT d.ID_PESSOA_DADO_BANCARIO AS id, d.TIPO AS tipo, d.ID_BANCO AS idBanco, ISNULL(b.CODIGO, '') AS bancoCodigo,
                              ISNULL(b.NOME, N'') AS bancoNome, d.AGENCIA AS agencia, d.AGENCIA_DV AS agenciaDv, d.CONTA AS conta,
                              d.CONTA_DV AS contaDv, d.TIPO_CONTA AS tipoConta, d.TITULAR_NOME AS titularNome,
                              d.TITULAR_DOCUMENTO AS titularDocumento, d.PIX_TIPO AS pixTipo, d.PIX_CHAVE AS pixChave, d.PRINCIPAL AS principal
                       FROM CAD.Pessoa_Dado_Bancario d WITH (NOLOCK)
                       LEFT JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = d.ID_BANCO
                       WHERE d.ID_PESSOA = p.ID_PESSOA AND d.ATIVO = 1
                       ORDER BY d.PRINCIPAL DESC, d.ID_PESSOA_DADO_BANCARIO
                       FOR JSON PATH), N'[]') AS DADOS_BANCARIOS
        FROM CAD.Pessoa p WITH (NOLOCK)
        CROSS APPLY CAD.fn_CAD_Pessoa_Pendencia_Cobranca(p.ID_PESSOA) f
        WHERE p.ID_PESSOA = @IdPessoa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a pessoa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
