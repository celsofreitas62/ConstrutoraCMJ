/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
GO
