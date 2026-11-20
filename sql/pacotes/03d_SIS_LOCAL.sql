/*******************************************************************************
  Pacote      : 03d - ajustes da base SIS na etapa 03d (rodapé dos e-mails sem CNPJ, limite de login por computador, versão do banco)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 20/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 03c2b já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : enviar um comunicado de teste e conferir o rodapé sem CNPJ.
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
                técnicos (razão social, CNPJ se EMAIL_RODAPE_CNPJ = S, e aviso
                de não responder).
                Logomarca: <img src="cid:logo_empresa">; o serviço embute o
                arquivo do parâmetro EMPRESA_LOGO_EMAIL com esse CID sempre
                que o corpo citar "cid:logo_empresa".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (17/11/2026) - Nome do sistema no rodapé pelo parâmetro SISTEMA_NOME.
    v1.2 (17/11/2026) - Logomarca conforme EMAIL_LOGO_MODO: EMBUTIDA (cid,
                        anexada pelo serviço), ENDERECO (EMAIL_LOGO_ENDERECO)
                        ou SEM_IMAGEM.
    v1.3 (20/11/2026) - CNPJ no rodapé do e-mail externo só se o parâmetro
                        EMAIL_RODAPE_CNPJ = S (pedido do Celso: tirar o CNPJ
                        do boletim; fábrica = N).

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
    DECLARE @Modo   VARCHAR(20)   = UPPER(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOGO_MODO'), N'EMBUTIDA'));
    DECLARE @Url    NVARCHAR(500) = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOGO_ENDERECO'), N'')));
    DECLARE @Logo   NVARCHAR(MAX);
    DECLARE @Sistema NVARCHAR(400) = SIS.fn_SIS_Texto_HTML(ISNULL(NULLIF(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''), N'SistemaCMJ'));

    SET @Cor = CASE @Sev WHEN 'ALERTA'  THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_ALERTA')
                         WHEN 'SUCESSO' THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_SUCESSO')
                         ELSE SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL') END;
    SET @Cor = ISNULL(NULLIF(@Cor, ''), '#333333');
    IF @Sev = 'ALERTA' SET @Titul = N'ALERTA - ' + @Titul;

    IF ISNULL(@Externo, 0) = 1
        SET @Rodape = N'<div style="font-weight:bold;">' + @Razao + N'</div>'
                    + CASE WHEN SIS.fn_SIS_Parametro_SN('EMAIL_RODAPE_CNPJ') = 1
                           THEN N'<div>CNPJ ' + ISNULL(SIS.fn_SIS_Mascarar_CPF_CNPJ(SIS.fn_SIS_Empresa_CNPJ(), 0), N'') + N'</div>' ELSE N'' END
                    + N'<div style="margin-top:6px;">Este e-mail foi enviado automaticamente. Por favor, não responda.</div>';
    ELSE
        SET @Rodape = N'<div>Gerado automaticamente pelo sistema ' + @Sistema + N': ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Rotina, N'')) + N'</div>'
                    + N'<div>Emitido em: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(CAST(SYSDATETIME() AS DATETIME2(0))), N'') + N'</div>'
                    + CASE WHEN ISNULL(@Grupo, '') <> '' THEN N'<div>Grupo de Destinatários: ' + SIS.fn_SIS_Texto_HTML(@Grupo) + N'</div>' ELSE N'' END
                    + N'<div style="margin-top:6px;font-weight:bold;">' + @Razao + N'</div>';

    SET @Logo = CASE WHEN @Modo = 'SEM_IMAGEM' THEN N''
                     WHEN @Modo = 'ENDERECO' AND @Url LIKE N'https://%' AND @Url NOT LIKE N'%"%'
                          THEN N'<div style="padding:16px 20px;"><img src="' + @Url + N'" alt="' + @Razao + N'" style="max-height:60px;"></div>'
                     ELSE N'<div style="padding:16px 20px;"><img src="cid:logo_empresa" alt="' + @Razao + N'" style="max-height:60px;"></div>' END;

    RETURN N'<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
         + N'<body style="margin:0;padding:20px;background:#eeeeee;font-family:Arial,''Segoe UI'',sans-serif;color:#333333;">'
         + N'<div style="max-width:700px;margin:0 auto;background:#ffffff;box-shadow:0 1px 4px rgba(0,0,0,0.15);">'
         + @Logo
         + N'<div style="background:' + @Cor + N';color:#ffffff;font-weight:bold;padding:12px 20px;font-size:15px;">' + @Titul + N'</div>'
         + N'<div style="padding:20px;font-size:14px;line-height:1.5;">' + ISNULL(@Conteudo, N'') + N'</div>'
         + N'<div style="background:#f9f9f9;padding:12px 20px;font-size:11px;color:#777777;border-top:1px solid #eeeeee;">' + @Rodape + N'</div>'
         + N'</div></body></html>';
END;
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
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Login_Log.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Login_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Toda tentativa de login, certa ou errada (seção 3.6).
                RESULTADO: OK, SENHA_ERRADA, BLOQUEOU (errou e foi bloqueado
                nesta tentativa), BLOQUEADO (já estava), INATIVO, SEM_SENHA,
                INEXISTENTE, ESTACAO_BLOQUEADA (o computador errou demais
                em pouco tempo e está em espera). LOGIN_INFORMADO guarda o que foi digitado
                (para ver tentativas com nomes que não existem).
                Nunca é apagado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: resultado ESTACAO_BLOQUEADA (limite de
                        tentativas por computador) e índice por IP e data.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Login_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Login_Log]
    (
        ID_LOGIN_LOG     BIGINT          IDENTITY(1,1) NOT NULL,
        LOGIN_INFORMADO  NVARCHAR(100)   NOT NULL CONSTRAINT DF_Login_Log_LOGIN_INFORMADO DEFAULT (N''),
        ID_USUARIO       INT             NULL,
        RESULTADO        VARCHAR(20)     NOT NULL,
        IP               VARCHAR(45)     NOT NULL CONSTRAINT DF_Login_Log_IP              DEFAULT (''),
        ESTACAO          NVARCHAR(128)   NOT NULL CONSTRAINT DF_Login_Log_ESTACAO         DEFAULT (N''),
        DT_TENTATIVA     DATETIME2(0)    NOT NULL CONSTRAINT DF_Login_Log_DT_TENTATIVA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Login_Log           PRIMARY KEY CLUSTERED (ID_LOGIN_LOG),
        CONSTRAINT FK_Login_Log_Usuario   FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Login_Log_RESULTADO CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_DT_TENTATIVA')
    CREATE NONCLUSTERED INDEX IX_Login_Log_DT_TENTATIVA ON [SIS].[Login_Log] (DT_TENTATIVA) INCLUDE (ID_USUARIO, RESULTADO);
GO

-- v1.1: novo resultado ESTACAO_BLOQUEADA (troca a restrição só se ainda não aceita)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c
               WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]')
                 AND c.definition LIKE N'%ESTACAO_BLOQUEADA%')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]'))
        ALTER TABLE [SIS].[Login_Log] DROP CONSTRAINT CK_Login_Log_RESULTADO;
    ALTER TABLE [SIS].[Login_Log] ADD CONSTRAINT CK_Login_Log_RESULTADO
        CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA'));
END;
GO

-- v1.1: contagem de tentativas erradas por computador (SIS_Usuario_Login_Processar)
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_IP_DT')
    CREATE NONCLUSTERED INDEX IX_Login_Log_IP_DT ON [SIS].[Login_Log] (IP, DT_TENTATIVA) INCLUDE (RESULTADO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Login_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Login_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 2º passo do login (uso exclusivo da API). A API informa se a
                senha conferiu (@SenhaConferida) e, se conferiu, o SHA-256 do
                token de sessão que vai no cookie (@TokenHash, 32 bytes).
                Regras:
                  - login inexistente/interno ou inativo: recusa genérica;
                  - bloqueado ou sem senha definida: recusa com o motivo;
                  - senha errada: soma tentativa; ao chegar no limite
                    SENHA_TENTATIVAS_BLOQUEIO (mínimo 3), bloqueia;
                  - senha certa: zera tentativas, abre a sessão;
                  - computador (IP) com LOGIN_COMPUTADOR_TENTATIVAS erros
                    seguidos (qualquer usuário, inclusive inexistente) nos
                    últimos LOGIN_COMPUTADOR_MINUTOS: recusa sem olhar a
                    senha nem contar tentativa no usuário (ESTACAO_BLOQUEADA),
                    até passar o tempo. Um login certo zera a contagem.
                Toda tentativa vai para SIS.Login_Log.
                Recusa antes de gravar: COMMIT (nada foi alterado), para a
                procedure funcionar também dentro de INSERT ... EXEC.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: limite de tentativas por computador.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Login_Processar]
    @Login           NVARCHAR(100),
    @SenhaConferida  BIT,
    @TokenHash       VARBINARY(32)  = NULL,
    @Ip              VARCHAR(45)    = NULL,
    @Estacao         NVARCHAR(128)  = NULL,
    @Navegador       NVARCHAR(300)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Usuario_Login_Processar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Limite       INT;
    DECLARE @IdUsuario    INT;
    DECLARE @Ativo        BIT;
    DECLARE @Bloqueado    BIT;
    DECLARE @TemSenha     BIT;
    DECLARE @Tentativas   SMALLINT;
    DECLARE @Nome         NVARCHAR(100);
    DECLARE @TrocarSenha  BIT;
    DECLARE @Resultado    VARCHAR(20)   = '';
    DECLARE @Mensagem     NVARCHAR(400) = N'';
    DECLARE @IdSessao     BIGINT;
    DECLARE @LimiteIp     INT;
    DECLARE @MinutosIp    INT;
    DECLARE @ErrosIp      INT = 0;

    BEGIN TRY
        SET @Login          = LOWER(LTRIM(RTRIM(ISNULL(@Login, N''))));
        SET @SenhaConferida = ISNULL(@SenhaConferida, 0);
        SET @Ip             = ISNULL(@Ip, '');
        SET @Estacao        = ISNULL(@Estacao, N'');
        SET @Navegador      = ISNULL(@Navegador, N'');
        SET @Limite         = SIS.fn_SIS_Parametro_Inteiro('SENHA_TENTATIVAS_BLOQUEIO');
        IF @Limite < 3 SET @Limite = 3;
        SET @LimiteIp       = ISNULL(SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_TENTATIVAS'), 10);
        IF @LimiteIp < 5 SET @LimiteIp = 5;
        SET @MinutosIp      = ISNULL(SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_MINUTOS'), 15);
        IF @MinutosIp < 1 SET @MinutosIp = 1;

        IF @SenhaConferida = 1 AND DATALENGTH(ISNULL(@TokenHash, 0x)) <> 32
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, ORIGEM)
            VALUES (@NomeProc, @EtapaAtual, 0, N'Token de sessão inválido recebido da API (precisa ter 32 bytes).', 0, 'SQL');
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Falha técnica no login. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        SET @EtapaAtual = 'Processamento';
        BEGIN TRANSACTION;

            SELECT @IdUsuario   = u.ID_USUARIO,
                   @Ativo       = u.ATIVO,
                   @Bloqueado   = u.BLOQUEADO,
                   @TemSenha    = CASE WHEN u.SENHA_HASH IS NULL THEN 0 ELSE 1 END,
                   @Tentativas  = u.TENTATIVAS_ERRADAS,
                   @Nome        = u.NOME,
                   @TrocarSenha = u.TROCAR_SENHA
            FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
            WHERE u.LOGIN = @Login
              AND u.INTERNO = 0;

            -- Computador que errou demais: espera, sem olhar a senha nem contar no usuário
            IF @Ip <> ''
                SELECT @ErrosIp = COUNT(*)
                FROM SIS.Login_Log l
                WHERE l.IP = @Ip
                  AND l.DT_TENTATIVA >= DATEADD(MINUTE, -@MinutosIp, SYSDATETIME())
                  AND l.RESULTADO IN ('SENHA_ERRADA', 'BLOQUEOU', 'INEXISTENTE', 'INATIVO')
                  AND l.ID_LOGIN_LOG > ISNULL((SELECT MAX(o.ID_LOGIN_LOG) FROM SIS.Login_Log o WHERE o.IP = @Ip AND o.RESULTADO = 'OK'), 0);

            IF @ErrosIp >= @LimiteIp
            BEGIN
                SET @Resultado = 'ESTACAO_BLOQUEADA';
                SET @Mensagem  = N'Muitas tentativas de login erradas neste computador. Aguarde ' + CONVERT(NVARCHAR(10), @MinutosIp) + N' minutos e tente de novo.';
            END;

            IF @Resultado = '' AND @IdUsuario IS NULL
            BEGIN
                SET @Resultado = 'INEXISTENTE';
                SET @Mensagem  = N'Usuário ou senha inválidos.';
            END;

            IF @Resultado = '' AND @Ativo = 0
            BEGIN
                SET @Resultado = 'INATIVO';
                SET @Mensagem  = CASE WHEN @SenhaConferida = 1 THEN N'Usuário inativo. Procure o administrador do sistema.' ELSE N'Usuário ou senha inválidos.' END;
            END;

            IF @Resultado = '' AND @Bloqueado = 1
            BEGIN
                SET @Resultado = 'BLOQUEADO';
                SET @Mensagem  = N'Usuário bloqueado por excesso de tentativas. Procure o administrador do sistema.';
            END;

            IF @Resultado = '' AND @TemSenha = 0
            BEGIN
                SET @Resultado = 'SEM_SENHA';
                SET @Mensagem  = N'A senha deste usuário ainda não foi definida. Procure o administrador do sistema.';
            END;

            IF @Resultado = '' AND @SenhaConferida = 0
            BEGIN
                SET @Tentativas = @Tentativas + 1;

                UPDATE u
                   SET u.TENTATIVAS_ERRADAS = @Tentativas,
                       u.BLOQUEADO          = CASE WHEN @Tentativas >= @Limite THEN 1 ELSE 0 END,
                       u.DT_BLOQUEIO        = CASE WHEN @Tentativas >= @Limite THEN SYSDATETIME() ELSE u.DT_BLOQUEIO END
                FROM SIS.Usuario u
                WHERE u.ID_USUARIO = @IdUsuario;

                SET @Resultado = CASE WHEN @Tentativas >= @Limite THEN 'BLOQUEOU' ELSE 'SENHA_ERRADA' END;
                SET @Mensagem  = CASE WHEN @Tentativas >= @Limite
                                      THEN N'Senha incorreta. O usuário foi bloqueado após ' + CONVERT(NVARCHAR(10), @Limite) + N' tentativas. Procure o administrador do sistema.'
                                      ELSE N'Usuário ou senha inválidos. Restam ' + CONVERT(NVARCHAR(10), @Limite - @Tentativas) + N' tentativa(s) antes do bloqueio.'
                                 END;
            END;

            IF @Resultado = ''
            BEGIN
                UPDATE u
                   SET u.TENTATIVAS_ERRADAS = 0,
                       u.DT_ULTIMO_LOGIN    = SYSDATETIME()
                FROM SIS.Usuario u
                WHERE u.ID_USUARIO = @IdUsuario;

                INSERT INTO SIS.Sessao (ID_USUARIO, TOKEN_HASH, IP, ESTACAO, NAVEGADOR)
                VALUES (@IdUsuario, @TokenHash, @Ip, @Estacao, @Navegador);
                SET @IdSessao = CAST(SCOPE_IDENTITY() AS BIGINT);

                SET @Resultado = 'OK';
                SET @Mensagem  = CASE WHEN @TrocarSenha = 1 THEN N'Bem-vindo. Defina uma nova senha para continuar.' ELSE N'Bem-vindo.' END;
            END;

            INSERT INTO SIS.Login_Log (LOGIN_INFORMADO, ID_USUARIO, RESULTADO, IP, ESTACAO)
            VALUES (LEFT(@Login, 100), @IdUsuario, @Resultado, @Ip, @Estacao);

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Resultado = 'OK' THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM,
               CAST(CASE WHEN @Resultado = 'OK' THEN @IdUsuario END AS INT) AS ID_USUARIO,
               @IdSessao AS ID_SESSAO,
               CAST(CASE WHEN @Resultado = 'OK' THEN ISNULL(@Nome, N'') ELSE N'' END AS NVARCHAR(100)) AS NOME,
               CAST(CASE WHEN @Resultado = 'OK' THEN ISNULL(@TrocarSenha, 0) ELSE 0 END AS BIT) AS TROCAR_SENHA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível fazer o login. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Versao_Banco.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Histórico das instalações do banco: cada vez que o MASTER (ou o
                pacote do desenvolvimento) roda, grava a versão instalada, quando
                e por quem. A versão atual é a do registro mais recente
                (SIS.fn_SIS_Versao_Banco). A API confere essa versão ao subir:
                programa e banco têm de estar na mesma versão (CLAUDE.md seção 7,
                fase 3d). Nunca é apagado.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Versao_Banco]', N'U') IS NULL
    CREATE TABLE [SIS].[Versao_Banco]
    (
        ID_VERSAO_BANCO  INT            IDENTITY(1,1) NOT NULL,
        VERSAO           VARCHAR(20)    NOT NULL,
        ORIGEM           VARCHAR(20)    NOT NULL,
        DT_INSTALACAO    DATETIME2(0)   NOT NULL CONSTRAINT DF_Versao_Banco_DT_INSTALACAO DEFAULT (SYSDATETIME()),
        USUARIO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_USUARIO       DEFAULT (SUSER_SNAME()),
        ESTACAO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_ESTACAO       DEFAULT (ISNULL(HOST_NAME(), N'')),
        CONSTRAINT PK_Versao_Banco        PRIMARY KEY CLUSTERED (ID_VERSAO_BANCO),
        CONSTRAINT CK_Versao_Banco_ORIGEM CHECK (ORIGEM IN ('MASTER', 'PACOTE_LOCAL'))
    );
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Versao_Banco.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Versão atual do banco (a da instalação mais recente em
                SIS.Versao_Banco). Vazio = banco sem versão registrada.
                Usada pela API ao subir e em /api/saude.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Versao_Banco();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Versao_Banco] ()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN ISNULL((SELECT TOP (1) v.VERSAO FROM SIS.Versao_Banco v ORDER BY v.ID_VERSAO_BANCO DESC), '');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Instalacao_Situacao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Situacao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se o banco está esperando o PRIMEIRO ACESSO da instalação:
                nenhum usuário administrador (perfil de nível 1 ou 2, ativo, não
                interno) tem senha definida. Só nesse caso a tela de instalação
                (que a API abre apenas no próprio servidor) pode definir as
                senhas do administrador geral e do administrador da empresa.
                Devolve 1 linha: PENDENTE, LOGIN_GERAL, LOGIN_EMPRESA.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
    -- EXEC SIS.SIS_Instalacao_Situacao;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Situacao]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                                  WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                     THEN 0 ELSE 1 END AS BIT) AS PENDENTE,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_GERAL,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_EMPRESA;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Instalacao_Senha_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Senha_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : PRIMEIRO ACESSO da instalação (uso exclusivo da API, tela que só
                abre no próprio servidor): grava de uma vez (tudo-ou-nada) a
                senha do administrador geral (nível 2) e a do administrador da
                empresa (nível 1). O banco recebe só o PBKDF2-SHA256 calculado
                pela API (como em SIS_Usuario_Senha_Gravar).
                Só funciona enquanto NENHUM administrador tem senha
                (SIS_Instalacao_Situacao.PENDENTE = 1); depois disso recusa
                sempre: senha nova passa pelo caminho normal (tela Usuários).
                Administrador geral: TROCAR_SENHA = 0 (ele mesmo digitou).
                Administrador da empresa: TROCAR_SENHA = 1 (senha provisória,
                troca no primeiro login).
                Gravado em nome do usuário "sistema" (auditoria), estação
                "Instalação (servidor)".
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Senha_Gravar]
    @HashGeral     VARBINARY(64),
    @SaltGeral     VARBINARY(64),
    @HashEmpresa   VARBINARY(64),
    @SaltEmpresa   VARBINARY(64),
    @Iteracoes     INT,
    @Algoritmo     VARCHAR(30),
    @Ip            VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Instalacao_Senha_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @MinIteracoes  INT;
    DECLARE @IdSistema     INT;
    DECLARE @IdGeral       INT;
    DECLARE @IdEmpresa     INT;

    BEGIN TRY
        SET @MinIteracoes = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PBKDF2_ITERACOES'), 600000);
        IF @MinIteracoes < 100000 SET @MinIteracoes = 100000;
        SET @IdSistema = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema' AND u.INTERNO = 1);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK) INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                SET @Recusa = N'A instalação já foi concluída: os administradores já têm senha. Para trocar uma senha, use a tela de usuários.';

            SELECT TOP (1) @IdGeral = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;
            SELECT TOP (1) @IdEmpresa = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;

            IF @Recusa = N'' AND (@IdGeral IS NULL OR @IdEmpresa IS NULL OR @IdSistema IS NULL)
                SET @Recusa = N'Faltam os usuários iniciais no banco (rode o MASTER).';
            IF @Recusa = N'' AND ISNULL(@Algoritmo, '') <> 'PBKDF2-SHA256'
                SET @Recusa = N'Falha técnica: algoritmo de senha não suportado.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@HashGeral, 0x)) <> 32 OR DATALENGTH(ISNULL(@HashEmpresa, 0x)) <> 32)
                SET @Recusa = N'Falha técnica: hash de senha inválido.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@SaltGeral, 0x)) < 16 OR DATALENGTH(ISNULL(@SaltEmpresa, 0x)) < 16)
                SET @Recusa = N'Falha técnica: salt de senha inválido.';
            IF @Recusa = N'' AND ISNULL(@Iteracoes, 0) < @MinIteracoes
                SET @Recusa = N'Falha técnica: quantidade de iterações da senha abaixo do mínimo.';

            IF @Recusa <> N''
            BEGIN
                COMMIT TRANSACTION;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
                RETURN;
            END;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = N'Instalação (servidor)', @Origem = N'Tela de primeiro acesso';

            UPDATE u
               SET u.SENHA_HASH         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @HashGeral ELSE @HashEmpresa END,
                   u.SENHA_SALT         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @SaltGeral ELSE @SaltEmpresa END,
                   u.SENHA_ITERACOES    = @Iteracoes,
                   u.SENHA_ALGORITMO    = @Algoritmo,
                   u.DT_SENHA           = SYSDATETIME(),
                   u.TROCAR_SENHA       = CASE WHEN u.ID_USUARIO = @IdGeral THEN 0 ELSE 1 END,
                   u.TENTATIVAS_ERRADAS = 0,
                   u.BLOQUEADO          = 0,
                   u.DT_BLOQUEIO        = NULL,
                   u.DT_ALTERACAO       = SYSDATETIME(),
                   u.USUARIO_ALTERACAO  = N'instalacao'
            FROM SIS.Usuario u
            WHERE u.ID_USUARIO IN (@IdGeral, @IdEmpresa);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Senhas gravadas. Entre com o administrador geral; o administrador da empresa troca a senha no primeiro acesso.' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar as senhas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Registro_Existe.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Registro_Existe]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se existe o registro @Id (chave primária de uma coluna) na
                tabela @Tabela, que precisa estar entre as TABELAS_DA_TELA do
                item @Item (SIS.fn_SIS_Item_Tem_Tabela); qualquer outra tabela
                devolve 0. Usada por quem precisa conferir um registro de
                tabela variável (ex.: SIS_Anexo_Gravar).
                Roda com a permissão do dono do banco (EXECUTE AS OWNER) porque
                a consulta é montada na hora (SQL dinâmico) e, no servidor, o
                login da API só executa procedures (papel rl_sistemacmj_api):
                sem isso o SELECT seria recusado. O escopo elevado fica só nesta
                consulta; nomes vêm do catálogo e vão com QUOTENAME.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d; achado no ensaio do serviço).

  Homologação (LOCAL e ensaio): sql/testes/SIS/03d_Homologacao_Registro_Existe.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Registro_Existe]
    @Item    VARCHAR(40),
    @Tabela  NVARCHAR(256),
    @Id      BIGINT,
    @Existe  BIT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ObjId INT, @Pk SYSNAME, @Qtd INT, @Achou INT, @Sql NVARCHAR(MAX);
    SET @Existe = 0;

    IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @Id IS NULL
        RETURN;

    SET @ObjId = OBJECT_ID(@Tabela, N'U');
    SELECT @Pk = MAX(c.name), @Qtd = COUNT(*)
    FROM sys.indexes ix
    INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

    IF @ObjId IS NULL OR @Pk IS NULL OR @Qtd <> 1
        RETURN;

    SET @Sql = N'SELECT @Achou = 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId))
             + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Achou INT OUTPUT', @Id = @Id, @Achou = @Achou OUTPUT;
    SET @Existe = CASE WHEN @Achou = 1 THEN 1 ELSE 0 END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Registra um anexo. A API recebe o arquivo, grava em disco com
                nome gerado (GUID + extensão) em ANEXO_PASTA_RAIZ\ano\mês,
                calcula o SHA-256 e então chama esta procedure. Se a procedure
                recusar, a API apaga o arquivo que acabou de gravar.
                Confere:
                  - permissão ALTERAR na tela (@Item) e que a tela mantém a
                    tabela (TABELAS_DA_TELA);
                  - que o registro existe (pela chave primária da tabela);
                  - tipo ativo e extensão aceita pelo tipo;
                  - tamanho até ANEXO_TAMANHO_MAX_MB;
                  - nome do arquivo gerado (só letras, números, "-" e ".");
                  - o mesmo arquivo (hash) ainda não anexado ao registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_ANEXO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (20/11/2026) - Etapa 03d: conferência do registro pelo SIS_Registro_Existe
                        (o SELECT dinâmico falhava com o login da API no servidor).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Gravar]
    @IdUsuario      INT,
    @Item           VARCHAR(40),
    @Tabela         NVARCHAR(256),
    @IdRegistro     BIGINT,
    @CodigoTipo     VARCHAR(30),
    @NomeOriginal   NVARCHAR(260),
    @NomeArquivo    VARCHAR(100),
    @PastaRelativa  VARCHAR(50),
    @TamanhoBytes   BIGINT,
    @HashSha256     VARBINARY(32),
    @Descricao      NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Anexo_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @IdTipo      INT;
    DECLARE @Extensoes   VARCHAR(200);
    DECLARE @Extensao    VARCHAR(10);
    DECLARE @MaxMb       INT;
    DECLARE @Existe      BIT           = 0;
    DECLARE @IdAnexo     BIGINT;

    BEGIN TRY
        SET @Tabela        = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @CodigoTipo    = UPPER(LTRIM(RTRIM(ISNULL(@CodigoTipo, ''))));
        SET @NomeOriginal  = LTRIM(RTRIM(ISNULL(@NomeOriginal, N'')));
        SET @NomeArquivo   = LTRIM(RTRIM(ISNULL(@NomeArquivo, '')));
        SET @PastaRelativa = LTRIM(RTRIM(ISNULL(@PastaRelativa, '')));
        SET @Extensao      = LOWER(CASE WHEN CHARINDEX('.', REVERSE(@NomeArquivo)) > 1
                                        THEN RIGHT(@NomeArquivo, CHARINDEX('.', REVERSE(@NomeArquivo)) - 1) ELSE '' END);
        SET @MaxMb         = SIS.fn_SIS_Parametro_Inteiro('ANEXO_TAMANHO_MAX_MB');
        IF @MaxMb < 1 SET @MaxMb = 1;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para anexar arquivos nesta tela.';
        IF @Recusa = N'' AND SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            SET @Recusa = N'Esta tela não aceita anexos desse tipo de registro.';

        SELECT @IdTipo = t.ID_ANEXO_TIPO, @Extensoes = t.EXTENSOES
        FROM SIS.Anexo_Tipo t
        WHERE t.CODIGO = @CodigoTipo AND t.ATIVO = 1;

        IF @Recusa = N'' AND @IdTipo IS NULL
            SET @Recusa = N'Escolha um tipo de anexo válido.';
        IF @Recusa = N'' AND (@Extensao = '' OR NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@Extensoes, ',') s WHERE LTRIM(RTRIM(s.value)) = @Extensao))
            SET @Recusa = N'Este tipo de anexo aceita só: ' + CONVERT(NVARCHAR(200), REPLACE(@Extensoes, ',', ', ')) + N'.';
        IF @Recusa = N'' AND (ISNULL(@TamanhoBytes, 0) <= 0 OR @TamanhoBytes > CAST(@MaxMb AS BIGINT) * 1048576)
            SET @Recusa = N'O arquivo precisa ter até ' + CONVERT(NVARCHAR(10), @MaxMb) + N' MB.';
        IF @Recusa = N'' AND (@NomeOriginal = N''
                              OR @NomeArquivo = ''
                              OR REPLACE(REPLACE(@NomeArquivo, '-', ''), '.', '') LIKE '%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2
                              OR REPLACE(@PastaRelativa, '\', '') LIKE '%[^0-9]%' COLLATE Latin1_General_BIN2
                              OR DATALENGTH(ISNULL(@HashSha256, 0x)) <> 32)
            SET @Recusa = N'Falha técnica no envio do arquivo (nome, pasta ou hash inválido).';

        IF @Recusa = N''
        BEGIN
            -- v1.1: conferência pelo SIS_Registro_Existe (SQL dinâmico com a permissão do dono:
            -- no servidor o login da API só executa procedures)
            SET @EtapaAtual = 'Registro de referência';
            EXEC SIS.SIS_Registro_Existe @Item = @Item, @Tabela = @Tabela, @Id = @IdRegistro, @Existe = @Existe OUTPUT;
            IF ISNULL(@Existe, 0) = 0
                SET @Recusa = N'Registro não encontrado.';
        END;

        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Anexo a
                                     WHERE a.TABELA_REFERENCIA = @Tabela AND a.ID_REFERENCIA = @IdRegistro
                                       AND a.HASH_SHA256 = @HashSha256 AND a.SITUACAO = 'ATIVO')
            SET @Recusa = N'Este arquivo já está anexado a este registro.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_ANEXO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        INSERT INTO SIS.Anexo (TABELA_REFERENCIA, ID_REFERENCIA, ID_ANEXO_TIPO, NOME_ORIGINAL, NOME_ARQUIVO, PASTA_RELATIVA,
                               EXTENSAO, TAMANHO_BYTES, HASH_SHA256, DESCRICAO, USUARIO_CRIACAO)
        VALUES (@Tabela, @IdRegistro, @IdTipo, @NomeOriginal, @NomeArquivo, @PastaRelativa,
                @Extensao, @TamanhoBytes, @HashSha256, LTRIM(RTRIM(ISNULL(@Descricao, N''))), ISNULL(@Usuario, N''));
        SET @IdAnexo = CAST(SCOPE_IDENTITY() AS BIGINT);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Arquivo anexado.' AS NVARCHAR(400)) AS MENSAGEM, @IdAnexo AS ID_ANEXO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o anexo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_ANEXO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Id.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Id]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Código (ID_USUARIO) do usuário pelo login. NULL se não existe.
                Usada pela API para gravar em nome do usuário interno "sistema"
                (ex.: instalação da licença), sem ler tabela direto (o login da
                API só executa procedures e functions).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, licença).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Usuario_Id('sistema');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Id] (@Login VARCHAR(40))
RETURNS INT
AS
BEGIN
    RETURN (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = LOWER(LTRIM(RTRIM(@Login))));
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : registro da versão do banco em [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : ÚLTIMA instrução do MASTER (depois da finalização): grava a
                versão que acabou de ser instalada. É a ÚNICA fonte da versão do
                banco: o montar_master.py lê o número daqui para o cabeçalho
                do MASTER, e a API exige o mesmo número
                (Infra/VersaoBanco.cs, VersaoExigida).
                REGRA: toda mudança que vai para o MASTER sobe este número e o
                da API juntos.
                Em banco de desenvolvimento (_LOCAL) grava com ORIGEM
                PACOTE_LOCAL. Rodar de novo grava outra linha (histórico).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d): versão 1.1 do banco.
    Versões do banco: 1.1 (20/11/2026) limite de login por computador e versão;
                      1.2 (20/11/2026) primeiro acesso da instalação;
                      1.3 (20/11/2026) SIS_Registro_Existe (anexos com o login da API);
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.4';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 03d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
