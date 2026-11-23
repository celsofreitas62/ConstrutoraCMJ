/*******************************************************************************
  Teste       : 04c - versões e notas da versão (P22)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 23/11/2026 (v1.0; v1.1: usuário de consulta temporário quando não há o "claude"). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Pressupõe as notas
                1.8 a 2.1 do docs/NOTAS_DA_VERSAO.md e o banco na 2.1 ou mais.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @n TABLE (VERSAO VARCHAR(20), VERSAO_NUMERO INT, DT_VERSAO VARCHAR(10), ORDEM SMALLINT, TIPO VARCHAR(10), TIPO_NOME NVARCHAR(20), PUBLICO VARCHAR(10),
                  TEXTO NVARCHAR(2000), TEXTO_HTML NVARCHAR(4000), ATUAL BIT);
DECLARE @nv TABLE (VERSAO VARCHAR(20), VERSAO_NUMERO INT, DT_VERSAO VARCHAR(10), ORDEM SMALLINT, TIPO VARCHAR(10), TIPO_NOME NVARCHAR(20), PUBLICO VARCHAR(10),
                   TEXTO NVARCHAR(2000), TEXTO_HTML NVARCHAR(4000), VERSAO_ATUAL VARCHAR(20), VERSOES_OMITIDAS INT);
DECLARE @o TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), EXTRA NVARCHAR(40));
DECLARE @Msg NVARCHAR(400), @Qtd INT, @IdAtu INT, @Agora DATETIME2(0) = SYSDATETIME();
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude' AND ATIVO = 1);
DECLARE @Celso  INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Atual VARCHAR(20) = SIS.fn_SIS_Versao_Banco();
BEGIN TRAN;
-- no banco do MASTER não existe o usuário de teste "claude": cria um usuário só de consulta (desfeito no fim)
IF @Claude IS NULL
BEGIN
    INSERT SIS.Usuario (LOGIN, NOME, ID_PERFIL) SELECT 'teste.04c', N'Teste 04c', p.ID_PERFIL FROM SIS.Perfil p WHERE p.NOME = N'Consulta';
    SET @Claude = SCOPE_IDENTITY();
    INSERT SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA) VALUES (@Claude, @Atual);
END;

-- números de versão
INSERT @r SELECT N'versão 2.10 maior que 2.9', N'S', CASE WHEN SIS.fn_SIS_Versao_Numero('2.10') > SIS.fn_SIS_Versao_Numero('2.9') THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'versão 1.8.0 = 1008000; vazio e inválido = 0', N'1008000|0|0',
       CONCAT(SIS.fn_SIS_Versao_Numero('1.8.0'), '|', SIS.fn_SIS_Versao_Numero(''), '|', SIS.fn_SIS_Versao_Numero('2.x'));
-- carga
INSERT @r SELECT N'notas carregadas (1.8 a 2.1)', N'S', CASE WHEN (SELECT COUNT(*) FROM SIS.Versao_Nota WHERE VERSAO IN ('1.8', '1.9', '2.0', '2.1')) = 16 THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'item só do administrador geral', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Versao_Nota WHERE PUBLICO = 'GERAL' AND VERSAO = '1.8';
INSERT @r SELECT N'texto sem marcação e HTML com <b>', N'S', CASE WHEN EXISTS (SELECT 1 FROM SIS.Versao_Nota WHERE TEXTO NOT LIKE N'%**%' AND TEXTO_HTML LIKE N'%<b>%') THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'tela SIS_VERSOES com VER e EXPORTAR', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM WHERE i.CODIGO = 'SIS_VERSOES';
INSERT @r SELECT N'parâmetros novos', N'4', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE CHAVE IN ('NOVIDADES_AVISO_ATIVO', 'NOVIDADES_VERSOES_MAX', 'VERSAO_AVISO_EMAIL_ATIVO', 'VERSAO_AVISO_GRUPO');
INSERT @r SELECT N'grupo VERSAO_AVISO com destinatário', N'S', CASE WHEN SIS.fn_SIS_Emails_Do_Grupo('VERSAO_AVISO') LIKE N'%@%' THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'usuários ativos com ponto de partida', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Usuario u WHERE u.ATIVO = 1 AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Novidade n WHERE n.ID_USUARIO = u.ID_USUARIO) AND u.LOGIN IN ('celso', 'claude');
INSERT @r SELECT N'Versao_Listar devolve as colunas', N'S', CASE WHEN (SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Versao_Listar @IdUsuario = 1', NULL, 0)) = 17 THEN N'S' ELSE N'N' END;

-- notas: todos veem; GERAL só nível 2
INSERT @n EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = @Celso;
INSERT @r SELECT N'nível 2 vê as 16 notas', N'16', CAST(COUNT(*) AS NVARCHAR(5)) FROM @n WHERE VERSAO IN ('1.8', '1.9', '2.0', '2.1');
INSERT @r SELECT N'nota da versão atual marcada', N'S', CASE WHEN EXISTS (SELECT 1 FROM @n WHERE ATUAL = 1 AND VERSAO = @Atual) THEN N'S' ELSE N'N' END;
DELETE @n;
INSERT @n EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = @Claude;
INSERT @r SELECT N'usuário comum vê 15 (sem a do administrador geral)', N'15', CAST(COUNT(*) AS NVARCHAR(5)) FROM @n WHERE VERSAO IN ('1.8', '1.9', '2.0', '2.1');
DELETE @n;
INSERT @n EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = @Claude, @Busca = N'lixeira';
INSERT @r SELECT N'busca por palavra', N'S', CASE WHEN COUNT(*) > 0 AND COUNT(*) = SUM(CASE WHEN TEXTO LIKE N'%lixeira%' THEN 1 ELSE 0 END) THEN N'S' ELSE N'N' END FROM @n;
DELETE @n;
INSERT @n EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = @Claude, @Versao = '2.0', @Tipo = 'MELHORIA';
INSERT @r SELECT N'filtro por versão e tipo', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM @n;

-- histórico com uma atualização registrada (e o e-mail da nota)
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoProgramaDe = '1.9.0', @VersaoProgramaPara = '2.1.0', @VersaoBancoDe = '1.9', @VersaoBancoPara = '2.1',
              @DtInicio = @Agora, @DtFim = @Agora, @SegundosFora = 18, @Situacao = 'CONCLUIDA', @Mensagem = N'teste 04c', @Notas = N'', @Pacote = N'teste';
SELECT @IdAtu = CAST(EXTRA AS INT) FROM @o;
INSERT @r SELECT N'registra a atualização', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @o);
INSERT @r SELECT N'e-mail da nota enfileirado para o grupo', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Email_Fila WHERE CHAVE_ORIGEM = N'VERSAO_NOTA_' + CAST(@IdAtu AS NVARCHAR(20)) AND TIPO = 'NOTA_VERSAO';
INSERT @r SELECT N'e-mail traz 2.0 e 2.1, sem 1.9 nem item do adm. geral', N'S',
       CASE WHEN CORPO_HTML LIKE N'%Versão 2.1%' AND CORPO_HTML LIKE N'%Versão 2.0%' AND CORPO_HTML NOT LIKE N'%Versão 1.9%' AND CORPO_HTML NOT LIKE N'%ajuda técnica%' THEN N'S' ELSE N'N' END
       FROM SIS.Email_Fila WHERE CHAVE_ORIGEM = N'VERSAO_NOTA_' + CAST(@IdAtu AS NVARCHAR(20));
UPDATE SIS.Parametro SET VALOR = N'N' WHERE CHAVE = 'VERSAO_AVISO_EMAIL_ATIVO';
DELETE @o;
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoBancoDe = '2.0', @VersaoBancoPara = '2.1', @VersaoProgramaPara = '2.1.0', @DtInicio = @Agora, @Situacao = 'CONCLUIDA';
SELECT @IdAtu = CAST(EXTRA AS INT) FROM @o;
INSERT @r SELECT N'e-mail desligado pelo parâmetro', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Email_Fila WHERE CHAVE_ORIGEM = N'VERSAO_NOTA_' + CAST(@IdAtu AS NVARCHAR(20));
DELETE @o;
INSERT @o EXEC SIS.SIS_Atualizacao_Registrar @VersaoBancoDe = '2.1', @VersaoBancoPara = '2.1', @VersaoProgramaPara = '2.1.0', @DtInicio = @Agora, @Situacao = 'DESFEITA', @Mensagem = N'falha simulada';
SELECT @Qtd = COUNT(*) FROM (SELECT 1 AS X FROM SIS.Atualizacao WHERE PACOTE IN (N'teste', N'') AND DT_INICIO = @Agora) t;
DECLARE @h TABLE (ORIGEM VARCHAR(12), ORIGEM_NOME NVARCHAR(30), ID_ATUALIZACAO INT, DT_INICIO DATETIME2(0), DT_FIM DATETIME2(0), VERSAO_BANCO_DE VARCHAR(20), VERSAO_BANCO_PARA VARCHAR(20),
                  VERSAO_PROGRAMA_DE VARCHAR(20), VERSAO_PROGRAMA_PARA VARCHAR(20), SEGUNDOS_FORA INT, SITUACAO VARCHAR(10), SITUACAO_NOME NVARCHAR(30), MENSAGEM NVARCHAR(2000),
                  USUARIO NVARCHAR(128), ESTACAO NVARCHAR(128), PACOTE NVARCHAR(260), TEM_NOTA BIT);
INSERT @h EXEC SIS.SIS_Versao_Listar @IdUsuario = @Celso;
INSERT @r SELECT N'histórico: 3 atualizações de hoje (1 desfeita)', N'3|1', CONCAT(SUM(CASE WHEN ORIGEM = 'ATUALIZACAO' AND DT_INICIO = @Agora THEN 1 ELSE 0 END), '|',
                                                                    SUM(CASE WHEN ORIGEM = 'ATUALIZACAO' AND DT_INICIO = @Agora AND SITUACAO = 'DESFEITA' THEN 1 ELSE 0 END)) FROM @h;
INSERT @r SELECT N'histórico: versões do pacote sem repetir', N'S', CASE WHEN NOT EXISTS (SELECT 1 FROM @h WHERE ORIGEM <> 'ATUALIZACAO' AND VERSAO_BANCO_DE = VERSAO_BANCO_PARA) THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'histórico: nota disponível na 2.1', N'S', CASE WHEN EXISTS (SELECT 1 FROM @h WHERE VERSAO_BANCO_PARA = '2.1' AND TEM_NOTA = 1) THEN N'S' ELSE N'N' END;

-- aviso "O que há de novo"
UPDATE SIS.Usuario_Novidade SET VERSAO_VISTA = '1.9' WHERE ID_USUARIO = @Claude;
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'viu 1.9: aviso com 2.0 e 2.1', N'2.0,2.1|0', CONCAT(STRING_AGG(VERSAO, ',') WITHIN GROUP (ORDER BY VERSAO_NUMERO), '|', MAX(VERSOES_OMITIDAS))
       FROM (SELECT DISTINCT VERSAO, VERSAO_NUMERO, VERSOES_OMITIDAS FROM @nv) x;
DELETE @nv;
UPDATE SIS.Usuario_Novidade SET VERSAO_VISTA = '' WHERE ID_USUARIO = @Claude;
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'nunca viu: no máximo 3 versões, 1 omitida', N'1.9,2.0,2.1|1', CONCAT(STRING_AGG(VERSAO, ',') WITHIN GROUP (ORDER BY VERSAO_NUMERO), '|', MAX(VERSOES_OMITIDAS))
       FROM (SELECT DISTINCT VERSAO, VERSAO_NUMERO, VERSOES_OMITIDAS FROM @nv) x;
DELETE @nv;
UPDATE SIS.Parametro SET VALOR = N'1' WHERE CHAVE = 'NOVIDADES_VERSOES_MAX';
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'máximo 1 versão pelo parâmetro', N'2.1', ISNULL(STRING_AGG(VERSAO, ','), '') FROM (SELECT DISTINCT VERSAO FROM @nv) x;
DELETE @nv;
UPDATE SIS.Parametro SET VALOR = N'N' WHERE CHAVE = 'NOVIDADES_AVISO_ATIVO';
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'aviso desligado pelo parâmetro', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @nv;
UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'NOVIDADES_AVISO_ATIVO';
DELETE @o;
INSERT @o EXEC SIS.SIS_Novidades_Marcar_Vista @IdUsuario = @Claude;
INSERT @r SELECT N'"Entendi" grava a versão atual', CONCAT('1|', @Atual), CONCAT(CAST(SUCESSO AS NVARCHAR(2)), '|', EXTRA) FROM @o;
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'depois do "Entendi" o aviso não volta', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @nv;
DELETE SIS.Usuario_Novidade WHERE ID_USUARIO = @Claude;
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'usuário novo: sem aviso e nasce com a versão atual', CONCAT('0|', @Atual),
       CONCAT((SELECT COUNT(*) FROM @nv), '|', (SELECT VERSAO_VISTA FROM SIS.Usuario_Novidade WHERE ID_USUARIO = @Claude));
DELETE @nv;
UPDATE SIS.Usuario_Novidade SET VERSAO_VISTA = '' WHERE ID_USUARIO = @Claude;
INSERT @nv EXEC SIS.SIS_Novidades_Obter @IdUsuario = @Claude;
INSERT @r SELECT N'aviso do usuário comum sem item do adm. geral', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @nv WHERE PUBLICO = 'GERAL';
-- recusas por último: o erro (XACT_ABORT) desfaz a transação do teste
DECLARE @Msg2 NVARCHAR(400);
BEGIN TRY
    EXEC SIS.SIS_Versao_Listar @IdUsuario = @Claude;
    SET @Msg = N'listou';
END TRY
BEGIN CATCH
    SET @Msg = N'recusado';
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
BEGIN TRY
    INSERT @n EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = -1;
    SET @Msg2 = N'listou';
END TRY
BEGIN CATCH
    SET @Msg2 = N'recusado';
END CATCH;
INSERT @r SELECT N'histórico sem permissão (usuário só consulta)', N'recusado', @Msg;
INSERT @r SELECT N'notas sem usuário válido', N'recusado', @Msg2;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
