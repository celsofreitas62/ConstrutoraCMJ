/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Lancamento_Pendencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - pendências em aberto de um lançamento, uma linha por
                pendência. Fonte única da lista, dos contadores, da ficha e,
                mais adiante, do check-up diário (P25).
                AUTOMATICA: calculada na hora (nada gravado), só para
                  lançamento em aberto (ativo, fora da lixeira, com parcela
                  ABERTA ou PARCIAL) emitido a partir de FIN_PEND_A_PARTIR_DE;
                  some sozinha quando o problema é corrigido. Regras ligadas
                  por parâmetro (nível 1):
                    SEM_CENTRO      FIN_PEND_SEM_CENTRO (S/N)
                    SEM_PLANO       FIN_PEND_SEM_PLANO (S/N)
                    SEM_DOCUMENTO   FIN_PEND_SEM_DOCUMENTO (P, R, A ou N)
                    SEM_ANEXO       FIN_PEND_PAGAR_SEM_ANEXO_VALOR (a pagar
                                    com valor total acima; 0 = desligada)
                    NAO_APTO        FIN_PEND_RECEBER_NAO_APTO (a receber; P10)
                    VENCIDA         FIN_PEND_VENCIDA_DIAS (0 = desligada; uma
                                    linha por lançamento, com a parcela mais
                                    antiga)
                  Automáticas nunca bloqueiam a baixa.
                MANUAL: FIN.Lancamento_Pendencia ABERTA e ativa, de lançamento
                  ativo fora da lixeira (pago ou não). BLOQUEIA_BAIXA vem do
                  tipo; ATRASADA = previsão já passou.
                Função em linha: nas listas entra por CROSS APPLY sem custo
                por linha.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c). Parâmetros lidos direto de
                        SIS.Parametro (sem função escalar por linha).
    v1.1 (26/11/2026) - Etapa 04f2d: o corpo passou para
                        FIN.fn_FIN_Lancamento_Pendencias_Simular (que também
                        simula um parâmetro para a tela de parâmetros); esta
                        chama a outra sem simulação. Mesmas colunas e regras.

  Homologação (LOCAL):
    -- SELECT TOP 50 l.ID_LANCAMENTO, f.* FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Lancamento_Pendencias] (@IdLancamento BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT s.* FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(@IdLancamento, NULL, NULL) s
);
GO
