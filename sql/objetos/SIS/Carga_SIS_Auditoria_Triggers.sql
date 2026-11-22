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
    v1.2 (22/11/2026) - Etapa 04b (P20): SIS.Lixeira e SIS.Tabela_Config.
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
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Lixeira',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Tabela_Config',     @Criar = 1;
GO
