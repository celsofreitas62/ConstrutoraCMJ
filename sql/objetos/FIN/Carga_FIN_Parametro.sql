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
    v1.1 (25/11/2026) - Etapa 04f2a: parâmetros da lista (dias "a vencer",
                        situação e visão ao abrir, canceladas em "todas").
    v1.2 (26/11/2026) - Etapa 04f2c (P27): regras das pendências automáticas
                        FIN_PEND_* (todas só para lançamentos em aberto;
                        data de corte e valor do anexo alteráveis pela
                        administradora, pedido do Celso em 26/11/2026).
    v1.3 (26/11/2026) - Etapa 04g: baixa (juros, multa, carência, cálculo
                        no a pagar, limite de desconto) e fechamento de caixa
                        (tipos de conta, aviso na transferência entre
                        empresas). Aprovado pelo Celso em 26/11/2026.
    v1.4 (27/11/2026) - Etapa 04g2: BANCO_EXTRATO_MAX_DIAS (período máximo do
                        extrato) e FIN_CAIXA_FECHAMENTO_ATRASO_DIAS (dias sem
                        fechar o caixa até a conta aparecer como atrasada).
    v1.5 (27/11/2026) - Etapa 04g3: FIN_BAIXA_FORMA_PADRAO (forma de pagamento
                        que a janela de baixa já traz escolhida). Aprovado
                        pelo Celso em 27/11/2026.
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
         N'Quantas linhas por página nas listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_DIAS_A_VENCER', N'7', 'INTEIRO',
         N'Quantos dias à frente contam como "a vencer" no contador e no filtro das listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_SITUACAO_INICIAL', N'EM_ABERTO', 'TEXTO',
         N'Situação já escolhida ao abrir as listas de contas a pagar e a receber (TODAS = sem filtro).', 1, N'EM_ABERTO;VENCIDA;HOJE;A_VENCER;TODAS'),
        ('FIN_LISTA_VISAO_INICIAL', N'PARCELA', 'TEXTO',
         N'Visão ao abrir as listas: PARCELA (uma linha por vencimento) ou LANCAMENTO (uma linha por lançamento).', 1, N'PARCELA;LANCAMENTO'),
        ('FIN_LISTA_OCULTA_CANCELADAS', N'S', 'SN',
         N'S = a situação "Todas" não mostra as parcelas canceladas (aparecem só escolhendo "Cancelada").', 1, N''),
        ('FIN_PEND_SEM_CENTRO', N'S', 'SN',
         N'Pendência automática: lançamento em aberto sem centro de custo.', 1, N''),
        ('FIN_PEND_SEM_PLANO', N'S', 'SN',
         N'Pendência automática: lançamento em aberto sem conta do plano de contas.', 1, N''),
        ('FIN_PEND_SEM_DOCUMENTO', N'P', 'TEXTO',
         N'Pendência automática: lançamento em aberto sem número de documento. P = só contas a pagar, R = só a receber, A = ambos, N = desligada.', 1, N'P;R;A;N'),
        ('FIN_PEND_PAGAR_SEM_ANEXO_VALOR', N'1000.00', 'DECIMAL',
         N'Pendência automática: conta a pagar em aberto com valor total acima deste, sem nenhum anexo (nota, boleto, contrato). 0 = desligada.', 1, N''),
        ('FIN_PEND_RECEBER_NAO_APTO', N'S', 'SN',
         N'Pendência automática: conta a receber em aberto de parceiro com o cadastro não apto para cobrança (falta CPF/CNPJ, endereço completo ou e-mail de cobrança).', 1, N''),
        ('FIN_PEND_VENCIDA_DIAS', N'30', 'INTEIRO',
         N'Pendência automática: parcela em aberto vencida há mais destes dias. 0 = desligada.', 1, N''),
        ('FIN_PEND_A_PARTIR_DE', N'2022-01-01', 'DATA',
         N'As pendências automáticas só olham os lançamentos em aberto com emissão a partir desta data. 01/01/2022 (início dos dados migrados) = todos.', 1, N''),
        ('FIN_BAIXA_MULTA_PERC', N'2.00', 'DECIMAL',
         N'Baixa com atraso: multa sugerida, em % do saldo da parcela (uma vez). 0 = sem multa.', 1, N''),
        ('FIN_BAIXA_JUROS_MES_PERC', N'1.00', 'DECIMAL',
         N'Baixa com atraso: juros sugeridos, em % ao mês, proporcionais aos dias de atraso (pro rata). 0 = sem juros.', 1, N''),
        ('FIN_BAIXA_CARENCIA_DIAS', N'0', 'INTEIRO',
         N'Baixa: dias depois do vencimento sem multa nem juros. Passou da carência, conta desde o vencimento.', 1, N''),
        ('FIN_BAIXA_CALCULA_PAGAR', N'N', 'SN',
         N'Calcular juros e multa também nas contas a pagar (N = o valor informado pelo fornecedor é digitado).', 1, N''),
        ('FIN_BAIXA_DESCONTO_LIMITE_PERC', N'5.00', 'DECIMAL',
         N'Desconto máximo na baixa a receber, em % do saldo da parcela. Acima disso, só com a ação "Desconto acima do limite" e motivo. 0 = sem limite.', 1, N''),
        ('FIN_CAIXA_FECHAMENTO_TIPOS', N'CAIXA', 'TEXTO',
         N'Tipos de conta que usam o fechamento de caixa, separados por vírgula (CAIXA, CORRENTE, POUPANCA, APLICACAO, PERMUTA). Vazio = nenhum.', 1, N''),
        ('FIN_TRANSF_ENTRE_EMPRESAS', N'AVISO', 'TEXTO',
         N'Transferência entre contas de empresas diferentes do grupo: AVISO (pede confirmação), BLOQUEIO (não deixa) ou NAO (sem aviso).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('BANCO_EXTRATO_MAX_DIAS', N'400', 'INTEIRO',
         N'Extrato da conta: período máximo de uma consulta, em dias.', 1, N''),
        ('FIN_CAIXA_FECHAMENTO_ATRASO_DIAS', N'1', 'INTEIRO',
         N'Fechamento de caixa: dias com movimento sem fechar até a conta aparecer como "fechamento atrasado". 0 = não avisa.', 1, N''),
        ('FIN_BAIXA_FORMA_PADRAO', N'PIX', 'TEXTO',
         N'Janela de baixa: forma de pagamento que já vem escolhida (o usuário pode trocar).', 1, N'PIX;BOLETO;TED;DOC;DEBITO;DINHEIRO;CHEQUE;PERMUTA;CARTAO;OUTRA')
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
