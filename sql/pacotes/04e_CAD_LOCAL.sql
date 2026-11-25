/*******************************************************************************
  Pacote      : 04e - empresas, centros de custo, plano de contas e contas bancarias (telas): rodape dos e-mails (P11), fichas de empresa e conta, travas; banco 2.4
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 25/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04d2 já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/CAD/04e_Homologacao_Cadastros_Base.sql, 03a e 04b.
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
-- Arquivo: sql/objetos/CAD/CAD.Empresa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Empresas do grupo (Construtora, SPEs, Holding), cadastro livre do
                administrador (decisão do Celso, 16/11/2026). O CNPJ da licença só
                registra o software; documentos de uma empresa/obra usam a razão social
                e o CNPJ daqui. CNPJ: só dígitos/letras (aceita o alfanumérico), único
                quando preenchido (a migração pode trazer empresa sem CNPJ).
                ID_CONTA_BANCARIA_PADRAO: FK para BANCO.Conta criada em
                CAD.FK_Conta_Padrao.sql (a conta é criada depois desta tabela).
                Logomarca: anexo do tipo LOGOMARCA (SIS.Anexo).
                CNPJ_COMPRAS: segundo CNPJ, opcional, para notas de compra e DDA
                (ex.: SPE no RET, em que a Receita cria um CNPJ só para isso;
                decisão da CMJ, 17/11/2026). Cobrança e relatórios usam o CNPJ.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - CNPJ_COMPRAS (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
    v1.3 (25/11/2026) - Etapa 04e (P11): RODAPE_EMAIL, texto livre com os
                        contatos da empresa para o rodapé dos e-mails.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Empresa]
    (
        ID_EMPRESA                 INT            IDENTITY(1,1) NOT NULL,
        RAZAO_SOCIAL               NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_NOME_FANTASIA       DEFAULT (N''),
        CNPJ                       VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ                DEFAULT (''),
        CNPJ_COMPRAS               VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS        DEFAULT (''),
        TIPO                       VARCHAR(12)    NOT NULL CONSTRAINT DF_Empresa_TIPO                DEFAULT ('OUTRA'),
        INSCRICAO_ESTADUAL         VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL        VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_MUNICIPAL DEFAULT (''),
        REGIME_TRIBUTARIO          VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_REGIME_TRIBUTARIO   DEFAULT (''),
        CEP                        VARCHAR(8)     NOT NULL CONSTRAINT DF_Empresa_CEP                 DEFAULT (''),
        LOGRADOURO                 NVARCHAR(150)  NOT NULL CONSTRAINT DF_Empresa_LOGRADOURO          DEFAULT (N''),
        NUMERO                     NVARCHAR(20)   NOT NULL CONSTRAINT DF_Empresa_NUMERO              DEFAULT (N''),
        COMPLEMENTO                NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_BAIRRO              DEFAULT (N''),
        CIDADE                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_CIDADE              DEFAULT (N''),
        UF                         CHAR(2)        NOT NULL CONSTRAINT DF_Empresa_UF                  DEFAULT (''),
        EMAIL                      NVARCHAR(256)  NOT NULL CONSTRAINT DF_Empresa_EMAIL               DEFAULT (N''),
        TELEFONE                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_TELEFONE            DEFAULT (''),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Empresa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Empresa                   PRIMARY KEY CLUSTERED (ID_EMPRESA),
        CONSTRAINT CK_Empresa_TIPO              CHECK (TIPO IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')),
        CONSTRAINT CK_Empresa_REGIME_TRIBUTARIO CHECK (REGIME_TRIBUTARIO IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')),
        CONSTRAINT CK_Empresa_CNPJ              CHECK (CNPJ = '' OR (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CNPJ_COMPRAS      CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CEP               CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Empresa_UF                CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

-- v1.1: coluna nova em tabela já existente (regra 59)
IF COL_LENGTH(N'CAD.Empresa', N'CNPJ_COMPRAS') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CNPJ_COMPRAS VARCHAR(14) NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS DEFAULT ('');
GO
IF OBJECT_ID(N'CAD.CK_Empresa_CNPJ_COMPRAS', N'C') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT CK_Empresa_CNPJ_COMPRAS
        CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2));
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Empresa_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Empresa]'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Empresa_CNPJ ON [CAD].[Empresa] (CNPJ) WHERE CNPJ <> '';
GO

IF COL_LENGTH(N'CAD.Empresa', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Empresa', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- v1.3: rodapé dos e-mails da empresa (P11)
IF COL_LENGTH(N'CAD.Empresa', N'RODAPE_EMAIL') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD RODAPE_EMAIL NVARCHAR(1000) NOT NULL CONSTRAINT DF_Empresa_RODAPE_EMAIL DEFAULT (N'');
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Centro_Custo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Centro_Custo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Onde o dinheiro é aplicado ou gerado: OBRA, ADMINISTRATIVO (escritório),
                IMOVEL_PROPRIO (salas, aptos de aluguel) e PARTICULAR. Todo lançamento
                leva conta do plano + centro de custo; a empresa do lançamento vem daqui.
                CONTABIL = 0: obra/centro que não vai para a contabilidade (o fechamento
                de mês só bloqueia conta contábil em centro contábil).
                ID_CONTA_BANCARIA_PADRAO: se vazio, vale a da empresa.
                Dados próprios da obra ficam em OBRA.Obra (proposta seguinte).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
    v1.2 (25/11/2026) - Etapa 04e: DT_ENCERRAMENTO (obra entregue/centro
                        encerrado: depois dessa data, lançamento novo é bloqueado
                        ou avisado, parâmetro CENTRO_ENCERRADO_BLOQUEIA, regra
                        aplicada no FIN na 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Centro_Custo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Centro_Custo]
    (
        ID_CENTRO_CUSTO            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA                 INT            NOT NULL,
        CODIGO                     VARCHAR(20)    NOT NULL,
        DESCRICAO                  NVARCHAR(100)  NOT NULL,
        TIPO                       VARCHAR(15)    NOT NULL,
        CONTABIL                   BIT            NOT NULL CONSTRAINT DF_Centro_Custo_CONTABIL DEFAULT (1),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Centro_Custo_ATIVO    DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Centro_Custo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Centro_Custo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Centro_Custo              PRIMARY KEY CLUSTERED (ID_CENTRO_CUSTO),
        CONSTRAINT UQ_Centro_Custo_CODIGO       UNIQUE (CODIGO),
        CONSTRAINT FK_Centro_Custo_Empresa      FOREIGN KEY (ID_EMPRESA)               REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Centro_Custo_Conta_Padrao FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Centro_Custo_TIPO         CHECK (TIPO IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')),
        CONSTRAINT CK_Centro_Custo_CODIGO       CHECK (CODIGO <> '')
    );
END;
GO

IF COL_LENGTH(N'CAD.Centro_Custo', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Centro_Custo] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Centro_Custo', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Centro_Custo] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- v1.2: data de encerramento do centro (04e)
IF COL_LENGTH(N'CAD.Centro_Custo', N'DT_ENCERRAMENTO') IS NULL
    ALTER TABLE [CAD].[Centro_Custo] ADD DT_ENCERRAMENTO DATE NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Anexo_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Anexo_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tipos de anexo e extensões aceitas. Só insere o que falta
                (regra 39). LOGOMARCA: logomarca de cada obra (pedido do Celso,
                15/11/2026), anexada no cadastro da obra (etapa 03).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (25/11/2026) - Etapa 04e: CERTIDAO (certidões negativas, com validade).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Anexo_Tipo (CODIGO, NOME, EXTENSOES)
SELECT v.CODIGO, v.NOME, v.EXTENSOES
FROM (VALUES
        (CAST('CONTRATO' AS VARCHAR(30)), CAST(N'Contrato' AS NVARCHAR(60)), CAST('pdf,doc,docx,jpg,jpeg,png' AS VARCHAR(200))),
        ('NOTA_FISCAL',  N'Nota fiscal',                'pdf,xml,jpg,jpeg,png'),
        ('COMPROVANTE',  N'Comprovante de pagamento',   'pdf,jpg,jpeg,png'),
        ('ACORDO',       N'Acordo / renegociação',      'pdf,doc,docx,jpg,jpeg,png'),
        ('BOLETO',       N'Boleto',                     'pdf'),
        ('MEDICAO',      N'Boletim de medição',         'pdf,xlsx,xls,jpg,jpeg,png'),
        ('DOCUMENTO',    N'Documento pessoal / da empresa', 'pdf,jpg,jpeg,png'),
        ('CERTIDAO',     N'Certidão',                   'pdf,jpg,jpeg,png'),
        ('LOGOMARCA',    N'Logomarca',                  'png,jpg,jpeg,svg'),
        ('OUTRO',        N'Outro',                      'pdf,doc,docx,xls,xlsx,jpg,jpeg,png,txt,zip')
     ) v (CODIGO, NOME, EXTENSOES)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Anexo_Tipo t WHERE t.CODIGO = v.CODIGO);
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
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
    v2.1 (23/11/2026) - Etapa 04c (P22): NOVIDADES_AVISO_ATIVO,
                        NOVIDADES_VERSOES_MAX (3), VERSAO_AVISO_EMAIL_ATIVO e
                        VERSAO_AVISO_GRUPO.
    v2.2 (25/11/2026) - Etapa 04d (P12, P10): PARCEIRO_ROTULO, PARCEIRO_ROTULO_PLURAL,
                        CEP_CONSULTA_ATIVA, CEP_URL_PRINCIPAL, CEP_URL_RESERVA,
                        CEP_CACHE_DIAS, CNPJ_CONSULTA_ATIVA, CNPJ_URL,
                        CONSULTA_TEMPO_LIMITE_SEG e COBRANCA_APTO_EXIGE_*.
    v2.3 (25/11/2026) - Etapa 04e: CENTRO_ENCERRADO_BLOQUEIA (lançamento novo em
                        centro de custo encerrado: S = bloqueia, N = só avisa) e
                        SELETOR_LIMITE (máximo de linhas nas escolhas com busca).
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
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
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
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1),
        ('NOVIDADES_AVISO_ATIVO', N'S', 'SN',
         N'S = depois de cada atualização, cada usuário vê uma vez a janela "O que há de novo" com as notas da versão. N = não mostra (as notas continuam em Sistema › Versões).', 'SIS', 1),
        ('NOVIDADES_VERSOES_MAX', N'3', 'INTEIRO',
         N'Quantas versões, no máximo, a janela "O que há de novo" mostra de uma vez (as mais novas); as outras ficam em Sistema › Versões.', 'SIS', 1),
        ('VERSAO_AVISO_EMAIL_ATIVO', N'S', 'SN',
         N'S = cada atualização concluída manda a nota da versão por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO. N = não manda.', 'SIS', 1),
        ('VERSAO_AVISO_GRUPO', N'VERSAO_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe a nota da versão depois de cada atualização (tela Grupos de e-mail).', 'SIS', 1),
        ('PARCEIRO_ROTULO', N'Parceiro', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (singular). Ex.: Parceiro.', 'CAD', 0),
        ('PARCEIRO_ROTULO_PLURAL', N'Parceiros', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (plural). Ex.: Parceiros.', 'CAD', 0),
        ('CEP_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CEP, o servidor consulta o endereço na internet (ViaCEP; reserva BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CEP_URL_PRINCIPAL', N'https://viacep.com.br/ws/{cep}/json/', 'TEXTO',
         N'Endereço da consulta principal de CEP ({cep} = 8 dígitos). Formato de resposta do ViaCEP.', 'CAD', 0),
        ('CEP_URL_RESERVA', N'https://brasilapi.com.br/api/cep/v1/{cep}', 'TEXTO',
         N'Endereço da consulta de CEP usada quando a principal falha ({cep} = 8 dígitos). Formato da BrasilAPI. Vazio = sem reserva.', 'CAD', 0),
        ('CEP_CACHE_DIAS', N'180', 'INTEIRO',
         N'Dias que um endereço consultado fica guardado antes de consultar de novo na internet.', 'CAD', 1),
        ('CNPJ_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CNPJ, o servidor consulta razão social, nome fantasia, endereço e situação na Receita (BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CNPJ_URL', N'https://brasilapi.com.br/api/cnpj/v1/{cnpj}', 'TEXTO',
         N'Endereço da consulta de CNPJ ({cnpj} = 14 caracteres). Formato da BrasilAPI.', 'CAD', 0),
        ('CONSULTA_TEMPO_LIMITE_SEG', N'8', 'INTEIRO',
         N'Segundos de espera de cada consulta na internet (CEP, CNPJ) antes de desistir e deixar digitar à mão.', 'CAD', 0),
        ('COBRANCA_APTO_EXIGE_DOCUMENTO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CPF ou CNPJ válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_ENDERECO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CEP, logradouro, número, bairro, cidade e UF.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_EMAIL', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige e-mail principal (ou de cobrança) válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_TELEFONE', N'N', 'SN',
         N'Cadastro apto para cobrança (boleto): exige celular ou telefone.', 'CAD', 1),
        ('CENTRO_ENCERRADO_BLOQUEIA', N'S', 'SN',
         N'Lançamento novo com data depois do encerramento do centro de custo (obra entregue): S = bloqueia; N = só avisa.', 'CAD', 1),
        ('SELETOR_LIMITE', N'50', 'INTEIRO',
         N'Máximo de linhas mostradas nas escolhas com busca (conta do plano, centro de custo, conta bancária).', 'CAD', 0)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Centros de custo" (e escolha do centro nos lançamentos).
                @IdEmpresa NULL = todas. CONTA_EFETIVA: a conta do centro ou, se vazia,
                a da empresa. Permissão: VER em CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04e: DT_ENCERRAMENTO e ENCERRADO; quem vê
                        empresas também vê os centros (aba da ficha da empresa).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(cc.ID_CONTA_BANCARIA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_CONTA_EFETIVA,
               ISNULL(c.DESCRICAO, ISNULL(ce.DESCRICAO, N'')) AS CONTA_EFETIVA_DESCRICAO,
               cc.DT_ENCERRAMENTO,
               CAST(CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS ENCERRADO,
               cc.ATIVO, cc.CODIGO_ACCESS, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR cc.ATIVO = 1)
          AND cc.DT_EXCLUSAO IS NULL
        ORDER BY cc.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os centros de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de um centro de custo (tela CAD_CENTRO_CUSTO): todos os
                campos, empresa, conta padrão (a própria ou, se vazia, a da
                empresa), data de encerramento, quantos lançamentos usam o centro
                (QTD_LANCAMENTOS: com lançamento, a empresa não muda) e NA_LIXEIRA.
                Permissão: VER em CAD_CENTRO_CUSTO. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Obter @IdUsuario = 2, @IdCentroCusto = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Obter]
    @IdUsuario      INT,
    @IdCentroCusto  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WITH (NOLOCK) WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto)
            THROW 50001, N'Centro de custo não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(ce.DESCRICAO, N'') AS CONTA_PADRAO_EMPRESA_DESCRICAO,
               cc.DT_ENCERRAMENTO,
               CAST(CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS ENCERRADO,
               (SELECT COUNT(*) FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_CENTRO_CUSTO = cc.ID_CENTRO_CUSTO) AS QTD_LANCAMENTOS,
               cc.ATIVO, CAST(CASE WHEN cc.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               cc.CODIGO_ACCESS, cc.DT_CRIACAO, cc.USUARIO_CRIACAO, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o centro de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdCentroCusto NULL) ou altera um centro de custo. Código
                curto, único, em maiúsculas (letras, números, "_" e "-"). Empresa e
                conta padrão têm de estar ativas (conta vazia = vale a da empresa).
                Permissão: INCLUIR ou ALTERAR em CAD_CENTRO_CUSTO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04e: @DtEncerramento (só grava com
                        @MexerEncerramento = 1; sem ele, não mexe); conta padrão
                        precisa ser da mesma empresa; centro com lançamento não
                        muda de empresa.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Codigo = 'ESC', @Descricao = N'Escritório', @Tipo = 'ADMINISTRATIVO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Gravar]
    @IdUsuario              INT,
    @IdCentroCusto          INT           = NULL,
    @IdEmpresa              INT,
    @Codigo                 VARCHAR(20),
    @Descricao              NVARCHAR(100),
    @Tipo                   VARCHAR(15),
    @Contabil               BIT           = 1,
    @IdContaBancariaPadrao  INT           = NULL,
    @DtEncerramento         DATE          = NULL,
    @MexerEncerramento      BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Contabil  = ISNULL(@Contabil, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', CASE WHEN @IdCentroCusto IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar centros de custo.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Centro_Custo', @IdCentroCusto) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'Centro de custo não encontrado.';
        IF @Recusa = N'' AND (@Codigo = '' OR REPLACE(REPLACE(@Codigo, '_', ''), '-', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números, "_" ou "-" (ex.: 62 ou ESC).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição do centro de custo.';
        IF @Recusa = N'' AND @Tipo NOT IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')
            SET @Recusa = N'Tipo inválido: obra, administrativo, imóvel próprio ou particular.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.CODIGO = @Codigo AND cc.ID_CENTRO_CUSTO <> ISNULL(@IdCentroCusto, 0))
            SET @Recusa = N'Já existe um centro de custo com este código.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'A conta padrão precisa ser uma conta da mesma empresa do centro de custo.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto AND cc.ID_EMPRESA <> @IdEmpresa)
           AND EXISTS (SELECT 1 FROM FIN.Lancamento l WHERE l.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'O centro de custo já tem lançamentos: não pode mudar de empresa.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdCentroCusto IS NULL
        BEGIN
            INSERT INTO CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ID_CONTA_BANCARIA_PADRAO, DT_ENCERRAMENTO, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Codigo, @Descricao, @Tipo, @Contabil, @IdContaBancariaPadrao, CASE WHEN @MexerEncerramento = 1 THEN @DtEncerramento END, @Usuario);
            SET @IdCentroCusto = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE cc
               SET cc.ID_EMPRESA = @IdEmpresa, cc.CODIGO = @Codigo, cc.DESCRICAO = @Descricao, cc.TIPO = @Tipo, cc.CONTABIL = @Contabil,
                   cc.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   cc.DT_ENCERRAMENTO = CASE WHEN ISNULL(@MexerEncerramento, 0) = 1 THEN @DtEncerramento ELSE cc.DT_ENCERRAMENTO END,
                   cc.DT_ALTERACAO = SYSDATETIME(), cc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Centro_Custo cc
            WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Centro de custo gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o centro de custo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Seletor_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Seletor_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Fonte única das escolhas com busca (componente js/seletor.js) de
                conta do plano (@Tipo = 'PLANO'), centro de custo ('CENTRO') e
                conta bancária ('CONTA'). Só registros ativos e fora da lixeira;
                a busca olha código/número e descrição (sem acento, qualquer parte)
                e, no plano, também o grupo e o subgrupo. @IdEmpresa filtra centros
                e contas; @IdAtual sempre volta (mesmo inativo), para a ficha mostrar
                o valor já gravado. No máximo SELETOR_LIMITE linhas.
                Permissão: VER em qualquer tela que usa essas escolhas (cadastros
                de parceiro, empresa, centro, plano, conta; o FIN entra na 04f).
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e, seletor com busca aprovado pelo Celso).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Seletor_Listar @IdUsuario = 2, @Tipo = 'PLANO', @Busca = N'cimento';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Seletor_Listar]
    @IdUsuario  INT,
    @Tipo       VARCHAR(10),
    @Busca      NVARCHAR(100) = NULL,
    @IdEmpresa  INT           = NULL,
    @IdAtual    INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Seletor_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Limite     INT;
    DECLARE @Termo      NVARCHAR(102);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estas escolhas.', 1;
        SET @Tipo = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        IF @Tipo NOT IN ('PLANO', 'CENTRO', 'CONTA')
            THROW 50001, N'Escolha inválida.', 1;

        SET @Limite = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SELETOR_LIMITE'), 50);
        IF @Limite NOT BETWEEN 10 AND 500 SET @Limite = 50;
        SET @Busca = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Termo = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

        SET @EtapaAtual = 'Consulta';
        IF @Tipo = 'PLANO'
            SELECT TOP (@Limite) v.ID, v.CODIGO, v.DESCRICAO, v.COMPLEMENTO, v.ATIVO
            FROM (SELECT pc.ID_PLANO_CONTA AS ID,
                         RIGHT('0' + CAST(g.NUMERO AS VARCHAR(2)), 2) + '.' + RIGHT('0' + CAST(s.NUMERO AS VARCHAR(2)), 2) + '.' + RIGHT('00' + CAST(pc.NUMERO AS VARCHAR(3)), 3) AS CODIGO,
                         pc.DESCRICAO, g.DESCRICAO + N' › ' + s.DESCRICAO AS COMPLEMENTO,
                         CAST(CASE WHEN pc.ATIVO = 1 AND s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT) AS ATIVO,
                         g.ORDEM AS O1, g.NUMERO AS O2, s.NUMERO AS O3, pc.NUMERO AS O4
                  FROM CAD.Plano_Conta pc WITH (NOLOCK)
                  INNER JOIN CAD.Plano_Subgrupo s WITH (NOLOCK) ON s.ID_PLANO_SUBGRUPO = pc.ID_PLANO_SUBGRUPO
                  INNER JOIN CAD.Plano_Grupo g    WITH (NOLOCK) ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO
                  WHERE pc.DT_EXCLUSAO IS NULL
                    AND (pc.ID_PLANO_CONTA = @IdAtual
                         OR (pc.ATIVO = 1 AND s.ATIVO = 1 AND g.ATIVO = 1
                             AND (@Busca = N'' OR pc.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR s.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR g.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR RIGHT('0' + CAST(g.NUMERO AS VARCHAR(2)), 2) + '.' + RIGHT('0' + CAST(s.NUMERO AS VARCHAR(2)), 2) + '.' + RIGHT('00' + CAST(pc.NUMERO AS VARCHAR(3)), 3) LIKE @Busca + '%')))
                 ) v
            ORDER BY CASE WHEN v.ID = @IdAtual THEN 0 ELSE 1 END, v.O1, v.O2, v.O3, v.O4;
        ELSE IF @Tipo = 'CENTRO'
            SELECT TOP (@Limite) cc.ID_CENTRO_CUSTO AS ID, cc.CODIGO, cc.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN N' · encerrado em ' + CONVERT(NVARCHAR(10), cc.DT_ENCERRAMENTO, 103) ELSE N'' END AS COMPLEMENTO,
                   cc.ATIVO
            FROM CAD.Centro_Custo cc WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
            WHERE cc.DT_EXCLUSAO IS NULL
              AND (cc.ID_CENTRO_CUSTO = @IdAtual
                   OR (cc.ATIVO = 1 AND (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR cc.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR cc.CODIGO LIKE @Busca + '%')))
            ORDER BY CASE WHEN cc.ID_CENTRO_CUSTO = @IdAtual THEN 0 ELSE 1 END, cc.CODIGO;
        ELSE
            SELECT TOP (@Limite) c.ID_CONTA AS ID, CAST(c.ID_CONTA AS VARCHAR(20)) AS CODIGO, c.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN c.NUMERO <> '' THEN N' · ag. ' + c.AGENCIA + N' c/c ' + c.NUMERO + CASE WHEN c.NUMERO_DV <> '' THEN N'-' + c.NUMERO_DV ELSE N'' END ELSE N'' END AS COMPLEMENTO,
                   c.ATIVO
            FROM BANCO.Conta c WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
            WHERE c.DT_EXCLUSAO IS NULL
              AND (c.ID_CONTA = @IdAtual
                   OR (c.ATIVO = 1 AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR c.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR c.NUMERO LIKE @Busca + '%')))
            ORDER BY CASE WHEN c.ID_CONTA = @IdAtual THEN 0 ELSE 1 END, e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Empresas" (e escolha da empresa nos outros cadastros): todas as
                colunas, CNPJ formatado e a conta padrão.
                Permissão: VER em CAD_EMPRESA, CAD_CENTRO_CUSTO ou BANCO_CONTA.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - Colunas CNPJ_COMPRAS e CNPJ_COMPRAS_FORMATADO, etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.
    v1.3 (25/11/2026) - Etapa 04e: colunas QTD_CONTAS e QTD_CENTROS.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.CNPJ_COMPRAS, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_COMPRAS_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               (SELECT COUNT(*) FROM BANCO.Conta x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CONTAS,
               (SELECT COUNT(*) FROM CAD.Centro_Custo x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CENTROS,
               e.ATIVO, e.CODIGO_ACCESS, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR e.ATIVO = 1)
          AND e.DT_EXCLUSAO IS NULL
        ORDER BY e.RAZAO_SOCIAL;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as empresas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de uma empresa (tela CAD_EMPRESA): todos os campos, o
                rodapé dos e-mails (P11), a pasta do OFX (PODE_PASTA_OFX = 1 só
                para administrador), a conta padrão, quantas contas e centros de
                custo ativos ela tem e NA_LIXEIRA (ficha só para consulta).
                Permissão: VER em CAD_EMPRESA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Obter @IdUsuario = 2, @IdEmpresa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Obter]
    @IdUsuario  INT,
    @IdEmpresa  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Empresa e WITH (NOLOCK) WHERE e.ID_EMPRESA = @IdEmpresa)
            THROW 50001, N'Empresa não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.CNPJ_COMPRAS, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_COMPRAS_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.RODAPE_EMAIL,
               CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) >= 1 THEN e.PASTA_OFX ELSE N'' END AS PASTA_OFX,
               CAST(CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) >= 1 THEN 1 ELSE 0 END AS BIT) AS PODE_PASTA_OFX,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               (SELECT COUNT(*) FROM BANCO.Conta x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CONTAS,
               (SELECT COUNT(*) FROM CAD.Centro_Custo x WITH (NOLOCK) WHERE x.ID_EMPRESA = e.ID_EMPRESA AND x.ATIVO = 1 AND x.DT_EXCLUSAO IS NULL) AS QTD_CENTROS,
               e.ATIVO, CAST(CASE WHEN e.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               e.CODIGO_ACCESS, e.DT_CRIACAO, e.USUARIO_CRIACAO, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE e.ID_EMPRESA = @IdEmpresa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a empresa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdEmpresa NULL) ou altera uma empresa do grupo. Pela tela o
                CNPJ é obrigatório e conferido (dígitos verificadores, aceita o
                alfanumérico); não pode repetir. CEP com 8 dígitos, UF com 2 letras,
                e-mail válido. Conta padrão: qualquer conta ativa (escolha no cadastro,
                decisão do Celso).
                CNPJ para notas de compra e DDA (@CnpjCompras): opcional; NULL
                mantém o que está gravado (na inclusão, fica vazio); '' apaga.
                Permissão: INCLUIR ou ALTERAR em CAD_EMPRESA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - @CnpjCompras (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.
    v1.3 (25/11/2026) - Etapa 04e: @RodapeEmail (P11) e @PastaOfx (só
                        administrador); NULL nos dois = não mexe. Conta padrão
                        precisa ser da própria empresa.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Gravar @IdUsuario = 2, @RazaoSocial = N'Construtora Teste Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'CONSTRUTORA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Gravar]
    @IdUsuario               INT,
    @IdEmpresa               INT           = NULL,
    @RazaoSocial             NVARCHAR(150),
    @NomeFantasia            NVARCHAR(100) = NULL,
    @Cnpj                    VARCHAR(20),
    @Tipo                    VARCHAR(12)   = 'OUTRA',
    @InscricaoEstadual       VARCHAR(20)   = NULL,
    @InscricaoMunicipal      VARCHAR(20)   = NULL,
    @RegimeTributario        VARCHAR(20)   = NULL,
    @Cep                     VARCHAR(10)   = NULL,
    @Logradouro              NVARCHAR(150) = NULL,
    @Numero                  NVARCHAR(20)  = NULL,
    @Complemento             NVARCHAR(60)  = NULL,
    @Bairro                  NVARCHAR(60)  = NULL,
    @Cidade                  NVARCHAR(60)  = NULL,
    @Uf                      CHAR(2)       = NULL,
    @Email                   NVARCHAR(256) = NULL,
    @Telefone                VARCHAR(30)   = NULL,
    @IdContaBancariaPadrao   INT           = NULL,
    @CnpjCompras             VARCHAR(20)   = NULL,
    @RodapeEmail             NVARCHAR(1000) = NULL,
    @PastaOfx                NVARCHAR(260) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @RazaoSocial        = LTRIM(RTRIM(ISNULL(@RazaoSocial, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @Cnpj               = CAD.fn_CAD_Documento_Limpo(@Cnpj);
        SET @Tipo               = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, 'OUTRA'))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @RegimeTributario   = UPPER(LTRIM(RTRIM(ISNULL(@RegimeTributario, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Email              = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Telefone           = CAD.fn_CAD_Somente_Digitos(@Telefone);
        IF @CnpjCompras IS NOT NULL SET @CnpjCompras = CAD.fn_CAD_Documento_Limpo(@CnpjCompras);
        IF @RodapeEmail IS NOT NULL SET @RodapeEmail = LTRIM(RTRIM(@RodapeEmail));
        IF @PastaOfx IS NOT NULL SET @PastaOfx = LTRIM(RTRIM(@PastaOfx));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', CASE WHEN @IdEmpresa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar empresas.';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Empresa', @IdEmpresa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'Empresa não encontrada.';
        IF @Recusa = N'' AND @RazaoSocial = N''
            SET @Recusa = N'Informe a razão social.';
        IF @Recusa = N'' AND (LEN(@Cnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@Cnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CNPJ = @Cnpj AND e.ID_EMPRESA <> ISNULL(@IdEmpresa, 0))
            SET @Recusa = N'Já existe uma empresa cadastrada com este CNPJ.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND (LEN(@CnpjCompras) <> 14 OR CAD.fn_CAD_Documento_Valido(@CnpjCompras) = 0)
            SET @Recusa = N'CNPJ para notas de compra e DDA inválido. Confira os números.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND @CnpjCompras = @Cnpj
            SET @Recusa = N'O CNPJ para notas de compra e DDA é igual ao CNPJ da empresa: deixe em branco.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')
            SET @Recusa = N'Tipo de empresa inválido.';
        IF @Recusa = N'' AND @RegimeTributario NOT IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')
            SET @Recusa = N'Regime tributário inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @Email <> N'' AND SIS.fn_SIS_Email_Valido(@Email) = 0
            SET @Recusa = N'E-mail inválido.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL AND @IdEmpresa IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'A conta padrão precisa ser uma conta desta empresa.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL AND @IdEmpresa IS NULL
            SET @Recusa = N'Grave a empresa primeiro; a conta padrão é escolhida depois de cadastrar as contas dela.';
        IF @Recusa = N'' AND @PastaOfx IS NOT NULL AND SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1
            SET @PastaOfx = NULL; -- só o administrador mexe na pasta do OFX: dos demais, ignora
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdEmpresa IS NULL
        BEGIN
            INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL, REGIME_TRIBUTARIO,
                                     CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, EMAIL, TELEFONE, ID_CONTA_BANCARIA_PADRAO,
                                     RODAPE_EMAIL, PASTA_OFX, USUARIO_CRIACAO)
            VALUES (@RazaoSocial, @NomeFantasia, @Cnpj, ISNULL(@CnpjCompras, ''), @Tipo, @InscricaoEstadual, @InscricaoMunicipal, @RegimeTributario,
                    @Cep, @Logradouro, @Numero, @Complemento, @Bairro, @Cidade, @Uf, @Email, @Telefone, @IdContaBancariaPadrao,
                    ISNULL(@RodapeEmail, N''), ISNULL(@PastaOfx, N''), @Usuario);
            SET @IdEmpresa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE e
               SET e.RAZAO_SOCIAL = @RazaoSocial, e.NOME_FANTASIA = @NomeFantasia, e.CNPJ = @Cnpj, e.CNPJ_COMPRAS = ISNULL(@CnpjCompras, e.CNPJ_COMPRAS), e.TIPO = @Tipo,
                   e.INSCRICAO_ESTADUAL = @InscricaoEstadual, e.INSCRICAO_MUNICIPAL = @InscricaoMunicipal, e.REGIME_TRIBUTARIO = @RegimeTributario,
                   e.CEP = @Cep, e.LOGRADOURO = @Logradouro, e.NUMERO = @Numero, e.COMPLEMENTO = @Complemento, e.BAIRRO = @Bairro,
                   e.CIDADE = @Cidade, e.UF = @Uf, e.EMAIL = @Email, e.TELEFONE = @Telefone, e.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   e.RODAPE_EMAIL = ISNULL(@RodapeEmail, e.RODAPE_EMAIL), e.PASTA_OFX = ISNULL(@PastaOfx, e.PASTA_OFX),
                   e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Empresa e
            WHERE e.ID_EMPRESA = @IdEmpresa;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Empresa gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a empresa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa (tela Contas bancárias e escolha da conta padrão da
                empresa e do centro de custo). @IdEmpresa NULL = todas.
                Permissão: VER em BANCO_CONTA, CAD_EMPRESA ou CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04e: coluna PADRAO_DA_EMPRESA.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as contas bancárias.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               c.DESCRICAO, c.TIPO, c.ID_BANCO, ISNULL(b.CODIGO, '') AS BANCO_CODIGO, ISNULL(b.NOME, N'') AS BANCO_NOME,
               c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, c.LIMITE_CREDITO, c.SALDO_INICIAL, c.DT_SALDO_INICIAL,
               c.CONCILIA, c.MOSTRA_SALDO, c.CONTA_CONTABIL_REF, c.ORDEM, c.ATIVO, c.CODIGO_ACCESS,
               CAST(CASE WHEN e.ID_CONTA_BANCARIA_PADRAO = c.ID_CONTA THEN 1 ELSE 0 END AS BIT) AS PADRAO_DA_EMPRESA,
               c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        WHERE (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR c.ATIVO = 1)
          AND c.DT_EXCLUSAO IS NULL
        ORDER BY e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as contas bancárias. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de uma conta bancária, caixa ou conta de permuta (tela
                BANCO_CONTA): todos os campos, empresa e banco, se é a conta
                padrão da empresa, TEM_MOVIMENTO (já há movimento ou baixa: a
                tela trava empresa, tipo e saldo inicial) e NA_LIXEIRA.
                Permissão: VER em BANCO_CONTA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Obter @IdUsuario = 2, @IdConta = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Obter]
    @IdUsuario  INT,
    @IdConta    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as contas bancárias.', 1;
        IF NOT EXISTS (SELECT 1 FROM BANCO.Conta c WITH (NOLOCK) WHERE c.ID_CONTA = @IdConta)
            THROW 50001, N'Conta não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               c.DESCRICAO, c.TIPO, c.ID_BANCO, ISNULL(b.CODIGO, '') AS BANCO_CODIGO, ISNULL(b.NOME, N'') AS BANCO_NOME,
               c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, c.LIMITE_CREDITO, c.SALDO_INICIAL, c.DT_SALDO_INICIAL,
               c.CONCILIA, c.MOSTRA_SALDO, c.CONTA_CONTABIL_REF, c.ORDEM,
               CAST(CASE WHEN e.ID_CONTA_BANCARIA_PADRAO = c.ID_CONTA THEN 1 ELSE 0 END AS BIT) AS PADRAO_DA_EMPRESA,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM BANCO.Movimento m WITH (NOLOCK) WHERE m.ID_CONTA = c.ID_CONTA)
                           OR EXISTS (SELECT 1 FROM FIN.Baixa x WITH (NOLOCK) WHERE x.ID_CONTA = c.ID_CONTA)
                         THEN 1 ELSE 0 END AS BIT) AS TEM_MOVIMENTO,
               c.ATIVO, CAST(CASE WHEN c.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               c.CODIGO_ACCESS, c.DT_CRIACAO, c.USUARIO_CRIACAO, c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        WHERE c.ID_CONTA = @IdConta;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a conta. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdConta NULL) ou altera uma conta da empresa. Conta de banco
                (corrente, poupança, aplicação) exige banco, agência e número; caixa e
                permuta não usam banco. Descrição única dentro da empresa. Saldo
                inicial diferente de zero exige a data.
                Permissão: INCLUIR ou ALTERAR em BANCO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04e: conta com movimento ou baixa não muda de
                        empresa nem de tipo, e o saldo inicial (valor e data)
                        fica travado; saldo inicial também não muda quando a data
                        (atual ou nova) cai em mês fechado da empresa.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Descricao = N'Caixa Construtora', @Tipo = 'CAIXA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Gravar]
    @IdUsuario         INT,
    @IdConta           INT           = NULL,
    @IdEmpresa         INT,
    @Descricao         NVARCHAR(60),
    @Tipo              VARCHAR(10),
    @IdBanco           INT           = NULL,
    @Agencia           VARCHAR(10)   = NULL,
    @AgenciaDv         VARCHAR(2)    = NULL,
    @Numero            VARCHAR(20)   = NULL,
    @NumeroDv          VARCHAR(2)    = NULL,
    @LimiteCredito     DECIMAL(18,2) = 0,
    @SaldoInicial      DECIMAL(18,2) = 0,
    @DtSaldoInicial    DATE          = NULL,
    @Concilia          BIT           = 0,
    @MostraSaldo       BIT           = 1,
    @ContaContabilRef  VARCHAR(30)   = NULL,
    @Ordem             SMALLINT      = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao        = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo             = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Agencia          = CAD.fn_CAD_Somente_Digitos(@Agencia);
        SET @AgenciaDv        = UPPER(LTRIM(RTRIM(ISNULL(@AgenciaDv, ''))));
        SET @Numero           = CAD.fn_CAD_Somente_Digitos(@Numero);
        SET @NumeroDv         = UPPER(LTRIM(RTRIM(ISNULL(@NumeroDv, ''))));
        SET @LimiteCredito    = ISNULL(@LimiteCredito, 0);
        SET @SaldoInicial     = ISNULL(@SaldoInicial, 0);
        SET @Concilia         = ISNULL(@Concilia, 0);
        SET @MostraSaldo      = ISNULL(@MostraSaldo, 1);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));
        SET @Ordem            = ISNULL(@Ordem, 0);
        IF @Tipo IN ('CAIXA', 'PERMUTA')
            SELECT @IdBanco = NULL, @Agencia = '', @AgenciaDv = '', @Numero = '', @NumeroDv = '';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', CASE WHEN @IdConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar contas bancárias.';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'BANCO.Conta', @IdConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta)
            SET @Recusa = N'Conta não encontrada.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa como titular da conta.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição da conta (ex.: Sicredi Orion).';
        IF @Recusa = N'' AND @Tipo NOT IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')
            SET @Recusa = N'Tipo de conta inválido.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA')
           AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco AND b.ATIVO = 1)
            SET @Recusa = N'Escolha o banco da conta.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA') AND (@Agencia = '' OR @Numero = '')
            SET @Recusa = N'Informe a agência e o número da conta.';
        IF @Recusa = N'' AND @SaldoInicial <> 0 AND @DtSaldoInicial IS NULL
            SET @Recusa = N'Informe a data do saldo inicial.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.DESCRICAO = @Descricao AND c.ID_CONTA <> ISNULL(@IdConta, 0))
            SET @Recusa = N'Esta empresa já tem uma conta com esta descrição.';
        IF @Recusa = N'' AND @IdConta IS NOT NULL
        BEGIN
            DECLARE @EmpresaAtual INT, @TipoAtual VARCHAR(10), @SaldoAtual DECIMAL(18,2), @DtSaldoAtual DATE, @TemMovimento BIT = 0;
            SELECT @EmpresaAtual = c.ID_EMPRESA, @TipoAtual = c.TIPO, @SaldoAtual = c.SALDO_INICIAL, @DtSaldoAtual = c.DT_SALDO_INICIAL
            FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;
            IF EXISTS (SELECT 1 FROM BANCO.Movimento m WHERE m.ID_CONTA = @IdConta)
               OR EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_CONTA = @IdConta)
                SET @TemMovimento = 1;
            IF @TemMovimento = 1 AND @EmpresaAtual <> @IdEmpresa
                SET @Recusa = N'A conta já tem movimento: não pode mudar de empresa. Desative-a e crie uma conta nova na outra empresa.';
            ELSE IF @TemMovimento = 1 AND @TipoAtual <> @Tipo
                SET @Recusa = N'A conta já tem movimento: o tipo não pode mudar.';
            ELSE IF @TemMovimento = 1 AND (@SaldoAtual <> @SaldoInicial OR ISNULL(@DtSaldoAtual, '19000101') <> ISNULL(@DtSaldoInicial, '19000101'))
                SET @Recusa = N'A conta já tem movimento: o saldo inicial não pode mudar. Para acertar o saldo, faça um lançamento de ajuste.';
            ELSE IF (@SaldoAtual <> @SaldoInicial OR ISNULL(@DtSaldoAtual, '19000101') <> ISNULL(@DtSaldoInicial, '19000101'))
                 AND EXISTS (SELECT 1 FROM FIN.Mes_Fechado f
                             WHERE f.ID_EMPRESA = @EmpresaAtual AND f.FECHADO = 1
                               AND f.MES IN (DATEFROMPARTS(YEAR(@DtSaldoAtual), MONTH(@DtSaldoAtual), 1),
                                             DATEFROMPARTS(YEAR(@DtSaldoInicial), MONTH(@DtSaldoInicial), 1)))
                SET @Recusa = N'O saldo inicial cai num mês fechado: não pode mudar.';
        END;
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdConta IS NULL
        BEGIN
            INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, NUMERO, NUMERO_DV, LIMITE_CREDITO,
                                     SALDO_INICIAL, DT_SALDO_INICIAL, CONCILIA, MOSTRA_SALDO, CONTA_CONTABIL_REF, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Descricao, @Tipo, @IdBanco, @Agencia, @AgenciaDv, @Numero, @NumeroDv, @LimiteCredito,
                    @SaldoInicial, @DtSaldoInicial, @Concilia, @MostraSaldo, @ContaContabilRef, @Ordem, @Usuario);
            SET @IdConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_EMPRESA = @IdEmpresa, c.DESCRICAO = @Descricao, c.TIPO = @Tipo, c.ID_BANCO = @IdBanco,
                   c.AGENCIA = @Agencia, c.AGENCIA_DV = @AgenciaDv, c.NUMERO = @Numero, c.NUMERO_DV = @NumeroDv,
                   c.LIMITE_CREDITO = @LimiteCredito, c.SALDO_INICIAL = @SaldoInicial, c.DT_SALDO_INICIAL = @DtSaldoInicial,
                   c.CONCILIA = @Concilia, c.MOSTRA_SALDO = @MostraSaldo, c.CONTA_CONTABIL_REF = @ContaContabilRef, c.ORDEM = @Ordem,
                   c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Conta c
            WHERE c.ID_CONTA = @IdConta;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Conta gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a conta. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do CAD e do BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas 11 tabelas da etapa 03a, gerando cada
                trigger com SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas. No MASTER
                fica na parte 8 (triggers).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Banco',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Conta',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Centro_Custo',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa',                @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Contato',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Vinculo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Dado_Bancario',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Tipo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Parceiro_Tipo',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

PRINT N'Pacote 04e concluído sem erro.';
GO

SET NOEXEC OFF;
GO
