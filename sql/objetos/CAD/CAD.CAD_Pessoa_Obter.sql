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
               CASE WHEN p.CPF_CNPJ = '' THEN 0
                    ELSE (SELECT COUNT(*) FROM CAD.Pessoa o WITH (NOLOCK) WHERE o.CPF_CNPJ = p.CPF_CNPJ AND o.ID_PESSOA <> p.ID_PESSOA) END AS DOCUMENTO_REPETIDO,
               ISNULL((SELECT pc.ID_PESSOA_CONTATO AS id, pc.TIPO AS tipo, pc.VALOR AS valor, pc.NOME_CONTATO AS nome,
                              pc.PRINCIPAL AS principal, pc.RECEBE_COBRANCA AS recebeCobranca
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
