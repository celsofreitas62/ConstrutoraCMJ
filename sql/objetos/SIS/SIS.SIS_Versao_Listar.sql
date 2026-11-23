/*******************************************************************************
  Objeto      : [SIS].[SIS_Versao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Histórico das versões do sistema (aba "Histórico de
                atualizações" da tela Sistema › Versões, pedido P22), do mais
                novo para o mais antigo. Junta:
                  - ATUALIZACAO: cada atualizar.cmd (SIS.Atualizacao), com
                    versões de/para do programa e do banco, tempo fora do ar,
                    resultado e mensagem;
                  - INSTALACAO: o MASTER rodado à mão (SIS.Versao_Banco com
                    ORIGEM = MASTER que não é de uma atualização);
                  - PACOTE: pacote de desenvolvimento (só no banco _LOCAL).
                De SIS.Versao_Banco entram só as mudanças de versão (rodar o
                MASTER de novo na mesma versão não aparece).
                Permissão: VER em SIS_VERSOES (só o administrador, decisão do
                Celso de 23/11/2026; as notas são para todos).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Versao_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Versao_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE = NULL,
    @DtFim      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Versao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_VERSOES', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o histórico de atualizações.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT x.ORIGEM,
               CAST(CASE x.ORIGEM WHEN 'ATUALIZACAO' THEN N'Atualização' WHEN 'INSTALACAO' THEN N'Instalação' ELSE N'Pacote (desenvolvimento)' END AS NVARCHAR(30)) AS ORIGEM_NOME,
               x.ID_ATUALIZACAO,
               x.DT_INICIO,
               x.DT_FIM,
               x.VERSAO_BANCO_DE,
               x.VERSAO_BANCO_PARA,
               x.VERSAO_PROGRAMA_DE,
               x.VERSAO_PROGRAMA_PARA,
               x.SEGUNDOS_FORA,
               x.SITUACAO,
               CAST(CASE x.SITUACAO WHEN 'CONCLUIDA' THEN N'Concluída' WHEN 'DESFEITA' THEN N'Desfeita (voltou sozinha)' ELSE N'Erro' END AS NVARCHAR(30)) AS SITUACAO_NOME,
               x.MENSAGEM,
               x.USUARIO,
               x.ESTACAO,
               x.PACOTE,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM SIS.Versao_Nota n WITH (NOLOCK) WHERE n.VERSAO = x.VERSAO_BANCO_PARA) THEN 1 ELSE 0 END AS BIT) AS TEM_NOTA
        FROM (
                SELECT CAST('ATUALIZACAO' AS VARCHAR(12)) AS ORIGEM, CAST(a.ID_ATUALIZACAO AS INT) AS ID_ATUALIZACAO,
                       a.DT_INICIO, a.DT_FIM, a.VERSAO_BANCO_DE, a.VERSAO_BANCO_PARA, a.VERSAO_PROGRAMA_DE, a.VERSAO_PROGRAMA_PARA,
                       a.SEGUNDOS_FORA, a.SITUACAO, CAST(a.MENSAGEM AS NVARCHAR(2000)) AS MENSAGEM,
                       CAST(a.USUARIO AS NVARCHAR(128)) AS USUARIO, CAST(a.ESTACAO AS NVARCHAR(128)) AS ESTACAO, CAST(a.PACOTE AS NVARCHAR(260)) AS PACOTE
                FROM SIS.Atualizacao a WITH (NOLOCK)
                UNION ALL
                SELECT CAST(CASE v.ORIGEM WHEN 'MASTER' THEN 'INSTALACAO' ELSE 'PACOTE' END AS VARCHAR(12)), CAST(0 AS INT),
                       v.DT_INSTALACAO, v.DT_INSTALACAO, CAST(ISNULL(ant.VERSAO, '') AS VARCHAR(20)), v.VERSAO, CAST('' AS VARCHAR(20)), CAST('' AS VARCHAR(20)),
                       CAST(0 AS INT), CAST('CONCLUIDA' AS VARCHAR(10)), CAST(N'' AS NVARCHAR(2000)),
                       CAST(v.USUARIO AS NVARCHAR(128)), CAST(v.ESTACAO AS NVARCHAR(128)), CAST(N'' AS NVARCHAR(260))
                FROM SIS.Versao_Banco v WITH (NOLOCK)
                OUTER APPLY (SELECT TOP (1) p.VERSAO FROM SIS.Versao_Banco p WITH (NOLOCK)
                             WHERE p.ID_VERSAO_BANCO < v.ID_VERSAO_BANCO ORDER BY p.ID_VERSAO_BANCO DESC) ant
                WHERE ISNULL(ant.VERSAO, '') <> v.VERSAO
                  AND NOT EXISTS (SELECT 1 FROM SIS.Atualizacao a WITH (NOLOCK)
                                  WHERE a.VERSAO_BANCO_PARA = v.VERSAO
                                    AND v.DT_INSTALACAO BETWEEN DATEADD(MINUTE, -1, a.DT_INICIO) AND DATEADD(MINUTE, 1, a.DT_FIM))
             ) x
        WHERE (@DtInicio IS NULL OR x.DT_INICIO >= CAST(@DtInicio AS DATETIME2(0)))
          AND (@DtFim    IS NULL OR x.DT_INICIO <  DATEADD(DAY, 1, CAST(@DtFim AS DATETIME2(0))))
        ORDER BY x.DT_INICIO DESC, x.ID_ATUALIZACAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o histórico de atualizações. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
