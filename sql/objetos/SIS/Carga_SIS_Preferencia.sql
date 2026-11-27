/*******************************************************************************
  Objeto      : carga de [SIS].[Preferencia] e dos parâmetros dos padrões
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Preferências que cada usuário escolhe para si (P03 tela
                inicial e P06 tema, aprovados pelo Celso em 27/11/2026, etapa
                04h) e os parâmetros com o padrão de cada uma (nível 1: os dois
                administradores mudam pela tela Parâmetros de uso). Também o
                período máximo da agenda (AGENDA_PERIODO_MAX_DIAS) e de quanto
                em quanto tempo a tela inicial se atualiza sozinha
                (AGENDA_ATUALIZAR_MIN).
                Parâmetros: só insere o que falta (regra 39); NIVEL_MINIMO,
                OPCOES e DESCRICAO são da instalação e são acertados sempre.
                Catálogo: insere o que falta e acerta nome, descrição, grupo,
                tipo, opções, faixa e ordem (é da instalação, nunca do
                usuário); as escolhas dos usuários ficam intocadas.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
    v1.1 (27/11/2026) - AGENDA_ATUALIZAR_MIN (sugestão aprovada na 04h2).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;
CREATE TABLE #CargaParametro
(
    CHAVE      VARCHAR(60)    NOT NULL,
    VALOR      NVARCHAR(400)  NOT NULL,
    TIPO       VARCHAR(10)    NOT NULL,
    DESCRICAO  NVARCHAR(400)  NOT NULL,
    MODULO     VARCHAR(10)    NOT NULL,
    OPCOES     NVARCHAR(400)  NOT NULL
);

INSERT INTO #CargaParametro (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, OPCOES)
VALUES
    ('INICIO_VISAO_PADRAO', N'CALENDARIO', 'TEXTO',
     N'Tela inicial: como abre para quem não escolheu nas Preferências (lista dos lançamentos ou calendário).', 'FIN', N'CALENDARIO;LISTA'),
    ('INICIO_PERIODO_PADRAO', N'MES', 'TEXTO',
     N'Tela inicial: período que abre para quem não escolheu nas Preferências.', 'FIN', N'SEMANA;QUINZENA;MES;BIMESTRE;TRIMESTRE;QUADRIMESTRE;ANO;ANOS'),
    ('INICIO_ANOS_PADRAO', N'2', 'INTEIRO',
     N'Tela inicial: quantos anos mostra quando o período é "Vários anos" (de 2 a 10).', 'FIN', N''),
    ('INICIO_INCLUI_REALIZADO_PADRAO', N'N', 'SN',
     N'Tela inicial: além do que está em aberto, mostra também o que já foi pago ou recebido (pelo vencimento).', 'FIN', N''),
    ('INICIO_SALDO_ACUMULADO_PADRAO', N'S', 'SN',
     N'Tela inicial: mostra o saldo previsto acumulado (saldo de hoje nas contas mais o que vence até cada dia). Só para quem pode ver os totais.', 'FIN', N''),
    ('AGENDA_PERIODO_MAX_DIAS', N'3700', 'INTEIRO',
     N'Tela inicial: período mais longo que a agenda aceita, em dias (3700 = cerca de 10 anos).', 'FIN', N''),
    ('AGENDA_ATUALIZAR_MIN', N'5', 'INTEIRO',
     N'Tela inicial: de quantos em quantos minutos ela se atualiza sozinha enquanto está aberta (0 = não atualiza sozinha).', 'FIN', N''),
    ('TEMA_PADRAO', N'SISTEMA', 'TEXTO',
     N'Tema das telas para quem não escolheu nas Preferências: seguir o Windows (claro ou escuro), sempre claro ou sempre escuro.', 'SIS', N'SISTEMA;CLARO;ESCURO');

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, 1, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = 1, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> 1 OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

DROP TABLE IF EXISTS #CargaParametro;
GO

DROP TABLE IF EXISTS #CargaPreferencia;
CREATE TABLE #CargaPreferencia
(
    CODIGO           VARCHAR(40)    NOT NULL,
    NOME             NVARCHAR(80)   NOT NULL,
    DESCRICAO        NVARCHAR(400)  NOT NULL,
    GRUPO            NVARCHAR(60)   NOT NULL,
    TIPO             VARCHAR(10)    NOT NULL,
    OPCOES           NVARCHAR(400)  NOT NULL,
    VALOR_MINIMO     INT            NULL,
    VALOR_MAXIMO     INT            NULL,
    CHAVE_PARAMETRO  VARCHAR(60)    NOT NULL,
    ORDEM            SMALLINT       NOT NULL
);

INSERT INTO #CargaPreferencia (CODIGO, NOME, DESCRICAO, GRUPO, TIPO, OPCOES, VALOR_MINIMO, VALOR_MAXIMO, CHAVE_PARAMETRO, ORDEM)
VALUES
    ('INICIO_VISAO', N'Abrir a tela inicial em', N'Lista dos lançamentos, linha a linha, ou calendário com os totais de cada dia ou mês.',
     N'Tela inicial', 'TEXTO', N'CALENDARIO;LISTA', NULL, NULL, 'INICIO_VISAO_PADRAO', 10),
    ('INICIO_PERIODO', N'Período ao abrir', N'Período que a tela inicial mostra ao abrir. Dá para trocar na hora, na própria tela.',
     N'Tela inicial', 'TEXTO', N'SEMANA;QUINZENA;MES;BIMESTRE;TRIMESTRE;QUADRIMESTRE;ANO;ANOS', NULL, NULL, 'INICIO_PERIODO_PADRAO', 20),
    ('INICIO_ANOS', N'Quantos anos em "Vários anos"', N'Usado quando o período é "Vários anos".',
     N'Tela inicial', 'INTEIRO', N'', 2, 10, 'INICIO_ANOS_PADRAO', 30),
    ('INICIO_INCLUI_REALIZADO', N'Mostrar também o que já foi pago ou recebido', N'Sem esta opção, a agenda mostra só o que está em aberto (o saldo de cada parcela).',
     N'Tela inicial', 'SN', N'', NULL, NULL, 'INICIO_INCLUI_REALIZADO_PADRAO', 40),
    ('INICIO_SALDO_ACUMULADO', N'Mostrar o saldo previsto acumulado', N'Saldo de hoje nas contas mais o que vence até cada dia. Aparece só para quem pode ver os totais.',
     N'Tela inicial', 'SN', N'', NULL, NULL, 'INICIO_SALDO_ACUMULADO_PADRAO', 50),
    ('TEMA', N'Tema das telas', N'Seguir o Windows (claro ou escuro), sempre claro ou sempre escuro.',
     N'Aparência', 'TEXTO', N'SISTEMA;CLARO;ESCURO', NULL, NULL, 'TEMA_PADRAO', 10);

INSERT INTO SIS.Preferencia (CODIGO, NOME, DESCRICAO, GRUPO, TIPO, OPCOES, VALOR_MINIMO, VALOR_MAXIMO, CHAVE_PARAMETRO, ORDEM, USUARIO_CRIACAO)
SELECT c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO, c.TIPO, c.OPCOES, c.VALOR_MINIMO, c.VALOR_MAXIMO, c.CHAVE_PARAMETRO, c.ORDEM, N'instalacao'
FROM #CargaPreferencia c
WHERE NOT EXISTS (SELECT 1 FROM SIS.Preferencia p WHERE p.CODIGO = c.CODIGO);

UPDATE p
   SET p.NOME = c.NOME, p.DESCRICAO = c.DESCRICAO, p.GRUPO = c.GRUPO, p.TIPO = c.TIPO, p.OPCOES = c.OPCOES,
       p.VALOR_MINIMO = c.VALOR_MINIMO, p.VALOR_MAXIMO = c.VALOR_MAXIMO, p.CHAVE_PARAMETRO = c.CHAVE_PARAMETRO, p.ORDEM = c.ORDEM,
       p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Preferencia p
INNER JOIN #CargaPreferencia c ON c.CODIGO = p.CODIGO
WHERE p.NOME <> c.NOME OR p.DESCRICAO <> c.DESCRICAO OR p.GRUPO <> c.GRUPO OR p.TIPO <> c.TIPO OR p.OPCOES <> c.OPCOES
   OR ISNULL(p.VALOR_MINIMO, -1) <> ISNULL(c.VALOR_MINIMO, -1) OR ISNULL(p.VALOR_MAXIMO, -1) <> ISNULL(c.VALOR_MAXIMO, -1)
   OR p.CHAVE_PARAMETRO <> c.CHAVE_PARAMETRO OR p.ORDEM <> c.ORDEM;

DROP TABLE IF EXISTS #CargaPreferencia;
GO
