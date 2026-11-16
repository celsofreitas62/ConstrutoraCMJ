/*******************************************************************************
  Objeto      : [SIS].[SIS_Modulo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Módulos e telas" (exclusiva do administrador geral):
                módulos e telas com a situação de cada um.
                Uma linha por módulo (TIPO = 'MODULO') e por tela
                (TIPO = 'TELA'), já na ordem do menu:
                  NA_LICENCA : módulo liberado pela licença ativa;
                  HABILITADO : ligado pelo administrador geral;
                  EM_USO     : aparece para os usuários (licença + módulo
                               habilitado + tela habilitada);
                  PROTEGIDO  : não pode ser desligado (módulo SIS e a própria
                               tela "Módulos e telas").
                Permissão: SIS_MODULO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c, pedido 5 do Celso).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Modulo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Modulo_Listar]
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Modulo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_MODULO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os módulos.', 1;

        SET @EtapaAtual = 'Consulta';
        WITH Arvore AS
        (
            SELECT i.ID_ITEM,
                   CAST(i.NOME AS NVARCHAR(400)) AS CAMINHO_NOME,
                   CAST(RIGHT('00000' + CONVERT(VARCHAR(5), i.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), i.ID_ITEM), 10) AS VARCHAR(400)) AS ORDEM_CAMINHO
            FROM SIS.Item i WITH (NOLOCK)
            WHERE i.ID_ITEM_PAI IS NULL
              AND i.ATIVO = 1
            UNION ALL
            SELECT c.ID_ITEM,
                   CAST(a.CAMINHO_NOME + N' > ' + c.NOME AS NVARCHAR(400)),
                   CAST(a.ORDEM_CAMINHO + '/' + RIGHT('00000' + CONVERT(VARCHAR(5), c.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), c.ID_ITEM), 10) AS VARCHAR(400))
            FROM SIS.Item c WITH (NOLOCK)
            INNER JOIN Arvore a ON a.ID_ITEM = c.ID_ITEM_PAI
            WHERE c.ATIVO = 1
        )
        SELECT x.TIPO, x.CODIGO, x.NOME, x.MODULO_CODIGO, x.EXCLUSIVO_GERAL, x.NA_LICENCA, x.HABILITADO, x.EM_USO, x.PROTEGIDO
        FROM (
                SELECT CAST('MODULO' AS VARCHAR(10))                       AS TIPO,
                       CAST(m.CODIGO AS VARCHAR(40))                       AS CODIGO,
                       CAST(m.NOME AS NVARCHAR(400))                       AS NOME,
                       m.CODIGO                                            AS MODULO_CODIGO,
                       CAST(0 AS BIT)                                      AS EXCLUSIVO_GERAL,
                       m.LIBERADO_LICENCA                                  AS NA_LICENCA,
                       m.HABILITADO,
                       CAST(CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS EM_USO,
                       CAST(CASE WHEN m.CODIGO = 'SIS' THEN 1 ELSE 0 END AS BIT) AS PROTEGIDO,
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10) AS VARCHAR(500)) AS ORDEM_GERAL
                FROM SIS.Modulo m WITH (NOLOCK)
                WHERE m.ATIVO = 1
                UNION ALL
                SELECT CAST('TELA' AS VARCHAR(10)),
                       CAST(i.CODIGO AS VARCHAR(40)),
                       ar.CAMINHO_NOME,
                       m.CODIGO,
                       i.EXCLUSIVO_GERAL,
                       m.LIBERADO_LICENCA,
                       i.HABILITADO,
                       CAST(CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 AND i.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT),
                       CAST(CASE WHEN i.CODIGO = 'SIS_MODULO' THEN 1 ELSE 0 END AS BIT),
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10)
                            + '|' + ar.ORDEM_CAMINHO AS VARCHAR(500))
                FROM Arvore ar
                INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.ID_ITEM   = ar.ID_ITEM AND i.TIPO = 'TELA'
                INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
                WHERE m.ATIVO = 1
             ) x
        ORDER BY x.ORDEM_GERAL
        OPTION (MAXRECURSION 20);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os módulos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
