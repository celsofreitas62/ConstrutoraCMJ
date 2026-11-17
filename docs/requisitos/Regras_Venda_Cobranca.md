# Regras de venda e cobrança informadas pela CMJ

Fonte: respostas da Renata (CMJ) em 17/11/2026 (`CashBookCMJ/Migracao_Perguntas_CMJ_03c2.docx` e `CashBookCMJ/Perguntas_CMJ_03c2_parte2.docx`) e o contrato-modelo da pasta `Contrato de venda de imóvel/` (fora do Git: dados pessoais). Base para as fases 5 (`VENDA`) e 6 (`COBR`). **Tudo o que pode variar vira parâmetro, com exceção por contrato.**

## 1. Reajuste das parcelas

| Regra | Como é | Fonte |
|---|---|---|
| Índice na obra | **INCC-M/FGV**, número-índice (Dez/1992 = 1,00), mensal e cumulativo | Renata + contrato, cláusula 7ª a |
| Índice depois | **IGP-M/FGV** a partir do mês seguinte à **expedição da certidão de construção (habite-se)**, continuando o reajuste anterior | contrato, cláusula 7ª b |
| Data-base | no contrato (mês da tabela de preços = mês anterior à assinatura); ex.: julho/2024 | Renata + contrato |
| Fator | índice do mês anterior ao vencimento ÷ índice da data-base | Renata + contrato |
| Acumulado do mês (cálculo da CMJ enquanto a FGV não publica) | acumulado anterior × (1 + variação do mês ÷ 100) | Renata |
| Casas decimais | fator com **8 casas**; parcela arredondada em **2 casas** | Renata |
| Quais parcelas | **todas** (mensais, semestrais, anuais, chaves, financiamento), mensalmente | Renata |
| Deflação | a parcela **fica igual** (não diminui) | Renata |
| Índice não publicado no vencimento | paga sem reajuste e compensa no período seguinte, para mais ou para menos | contrato, cláusula 7ª §1º |
| Índice extinto | substitutos em ordem: INCC; CUB/SINDUSCON-MG (obra); IGP/FGV; IPC/FGV; IPC/FIPE (depois) | contrato, cláusula 7ª §2º |
| Por contrato | índice e regra **podem ser diferentes por cliente** | Renata |

Conferência dos exemplos da CMJ: 4.502,5477 ÷ 3.896,2883 = 1,15559921 (8 casas) e R$ 10.623,25 × 1,15559921 = **R$ 12.276,22**, igual ao informado. O primeiro exemplo (data-base jun/2026) dá 1,01728958, e não 1,1360: foi engano de digitação, confirmado pela CMJ.

## 2. Atraso, juros e multa

| Regra | Como é |
|---|---|
| Juros | 1% ao mês, pro rata die, a partir do dia seguinte ao vencimento (sem carência) |
| Multa | 2% |
| Variação | podem ser diferentes por cliente (padrão em parâmetro, exceção no contrato) |
| Parcela paga em atraso | o boleto mantém o reajuste do mês do vencimento; calculam-se multa e juros; o cliente pode pedir acerto ou reparcelamento (renegociação, seção 3.3 item 6 do CLAUDE.md) |

## 3. Boletos (Sicredi, CNAB 400)

| Empresa | Cooperativa | Posto | Conta | Beneficiário |
|---|---|---|---|---|
| Orion Incorporadora SPE | 0217 | 55 | 73623-5 | 55.73623 |
| Opera (Opera Incorporadora) | 0217 | 55 | 77315-4 | 55.77315 |
| Music Incorporadora SPE | 0217 | 55 | 94652-1 | 55.94652 |

- Desconto: existe, negociado com os proprietários caso a caso: **parâmetro** (e por contrato).
- **Sem protesto e sem negativação.**
- **Baixa** do boleto vencido: manual, pelo operador do financeiro (no SisCMJ: botão de baixa/cancelamento que gera a instrução de baixa na remessa).
- Quem envia o boleto ao cliente: **a CMJ** (no SisCMJ: e-mail com o PDF, item 4 da seção 1).
- **Boleto híbrido com QR Code PIX**: sim (registro tipo 8 do CNAB 400 e leitura obrigatória do tipo 8 no retorno).
- Troca de arquivos CNAB 400: a CMJ vai pedir a liberação ao gerente para as contas de cobrança.
- Manual: `Manuais Sicredi/` (CNAB 400 versão 3.0, fev/2026, e guia da cobrança no internet banking).

## 4. Empresas e RET

- Campo opcional **"CNPJ para notas de compra e DDA"** em `CAD.Empresa`: **aprovado**. Hoje só a **Opera** usa (56.304.064/0002-11; cobrança no /0001-30).
- Ilha das Galès, Allegro (Judice e Daher), Square (MJ Incorporadora), Maui e La Sante têm RET, mas o CNPJ do RET servia só para a guia do imposto; Orion e Music ainda não têm RET.
- CNPJs ainda não informados: Ilha das Galès, Judice e Daher, MJ Incorporadora (Square), Edifício Comercial La Sante SPE (preencher pela tela de Empresas).

## 5. Pontos a confirmar com a CMJ (diferenças entre o contrato e a prática informada)

1. **Troca de índice**: o contrato troca INCC-M por IGP-M depois da **certidão de construção (habite-se)**; a resposta falou em "entrega das chaves". O sistema usará a data do habite-se de cada empreendimento: confirmar.
2. **Juros depois da obra**: a cláusula 20 prevê, após o certificado de conclusão, **juros de 1% ao mês pela Tabela Price** sobre as parcelas não pagas, além do IGP-M. A resposta citou só o IGP-M. A CMJ aplica esses juros?
3. **Ordem dos encargos no atraso** (cláusula 8ª): correção pro rata entre o vencimento e o pagamento, juros sobre o valor corrigido e **multa sobre o valor corrigido e com juros**. A resposta fala em juros e multa sobre o valor da parcela. Qual vale na prática?
