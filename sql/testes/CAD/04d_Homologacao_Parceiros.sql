/*******************************************************************************
  Teste       : 04d - Parceiros (P12, P10): tipos, contatos com finalidade e
                principal único, conta/centro padrão, apto para cobrança,
                configuração das consultas de CEP/CNPJ e cache, validade do anexo.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 25/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @P INT, @C1 INT, @C2 INT, @Pc INT, @J NVARCHAR(MAX), @Ok BIT;

INSERT @r SELECT N'tipos do sistema (NA, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR)', N'5', CAST(COUNT(*) AS NVARCHAR(5)) FROM CAD.Parceiro_Tipo WHERE SISTEMA = 1;
INSERT @r SELECT N'todo parceiro tem pelo menos um tipo ativo', N'0', CAST(COUNT(*) AS NVARCHAR(10))
       FROM CAD.Pessoa p WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1);
INSERT @r SELECT N'marcas antigas batem com os tipos do sistema', N'0', CAST(COUNT(*) AS NVARCHAR(10))
       FROM CAD.Pessoa p
       WHERE p.CLIENTE <> CASE WHEN EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                                            WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1 AND t.CODIGO = 'CLIENTE') THEN 1 ELSE 0 END;
INSERT @r SELECT N'um só e-mail principal ativo por parceiro', N'0', CAST(COUNT(*) AS NVARCHAR(10))
       FROM (SELECT ID_PESSOA FROM CAD.Pessoa_Contato WHERE PRINCIPAL = 1 AND ATIVO = 1 GROUP BY ID_PESSOA, TIPO HAVING COUNT(*) > 1) d;
INSERT @r SELECT N'parâmetros novos da 04d', N'13', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro
       WHERE CHAVE IN ('PARCEIRO_ROTULO', 'PARCEIRO_ROTULO_PLURAL', 'CEP_CONSULTA_ATIVA', 'CEP_URL_PRINCIPAL', 'CEP_URL_RESERVA', 'CEP_CACHE_DIAS',
                       'CNPJ_CONSULTA_ATIVA', 'CNPJ_URL', 'CONSULTA_TEMPO_LIMITE_SEG', 'COBRANCA_APTO_EXIGE_DOCUMENTO', 'COBRANCA_APTO_EXIGE_ENDERECO',
                       'COBRANCA_APTO_EXIGE_EMAIL', 'COBRANCA_APTO_EXIGE_TELEFONE');
INSERT @r SELECT N'tela Tipos de parceiro cadastrada', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item WHERE CODIGO = 'CAD_PARCEIRO_TIPO';

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO = 'CAD' AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('CAD_PESSOA', 'CAD_PARCEIRO_TIPO') AND HABILITADO = 0;

-- tipos de parceiro
INSERT @g EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = @Celso, @Codigo = 'empreiteiro_t', @Descricao = N'Empreiteiro teste';
INSERT @r SELECT N'inclui tipo novo (código vira maiúsculas)', N'EMPREITEIRO_T', (SELECT CODIGO FROM CAD.Parceiro_Tipo WHERE ID_PARCEIRO_TIPO = (SELECT ID FROM @g));
DELETE @g;
INSERT @g EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = @Celso, @IdParceiroTipo = 2, @Codigo = 'CLIENTE', @Descricao = N'Cliente', @Ativo = 0;
INSERT @r SELECT N'tipo do sistema não desativa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = @Celso, @Codigo = 'Emp-1', @Descricao = N'X';
INSERT @r SELECT N'código inválido recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = @Claude, @Codigo = 'OUTRO_T', @Descricao = N'X';
INSERT @r SELECT N'usuário só de consulta não grava tipo', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;

-- parceiro sem tipo nasce N/A; contatos com finalidade
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @TipoPessoa = 'F', @Nome = N'Teste 04d', @CpfCnpj = '529.982.247-25',
     @Contatos = N'[{"tipo":"EMAIL","valor":"a@teste.com","principal":true,"finalidade":"cobranca"},{"tipo":"EMAIL","valor":"b@teste.com","principal":false}]';
SET @P = (SELECT ID FROM @g);
INSERT @r SELECT N'parceiro sem tipo nasce N/A', N'NA', (SELECT STRING_AGG(t.CODIGO, ',') FROM CAD.Pessoa_Tipo x JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO WHERE x.ID_PESSOA = @P AND x.ATIVO = 1);
INSERT @r SELECT N'finalidade gravada', N'COBRANCA', (SELECT FINALIDADE FROM CAD.Pessoa_Contato WHERE ID_PESSOA = @P AND VALOR = N'a@teste.com');
INSERT @r SELECT N'sem endereço: não apto para cobrança', N'0', (SELECT CAST(APTO AS NVARCHAR(1)) FROM CAD.fn_CAD_Pessoa_Pendencia_Cobranca(@P));

-- tipos + troca de principal + conta padrão + endereço completo
SELECT @C1 = ID_PESSOA_CONTATO FROM CAD.Pessoa_Contato WHERE ID_PESSOA = @P AND VALOR = N'a@teste.com';
SELECT @C2 = ID_PESSOA_CONTATO FROM CAD.Pessoa_Contato WHERE ID_PESSOA = @P AND VALOR = N'b@teste.com';
SET @J = N'[{"id":' + CAST(@C1 AS NVARCHAR(10)) + N',"tipo":"EMAIL","valor":"a@teste.com","principal":false},{"id":' + CAST(@C2 AS NVARCHAR(10)) + N',"tipo":"EMAIL","valor":"b@teste.com","principal":true}]';
SET @Pc = (SELECT TOP 1 ID_PLANO_CONTA FROM CAD.Plano_Conta WHERE ATIVO = 1);
DELETE @g;
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @IdPessoa = @P, @TipoPessoa = 'F', @Nome = N'Teste 04d', @CpfCnpj = '529.982.247-25', @Tipos = N'[2,3]', @Contatos = @J,
     @IdPlanoContaPadrao = @Pc, @Cep = '37701-000', @Logradouro = N'Rua A', @Numero = N'10', @Bairro = N'Centro', @Cidade = N'Poços de Caldas', @Uf = 'MG';
INSERT @r SELECT N'grava com tipos cliente e fornecedor', N'CLIENTE,FORNECEDOR', (SELECT STRING_AGG(t.CODIGO, ',') WITHIN GROUP (ORDER BY t.ORDEM) FROM CAD.Pessoa_Tipo x JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO WHERE x.ID_PESSOA = @P AND x.ATIVO = 1);
INSERT @r SELECT N'marcas acertadas pelos tipos', N'1100', (SELECT CONCAT(CAST(CLIENTE AS INT), CAST(FORNECEDOR AS INT), CAST(FUNCIONARIO AS INT), CAST(CORRETOR AS INT)) FROM CAD.Pessoa WHERE ID_PESSOA = @P);
INSERT @r SELECT N'troca do e-mail principal', N'b@teste.com', (SELECT VALOR FROM CAD.Pessoa_Contato WHERE ID_PESSOA = @P AND PRINCIPAL = 1 AND ATIVO = 1);
INSERT @r SELECT N'conta padrão gravada', N'S', CASE WHEN (SELECT ID_PLANO_CONTA_PADRAO FROM CAD.Pessoa WHERE ID_PESSOA = @P) = @Pc THEN N'S' ELSE N'N' END;
INSERT @r SELECT N'cadastro completo: apto para cobrança', N'1', (SELECT CAST(APTO AS NVARCHAR(1)) FROM CAD.fn_CAD_Pessoa_Pendencia_Cobranca(@P));

-- chamada antiga (sem @Tipos e sem conta): mantém conta, tipos pelas marcas
DELETE @g;
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @IdPessoa = @P, @TipoPessoa = 'F', @Nome = N'Teste 04d', @Cliente = 1;
INSERT @r SELECT N'sem @Tipos: tipos pelas marcas', N'CLIENTE', (SELECT STRING_AGG(t.CODIGO, ',') FROM CAD.Pessoa_Tipo x JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO WHERE x.ID_PESSOA = @P AND x.ATIVO = 1);
INSERT @r SELECT N'conta padrão NULL = não mexe', N'S', CASE WHEN (SELECT ID_PLANO_CONTA_PADRAO FROM CAD.Pessoa WHERE ID_PESSOA = @P) = @Pc THEN N'S' ELSE N'N' END;
DELETE @g;
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @IdPessoa = @P, @TipoPessoa = 'F', @Nome = N'Teste 04d', @IdPlanoContaPadrao = 0;
INSERT @r SELECT N'conta padrão 0 = limpa', N'S', CASE WHEN (SELECT ID_PLANO_CONTA_PADRAO FROM CAD.Pessoa WHERE ID_PESSOA = @P) IS NULL THEN N'S' ELSE N'N' END;
DELETE @g;
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @IdPessoa = @P, @TipoPessoa = 'F', @Nome = N'Teste 04d', @Contatos = N'[{"tipo":"EMAIL","valor":"c@teste.com","finalidade":"X"}]';
INSERT @r SELECT N'finalidade inválida recusada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @Celso, @IdPessoa = @P, @TipoPessoa = 'F', @Nome = N'Teste 04d', @Tipos = N'[999]';
INSERT @r SELECT N'tipo inexistente recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);

-- consultas de CEP: configuração e cache
EXEC CAD.CAD_Cep_Cache_Gravar @IdUsuario = @Celso, @Cep = '99999-999', @Logradouro = N'Rua Teste', @Cidade = N'Cidade Teste', @Uf = 'mg', @Fonte = 'TESTE';
DECLARE @cfg TABLE (PODE BIT, CEP_ATIVA BIT, CEP_URL_PRINCIPAL NVARCHAR(4000), CEP_URL_RESERVA NVARCHAR(4000), CNPJ_ATIVA BIT, CNPJ_URL NVARCHAR(4000), TEMPO_LIMITE_SEG INT,
                    LOGRADOURO NVARCHAR(150), COMPLEMENTO NVARCHAR(60), BAIRRO NVARCHAR(60), CIDADE NVARCHAR(60), UF CHAR(2), CODIGO_IBGE VARCHAR(7), FONTE VARCHAR(20), CEP_EM_CACHE BIT);
INSERT @cfg EXEC CAD.CAD_Consulta_Config_Obter @IdUsuario = @Celso, @Cep = '99999999';
INSERT @r SELECT N'CEP guardado volta do cache (UF em maiúsculas)', N'1 MG', (SELECT CONCAT(CAST(CEP_EM_CACHE AS INT), N' ', UF) FROM @cfg);
DELETE @cfg;
INSERT @cfg EXEC CAD.CAD_Consulta_Config_Obter @IdUsuario = @Claude, @Cep = '99999999';
INSERT @r SELECT N'usuário só de consulta não usa a consulta', N'0 0', (SELECT CONCAT(CAST(PODE AS INT), N' ', CAST(CEP_EM_CACHE AS INT)) FROM @cfg);

-- validade do anexo
INSERT @r SELECT N'Anexo_Listar devolve DT_VALIDADE e VENCIDO', N'2', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Anexo_Listar @IdUsuario = 1, @Item = ''CAD_PESSOA'', @Tabela = N''CAD.Pessoa'', @IdRegistro = 1', NULL, 0)
       WHERE name IN ('DT_VALIDADE', 'VENCIDO');
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
