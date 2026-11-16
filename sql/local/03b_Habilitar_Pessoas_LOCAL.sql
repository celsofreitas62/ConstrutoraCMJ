/*******************************************************************************
  Objeto      : script de desenvolvimento (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fase 3b: liga o módulo Cadastros (CAD) e a tela Pessoas
                (CAD_PESSOA) para testar a primeira tela no navegador. Módulo e
                tela novos nascem desligados (etapa 02c); quem liga é o
                administrador geral (usuário "celso"), pela mesma procedure que
                a tela "Módulos e telas" vai usar.
                No fim mostra a conferência: módulo, tela e o menu do celso.
                Não faz parte do MASTER.

  Changelog:
    v1.0 (16/11/2026) - Criação (fase 3b).

  Execução: SSMS -> Arquivo -> Abrir -> este arquivo -> conferir o banco -> F5.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO
SET NOCOUNT ON;

DECLARE @IdCelso INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = N'celso');

IF @IdCelso IS NULL
BEGIN
    RAISERROR(N'Usuário celso não encontrado no SISTEMACMJ_LOCAL.', 16, 1);
    RETURN;
END;

EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'MODULO', @Codigo = 'CAD',        @Habilitado = 1;
EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'TELA',   @Codigo = 'CAD_PESSOA', @Habilitado = 1;

-- Conferência 1: o módulo tem de estar liberado na licença E habilitado.
SELECT m.CODIGO, m.NOME, m.LIBERADO_LICENCA, m.HABILITADO
FROM SIS.Modulo m
WHERE m.CODIGO = 'CAD';

-- Conferência 2: a tela Pessoas habilitada.
SELECT i.CODIGO, i.NOME, i.CAMINHO, i.HABILITADO
FROM SIS.Item i
WHERE i.CODIGO = 'CAD_PESSOA';

-- Conferência 3: o menu do celso precisa mostrar Cadastros > Pessoas.
EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdCelso;

-- Conferência 4: o celso já tem senha? (SENHA_DEFINIDA = 0 -> rodar "dotnet run -- senha-inicial celso")
SELECT u.LOGIN, u.NOME, CAST(CASE WHEN u.SENHA_HASH IS NULL THEN 0 ELSE 1 END AS BIT) AS SENHA_DEFINIDA, u.TROCAR_SENHA, u.BLOQUEADO
FROM SIS.Usuario u
WHERE u.INTERNO = 0;
GO
