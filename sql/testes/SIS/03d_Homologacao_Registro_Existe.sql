/*******************************************************************************
  Teste       : 03d - SIS_Registro_Existe (conferência de registro de tabela
                variável com a permissão do dono do banco)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Roda no LOCAL e no banco de ensaio SISTEMACMJ;
                testa também COMO um usuário no papel da API (rl_sistemacmj_api,
                criado sem login e apagado no fim), que só executa procedures.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @R TABLE (CASO VARCHAR(90), ESPERADO VARCHAR(20), OBTIDO VARCHAR(400));
DECLARE @E BIT, @Id BIGINT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
-- Usuário de teste SEM login, no mesmo papel da API (rl_sistemacmj_api): mesmas permissões
-- do login do serviço no servidor. Apagado no fim.
IF DATABASE_PRINCIPAL_ID(N'hml_api_teste') IS NULL CREATE USER [hml_api_teste] WITHOUT LOGIN;
ALTER ROLE [rl_sistemacmj_api] ADD MEMBER [hml_api_teste];
DECLARE @Servico SYSNAME = N'hml_api_teste';

EXEC SIS.SIS_Registro_Existe @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @Id = @Id, @Existe = @E OUTPUT;
INSERT @R VALUES ('registro que existe', '1', CAST(@E AS VARCHAR(1)));
EXEC SIS.SIS_Registro_Existe @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @Id = -1, @Existe = @E OUTPUT;
INSERT @R VALUES ('registro que nao existe', '0', CAST(@E AS VARCHAR(1)));
EXEC SIS.SIS_Registro_Existe @Item = 'SIS_USUARIO', @Tabela = N'SIS.Parametro', @Id = 1, @Existe = @E OUTPUT;
INSERT @R VALUES ('tabela que nao e da tela: recusa (0)', '0', CAST(@E AS VARCHAR(1)));
EXEC SIS.SIS_Registro_Existe @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario; DROP TABLE x', @Id = 1, @Existe = @E OUTPUT;
INSERT @R VALUES ('nome de tabela malicioso: recusa (0)', '0', CAST(@E AS VARCHAR(1)));

IF @Servico IS NOT NULL
BEGIN
    DECLARE @Sql NVARCHAR(400) = N'EXECUTE AS USER = N''' + REPLACE(@Servico, '''', '''''') + N''';';
    DECLARE @Sql1 NVARCHAR(1000) = @Sql + N' DECLARE @x BIT; EXEC SIS.SIS_Registro_Existe @Item = ''SIS_USUARIO'', @Tabela = N''SIS.Usuario'', @Id = ' + CAST(@Id AS NVARCHAR(20)) + N', @Existe = @x OUTPUT; SELECT CAST(@x AS VARCHAR(1)) AS V INTO ##RegExiste1; REVERT;';
    EXEC (@Sql1);
    INSERT @R SELECT 'como o login do servico: confere o registro', '1', V FROM ##RegExiste1; DROP TABLE ##RegExiste1;
    BEGIN TRY
        DECLARE @Sql2 NVARCHAR(1000) = @Sql + N' BEGIN TRY DECLARE @n INT = (SELECT COUNT(*) FROM SIS.Usuario); SELECT ''LEU'' AS V INTO ##RegExiste2; END TRY BEGIN CATCH SELECT ''NEGADO'' AS V INTO ##RegExiste2; END CATCH; REVERT;';
        EXEC (@Sql2);
    END TRY BEGIN CATCH SELECT 'NEGADO' AS V INTO ##RegExiste2; END CATCH;
    INSERT @R SELECT 'como o login do servico: SELECT direto na tabela e negado', 'NEGADO', V FROM ##RegExiste2; DROP TABLE ##RegExiste2;
END
ELSE INSERT @R VALUES ('(sem login de servico neste banco: testes como o servico pulados)', 'OK', 'OK');

ALTER ROLE [rl_sistemacmj_api] DROP MEMBER [hml_api_teste];
DROP USER [hml_api_teste];

SELECT DB_NAME() AS BANCO, CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @R;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @R;
GO
