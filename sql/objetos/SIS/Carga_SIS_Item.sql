/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Item] e [SIS].[Item_Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Menu do módulo SIS e as ações de cada tela. Só insere o que
                falta (regra 39). Cada etapa seguinte acrescenta aqui os itens
                do seu módulo (ou cria a carga do seu bloco).
                Itens são inseridos em passadas: primeiro os de 1º nível,
                depois os filhos cujo pai já existe (até 5 níveis).
                Caminhos das telas: relativos ao wwwroot da API (fase 4).
                Acertado também em item já existente (itens só mudam por
                carga): EXCLUSIVO_GERAL e TABELAS_DA_TELA.
                HABILITADO só é gravado na inclusão (depois é escolha do
                administrador geral). Telas do SIS nascem habilitadas; telas de
                módulos novos devem nascer com HABILITADO = 0.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL: Licença e Parâmetros só para o
                        administrador geral (acertado também em item já
                        existente, porque itens só mudam por carga).
    v1.2 (16/11/2026) - Etapa 02c: HABILITADO, TABELAS_DA_TELA e as telas
                        "Módulos e telas" (exclusiva), "Auditoria" e "Lotes".
    v1.3 (16/11/2026) - Etapa 02d: "Rotinas automáticas" e "Instalação e
                        manutenção" (exclusivas); agrupador "E-mails" com
                        "Grupos de e-mail" e "E-mails enviados".
    v1.4 (22/11/2026) - Etapa 04b (P20): tela "Lixeira" (Monitoramento) e ação
                        DESFAZER em Usuários, Perfis e Auditoria (lote).
    v1.5 (23/11/2026) - Etapa 04c (P22): tela "Versões" (Monitoramento). VER
                        libera o histórico de atualizações; as notas das
                        versões são para todos (não dependem de permissão).
    v1.6 (25/11/2026) - Etapa 04f: tela "Parâmetros de uso" (SIS_PARAMETRO_USO,
                        mesma tela de Parâmetros com ?uso=1): os dois
                        administradores alteram os parâmetros de NIVEL_MINIMO 1
                        (decisão do Celso de 18/11/2026). VER, ALTERAR e EXPORTAR.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.PAI, v.CODIGO, v.NOME, v.TIPO, v.CAMINHO, v.ORDEM, v.EXCLUSIVO_GERAL, v.HABILITADO, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('SIS' AS VARCHAR(10)), CAST(NULL AS VARCHAR(40)), CAST('SIS_CONFIGURACAO' AS VARCHAR(40)), CAST(N'Configuração' AS NVARCHAR(80)),
         CAST('MENU' AS VARCHAR(10)), CAST('' AS VARCHAR(200)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(1 AS BIT), CAST('' AS VARCHAR(500))),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_LICENCA',       N'Licença',             'TELA', 'sis/licenca.html',     10, 1, 1, 'SIS.Licenca,SIS.Licenca_Empresa'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO',     N'Parâmetros',          'TELA', 'sis/parametros.html',  20, 1, 1, 'SIS.Parametro'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO_USO', N'Parâmetros de uso',   'TELA', 'sis/parametros.html?uso=1', 25, 0, 1, 'SIS.Parametro'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_MODULO',        N'Módulos e telas',     'TELA', 'sis/modulos.html',     30, 1, 1, 'SIS.Modulo,SIS.Item'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_ROTINA',        N'Rotinas automáticas', 'TELA', 'sis/rotinas.html',     40, 1, 1, 'SIS.Rotina'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_INSTALACAO',    N'Instalação e manutenção', 'TELA', 'sis/instalacao.html', 50, 1, 1, ''),
        ('SIS', NULL,                'SIS_SEGURANCA',     N'Segurança',           'MENU', '',                     20, 0, 1, ''),
        ('SIS', 'SIS_SEGURANCA',     'SIS_USUARIO',       N'Usuários',            'TELA', 'sis/usuarios.html',    10, 0, 1, 'SIS.Usuario,SIS.Usuario_Permissao'),
        ('SIS', 'SIS_SEGURANCA',     'SIS_PERFIL',        N'Perfis e permissões', 'TELA', 'sis/perfis.html',      20, 0, 1, 'SIS.Perfil,SIS.Perfil_Permissao'),
        ('SIS', NULL,                'SIS_EMAILS',        N'E-mails',             'MENU', '',                     25, 0, 1, ''),
        ('SIS', 'SIS_EMAILS',        'SIS_GRUPO_EMAIL',   N'Grupos de e-mail',    'TELA', 'sis/grupos-email.html', 10, 0, 1, 'SIS.Grupo_Email,SIS.Grupo_Email_Destinatario'),
        ('SIS', 'SIS_EMAILS',        'SIS_EMAIL_FILA',    N'E-mails enviados',    'TELA', 'sis/emails.html',      20, 0, 1, ''),
        ('SIS', NULL,                'SIS_MONITORAMENTO', N'Monitoramento',       'MENU', '',                     30, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOG_ERRO',      N'Log de erros',        'TELA', 'sis/log-erros.html',   10, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_AUDITORIA',     N'Auditoria',           'TELA', 'sis/auditoria.html',   20, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOTE',          N'Lotes',               'TELA', 'sis/lotes.html',       30, 0, 1, 'SIS.Lote'),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LIXEIRA',       N'Lixeira',             'TELA', 'sis/lixeira.html',     40, 0, 1, 'SIS.Lixeira,SIS.Tabela_Config'),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_VERSOES',       N'Versões',             'TELA', 'sis/versoes.html',     50, 0, 1, '')
     ) v (MODULO, PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS);

