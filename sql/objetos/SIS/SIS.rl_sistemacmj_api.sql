/*******************************************************************************
  Objeto      : papel [rl_sistemacmj_api]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Papel do banco usado pelo login da API e do serviço do
                sistema (CLAUDE.md seção 2): só EXECUTA procedures e
                functions dos schemas do sistema; não lê nem grava tabela
                direto (as procedures fazem isso por encadeamento de dono).
                Proteções a mais:
                  - DENY de INSERT/UPDATE/DELETE em SIS.Auditoria (além da
                    trigger de proteção);
                  - DENY de EXECUTE no gerador de triggers (só instalação);
                  - DENY de EXECUTE no registro de atualização (só o atualizar.cmd);
                  - DENY de EXECUTE nas procedures internas da lixeira e do
                    desfazer (só chamadas por dentro, pelas procedures das
                    telas, com EXECUTE AS OWNER).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (22/11/2026) - DENY em SIS_Atualizacao_Registrar (etapa 03h).
    v1.2 (22/11/2026) - Etapa 04b (P20): DENY nas procedures internas da
                        lixeira e do desfazer.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NULL
    CREATE ROLE [rl_sistemacmj_api] AUTHORIZATION [dbo];
GO

DECLARE @Sql NVARCHAR(MAX) = N'';

SELECT @Sql = @Sql + N'GRANT EXECUTE ON SCHEMA::' + QUOTENAME(s.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.schemas s
WHERE s.name IN (N'SIS', N'CAD', N'BANCO', N'IMOB', N'VENDA', N'FIN', N'COBR', N'OBRA', N'GER', N'COMP');

EXEC sys.sp_executesql @Sql;
GO

DENY INSERT, UPDATE, DELETE ON [SIS].[Auditoria] TO [rl_sistemacmj_api];
DENY EXECUTE ON [SIS].[SIS_Auditoria_Trigger_Gerar] TO [rl_sistemacmj_api];
IF OBJECT_ID(N'[SIS].[SIS_Atualizacao_Registrar]', N'P') IS NOT NULL
    DENY EXECUTE ON [SIS].[SIS_Atualizacao_Registrar] TO [rl_sistemacmj_api];
GO

DECLARE @Internas NVARCHAR(MAX) = N'';
SELECT @Internas = @Internas + N'DENY EXECUTE ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.objects o
WHERE o.type = 'P'
  AND o.object_id IN (OBJECT_ID(N'[SIS].[SIS_Lixeira_Marcar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Apagar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Referencias]'),
                      OBJECT_ID(N'[SIS].[SIS_Tabela_Trava_Conferir]'), OBJECT_ID(N'[SIS].[SIS_Historico_Desfazer_Montar]'));
EXEC sys.sp_executesql @Internas;
GO
