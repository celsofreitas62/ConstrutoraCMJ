/*******************************************************************************
  Objeto      : [CAD].[CAD_Seletor_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Fonte única das escolhas com busca (componente js/seletor.js) de
                conta do plano (@Tipo = 'PLANO'), centro de custo ('CENTRO') e
                conta bancária ('CONTA'). Só registros ativos e fora da lixeira;
                a busca olha código/número e descrição (sem acento, qualquer parte)
                e, no plano, também o grupo e o subgrupo. @IdEmpresa filtra centros
                e contas; @IdAtual sempre volta (mesmo inativo), para a ficha mostrar
                o valor já gravado. No máximo SELETOR_LIMITE linhas.
                Permissão: VER em qualquer tela que usa essas escolhas (cadastros
                de parceiro, empresa, centro, plano, conta; o FIN entra na 04f).
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e, seletor com busca aprovado pelo Celso).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Seletor_Listar @IdUsuario = 2, @Tipo = 'PLANO', @Busca = N'cimento';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Seletor_Listar]
    @IdUsuario  INT,
    @Tipo       VARCHAR(10),
    @Busca      NVARCHAR(100) = NULL,
    @IdEmpresa  INT           = NULL,
    @IdAtual    INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Seletor_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Limite     INT;
    DECLARE @Termo      NVARCHAR(102);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estas escolhas.', 1;
        SET @Tipo = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        IF @Tipo NOT IN ('PLANO', 'CENTRO', 'CONTA')
            THROW 50001, N'Escolha inválida.', 1;

        SET @Limite = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SELETOR_LIMITE'), 50);
        IF @Limite NOT BETWEEN 10 AND 500 SET @Limite = 50;
        SET @Busca = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Termo = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

        SET @EtapaAtual = 'Consulta';
        IF @Tipo = 'PLANO'
            SELECT TOP (@Limite) v.ID, v.CODIGO, v.DESCRICAO, v.COMPLEMENTO, v.ATIVO
            FROM (SELECT v.ID_PLANO_CONTA AS ID, v.CODIGO, v.DESCRICAO, v.GRUPO_DESCRICAO + N' › ' + v.SUBGRUPO_DESCRICAO AS COMPLEMENTO,
                         v.ATIVO_EFETIVO AS ATIVO, v.ORDEM_ARVORE
                  FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
                  INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
                  WHERE pc.DT_EXCLUSAO IS NULL
                    AND (v.ID_PLANO_CONTA = @IdAtual
                         OR (v.ATIVO_EFETIVO = 1
                             AND (@Busca = N'' OR v.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR v.SUBGRUPO_DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR v.GRUPO_DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR v.CODIGO LIKE @Busca + '%')))
                 ) v
            ORDER BY CASE WHEN v.ID = @IdAtual THEN 0 ELSE 1 END, v.ORDEM_ARVORE;
        ELSE IF @Tipo = 'CENTRO'
            SELECT TOP (@Limite) cc.ID_CENTRO_CUSTO AS ID, cc.CODIGO, cc.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN N' · encerrado em ' + CONVERT(NVARCHAR(10), cc.DT_ENCERRAMENTO, 103) ELSE N'' END AS COMPLEMENTO,
                   cc.ATIVO
            FROM CAD.Centro_Custo cc WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
            WHERE cc.DT_EXCLUSAO IS NULL
              AND (cc.ID_CENTRO_CUSTO = @IdAtual
                   OR (cc.ATIVO = 1 AND (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR cc.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR cc.CODIGO LIKE @Busca + '%')))
            ORDER BY CASE WHEN cc.ID_CENTRO_CUSTO = @IdAtual THEN 0 ELSE 1 END, cc.CODIGO;
        ELSE
            SELECT TOP (@Limite) c.ID_CONTA AS ID, CAST(c.ID_CONTA AS VARCHAR(20)) AS CODIGO, c.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN c.NUMERO <> '' THEN N' · ag. ' + c.AGENCIA + N' c/c ' + c.NUMERO + CASE WHEN c.NUMERO_DV <> '' THEN N'-' + c.NUMERO_DV ELSE N'' END ELSE N'' END AS COMPLEMENTO,
                   c.ATIVO
            FROM BANCO.Conta c WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
            WHERE c.DT_EXCLUSAO IS NULL
              AND (c.ID_CONTA = @IdAtual
                   OR (c.ATIVO = 1 AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR c.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR c.NUMERO LIKE @Busca + '%')))
            ORDER BY CASE WHEN c.ID_CONTA = @IdAtual THEN 0 ELSE 1 END, e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
