/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de uma empresa (tela CAD_EMPRESA): todos os campos, o
                rodapé dos e-mails (P11), a pasta do OFX (PODE_PASTA_OFX = 1 só
                para administrador), a conta padrão, quantas contas e centros de
                custo ativos ela tem e NA_LIXEIRA (ficha só para consulta).
                Permissão: VER em CAD_EMPRESA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Obter @IdUsuario = 2, @IdEmpresa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Obter]
    @IdUsuario  INT,
    @IdEmpresa  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Empresa e WITH (NOLOCK) WHERE e.ID_EMPRESA = @IdEmpresa)
            THROW 50001, N'Empresa não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.CNPJ_COMPRAS, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_COMPRAS_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.RODAPE_EMAIL,
               CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) >= 1 THEN e.PASTA_OFX ELSE N'' END AS PASTA_OFX,
               CAST(CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) >= 1 THEN 1 ELSE 0 END AS BIT) AS PODE_PASTA_OFX,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               (SELECT COUNT(*) FROM BANCO.Conta x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CONTAS,
               (SELECT COUNT(*) FROM CAD.Centro_Custo x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CENTROS,
               e.ATIVO, CAST(CASE WHEN e.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               e.CODIGO_ACCESS, e.DT_CRIACAO, e.USUARIO_CRIACAO, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE e.ID_EMPRESA = @IdEmpresa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a empresa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
