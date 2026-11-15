/*******************************************************************************
  Objeto      : [SIS].[SIS_Menu_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Menu lateral em drill-down do usuário logado (seção 3 item 8):
                só módulos liberados na licença, só telas em que ele tem VER,
                e os agrupadores (MENU) que levam até elas.
                Uma linha por nó, já na ordem de exibição:
                  TIPO      : MODULO / MENU / TELA
                  CHAVE     : 'M<id>' (módulo) ou 'I<id>' (item)
                  CHAVE_PAI : '' (módulo), 'M<id>' ou 'I<id>'
                  NIVEL     : 0 = módulo, 1 = direto no módulo, 2...
                  ACOES     : ações permitidas na tela ("VER,INCLUIR,...")
                              para a tela esconder os botões não permitidos.
                Sem conferência de permissão: é o próprio menu do usuário.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Menu_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Menu_Listar]
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Menu_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissões';

    DROP TABLE IF EXISTS #Perm;
    DROP TABLE IF EXISTS #Arv;
    DROP TABLE IF EXISTS #Vis;

    BEGIN TRY
        SELECT v.ID_ITEM, v.ACAO_CODIGO, a.ORDEM
        INTO #Perm
        FROM SIS.vw_SIS_Permissao_Efetiva v
        INNER JOIN SIS.Acao a ON a.ID_ACAO = v.ID_ACAO
        WHERE v.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Árvore do menu';
        WITH Arvore AS
        (
            SELECT i.ID_ITEM, 1 AS NIVEL,
                   CAST(RIGHT('00000' + CONVERT(VARCHAR(5), i.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), i.ID_ITEM), 10) AS VARCHAR(400)) AS ORDEM_CAMINHO
            FROM SIS.Item i WITH (NOLOCK)
            WHERE i.ID_ITEM_PAI IS NULL
              AND i.ATIVO = 1
            UNION ALL
            SELECT c.ID_ITEM, a.NIVEL + 1,
                   CAST(a.ORDEM_CAMINHO + '/' + RIGHT('00000' + CONVERT(VARCHAR(5), c.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), c.ID_ITEM), 10) AS VARCHAR(400))
            FROM SIS.Item c WITH (NOLOCK)
            INNER JOIN Arvore a ON a.ID_ITEM = c.ID_ITEM_PAI
            WHERE c.ATIVO = 1
        )
        SELECT ar.ID_ITEM, ar.NIVEL, ar.ORDEM_CAMINHO
        INTO #Arv
        FROM Arvore ar
        OPTION (MAXRECURSION 20);

        SET @EtapaAtual = 'Itens visíveis';
        WITH Visivel AS
        (
            SELECT i.ID_ITEM, i.ID_ITEM_PAI
            FROM SIS.Item i WITH (NOLOCK)
            INNER JOIN #Arv ar ON ar.ID_ITEM = i.ID_ITEM
            WHERE i.TIPO = 'TELA'
              AND EXISTS (SELECT 1 FROM #Perm p WHERE p.ID_ITEM = i.ID_ITEM AND p.ACAO_CODIGO = 'VER')
            UNION ALL
            SELECT pai.ID_ITEM, pai.ID_ITEM_PAI
            FROM SIS.Item pai WITH (NOLOCK)
            INNER JOIN Visivel v ON v.ID_ITEM_PAI = pai.ID_ITEM
            WHERE pai.ATIVO = 1
        )
        SELECT DISTINCT v.ID_ITEM
        INTO #Vis
        FROM Visivel v
        OPTION (MAXRECURSION 20);

        SET @EtapaAtual = 'Montagem';
        SELECT x.TIPO, x.CHAVE, x.CHAVE_PAI, x.CODIGO, x.NOME, x.CAMINHO, x.ICONE, x.NIVEL, x.ACOES
        FROM (
                SELECT CAST('MODULO' AS VARCHAR(10))                               AS TIPO,
                       CAST('M' + CONVERT(VARCHAR(10), m.ID_MODULO) AS VARCHAR(12)) AS CHAVE,
                       CAST('' AS VARCHAR(12))                                     AS CHAVE_PAI,
                       CAST(m.CODIGO AS VARCHAR(40))                               AS CODIGO,
                       CAST(m.NOME AS NVARCHAR(80))                                AS NOME,
                       CAST('' AS VARCHAR(200))                                    AS CAMINHO,
                       m.ICONE                                                     AS ICONE,
                       0                                                           AS NIVEL,
                       CAST('' AS VARCHAR(400))                                    AS ACOES,
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10) AS VARCHAR(500)) AS ORDEM_GERAL
                FROM SIS.Modulo m WITH (NOLOCK)
                WHERE EXISTS (SELECT 1 FROM #Vis v INNER JOIN SIS.Item i ON i.ID_ITEM = v.ID_ITEM WHERE i.ID_MODULO = m.ID_MODULO)
                UNION ALL
                SELECT CAST(i.TIPO AS VARCHAR(10)),
                       CAST('I' + CONVERT(VARCHAR(10), i.ID_ITEM) AS VARCHAR(12)),
                       CAST(CASE WHEN i.ID_ITEM_PAI IS NULL THEN 'M' + CONVERT(VARCHAR(10), i.ID_MODULO)
                                 ELSE 'I' + CONVERT(VARCHAR(10), i.ID_ITEM_PAI) END AS VARCHAR(12)),
                       CAST(i.CODIGO AS VARCHAR(40)),
                       CAST(i.NOME AS NVARCHAR(80)),
                       CAST(i.CAMINHO AS VARCHAR(200)),
                       i.ICONE,
                       ar.NIVEL,
                       CAST(ISNULL((SELECT STRING_AGG(CAST(p.ACAO_CODIGO AS VARCHAR(400)), ',') WITHIN GROUP (ORDER BY p.ORDEM)
                                    FROM #Perm p WHERE p.ID_ITEM = i.ID_ITEM), '') AS VARCHAR(400)),
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10)
                            + '|' + ar.ORDEM_CAMINHO AS VARCHAR(500))
                FROM #Vis v
                INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.ID_ITEM   = v.ID_ITEM
                INNER JOIN #Arv       ar              ON ar.ID_ITEM  = i.ID_ITEM
                INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
             ) x
        ORDER BY x.ORDEM_GERAL;

        DROP TABLE IF EXISTS #Perm;
        DROP TABLE IF EXISTS #Arv;
        DROP TABLE IF EXISTS #Vis;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Perm;
            DROP TABLE IF EXISTS #Arv;
            DROP TABLE IF EXISTS #Vis;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        THROW 50001, N'Não foi possível montar o menu. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
