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
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
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
-- Arquivo: sql/objetos/SIS/SIS.Backup_Execucao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Backup_Execucao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registro de cada backup feito pelo script do servidor
                (instalacao\backup_servidor.ps1, tarefas agendadas do Windows):
                COMPLETO (diário), LOG (de hora em hora), TESTE (restauração de
                conferência, semanal) e SEGURANCA (feito logo antes de uma
                restauração pedida pela tela). Serve para a tela de backups e
                restauração, para os avisos de atraso/falha
                (SIS_Backup_Conferir_Processar) e para a auditoria.
                Os arquivos ficam no disco (parâmetro BACKUP_PASTA); aqui só a
                referência. Nunca é apagado (o arquivo pode ser, pela retenção:
                ARQUIVO_EXISTE = 0).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor). Nome com sufixo:
                        BACKUP é palavra reservada do SQL Server.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Nome antigo (BACKUP é palavra reservada do SQL): apaga se ficou vazio de um ensaio de 20/11/2026
IF OBJECT_ID(N'[SIS].[Backup]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [SIS].[Backup])
        DROP TABLE [SIS].[Backup];
END;
GO

IF OBJECT_ID(N'[SIS].[Backup_Execucao]', N'U') IS NULL
    CREATE TABLE [SIS].[Backup_Execucao]
    (
        ID_BACKUP        BIGINT          IDENTITY(1,1) NOT NULL,
        TIPO             VARCHAR(10)     NOT NULL,
        ARQUIVO          NVARCHAR(400)   NOT NULL CONSTRAINT DF_Backup_Execucao_ARQUIVO        DEFAULT (N''),
        DT_INICIO        DATETIME2(0)    NOT NULL,
        DT_FIM           DATETIME2(0)    NULL,
        TAMANHO_MB       DECIMAL(12,1)   NOT NULL CONSTRAINT DF_Backup_Execucao_TAMANHO_MB     DEFAULT (0),
        SITUACAO         VARCHAR(10)     NOT NULL,
        MENSAGEM         NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Backup_Execucao_MENSAGEM       DEFAULT (N''),
        COPIA_NUVEM      BIT             NOT NULL CONSTRAINT DF_Backup_Execucao_COPIA_NUVEM    DEFAULT (0),
        ARQUIVO_EXISTE   BIT             NOT NULL CONSTRAINT DF_Backup_Execucao_ARQUIVO_EXISTE DEFAULT (1),
        SERVIDOR         NVARCHAR(128)   NOT NULL CONSTRAINT DF_Backup_Execucao_SERVIDOR       DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_REGISTRO      DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Execucao_DT_REGISTRO    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Backup_Execucao          PRIMARY KEY CLUSTERED (ID_BACKUP),
        CONSTRAINT CK_Backup_Execucao_TIPO     CHECK (TIPO IN ('COMPLETO', 'LOG', 'TESTE', 'SEGURANCA')),
        CONSTRAINT CK_Backup_Execucao_SITUACAO CHECK (SITUACAO IN ('OK', 'ERRO'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Backup_Execucao]') AND i.name = N'IX_Backup_Execucao_TIPO_DT')
    CREATE NONCLUSTERED INDEX IX_Backup_Execucao_TIPO_DT ON [SIS].[Backup_Execucao] (TIPO, SITUACAO, DT_INICIO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Registrar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Registrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registra um backup em SIS.Backup_Execucao. Chamada SÓ pelo script de
                backup do servidor (instalacao\backup_servidor.ps1), que roda
                pelas tarefas do Windows; o login da API não pode executar
                (DENY no papel rl_sistemacmj_api).
                Situação ERRO: manda aviso por e-mail para o parâmetro
                EMAIL_ADMIN_ALERTA (se preenchido), uma vez por backup.
                @ArquivosExistentes (opcional): lista separada por "|" com os
                arquivos que ainda existem na pasta depois da limpeza; os
                demais registros ficam com ARQUIVO_EXISTE = 0.
                Devolve 1 linha: ID_BACKUP.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Registrar]
    @Tipo                VARCHAR(10),
    @Arquivo             NVARCHAR(400),
    @DtInicio            DATETIME2(0),
    @DtFim               DATETIME2(0)   = NULL,
    @TamanhoMb           DECIMAL(12,1)  = 0,
    @Situacao            VARCHAR(10),
    @Mensagem            NVARCHAR(2000) = N'',
    @CopiaNuvem          BIT            = 0,
    @ArquivosExistentes  NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id BIGINT, @Para NVARCHAR(400), @IdEmail BIGINT, @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200);

    INSERT INTO SIS.Backup_Execucao (TIPO, ARQUIVO, DT_INICIO, DT_FIM, TAMANHO_MB, SITUACAO, MENSAGEM, COPIA_NUVEM)
    VALUES (@Tipo, ISNULL(@Arquivo, N''), @DtInicio, @DtFim, ISNULL(@TamanhoMb, 0), @Situacao, LEFT(ISNULL(@Mensagem, N''), 2000), ISNULL(@CopiaNuvem, 0));
    SET @Id = CAST(SCOPE_IDENTITY() AS BIGINT);

    IF @ArquivosExistentes IS NOT NULL
        UPDATE b SET b.ARQUIVO_EXISTE = 0
        FROM SIS.Backup_Execucao b
        WHERE b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@ArquivosExistentes, '|') s WHERE LTRIM(RTRIM(s.value)) = b.ARQUIVO);

    IF @Situacao = 'ERRO'
    BEGIN
        SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Para <> N''
        BEGIN
            SET @Corpo = SIS.fn_SIS_Email_HTML(N'Falha no backup', 'ALERTA',
                N'<p>O backup <b>' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</b> do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> falhou em '
                + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@DtInicio), N'') + N'.</p><p>Mensagem: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>'
                + N'<p>Confira o servidor e o registro do backup (pasta do backup, arquivo backup.log).</p>',
                N'[SIS].[SIS_Backup_Registrar]', NULL, 0);
            SET @Chave = N'BACKUP_ERRO_' + CONVERT(NVARCHAR(20), @Id);
            EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: falha no backup do sistema', @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
        END;
    END;

    SELECT @Id AS ID_BACKUP;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Conferir_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Conferir_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina agendada (BACKUP_CONFERIR, de hora em hora): avisa por
                e-mail (parâmetro EMAIL_ADMIN_ALERTA) quando o backup ATRASA:
                  - último backup COMPLETO ok há mais de BACKUP_HORAS_ALERTA_COMPLETO;
                  - último backup do LOG ok há mais de BACKUP_HORAS_ALERTA_LOG
                    (só depois do primeiro completo);
                  - último TESTE de restauração ok há mais de BACKUP_DIAS_ALERTA_TESTE.
                Cada aviso sai no máximo uma vez por dia (chave de origem com a
                data). Sem nenhum backup registrado ainda: não avisa (servidor
                recém-instalado).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Conferir_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Para NVARCHAR(400) = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
    DECLARE @HorasCompleto INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_COMPLETO'), 26);
    DECLARE @HorasLog INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_LOG'), 3);
    DECLARE @DiasTeste INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_DIAS_ALERTA_TESTE'), 8);
    DECLARE @UltCompleto DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK');
    DECLARE @UltLog DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO IN ('LOG', 'COMPLETO') AND b.SITUACAO = 'OK');
    DECLARE @UltTeste DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'TESTE' AND b.SITUACAO = 'OK');
    DECLARE @Agora DATETIME2(0) = SYSDATETIME();
    DECLARE @Problemas NVARCHAR(MAX) = N'';
    DECLARE @Corpo NVARCHAR(MAX), @IdEmail BIGINT, @Chave NVARCHAR(200);

    IF @Para = N'' OR NOT EXISTS (SELECT 1 FROM SIS.Backup_Execucao) RETURN;

    IF @UltCompleto IS NULL OR @UltCompleto < DATEADD(HOUR, -@HorasCompleto, @Agora)
        SET @Problemas += N'<li>Backup completo: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltCompleto), N'(nenhum)') + N'.</li>';
    IF @UltCompleto IS NOT NULL AND @UltLog < DATEADD(HOUR, -@HorasLog, @Agora)
        SET @Problemas += N'<li>Backup do log (de hora em hora): o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltLog), N'(nenhum)') + N'.</li>';
    -- teste: só cobra depois que o servidor tem backups há mais de @DiasTeste dias
    IF (SELECT MIN(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK') < DATEADD(DAY, -@DiasTeste, @Agora)
       AND (@UltTeste IS NULL OR @UltTeste < DATEADD(DAY, -@DiasTeste, @Agora))
        SET @Problemas += N'<li>Teste de restauração: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltTeste), N'(nenhum)') + N'.</li>';

    IF @Problemas = N'' RETURN;

    SET @Corpo = SIS.fn_SIS_Email_HTML(N'Backup atrasado', 'ALERTA',
        N'<p>O backup do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> está atrasado:</p><ul>' + @Problemas + N'</ul>'
        + N'<p>Confira se o servidor ficou desligado, se as tarefas "SisCMJ - Backup" estão ativas no Agendador de Tarefas e o arquivo backup.log na pasta do backup.</p>',
        N'[SIS].[SIS_Backup_Conferir_Processar]', NULL, 0);
    SET @Chave = N'BACKUP_ATRASO_' + CONVERT(NVARCHAR(8), @Agora, 112);
    EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: backup do sistema atrasado', @CorpoHTML = @Corpo,
         @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Conferir_Processar]',
         @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Backup_Restauracao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Backup_Restauracao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Pedidos de restauração do banco feitos pela tela Sistema >
                Backups (SIS_BACKUP, ação RESTAURAR). A tela só registra o
                pedido (PENDENTE); quem restaura é a tarefa do Windows
                "Restauração (pedidos)" (instalacao\backup_servidor.ps1, como
                SYSTEM), que captura o pedido (EXECUTANDO), faz o backup de
                segurança, restaura e grava o resultado (OK ou ERRO).
                Como a restauração volta esta tabela ao passado, o script
                regrava o pedido no banco restaurado com o mesmo ID
                (SIS_Backup_Restauracao_Resultado, IDENTITY_INSERT).
                TIPO_PONTO: BACKUP (volta para um backup completo ou de
                segurança, ID_BACKUP) ou DATA_HORA (volta para um dia e hora,
                DT_PONTO, com os backups do log de hora em hora).
                Nunca é apagado.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Backup_Restauracao]', N'U') IS NULL
    CREATE TABLE [SIS].[Backup_Restauracao]
    (
        ID_RESTAURACAO       INT             IDENTITY(1,1) NOT NULL,
        TIPO_PONTO           VARCHAR(10)     NOT NULL,
        ID_BACKUP            BIGINT          NULL,
        DT_PONTO             DATETIME2(0)    NULL,
        MOTIVO               NVARCHAR(400)   NOT NULL,
        SITUACAO             VARCHAR(12)     NOT NULL CONSTRAINT DF_Backup_Restauracao_SITUACAO  DEFAULT ('PENDENTE'),
        ID_USUARIO_PEDIDO    INT             NOT NULL,
        USUARIO_PEDIDO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Backup_Restauracao_USUARIO_PEDIDO DEFAULT (N''),
        DT_PEDIDO            DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Restauracao_DT_PEDIDO DEFAULT (SYSDATETIME()),
        DT_INICIO            DATETIME2(0)    NULL,
        DT_FIM               DATETIME2(0)    NULL,
        PLANO                NVARCHAR(4000)  NOT NULL CONSTRAINT DF_Backup_Restauracao_PLANO     DEFAULT (N''),
        ARQUIVO_SEGURANCA    NVARCHAR(400)   NOT NULL CONSTRAINT DF_Backup_Restauracao_ARQUIVO_SEGURANCA DEFAULT (N''),
        MENSAGEM             NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Backup_Restauracao_MENSAGEM  DEFAULT (N''),
        SERVIDOR             NVARCHAR(128)   NOT NULL CONSTRAINT DF_Backup_Restauracao_SERVIDOR  DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_CRIACAO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Restauracao_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)   NOT NULL CONSTRAINT DF_Backup_Restauracao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)    NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)   NULL,
        CONSTRAINT PK_Backup_Restauracao            PRIMARY KEY CLUSTERED (ID_RESTAURACAO),
        CONSTRAINT FK_Backup_Restauracao_Backup     FOREIGN KEY (ID_BACKUP) REFERENCES [SIS].[Backup_Execucao] (ID_BACKUP),
        CONSTRAINT CK_Backup_Restauracao_TIPO_PONTO CHECK (TIPO_PONTO IN ('BACKUP', 'DATA_HORA')),
        CONSTRAINT CK_Backup_Restauracao_PONTO      CHECK ((TIPO_PONTO = 'BACKUP' AND ID_BACKUP IS NOT NULL) OR (TIPO_PONTO = 'DATA_HORA' AND DT_PONTO IS NOT NULL)),
        CONSTRAINT CK_Backup_Restauracao_SITUACAO   CHECK (SITUACAO IN ('PENDENTE', 'EXECUTANDO', 'OK', 'ERRO', 'CANCELADO'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Backup_Restauracao]') AND i.name = N'IX_Backup_Restauracao_SITUACAO')
    CREATE NONCLUSTERED INDEX IX_Backup_Restauracao_SITUACAO ON [SIS].[Backup_Restauracao] (SITUACAO, DT_PEDIDO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Backup_Plano.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Backup_Plano]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Plano de uma restauração: quais arquivos de backup aplicar e
                em que ordem (function inline, só leitura).
                  @IdBackup preenchido (TIPO_PONTO BACKUP): só aquele backup
                    completo ou de segurança, ORDEM 0.
                  @DtPonto preenchido (TIPO_PONTO DATA_HORA): o último backup
                    COMPLETO que terminou até o ponto (ORDEM 0) e os backups
                    do LOG seguintes, até o primeiro que passa do ponto
                    (ORDEM 1, 2...; o último é aplicado com STOPAT).
                Só backups com SITUACAO OK. ARQUIVO_EXISTE vem junto para quem
                chama recusar o plano com arquivo que já foi apagado.
                O plano está completo quando tem a linha 0 e, no DATA_HORA,
                a última linha tem DT_FIM >= @DtPonto (coluna ALCANCA_PONTO).
                A conferência fina da sequência do log (LSN) é feita pelo
                script na hora de restaurar.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- SELECT * FROM SIS.fn_SIS_Backup_Plano(NULL, '2026-11-20 14:45') ORDER BY ORDEM;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Backup_Plano] (@IdBackup BIGINT, @DtPonto DATETIME2(0))
