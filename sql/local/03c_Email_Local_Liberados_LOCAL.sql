/*******************************************************************************
  Script      : libera o boletim oficial para sair de verdade do notebook
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026 (etapa 03c)
  Descrição   : Pedido do Celso: enquanto o sistema roda só no notebook, o
                boletim semanal aprovado (tipo COMUNICADO) vai para os
                destinatários reais (escritório e Danielle). Todos os outros
                e-mails continuam desviados para o EMAIL_TESTE. Para voltar a
                desviar tudo, gravar o parâmetro vazio.
                Fica gravado na auditoria em nome do celso.
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
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'NOTEBOOK-CELSO', @Origem = N'script-03c-email-local';

UPDATE SIS.Parametro
   SET VALOR = N'COMUNICADO', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'celso'
 WHERE CHAVE = 'EMAIL_LOCAL_LIBERADOS' AND VALOR <> N'COMUNICADO';

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

SELECT CHAVE, VALOR FROM SIS.Parametro WHERE CHAVE = 'EMAIL_LOCAL_LIBERADOS';
GO

SET NOEXEC OFF;
GO
