/*******************************************************************************
  Objeto      : carga de [CAD].[Parceiro_Tipo] e [CAD].[Pessoa_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de fábrica (SISTEMA = 1): NA ("N/A", para classificar
                depois), CLIENTE, FORNECEDOR, FUNCIONARIO e CORRETOR. Nunca
                muda a descrição que a CMJ editou.
                Completa os tipos de cada parceiro a partir das marcas antigas
                de CAD.Pessoa (só o que falta) e põe N/A em quem ficou sem tipo
                ativo. Idempotente.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d, P12).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO CAD.Parceiro_Tipo (CODIGO, DESCRICAO, SISTEMA, ORDEM, USUARIO_CRIACAO)
SELECT v.CODIGO, v.DESCRICAO, 1, v.ORDEM, N'instalacao'
FROM (VALUES ('NA', N'N/A (a classificar)', 1),
             ('CLIENTE', N'Cliente', 10),
             ('FORNECEDOR', N'Fornecedor', 20),
             ('FUNCIONARIO', N'Funcionário', 30),
             ('CORRETOR', N'Corretor', 40)) v (CODIGO, DESCRICAO, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = v.CODIGO);

UPDATE CAD.Parceiro_Tipo SET SISTEMA = 1, ATIVO = 1
WHERE CODIGO IN ('NA', 'CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR') AND (SISTEMA = 0 OR ATIVO = 0);
GO

INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
SELECT p.ID_PESSOA, t.ID_PARCEIRO_TIPO, N'instalacao'
FROM CAD.Pessoa p
CROSS APPLY (VALUES ('CLIENTE', p.CLIENTE), ('FORNECEDOR', p.FORNECEDOR), ('FUNCIONARIO', p.FUNCIONARIO), ('CORRETOR', p.CORRETOR)) m (CODIGO, MARCA)
INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = m.CODIGO
WHERE m.MARCA = 1
  AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO);

INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
SELECT p.ID_PESSOA, t.ID_PARCEIRO_TIPO, N'instalacao'
FROM CAD.Pessoa p
INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = 'NA'
WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1)
  AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO);
GO
