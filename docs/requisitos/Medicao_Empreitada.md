# Medição de empreitada (pedido 7 do Celso, 16/11/2026)

Proposta de modelo para o módulo `OBRA` (fase 8), a partir da planilha que a CMJ usa hoje: `PlanilhasCMJ/Medição.xlsx` ("ORÇAMENTO DE EMPREITA"). **A planilha tem nomes e valores de pessoas reais: fica fora do Git** (`.gitignore`). Aqui só a estrutura.

**Situação**: proposta registrada; o desenho final (tabelas e procedures) é feito na etapa da `OBRA`, com confirmação do Celso.

## 1. Como a planilha funciona hoje

Um **boletim de medição** por empreiteiro, obra e mês:

| Parte | Conteúdo |
|---|---|
| Cabeçalho | Empreiteiro, obra, **número da medição** (ex.: 13), mês de referência |
| Itens do contrato | código hierárquico (1, 1.2, 4.10), serviço e local (torre, apartamento, pavimento), **quantidade a executar** (contratada), **já executado** (acumulado), **executado no período**, **preço unitário**, valor já pago, total do orçamento, **a pagar** (período x preço) |
| Subtotais | por grupo de serviço (carpintaria, pedreiro, elétrica) |
| Diárias | dias trabalhados x valor da diária, por pessoa |
| Total | soma dos serviços + diárias |
| Descontos | por funcionário do empreiteiro: FGTS, multa, contribuição assistencial, vale-refeição, salário depositado pela CMJ, adiantamento já pago |
| Total a pagar | total - descontos |
| Assinaturas | engenheiro da CMJ e empreiteiro, local e data |

## 2. Problemas da planilha que o sistema elimina

- Fórmulas diferentes no mesmo bloco (algumas linhas multiplicam o "já executado" no lugar do "executado no período"): no sistema a conta é uma só, sempre.
- Códigos repetidos (1.1, 1.2 aparecem várias vezes) e fatores fixos digitados dentro da fórmula (`*0,76`).
- Saldo a executar e acumulado conferidos à mão; nada impede medir mais do que o contratado.
- Descontos digitados de novo todo mês, sem ligação com o que a CMJ já pagou.

## 3. Proposta de modelo (`OBRA`)

| Tabela | O que guarda |
|---|---|
| `OBRA.Contrato_Empreitada` | obra, empreiteiro (`CAD.Pessoa`), objeto, data, situação, valor total contratado, retenção técnica % (se a CMJ usar), arquivo do contrato (anexo) |
| `OBRA.Contrato_Item` | código hierárquico, descrição, local (torre/unidade, ligado a `IMOB` quando couber), unidade de medida, **quantidade contratada**, **preço unitário**, etapa do orçamento da obra; grupos e subtotais pela hierarquia |
| `OBRA.Medicao` | contrato, **número sequencial automático**, mês de referência, data, situação (rascunho, conferida, aprovada, paga, cancelada), quem aprovou, boletim assinado (anexo) |
| `OBRA.Medicao_Item` | item do contrato e **quantidade executada no período**; acumulado anterior, saldo e valor calculados pelo sistema |
| `OBRA.Medicao_Diaria` | pessoa, dias, valor da diária |
| `OBRA.Medicao_Desconto` | pessoa (funcionário do empreiteiro), tipo de desconto (tabela de tipos: FGTS, multa, contribuição, VR, salário, adiantamento...), valor, e, quando for o caso, o **lançamento já pago** pela CMJ a que se refere (evita desconto em dobro ou esquecido) |

Regras:
- Não medir além do contratado (recusa, ou alerta com permissão especial, a definir).
- Ao **aprovar** a medição, o sistema gera o lançamento a pagar no financeiro (origem `MEDICAO`, com lote), com a **referência da medição** no movimento: é o "campo medição" pedido no item 7.
- Boletim de medição em PDF A4 no padrão de relatórios (logomarca da empresa e da obra, subtotais, total, descontos, assinaturas), para imprimir e enviar por e-mail ao empreiteiro.
- O custo medido entra no orçado x realizado da obra e no painel (item 6).

## 4. A confirmar no desenho da `OBRA`

- A CMJ usa retenção técnica (ex.: 5% retido até o fim do serviço)?
- Aditivos de contrato (item novo, mudança de quantidade ou preço): precisam de histórico?
- Medir além do contratado: bloquear ou só alertar?
- Os descontos de funcionários do empreiteiro (FGTS, salário) são pagos pela CMJ por responsabilidade solidária? Devem gerar lançamento próprio ou só abater da medição?
