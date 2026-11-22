/*******************************************************************************
  Teste       : 03h - histórico das atualizações (SIS.Atualizacao, SIS_Atualizacao_Registrar)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 22/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(80), ESPERADO NVARCHAR(60), OBTIDO NVARCHAR(60));
DECLARE @o TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_GERADO INT);
DECLARE @Agora DATETIME2(0) = SYSDATETIME(), @Id INT, @Antes INT;
DECLARE @Notas NVARCHAR(MAX) = N'## 1.8' + NCHAR(13) + NCHAR(10) + N'- Novo: atualização em um clique.';

-- v1.1 (22/11/2026, 04a): versão 1.8 ou mais nova (o teste continua valendo nas versões seguintes)
INSERT @r SELECT N'versão do banco 1.8 ou mais nova', N'S', CASE WHEN TRY_CONVERT(INT, PARSENAME(SIS.fn_SIS_Versao_Banco(), 2)) * 1000 + TRY_CONVERT(INT, PARSENAME(SIS.fn_SIS_Versao_Banco(), 1)) >= 1008 THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'papel da API sem permissão de registrar', N'DENY',
       ISNULL((SELECT TOP 1 p.state_desc FROM sys.database_permissions p WHERE p.major_id = OBJECT_ID(N'SIS.SIS_Atualizacao_Registrar')
               AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') AND p.permission_name = 'EXECUTE' ORDER BY p.state_desc), N'nenhuma');

BEGIN TRAN;
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaDe = '1.7.0', @VersaoProgramaPara = '1.8.0', @VersaoBancoDe = '1.7', @VersaoBancoPara = '1.8',
     @DtInicio = @Agora, @DtFim = @Agora, @SegundosFora = 75, @Situacao = 'CONCLUIDA', @Mensagem = N'teste', @Notas = @Notas, @Pacote = N'C:\teste';
SELECT @Id = ID_GERADO FROM @o;
INSERT @r SELECT N'registra CONCLUIDA', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;
INSERT @r SELECT N'grava versões, tempo e notas', N'1.7>1.8|75|S',
       (SELECT VERSAO_BANCO_DE + N'>' + VERSAO_BANCO_PARA + N'|' + CAST(SEGUNDOS_FORA AS NVARCHAR(10)) + N'|' + CASE WHEN NOTAS LIKE N'%um clique%' THEN N'S' ELSE N'N' END FROM SIS.Atualizacao WHERE ID_ATUALIZACAO = @Id);

INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaPara = '1.8.0', @VersaoBancoPara = '1.8', @DtInicio = @Agora, @Situacao = 'OUTRA';
INSERT @r SELECT N'situação inválida recusada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaPara = '', @VersaoBancoPara = '1.8', @DtInicio = @Agora, @Situacao = 'CONCLUIDA';
INSERT @r SELECT N'sem versão nova recusada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;

UPDATE SIS.Parametro SET VALOR = N'celsofreitas62@gmail.com' WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';
SET @Antes = (SELECT COUNT(*) FROM SIS.Email_Fila);
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaDe = '1.7.0', @VersaoProgramaPara = '1.8.0', @VersaoBancoDe = '1.7', @VersaoBancoPara = '1.8',
     @DtInicio = @Agora, @Situacao = 'DESFEITA', @Mensagem = N'teste de falha';
INSERT @r SELECT N'DESFEITA registrada', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o); DELETE @o;
INSERT @r SELECT N'DESFEITA enfileira aviso por e-mail', N'1', CAST((SELECT COUNT(*) FROM SIS.Email_Fila) - @Antes AS NVARCHAR(5));
ROLLBACK;

INSERT @r SELECT N'formato fixo (sp_describe_first_result_set)', N'SUCESSO,MENSAGEM,ID_GERADO',
       (SELECT STRING_AGG(name, ',') WITHIN GROUP (ORDER BY column_ordinal) FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Atualizacao_Registrar ''1'', ''1'', ''1'', ''1'', NULL, NULL, 0, ''X''', NULL, 0));
INSERT @r SELECT N'nada ficou gravado (ROLLBACK)', N'0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Atualizacao WHERE MENSAGEM LIKE N'teste%');

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @r;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @r;
