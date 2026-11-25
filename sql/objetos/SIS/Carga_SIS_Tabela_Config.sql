/*******************************************************************************
  Objeto      : carga de [SIS].[Tabela_Config] e do grupo de e-mail da lixeira
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração do desfazer e da lixeira por tabela (P20,
                docs/requisitos/Lixeira_Desfazer.md). Inclui o que falta e
                acerta a parte técnica (filhas, campos, descrição) das que já
                existem; o prazo próprio (DIAS_GUARDA) é da CMJ e nunca é
                mudado por aqui.
                Grupo de e-mail LIXEIRA_AVISO (aviso do que será apagado):
                nasce com o e-mail interno do sistema; a CMJ ajusta na tela
                Grupos de e-mail.
                Idempotente.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
    v1.1 (25/11/2026) - Etapa 04d: CAD.Pessoa_Tipo (filha da Pessoa) e CAD.Parceiro_Tipo.
    v1.2 (25/11/2026) - Etapa 04f: FIN.Lancamento (lixeira, parcelas vão junto,
                        trava própria FIN_Lancamento_Trava_Conferir: só manual,
                        sem baixa, mês fechado de conta contábil) e FIN.Parcela
                        (desfazer; inclusão de parcela não é desfeita).
                        PROC_VALIDAR entra também pela carga.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaConfig;

SELECT v.TABELA, v.DESFAZER, v.LIXEIRA, v.BLOQUEADOS, v.UNICOS, v.FILHAS, v.INCLUSAO, v.EXCLUSAO, v.DESCRICAO
INTO #CargaConfig
FROM (VALUES
        (CAST(N'CAD.Pessoa' AS NVARCHAR(256)), CAST(1 AS BIT), CAST(1 AS BIT), CAST(N'' AS NVARCHAR(1000)), CAST(N'CPF_CNPJ' AS NVARCHAR(400)),
         CAST(N'CAD.Pessoa_Contato.ID_PESSOA,CAD.Pessoa_Vinculo.ID_PESSOA,CAD.Pessoa_Dado_Bancario.ID_PESSOA,CAD.Pessoa_Tipo.ID_PESSOA' AS NVARCHAR(1000)),
         CAST('LIXEIRA' AS VARCHAR(10)), CAST('RECUSAR' AS VARCHAR(10)),
         CAST(N't.NOME + CASE WHEN t.CPF_CNPJ <> '''' THEN N'' ('' + CONVERT(NVARCHAR(20), t.CPF_CNPJ) + N'')'' ELSE N'''' END' AS NVARCHAR(1000))),
        (N'CAD.Pessoa_Contato',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(20), t.TIPO) + N'': '' + t.VALOR'),
        (N'CAD.Pessoa_Tipo',          1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Tipo '' + CAST(t.ID_PARCEIRO_TIPO AS NVARCHAR(10))'),
        (N'CAD.Parceiro_Tipo',        1, 1, N'SISTEMA', N'CODIGO', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Pessoa_Vinculo',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Vínculo '' + CONVERT(NVARCHAR(30), t.TIPO)'),
        (N'CAD.Pessoa_Dado_Bancario', 1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Conta '' + CONVERT(NVARCHAR(20), t.AGENCIA) + N'' / '' + CONVERT(NVARCHAR(30), t.CONTA)'),
        (N'CAD.Empresa',              1, 1, N'', N'CNPJ', N'', 'LIXEIRA', 'RECUSAR', N't.RAZAO_SOCIAL'),
        (N'CAD.Centro_Custo',         1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N'CONVERT(NVARCHAR(30), t.CODIGO) + N'' - '' + t.DESCRICAO'),
        (N'CAD.Plano_Grupo',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Subgrupo',       1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Conta',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Conta',              1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Banco',              1, 0, N'', N'', N'', 'RECUSAR', 'RECUSAR', N'CONVERT(NVARCHAR(10), t.CODIGO) + N'' - '' + t.NOME'),
        (N'SIS.Usuario',              1, 0, N'SENHA_HASH,SENHA_SALT,SENHA_ITERACOES,SENHA_ALGORITMO,DT_SENHA,TROCAR_SENHA,TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN,BLOQUEADO,DT_BLOQUEIO,INTERNO',
         N'', N'SIS.Usuario_Permissao.ID_USUARIO', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(100), t.LOGIN) + N'' - '' + t.NOME'),
        (N'SIS.Usuario_Permissao',    1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'SIS.Perfil',               1, 0, N'NIVEL_ADMIN', N'', N'SIS.Perfil_Permissao.ID_PERFIL', 'DESATIVAR', 'RECUSAR', N't.NOME'),
        (N'SIS.Perfil_Permissao',     1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'FIN.Lancamento',           1, 1, N'TIPO,ORIGEM,ID_ORIGEM,ID_LOTE,CODIGO_ACCESS,ORIGEM_ACCESS,ID_PEDIDO_COMPRA', N'', N'FIN.Parcela.ID_LANCAMENTO', 'LIXEIRA', 'RECUSAR',
         N'CASE t.TIPO WHEN ''P'' THEN N''A pagar '' ELSE N''A receber '' END + CASE WHEN t.DOCUMENTO <> N'''' THEN N''doc. '' + t.DOCUMENTO + N'' - '' ELSE N'''' END + t.HISTORICO + N'' ('' + CONVERT(NVARCHAR(30), t.VALOR_TOTAL) + N'')'''),
        (N'FIN.Parcela',              1, 0, N'VALOR_BAIXADO,SITUACAO,ID_LANCAMENTO,CODIGO_ACCESS,ID_LOTE', N'', N'', 'RECUSAR', 'RECUSAR',
         N'N''Parcela '' + CONVERT(NVARCHAR(5), t.NUMERO) + N''/'' + CONVERT(NVARCHAR(5), t.QTD_PARCELAS) + N'' venc. '' + CONVERT(NVARCHAR(10), t.DT_VENCIMENTO, 103)')
     ) v (TABELA, DESFAZER, LIXEIRA, BLOQUEADOS, UNICOS, FILHAS, INCLUSAO, EXCLUSAO, DESCRICAO);

INSERT INTO SIS.Tabela_Config (TABELA, PERMITE_DESFAZER, PERMITE_LIXEIRA, CAMPOS_BLOQUEADOS, CAMPOS_UNICOS, TABELAS_FILHAS, DESFAZER_INCLUSAO, DESFAZER_EXCLUSAO, DESCRICAO_SQL, USUARIO_CRIACAO)
SELECT c.TABELA, c.DESFAZER, c.LIXEIRA, c.BLOQUEADOS, c.UNICOS, c.FILHAS, c.INCLUSAO, c.EXCLUSAO, c.DESCRICAO, N'instalacao'
FROM #CargaConfig c
WHERE OBJECT_ID(c.TABELA, N'U') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config t WHERE t.TABELA = c.TABELA);

UPDATE t
   SET t.PERMITE_DESFAZER = c.DESFAZER, t.PERMITE_LIXEIRA = c.LIXEIRA, t.CAMPOS_BLOQUEADOS = c.BLOQUEADOS, t.CAMPOS_UNICOS = c.UNICOS,
       t.TABELAS_FILHAS = c.FILHAS, t.DESFAZER_INCLUSAO = c.INCLUSAO, t.DESFAZER_EXCLUSAO = c.EXCLUSAO, t.DESCRICAO_SQL = c.DESCRICAO,
       t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN #CargaConfig c ON c.TABELA = t.TABELA
WHERE t.PERMITE_DESFAZER <> c.DESFAZER OR t.PERMITE_LIXEIRA <> c.LIXEIRA OR t.CAMPOS_BLOQUEADOS <> c.BLOQUEADOS OR t.CAMPOS_UNICOS <> c.UNICOS
   OR t.TABELAS_FILHAS <> c.FILHAS OR t.DESFAZER_INCLUSAO <> c.INCLUSAO OR t.DESFAZER_EXCLUSAO <> c.EXCLUSAO OR t.DESCRICAO_SQL <> c.DESCRICAO;

UPDATE t
   SET t.PROC_VALIDAR = v.PROC_VALIDAR, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN (VALUES (CAST(N'FIN.Lancamento' AS NVARCHAR(256)), CAST(N'FIN.FIN_Lancamento_Trava_Conferir' AS NVARCHAR(256))),
                   (N'FIN.Parcela', N'FIN.FIN_Lancamento_Trava_Conferir')) v (TABELA, PROC_VALIDAR) ON v.TABELA = t.TABELA
WHERE t.PROC_VALIDAR <> v.PROC_VALIDAR;

DROP TABLE IF EXISTS #CargaConfig;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'LIXEIRA_AVISO', N'Aviso da lixeira', N'Recebem o aviso diário do que será apagado de vez da lixeira (Sistema › Lixeira).', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'LIXEIRA_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'LIXEIRA_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);
GO
