/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema, na ordem do menu. Só insere o que falta
                (PADRAO_SQL regra 39): nada já cadastrado é alterado.
                LIBERADO_LICENCA começa 0 em todos, menos SIS (a parte básica
                do sistema). Os demais são ligados pela licença (etapa 02b).
                Ícones: definidos na fase das telas.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Modulo (CODIGO, NOME, ORDEM_MENU, ICONE, LIBERADO_LICENCA)
SELECT v.CODIGO, v.NOME, v.ORDEM_MENU, '', v.LIBERADO_LICENCA
FROM (VALUES
        (CAST('CAD'   AS VARCHAR(10)), CAST(N'Cadastros'           AS NVARCHAR(60)), CAST(10 AS SMALLINT), CAST(0 AS BIT)),
        ('IMOB',  N'Imóveis',             20, 0),
        ('VENDA', N'Vendas',              30, 0),
        ('FIN',   N'Financeiro',          40, 0),
        ('BANCO', N'Bancos',              50, 0),
        ('COBR',  N'Cobrança',            60, 0),
        ('OBRA',  N'Custos de obra',      70, 0),
        ('GER',   N'Painel e relatórios', 80, 0),
        ('SIS',   N'Sistema',             90, 1)
     ) v (CODIGO, NOME, ORDEM_MENU, LIBERADO_LICENCA)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = v.CODIGO);
GO
