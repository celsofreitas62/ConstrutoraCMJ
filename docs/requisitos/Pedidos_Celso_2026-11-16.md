# Pedidos do Celso em 16/11/2026 (12 itens)

Registrados antes da etapa 02c. Respostas do Celso às dúvidas no fim.

| Nº | Pedido | Onde entra | Como fica |
|---|---|---|---|
| 1 | Mensagens de erro em janela (pop-up) com OK para prosseguir | Padrão das telas (`padroes/PADRAO_TELAS.md`), fases 3 e 4 | Toda recusa ou erro devolvido pela procedure (`SUCESSO = 0`, ou erro 50001 nas "Listar") abre janela que só fecha no OK. |
| 2 | Instalação de serviços do Windows pelo menu do administrador geral, e outros que surgirem, tudo pelo sistema | Tela **Instalação e manutenção** (exclusiva do administrador geral). SQL na 02d; botões na fase da API | O SQL nunca executa comando do Windows. O botão grava um pedido numa fila (`SIS`); o serviço do sistema executa uma **lista fixa** de comandos e grava saída e resultado. Só no próprio servidor ou com a senha pedida de novo; tudo auditado. A primeira instalação (SQL Express, .NET e o próprio serviço) fica num **instalador único** rodado uma vez como administrador. |
| 3 | Ajuda só para o administrador geral (instalação, configurações que só ele controla) | Ajuda do sistema (CLAUDE.md seção 3, item 9) | Páginas de ajuda marcadas como exclusivas: a API só entrega ao nível 2. **03g-A feita (22/11/2026)**: tela Sistema › Configuração › Ajuda do administrador geral, páginas Instalação, Licença e Diagnóstico; **03g-B feita (22/11/2026)**: 9 páginas no total, Parâmetros e Comandos lidos do banco; banco 1.7. |
| 4 | Todo comando de instalação tem botão ou item de menu | Junto com o item 2 | Cada comando do roteiro de instalação vira um botão da tela Instalação e manutenção (criar banco, rodar MASTER, aplicar atualização, backup agora, teste de restauração, instalar/reiniciar serviço, regra de firewall, certificado HTTPS...). |
| 5 | O administrador geral **habilita** os módulos (cadastros, contas a pagar, a receber, painel...), para desenvolver módulos sem liberar de imediato | **Ajuste na 02c** | Chave `HABILITADO` em `SIS.Modulo` **e** em `SIS.Item` (tela), só o nível 2 liga. Aparece para uso só o que está **na licença e habilitado** (módulo e tela). |
| 6 | Painel gerencial: obras em andamento em gráfico financeiro, clique na obra abre detalhes em gráfico, drill-down a cada clique (custo, vendas...) | `GER`, fase 9 | Obra > orçado x realizado, vendas, recebido, a receber > etapas > lançamentos. |
| 7 | Campo "medição" do prestador de serviço no movimento | `OBRA` (fase 8) + `FIN` | **Controle completo de medição de empreitada**: ver `docs/requisitos/Medicao_Empreitada.md`. O lançamento gerado pela medição leva a referência dela. |
| 8 | Campos de juros pago, desconto etc. no movimento | `FIN.Baixa` (CLAUDE.md seção 3.2) | Juros, multa, desconto, abatimento, tarifa bancária, correção monetária e retenções (ISS, INSS, IR, PIS/COFINS/CSLL), cada um no seu campo. |
| 9 | Ver o lote: grade com os lançamentos do lote; clique abre o movimento | Tela de movimento (fase 6); `SIS.Lote` na 02c | Como na seção 3.1 item 2, com o detalhe da tela. |
| 10 | Mês fechado: impedir lançamento depois do fechamento contábil entregue, para os que forem contábeis | `FIN`, seção 3.3 item 10 | Fechado o mês, ficam bloqueados só os lançamentos em conta **marcada como contábil** no plano de contas; gerenciais e previsões continuam livres. Reabrir só com permissão e registro. |
| 11 | Analisar o plano de contas de 3 níveis e propor melhoria; níveis sempre alinhados (3 > 2 > 1) para o painel | `CAD`, **etapa 03** | Só o nível 3 recebe lançamento; todo nível 3 ligado a um nível 2, que se liga a um nível 1 (garantido por chave estrangeira). Análise do plano do Access + proposta no início da etapa 03. |
| 12 | Relatórios linha a linha: impressão A4 profissional com subtotal e total; envio por e-mail com logomarca da empresa e da obra; extrato para cliente (parcelas pagas e a pagar) e fornecedor (pago e a pagar) | Padrão de relatórios (`padroes/PADRAO_RELATORIOS.md`), fase 9 e telas de cada módulo | PDF gerado pela API, mesmo layout para imprimir e enviar. |

## Respostas do Celso (16/11/2026)

- **Medição (7)**: ver a planilha `PlanilhasCMJ/Medição.xlsx` → é o controle completo de medição de empreitada.
- **Mês fechado (10)**: sim, bloqueia só os lançamentos contábeis.
- **Habilitar (5)**: por módulo **e** por tela.
- **Plano de contas (11)**: análise na etapa 03.
