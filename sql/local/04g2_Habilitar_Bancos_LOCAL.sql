/*******************************************************************************
  Script      : 04g2 - habilitar no LOCAL as telas novas do módulo Bancos
                (Transferências, Extrato e saldos, Fechamento de caixa).
                Na instalação da CMJ, habilitar pela tela (nascem desligadas).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 27/11/2026
*******************************************************************************/
SET NOCOUNT ON;
UPDATE SIS.Item SET HABILITADO = 1, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'instalacao'
WHERE CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA') AND HABILITADO = 0;
SELECT CODIGO, HABILITADO FROM SIS.Item WHERE CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA');
