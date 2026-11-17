/*******************************************************************************
  Script      : nome do sistema SisCMJ no banco do notebook
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026 (etapa 03c)
  Descrição   : Pedido do Celso: o nome do sistema passa a ser SisCMJ
                ("sistema SisCMJ" lê melhor que "sistema SistemaCMJ").
                A carga só insere o que falta, então no banco que já existe
                o valor é trocado aqui: parâmetro SISTEMA_NOME e título do
                boletim. Fica na auditoria em nome do celso.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este script só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

DECLARE @IdCelso INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'NOTEBOOK-CELSO', @Origem = N'script-03c-nome-sistema';

UPDATE SIS.Parametro
   SET VALOR = N'SisCMJ', VALOR_PADRAO = N'SisCMJ', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'celso'
 WHERE CHAVE = 'SISTEMA_NOME' AND VALOR <> N'SisCMJ';

UPDATE SIS.Comunicado
   SET TITULO = N'Boletim da implantação do SisCMJ', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'celso'
 WHERE CODIGO = 'BOLETIM_IMPLANTACAO' AND TITULO = N'Boletim da implantação do SistemaCMJ';

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

SELECT (SELECT VALOR FROM SIS.Parametro WHERE CHAVE = 'SISTEMA_NOME') AS SISTEMA_NOME,
       (SELECT TITULO FROM SIS.Comunicado WHERE CODIGO = 'BOLETIM_IMPLANTACAO') AS TITULO_BOLETIM;
GO

SET NOEXEC OFF;
GO
