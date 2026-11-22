/*******************************************************************************
  Teste       : 03g - ajuda exclusiva do administrador geral (SIS_Ajuda_Geral_Obter)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 22/11/2026 (v1.0). Banco: SISTEMACMJ_LOCAL.
  v1.1        : 22/11/2026 - roda também no banco instalado pelo MASTER (sem renata
                e claude): nível 1 = renata ou admin; sem usuário comum, o caso
                usa um ID inexistente. LOCAL 17/0; ensaio SISTEMACMJ 17/0.
  Observação  : não muda nada (os registros de consulta são desfeitos com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(80), ESPERADO NVARCHAR(40), OBTIDO NVARCHAR(40));
DECLARE @o TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400));
DECLARE @Geral INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = N'celso');
DECLARE @Admin INT = ISNULL((SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = N'renata'), (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = N'admin'));
DECLARE @AdminLogin NVARCHAR(100) = (SELECT LOGIN FROM SIS.Usuario WHERE ID_USUARIO = @Admin);
DECLARE @Comum INT = ISNULL((SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = N'claude'), 999998);
DECLARE @Antes INT;

INSERT @r SELECT N'tela existe e é exclusiva do nível 2', N'1', (SELECT CAST(EXCLUSIVO_GERAL AS NVARCHAR(5)) FROM SIS.Item WHERE CODIGO = 'SIS_AJUDA_GERAL');
INSERT @r SELECT N'tela abaixo de Configuração', N'SIS_CONFIGURACAO', (SELECT p.CODIGO FROM SIS.Item i JOIN SIS.Item p ON p.ID_ITEM = i.ID_ITEM_PAI WHERE i.CODIGO = 'SIS_AJUDA_GERAL');
INSERT @r SELECT N'ação VER ligada', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'SIS_AJUDA_GERAL' AND a.CODIGO = 'VER');
INSERT @r SELECT N'usuários de teste existem (celso e um nível 1)', N'2', CAST((CASE WHEN @Geral IS NULL THEN 0 ELSE 1 END + CASE WHEN @Admin IS NULL THEN 0 ELSE 1 END) AS NVARCHAR(5));
INSERT @r SELECT N'nível de celso / nível 1', N'2/1', CAST(SIS.fn_SIS_Usuario_Nivel_Admin(@Geral) AS NVARCHAR(2)) + N'/' + CAST(SIS.fn_SIS_Usuario_Nivel_Admin(@Admin) AS NVARCHAR(2));

BEGIN TRAN;
SET @Antes = (SELECT COUNT(*) FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]');

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = @Geral, @Pagina = 'licenca', @Estacao = N'teste';
INSERT @r SELECT N'nível 2 (celso) abre a página', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = @Geral, @Pagina = '', @Estacao = N'teste';
INSERT @r SELECT N'nível 2 abre o índice', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = @Admin, @Pagina = 'licenca', @Estacao = N'teste';
INSERT @r SELECT N'nível 1 (renata ou admin) recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o);
INSERT @r SELECT N'recusa não revela a página', N'Página não encontrada.', (SELECT MENSAGEM FROM @o); DELETE @o;

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = @Comum, @Pagina = 'licenca', @Estacao = N'teste';
INSERT @r SELECT N'usuário comum (claude ou inexistente) recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = 999999, @Pagina = 'licenca', @Estacao = N'teste';
INSERT @r SELECT N'usuário inexistente recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

INSERT @o EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = NULL, @Pagina = NULL, @Estacao = NULL;
INSERT @r SELECT N'tudo NULL recusado sem erro', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

INSERT @r SELECT N'6 consultas registradas', N'6', CAST((SELECT COUNT(*) FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]') - @Antes AS NVARCHAR(5));
INSERT @r SELECT N'2 OK e 4 AVISO', N'2/4',
       (SELECT CAST(SUM(CASE WHEN STATUS = 'OK' THEN 1 ELSE 0 END) AS NVARCHAR(5)) + N'/' + CAST(SUM(CASE WHEN STATUS = 'AVISO' THEN 1 ELSE 0 END) AS NVARCHAR(5))
        FROM (SELECT TOP (6) STATUS FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]' ORDER BY ID_LOG_PASSO DESC) x);
INSERT @r SELECT N'registro diz a página e o usuário', N'SIM',
       CASE WHEN EXISTS (SELECT 1 FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]' AND ETAPA = N'Recusada: licenca' AND DETALHE LIKE N'%' + @AdminLogin + N'%') THEN N'SIM' ELSE N'NAO' END;
ROLLBACK;

INSERT @r SELECT N'formato fixo (sp_describe_first_result_set)', N'SUCESSO,MENSAGEM',
       (SELECT STRING_AGG(name, ',') WITHIN GROUP (ORDER BY column_ordinal) FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Ajuda_Geral_Obter 1', NULL, 0));
INSERT @r SELECT N'não aparece no menu do nível 1', N'0',
       (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.vw_SIS_Permissao_Efetiva WHERE ID_USUARIO = @Admin AND ITEM_CODIGO = 'SIS_AJUDA_GERAL');

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @r;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @r;
