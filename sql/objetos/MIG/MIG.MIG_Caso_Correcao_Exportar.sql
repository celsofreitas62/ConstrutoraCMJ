/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Correcao_Exportar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Monta o script SQL que leva as correções da tela "Casos da
                migração" (MIG.Caso_Correcao e MIG.Caso_Correcao_Linha) de um
                banco para outro: do notebook (ensaio) para o servidor da CMJ
                na instalação (etapa 3d). Uma linha de texto por comando
                (coluna LINHA, em ordem); a tela junta tudo num arquivo .sql
                ("Baixar correções"). O script substitui as correções do banco
                de destino pelas do banco de origem, com usuário, datas e
                impressões digitais do Access; tudo-ou-nada.
                Permissão: ALTERAR em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, cópia das correções para a 3d).
    v1.1 (18/11/2026) - Leva também a troca de lote (LOTE).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Correcao_Exportar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Correcao_Exportar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Correcao_Exportar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            THROW 50001, N'Você não tem permissão para baixar as correções da migração.', 1;

        SET @EtapaAtual = 'Montagem';
        SELECT x.LINHA
        FROM (
            SELECT 1 AS PARTE, CAST(0 AS BIGINT) AS ORDEM, CAST(
                   N'/* SisCMJ - correções da tela "Casos da migração"' + NCHAR(13) + NCHAR(10)
                 + N'   Gerado em ' + CONVERT(NVARCHAR(19), SYSDATETIME(), 120) + N' no banco ' + DB_NAME() + N' por ' + SIS.fn_SIS_Usuario_Login(@IdUsuario) + NCHAR(13) + NCHAR(10)
                 + N'   ' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao)) + N' decisões e '
                 + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha)) + N' linhas corrigidas.' + NCHAR(13) + NCHAR(10)
                 + N'   Como usar: no servidor de destino, SSMS > Abrir > este arquivo > F5. Substitui as correções de lá pelas deste arquivo. */' + NCHAR(13) + NCHAR(10)
                 + N'SET NOCOUNT ON;' + NCHAR(13) + NCHAR(10) + N'SET XACT_ABORT ON;' + NCHAR(13) + NCHAR(10)
                 + N'IF SCHEMA_ID(N''MIG'') IS NULL OR OBJECT_ID(N''MIG.Caso_Correcao'', N''U'') IS NULL OR COL_LENGTH(N''MIG.Caso_Correcao_Linha'', N''LOTE'') IS NULL' + NCHAR(13) + NCHAR(10)
                 + N'    THROW 50001, N''Este banco não tem as tabelas de correção da migração: rode antes o pacote 03c2b.'', 1;' + NCHAR(13) + NCHAR(10)
                 + N'BEGIN TRANSACTION;' + NCHAR(13) + NCHAR(10)
                 + N'DELETE FROM MIG.Caso_Correcao_Linha;' + NCHAR(13) + NCHAR(10)
                 + N'DELETE FROM MIG.Caso_Correcao;' AS NVARCHAR(MAX)) AS LINHA
            UNION ALL
            SELECT 2, c.ID_CASO_CORRECAO,
                   N'INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, HASH_ACCESS, DT_CRIACAO, USUARIO_CRIACAO, DT_ALTERACAO, USUARIO_ALTERACAO) VALUES ('
                 + N'''' + c.UNIDADE + N''', ''' + c.ACAO + N''', N''' + REPLACE(c.MOTIVO, N'''', N'''''') + N''', '
                 + ISNULL(CONVERT(NVARCHAR(70), c.HASH_ACCESS, 1), N'NULL') + N', '
                 + N'''' + CONVERT(NVARCHAR(19), c.DT_CRIACAO, 120) + N''', N''' + REPLACE(c.USUARIO_CRIACAO, N'''', N'''''') + N''', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(19), c.DT_ALTERACAO, 120) + N'''', N'NULL') + N', '
                 + ISNULL(N'N''' + REPLACE(c.USUARIO_ALTERACAO, N'''', N'''''') + N'''', N'NULL') + N');'
            FROM MIG.Caso_Correcao c
            UNION ALL
            SELECT 3, o.ID_CASO_CORRECAO_LINHA,
                   N'INSERT INTO MIG.Caso_Correcao_Linha (ORIGEM, NUM, UNIDADE, EMP_VINCULADA, PARCEIRO, CONTA, PLANO3, DT_MOVTO, DT_VENCTO, DT_PAGTO, '
                 + N'VALOR_DEBITO, VALOR_CREDITO, CONFIRMADO, IGNORAR_LINHA, MOTIVO, HASH_ACCESS, LOTE, DT_CRIACAO, USUARIO_CRIACAO, DT_ALTERACAO, USUARIO_ALTERACAO) VALUES ('
                 + N'''' + o.ORIGEM + N''', ' + CONVERT(NVARCHAR(12), o.NUM) + N', ''' + o.UNIDADE + N''', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.EMP_VINCULADA), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.PARCEIRO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.CONTA), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.PLANO3), N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_MOVTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_VENCTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_PAGTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(30), o.VALOR_DEBITO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(30), o.VALOR_CREDITO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(1), o.CONFIRMADO), N'NULL') + N', '
                 + CONVERT(NVARCHAR(1), o.IGNORAR_LINHA) + N', '
                 + N'N''' + REPLACE(o.MOTIVO, N'''', N'''''') + N''', '
                 + ISNULL(CONVERT(NVARCHAR(70), o.HASH_ACCESS, 1), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.LOTE), N'NULL') + N', '
                 + N'''' + CONVERT(NVARCHAR(19), o.DT_CRIACAO, 120) + N''', N''' + REPLACE(o.USUARIO_CRIACAO, N'''', N'''''') + N''', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(19), o.DT_ALTERACAO, 120) + N'''', N'NULL') + N', '
                 + ISNULL(N'N''' + REPLACE(o.USUARIO_ALTERACAO, N'''', N'''''') + N'''', N'NULL') + N');'
            FROM MIG.Caso_Correcao_Linha o
            UNION ALL
            SELECT 4, 0, N'COMMIT TRANSACTION;' + NCHAR(13) + NCHAR(10)
                 + N'SELECT N''Correções copiadas: '' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao)) + N'' decisões e '''
                 + N' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha)) + N'' linhas. Rode a migração para aplicar.'' AS RESULTADO;'
        ) x
        ORDER BY x.PARTE, x.ORDEM;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível montar o arquivo das correções. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
