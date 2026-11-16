# Padrão de Relatórios do SistemaCMJ

Regras para todo relatório e documento impresso ou enviado (pedido 12 do Celso, 16/11/2026). Mesmo espírito do [PADRAO_EMAIL.md](PADRAO_EMAIL.md): sóbrio, profissional, rastreável. Detalhado na fase 9; aplicar desde o primeiro relatório.

## 1. Formato

1. **Papel A4**, retrato por padrão (paisagem quando a largura das colunas pedir), margens de impressão seguras.
2. **Cabeçalho**: logomarca horizontal da empresa (parâmetro `EMPRESA_LOGO_HORIZONTAL`); quando o relatório é de uma obra, também a **logomarca da obra**; título, filtros usados (período, obra, cliente) e data/hora de emissão.
3. **Tabela** zebrada, valores à direita, datas e códigos centralizados, cabeçalho de coluna repetido em toda página.
4. **Subtotais** por grupo quando couber (obra, conta, mês, cliente) e **total geral** no fim, em negrito.
5. **Rodapé** em toda página: razão social e CNPJ (da licença), "Página X de Y", usuário que emitiu e nome da rotina.
6. Formatos brasileiros: `R$ 1.234,56`, `dd/MM/yyyy`; CPF de cliente mascarado quando o documento vai para terceiros.
7. Cores só dos parâmetros (`EMPRESA_COR_PRINCIPAL`, `EMPRESA_COR_SECUNDARIA`); nada fixo no código.

## 2. Saídas

8. Todo relatório linha a linha tem três saídas: **ver na tela**, **imprimir/PDF** (mesmo layout) e **enviar por e-mail** (o PDF vai anexado, pela fila de e-mail do padrão de e-mail, com logomarca da empresa e da obra quando couber).
9. Toda lista/grade também exporta para Excel (CLAUDE.md seção 3.3 item 20).
10. O PDF é gerado pela API com biblioteca gratuita (PdfSharp/MigraDoc ou HTML para PDF; nunca QuestPDF), a partir dos dados devolvidos pela procedure. O SQL monta os dados; o layout fica num modelo por relatório.

## 3. Documentos para clientes e fornecedores

11. **Extrato do cliente** (posição da compra do imóvel): unidade, contrato, parcelas pagas (data, valor, juros/multa/desconto) e a pagar (vencimento, valor atualizado), totais, com logomarca da empresa e da obra. Enviado a pedido do cliente.
12. **Extrato do fornecedor**: valores pagos e a pagar no período, por documento/medição, com totais.
13. Documento para cliente ou fornecedor segue o rodapé "externo" do padrão de e-mail (sem detalhes técnicos, com aviso contra golpe do boleto quando houver boleto).
