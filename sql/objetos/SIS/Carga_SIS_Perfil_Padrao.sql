/*******************************************************************************
  Objeto      : carga inicial dos perfis comuns de [SIS].[Perfil]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Perfis de fábrica para o administrador da empresa começar
                (pendência 9 da seção 6 do CLAUDE.md; sugestão aprovada pelo
                Celso em 22/11/2026, conversa 04a). Depois de criados, quem
                manda é a tela Perfis e permissões: o administrador ajusta à
                vontade.
                  Financeiro: todas as ações nas telas de Cadastros,
                      Financeiro, Bancos e Cobrança, menos REABRIR (mês
                      fechado); só consulta em Imóveis, Vendas, Custos de obra
                      e Painel.
                  Consulta: só VER em todas as telas fora do módulo Sistema.
                As permissões são dadas SÓ quando o perfil nasce (neste mesmo
                lote). Perfil que já existe não é tocado: rodar o MASTER de novo
                (atualização) nunca devolve uma permissão que o administrador
                tirou. Telas novas de versões futuras entram desmarcadas: o
                administrador marca na tela.
                Telas exclusivas do administrador geral nunca entram.
                Depende das cargas de SIS.Item e SIS.Item_Acao de todos os
                módulos (vai depois delas).

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04a).
    v1.1 (22/11/2026) - Etapa 04b (P20): Financeiro não recebe DESFAZER
                        (liberável por perfil; decisão do Celso).
    v1.2 (25/11/2026) - Etapa 04f: Financeiro também não recebe
                        LANCAR_RETROATIVO (por padrão só os administradores).
    v1.3 (27/11/2026) - Etapa 04g2: Financeiro também não recebe
                        LIBERAR_PENDENCIA, DESCONTO_LIMITE e AJUSTE_CAIXA
                        (decisão de 26/11/2026: nascem sem ninguém; os
                        administradores dão pela tela Perfis e permissões).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Novos TABLE (ID_PERFIL INT NOT NULL, NOME NVARCHAR(60) NOT NULL);

INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO)
OUTPUT inserted.ID_PERFIL, inserted.NOME INTO @Novos (ID_PERFIL, NOME)
SELECT v.NOME, v.DESCRICAO, 0, 1
FROM (VALUES
        (CAST(N'Financeiro' AS NVARCHAR(60)),
         CAST(N'Contas a pagar e a receber, baixas, bancos e cobrança, com os cadastros. Não reabre mês fechado. Só consulta imóveis, vendas, obras e painel.' AS NVARCHAR(400))),
        (N'Consulta',
         N'Só consulta: vê as telas dos módulos liberados, sem incluir, alterar, excluir nem exportar.')
     ) v (NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil p WHERE p.NOME = v.NOME);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT n.ID_PERFIL, ia.ID_ITEM_ACAO
FROM @Novos n
CROSS JOIN SIS.Item_Acao ia
INNER JOIN SIS.Item   i ON i.ID_ITEM   = ia.ID_ITEM AND i.TIPO = 'TELA' AND i.EXCLUSIVO_GERAL = 0
INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO
INNER JOIN SIS.Acao   a ON a.ID_ACAO   = ia.ID_ACAO
WHERE ia.ATIVO = 1
  AND m.CODIGO <> 'SIS'
  AND (   (n.NOME = N'Consulta'   AND a.CODIGO = 'VER')
       OR (n.NOME = N'Financeiro' AND m.CODIGO IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO NOT IN ('REABRIR', 'DESFAZER', 'LANCAR_RETROATIVO', 'LIBERAR_PENDENCIA', 'DESCONTO_LIMITE', 'AJUSTE_CAIXA'))
       OR (n.NOME = N'Financeiro' AND m.CODIGO NOT IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO = 'VER'))
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = n.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
GO
