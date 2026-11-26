/*******************************************************************************
  SistemaCMJ - sql/local/04f2c2_Habilitar_Pendencia_Tipo_LOCAL.sql
  Autor     : Celso de Freitas
  Refatorado: Claude
  Criação   : 26/11/2026 (etapa 04f2c2, P27)
  Descrição : Só no LOCAL: habilita a tela Financeiro › Tipos de pendência
              (FIN_PENDENCIA_TIPO nasce desabilitada; na CMJ é habilitada na
              instalação, lembrete na seção 0 do CLAUDE.md).
*******************************************************************************/
SET NOCOUNT ON;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO = 'FIN_PENDENCIA_TIPO' AND HABILITADO = 0;
SELECT CODIGO, NOME, CAMINHO, HABILITADO FROM SIS.Item WHERE CODIGO = 'FIN_PENDENCIA_TIPO';
SELECT CODIGO, DESCRICAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ATIVO FROM FIN.Pendencia_Tipo ORDER BY ORDEM;
GO
