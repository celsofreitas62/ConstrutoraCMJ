/*******************************************************************************
  Teste       : 04b2 - histórico com TRANSACAO (aba Histórico e tela Auditoria)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 23/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @h TABLE (ID_AUDITORIA BIGINT, DT_OPERACAO DATETIME2(3), OPERACAO CHAR(1), OPERACAO_NOME NVARCHAR(20), CAMPO NVARCHAR(128), VALOR_ANTES NVARCHAR(4000),
                  VALOR_DEPOIS NVARCHAR(4000), USUARIO NVARCHAR(100), ESTACAO NVARCHAR(100), ORIGEM NVARCHAR(256), ID_LOTE BIGINT, TRANSACAO BIGINT);
DECLARE @hl TABLE (ID_AUDITORIA BIGINT, DT_OPERACAO DATETIME2(3), TABELA NVARCHAR(256), ID_REGISTRO BIGINT, PRINCIPAL BIT, OPERACAO CHAR(1), OPERACAO_NOME NVARCHAR(20),
                   CAMPO NVARCHAR(128), VALOR_ANTES NVARCHAR(4000), VALOR_DEPOIS NVARCHAR(4000), USUARIO NVARCHAR(100), ESTACAO NVARCHAR(100), ORIGEM NVARCHAR(256),
                   ID_LOTE BIGINT, TRANSACAO BIGINT, DESCRICAO NVARCHAR(200));
DECLARE @Msg NVARCHAR(400), @Perfil INT, @IaA INT;
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @P INT;

INSERT @r SELECT N'versão do banco', N'2.1', (SELECT TOP 1 VERSAO FROM SIS.Versao_Banco ORDER BY ID_VERSAO_BANCO DESC);
INSERT @r SELECT N'Registro_Listar devolve TRANSACAO', N'1', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = 1, @Item = ''CAD_PESSOA'', @Tabela = N''CAD.Pessoa'', @IdRegistro = 1', NULL, 0)
       WHERE name = 'TRANSACAO';
INSERT @r SELECT N'Auditoria_Listar devolve TRANSACAO e TELA_NOME', N'2', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 1', NULL, 0)
       WHERE name IN ('TRANSACAO', 'TELA_NOME');

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'SIS') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('CAD_PESSOA', 'SIS_AUDITORIA', 'SIS_PERFIL') AND HABILITADO = 0;
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b2', '');  SET @P = SCOPE_IDENTITY();
UPDATE CAD.Pessoa SET NOME = N'Teste 04b2 alterado', OBSERVACAO = N'obs' WHERE ID_PESSOA = @P;
INSERT @h EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P;
INSERT @r SELECT N'linhas do histórico com TRANSACAO preenchida', N'S', CASE WHEN COUNT(*) > 0 AND COUNT(*) = COUNT(TRANSACAO) THEN N'S' ELSE N'N' END FROM @h;
INSERT @r SELECT N'alteração de 2 campos na mesma operação', N'1', CAST(COUNT(DISTINCT TRANSACAO) AS NVARCHAR(5)) FROM @h WHERE OPERACAO = 'A';
-- histórico padrão: pessoa + contato (inclusive apagado)
INSERT CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR) VALUES (@P, 'EMAIL', N'a@teste.com');
INSERT CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR) VALUES (@P, 'EMAIL', N'b@teste.com');
DELETE CAD.Pessoa_Contato WHERE ID_PESSOA = @P AND VALOR = N'b@teste.com';
INSERT @hl EXEC SIS.SIS_Historico_Listar @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P;
INSERT @r SELECT N'histórico padrão: linhas da pessoa (principal)', N'S', CASE WHEN COUNT(*) >= 2 THEN N'S' ELSE N'N' END FROM @hl WHERE PRINCIPAL = 1;
INSERT @r SELECT N'histórico padrão: contatos (2 incluídos e 1 apagado)', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM @hl WHERE TABELA = N'CAD.Pessoa_Contato' AND OPERACAO IN ('I', 'E');
-- permissões do perfil com nome da tela e da ação
INSERT SIS.Perfil (NOME, DESCRICAO) VALUES (N'Teste 04b2', N'');  SET @Perfil = SCOPE_IDENTITY();
SELECT @IaA = ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'CAD_PESSOA' AND a.CODIGO = 'VER';
INSERT SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO) VALUES (@Perfil, @IaA);
DELETE @hl;
INSERT @hl EXEC SIS.SIS_Historico_Listar @IdUsuario = @Celso, @Item = 'SIS_PERFIL', @Tabela = N'SIS.Perfil', @IdRegistro = @Perfil;
INSERT @r SELECT N'histórico do perfil: permissão com nome da tela', N'S', CASE WHEN EXISTS (SELECT 1 FROM @hl WHERE TABELA = N'SIS.Perfil_Permissao' AND DESCRICAO LIKE N'Pessoas%') THEN N'S' ELSE N'N' END;
ROLLBACK;

BEGIN TRY
    INSERT @hl EXEC SIS.SIS_Historico_Listar @IdUsuario = @Claude, @Item = 'SIS_LIXEIRA', @Tabela = N'SIS.Lixeira', @IdRegistro = 1;
    SET @Msg = N'listou';
END TRY
BEGIN CATCH
    SET @Msg = N'recusado';
END CATCH;
INSERT @r SELECT N'histórico sem permissão na tela', N'recusado', @Msg;
BEGIN TRY
    INSERT @hl EXEC SIS.SIS_Historico_Listar @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'SIS.Usuario', @IdRegistro = 1;
    SET @Msg = N'listou';
END TRY
BEGIN CATCH
    SET @Msg = N'recusado';
END CATCH;
INSERT @r SELECT N'histórico de tabela que não é da tela', N'recusado', @Msg;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
