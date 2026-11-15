/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Perfil] e [SIS].[Usuario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Os dois perfis de administrador e os usuários iniciais.
                Só insere o que falta (regra 39); perfis procurados pelo nível.
                Perfis:
                  Administrador geral (NIVEL_ADMIN 2): o criador do sistema;
                      tudo, inclusive Licença e Parâmetros; invisível para os
                      demais.
                  Administrador (NIVEL_ADMIN 1): administrador da CMJ; todos os
                      menus menos as telas exclusivas do administrador geral.
                Usuários:
                  sistema : INTERNO, rotinas automáticas e migração; nunca faz
                            login.
                  celso   : Celso de Freitas, administrador geral.
                  admin   : administrador da CMJ.
                celso e admin nascem SEM senha: a senha provisória é definida
                no primeiro acesso da instalação (tela local do servidor, que
                a API só abre em localhost e grava com o usuário "sistema");
                no primeiro login cada um troca a sua.
                Os outros perfis (Financeiro, Vendas, Consulta...) são criados
                pelo administrador da CMJ (pendência 9 da seção 6).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: perfil "Administrador
                        geral" (nível 2) e usuário celso.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO)
SELECT v.NOME, v.DESCRICAO, v.NIVEL_ADMIN, 1
FROM (VALUES
        (CAST(N'Administrador geral' AS NVARCHAR(60)),
         CAST(N'Criador do sistema: acesso total, inclusive licença e parâmetros. Visível só para o próprio nível.' AS NVARCHAR(400)),
         CAST(2 AS TINYINT)),
        (N'Administrador',
         N'Administrador da empresa: todos os menus liberados na licença, inclusive usuários e permissões, menos licença e parâmetros.',
         1)
     ) v (NOME, DESCRICAO, NIVEL_ADMIN)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = v.NIVEL_ADMIN);
GO

INSERT INTO SIS.Usuario (LOGIN, NOME, EMAIL, ID_PERFIL, TROCAR_SENHA, INTERNO, ATIVO)
SELECT v.LOGIN, v.NOME, N'', pa.ID_PERFIL, v.TROCAR_SENHA, v.INTERNO, 1
FROM (VALUES
        (CAST('sistema' AS VARCHAR(40)), CAST(N'Sistema (rotinas automáticas)' AS NVARCHAR(100)), CAST(0 AS BIT), CAST(1 AS BIT), CAST(2 AS TINYINT)),
        ('celso', N'Celso de Freitas',          1, 0, 2),
        ('admin', N'Administrador do sistema',  1, 0, 1)
     ) v (LOGIN, NOME, TROCAR_SENHA, INTERNO, NIVEL_ADMIN)
CROSS APPLY (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = v.NIVEL_ADMIN ORDER BY p.ID_PERFIL) pa
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.LOGIN = v.LOGIN);
GO