RETURNS TABLE
AS
RETURN
WITH Base AS
(
    SELECT TOP (1) b.ID_BACKUP, b.TIPO, b.ARQUIVO, b.DT_INICIO, b.DT_FIM, b.ARQUIVO_EXISTE
    FROM SIS.Backup_Execucao b
    WHERE b.SITUACAO = 'OK'
      AND b.ARQUIVO <> N''
      AND (   (@IdBackup IS NOT NULL AND b.ID_BACKUP = @IdBackup AND b.TIPO IN ('COMPLETO', 'SEGURANCA'))
           OR (@IdBackup IS NULL AND @DtPonto IS NOT NULL AND b.TIPO = 'COMPLETO' AND b.ARQUIVO_EXISTE = 1 AND b.DT_FIM <= @DtPonto))
    ORDER BY b.DT_FIM DESC, b.ID_BACKUP DESC
),
Corte AS
(
    SELECT MIN(l.DT_INICIO) AS DT_CORTE
    FROM SIS.Backup_Execucao l
    INNER JOIN Base b ON l.DT_INICIO >= b.DT_INICIO
    WHERE @IdBackup IS NULL
      AND l.TIPO = 'LOG'
      AND l.SITUACAO = 'OK'
      AND l.DT_FIM >= @DtPonto
)
SELECT CAST(0 AS INT) AS ORDEM, b.ID_BACKUP, b.TIPO, b.ARQUIVO, b.DT_INICIO, b.DT_FIM, b.ARQUIVO_EXISTE,
       CAST(CASE WHEN @IdBackup IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS ALCANCA_PONTO
FROM Base b
UNION ALL
SELECT CAST(ROW_NUMBER() OVER (ORDER BY l.DT_INICIO, l.ID_BACKUP) AS INT), l.ID_BACKUP, l.TIPO, l.ARQUIVO, l.DT_INICIO, l.DT_FIM, l.ARQUIVO_EXISTE,
       CAST(CASE WHEN l.DT_INICIO = c.DT_CORTE THEN 1 ELSE 0 END AS BIT)
FROM SIS.Backup_Execucao l
INNER JOIN Base b  ON l.DT_INICIO >= b.DT_INICIO
INNER JOIN Corte c ON c.DT_CORTE IS NOT NULL AND l.DT_INICIO <= c.DT_CORTE
WHERE @IdBackup IS NULL
  AND l.TIPO = 'LOG'
  AND l.SITUACAO = 'OK';
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Lista dos backups para a tela Sistema > Backups (SIS_BACKUP,
                ação VER): completos, do log de hora em hora, testes de
                restauração e backups de segurança, do mais novo para o mais
                antigo, com a indicação de que o arquivo ainda existe.
                Mostra os dos últimos @Dias dias (padrão: parâmetro
                BACKUP_DIAS_MANTER + 7) e qualquer um cujo arquivo ainda exista.
                Sem permissão: erro 50001 (a tela mostra a mensagem).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Listar]
    @IdUsuario  INT,
    @Dias       INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Desde      DATETIME2(0);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @Dias = ISNULL(@Dias, ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro('BACKUP_DIAS_MANTER')), 7) + 7);
        IF @Dias < 1 SET @Dias = 1;
        IF @Dias > 3650 SET @Dias = 3650;
        SET @Desde = DATEADD(DAY, -@Dias, SYSDATETIME());

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_BACKUP,
               b.TIPO,
               CAST(CASE b.TIPO WHEN 'COMPLETO' THEN N'Completo' WHEN 'LOG' THEN N'De hora em hora (log)'
                                WHEN 'TESTE' THEN N'Teste de restauração' WHEN 'SEGURANCA' THEN N'Segurança (antes de restaurar)'
                                ELSE N'' END AS NVARCHAR(40)) AS TIPO_NOME,
               b.ARQUIVO,
               CAST(ISNULL(RIGHT(b.ARQUIVO, CHARINDEX(N'\', REVERSE(b.ARQUIVO) + N'\') - 1), N'') AS NVARCHAR(260)) AS ARQUIVO_NOME,
               b.DT_INICIO,
               b.DT_FIM,
               b.TAMANHO_MB,
               b.SITUACAO,
               b.MENSAGEM,
               b.COPIA_NUVEM,
               b.ARQUIVO_EXISTE,
               CAST(CASE WHEN b.TIPO IN ('COMPLETO', 'SEGURANCA') AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
                         THEN 1 ELSE 0 END AS BIT) AS PODE_ESCOLHER,
               b.SERVIDOR
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.DT_INICIO >= @Desde
           OR (b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N'' AND b.TIPO <> 'TESTE')
        ORDER BY b.DT_INICIO DESC, b.ID_BACKUP DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível listar os backups. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Situacao_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Situacao_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Resumo do topo da tela Sistema > Backups (SIS_BACKUP, VER),
                1 linha: até onde dá para voltar (do backup completo mais
                antigo que ainda existe até o último backup do log ou
                completo), último completo, último log, último teste, pedido
                de restauração em aberto e se o usuário pode restaurar.
                Sem permissão: erro 50001.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Situacao_Obter @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Situacao_Obter]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Backup_Situacao_Obter]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @DtMaisAntigo DATETIME2(0), @DtInicioAntigo DATETIME2(0), @DtMaisRecente DATETIME2(0);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (1) @DtMaisAntigo = b.DT_FIM, @DtInicioAntigo = b.DT_INICIO
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N'' AND b.DT_FIM IS NOT NULL
        ORDER BY b.DT_FIM, b.ID_BACKUP;

        SELECT @DtMaisRecente = MAX(b.DT_FIM)
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.TIPO IN ('COMPLETO', 'LOG') AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND b.DT_INICIO >= @DtInicioAntigo;

        SELECT @DtMaisAntigo  AS DT_PODE_VOLTAR_DE,
               @DtMaisRecente AS DT_PODE_VOLTAR_ATE,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK') AS DT_ULTIMO_COMPLETO,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'LOG'      AND b.SITUACAO = 'OK') AS DT_ULTIMO_LOG,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'TESTE'    AND b.SITUACAO = 'OK') AS DT_ULTIMO_TESTE,
               CAST(ISNULL((SELECT COUNT(*) FROM SIS.Backup_Execucao b WITH (NOLOCK)
                            WHERE b.SITUACAO = 'ERRO' AND b.DT_INICIO >= DATEADD(DAY, -7, SYSDATETIME())), 0) AS INT) AS QTD_ERROS_7_DIAS,
               CAST(ISNULL((SELECT TOP (1) r.ID_RESTAURACAO FROM SIS.Backup_Restauracao r WITH (NOLOCK)
                            WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO') ORDER BY r.ID_RESTAURACAO), 0) AS INT) AS ID_RESTAURACAO_ABERTA,
               CAST(ISNULL((SELECT TOP (1) r.SITUACAO FROM SIS.Backup_Restauracao r WITH (NOLOCK)
                            WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO') ORDER BY r.ID_RESTAURACAO), '') AS VARCHAR(12)) AS SITUACAO_ABERTA,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') AS PODE_RESTAURAR,
               CAST(DB_NAME() AS NVARCHAR(128)) AS BANCO,
               SYSDATETIME() AS DT_AGORA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar a situação dos backups. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Restauracao_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Pedidos de restauração e o resultado de cada um, do mais novo
                para o mais antigo (tela Sistema > Backups, SIS_BACKUP, VER).
                Sem permissão: erro 50001.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT r.ID_RESTAURACAO,
               r.TIPO_PONTO,
               CAST(CASE r.TIPO_PONTO WHEN 'BACKUP' THEN N'Backup escolhido' ELSE N'Dia e hora' END AS NVARCHAR(30)) AS TIPO_PONTO_NOME,
               r.ID_BACKUP,
               CAST(ISNULL(b.ARQUIVO, N'') AS NVARCHAR(400)) AS ARQUIVO_BACKUP,
               ISNULL(r.DT_PONTO, b.DT_FIM) AS DT_VOLTA_PARA,
               r.MOTIVO,
               r.SITUACAO,
               CAST(CASE r.SITUACAO WHEN 'PENDENTE' THEN N'Aguardando' WHEN 'EXECUTANDO' THEN N'Restaurando'
                                    WHEN 'OK' THEN N'Concluída' WHEN 'ERRO' THEN N'Com erro' WHEN 'CANCELADO' THEN N'Cancelada'
                                    ELSE N'' END AS NVARCHAR(20)) AS SITUACAO_NOME,
               r.USUARIO_PEDIDO,
               r.DT_PEDIDO,
               r.DT_INICIO,
               r.DT_FIM,
               r.PLANO,
               r.ARQUIVO_SEGURANCA,
               r.MENSAGEM,
               CAST(CASE WHEN r.SITUACAO = 'PENDENTE' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 1
                         THEN 1 ELSE 0 END AS BIT) AS PODE_CANCELAR
        FROM SIS.Backup_Restauracao r WITH (NOLOCK)
        LEFT JOIN SIS.Backup_Execucao b WITH (NOLOCK) ON b.ID_BACKUP = r.ID_BACKUP
        ORDER BY r.ID_RESTAURACAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível listar os pedidos de restauração. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Restauracao_Solicitar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Solicitar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registra um pedido de restauração do banco (tela Sistema >
                Backups, SIS_BACKUP, ação RESTAURAR). Não restaura nada: a
                tarefa do Windows "Restauração (pedidos)" confere os pedidos a
                cada minuto e faz a restauração (o login da API não tem
                permissão para restaurar).
                Confirmação forte: a API confere a senha do usuário
                (@SenhaConferida = 1), o usuário escreve RESTAURAR
                (@Confirmacao) e informa o motivo (mínimo no parâmetro
                BACKUP_RESTAURACAO_MOTIVO_MINIMO).
                @TipoPonto BACKUP: volta para o backup completo ou de
                segurança @IdBackup. DATA_HORA: volta para @DtPonto, com o
                último completo antes dele e os backups do log seguintes
                (fn_SIS_Backup_Plano).
                Um pedido em aberto (PENDENTE ou EXECUTANDO) por vez.
                Avisa por e-mail o EMAIL_ADMIN_ALERTA (se preenchido).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_RESTAURACAO.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = 1, @TipoPonto = 'DATA_HORA', @DtPonto = '2026-11-20 14:25',
    --      @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Solicitar]
    @IdUsuario       INT,
    @TipoPonto       VARCHAR(10),
    @IdBackup        BIGINT        = NULL,
    @DtPonto         DATETIME2(0)  = NULL,
    @Motivo          NVARCHAR(400) = NULL,
    @Confirmacao     NVARCHAR(20)  = NULL,
    @SenhaConferida  BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Solicitar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @MotivoMin    INT;
    DECLARE @Login        NVARCHAR(100);
    DECLARE @Plano        NVARCHAR(4000) = N'';
    DECLARE @QtdLinhas    INT, @QtdSemArquivo INT, @Alcanca INT;
    DECLARE @DtVolta      DATETIME2(0);
    DECLARE @IdRestauracao INT;
    DECLARE @Para NVARCHAR(400), @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200), @IdEmail BIGINT;

    BEGIN TRY
        SET @TipoPonto = UPPER(LTRIM(RTRIM(ISNULL(@TipoPonto, ''))));
        SET @Motivo    = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @MotivoMin = ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro('BACKUP_RESTAURACAO_MOTIVO_MINIMO')), 10);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 0
            SET @Recusa = N'Você não tem permissão para restaurar backup.';
        ELSE IF ISNULL(@SenhaConferida, 0) = 0
            SET @Recusa = N'A senha não confere.';
        ELSE IF UPPER(LTRIM(RTRIM(ISNULL(@Confirmacao, N'')))) <> N'RESTAURAR'
            SET @Recusa = N'Para confirmar, escreva a palavra RESTAURAR.';
        ELSE IF LEN(@Motivo) < @MotivoMin
            SET @Recusa = N'Informe o motivo da restauração (pelo menos ' + CONVERT(NVARCHAR(10), @MotivoMin) + N' letras).';
        ELSE IF @TipoPonto NOT IN ('BACKUP', 'DATA_HORA')
            SET @Recusa = N'Escolha um backup ou um dia e hora para voltar.';
        ELSE IF @TipoPonto = 'BACKUP' AND @IdBackup IS NULL
            SET @Recusa = N'Escolha o backup para voltar.';
        ELSE IF @TipoPonto = 'DATA_HORA' AND @DtPonto IS NULL
            SET @Recusa = N'Informe o dia e a hora para voltar.';
        ELSE IF @TipoPonto = 'DATA_HORA' AND @DtPonto >= SYSDATETIME()
            SET @Recusa = N'O dia e a hora para voltar precisam estar no passado.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        IF @TipoPonto = 'BACKUP' SET @DtPonto = NULL;
        IF @TipoPonto = 'DATA_HORA' SET @IdBackup = NULL;

        SET @EtapaAtual = 'Plano';
        SELECT @QtdLinhas     = COUNT(*),
               @QtdSemArquivo = SUM(CASE WHEN p.ARQUIVO_EXISTE = 0 THEN 1 ELSE 0 END),
               @Alcanca       = MAX(CAST(p.ALCANCA_PONTO AS INT)),
               @DtVolta       = MAX(CASE WHEN p.ORDEM = 0 THEN p.DT_FIM END)
        FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p;

        SET @Plano = ISNULL(STUFF((SELECT N' | ' + CONVERT(NVARCHAR(10), p.ORDEM) + N': ' + p.ARQUIVO
                                   FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p
                                   ORDER BY p.ORDEM
                                   FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 3, N''), N'');

        IF ISNULL(@QtdLinhas, 0) = 0
            SET @Recusa = CASE WHEN @TipoPonto = 'BACKUP' THEN N'Backup não encontrado ou não serve para restaurar. Atualize a lista.'
                               ELSE N'Não há backup completo antes desse dia e hora. Escolha um ponto dentro do período mostrado em "Dá para voltar".' END;
        ELSE IF ISNULL(@QtdSemArquivo, 0) > 0
            SET @Recusa = N'Algum arquivo de backup necessário já foi apagado pela limpeza. Escolha um ponto mais recente.';
        ELSE IF ISNULL(@Alcanca, 0) = 0
            SET @Recusa = N'Ainda não há backup de hora em hora depois desse dia e hora. Escolha um ponto até o último backup ou espere o próximo backup de hora em hora.';
        ELSE IF LEN(@Plano) > 3900
            SET @Recusa = N'O ponto escolhido usa backups demais. Escolha um ponto mais perto de um backup completo.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT @Login = u.LOGIN FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            -- sem ROLLBACK na recusa: nada foi gravado e a rotina pode ser chamada por INSERT ... EXEC (teste)
            IF EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WITH (UPDLOCK, HOLDLOCK) WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO'))
                SET @Recusa = N'Já existe um pedido de restauração em andamento. Espere terminar ou cancele o pedido que está aguardando.';

            IF @Recusa = N''
            BEGIN
                INSERT INTO SIS.Backup_Restauracao (TIPO_PONTO, ID_BACKUP, DT_PONTO, MOTIVO, SITUACAO, ID_USUARIO_PEDIDO, USUARIO_PEDIDO, PLANO)
                VALUES (@TipoPonto, @IdBackup, @DtPonto, @Motivo, 'PENDENTE', @IdUsuario, ISNULL(@Login, N''), ISNULL(@Plano, N''));
                SET @IdRestauracao = CAST(SCOPE_IDENTITY() AS INT);
            END;

        COMMIT TRANSACTION;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SET @EtapaAtual = 'Aviso por e-mail';
        BEGIN TRY
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            IF @Para <> N''
            BEGIN
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Pedido de restauração do banco', 'ALERTA',
                    N'<p><b>' + SIS.fn_SIS_Texto_HTML(ISNULL(@Login, N'')) + N'</b> pediu para restaurar o banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME())
                    + N'</b>, voltando para <b>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtPonto, @DtVolta)), N'') + N'</b>.</p>'
                    + N'<p>Motivo: ' + SIS.fn_SIS_Texto_HTML(@Motivo) + N'</p>'
                    + N'<p>Pedido nº ' + CONVERT(NVARCHAR(10), @IdRestauracao) + N'. O sistema fica fora do ar por alguns minutos durante a restauração.</p>',
                    @NomeProc, NULL, 0);
                SET @Chave = N'RESTAURACAO_PEDIDO_' + CONVERT(NVARCHAR(10), @IdRestauracao);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: pedido de restauração do banco', @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = @NomeProc, @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Pedido de restauração nº ' + CONVERT(NVARCHAR(10), @IdRestauracao)
                    + N' registrado. Em até 1 minuto o sistema sai do ar por alguns minutos para restaurar; depois, entre de novo.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdRestauracao AS ID_RESTAURACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o pedido de restauração. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_RESTAURACAO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Restauracao_Cancelar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Cancela um pedido de restauração que ainda está aguardando
                (PENDENTE), antes de a tarefa do Windows começar (tela
                Sistema > Backups, SIS_BACKUP, ação RESTAURAR). Depois de
                EXECUTANDO não dá mais para cancelar.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_RESTAURACAO.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Cancelar @IdUsuario = 1, @IdRestauracao = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Cancelar]
    @IdUsuario      INT,
    @IdRestauracao  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Linhas     INT;
    DECLARE @Login      NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para restaurar backup.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT @Login = u.LOGIN FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.SITUACAO          = 'CANCELADO',
               r.DT_FIM            = SYSDATETIME(),
               r.MENSAGEM          = LEFT(N'Cancelado por ' + ISNULL(@Login, N'') + N' antes de começar.', 2000),
               r.DT_ALTERACAO      = SYSDATETIME(),
               r.USUARIO_ALTERACAO = ISNULL(@Login, N'')
        FROM SIS.Backup_Restauracao r
        WHERE r.ID_RESTAURACAO = @IdRestauracao
          AND r.SITUACAO = 'PENDENTE';
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(N'Este pedido não está mais aguardando (já começou, terminou ou foi cancelado). Atualize a lista.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Pedido de restauração cancelado.' AS NVARCHAR(400)) AS MENSAGEM, @IdRestauracao AS ID_RESTAURACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível cancelar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_RESTAURACAO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Restauracao_Resultado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Resultado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Grava o resultado (OK ou ERRO) de um pedido de restauração.
                Chamada SÓ pelo script do servidor (e pela Capturar); o login
                da API não pode executar (DENY).
                Depois da restauração o banco volta ao passado e o pedido pode
                não existir mais nele (ou estar como PENDENTE): por isso o
                script manda todos os dados do pedido, e esta rotina grava de
                novo a linha com o MESMO ID (IDENTITY_INSERT), ou atualiza a
                que existe. Os dados que vierem vazios ficam como estão.
                @ArquivoBackup: o backup escolhido (TIPO_PONTO BACKUP) é
                localizado pelo arquivo, porque o ID dele pode ter mudado
                quando o script registrou de novo os backups que faltavam.
                Avisa por e-mail o EMAIL_ADMIN_ALERTA e quem pediu.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Resultado]
    @IdRestauracao     INT,
    @Situacao          VARCHAR(12),
    @Mensagem          NVARCHAR(2000) = N'',
    @TipoPonto         VARCHAR(10)    = NULL,
    @ArquivoBackup     NVARCHAR(400)  = NULL,
    @DtPonto           DATETIME2(0)   = NULL,
    @Motivo            NVARCHAR(400)  = NULL,
    @IdUsuarioPedido   INT            = NULL,
    @UsuarioPedido     NVARCHAR(100)  = NULL,
    @DtPedido          DATETIME2(0)   = NULL,
    @DtInicio          DATETIME2(0)   = NULL,
    @Plano             NVARCHAR(4000) = NULL,
    @ArquivoSeguranca  NVARCHAR(400)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Resultado]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @IdBackup   BIGINT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Para NVARCHAR(400), @EmailPedido NVARCHAR(200), @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200), @IdEmail BIGINT;
    DECLARE @Titulo NVARCHAR(200), @Texto NVARCHAR(MAX);
    DECLARE @r TABLE (TIPO_PONTO VARCHAR(10), DT_PONTO DATETIME2(0), ID_BACKUP BIGINT, MOTIVO NVARCHAR(400),
                      ID_USUARIO_PEDIDO INT, USUARIO_PEDIDO NVARCHAR(100), ARQUIVO_SEGURANCA NVARCHAR(400));

    BEGIN TRY
        IF @IdRestauracao IS NULL OR ISNULL(@Situacao, '') NOT IN ('OK', 'ERRO')
            THROW 50000, N'Informe o pedido e a situação (OK ou ERRO).', 1;

        IF NULLIF(LTRIM(RTRIM(ISNULL(@ArquivoBackup, N''))), N'') IS NOT NULL
            SELECT TOP (1) @IdBackup = b.ID_BACKUP
            FROM SIS.Backup_Execucao b
            WHERE b.ARQUIVO = @ArquivoBackup AND b.TIPO IN ('COMPLETO', 'SEGURANCA')
            ORDER BY b.ID_BACKUP DESC;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WITH (UPDLOCK, HOLDLOCK) WHERE r.ID_RESTAURACAO = @IdRestauracao)
            BEGIN
                IF ISNULL(@TipoPonto, '') NOT IN ('BACKUP', 'DATA_HORA')
                   OR (@TipoPonto = 'BACKUP' AND @IdBackup IS NULL)
                   OR (@TipoPonto = 'DATA_HORA' AND @DtPonto IS NULL)
                    THROW 50000, N'Pedido não existe no banco restaurado e faltam os dados para gravar de novo (tipo, backup ou dia e hora).', 1;

                SET IDENTITY_INSERT SIS.Backup_Restauracao ON;
                INSERT INTO SIS.Backup_Restauracao (ID_RESTAURACAO, TIPO_PONTO, ID_BACKUP, DT_PONTO, MOTIVO, SITUACAO, ID_USUARIO_PEDIDO, USUARIO_PEDIDO,
                                                    DT_PEDIDO, DT_INICIO, DT_FIM, PLANO, ARQUIVO_SEGURANCA, MENSAGEM, USUARIO_CRIACAO)
                VALUES (@IdRestauracao, @TipoPonto, CASE WHEN @TipoPonto = 'BACKUP' THEN @IdBackup END, CASE WHEN @TipoPonto = 'DATA_HORA' THEN @DtPonto END,
                        ISNULL(@Motivo, N''), @Situacao, ISNULL(@IdUsuarioPedido, 0), ISNULL(@UsuarioPedido, N''),
                        ISNULL(@DtPedido, @Agora), ISNULL(@DtInicio, @Agora), @Agora, ISNULL(@Plano, N''), ISNULL(@ArquivoSeguranca, N''),
                        LEFT(ISNULL(@Mensagem, N''), 2000), N'restauracao');
                SET IDENTITY_INSERT SIS.Backup_Restauracao OFF;
            END;

            UPDATE r
               SET r.SITUACAO          = @Situacao,
                   r.ID_BACKUP         = CASE WHEN r.TIPO_PONTO = 'BACKUP' THEN ISNULL(@IdBackup, r.ID_BACKUP) ELSE r.ID_BACKUP END,
                   r.DT_INICIO         = ISNULL(r.DT_INICIO, ISNULL(@DtInicio, @Agora)),
                   r.DT_FIM            = @Agora,
                   r.PLANO             = CASE WHEN ISNULL(@Plano, N'') <> N'' THEN @Plano ELSE r.PLANO END,
                   r.ARQUIVO_SEGURANCA = CASE WHEN ISNULL(@ArquivoSeguranca, N'') <> N'' THEN @ArquivoSeguranca ELSE r.ARQUIVO_SEGURANCA END,
                   r.MENSAGEM          = LEFT(ISNULL(@Mensagem, N''), 2000),
                   r.DT_ALTERACAO      = @Agora,
                   r.USUARIO_ALTERACAO = N'restauracao'
            OUTPUT inserted.TIPO_PONTO, inserted.DT_PONTO, inserted.ID_BACKUP, inserted.MOTIVO, inserted.ID_USUARIO_PEDIDO, inserted.USUARIO_PEDIDO, inserted.ARQUIVO_SEGURANCA
            INTO @r
            FROM SIS.Backup_Restauracao r
            WHERE r.ID_RESTAURACAO = @IdRestauracao;

        COMMIT TRANSACTION;

        SET @EtapaAtual = 'Aviso por e-mail';
        BEGIN TRY
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            SELECT @EmailPedido = LTRIM(RTRIM(ISNULL(u.EMAIL, N'')))
            FROM @r x INNER JOIN SIS.Usuario u ON u.ID_USUARIO = x.ID_USUARIO_PEDIDO;
            IF ISNULL(@EmailPedido, N'') <> N'' AND CHARINDEX(@EmailPedido, @Para) = 0
                SET @Para = CASE WHEN @Para = N'' THEN @EmailPedido ELSE @Para + N';' + @EmailPedido END;

            IF @Para <> N''
            BEGIN
                SET @Titulo = CASE WHEN @Situacao = 'OK' THEN N'Restauração do banco concluída' ELSE N'Falha na restauração do banco' END;
                SELECT @Texto = N'<p>Pedido nº ' + CONVERT(NVARCHAR(10), @IdRestauracao) + N', feito por <b>' + SIS.fn_SIS_Texto_HTML(ISNULL(x.USUARIO_PEDIDO, N''))
                              + N'</b>, banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b>.</p>'
                              + N'<p>Voltar para: <b>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(x.DT_PONTO, b.DT_FIM)), N'') + N'</b>.</p>'
                              + N'<p>Motivo: ' + SIS.fn_SIS_Texto_HTML(ISNULL(x.MOTIVO, N'')) + N'</p>'
                              + N'<p>Resultado: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>'
                              + CASE WHEN ISNULL(x.ARQUIVO_SEGURANCA, N'') <> N''
                                     THEN N'<p>Backup de segurança feito antes (para desfazer, se preciso): ' + SIS.fn_SIS_Texto_HTML(x.ARQUIVO_SEGURANCA) + N'</p>' ELSE N'' END
                FROM @r x
                LEFT JOIN SIS.Backup_Execucao b ON b.ID_BACKUP = x.ID_BACKUP;

                SET @Corpo = SIS.fn_SIS_Email_HTML(@Titulo, 'ALERTA', ISNULL(@Texto, N''), @NomeProc, NULL, 0);
                SET @Chave = N'RESTAURACAO_RESULTADO_' + CONVERT(NVARCHAR(10), @IdRestauracao) + N'_' + @Situacao;
                SET @Titulo = CASE WHEN @Situacao = 'OK' THEN N'AVISO: restauração do banco concluída' ELSE N'ALERTA: falha na restauração do banco' END;
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Titulo, @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = @NomeProc, @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;

        SELECT @IdRestauracao AS ID_RESTAURACAO, @Situacao AS SITUACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Restauracao_Capturar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Chamada SÓ pelo script do servidor (instalacao\backup_servidor.ps1,
                tarefa "Restauração (pedidos)", a cada minuto, como SYSTEM). O
                login da API não pode executar (DENY no papel rl_sistemacmj_api).
                Pega o pedido PENDENTE mais antigo, marca EXECUTANDO e devolve o
                plano: uma linha por arquivo a aplicar, na ordem (ORDEM 0 = o
                backup completo; 1, 2... = os backups do log; ULTIMO = 1 na
                última linha, aplicada com STOPAT quando TIPO_PONTO = DATA_HORA).
                Sem pedido, ou com outro pedido já EXECUTANDO: devolve 0 linhas.
                Se o plano não fecha mais (arquivo apagado pela limpeza), marca
                o pedido como ERRO, avisa por e-mail e devolve 0 linhas.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Capturar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @Capturado  TABLE (ID_RESTAURACAO INT NOT NULL);
    DECLARE @Id INT, @IdBackup BIGINT, @DtPonto DATETIME2(0);
    DECLARE @QtdLinhas INT, @QtdSemArquivo INT, @Alcanca INT;
    DECLARE @Erro NVARCHAR(400) = N'';
    DECLARE @Resultado  TABLE (ID_RESTAURACAO INT, SITUACAO VARCHAR(12));

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WHERE r.SITUACAO = 'EXECUTANDO')
            RETURN;

        BEGIN TRANSACTION;
            WITH Proximo AS
            (
                SELECT TOP (1) r.*
                FROM SIS.Backup_Restauracao r WITH (UPDLOCK, READPAST, ROWLOCK)
                WHERE r.SITUACAO = 'PENDENTE'
                ORDER BY r.ID_RESTAURACAO
            )
            UPDATE Proximo
               SET SITUACAO          = 'EXECUTANDO',
                   DT_INICIO         = SYSDATETIME(),
                   MENSAGEM          = N'',
                   DT_ALTERACAO      = SYSDATETIME(),
                   USUARIO_ALTERACAO = N'restauracao'
            OUTPUT inserted.ID_RESTAURACAO INTO @Capturado (ID_RESTAURACAO);
        COMMIT TRANSACTION;

        SELECT @Id = c.ID_RESTAURACAO FROM @Capturado c;
        IF @Id IS NULL RETURN;

        SELECT @IdBackup = r.ID_BACKUP, @DtPonto = r.DT_PONTO FROM SIS.Backup_Restauracao r WHERE r.ID_RESTAURACAO = @Id;

        SET @EtapaAtual = 'Plano';
        SELECT @QtdLinhas     = COUNT(*),
               @QtdSemArquivo = SUM(CASE WHEN p.ARQUIVO_EXISTE = 0 THEN 1 ELSE 0 END),
               @Alcanca       = MAX(CAST(p.ALCANCA_PONTO AS INT))
        FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p;

        IF ISNULL(@QtdLinhas, 0) = 0 OR ISNULL(@QtdSemArquivo, 0) > 0 OR ISNULL(@Alcanca, 0) = 0
            SET @Erro = N'O plano da restauração não fecha mais (backup não encontrado ou arquivo apagado pela limpeza). Nada foi restaurado; faça um pedido novo.';

        IF @Erro <> N''
        BEGIN
            INSERT INTO @Resultado (ID_RESTAURACAO, SITUACAO)
            EXEC SIS.SIS_Backup_Restauracao_Resultado @IdRestauracao = @Id, @Situacao = 'ERRO', @Mensagem = @Erro;
            RETURN;
        END;

        SELECT r.ID_RESTAURACAO, r.TIPO_PONTO, r.DT_PONTO, r.ID_BACKUP, r.MOTIVO, r.USUARIO_PEDIDO, r.ID_USUARIO_PEDIDO, r.DT_PEDIDO, r.DT_INICIO,
               p.ORDEM, p.ID_BACKUP AS ID_BACKUP_ARQUIVO, p.TIPO, p.ARQUIVO, p.DT_INICIO AS DT_INICIO_ARQUIVO, p.DT_FIM AS DT_FIM_ARQUIVO,
               CAST(CASE WHEN p.ORDEM = MAX(p.ORDEM) OVER () THEN 1 ELSE 0 END AS BIT) AS ULTIMO
        FROM SIS.Backup_Restauracao r
        CROSS JOIN SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p
        WHERE r.ID_RESTAURACAO = @Id
        ORDER BY p.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
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
    v1.2 (20/11/2026) - Ação RESTAURAR (restauração de backup pela tela; etapa 03d2).
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
        ('EXECUTAR',         N'Executar (rotina, comando)', 150),
        ('RESTAURAR',        N'Restaurar backup do banco',  160)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Backup.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga do backup do servidor
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina BACKUP_CONFERIR (de hora em hora; avisa atraso de backup
                por e-mail): nasce ATIVA no servidor e DESLIGADA no banco de
                desenvolvimento (_LOCAL), onde o backup é outro (backup\ do
                notebook) e não se registra em SIS.Backup.
                Segurança: o login da API não pode registrar backup (DENY).
                Só insere o que falta (regra 39).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
    v1.1 (20/11/2026) - Etapa 03d2: menu Backups e tela SIS_BACKUP (ações VER e
                        RESTAURAR); DENY para a API nas rotinas só do script
                        (SIS_Backup_Restauracao_Capturar e _Resultado).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'BACKUP_CONFERIR', N'Conferir o backup',
       N'Avisa por e-mail (EMAIL_ADMIN_ALERTA) quando o backup completo, o do log ou o teste de restauração atrasam (parâmetros BACKUP_*_ALERTA_*).',
       N'SIS.SIS_Backup_Conferir_Processar', m.ID_MODULO, 'MINUTOS', 60, '00:00', '', 0, 10,
       CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 0 ELSE 1 END,
       SIS.fn_SIS_Rotina_Proxima('MINUTOS', 60, '00:00', '', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'BACKUP_CONFERIR');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'SIS_BACKUPS', N'Backups', 'MENU', '', 35, 0, 1, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_BACKUPS');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_BACKUP', N'Backups e restauração', 'TELA', 'sis/backups.html', 10, 0, 1, 'SIS.Backup_Restauracao'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_BACKUPS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_BACKUP');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('RESTAURAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_BACKUP'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NOT NULL
BEGIN
    DENY EXECUTE ON [SIS].[SIS_Backup_Registrar] TO [rl_sistemacmj_api];
    DENY EXECUTE ON [SIS].[SIS_Backup_Restauracao_Capturar] TO [rl_sistemacmj_api];
    DENY EXECUTE ON [SIS].[SIS_Backup_Restauracao_Resultado] TO [rl_sistemacmj_api];
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
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API);
                      1.5 (20/11/2026) backup do servidor (SIS.Backup, avisos de atraso).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.5';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 03d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