DECLARE @Passada INT = 1;
WHILE @Passada <= 5
BEGIN
    INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
    SELECT m.ID_MODULO, pai.ID_ITEM, c.CODIGO, c.NOME, c.TIPO, c.CAMINHO, c.ORDEM, c.EXCLUSIVO_GERAL, c.HABILITADO, c.TABELAS
    FROM #CargaItem c
    INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
    LEFT  JOIN SIS.Item pai ON pai.CODIGO = c.PAI
    WHERE (c.PAI IS NULL OR pai.ID_ITEM IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

    SET @Passada = @Passada + 1;
END;

UPDATE i
   SET i.EXCLUSIVO_GERAL   = c.EXCLUSIVO_GERAL,
       i.TABELAS_DA_TELA   = c.TABELAS,
       i.DT_ALTERACAO      = SYSDATETIME(),
       i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.EXCLUSIVO_GERAL <> c.EXCLUSIVO_GERAL
   OR i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('SIS_LICENCA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('SIS_LICENCA',   'INCLUIR'),
        ('SIS_PARAMETRO', 'VER'),
        ('SIS_PARAMETRO', 'ALTERAR'),
        ('SIS_PARAMETRO', 'EXPORTAR'),
        ('SIS_PARAMETRO_USO', 'VER'),
        ('SIS_PARAMETRO_USO', 'ALTERAR'),
        ('SIS_PARAMETRO_USO', 'EXPORTAR'),
        ('SIS_MODULO',    'VER'),
        ('SIS_MODULO',    'ALTERAR'),
        ('SIS_USUARIO',   'VER'),
        ('SIS_USUARIO',   'INCLUIR'),
        ('SIS_USUARIO',   'ALTERAR'),
        ('SIS_USUARIO',   'DESBLOQUEAR'),
        ('SIS_USUARIO',   'REDEFINIR_SENHA'),
        ('SIS_USUARIO',   'EXPORTAR'),
        ('SIS_PERFIL',    'VER'),
        ('SIS_PERFIL',    'INCLUIR'),
        ('SIS_PERFIL',    'ALTERAR'),
        ('SIS_PERFIL',    'EXPORTAR'),
        ('SIS_LOG_ERRO',  'VER'),
        ('SIS_LOG_ERRO',  'EXPORTAR'),
        ('SIS_AUDITORIA', 'VER'),
        ('SIS_AUDITORIA', 'EXPORTAR'),
        ('SIS_LOTE',      'VER'),
        ('SIS_LOTE',      'EXPORTAR'),
        ('SIS_ROTINA',    'VER'),
        ('SIS_ROTINA',    'ALTERAR'),
        ('SIS_ROTINA',    'EXECUTAR'),
        ('SIS_INSTALACAO','VER'),
        ('SIS_INSTALACAO','EXECUTAR'),
        ('SIS_INSTALACAO','CANCELAR'),
        ('SIS_GRUPO_EMAIL','VER'),
        ('SIS_GRUPO_EMAIL','INCLUIR'),
        ('SIS_GRUPO_EMAIL','ALTERAR'),
        ('SIS_GRUPO_EMAIL','EXPORTAR'),
        ('SIS_EMAIL_FILA','VER'),
        ('SIS_EMAIL_FILA','ENVIAR'),
        ('SIS_EMAIL_FILA','CANCELAR'),
        ('SIS_EMAIL_FILA','EXPORTAR'),
        ('SIS_LIXEIRA',   'VER'),
        ('SIS_LIXEIRA',   'RECUPERAR'),
        ('SIS_LIXEIRA',   'ALTERAR'),
        ('SIS_LIXEIRA',   'ESVAZIAR'),
        ('SIS_LIXEIRA',   'EXPORTAR'),
        ('SIS_USUARIO',   'DESFAZER'),
        ('SIS_PERFIL',    'DESFAZER'),
        ('SIS_AUDITORIA', 'DESFAZER'),
        ('SIS_VERSOES',   'VER'),
        ('SIS_VERSOES',   'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
