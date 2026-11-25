/*******************************************************************************
  Objeto      : carga dos parâmetros do financeiro em [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas (aprovada em 18/11/2026) e proteções contra
                erro de digitação nos lançamentos (P17, aprovado em 25/11/2026).
                Regras FIN_REGRA_*: AVISO (pede confirmação, que fica
                registrada), BLOQUEIO (não deixa gravar) ou NAO (desligada).
                Só insere o que falta (regra 39): nunca sobrescreve o valor
                que a CMJ já alterou. NIVEL_MINIMO e OPCOES são da instalação
                e são acertados sempre. Os parâmetros de uso têm NIVEL_MINIMO
                1 (os dois administradores alteram em "Parâmetros de uso").
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;

SELECT v.CHAVE, v.VALOR, v.TIPO, v.DESCRICAO, v.NIVEL, v.OPCOES
INTO #CargaParametro
FROM (VALUES
        (CAST('FIN_TRAVA_DATAS_ATIVA' AS VARCHAR(60)), CAST(N'S' AS NVARCHAR(4000)), CAST('SN' AS VARCHAR(10)),
         CAST(N'Liga a trava de datas dos lançamentos (datas muito antigas ou futuras são recusadas; quem tem a permissão "Lançar fora da trava de datas" grava informando o motivo).' AS NVARCHAR(400)),
         CAST(1 AS TINYINT), CAST(N'' AS NVARCHAR(200))),
        ('FIN_DIAS_TOLERANCIA_MES_ANTERIOR', N'5', 'INTEIRO',
         N'Data anterior ao 1º dia do mês atual é recusada, menos até este dia do mês, quando o mês anterior ainda é aceito.', 1, N''),
        ('FIN_EMISSAO_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de emissão do documento pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_BAIXA_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de pagamento, recebimento, transferência ou movimento bancário pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_VENCIMENTO_ANOS_FUTURO', N'35', 'INTEIRO',
         N'Até quantos anos à frente um vencimento pode ser lançado.', 1, N''),
        ('FIN_DATA_AVISO_DIAS', N'3', 'INTEIRO',
         N'Data de emissão (ou vencimento no passado) a mais destes dias de hoje, mesmo dentro do permitido: a tela pede para confirmar a data.', 1, N''),
        ('FIN_REGRA_DUPLIC_DOCUMENTO', N'BLOQUEIO', 'TEXTO',
         N'Mesmo parceiro e mesmo número de documento já lançado (no mesmo tipo, a pagar ou a receber). Vale para documento com número.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_DUPLIC_VALOR', N'AVISO', 'TEXTO',
         N'Possível duplicidade: mesmo parceiro, mesmo valor de parcela e vencimento próximo (dias em FIN_DUPLIC_VALOR_DIAS).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_DUPLIC_VALOR_DIAS', N'5', 'INTEIRO',
         N'Diferença de dias no vencimento para considerar possível duplicidade.', 1, N''),
        ('FIN_REGRA_VALOR_FORA_PADRAO', N'AVISO', 'TEXTO',
         N'Valor fora do padrão: maior que FIN_VALOR_FORA_PADRAO_VEZES vezes a média dos lançamentos do mesmo parceiro e conta do plano.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_VALOR_FORA_PADRAO_VEZES', N'3', 'DECIMAL',
         N'Quantas vezes acima da média o valor precisa estar para o aviso de valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MIN_HIST', N'3', 'INTEIRO',
         N'Quantos lançamentos anteriores (mesmo parceiro e conta) são necessários para calcular a média do valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MESES', N'12', 'INTEIRO',
         N'Quantos meses para trás entram na média do valor fora do padrão.', 1, N''),
        ('FIN_REGRA_VENC_ANTES_EMISSAO', N'AVISO', 'TEXTO',
         N'Vencimento de alguma parcela antes da data de emissão do documento.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_COMPETENCIA_DISTANTE', N'AVISO', 'TEXTO',
         N'Mês de competência distante do mês de emissão (mais que FIN_COMPETENCIA_MESES meses).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_COMPETENCIA_MESES', N'3', 'INTEIRO',
         N'Diferença máxima, em meses, entre a competência e a emissão antes do aviso.', 1, N''),
        ('FIN_REGRA_TIPO_PARCEIRO', N'AVISO', 'TEXTO',
         N'Parceiro sem o tipo Fornecedor (contas a pagar) ou Cliente (contas a receber); o aviso oferece marcar o tipo.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_TIPO_CONTA', N'AVISO', 'TEXTO',
         N'Conta do plano de receita usada em contas a pagar, ou de despesa em contas a receber.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_LISTA_POR_PAGINA', N'100', 'INTEIRO',
         N'Quantas linhas por página nas listas de contas a pagar e a receber.', 1, N'')
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, NIVEL, OPCOES);

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, c.NIVEL, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = c.NIVEL, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> c.NIVEL OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

-- Parâmetros de uso de outras etapas que os dois administradores também alteram
UPDATE p
   SET p.NIVEL_MINIMO = 1
FROM SIS.Parametro p
WHERE p.CHAVE IN ('CENTRO_ENCERRADO_BLOQUEIA')
  AND p.NIVEL_MINIMO <> 1;

DROP TABLE IF EXISTS #CargaParametro;
GO
