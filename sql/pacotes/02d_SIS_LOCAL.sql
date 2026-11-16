/*******************************************************************************
  Pacote      : 02d - base SIS (e-mail, agenda das rotinas, comandos de instalação, papel da API, módulo Compras)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 16/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a, 02b, 02b2 e 02c já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02d_Homologacao_SIS.sql e depois
                02c_Homologacao_SIS.sql (v1.3) e 02b_Homologacao_SIS.sql.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/_GERAL/Schemas.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : schemas do SistemaCMJ
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cria os schemas por bloco (PADRAO_SQL regra 31).
                O schema MIG (migração) não é criado aqui: ele não entra no
                MASTER e é criado pelo pacote da migração.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - Schema COMP (Compras), pedido do Celso (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'CAD')   IS NULL EXEC (N'CREATE SCHEMA [CAD] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'BANCO') IS NULL EXEC (N'CREATE SCHEMA [BANCO] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'IMOB')  IS NULL EXEC (N'CREATE SCHEMA [IMOB] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'VENDA') IS NULL EXEC (N'CREATE SCHEMA [VENDA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'FIN')   IS NULL EXEC (N'CREATE SCHEMA [FIN] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'COBR')  IS NULL EXEC (N'CREATE SCHEMA [COBR] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'OBRA')  IS NULL EXEC (N'CREATE SCHEMA [OBRA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'COMP')  IS NULL EXEC (N'CREATE SCHEMA [COMP] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'GER')   IS NULL EXEC (N'CREATE SCHEMA [GER] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'SIS')   IS NULL EXEC (N'CREATE SCHEMA [SIS] AUTHORIZATION [dbo];');
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Modulo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema, na ordem do menu. Só insere o que falta
                (PADRAO_SQL regra 39): nada já cadastrado é alterado.
                LIBERADO_LICENCA começa 0 em todos, menos SIS (a parte básica
                do sistema). Os demais são ligados pela licença (etapa 02b).
                Ícones: definidos na fase das telas.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - HABILITADO: só o SIS nasce habilitado; os demais o
                        administrador geral liga quando estiverem prontos.
    v1.2 (16/11/2026) - Módulo COMP (Compras), pedido do Celso; nasce fora
                        da licença e desabilitado (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Modulo (CODIGO, NOME, ORDEM_MENU, ICONE, LIBERADO_LICENCA, HABILITADO)
SELECT v.CODIGO, v.NOME, v.ORDEM_MENU, '', v.LIBERADO_LICENCA, v.LIBERADO_LICENCA
FROM (VALUES
        (CAST('CAD'   AS VARCHAR(10)), CAST(N'Cadastros'           AS NVARCHAR(60)), CAST(10 AS SMALLINT), CAST(0 AS BIT)),
        ('IMOB',  N'Imóveis',             20, 0),
        ('VENDA', N'Vendas',              30, 0),
        ('FIN',   N'Financeiro',          40, 0),
        ('COMP',  N'Compras',             45, 0),
        ('BANCO', N'Bancos',              50, 0),
        ('COBR',  N'Cobrança',            60, 0),
        ('OBRA',  N'Custos de obra',      70, 0),
        ('GER',   N'Painel e relatórios', 80, 0),
        ('SIS',   N'Sistema',             90, 1)
     ) v (CODIGO, NOME, ORDEM_MENU, LIBERADO_LICENCA)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Acao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que as telas podem ter. Só insere o que falta
                (regra 39). Ação nova de um módulo futuro entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (16/11/2026) - Ação EXECUTAR (rotinas e comandos; etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Acao (CODIGO, NOME, ORDEM)
SELECT v.CODIGO, v.NOME, v.ORDEM
FROM (VALUES
        (CAST('VER' AS VARCHAR(20)), CAST(N'Ver / consultar' AS NVARCHAR(60)), CAST(10 AS SMALLINT)),
        ('INCLUIR',          N'Incluir',                     20),
        ('ALTERAR',          N'Alterar',                     30),
        ('EXCLUIR',          N'Excluir / cancelar registro', 40),
        ('EXPORTAR',         N'Exportar para Excel',         50),
        ('IMPORTAR',         N'Importar arquivo',            60),
        ('BAIXAR',           N'Baixar (pagar/receber)',      70),
        ('ESTORNAR',         N'Estornar',                    80),
        ('CANCELAR',         N'Cancelar (contrato, boleto)', 90),
        ('REABRIR',          N'Reabrir (mês, contrato)',    100),
        ('APROVAR',          N'Aprovar',                    110),
        ('ENVIAR',           N'Enviar (e-mail, remessa)',   120),
        ('DESBLOQUEAR',      N'Desbloquear usuário',        130),
        ('REDEFINIR_SENHA',  N'Definir senha provisória',   140),
        ('EXECUTAR',         N'Executar (rotina, comando)', 150)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Grupo_Email.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Grupos de destinatários dos e-mails do sistema (PADRAO_EMAIL
                regra 10): nenhum e-mail fica fixo no código; a rotina pede
                o grupo (ex.: FIN_PAGAR) e a function devolve os endereços.
                Um grupo pode misturar e-mails internos e externos.
                Os endereços ficam em SIS.Grupo_Email_Destinatario.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email]
    (
        ID_GRUPO_EMAIL     INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(30)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Grupo_Email_DESCRICAO       DEFAULT (N''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Grupo_Email_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email        PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL),
        CONSTRAINT UQ_Grupo_Email_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Grupo_Email_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Grupo_Email_Destinatario.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email_Destinatario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços de cada grupo de e-mail. O mesmo endereço não se
                repete no mesmo grupo. Mantidos pela tela "Grupos de e-mail"
                (SIS_Grupo_Email_Gravar).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email_Destinatario]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email_Destinatario]
    (
        ID_GRUPO_EMAIL_DESTINATARIO  INT            IDENTITY(1,1) NOT NULL,
        ID_GRUPO_EMAIL               INT            NOT NULL,
        EMAIL                        NVARCHAR(256)  NOT NULL,
        NOME                         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_NOME            DEFAULT (N''),
        ATIVO                        BIT            NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_ATIVO           DEFAULT (1),
        DT_CRIACAO                   DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO                 DATETIME2(0)   NULL,
        USUARIO_ALTERACAO            NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email_Destinatario       PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL_DESTINATARIO),
        CONSTRAINT UQ_Grupo_Email_Destinatario_EMAIL UNIQUE (ID_GRUPO_EMAIL, EMAIL),
        CONSTRAINT FK_Grupo_Email_Destinatario_Grupo FOREIGN KEY (ID_GRUPO_EMAIL) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Email_Fila.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Email_Fila]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fila de e-mails (PADRAO_EMAIL seção 1). As rotinas só gravam
                aqui (SIS_Email_Enfileirar); o serviço do sistema captura
                (SIS_Email_Capturar), envia por SMTP e grava o resultado
                (SIS_Email_Resultado_Gravar). Falha de envio nunca desfaz a
                operação de negócio.
                STATUS: PENDENTE > PROCESSANDO > ENVIADO | ERRO; CANCELADO
                pela tela.
                CHAVE_ORIGEM: impede o mesmo aviso duas vezes (ex.:
                'BOLETO:12345'); índice único só quando informada.
                ID_EMAIL numérico (aparece na tela); a idempotência fica na
                CHAVE_ORIGEM.
                CONTA: INTERNA (avisos da CMJ) ou EXTERNA (clientes e
                terceiros); o serviço escolhe a conta SMTP por ela.
                MODO_TESTE = 1: gravado no banco _LOCAL; PARA foi trocado pelo
                EMAIL_TESTE e o endereço pedido ficou em PARA_ORIGINAL.
                Anexos em SIS.Email_Fila_Anexo; histórico em SIS.Email_Log.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila]
    (
        ID_EMAIL           BIGINT         IDENTITY(1,1) NOT NULL,
        CHAVE_ORIGEM       NVARCHAR(200)  NULL,
        TIPO               VARCHAR(30)    NOT NULL,
        CONTA              VARCHAR(10)    NOT NULL CONSTRAINT DF_Email_Fila_CONTA             DEFAULT ('INTERNA'),
        GRUPO              VARCHAR(30)    NOT NULL CONSTRAINT DF_Email_Fila_GRUPO             DEFAULT (''),
        PARA               NVARCHAR(2000) NOT NULL,
        CC                 NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CC                DEFAULT (N''),
        CCO                NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CCO               DEFAULT (N''),
        PARA_ORIGINAL      NVARCHAR(4000) NOT NULL CONSTRAINT DF_Email_Fila_PARA_ORIGINAL     DEFAULT (N''),
        ASSUNTO            NVARCHAR(400)  NOT NULL,
        CORPO_HTML         NVARCHAR(MAX)  NOT NULL,
        STATUS             VARCHAR(12)    NOT NULL CONSTRAINT DF_Email_Fila_STATUS            DEFAULT ('PENDENTE'),
        TENTATIVAS         INT            NOT NULL CONSTRAINT DF_Email_Fila_TENTATIVAS        DEFAULT (0),
        PROXIMA_TENTATIVA  DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_PROXIMA_TENTATIVA DEFAULT (SYSDATETIME()),
        DT_CAPTURA         DATETIME2(0)   NULL,
        SERVIDOR           NVARCHAR(128)  NOT NULL CONSTRAINT DF_Email_Fila_SERVIDOR          DEFAULT (N''),
        DT_ENVIO           DATETIME2(0)   NULL,
        ULTIMO_ERRO        NVARCHAR(1000) NOT NULL CONSTRAINT DF_Email_Fila_ULTIMO_ERRO       DEFAULT (N''),
        ORIGEM             NVARCHAR(256)  NOT NULL CONSTRAINT DF_Email_Fila_ORIGEM            DEFAULT (N''),
        ID_LOTE            BIGINT         NULL,
        MODO_TESTE         BIT            NOT NULL CONSTRAINT DF_Email_Fila_MODO_TESTE        DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Email_Fila_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Email_Fila        PRIMARY KEY CLUSTERED (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_STATUS CHECK (STATUS IN ('PENDENTE', 'PROCESSANDO', 'ENVIADO', 'ERRO', 'CANCELADO')),
        CONSTRAINT CK_Email_Fila_CONTA  CHECK (CONTA IN ('INTERNA', 'EXTERNA')),
        CONSTRAINT CK_Email_Fila_TIPO   CHECK (TIPO <> '' AND REPLACE(TIPO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'UX_Email_Fila_CHAVE_ORIGEM')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Email_Fila_CHAVE_ORIGEM ON [SIS].[Email_Fila] (CHAVE_ORIGEM) WHERE CHAVE_ORIGEM IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_STATUS')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_STATUS ON [SIS].[Email_Fila] (STATUS, PROXIMA_TENTATIVA);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_DT_CRIACAO')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_DT_CRIACAO ON [SIS].[Email_Fila] (DT_CRIACAO) INCLUDE (STATUS, TIPO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Email_Fila_Anexo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Email_Fila_Anexo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de cada e-mail da fila (PADRAO_EMAIL regras 23 e 24):
                o arquivo fica em disco e aqui só o caminho. O serviço confere
                se o arquivo existe antes de enviar; se não existir, o e-mail
                vai para ERRO (nunca sai sem o anexo).
                NOME_EXIBICAO: nome que o destinatário vê (sem acento e sem
                espaço). CID preenchido = imagem embutida no corpo
                (<img src="cid:...">) em vez de anexo comum.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila_Anexo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila_Anexo]
    (
        ID_EMAIL_ANEXO  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL        BIGINT          NOT NULL,
        CAMINHO         NVARCHAR(1000)  NOT NULL,
        NOME_EXIBICAO   NVARCHAR(260)   NOT NULL,
        CID             VARCHAR(60)     NOT NULL CONSTRAINT DF_Email_Fila_Anexo_CID   DEFAULT (''),
        ORDEM           SMALLINT        NOT NULL CONSTRAINT DF_Email_Fila_Anexo_ORDEM DEFAULT (0),
        CONSTRAINT PK_Email_Fila_Anexo       PRIMARY KEY CLUSTERED (ID_EMAIL_ANEXO),
        CONSTRAINT FK_Email_Fila_Anexo_Email FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_Anexo_CAMINHO CHECK (CAMINHO <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila_Anexo]') AND i.name = N'IX_Email_Fila_Anexo_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_Anexo_ID_EMAIL ON [SIS].[Email_Fila_Anexo] (ID_EMAIL, ORDEM);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Email_Log.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Email_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de cada e-mail da fila: cada tentativa de envio e
                cada ação da tela (reenviar, cancelar) ou da rotina que solta
                os presos. Não é apagado.
                RESULTADO: ENVIADO, ERRO_TEMPORARIO, ERRO_PERMANENTE,
                LIBERADO, REENVIO, CANCELADO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Log]
    (
        ID_EMAIL_LOG  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL      BIGINT          NOT NULL,
        TENTATIVA     INT             NOT NULL CONSTRAINT DF_Email_Log_TENTATIVA   DEFAULT (0),
        RESULTADO     VARCHAR(20)     NOT NULL,
        MENSAGEM      NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Email_Log_MENSAGEM    DEFAULT (N''),
        SERVIDOR      NVARCHAR(128)   NOT NULL CONSTRAINT DF_Email_Log_SERVIDOR    DEFAULT (N''),
        USUARIO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Email_Log_USUARIO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_REGISTRO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Email_Log_DT_REGISTRO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Email_Log          PRIMARY KEY CLUSTERED (ID_EMAIL_LOG),
        CONSTRAINT FK_Email_Log_Email    FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Log_RESULTADO CHECK (RESULTADO IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE', 'LIBERADO', 'REENVIO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Log]') AND i.name = N'IX_Email_Log_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Log_ID_EMAIL ON [SIS].[Email_Log] (ID_EMAIL, ID_EMAIL_LOG);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Rotina.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Rotina]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Agenda das rotinas automáticas (SQL Server Express não tem
                Agent). O serviço do sistema chama SIS_Rotina_Processar a
                cada minuto; ela roda, uma de cada vez, as rotinas vencidas.
                As rotinas são cadastradas só por carga (lista fixa de
                procedures, sem parâmetro): pela tela muda-se apenas a agenda,
                ligar/desligar e "executar agora".
                FREQUENCIA: MINUTOS (INTERVALO_MINUTOS), DIARIA (HORARIO),
                SEMANAL (DIAS_SEMANA '2,3,4,5,6', 1 = domingo, e HORARIO),
                MENSAL (DIA_MES; 31 = último dia do mês, e HORARIO).
                Só roda se o módulo da rotina estiver na licença e
                habilitado.
                Colunas de execução (PROXIMA_EXECUCAO em diante) não entram
                na auditoria (mudam a cada execução); o histórico de cada
                execução fica em SIS.Rotina_Execucao.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Rotina]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Rotina]
    (
        ID_ROTINA             INT            IDENTITY(1,1) NOT NULL,
        CODIGO                VARCHAR(40)    NOT NULL,
        NOME                  NVARCHAR(80)   NOT NULL,
        DESCRICAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Rotina_DESCRICAO       DEFAULT (N''),
        PROCEDIMENTO          NVARCHAR(256)  NOT NULL,
        ID_MODULO             INT            NOT NULL,
        FREQUENCIA            VARCHAR(10)    NOT NULL,
        INTERVALO_MINUTOS     INT            NOT NULL CONSTRAINT DF_Rotina_INTERVALO       DEFAULT (0),
        HORARIO               TIME(0)        NOT NULL CONSTRAINT DF_Rotina_HORARIO         DEFAULT ('00:00'),
        DIAS_SEMANA           VARCHAR(20)    NOT NULL CONSTRAINT DF_Rotina_DIAS_SEMANA     DEFAULT (''),
        DIA_MES               TINYINT        NOT NULL CONSTRAINT DF_Rotina_DIA_MES         DEFAULT (0),
        TEMPO_LIMITE_MINUTOS  INT            NOT NULL CONSTRAINT DF_Rotina_TEMPO_LIMITE    DEFAULT (60),
        ATIVA                 BIT            NOT NULL CONSTRAINT DF_Rotina_ATIVA           DEFAULT (1),
        PROXIMA_EXECUCAO      DATETIME2(0)   NULL,
        SOLICITADA_POR        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Rotina_SOLICITADA_POR  DEFAULT (N''),
        EM_EXECUCAO           BIT            NOT NULL CONSTRAINT DF_Rotina_EM_EXECUCAO     DEFAULT (0),
        DT_INICIO_EXECUCAO    DATETIME2(0)   NULL,
        ULTIMA_EXECUCAO       DATETIME2(0)   NULL,
        ULTIMO_RESULTADO      VARCHAR(10)    NOT NULL CONSTRAINT DF_Rotina_ULTIMO_RESULTADO DEFAULT (''),
        ULTIMA_MENSAGEM       NVARCHAR(1000) NOT NULL CONSTRAINT DF_Rotina_ULTIMA_MENSAGEM  DEFAULT (N''),
        DT_CRIACAO            DATETIME2(0)   NOT NULL CONSTRAINT DF_Rotina_DT_CRIACAO       DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO       NVARCHAR(100)  NOT NULL CONSTRAINT DF_Rotina_USUARIO_CRIACAO  DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO          DATETIME2(0)   NULL,
        USUARIO_ALTERACAO     NVARCHAR(100)  NULL,
        CONSTRAINT PK_Rotina            PRIMARY KEY CLUSTERED (ID_ROTINA),
        CONSTRAINT UQ_Rotina_CODIGO     UNIQUE (CODIGO),
        CONSTRAINT FK_Rotina_Modulo     FOREIGN KEY (ID_MODULO) REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT CK_Rotina_CODIGO     CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Rotina_FREQUENCIA CHECK (FREQUENCIA IN ('MINUTOS', 'DIARIA', 'SEMANAL', 'MENSAL')),
        CONSTRAINT CK_Rotina_AGENDA     CHECK (   (FREQUENCIA = 'MINUTOS' AND INTERVALO_MINUTOS BETWEEN 1 AND 1440)
                                               OR (FREQUENCIA = 'DIARIA')
                                               OR (FREQUENCIA = 'SEMANAL' AND DIAS_SEMANA <> '' AND DIAS_SEMANA NOT LIKE '%[^1-7,]%')
                                               OR (FREQUENCIA = 'MENSAL'  AND DIA_MES BETWEEN 1 AND 31)),
        CONSTRAINT CK_Rotina_TEMPO_LIMITE CHECK (TEMPO_LIMITE_MINUTOS BETWEEN 1 AND 1440)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Rotina_Execucao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Rotina_Execucao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de cada execução das rotinas automáticas: quando,
                por quê (AGENDA ou MANUAL, com quem pediu), quanto tempo
                levou e o resultado (OK / ERRO, com a mensagem). O erro
                detalhado fica também em SIS.Log_Erro (gravado pela própria
                rotina ou pela SIS_Rotina_Processar).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Rotina_Execucao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Rotina_Execucao]
    (
        ID_EXECUCAO   BIGINT          IDENTITY(1,1) NOT NULL,
        ID_ROTINA     INT             NOT NULL,
        ORIGEM        VARCHAR(10)     NOT NULL,
        SOLICITANTE   NVARCHAR(100)   NOT NULL CONSTRAINT DF_Rotina_Execucao_SOLICITANTE DEFAULT (N''),
        SERVIDOR      NVARCHAR(128)   NOT NULL CONSTRAINT DF_Rotina_Execucao_SERVIDOR    DEFAULT (N''),
        DT_INICIO     DATETIME2(0)    NOT NULL CONSTRAINT DF_Rotina_Execucao_DT_INICIO   DEFAULT (SYSDATETIME()),
        DT_FIM        DATETIME2(0)    NULL,
        RESULTADO     VARCHAR(10)     NOT NULL CONSTRAINT DF_Rotina_Execucao_RESULTADO   DEFAULT ('EXECUTANDO'),
        MENSAGEM      NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Rotina_Execucao_MENSAGEM    DEFAULT (N''),
        CONSTRAINT PK_Rotina_Execucao          PRIMARY KEY CLUSTERED (ID_EXECUCAO),
        CONSTRAINT FK_Rotina_Execucao_Rotina   FOREIGN KEY (ID_ROTINA) REFERENCES [SIS].[Rotina] (ID_ROTINA),
        CONSTRAINT CK_Rotina_Execucao_ORIGEM   CHECK (ORIGEM IN ('AGENDA', 'MANUAL')),
        CONSTRAINT CK_Rotina_Execucao_RESULTADO CHECK (RESULTADO IN ('EXECUTANDO', 'OK', 'ERRO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Rotina_Execucao]') AND i.name = N'IX_Rotina_Execucao_ID_ROTINA')
    CREATE NONCLUSTERED INDEX IX_Rotina_Execucao_ID_ROTINA ON [SIS].[Rotina_Execucao] (ID_ROTINA, ID_EXECUCAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Comando.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Catálogo dos comandos de instalação e manutenção (pedidos 2 e
                4 do Celso, 16/11/2026): cada linha vira um botão da tela
                "Instalação e manutenção", exclusiva do administrador geral.
                O SQL nunca executa comando do Windows: o botão grava um
                pedido em SIS.Comando_Fila e o serviço do sistema executa o
                que estiver na SUA lista fixa para aquele CODIGO (nada de
                texto de comando vindo do banco).
                PERIGOSO = 1: a API pede a senha de novo e uma confirmação
                antes de gravar o pedido.
                ACEITA_PARAMETRO = 1: o botão pede um valor (ex.: nome do
                arquivo do pacote), validado aqui e de novo pelo serviço.
                Cadastrado só por carga (Carga_SIS_Comando.sql).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comando]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comando]
    (
        ID_COMANDO           INT             IDENTITY(1,1) NOT NULL,
        CODIGO               VARCHAR(40)     NOT NULL,
        NOME                 NVARCHAR(80)    NOT NULL,
        DESCRICAO            NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Comando_DESCRICAO           DEFAULT (N''),
        GRUPO                VARCHAR(20)     NOT NULL,
        ORDEM                SMALLINT        NOT NULL CONSTRAINT DF_Comando_ORDEM               DEFAULT (0),
        PERIGOSO             BIT             NOT NULL CONSTRAINT DF_Comando_PERIGOSO            DEFAULT (0),
        ACEITA_PARAMETRO     BIT             NOT NULL CONSTRAINT DF_Comando_ACEITA_PARAMETRO    DEFAULT (0),
        PARAMETRO_DESCRICAO  NVARCHAR(200)   NOT NULL CONSTRAINT DF_Comando_PARAMETRO_DESCRICAO DEFAULT (N''),
        ATIVO                BIT             NOT NULL CONSTRAINT DF_Comando_ATIVO               DEFAULT (1),
        DT_CRIACAO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Comando_DT_CRIACAO          DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)   NOT NULL CONSTRAINT DF_Comando_USUARIO_CRIACAO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)    NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)   NULL,
        CONSTRAINT PK_Comando        PRIMARY KEY CLUSTERED (ID_COMANDO),
        CONSTRAINT UQ_Comando_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Comando_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Comando_GRUPO  CHECK (GRUPO IN ('INSTALACAO', 'ATUALIZACAO', 'BACKUP', 'SERVICO', 'DIAGNOSTICO'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Comando_Fila.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Comando_Fila]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Pedidos de execução dos comandos de instalação e manutenção
                (SIS.Comando). Quem pediu, de onde, quando começou e
                terminou, código de saída e a saída do comando. Os comandos
                rodam um de cada vez, na ordem dos pedidos.
                STATUS: PENDENTE > EXECUTANDO > CONCLUIDO | ERRO; CANCELADO
                (só enquanto pendente). Não é apagado.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comando_Fila]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comando_Fila]
    (
        ID_PEDIDO             BIGINT          IDENTITY(1,1) NOT NULL,
        ID_COMANDO            INT             NOT NULL,
        PARAMETRO             NVARCHAR(400)   NOT NULL CONSTRAINT DF_Comando_Fila_PARAMETRO      DEFAULT (N''),
        STATUS                VARCHAR(12)     NOT NULL CONSTRAINT DF_Comando_Fila_STATUS         DEFAULT ('PENDENTE'),
        DT_PEDIDO             DATETIME2(0)    NOT NULL CONSTRAINT DF_Comando_Fila_DT_PEDIDO      DEFAULT (SYSDATETIME()),
        USUARIO_PEDIDO        NVARCHAR(100)   NOT NULL,
        ESTACAO_PEDIDO        NVARCHAR(128)   NOT NULL CONSTRAINT DF_Comando_Fila_ESTACAO        DEFAULT (N''),
        DT_INICIO             DATETIME2(0)    NULL,
        DT_FIM                DATETIME2(0)    NULL,
        SERVIDOR              NVARCHAR(128)   NOT NULL CONSTRAINT DF_Comando_Fila_SERVIDOR       DEFAULT (N''),
        CODIGO_SAIDA          INT             NULL,
        SAIDA                 NVARCHAR(MAX)   NOT NULL CONSTRAINT DF_Comando_Fila_SAIDA          DEFAULT (N''),
        DT_CANCELAMENTO       DATETIME2(0)    NULL,
        USUARIO_CANCELAMENTO  NVARCHAR(100)   NOT NULL CONSTRAINT DF_Comando_Fila_USUARIO_CANC   DEFAULT (N''),
        CONSTRAINT PK_Comando_Fila         PRIMARY KEY CLUSTERED (ID_PEDIDO),
        CONSTRAINT FK_Comando_Fila_Comando FOREIGN KEY (ID_COMANDO) REFERENCES [SIS].[Comando] (ID_COMANDO),
        CONSTRAINT CK_Comando_Fila_STATUS  CHECK (STATUS IN ('PENDENTE', 'EXECUTANDO', 'CONCLUIDO', 'ERRO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Comando_Fila]') AND i.name = N'IX_Comando_Fila_STATUS')
    CREATE NONCLUSTERED INDEX IX_Comando_Fila_STATUS ON [SIS].[Comando_Fila] (STATUS, ID_PEDIDO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Email_Valido.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Email_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : 1 se o texto tem formato de UM endereço de e-mail
                (nome@dominio.ext, sem espaço, sem acento, sem dois @, sem
                ".." e sem ponto no começo/fim); 0 caso contrário.
                Não confere se a caixa existe (isso só o envio mostra).
                Caracteres aceitos: letras sem acento, números, . @ _ + -
                (conferidos com REPLACE + '[^A-Za-z0-9]' em BIN2, nunca com
                '_' ou '-' dentro de colchetes; PADRAO_SQL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Email_Valido(N'financeiro@cmj.com.br'), SIS.fn_SIS_Email_Valido(N'sem arroba');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Email_Valido] (@Email NVARCHAR(256))
RETURNS BIT
AS
BEGIN
    DECLARE @E NVARCHAR(256) = LTRIM(RTRIM(ISNULL(@Email, N'')));
    DECLARE @Arroba INT = CHARINDEX(N'@', @E);

    IF LEN(@E) < 6 OR @Arroba < 2 RETURN 0;
    IF CHARINDEX(N'@', @E, @Arroba + 1) > 0 RETURN 0;
    IF CHARINDEX(N'..', @E) > 0 RETURN 0;
    IF LEFT(@E, 1) = N'.' OR RIGHT(@E, 1) = N'.' RETURN 0;
    IF SUBSTRING(@E, @Arroba - 1, 1) = N'.' OR SUBSTRING(@E, @Arroba + 1, 1) = N'.' RETURN 0;
    IF CHARINDEX(N'.', @E, @Arroba + 2) = 0 RETURN 0;
    IF REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@E, N'.', N''), N'@', N''), N'_', N''), N'+', N''), N'-', N'')
       LIKE N'%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2 RETURN 0;

    RETURN 1;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Emails_Do_Grupo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Emails_Do_Grupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços ativos de um grupo de e-mail ativo, separados por
                "; ", em ordem alfabética. Nunca devolve NULL: grupo
                inexistente, inativo ou vazio devolve '' (a orquestradora
                registra o motivo e não envia; PADRAO_EMAIL regra 8).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Emails_Do_Grupo('SIS_ALERTA');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Emails_Do_Grupo] (@Grupo VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Emails NVARCHAR(MAX);

    SELECT @Emails = STRING_AGG(CONVERT(NVARCHAR(MAX), LTRIM(RTRIM(d.EMAIL))), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
    FROM SIS.Grupo_Email_Destinatario d
    INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL
    WHERE g.CODIGO = @Grupo
      AND g.ATIVO = 1
      AND d.ATIVO = 1
      AND LTRIM(RTRIM(ISNULL(d.EMAIL, N''))) <> N'';

    RETURN ISNULL(@Emails, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Filtrar_Emails_Por_Dominio.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Separa uma lista de e-mails em internos e externos (PADRAO_EMAIL
                regra 10), para enviar por contas diferentes sem duplicar
                grupo. Interno = domínio listado no parâmetro
                EMAIL_DOMINIO_INTERNO (pode ter vários, separados por
                vírgula; ex.: cmj.com.br). Parâmetro vazio = todos internos.
                @Interno = 1 devolve os internos; 0 devolve os externos.
                Aceita ";" ou "," como separador; devolve "; ", sem
                repetidos, na ordem em que vieram. Nunca devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br; b@gmail.com', 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio] (@Emails NVARCHAR(MAX), @Interno BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Dominios NVARCHAR(4000) = LOWER(REPLACE(ISNULL(SIS.fn_SIS_Parametro('EMAIL_DOMINIO_INTERNO'), N''), N' ', N''));
    DECLARE @Saida    NVARCHAR(MAX);

    WITH e AS
    (
        SELECT LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
        FROM STRING_SPLIT(REPLACE(ISNULL(@Emails, N''), N',', N';'), N';', 1) s
        WHERE LTRIM(RTRIM(s.value)) <> N''
        GROUP BY LTRIM(RTRIM(s.value))
    ),
    c AS
    (
        SELECT e.EMAIL, e.ORDEM,
               CASE WHEN @Dominios = N'' THEN 1
                    WHEN EXISTS (SELECT 1 FROM STRING_SPLIT(@Dominios, N',') d
                                 WHERE d.value <> N''
                                   AND LOWER(SUBSTRING(e.EMAIL, CHARINDEX(N'@', e.EMAIL) + 1, 256)) = d.value) THEN 1
                    ELSE 0 END AS INTERNO
        FROM e
    )
    SELECT @Saida = STRING_AGG(CONVERT(NVARCHAR(MAX), c.EMAIL), N'; ') WITHIN GROUP (ORDER BY c.ORDEM)
    FROM c
    WHERE c.INTERNO = ISNULL(@Interno, 1);

    RETURN ISNULL(@Saida, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Email_HTML.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Email_HTML]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Moldura padrão de todo e-mail do sistema (PADRAO_EMAIL seções
                3 e 4): container branco centralizado, logomarca, cabeçalho
                colorido pela severidade, o conteúdo e o rodapé de rastreio.
                A orquestradora monta só o miolo (@Conteudo, já em HTML, com
                o texto digitado escapado por fn_SIS_Texto_HTML) e chama esta
                function: o visual fica igual em todo o sistema.
                @Severidade: INFO (cor EMPRESA_COR_PRINCIPAL), ALERTA (cor
                EMAIL_COR_ALERTA e a palavra ALERTA no título) ou SUCESSO
                (cor EMAIL_COR_SUCESSO). Cores sempre dos parâmetros.
                @Rotina: nome da procedure que gerou (variável @NomeProc).
                @Grupo : código do grupo (só em e-mail interno).
                @Externo = 1: e-mail a cliente/terceiro; rodapé sem dados
                técnicos (razão social, CNPJ e aviso de não responder).
                Logomarca: <img src="cid:logo_empresa">; o serviço embute o
                arquivo do parâmetro EMPRESA_LOGO_EMAIL com esse CID sempre
                que o corpo citar "cid:logo_empresa".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Email_HTML(N'Teste', 'INFO', N'<p>Olá</p>', N'[SIS].[Teste]', 'SIS_ALERTA', 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Email_HTML]
(
    @Titulo      NVARCHAR(200),
    @Severidade  VARCHAR(10),
    @Conteudo    NVARCHAR(MAX),
    @Rotina      NVARCHAR(256),
    @Grupo       VARCHAR(30),
    @Externo     BIT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Sev    VARCHAR(10)   = UPPER(ISNULL(@Severidade, 'INFO'));
    DECLARE @Cor    VARCHAR(7);
    DECLARE @Titul  NVARCHAR(300) = UPPER(SIS.fn_SIS_Texto_HTML(ISNULL(@Titulo, N'')));
    DECLARE @Razao  NVARCHAR(400) = SIS.fn_SIS_Texto_HTML(ISNULL(SIS.fn_SIS_Empresa_Razao_Social(), N''));
    DECLARE @Rodape NVARCHAR(MAX);

    SET @Cor = CASE @Sev WHEN 'ALERTA'  THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_ALERTA')
                         WHEN 'SUCESSO' THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_SUCESSO')
                         ELSE SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL') END;
    SET @Cor = ISNULL(NULLIF(@Cor, ''), '#333333');
    IF @Sev = 'ALERTA' SET @Titul = N'ALERTA - ' + @Titul;

    IF ISNULL(@Externo, 0) = 1
        SET @Rodape = N'<div style="font-weight:bold;">' + @Razao + N'</div>'
                    + N'<div>CNPJ ' + ISNULL(SIS.fn_SIS_Mascarar_CPF_CNPJ(SIS.fn_SIS_Empresa_CNPJ(), 0), N'') + N'</div>'
                    + N'<div style="margin-top:6px;">Este e-mail foi enviado automaticamente. Por favor, não responda.</div>';
    ELSE
        SET @Rodape = N'<div>Gerado automaticamente pelo sistema SistemaCMJ: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Rotina, N'')) + N'</div>'
                    + N'<div>Emitido em: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(CAST(SYSDATETIME() AS DATETIME2(0))), N'') + N'</div>'
                    + CASE WHEN ISNULL(@Grupo, '') <> '' THEN N'<div>Grupo de Destinatários: ' + SIS.fn_SIS_Texto_HTML(@Grupo) + N'</div>' ELSE N'' END
                    + N'<div style="margin-top:6px;font-weight:bold;">' + @Razao + N'</div>';

    RETURN N'<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
         + N'<body style="margin:0;padding:20px;background:#eeeeee;font-family:Arial,''Segoe UI'',sans-serif;color:#333333;">'
         + N'<div style="max-width:700px;margin:0 auto;background:#ffffff;box-shadow:0 1px 4px rgba(0,0,0,0.15);">'
         + N'<div style="padding:16px 20px;"><img src="cid:logo_empresa" alt="' + @Razao + N'" style="max-height:60px;"></div>'
         + N'<div style="background:' + @Cor + N';color:#ffffff;font-weight:bold;padding:12px 20px;font-size:15px;">' + @Titul + N'</div>'
         + N'<div style="padding:20px;font-size:14px;line-height:1.5;">' + ISNULL(@Conteudo, N'') + N'</div>'
         + N'<div style="background:#f9f9f9;padding:12px 20px;font-size:11px;color:#777777;border-top:1px solid #eeeeee;">' + @Rodape + N'</div>'
         + N'</div></body></html>';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Rotina_Proxima.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Rotina_Proxima]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Próxima data e hora de execução de uma rotina, depois de
                @Base (sempre maior que @Base):
                  MINUTOS : @Base + intervalo;
                  DIARIA  : próximo dia no HORARIO;
                  SEMANAL : próximo dia da lista DIAS_SEMANA (1 = domingo
                            ... 7 = sábado) no HORARIO;
                  MENSAL  : próximo mês no DIA_MES (se o mês não tem o dia,
                            ex.: 31 em abril, usa o último dia) no HORARIO.
                Dia da semana calculado sem depender do SET DATEFIRST
                (07/01/1900 foi domingo). Agenda inválida devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '08:00', '2,4', 0, '2026-11-16T09:00:00');  -- 18/11 08:00
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Rotina_Proxima]
(
    @Frequencia  VARCHAR(10),
    @Intervalo   INT,
    @Horario     TIME(0),
    @DiasSemana  VARCHAR(20),
    @DiaMes      TINYINT,
    @Base        DATETIME2(0)
)
RETURNS DATETIME2(0)
AS
BEGIN
    DECLARE @Dia       DATE         = CAST(@Base AS DATE);
    DECLARE @Hora      TIME(0)      = ISNULL(@Horario, '00:00');
    DECLARE @Candidato DATETIME2(0);
    DECLARE @N         INT          = 0;
    DECLARE @Mes1      DATE;
    DECLARE @DiaUsado  INT;

    IF @Base IS NULL RETURN NULL;

    IF @Frequencia = 'MINUTOS'
    BEGIN
        IF ISNULL(@Intervalo, 0) < 1 RETURN NULL;
        RETURN DATEADD(MINUTE, @Intervalo, @Base);
    END;

    IF @Frequencia = 'DIARIA'
    BEGIN
        SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(@Dia AS DATETIME2(0)));
        IF @Candidato <= @Base SET @Candidato = DATEADD(DAY, 1, @Candidato);
        RETURN @Candidato;
    END;

    IF @Frequencia = 'SEMANAL'
    BEGIN
        WHILE @N <= 7
        BEGIN
            IF CHARINDEX(',' + CAST(DATEDIFF(DAY, '19000107', DATEADD(DAY, @N, @Dia)) % 7 + 1 AS VARCHAR(1)) + ',', ',' + ISNULL(@DiasSemana, '') + ',') > 0
            BEGIN
                SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(DATEADD(DAY, @N, @Dia) AS DATETIME2(0)));
                IF @Candidato > @Base RETURN @Candidato;
            END;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    IF @Frequencia = 'MENSAL'
    BEGIN
        IF ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31 RETURN NULL;
        SET @Mes1 = DATEFROMPARTS(YEAR(@Dia), MONTH(@Dia), 1);
        WHILE @N <= 2
        BEGIN
            SET @DiaUsado = CASE WHEN @DiaMes > DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) THEN DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) ELSE @DiaMes END;
            SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora),
                                     CAST(DATEADD(DAY, @DiaUsado - 1, DATEADD(MONTH, @N, @Mes1)) AS DATETIME2(0)));
            IF @Candidato > @Base RETURN @Candidato;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    RETURN NULL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Enfileirar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Enfileirar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Única porta de entrada da fila de e-mails (PADRAO_EMAIL seção
                1). Chamada pelas orquestradoras e rotinas, nunca pela tela.
                Só faz INSERT: quem envia é o serviço.
                - Destinatários: ";" ou "," como separador; endereços
                  inválidos são descartados (e registrados no log); sem
                  nenhum válido, não grava e devolve @IdEmail = NULL.
                - @ChaveOrigem repetida: não grava de novo; devolve o
                  @IdEmail que já existe (o mesmo aviso nunca sai duas
                  vezes).
                - Banco _LOCAL (teste): o e-mail vai só para o parâmetro
                  EMAIL_TESTE, com "[TESTE]" no assunto e o endereço pedido
                  guardado em PARA_ORIGINAL (MODO_TESTE = 1). Proteção
                  extra, além do @bRunLocal das orquestradoras.
                - Assunto sem quebra de linha (texto puro, regra 14).
                - @Anexos: JSON '[{"caminho":"C:\\...\\a.pdf","nome":"a.pdf",
                  "cid":""}]'.
                - ID_LOTE vem do contexto da sessão, se houver.
                Se quem chamou já está numa transação, o INSERT entra nela
                (sai junto com a operação de negócio, ou não sai).
                Erro interno: grava em SIS.Log_Erro e devolve @IdEmail NULL
                (falha de e-mail não desfaz a operação de negócio), salvo se
                a transação de quem chamou ficou condenada (aí repassa o
                erro).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- DECLARE @Id BIGINT;
    -- EXEC SIS.SIS_Email_Enfileirar @Para = N'x@y.com', @Assunto = N'Teste', @CorpoHTML = N'<p>oi</p>',
    --      @Tipo = 'TESTE', @Origem = N'manual', @IdEmail = @Id OUTPUT; SELECT @Id;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Enfileirar]
    @Para         NVARCHAR(MAX),
    @Assunto      NVARCHAR(400),
    @CorpoHTML    NVARCHAR(MAX),
    @Tipo         VARCHAR(30),
    @Origem       NVARCHAR(256),
    @ChaveOrigem  NVARCHAR(200) = NULL,
    @Cc           NVARCHAR(MAX) = NULL,
    @Cco          NVARCHAR(MAX) = NULL,
    @Grupo        VARCHAR(30)   = NULL,
    @Conta        VARCHAR(10)   = 'INTERNA',
    @Anexos       NVARCHAR(MAX) = NULL,
    @IdEmail      BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Enfileirar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Destinatários';
    DECLARE @ParaOk      NVARCHAR(MAX);
    DECLARE @CcOk        NVARCHAR(MAX);
    DECLARE @CcoOk       NVARCHAR(MAX);
    DECLARE @Invalidos   NVARCHAR(MAX);
    DECLARE @ParaOrig    NVARCHAR(MAX) = N'';
    DECLARE @Teste       BIT           = CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 1 ELSE 0 END;
    DECLARE @IdLote      BIGINT        = TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE'));
    DECLARE @MinhaTran   BIT           = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    SET @IdEmail = NULL;

    BEGIN TRY
        SET @ChaveOrigem = NULLIF(LTRIM(RTRIM(@ChaveOrigem)), N'');
        SET @Tipo        = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Conta       = UPPER(LTRIM(RTRIM(ISNULL(@Conta, 'INTERNA'))));
        SET @Assunto     = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Assunto, N''), NCHAR(13) + NCHAR(10), N' '), NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' ')));

        IF @ChaveOrigem IS NOT NULL
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            IF @IdEmail IS NOT NULL RETURN;
        END;

        -- Separa válidos e inválidos (sem repetir, na ordem em que vieram)
        WITH e AS
        (
            SELECT x.LISTA, LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
            FROM (VALUES (1, ISNULL(@Para, N'')), (2, ISNULL(@Cc, N'')), (3, ISNULL(@Cco, N''))) x (LISTA, TEXTO)
            CROSS APPLY STRING_SPLIT(REPLACE(x.TEXTO, N',', N';'), N';', 1) s
            WHERE LTRIM(RTRIM(s.value)) <> N''
            GROUP BY x.LISTA, LTRIM(RTRIM(s.value))
        )
        SELECT @ParaOk    = STRING_AGG(CASE WHEN e.LISTA = 1 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcOk      = STRING_AGG(CASE WHEN e.LISTA = 2 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcoOk     = STRING_AGG(CASE WHEN e.LISTA = 3 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @Invalidos = STRING_AGG(CASE WHEN SIS.fn_SIS_Email_Valido(e.EMAIL) = 0 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM)
        FROM e;

        SET @ParaOk = ISNULL(@ParaOk, N'');
        SET @CcOk   = ISNULL(@CcOk, N'');
        SET @CcoOk  = ISNULL(@CcoOk, N'');

        IF ISNULL(@Invalidos, N'') <> N''
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'Endereços inválidos descartados (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N'): ' + @Invalidos, 4000), 0, SYSDATETIME());

        IF @ParaOk = N''
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'E-mail não enfileirado: nenhum destinatário válido (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N' / ' + @Assunto + N').', 4000), 0, SYSDATETIME());
            RETURN;
        END;

        SET @EtapaAtual = 'Modo teste';
        IF @Teste = 1
        BEGIN
            SET @ParaOrig = @ParaOk
                          + CASE WHEN @CcOk  <> N'' THEN N' | cc: '  + @CcOk  ELSE N'' END
                          + CASE WHEN @CcoOk <> N'' THEN N' | cco: ' + @CcoOk ELSE N'' END;
            SET @ParaOk   = ISNULL(SIS.fn_SIS_Parametro('EMAIL_TESTE'), N'');
            SET @CcOk     = N'';
            SET @CcoOk    = N'';
            SET @Assunto  = N'[TESTE] ' + @Assunto;

            IF SIS.fn_SIS_Email_Valido(@ParaOk) = 0
            BEGIN
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, 0, N'E-mail não enfileirado: parâmetro EMAIL_TESTE vazio ou inválido.', 0, SYSDATETIME());
                RETURN;
            END;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @MinhaTran = 1 BEGIN TRANSACTION;

        INSERT INTO SIS.Email_Fila (CHAVE_ORIGEM, TIPO, CONTA, GRUPO, PARA, CC, CCO, PARA_ORIGINAL, ASSUNTO, CORPO_HTML, ORIGEM, ID_LOTE, MODO_TESTE)
        VALUES (@ChaveOrigem, @Tipo, @Conta, LTRIM(RTRIM(ISNULL(@Grupo, ''))), LEFT(@ParaOk, 2000), LEFT(@CcOk, 2000), LEFT(@CcoOk, 2000),
                LEFT(@ParaOrig, 4000), LEFT(@Assunto, 400), ISNULL(@CorpoHTML, N''), LEFT(ISNULL(@Origem, N''), 256), @IdLote, @Teste);

        SET @IdEmail = SCOPE_IDENTITY();

        IF ISNULL(@Anexos, N'') <> N''
            INSERT INTO SIS.Email_Fila_Anexo (ID_EMAIL, CAMINHO, NOME_EXIBICAO, CID, ORDEM)
            SELECT @IdEmail,
                   LTRIM(RTRIM(j.caminho)),
                   ISNULL(NULLIF(LTRIM(RTRIM(j.nome)), N''), RIGHT(LTRIM(RTRIM(j.caminho)), CHARINDEX(N'\', REVERSE(N'\' + LTRIM(RTRIM(j.caminho)))) - 1)),
                   LTRIM(RTRIM(ISNULL(j.cid, ''))),
                   CAST(k.[key] AS SMALLINT) + 1
            FROM OPENJSON(@Anexos) k
            CROSS APPLY OPENJSON(k.value) WITH (caminho NVARCHAR(1000) '$.caminho', nome NVARCHAR(260) '$.nome', cid VARCHAR(60) '$.cid') j
            WHERE LTRIM(RTRIM(ISNULL(j.caminho, N''))) <> N'';

        IF @MinhaTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @MinhaTran = 1 AND @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Mesma chave gravada ao mesmo tempo por outra sessão: devolve a que ficou
        IF ERROR_NUMBER() IN (2601, 2627) AND @ChaveOrigem IS NOT NULL AND XACT_STATE() <> -1
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            RETURN;
        END;

        IF XACT_STATE() = -1 THROW;

        SET @IdEmail = NULL;
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Capturar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema (a cada minuto). Pega até
                @Quantidade e-mails PENDENTES já no horário, marca como
                PROCESSANDO e soma 1 tentativa, numa única instrução com
                UPDLOCK + READPAST: dois serviços (ou duas chamadas) nunca
                pegam o mesmo e-mail.
                Devolve um e-mail por linha, com os anexos em JSON
                (ANEXOS_JSON: [{"CAMINHO","NOME_EXIBICAO","CID"}]).
                Depois de tentar enviar, o serviço chama
                SIS_Email_Resultado_Gravar para cada um.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Capturar @Servidor = N'TESTE', @Quantidade = 5;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Capturar]
    @Servidor    NVARCHAR(128),
    @Quantidade  INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Pegos      TABLE (ID_EMAIL BIGINT PRIMARY KEY);

    BEGIN TRY
        SET @Quantidade = CASE WHEN ISNULL(@Quantidade, 0) < 1 THEN 20 WHEN @Quantidade > 200 THEN 200 ELSE @Quantidade END;

        WITH c AS
        (
            SELECT TOP (@Quantidade) f.ID_EMAIL, f.STATUS, f.TENTATIVAS, f.DT_CAPTURA, f.SERVIDOR
            FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
              AND f.PROXIMA_TENTATIVA <= @Agora
            ORDER BY f.PROXIMA_TENTATIVA, f.ID_EMAIL
        )
        UPDATE c
           SET c.STATUS     = 'PROCESSANDO',
               c.TENTATIVAS = c.TENTATIVAS + 1,
               c.DT_CAPTURA = @Agora,
               c.SERVIDOR   = LEFT(ISNULL(@Servidor, N''), 128)
        OUTPUT inserted.ID_EMAIL INTO @Pegos (ID_EMAIL);

        SET @EtapaAtual = 'Retorno';
        SELECT f.ID_EMAIL, f.TIPO, f.CONTA, f.PARA, f.CC, f.CCO, f.ASSUNTO, f.CORPO_HTML, f.TENTATIVAS, f.MODO_TESTE,
               ISNULL((SELECT a.CAMINHO, a.NOME_EXIBICAO, a.CID
                       FROM SIS.Email_Fila_Anexo a
                       WHERE a.ID_EMAIL = f.ID_EMAIL
                       ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO
                       FOR JSON PATH), N'[]') AS ANEXOS_JSON
        FROM SIS.Email_Fila f
        INNER JOIN @Pegos p ON p.ID_EMAIL = f.ID_EMAIL
        ORDER BY f.ID_EMAIL;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Resultado_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, depois de tentar enviar um e-mail
                capturado (PADRAO_EMAIL regras 3 a 5).
                @Resultado:
                  ENVIADO         : STATUS = ENVIADO.
                  ERRO_TEMPORARIO : volta para PENDENTE e espera 1, 5, 15 e
                                    depois 60 min a cada tentativa; passou de
                                    EMAIL_TENTATIVAS_MAX, vira ERRO.
                  ERRO_PERMANENTE : ERRO direto (endereço inválido, anexo
                                    que não existe, recusa definitiva).
                Toda tentativa vai para SIS.Email_Log.
                E-mail que terminou em ERRO gera um alerta técnico para o
                parâmetro EMAIL_ADMIN_ALERTA (se preenchido), uma vez por
                e-mail (CHAVE_ORIGEM 'ALERTA_EMAIL:<id>'). Alerta que falha
                não gera outro alerta.
                Devolve SUCESSO, MENSAGEM, ID (ID = ID_EMAIL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = 1, @Resultado = 'ENVIADO', @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Resultado_Gravar]
    @IdEmail    BIGINT,
    @Resultado  VARCHAR(20),
    @Mensagem   NVARCHAR(1000) = NULL,
    @Servidor   NVARCHAR(128)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Resultado_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Status      VARCHAR(12);
    DECLARE @Tentativas  INT;
    DECLARE @Tipo        VARCHAR(30);
    DECLARE @Assunto     NVARCHAR(400);
    DECLARE @Para        NVARCHAR(2000);
    DECLARE @Max         INT           = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
    DECLARE @Novo        VARCHAR(12);
    DECLARE @Espera      INT;
    DECLARE @Agora       DATETIME2(0)  = SYSDATETIME();
    DECLARE @Alerta      NVARCHAR(256);
    DECLARE @Corpo       NVARCHAR(MAX);
    DECLARE @IdAlerta    BIGINT;
    DECLARE @Chave       NVARCHAR(200);

    BEGIN TRY
        SET @Resultado = UPPER(LTRIM(RTRIM(ISNULL(@Resultado, ''))));
        SET @Mensagem  = LEFT(ISNULL(@Mensagem, N''), 1000);
        IF @Max < 1 SET @Max = 1;

        IF @Resultado NOT IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE')
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Resultado inválido.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS, @Tipo = f.TIPO, @Assunto = f.ASSUNTO, @Para = f.PARA
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        IF @Status IS NULL OR @Status <> 'PROCESSANDO'
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.' ELSE N'O e-mail não está em processamento (situação: ' + @Status + N').' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdEmail AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Novo = CASE WHEN @Resultado = 'ENVIADO' THEN 'ENVIADO'
                         WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Tentativas < @Max THEN 'PENDENTE'
                         ELSE 'ERRO' END;
        SET @Espera = CASE WHEN @Tentativas <= 1 THEN 1 WHEN @Tentativas = 2 THEN 5 WHEN @Tentativas = 3 THEN 15 ELSE 60 END;

        UPDATE f
           SET f.STATUS            = @Novo,
               f.DT_ENVIO          = CASE WHEN @Novo = 'ENVIADO' THEN @Agora ELSE f.DT_ENVIO END,
               f.ULTIMO_ERRO       = CASE WHEN @Novo = 'ENVIADO' THEN N'' ELSE @Mensagem END,
               f.PROXIMA_TENTATIVA = CASE WHEN @Novo = 'PENDENTE' THEN DATEADD(MINUTE, @Espera, @Agora) ELSE f.PROXIMA_TENTATIVA END,
               f.SERVIDOR          = CASE WHEN ISNULL(@Servidor, N'') <> N'' THEN LEFT(@Servidor, 128) ELSE f.SERVIDOR END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, SERVIDOR, USUARIO)
        VALUES (@IdEmail, @Tentativas,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN 'ERRO_PERMANENTE' ELSE @Resultado END,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN LEFT(N'Limite de tentativas atingido. ' + @Mensagem, 1000) ELSE @Mensagem END,
                LEFT(ISNULL(@Servidor, N''), 128), N'sistema');

        -- Alerta técnico (uma vez por e-mail; alerta não gera alerta)
        SET @EtapaAtual = 'Alerta';
        SET @Alerta = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Novo = 'ERRO' AND @Tipo <> 'ALERTA_EMAIL' AND @Alerta <> N''
        BEGIN
            SET @Chave = N'ALERTA_EMAIL:' + CAST(@IdEmail AS NVARCHAR(20));
            SET @Corpo = SIS.fn_SIS_Email_HTML(
                             N'Falha no envio de e-mail', 'ALERTA',
                             N'<p>Um e-mail do sistema não pôde ser enviado e foi marcado como erro.</p>'
                           + N'<table style="border-collapse:collapse;font-size:13px;">'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Número</td><td style="padding:4px 8px;">' + CAST(@IdEmail AS NVARCHAR(20)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Tipo</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Assunto</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Assunto) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Para</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Para) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Tentativas</td><td style="padding:4px 8px;">' + CAST(@Tentativas AS NVARCHAR(10)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Erro</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Mensagem) + N'</td></tr>'
                           + N'</table>'
                           + N'<p>Para reenviar, use a tela Sistema &gt; E-mails &gt; E-mails enviados.</p>',
                             @NomeProc, '', 0);

            EXEC SIS.SIS_Email_Enfileirar
                 @Para = @Alerta,
                 @Assunto = N'SistemaCMJ - FALHA no envio de e-mail',
                 @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA_EMAIL',
                 @Origem = @NomeProc,
                 @ChaveOrigem = @Chave,
                 @IdEmail = @IdAlerta OUTPUT;
        END;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Novo WHEN 'ENVIADO'  THEN N'Enviado.'
                               WHEN 'PENDENTE' THEN N'Nova tentativa em ' + CAST(@Espera AS NVARCHAR(5)) + N' min.'
                               ELSE N'Marcado como erro.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado do envio. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Presos_Liberar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Presos_Liberar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotina automática (SIS.Rotina EMAIL_PRESOS). Um e-mail que
                ficou em PROCESSANDO mais que EMAIL_MINUTOS_PRESO minutos
                (o serviço caiu no meio do envio) volta para PENDENTE, ou vai
                para ERRO se já gastou todas as tentativas. Registra no
                SIS.Email_Log (LIBERADO). Sem parâmetro e sem retorno, como
                toda rotina da agenda.
                Pode repetir um envio se o serviço caiu depois de enviar e
                antes de gravar o resultado (raro; preferível a perder o
                e-mail).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Presos_Liberar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Presos_Liberar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Presos_Liberar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Parâmetros';
    DECLARE @Minutos    INT;
    DECLARE @Max        INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Soltos     TABLE (ID_EMAIL BIGINT, TENTATIVAS INT, STATUS VARCHAR(12));

    BEGIN TRY
        SET @Minutos = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_MINUTOS_PRESO'), 15);
        SET @Max     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
        IF @Minutos < 5 SET @Minutos = 5;
        IF @Max < 1 SET @Max = 1;

        SET @EtapaAtual = 'Liberação';
        BEGIN TRANSACTION;

        UPDATE f
           SET f.STATUS            = CASE WHEN f.TENTATIVAS >= @Max THEN 'ERRO' ELSE 'PENDENTE' END,
               f.PROXIMA_TENTATIVA = @Agora,
               f.ULTIMO_ERRO       = N'Ficou preso em processamento (o serviço parou no meio do envio).',
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        OUTPUT inserted.ID_EMAIL, inserted.TENTATIVAS, inserted.STATUS INTO @Soltos (ID_EMAIL, TENTATIVAS, STATUS)
        FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE f.STATUS = 'PROCESSANDO'
          AND f.DT_CAPTURA < DATEADD(MINUTE, -@Minutos, @Agora);

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        SELECT s.ID_EMAIL, s.TENTATIVAS, 'LIBERADO',
               CASE WHEN s.STATUS = 'ERRO' THEN N'Preso em processamento; tentativas esgotadas: marcado como erro.'
                    ELSE N'Preso em processamento há mais de ' + CAST(@Minutos AS NVARCHAR(10)) + N' min: volta para a fila.' END,
               N'sistema'
        FROM @Soltos s;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "E-mails enviados" (Sistema > E-mails): a fila com
                filtro por situação, período (data de criação) e texto
                (assunto, destinatário ou tipo). Mais recente primeiro.
                Sem o corpo (ver SIS_Email_Obter).
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Listar @IdUsuario = 2, @Status = 'ERRO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Listar]
    @IdUsuario  INT,
    @Status     VARCHAR(12)   = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Texto      NVARCHAR(200) = NULL,
    @MaxLinhas  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        SET @Status    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Status, '')))), '');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.PARA_ORIGINAL, f.ASSUNTO,
               f.TENTATIVAS, f.PROXIMA_TENTATIVA, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.ID_LOTE,
               (SELECT COUNT(*) FROM SIS.Email_Fila_Anexo a WHERE a.ID_EMAIL = f.ID_EMAIL AND a.CID = '') AS QTD_ANEXOS
        FROM SIS.Email_Fila f WITH (NOLOCK)
        WHERE (@Status   IS NULL OR f.STATUS = @Status)
          AND (@DtInicio IS NULL OR f.DT_CRIACAO >= @DtInicio)
          AND (@DtFim    IS NULL OR f.DT_CRIACAO <  DATEADD(DAY, 1, CAST(@DtFim AS DATETIME2(0))))
          AND (@Texto    IS NULL OR f.ASSUNTO LIKE N'%' + @Texto + N'%' OR f.PARA LIKE N'%' + @Texto + N'%'
                                 OR f.PARA_ORIGINAL LIKE N'%' + @Texto + N'%' OR f.TIPO LIKE N'%' + @Texto + N'%')
        ORDER BY f.ID_EMAIL DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os e-mails. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Detalhe de um e-mail da fila para a tela (pré-visualizar o
                corpo, ver anexos e o histórico de tentativas).
                Devolve 3 conjuntos: 1) o e-mail com o corpo; 2) os anexos;
                3) o histórico (SIS.Email_Log), mais recente primeiro.
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Obter @IdUsuario = 2, @IdEmail = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Obter]
    @IdUsuario  INT,
    @IdEmail    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        IF NOT EXISTS (SELECT 1 FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @IdEmail)
            THROW 50001, N'E-mail não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.CC, f.CCO, f.PARA_ORIGINAL, f.ASSUNTO, f.CORPO_HTML,
               f.TENTATIVAS, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.CHAVE_ORIGEM, f.ID_LOTE, f.USUARIO_CRIACAO
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        SELECT a.ID_EMAIL_ANEXO, a.NOME_EXIBICAO, a.CAMINHO, a.CID, a.ORDEM
        FROM SIS.Email_Fila_Anexo a
        WHERE a.ID_EMAIL = @IdEmail
        ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO;

        SELECT l.ID_EMAIL_LOG, l.DT_REGISTRO, l.TENTATIVA, l.RESULTADO, l.MENSAGEM, l.SERVIDOR, l.USUARIO
        FROM SIS.Email_Log l
        WHERE l.ID_EMAIL = @IdEmail
        ORDER BY l.ID_EMAIL_LOG DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível abrir o e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Situacao_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Situacao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "E-mails enviados":
                @Acao = 'REENVIAR': e-mail em ERRO ou CANCELADO volta para a
                        fila (PENDENTE, tentativas zeradas). Permissão
                        ENVIAR. E-mail já enviado não é reenviado por aqui
                        (evita mandar duas vezes ao cliente).
                @Acao = 'CANCELAR': e-mail PENDENTE ou em ERRO não sai mais.
                        Permissão CANCELAR. @Motivo obrigatório.
                Tudo fica no SIS.Email_Log com o usuário.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = 2, @IdEmail = 1, @Acao = 'REENVIAR';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Situacao_Gravar]
    @IdUsuario  INT,
    @IdEmail    BIGINT,
    @Acao       VARCHAR(10),
    @Motivo     NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Situacao_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Status     VARCHAR(12);
    DECLARE @Tentativas INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();

    BEGIN TRY
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF @Acao NOT IN ('REENVIAR', 'CANCELAR')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', CASE @Acao WHEN 'REENVIAR' THEN 'ENVIAR' ELSE 'CANCELAR' END) = 0
            SET @Recusa = CASE @Acao WHEN 'REENVIAR' THEN N'Você não tem permissão para reenviar e-mails.' ELSE N'Você não tem permissão para cancelar e-mails.' END;
        IF @Recusa = N'' AND @Acao = 'CANCELAR' AND @Motivo = N''
            SET @Recusa = N'Informe o motivo do cancelamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        SET @Recusa = CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.'
                           WHEN @Acao = 'REENVIAR' AND @Status NOT IN ('ERRO', 'CANCELADO')
                                THEN N'Só e-mail com erro ou cancelado pode ser reenviado (situação: ' + @Status + N').'
                           WHEN @Acao = 'CANCELAR' AND @Status NOT IN ('PENDENTE', 'ERRO')
                                THEN N'Só e-mail pendente ou com erro pode ser cancelado (situação: ' + @Status + N').'
                           ELSE N'' END;

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        UPDATE f
           SET f.STATUS            = CASE @Acao WHEN 'REENVIAR' THEN 'PENDENTE' ELSE 'CANCELADO' END,
               f.TENTATIVAS        = CASE @Acao WHEN 'REENVIAR' THEN 0 ELSE f.TENTATIVAS END,
               f.PROXIMA_TENTATIVA = CASE @Acao WHEN 'REENVIAR' THEN @Agora ELSE f.PROXIMA_TENTATIVA END,
               f.ULTIMO_ERRO       = CASE @Acao WHEN 'REENVIAR' THEN N'' ELSE f.ULTIMO_ERRO END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        VALUES (@IdEmail, @Tentativas, CASE @Acao WHEN 'REENVIAR' THEN 'REENVIO' ELSE 'CANCELADO' END,
                CASE @Acao WHEN 'REENVIAR' THEN N'Reenvio pedido pela tela.' ELSE LEFT(N'Cancelado: ' + @Motivo, 1000) END, @Usuario);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Acao WHEN 'REENVIAR' THEN N'E-mail colocado de novo na fila.' ELSE N'E-mail cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Grupo_Email_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Grupos de e-mail": cada grupo com a quantidade e a lista
                de destinatários ativos (separados por "; ").
                Permissão: VER em SIS_GRUPO_EMAIL.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os grupos de e-mail.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT g.ID_GRUPO_EMAIL, g.CODIGO, g.NOME, g.DESCRICAO, g.ATIVO,
               (SELECT COUNT(*) FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1) AS QTD_DESTINATARIOS,
               ISNULL((SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), d.EMAIL), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
                       FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1), N'') AS DESTINATARIOS,
               g.DT_ALTERACAO, g.USUARIO_ALTERACAO
        FROM SIS.Grupo_Email g
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR g.ATIVO = 1)
        ORDER BY g.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os grupos de e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Grupo_Email_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdGrupoEmail NULL) ou altera um grupo de e-mail e a
                lista de destinatários dele.
                @Destinatarios: todos os endereços do grupo, separados por
                ";", "," ou quebra de linha. A lista gravada fica igual à
                informada: endereço novo entra, endereço que saiu é
                excluído (fica na auditoria), endereço desativado volta.
                Recusa com a lista dos endereços inválidos (nada é gravado).
                Código: letras maiúsculas, números e "_" (ex.: FIN_PAGAR);
                não muda depois de criado (as rotinas usam o código).
                Permissão: INCLUIR ou ALTERAR em SIS_GRUPO_EMAIL.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = 2, @IdGrupoEmail = NULL, @Codigo = 'FIN_PAGAR',
    --      @Nome = N'Contas a pagar', @Destinatarios = N'financeiro@cmj.com.br';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Gravar]
    @IdUsuario      INT,
    @IdGrupoEmail   INT           = NULL,
    @Codigo         VARCHAR(30),
    @Nome           NVARCHAR(80),
    @Descricao      NVARCHAR(400) = NULL,
    @Ativo          BIT           = 1,
    @Destinatarios  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Invalidos  NVARCHAR(MAX);
    DECLARE @CodigoAtual VARCHAR(30);
    DECLARE @Lista      TABLE (EMAIL NVARCHAR(256) PRIMARY KEY);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Nome      = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', CASE WHEN @IdGrupoEmail IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar grupos de e-mail.';

        IF @Recusa = N'' AND @IdGrupoEmail IS NOT NULL
        BEGIN
            SELECT @CodigoAtual = g.CODIGO FROM SIS.Grupo_Email g WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail;
            IF @CodigoAtual IS NULL SET @Recusa = N'Grupo não encontrado.';
            ELSE IF @Codigo <> @CodigoAtual SET @Recusa = N'O código do grupo não pode ser mudado (as rotinas usam o código).';
        END;

        IF @Recusa = N'' AND (@Codigo = '' OR LEN(@Codigo) > 30 OR REPLACE(@Codigo, '_', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras maiúsculas sem acento, números e "_" (ex.: FIN_PAGAR).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do grupo.';
        IF @Recusa = N'' AND @IdGrupoEmail IS NULL AND EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = @Codigo)
            SET @Recusa = N'Já existe um grupo com este código.';

        IF @Recusa = N''
        BEGIN
            INSERT INTO @Lista (EMAIL)
            SELECT DISTINCT LOWER(LTRIM(RTRIM(s.value)))
            FROM STRING_SPLIT(REPLACE(REPLACE(REPLACE(ISNULL(@Destinatarios, N''), NCHAR(13), N';'), NCHAR(10), N';'), N',', N';'), N';') s
            WHERE LTRIM(RTRIM(s.value)) <> N'';

            SELECT @Invalidos = STRING_AGG(CONVERT(NVARCHAR(MAX), l.EMAIL), N'; ')
            FROM @Lista l
            WHERE SIS.fn_SIS_Email_Valido(l.EMAIL) = 0;

            IF ISNULL(@Invalidos, N'') <> N''
                SET @Recusa = LEFT(N'Endereço(s) inválido(s): ' + @Invalidos, 400);
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdGrupoEmail IS NULL
        BEGIN
            INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Nome, @Descricao, @Ativo, @Usuario);
            SET @IdGrupoEmail = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NOME = @Nome, g.DESCRICAO = @Descricao, g.ATIVO = @Ativo,
                   g.DT_ALTERACAO = @Agora, g.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Grupo_Email g
            WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail
              AND (g.NOME <> @Nome COLLATE Latin1_General_BIN2 OR g.DESCRICAO <> @Descricao COLLATE Latin1_General_BIN2 OR g.ATIVO <> @Ativo);

        DELETE d
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND NOT EXISTS (SELECT 1 FROM @Lista l WHERE l.EMAIL = d.EMAIL);

        UPDATE d
           SET d.ATIVO = 1, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND d.ATIVO = 0;

        INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, USUARIO_CRIACAO)
        SELECT @IdGrupoEmail, l.EMAIL, @Usuario
        FROM @Lista l
        WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail AND d.EMAIL = l.EMAIL);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Grupo gravado com ' + CAST((SELECT COUNT(*) FROM @Lista) AS NVARCHAR(10)) + N' destinatário(s).' AS NVARCHAR(400)) AS MENSAGEM,
               @IdGrupoEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o grupo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Agendador das rotinas automáticas (substitui o SQL Agent, que
                o Express não tem). O serviço do sistema chama a cada minuto.
                1) Rotina presa além do TEMPO_LIMITE_MINUTOS (o serviço caiu
                   no meio): fecha a execução como ERRO e reagenda.
                2) Roda, uma de cada vez e até @Maximo, as rotinas vencidas:
                   ativas (ou pedidas em "executar agora"), não em execução,
                   com o módulo na licença e habilitado. A captura usa
                   UPDLOCK + READPAST: duas chamadas nunca rodam a mesma.
                3) Cada rotina roda com o contexto do usuário interno
                   "sistema" (a auditoria mostra "sistema" e a origem
                   "rotina:<CODIGO>"), por EXEC da procedure cadastrada em
                   SIS.Rotina (precisa existir e não ter parâmetros).
                4) Grava o resultado em SIS.Rotina_Execucao e em SIS.Rotina e
                   calcula a próxima execução (fn_SIS_Rotina_Proxima). Erro
                   da rotina vai também para SIS.Log_Erro e não impede as
                   outras de rodar.
                Devolve 1 linha: QTD_EXECUTADAS, QTD_ERRO, QTD_LIBERADAS
                (@Silencioso = 1: não devolve nada).
                Não roda dentro de transação aberta (nem via INSERT-EXEC):
                cada rotina precisa controlar a própria transação.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Processar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Processar]
    @Servidor  NVARCHAR(128),
    @Maximo      INT = 10,
    @Silencioso  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Rotina_Processar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Rotinas presas';
    DECLARE @IdSistema   INT           = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema');
    DECLARE @Feitas      INT           = 0;
    DECLARE @Erros       INT           = 0;
    DECLARE @Liberadas   INT           = 0;
    DECLARE @IdRotina    INT;
    DECLARE @Codigo      VARCHAR(40);
    DECLARE @Proc        NVARCHAR(256);
    DECLARE @Solicitante NVARCHAR(100);
    DECLARE @IdExecucao  BIGINT;
    DECLARE @Inicio      DATETIME2(0);
    DECLARE @ObjId       INT;
    DECLARE @Sql         NVARCHAR(600);
    DECLARE @Resultado   VARCHAR(10);
    DECLARE @Msg         NVARCHAR(1000);
    DECLARE @OrigemCtx   NVARCHAR(256);
    DECLARE @Presas      TABLE (ID_ROTINA INT PRIMARY KEY);

    IF @@TRANCOUNT > 0
        THROW 50001, N'O agendador de rotinas não pode rodar dentro de uma transação.', 1;

    BEGIN TRY
        SET @Servidor = LEFT(ISNULL(@Servidor, N''), 128);
        SET @Maximo   = CASE WHEN ISNULL(@Maximo, 0) < 1 THEN 10 WHEN @Maximo > 100 THEN 100 ELSE @Maximo END;

        -- 1) Presas além do tempo limite
        BEGIN TRANSACTION;

        UPDATE r
           SET r.EM_EXECUCAO      = 0,
               r.ULTIMO_RESULTADO = 'ERRO',
               r.ULTIMA_MENSAGEM  = N'Passou do tempo limite de ' + CAST(r.TEMPO_LIMITE_MINUTOS AS NVARCHAR(10)) + N' min sem terminar (o serviço pode ter parado).',
               r.SOLICITADA_POR   = N'',
               r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
        OUTPUT inserted.ID_ROTINA INTO @Presas (ID_ROTINA)
        FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE r.EM_EXECUCAO = 1
          AND r.DT_INICIO_EXECUCAO < DATEADD(MINUTE, -r.TEMPO_LIMITE_MINUTOS, SYSDATETIME());

        UPDATE e
           SET e.RESULTADO = 'ERRO', e.DT_FIM = SYSDATETIME(), e.MENSAGEM = N'Passou do tempo limite sem terminar.'
        FROM SIS.Rotina_Execucao e
        INNER JOIN @Presas p ON p.ID_ROTINA = e.ID_ROTINA
        WHERE e.RESULTADO = 'EXECUTANDO';

        SET @Liberadas = (SELECT COUNT(*) FROM @Presas);
        COMMIT TRANSACTION;

        -- 2) Vencidas, uma de cada vez
        WHILE @Feitas < @Maximo
        BEGIN
            SET @EtapaAtual = 'Captura';
            SET @IdRotina = NULL;

            BEGIN TRANSACTION;

            SELECT TOP (1) @IdRotina = r.ID_ROTINA, @Codigo = r.CODIGO, @Proc = r.PROCEDIMENTO, @Solicitante = r.SOLICITADA_POR
            FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.EM_EXECUCAO = 0
              AND r.PROXIMA_EXECUCAO <= SYSDATETIME()
              AND (r.ATIVA = 1 OR r.SOLICITADA_POR <> N'')
              AND m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1
            ORDER BY r.PROXIMA_EXECUCAO, r.ID_ROTINA;

            IF @IdRotina IS NULL
            BEGIN
                COMMIT TRANSACTION;
                BREAK;
            END;

            SET @Inicio = SYSDATETIME();
            UPDATE SIS.Rotina SET EM_EXECUCAO = 1, DT_INICIO_EXECUCAO = @Inicio WHERE ID_ROTINA = @IdRotina;

            INSERT INTO SIS.Rotina_Execucao (ID_ROTINA, ORIGEM, SOLICITANTE, SERVIDOR, DT_INICIO)
            VALUES (@IdRotina, CASE WHEN @Solicitante <> N'' THEN 'MANUAL' ELSE 'AGENDA' END, @Solicitante, @Servidor, @Inicio);
            SET @IdExecucao = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            -- 3) Execução
            SET @EtapaAtual = LEFT('Rotina ' + @Codigo, 100);
            SET @Resultado  = 'OK';
            SET @Msg        = N'';

            BEGIN TRY
                SET @OrigemCtx = N'rotina:' + @Codigo;
                EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = @Servidor, @Origem = @OrigemCtx;

                SET @ObjId = OBJECT_ID(@Proc, N'P');
                IF @ObjId IS NULL
                    THROW 50001, N'A procedure cadastrada para a rotina não existe.', 1;
                IF EXISTS (SELECT 1 FROM sys.parameters p WHERE p.object_id = @ObjId)
                    THROW 50001, N'A procedure da rotina não pode ter parâmetros.', 1;

                SET @Sql = N'EXEC ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N';';
                EXEC sys.sp_executesql @Sql;

                IF @@TRANCOUNT > 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    THROW 50001, N'A rotina terminou com uma transação aberta (desfeita).', 1;
                END;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

                SET @Resultado = 'ERRO';
                SET @Msg       = LEFT(ERROR_MESSAGE(), 1000);

                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
            END CATCH;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

            -- 4) Resultado e próxima execução
            SET @EtapaAtual = 'Resultado';
            UPDATE r
               SET r.EM_EXECUCAO      = 0,
                   r.ULTIMA_EXECUCAO  = @Inicio,
                   r.ULTIMO_RESULTADO = @Resultado,
                   r.ULTIMA_MENSAGEM  = @Msg,
                   r.SOLICITADA_POR   = N'',
                   r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
            FROM SIS.Rotina r
            WHERE r.ID_ROTINA = @IdRotina;

            UPDATE SIS.Rotina_Execucao
               SET DT_FIM = SYSDATETIME(), RESULTADO = @Resultado, MENSAGEM = @Msg
            WHERE ID_EXECUCAO = @IdExecucao;

            SET @Feitas = @Feitas + 1;
            IF @Resultado = 'ERRO' SET @Erros = @Erros + 1;
        END;

        IF ISNULL(@Silencioso, 0) = 0
            SELECT @Feitas AS QTD_EXECUTADAS, @Erros AS QTD_ERRO, @Liberadas AS QTD_LIBERADAS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas" (exclusiva do administrador
                geral): cada rotina com a agenda em texto ("A cada 10 min",
                "Diária às 03:10", "Semanal (seg, qua) às 08:00", "Mensal
                no dia 5 às 07:00"), situação, última e próxima execução.
                MODULO_DISPONIVEL = 0: o módulo da rotina está fora da
                licença ou desabilitado (a rotina não roda).
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT r.ID_ROTINA, r.CODIGO, r.NOME, r.DESCRICAO, m.CODIGO AS MODULO_CODIGO,
               CAST(CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS MODULO_DISPONIVEL,
               r.FREQUENCIA, r.INTERVALO_MINUTOS, CONVERT(VARCHAR(5), r.HORARIO, 108) AS HORARIO, r.DIAS_SEMANA, r.DIA_MES,
               CAST(CASE r.FREQUENCIA
                        WHEN 'MINUTOS' THEN N'A cada ' + CAST(r.INTERVALO_MINUTOS AS NVARCHAR(10)) + N' min'
                        WHEN 'DIARIA'  THEN N'Diária às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        WHEN 'SEMANAL' THEN N'Semanal (' + ISNULL((SELECT STRING_AGG(CHOOSE(TRY_CAST(s.value AS INT), N'dom', N'seg', N'ter', N'qua', N'qui', N'sex', N'sáb'), N', ')
                                                                          WITHIN GROUP (ORDER BY TRY_CAST(s.value AS INT))
                                                                   FROM STRING_SPLIT(r.DIAS_SEMANA, ',') s WHERE s.value <> ''), N'') + N') às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        ELSE CASE WHEN r.DIA_MES = 31 THEN N'Mensal no último dia às ' ELSE N'Mensal no dia ' + CAST(r.DIA_MES AS NVARCHAR(3)) + N' às ' END + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                    END AS NVARCHAR(200)) AS AGENDA_TEXTO,
               r.TEMPO_LIMITE_MINUTOS, r.ATIVA, r.EM_EXECUCAO, r.PROXIMA_EXECUCAO, r.SOLICITADA_POR,
               r.ULTIMA_EXECUCAO, r.ULTIMO_RESULTADO, r.ULTIMA_MENSAGEM, r.PROCEDIMENTO
        FROM SIS.Rotina r
        INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
        ORDER BY m.ORDEM_MENU, r.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas": muda a agenda de uma rotina e
                liga/desliga. A rotina em si (qual procedure roda) só muda
                por carga: pela tela não se cadastra rotina nova.
                @Frequencia MINUTOS usa @IntervaloMinutos (1 a 1440);
                DIARIA usa @Horario ('HH:MM'); SEMANAL usa @DiasSemana
                ('2,4', 1 = domingo) e @Horario; MENSAL usa @DiaMes (1 a 31;
                31 = último dia) e @Horario. Os campos que a frequência não
                usa são zerados.
                Recalcula a próxima execução (desligada = sem próxima).
                Permissão: ALTERAR em SIS_ROTINA (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Gravar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'DIARIA', @Horario = '03:10';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Gravar]
    @IdUsuario           INT,
    @Codigo              VARCHAR(40),
    @Ativa               BIT,
    @Frequencia          VARCHAR(10),
    @IntervaloMinutos    INT         = NULL,
    @Horario             VARCHAR(5)  = NULL,
    @DiasSemana          VARCHAR(20) = NULL,
    @DiaMes              TINYINT     = NULL,
    @TempoLimiteMinutos  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @IdRotina   INT;
    DECLARE @Hora       TIME(0);
    DECLARE @Dias       VARCHAR(20)   = '';
    DECLARE @Proxima    DATETIME2(0);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar as rotinas automáticas.';

        SET @Codigo     = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Frequencia = UPPER(LTRIM(RTRIM(ISNULL(@Frequencia, ''))));
        SET @Ativa      = ISNULL(@Ativa, 0);

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @TempoLimiteMinutos = ISNULL(@TempoLimiteMinutos, r.TEMPO_LIMITE_MINUTOS)
            FROM SIS.Rotina r WHERE r.CODIGO = @Codigo;
            IF @IdRotina IS NULL SET @Recusa = N'Rotina não encontrada.';
        END;

        IF @Recusa = N'' AND @Frequencia NOT IN ('MINUTOS', 'DIARIA', 'SEMANAL', 'MENSAL')
            SET @Recusa = N'Escolha a frequência: a cada X minutos, diária, semanal ou mensal.';

        IF @Recusa = N'' AND @Frequencia = 'MINUTOS' AND ISNULL(@IntervaloMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Informe o intervalo em minutos (de 1 a 1440).';

        IF @Recusa = N'' AND @Frequencia <> 'MINUTOS'
        BEGIN
            SET @Hora = TRY_CONVERT(TIME(0), LTRIM(RTRIM(ISNULL(@Horario, ''))));
            IF @Hora IS NULL OR LEN(LTRIM(RTRIM(@Horario))) <> 5 SET @Recusa = N'Informe o horário no formato HH:MM (ex.: 03:10).';
        END;

        IF @Recusa = N'' AND @Frequencia = 'SEMANAL'
        BEGIN
            IF EXISTS (SELECT 1 FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s
                       WHERE s.value <> '' AND ISNULL(TRY_CAST(s.value AS INT), 0) NOT BETWEEN 1 AND 7)
                SET @Recusa = N'Dias da semana inválidos (1 = domingo ... 7 = sábado).';
            ELSE
                SELECT @Dias = ISNULL(STRING_AGG(CAST(d.N AS VARCHAR(1)), ',') WITHIN GROUP (ORDER BY d.N), '')
                FROM (SELECT DISTINCT TRY_CAST(s.value AS INT) AS N
                      FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s WHERE s.value <> '') d;
            IF @Recusa = N'' AND @Dias = '' SET @Recusa = N'Escolha ao menos um dia da semana.';
        END;

        IF @Recusa = N'' AND @Frequencia = 'MENSAL' AND ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31
            SET @Recusa = N'Informe o dia do mês (1 a 31; 31 = último dia).';

        IF @Recusa = N'' AND ISNULL(@TempoLimiteMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Tempo limite inválido (de 1 a 1440 minutos).';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        IF @Frequencia <> 'MINUTOS' SET @IntervaloMinutos = 0;
        IF @Frequencia = 'MINUTOS'  SET @Hora = '00:00';
        IF @Frequencia <> 'MENSAL'  SET @DiaMes = 0;

        SET @Proxima = CASE WHEN @Ativa = 1 THEN SIS.fn_SIS_Rotina_Proxima(@Frequencia, @IntervaloMinutos, @Hora, @Dias, @DiaMes, SYSDATETIME()) END;
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.ATIVA                = @Ativa,
               r.FREQUENCIA           = @Frequencia,
               r.INTERVALO_MINUTOS    = @IntervaloMinutos,
               r.HORARIO              = @Hora,
               r.DIAS_SEMANA          = @Dias,
               r.DIA_MES              = @DiaMes,
               r.TEMPO_LIMITE_MINUTOS = @TempoLimiteMinutos,
               r.PROXIMA_EXECUCAO     = CASE WHEN r.EM_EXECUCAO = 1 THEN r.PROXIMA_EXECUCAO ELSE @Proxima END,
               r.DT_ALTERACAO         = SYSDATETIME(),
               r.USUARIO_ALTERACAO    = @Usuario
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Ativa = 0 THEN N'Rotina desligada: não roda mais pela agenda.'
                         ELSE N'Agenda gravada. Próxima execução: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@Proxima), N'-') + N'.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a rotina. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Executar_Agora.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Executar_Agora]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão "Executar agora" da tela "Rotinas automáticas": marca a
                rotina para rodar na próxima volta do agendador (o serviço
                confere a cada minuto). Vale também para rotina desligada
                (roda uma vez). A execução fica registrada como MANUAL, com
                quem pediu.
                Recusa se já está em execução ou se o módulo da rotina está
                fora da licença ou desabilitado.
                Permissão: EXECUTAR em SIS_ROTINA. Devolve SUCESSO, MENSAGEM,
                ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Executar_Agora @IdUsuario = 2, @Codigo = 'EMAIL_PRESOS';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Executar_Agora]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Executar_Agora]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdRotina   INT;
    DECLARE @EmExecucao BIT;
    DECLARE @Disponivel BIT;

    BEGIN TRY
        SET @Codigo = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar rotinas.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @EmExecucao = r.EM_EXECUCAO,
                   @Disponivel = CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END
            FROM SIS.Rotina r
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.CODIGO = @Codigo;

            SET @Recusa = CASE WHEN @IdRotina IS NULL THEN N'Rotina não encontrada.'
                               WHEN @EmExecucao = 1 THEN N'A rotina já está em execução.'
                               WHEN @Disponivel = 0 THEN N'O módulo desta rotina está fora da licença ou desabilitado.'
                               ELSE N'' END;
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.PROXIMA_EXECUCAO = SYSDATETIME(),
               r.SOLICITADA_POR   = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina AND r.EM_EXECUCAO = 0;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Pedido registrado: a rotina roda em até 1 minuto.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Execucao_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Execucao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico das execuções das rotinas automáticas (todas ou de
                uma rotina), mais recente primeiro, com a duração em
                segundos.
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Execucao_Listar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Execucao_Listar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40) = NULL,
    @MaxLinhas  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Execucao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @Codigo    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Codigo, '')))), '');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               e.ID_EXECUCAO, r.CODIGO, r.NOME, e.ORIGEM, e.SOLICITANTE, e.SERVIDOR, e.DT_INICIO, e.DT_FIM,
               DATEDIFF(SECOND, e.DT_INICIO, ISNULL(e.DT_FIM, SYSDATETIME())) AS DURACAO_SEGUNDOS,
               e.RESULTADO, e.MENSAGEM
        FROM SIS.Rotina_Execucao e WITH (NOLOCK)
        INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA
        WHERE (@Codigo IS NULL OR r.CODIGO = @Codigo)
        ORDER BY e.ID_EXECUCAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico das rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (exclusiva do
                administrador geral), por grupo e ordem, com o último pedido
                de cada comando (situação, quando e por quem).
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMANDO, c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO,
               CAST(CASE c.GRUPO WHEN 'INSTALACAO'  THEN N'Instalação'
                                 WHEN 'ATUALIZACAO' THEN N'Atualização'
                                 WHEN 'BACKUP'      THEN N'Backup'
                                 WHEN 'SERVICO'     THEN N'Serviço do sistema'
                                 ELSE N'Diagnóstico' END AS NVARCHAR(40)) AS GRUPO_NOME,
               c.ORDEM, c.PERIGOSO, c.ACEITA_PARAMETRO, c.PARAMETRO_DESCRICAO,
               u.ID_PEDIDO AS ULTIMO_PEDIDO, u.STATUS AS ULTIMO_STATUS, u.DT_PEDIDO AS ULTIMO_DT_PEDIDO,
               u.USUARIO_PEDIDO AS ULTIMO_USUARIO, u.DT_FIM AS ULTIMO_DT_FIM
        FROM SIS.Comando c
        OUTER APPLY (SELECT TOP (1) f.ID_PEDIDO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.DT_FIM
                     FROM SIS.Comando_Fila f WHERE f.ID_COMANDO = c.ID_COMANDO ORDER BY f.ID_PEDIDO DESC) u
        WHERE c.ATIVO = 1
        ORDER BY CASE c.GRUPO WHEN 'INSTALACAO' THEN 1 WHEN 'ATUALIZACAO' THEN 2 WHEN 'BACKUP' THEN 3 WHEN 'SERVICO' THEN 4 ELSE 5 END,
                 c.ORDEM, c.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os comandos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Solicitar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Solicitar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão de um comando na tela "Instalação e manutenção": grava o
                pedido em SIS.Comando_Fila para o serviço executar. Não
                executa nada no Windows.
                - Comando PERIGOSO: a API só chama esta procedure depois de
                  pedir a senha de novo e a confirmação.
                - @Parametro: só para comando que aceita (e aí é
                  obrigatório). Recusa caracteres que poderiam virar outro
                  comando (& | ; < > ` " ' % ^ e quebra de linha); o serviço
                  valida de novo.
                - Recusa se o mesmo comando já está pendente ou executando.
                Permissão: EXECUTAR em SIS_INSTALACAO (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID
                (ID = número do pedido).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Solicitar @IdUsuario = 2, @Codigo = 'DISCO_ESPACO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Solicitar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40),
    @Parametro  NVARCHAR(400) = NULL,
    @Estacao    NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Solicitar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdComando  INT;
    DECLARE @Aceita     BIT;
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Parametro = LTRIM(RTRIM(ISNULL(@Parametro, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar comandos de instalação e manutenção.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdComando = c.ID_COMANDO, @Aceita = c.ACEITA_PARAMETRO
            FROM SIS.Comando c WHERE c.CODIGO = @Codigo AND c.ATIVO = 1;
            IF @IdComando IS NULL SET @Recusa = N'Comando não encontrado.';
        END;

        IF @Recusa = N'' AND @Aceita = 0 AND @Parametro <> N''
            SET @Recusa = N'Este comando não recebe valor.';
        IF @Recusa = N'' AND @Aceita = 1 AND @Parametro = N''
            SET @Recusa = N'Informe o valor pedido pelo comando.';
        IF @Recusa = N'' AND @Parametro <> N''
           AND (   @Parametro LIKE N'%[&|;<>`"''%^]%'
                OR CHARINDEX(NCHAR(13), @Parametro) > 0 OR CHARINDEX(NCHAR(10), @Parametro) > 0 OR CHARINDEX(N'..', @Parametro) > 0)
            SET @Recusa = N'O valor tem caracteres não permitidos.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK)
                   WHERE f.ID_COMANDO = @IdComando AND f.STATUS IN ('PENDENTE', 'EXECUTANDO'))
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este comando já está na fila ou em execução.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        INSERT INTO SIS.Comando_Fila (ID_COMANDO, PARAMETRO, USUARIO_PEDIDO, ESTACAO_PEDIDO)
        VALUES (@IdComando, @Parametro, SIS.fn_SIS_Usuario_Login(@IdUsuario),
                LEFT(ISNULL(NULLIF(@Estacao, N''), ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ESTACAO')), N'')), 128));
        SET @IdPedido = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Pedido registrado. Acompanhe o resultado nesta tela.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Cancelar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Cancela um pedido de comando que ainda não começou
                (PENDENTE). Comando em execução não é interrompido por aqui.
                Permissão: CANCELAR em SIS_INSTALACAO. Devolve SUCESSO,
                MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Cancelar @IdUsuario = 2, @IdPedido = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Cancelar]
    @IdUsuario  INT,
    @IdPedido   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'CANCELAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para cancelar comandos.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE f
           SET f.STATUS               = 'CANCELADO',
               f.DT_CANCELAMENTO      = SYSDATETIME(),
               f.USUARIO_CANCELAMENTO = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'PENDENTE';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pedido cancelado.' ELSE N'Só pedido pendente (que ainda não começou) pode ser cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível cancelar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Fila_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Fila_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico dos pedidos de comandos (tela "Instalação e
                manutenção"), mais recente primeiro. @IdPedido informado:
                só aquele pedido, com a saída completa (para a janela de
                detalhe); sem ele, a saída vem cortada em 500 caracteres.
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Fila_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Fila_Listar]
    @IdUsuario  INT,
    @IdPedido   BIGINT = NULL,
    @MaxLinhas  INT    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Fila_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 2000 THEN 200 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_PEDIDO, c.CODIGO, c.NOME, f.PARAMETRO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.ESTACAO_PEDIDO,
               f.DT_INICIO, f.DT_FIM, f.SERVIDOR, f.CODIGO_SAIDA,
               CASE WHEN @IdPedido IS NULL AND LEN(f.SAIDA) > 500 THEN LEFT(f.SAIDA, 500) + N' (...)' ELSE f.SAIDA END AS SAIDA,
               f.DT_CANCELAMENTO, f.USUARIO_CANCELAMENTO
        FROM SIS.Comando_Fila f WITH (NOLOCK)
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE (@IdPedido IS NULL OR f.ID_PEDIDO = @IdPedido)
        ORDER BY f.ID_PEDIDO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os pedidos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Capturar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema. Pega o pedido de comando
                PENDENTE mais antigo e marca EXECUTANDO; um comando de cada
                vez (se já existe um executando, não devolve nada).
                Devolve 0 ou 1 linha: ID_PEDIDO, CODIGO, PARAMETRO. O
                serviço executa o que estiver na SUA lista fixa para o
                CODIGO e chama SIS_Comando_Resultado_Gravar.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Capturar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Capturar]
    @Servidor  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK) WHERE f.STATUS = 'EXECUTANDO')
        BEGIN
            SELECT TOP (1) @IdPedido = f.ID_PEDIDO
            FROM SIS.Comando_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
            ORDER BY f.ID_PEDIDO;

            IF @IdPedido IS NOT NULL
                UPDATE SIS.Comando_Fila
                   SET STATUS = 'EXECUTANDO', DT_INICIO = SYSDATETIME(), SERVIDOR = LEFT(ISNULL(@Servidor, N''), 128)
                WHERE ID_PEDIDO = @IdPedido;
        END;

        COMMIT TRANSACTION;

        SELECT f.ID_PEDIDO, c.CODIGO, f.PARAMETRO
        FROM SIS.Comando_Fila f
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE f.ID_PEDIDO = @IdPedido;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Resultado_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, ao terminar um comando capturado:
                grava CONCLUIDO (@Sucesso = 1) ou ERRO, o código de saída e a
                saída do comando (o serviço tira senhas e chaves antes de
                mandar). Só aceita pedido em EXECUTANDO.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Resultado_Gravar @IdPedido = 1, @Sucesso = 1, @CodigoSaida = 0, @Saida = N'ok';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Resultado_Gravar]
    @IdPedido     BIGINT,
    @Sucesso      BIT,
    @CodigoSaida  INT           = NULL,
    @Saida        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Resultado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Gravação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        UPDATE f
           SET f.STATUS       = CASE WHEN ISNULL(@Sucesso, 0) = 1 THEN 'CONCLUIDO' ELSE 'ERRO' END,
               f.DT_FIM       = SYSDATETIME(),
               f.CODIGO_SAIDA = @CodigoSaida,
               f.SAIDA        = ISNULL(@Saida, N'')
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'EXECUTANDO';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Resultado gravado.' ELSE N'O pedido não está em execução.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Item.sql
-- =============================================================================
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
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOTE',          N'Lotes',               'TELA', 'sis/lotes.html',       30, 0, 1, 'SIS.Lote')
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
        ('SIS_EMAIL_FILA','EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Rotina.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Rotina]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotinas automáticas da base SIS. Só insere o que falta
                (regra 39): agenda já mudada pela tela não é desfeita.
                Cada etapa seguinte acrescenta aqui as rotinas do seu módulo
                (ex.: avisos de vencimento, retorno do banco), com a
                procedure sem parâmetros que a rotina chama.
                A próxima execução é calculada na inclusão.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d): limpeza do log passo a passo e
                        liberação de e-mails presos.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.PROCEDIMENTO, m.ID_MODULO, v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES,
       v.LIMITE, 1, SIS.fn_SIS_Rotina_Proxima(v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES, SYSDATETIME()), N'instalacao'
FROM (VALUES
        (CAST('LOG_LIMPEZA' AS VARCHAR(40)), CAST(N'Limpeza do log passo a passo' AS NVARCHAR(80)),
         CAST(N'Apaga o log passo a passo das rotinas mais antigo que o parâmetro LOG_PASSO_DIAS_RETENCAO. O log de erros não é apagado.' AS NVARCHAR(400)),
         CAST(N'SIS.SIS_Log_Limpar_Processar' AS NVARCHAR(256)), CAST('SIS' AS VARCHAR(10)), CAST('DIARIA' AS VARCHAR(10)),
         CAST(0 AS INT), CAST('03:10' AS TIME(0)), CAST('' AS VARCHAR(20)), CAST(0 AS TINYINT), CAST(60 AS INT)),
        ('EMAIL_PRESOS', N'Liberar e-mails presos',
         N'Devolve para a fila os e-mails que ficaram "processando" (o serviço parou no meio do envio), conforme o parâmetro EMAIL_MINUTOS_PRESO.',
         N'SIS.SIS_Email_Presos_Liberar', 'SIS', 'MINUTOS', 10, '00:00', '', 0, 10)
     ) v (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, MODULO, FREQUENCIA, INTERVALO, HORARIO, DIAS, DIA_MES, LIMITE)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Comando.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (pedidos 2 e 4 do
                Celso). Só insere o que falta; nome, descrição, grupo, ordem
                e as marcas PERIGOSO / ACEITA_PARAMETRO são acertados também
                em comando já existente (comandos só mudam por carga).
                O que cada CODIGO faz de verdade fica na lista fixa do
                serviço (fase 3, API/serviço); código sem tratamento no
                serviço termina em ERRO "comando não disponível nesta
                versão".
                A primeira instalação (SQL Server Express, .NET e o próprio
                serviço) é feita pelo instalador único, rodado uma vez como
                administrador do Windows; daí em diante, tudo por aqui.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaComando;

SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.GRUPO, v.ORDEM, v.PERIGOSO, v.ACEITA, v.PARAM_DESC
INTO #CargaComando
FROM (VALUES
        (CAST('PASTAS_CRIAR' AS VARCHAR(40)), CAST(N'Criar as pastas do sistema' AS NVARCHAR(80)),
         CAST(N'Cria (se faltar) as pastas de anexos, identidade visual, backup e atualizações dos parâmetros, com as permissões do serviço.' AS NVARCHAR(1000)),
         CAST('INSTALACAO' AS VARCHAR(20)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(0 AS BIT), CAST(N'' AS NVARCHAR(200))),
        ('FIREWALL_LIBERAR', N'Liberar o sistema no firewall',
         N'Cria a regra do Firewall do Windows para a porta do sistema, só para a rede interna.', 'INSTALACAO', 20, 1, 0, N''),
        ('CERTIFICADO_HTTPS', N'Instalar ou renovar o certificado HTTPS',
         N'Instala o certificado (.pfx) usado pelo endereço seguro do sistema e reinicia o serviço.', 'INSTALACAO', 30, 1, 1,
         N'Nome do arquivo .pfx na pasta de atualizações'),
        ('SERVICO_INSTALAR', N'Reinstalar o serviço do sistema',
         N'Registra de novo o serviço do Windows do SistemaCMJ (início automático e recuperação em falha).', 'INSTALACAO', 40, 1, 0, N''),
        ('ATUALIZACAO_BANCO', N'Aplicar atualização do banco',
         N'Faz backup e depois roda o pacote de atualização do banco (.sql) que está na pasta de atualizações.', 'ATUALIZACAO', 10, 1, 1,
         N'Nome do arquivo .sql na pasta de atualizações'),
        ('ATUALIZACAO_SISTEMA', N'Atualizar o sistema (telas e API)',
         N'Para o serviço, troca os arquivos do sistema pelo pacote (.zip) da pasta de atualizações, guardando a versão anterior, e inicia o serviço.', 'ATUALIZACAO', 20, 1, 1,
         N'Nome do arquivo .zip na pasta de atualizações'),
        ('BACKUP_AGORA', N'Fazer backup agora',
         N'Backup completo do banco na pasta de backup, com conferência (RESTORE VERIFYONLY).', 'BACKUP', 10, 0, 0, N''),
        ('BACKUP_TESTAR', N'Testar a restauração do último backup',
         N'Restaura o último backup num banco de teste separado, confere e apaga o banco de teste. O banco em uso não é tocado.', 'BACKUP', 20, 0, 0, N''),
        ('BACKUP_COPIAR', N'Copiar backups para fora do servidor',
         N'Copia os backups para a pasta externa configurada (disco externo ou pasta sincronizada com a nuvem).', 'BACKUP', 30, 0, 0, N''),
        ('SERVICO_SITUACAO', N'Ver situação do serviço',
         N'Mostra se o serviço está rodando, desde quando, a versão e a última volta da fila de e-mails e das rotinas.', 'SERVICO', 10, 0, 0, N''),
        ('SERVICO_REINICIAR', N'Reiniciar o serviço do sistema',
         N'Reinicia o serviço do SistemaCMJ. Os usuários conectados perdem a tela aberta por alguns segundos.', 'SERVICO', 20, 1, 0, N''),
        ('BANCO_VERIFICAR', N'Verificar a integridade do banco',
         N'Roda o DBCC CHECKDB e mostra o resultado.', 'DIAGNOSTICO', 10, 0, 0, N''),
        ('DISCO_ESPACO', N'Espaço em disco do servidor',
         N'Mostra o espaço livre dos discos e o tamanho do banco, dos anexos e dos backups.', 'DIAGNOSTICO', 20, 0, 0, N''),
        ('LOG_SERVICO_VER', N'Ver o log do serviço',
         N'Mostra as últimas linhas do log do serviço do sistema (sem senhas).', 'DIAGNOSTICO', 30, 0, 0, N'')
     ) v (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA, PARAM_DESC);

INSERT INTO SIS.Comando (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA_PARAMETRO, PARAMETRO_DESCRICAO, USUARIO_CRIACAO)
SELECT c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO, c.ORDEM, c.PERIGOSO, c.ACEITA, c.PARAM_DESC, N'instalacao'
FROM #CargaComando c
WHERE NOT EXISTS (SELECT 1 FROM SIS.Comando x WHERE x.CODIGO = c.CODIGO);

UPDATE x
   SET x.NOME = c.NOME, x.DESCRICAO = c.DESCRICAO, x.GRUPO = c.GRUPO, x.ORDEM = c.ORDEM,
       x.PERIGOSO = c.PERIGOSO, x.ACEITA_PARAMETRO = c.ACEITA, x.PARAMETRO_DESCRICAO = c.PARAM_DESC,
       x.DT_ALTERACAO = SYSDATETIME(), x.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Comando x
INNER JOIN #CargaComando c ON c.CODIGO = x.CODIGO
WHERE x.NOME <> c.NOME COLLATE Latin1_General_BIN2 OR x.DESCRICAO <> c.DESCRICAO COLLATE Latin1_General_BIN2
   OR x.GRUPO <> c.GRUPO OR x.ORDEM <> c.ORDEM OR x.PERIGOSO <> c.PERIGOSO OR x.ACEITA_PARAMETRO <> c.ACEITA
   OR x.PARAMETRO_DESCRICAO <> c.PARAM_DESC COLLATE Latin1_General_BIN2;

DROP TABLE IF EXISTS #CargaComando;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de configuração e
                segurança do SIS, gerando cada trigger com
                SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas.
                No MASTER fica na parte 8 (triggers). Cada etapa seguinte
                acrescenta aqui (ou na carga do seu bloco) as suas tabelas.
                Não auditadas (são registros, não cadastros): Log_Erro,
                Log_Passo, Login_Log, Sessao, Lote e a própria Auditoria.
                SIS.Usuario: não registra contador de tentativas nem último
                login (mudam a cada acesso); hash e salt da senha saem "***".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (16/11/2026) - Etapa 02d: grupos de e-mail, rotinas (sem as colunas
                        de execução) e comandos. Filas e logs não são
                        auditados (têm histórico próprio).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Modulo',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Acao',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item_Acao',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil_Permissao',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario',           @Criar = 1,
     @CamposIgnorados = N'TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN', @CamposSigilosos = N'SENHA_HASH,SENHA_SALT';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario_Permissao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca_Empresa',   @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo_Tipo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo',             @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email_Destinatario', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Rotina',            @Criar = 1,
     @CamposIgnorados = N'PROXIMA_EXECUCAO,SOLICITADA_POR,EM_EXECUCAO,DT_INICIO_EXECUCAO,ULTIMA_EXECUCAO,ULTIMO_RESULTADO,ULTIMA_MENSAGEM';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comando',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.rl_sistemacmj_api.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : papel [rl_sistemacmj_api]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Papel do banco usado pelo login da API e do serviço do
                sistema (CLAUDE.md seção 2): só EXECUTA procedures e
                functions dos schemas do sistema; não lê nem grava tabela
                direto (as procedures fazem isso por encadeamento de dono).
                Proteções a mais:
                  - DENY de INSERT/UPDATE/DELETE em SIS.Auditoria (além da
                    trigger de proteção);
                  - DENY de EXECUTE no gerador de triggers (só instalação).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NULL
    CREATE ROLE [rl_sistemacmj_api] AUTHORIZATION [dbo];
GO

DECLARE @Sql NVARCHAR(MAX) = N'';

SELECT @Sql = @Sql + N'GRANT EXECUTE ON SCHEMA::' + QUOTENAME(s.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.schemas s
WHERE s.name IN (N'SIS', N'CAD', N'BANCO', N'IMOB', N'VENDA', N'FIN', N'COBR', N'OBRA', N'GER', N'COMP');

EXEC sys.sp_executesql @Sql;
GO

DENY INSERT, UPDATE, DELETE ON [SIS].[Auditoria] TO [rl_sistemacmj_api];
DENY EXECUTE ON [SIS].[SIS_Auditoria_Trigger_Gerar] TO [rl_sistemacmj_api];
GO

PRINT N'Pacote 02d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
