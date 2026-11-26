/*******************************************************************************
  Teste       : 04b - histórico padrão: lixeira e desfazer pela auditoria (P20)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 22/11/2026 (v1.0; v1.1 em 25/11/2026, 04f: FIN.Lancamento na lixeira, 9 tabelas; v1.2 em 26/11/2026, 04f2c: FIN.Pendencia_Tipo, 10 tabelas). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Leva uns 3 segundos
                (espera de 2 s para separar o "ponto do histórico").
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @ex TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_LIXEIRA BIGINT, DT_APAGAR DATE);
DECLARE @rc TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), TABELA NVARCHAR(256), ID_REGISTRO BIGINT);
DECLARE @mt TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), DT_APAGAR DATE);
DECLARE @ev TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), QTD_APAGADOS INT, QTD_RECUSADOS INT);
DECLARE @ds TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
DECLARE @g  TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT);
DECLARE @lista TABLE (ID_LIXEIRA BIGINT, MODULO_CODIGO VARCHAR(10), MODULO_NOME NVARCHAR(60), ITEM_CODIGO VARCHAR(40), TELA_NOME NVARCHAR(80), TABELA NVARCHAR(256),
                   ID_REGISTRO BIGINT, DESCRICAO NVARCHAR(400), MOTIVO NVARCHAR(400), DT_EXCLUSAO DATETIME2(0), USUARIO_EXCLUSAO NVARCHAR(100), DT_APAGAR DATE,
                   DIAS_RESTANTES INT, APAGA_LOGO BIT, SITUACAO VARCHAR(12), DT_SITUACAO DATETIME2(0), USUARIO_SITUACAO NVARCHAR(100), MOTIVO_SITUACAO NVARCHAR(400), DT_AVISO DATETIME2(0));
DECLARE @pv TABLE (ORDEM INT, TABELA NVARCHAR(256), TELA_NOME NVARCHAR(256), ID_REGISTRO BIGINT, DESCRICAO NVARCHAR(400), CAMPO NVARCHAR(128),
                   VALOR_ATUAL NVARCHAR(4000), VALOR_NOVO NVARCHAR(4000), ACAO VARCHAR(10), SITUACAO VARCHAR(10), MENSAGEM NVARCHAR(400), ULTIMA_AUDITORIA BIGINT,
                   PODE_DESFAZER BIT, RESUMO NVARCHAR(400));
DECLARE @df TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_DESFAZER BIGINT, QTD_REGISTROS INT, QTD_CAMPOS INT, QTD_LIXEIRA INT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @Consulta INT = (SELECT ID_PERFIL FROM SIS.Perfil WHERE NOME = N'Consulta');
DECLARE @Financeiro INT = (SELECT ID_PERFIL FROM SIS.Perfil WHERE NOME = N'Financeiro');
DECLARE @P1 INT, @P2 INT, @P3 INT, @P4 INT, @P5 INT, @P6 INT, @P7 INT, @P8 INT, @C1 INT, @C2 INT, @C4 INT, @PRef INT, @U INT, @E INT, @CC INT;
DECLARE @Lx BIGINT, @Lx4 BIGINT, @Lx7 BIGINT, @Lx8 BIGINT, @Marco DATETIME2(0), @Dt DATE, @Msg NVARCHAR(400), @Emails INT, @IaA INT, @IaB INT, @Aud BIGINT;
DECLARE @Hoje DATE = CAST(SYSDATETIME() AS DATE);

-- Configuração, parâmetros, permissões
INSERT @r SELECT N'parâmetro LIXEIRA_DIAS_GUARDA (padrão 90)', N'90', SIS.fn_SIS_Parametro('LIXEIRA_DIAS_GUARDA');
INSERT @r SELECT N'parâmetros da lixeira (5)', N'5', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE CHAVE LIKE 'LIXEIRA[_]%';
INSERT @r SELECT N'prazo que vale para Pessoas', N'90', CAST(SIS.fn_SIS_Lixeira_Dias(N'CAD.Pessoa') AS NVARCHAR(5));
INSERT @r SELECT N'tabelas configuradas para a lixeira (10 desde a 04f2c)', N'10', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Tabela_Config WHERE PERMITE_LIXEIRA = 1;
INSERT @r SELECT N'tela da tabela CAD.Plano_Grupo', N'CAD_PLANO_CONTA', SIS.fn_SIS_Item_Da_Tabela(N'CAD.Plano_Grupo');
INSERT @r SELECT N'tela Lixeira cadastrada', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item WHERE CODIGO = 'SIS_LIXEIRA';
INSERT @r SELECT N'rotina LIXEIRA_LIMPEZA cadastrada e ativa', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Rotina WHERE CODIGO = 'LIXEIRA_LIMPEZA' AND ATIVA = 1;
INSERT @r SELECT N'grupo de e-mail LIXEIRA_AVISO com destinatário', N'S', CASE WHEN SIS.fn_SIS_Emails_Do_Grupo('LIXEIRA_AVISO') <> N'' THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'Financeiro tem DESATIVAR em Pessoas (vinha do EXCLUIR)', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE pp.ID_PERFIL = @Financeiro AND i.CODIGO = 'CAD_PESSOA' AND a.CODIGO = 'DESATIVAR';
INSERT @r SELECT N'perfis de fábrica sem DESFAZER, RECUPERAR, ESVAZIAR', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE pp.ID_PERFIL IN (@Financeiro, @Consulta) AND a.CODIGO IN ('DESFAZER', 'RECUPERAR', 'ESVAZIAR');
INSERT @r SELECT N'API sem EXECUTE nas procedures internas', N'5', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.database_permissions dp
       WHERE dp.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') AND dp.state = 'D' AND dp.permission_name = 'EXECUTE'
         AND dp.major_id IN (OBJECT_ID(N'SIS.SIS_Lixeira_Marcar'), OBJECT_ID(N'SIS.SIS_Lixeira_Apagar'), OBJECT_ID(N'SIS.SIS_Lixeira_Referencias'),
                             OBJECT_ID(N'SIS.SIS_Tabela_Trava_Conferir'), OBJECT_ID(N'SIS.SIS_Historico_Desfazer_Montar'));
INSERT @r SELECT N'trigger de auditoria da Pessoa grava DT_EXCLUSAO', N'1', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'CAD.tg_CAD_Pessoa_Auditoria')) LIKE N'%DT_EXCLUSAO%' THEN N'1' ELSE N'0' END;
SELECT TOP 1 @PRef = l.ID_PESSOA FROM FIN.Lancamento l WHERE l.ID_PESSOA IS NOT NULL ORDER BY l.ID_PESSOA;

-- Lista sem permissão (fora da transação: a recusa por THROW encerra a transação)
BEGIN TRY
    INSERT @lista EXEC SIS.SIS_Lixeira_Listar @IdUsuario = @Claude;
    SET @Msg = N'listou';
END TRY
BEGIN CATCH
    SET @Msg = N'recusado';
END CATCH;
INSERT @r SELECT N'lista sem permissão na tela Lixeira', N'recusado', @Msg;

BEGIN TRAN;
-- Telas usadas no teste ligadas (no banco do MASTER podem estar desligadas; o ROLLBACK volta)
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'SIS') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('CAD_PESSOA', 'CAD_CENTRO_CUSTO', 'SIS_AUDITORIA', 'SIS_LIXEIRA') AND HABILITADO = 0;
-- Cadastros de teste
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P1', '');  SET @P1 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P2', '');  SET @P2 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P3', '');  SET @P3 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P4', '99999999904');  SET @P4 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P6', '');  SET @P6 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P7', '');  SET @P7 = SCOPE_IDENTITY();
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P8', '');  SET @P8 = SCOPE_IDENTITY();
INSERT CAD.Pessoa_Vinculo (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO) VALUES (@P3, @P2, 'CONJUGE');
INSERT CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR) VALUES (@P4, 'EMAIL', N'p4@teste.com');  SET @C4 = SCOPE_IDENTITY();
INSERT CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR) VALUES (@P6, 'EMAIL', N'antes@teste.com'); SET @C1 = SCOPE_IDENTITY();
INSERT @g EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @Celso, @Login = 'teste.04b', @Nome = N'Teste 04b', @Email = N'celsofreitas62@gmail.com', @IdPerfil = @Consulta;
SELECT @U = ID_USUARIO FROM @g; DELETE @g;
SELECT @IaA = ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'CAD_PESSOA' AND a.CODIGO = 'INCLUIR';
SELECT @IaB = ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'CAD_PESSOA' AND a.CODIGO = 'ALTERAR';
INSERT SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO) VALUES (@U, @IaB, 'C');

-- Ponto do histórico (tudo acima fica antes dele)
WAITFOR DELAY '00:00:02';
SET @Marco = DATEADD(SECOND, -1, CAST(SYSDATETIME() AS DATETIME2(0)));

-- Lixeira: excluir
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Claude, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1;
INSERT @r SELECT N'sem permissão EXCLUIR: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_EMPRESA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1;
INSERT @r SELECT N'tela que não mostra a tabela: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1, @Motivo = N'cadastro em dobro';
SELECT @Lx = ID_LIXEIRA, @Dt = DT_APAGAR FROM @ex;
INSERT @r SELECT N'exclui P1 para a lixeira', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
INSERT @r SELECT N'prazo de 90 dias', N'90', CAST(DATEDIFF(DAY, @Hoje, @Dt) AS NVARCHAR(5));
INSERT @r SELECT N'P1 desativado e marcado', N'0|S', (SELECT CAST(ATIVO AS NVARCHAR(1)) + N'|' + CASE WHEN DT_EXCLUSAO IS NOT NULL AND USUARIO_EXCLUSAO = N'celso' THEN N'S' ELSE N'N' END FROM CAD.Pessoa WHERE ID_PESSOA = @P1);
INSERT @r SELECT N'fn_SIS_Na_Lixeira', N'1', CAST(SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', @P1) AS NVARCHAR(1));
INSERT @r SELECT N'descrição guardada', N'Teste 04b P1', (SELECT DESCRICAO FROM SIS.Lixeira WHERE ID_LIXEIRA = @Lx);
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1;
INSERT @r SELECT N'excluir de novo: já está na lixeira', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
INSERT @ds EXEC CAD.CAD_Pessoa_Excluir @IdUsuario = @Celso, @IdPessoa = @P1, @Reativar = 1;
INSERT @r SELECT N'reativar quem está na lixeira: recusado', N'0|S', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CASE WHEN MENSAGEM LIKE N'%lixeira%' THEN N'S' ELSE N'N' END FROM @ds); DELETE @ds;
INSERT @lista EXEC SIS.SIS_Lixeira_Listar @IdUsuario = @Celso, @Modulo = 'CAD', @Texto = N'Teste 04b';
INSERT @r SELECT N'lista da lixeira (módulo Cadastros)', N'1|CAD_PESSOA|Pessoas', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) + N'|' + MAX(ITEM_CODIGO) + N'|' + MAX(TELA_NOME) FROM @lista); DELETE @lista;

-- Usado em outro lugar
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P2;
INSERT @r SELECT N'P2 é vinculada a P3: não exclui', N'0|S', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CASE WHEN MENSAGEM LIKE N'%usado em Pessoas%Desativar%' THEN N'S' ELSE N'N' END FROM @ex); DELETE @ex;
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P3;
INSERT @r SELECT N'P3 (com vínculo próprio, que vai junto) exclui', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
IF @PRef IS NOT NULL
BEGIN
    INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @PRef;
    INSERT @r SELECT N'pessoa com lançamento no financeiro: não exclui', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ex); DELETE @ex;
END;

-- Recuperar
INSERT @rc EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = @Claude, @IdLixeira = @Lx;
INSERT @r SELECT N'recuperar sem permissão: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @rc); DELETE @rc;
INSERT @rc EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = @Celso, @IdLixeira = @Lx, @Motivo = N'excluído por engano';
INSERT @r SELECT N'recupera P1', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @rc); DELETE @rc;
INSERT @r SELECT N'P1 volta ativo e sem a marca', N'1|N', (SELECT CAST(ATIVO AS NVARCHAR(1)) + N'|' + CASE WHEN DT_EXCLUSAO IS NULL AND USUARIO_EXCLUSAO IS NULL THEN N'N' ELSE N'S' END FROM CAD.Pessoa WHERE ID_PESSOA = @P1);
INSERT @r SELECT N'linha da lixeira RECUPERADO', N'RECUPERADO', (SELECT SITUACAO FROM SIS.Lixeira WHERE ID_LIXEIRA = @Lx);
INSERT @rc EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = @Celso, @IdLixeira = @Lx;
INSERT @r SELECT N'recuperar de novo: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @rc); DELETE @rc;

-- Conflito de CPF na recuperação, manter e esvaziar
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P4;
SELECT @Lx4 = ID_LIXEIRA, @Dt = DT_APAGAR FROM @ex; DELETE @ex;
INSERT CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ) VALUES ('F', N'Teste 04b P5', '99999999904'); SET @P5 = SCOPE_IDENTITY();
INSERT @rc EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = @Celso, @IdLixeira = @Lx4;
INSERT @r SELECT N'outro cadastro com o mesmo CPF: não recupera', N'0|S', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CASE WHEN MENSAGEM LIKE N'%Teste 04b P5%' THEN N'S' ELSE N'N' END FROM @rc); DELETE @rc;
INSERT @mt EXEC SIS.SIS_Lixeira_Manter @IdUsuario = @Celso, @IdLixeira = @Lx4, @Dias = 10;
INSERT @r SELECT N'manter mais 10 dias', N'1|10', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CAST(DATEDIFF(DAY, @Dt, DT_APAGAR) AS NVARCHAR(5)) FROM @mt); DELETE @mt;
SET @Msg = CAST(@Lx4 AS NVARCHAR(20));
INSERT @ev EXEC SIS.SIS_Lixeira_Esvaziar @IdUsuario = @Claude, @Ids = @Msg;
INSERT @r SELECT N'esvaziar sem permissão: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @ev); DELETE @ev;
INSERT @ev EXEC SIS.SIS_Lixeira_Esvaziar @IdUsuario = @Celso, @Ids = @Msg;
INSERT @r SELECT N'esvaziar agora apaga P4', N'1|1|0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CAST(QTD_APAGADOS AS NVARCHAR(5)) + N'|' + CAST(QTD_RECUSADOS AS NVARCHAR(5)) FROM @ev); DELETE @ev;
INSERT @r SELECT N'P4 e o contato dela apagados de vez', N'0|0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM CAD.Pessoa WHERE ID_PESSOA = @P4) + N'|' + (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM CAD.Pessoa_Contato WHERE ID_PESSOA_CONTATO = @C4);
INSERT @r SELECT N'cópia da P4 guardada na auditoria', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Auditoria WHERE TABELA = N'CAD.Pessoa' AND ID_REGISTRO = @P4 AND OPERACAO = 'E');
INSERT @r SELECT N'linha da lixeira APAGADO', N'APAGADO', (SELECT SITUACAO FROM SIS.Lixeira WHERE ID_LIXEIRA = @Lx4);

-- Trava de mês fechado (configuração temporária no Centro de custo)
SELECT TOP 1 @E = ID_EMPRESA FROM CAD.Empresa ORDER BY ID_EMPRESA;
IF @E IS NULL BEGIN INSERT CAD.Empresa (RAZAO_SOCIAL) VALUES (N'Teste 04b empresa'); SET @E = SCOPE_IDENTITY(); END;
INSERT CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO) VALUES (@E, 'T04B', N'Teste 04b', 'ADMINISTRATIVO'); SET @CC = SCOPE_IDENTITY();
UPDATE SIS.Tabela_Config SET COLUNA_EMPRESA = N'ID_EMPRESA', COLUNA_DATA_MES = N'DT_CRIACAO' WHERE TABELA = N'CAD.Centro_Custo';
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO = 'CAD_CENTRO_CUSTO';  -- tela ainda não construída: liga só dentro do teste
IF EXISTS (SELECT 1 FROM FIN.Mes_Fechado WHERE ID_EMPRESA = @E AND MES = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1))
    UPDATE FIN.Mes_Fechado SET FECHADO = 1 WHERE ID_EMPRESA = @E AND MES = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
ELSE
    INSERT FIN.Mes_Fechado (ID_EMPRESA, MES) VALUES (@E, DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1));
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_CENTRO_CUSTO', @Tabela = N'CAD.Centro_Custo', @IdRegistro = @CC;
INSERT @r SELECT N'mês fechado: não exclui', N'0|S', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CASE WHEN MENSAGEM LIKE N'%está fechado%' THEN N'S' ELSE N'N' END FROM @ex); DELETE @ex;
UPDATE SIS.Tabela_Config SET COLUNA_EMPRESA = N'', COLUNA_DATA_MES = N'' WHERE TABELA = N'CAD.Centro_Custo';

-- Rotina diária: apaga o vencido e avisa o que vence amanhã
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P7;
SELECT @Lx7 = ID_LIXEIRA FROM @ex; DELETE @ex;
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P8;
SELECT @Lx8 = ID_LIXEIRA FROM @ex; DELETE @ex;
UPDATE SIS.Lixeira SET DT_APAGAR = @Hoje WHERE ID_LIXEIRA = @Lx7;
UPDATE SIS.Lixeira SET DT_APAGAR = DATEADD(DAY, 1, @Hoje) WHERE ID_LIXEIRA = @Lx8;
SET @Emails = (SELECT COUNT(*) FROM SIS.Email_Fila WHERE TIPO = 'LIXEIRA_AVISO');
EXEC SIS.SIS_Lixeira_Processar;
INSERT @r SELECT N'rotina apaga o vencido (P7)', N'APAGADO|0', (SELECT SITUACAO FROM SIS.Lixeira WHERE ID_LIXEIRA = @Lx7) + N'|' + (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM CAD.Pessoa WHERE ID_PESSOA = @P7);
INSERT @r SELECT N'rotina avisa o que vence amanhã (1 e-mail)', N'1', CAST((SELECT COUNT(*) FROM SIS.Email_Fila WHERE TIPO = 'LIXEIRA_AVISO') - @Emails AS NVARCHAR(5));
INSERT @r SELECT N'e-mail do aviso lista a P8', N'S', (SELECT TOP 1 CASE WHEN CORPO_HTML LIKE N'%Teste 04b P8%' THEN N'S' ELSE N'N' END FROM SIS.Email_Fila WHERE TIPO = 'LIXEIRA_AVISO' ORDER BY ID_EMAIL DESC);
INSERT @r SELECT N'"avisado" só fora do banco de teste', CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN N'N' ELSE N'S' END, (SELECT CASE WHEN DT_AVISO IS NULL THEN N'N' ELSE N'S' END FROM SIS.Lixeira WHERE ID_LIXEIRA = @Lx8);
INSERT @lista EXEC SIS.SIS_Lixeira_Listar @IdUsuario = @Celso, @Texto = N'Teste 04b P8';
INSERT @r SELECT N'lista marca "apaga amanhã"', N'1', (SELECT CAST(APAGA_LOGO AS NVARCHAR(1)) FROM @lista); DELETE @lista;

-- Desfazer: voltar a P6 (com contatos) para o ponto do histórico
UPDATE CAD.Pessoa SET NOME = N'Teste 04b P6 mudado' WHERE ID_PESSOA = @P6;
UPDATE CAD.Pessoa_Contato SET VALOR = N'depois@teste.com' WHERE ID_PESSOA_CONTATO = @C1;
INSERT CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR) VALUES (@P6, 'CELULAR', N'35999990000'); SET @C2 = SCOPE_IDENTITY();
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P6, @DataHora = @Marco;
INSERT @r SELECT N'prévia: pode desfazer, 3 mudanças', N'1|3', (SELECT CAST(MAX(CAST(PODE_DESFAZER AS INT)) AS NVARCHAR(1)) + N'|' + CAST(SUM(CASE WHEN ACAO = 'ALTERAR' THEN 1 ELSE 0 END) AS NVARCHAR(5)) FROM @pv);
INSERT @r SELECT N'prévia: nome volta', N'Teste 04b P6', (SELECT VALOR_NOVO FROM @pv WHERE TABELA = N'CAD.Pessoa' AND CAMPO = N'NOME');
INSERT @r SELECT N'prévia: contato incluído depois é desativado', N'0', (SELECT VALOR_NOVO FROM @pv WHERE TABELA = N'CAD.Pessoa_Contato' AND ID_REGISTRO = @C2 AND CAMPO = N'ATIVO');
DELETE @pv;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P6, @DataHora = @Marco;
INSERT @r SELECT N'desfazer sem motivo: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df); DELETE @df;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Claude, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P6, @DataHora = @Marco, @Motivo = N'teste';
INSERT @r SELECT N'desfazer sem permissão: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df); DELETE @df;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P6, @DataHora = @Marco, @Motivo = N'mudado por engano';
INSERT @r SELECT N'desfaz: 3 campos em 3 registros', N'1|3|3', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CAST(QTD_CAMPOS AS NVARCHAR(5)) + N'|' + CAST(QTD_REGISTROS AS NVARCHAR(5)) FROM @df); DELETE @df;
INSERT @r SELECT N'P6, contato e contato novo como no ponto', N'Teste 04b P6|antes@teste.com|0',
       (SELECT NOME FROM CAD.Pessoa WHERE ID_PESSOA = @P6) + N'|' + (SELECT VALOR FROM CAD.Pessoa_Contato WHERE ID_PESSOA_CONTATO = @C1) + N'|' + (SELECT CAST(ATIVO AS NVARCHAR(1)) FROM CAD.Pessoa_Contato WHERE ID_PESSOA_CONTATO = @C2);
INSERT @r SELECT N'registro em SIS.Desfazer com o motivo', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Desfazer WHERE TIPO = 'REGISTRO' AND ID_REGISTRO = @P6 AND MOTIVO = N'mudado por engano');
INSERT @r SELECT N'auditoria do desfazer com origem "desfazer"', N'S', CASE WHEN EXISTS (SELECT 1 FROM SIS.Auditoria WHERE TABELA = N'CAD.Pessoa' AND ID_REGISTRO = @P6 AND CAMPO = N'NOME' AND ORIGEM LIKE N'%desfazer') THEN N'S' ELSE N'N' END;
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P6, @DataHora = @Marco;
INSERT @r SELECT N'prévia de novo: nada a desfazer', N'0|0', (SELECT CAST(MAX(CAST(PODE_DESFAZER AS INT)) AS NVARCHAR(1)) + N'|' + CAST(SUM(CASE WHEN ACAO <> 'NADA' THEN 1 ELSE 0 END) AS NVARCHAR(5)) FROM @pv); DELETE @pv;

-- Desfazer um lote, com conflito
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = -4201;
UPDATE CAD.Pessoa SET OBSERVACAO = N'do lote' WHERE ID_PESSOA = @P6;
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = NULL;
UPDATE CAD.Pessoa SET OBSERVACAO = N'mexido depois' WHERE ID_PESSOA = @P6;
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4201;
INSERT @r SELECT N'lote mexido depois: conflito na prévia', N'0|CONFLITO', (SELECT CAST(MAX(CAST(PODE_DESFAZER AS INT)) AS NVARCHAR(1)) + N'|' + MAX(SITUACAO) FROM @pv); DELETE @pv;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4201, @Motivo = N'teste';
INSERT @r SELECT N'lote com conflito: nada é desfeito', N'0|mexido depois', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df) + N'|' + (SELECT OBSERVACAO FROM CAD.Pessoa WHERE ID_PESSOA = @P6); DELETE @df;
UPDATE CAD.Pessoa SET OBSERVACAO = N'do lote' WHERE ID_PESSOA = @P6;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'LOTE', @IdLote = -4201, @Motivo = N'teste';
INSERT @r SELECT N'lote só pela tela de Auditoria', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df); DELETE @df;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4201, @Motivo = N'lote errado';
INSERT @r SELECT N'desfaz o lote', N'1|(vazio)', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df) + N'|' + (SELECT ISNULL(NULLIF(OBSERVACAO, N''), N'(vazio)') FROM CAD.Pessoa WHERE ID_PESSOA = @P6); DELETE @df;

-- Registro na lixeira: bloqueado no desfazer
INSERT @ex EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1; DELETE @ex;
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = @P1, @DataHora = @Marco;
INSERT @r SELECT N'registro na lixeira: bloqueado', N'0|BLOQUEADO|S', (SELECT CAST(MAX(CAST(PODE_DESFAZER AS INT)) AS NVARCHAR(1)) + N'|' + MAX(SITUACAO) + N'|' + CASE WHEN MAX(MENSAGEM) LIKE N'%lixeira%' THEN N'S' ELSE N'N' END FROM @pv); DELETE @pv;

-- Permissões (tabela de ligação): incluir e retirar num lote, desfazer o lote
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = -4202;
INSERT SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO) VALUES (@U, @IaA, 'C');
DELETE SIS.Usuario_Permissao WHERE ID_USUARIO = @U AND ID_ITEM_ACAO = @IaB;
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = NULL;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4202, @Motivo = N'permissões trocadas';
INSERT @r SELECT N'desfaz o lote de permissões', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df); DELETE @df;
INSERT @r SELECT N'permissão incluída saiu e a retirada voltou', N'0|1',
       (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Usuario_Permissao WHERE ID_USUARIO = @U AND ID_ITEM_ACAO = @IaA) + N'|'
     + (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Usuario_Permissao WHERE ID_USUARIO = @U AND ID_ITEM_ACAO = @IaB AND TIPO = 'C');

-- Senha nunca é desfeita
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = -4203;
UPDATE SIS.Usuario SET NOME = N'Outro nome', SENHA_HASH = CRYPT_GEN_RANDOM(32) WHERE ID_USUARIO = @U;
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = NULL;
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4203;
INSERT @r SELECT N'senha: ignorada na prévia', N'IGNORADO', (SELECT SITUACAO FROM @pv WHERE CAMPO = N'SENHA_HASH'); DELETE @pv;
INSERT @df EXEC SIS.SIS_Historico_Desfazer @IdUsuario = @Celso, @Item = 'SIS_AUDITORIA', @Modo = 'LOTE', @IdLote = -4203, @Motivo = N'nome errado';
INSERT @r SELECT N'desfaz o nome e não mexe na senha', N'1|Teste 04b', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @df) + N'|' + (SELECT NOME FROM SIS.Usuario WHERE ID_USUARIO = @U); DELETE @df;

-- Operação (transação): monta a prévia
SELECT @Aud = MAX(ID_AUDITORIA) FROM SIS.Auditoria WHERE TABELA = N'CAD.Pessoa' AND ID_REGISTRO = @P6;
INSERT @pv EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = @Celso, @Item = 'CAD_PESSOA', @Modo = 'OPERACAO', @IdAuditoria = @Aud;
INSERT @r SELECT N'operação: prévia monta as linhas', N'S', CASE WHEN EXISTS (SELECT 1 FROM @pv WHERE TABELA = N'CAD.Pessoa' AND ID_REGISTRO = @P6) THEN N'S' ELSE N'N' END; DELETE @pv;
ROLLBACK;
EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = NULL;

INSERT @r SELECT N'Obter da pessoa devolve NA_LIXEIRA', N'1', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC CAD.CAD_Pessoa_Obter 2, 1', NULL, 0) WHERE name = 'NA_LIXEIRA';
INSERT @r SELECT N'nada ficou gravado (ROLLBACK)', N'0|0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM CAD.Pessoa WHERE NOME LIKE N'Teste 04b%') + N'|'
     + (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Lixeira WHERE DESCRICAO LIKE N'Teste 04b%');

SELECT CASO, ESPERADO, ISNULL(OBTIDO, N'(nulo)') AS OBTIDO, CASE WHEN ESPERADO = ISNULL(OBTIDO, N'(nulo)') THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @r;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = ISNULL(OBTIDO, N'(nulo)') THEN 0 ELSE 1 END) AS FALHAS FROM @r;
