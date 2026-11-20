/*******************************************************************************
  Pacote      : 03d - ajustes da base SIS durante a etapa 03d (rodapé dos e-mails sem CNPJ por parâmetro)
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

PRINT N'Pacote 03d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
