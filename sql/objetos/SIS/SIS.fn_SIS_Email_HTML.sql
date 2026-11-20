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
