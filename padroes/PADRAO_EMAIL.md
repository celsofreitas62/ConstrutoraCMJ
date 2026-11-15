# Padrão de E-mails e Avisos do SistemaCMJ

Todo e-mail automático do sistema (avisos de vencimento a pagar/receber, envio de boleto ao cliente, resumo diário, alertas de falha) segue este padrão. É o mesmo padrão visual e estrutural que o autor usa em produção há anos, adaptado para SQL Server Express (sem Database Mail).

---

## 1. Arquitetura: fila + processador

```
Evento de negócio (procedure / trigger / rotina agendada)
        │  monta assunto + HTML + destinatários + anexos
        ▼
  SIS.Email_Fila  (STATUS: PENDENTE → PROCESSANDO → ENVIADO | ERRO)
        │
        ▼
Serviço da aplicação (agendador interno, a cada 1 min)
        │  captura atômica (UPDLOCK, READPAST), envia por SMTP, grava resultado
        ▼
  SIS.Email_Fila atualizada  +  SIS.Email_Log (histórico)
```

1. **Nunca enviar e-mail de forma síncrona dentro de uma gravação de negócio.** A procedure/trigger só faz um `INSERT` barato na fila. Uma falha de SMTP nunca desfaz a venda, a baixa ou o lançamento.
2. **Fila com idempotência**: `ID_EMAIL` (`uniqueidentifier`), `CHAVE_ORIGEM` (ex.: `BOLETO:12345`) com índice único filtrado para impedir duplicidade do mesmo aviso, `TENTATIVAS`, `PROXIMA_TENTATIVA`, `ULTIMO_ERRO`.
3. **Retentativa só para falha temporária** (timeout, SMTP indisponível, 4xx), com espera progressiva (1, 5, 15, 60 min) e limite de tentativas. Erro permanente (endereço inválido, 5xx definitivo) vai direto para `ERRO`.
4. **Laço isolado**: um e-mail com problema não impede os demais de sair.
5. **Falha no envio gera alerta técnico** para o administrador (endereço em `SIS.Parametro`), nunca para o cliente/usuário final.
6. **Credenciais SMTP** nunca em tabela comum nem no código-fonte: ficam na configuração protegida do serviço (variável de ambiente / arquivo de segredos fora da pasta publicada / DPAPI). Nunca registrar senha, token ou cabeçalho de autenticação em log.

## 2. Montagem (no SQL)

7. **Procedure orquestradora única** por domínio, com roteador por parâmetro `@TipoEmail` (ex.: `FIN.FIN_Email_Orquestrador @TipoEmail = 'VENC_PAGAR' | 'VENC_RECEBER' | 'RESUMO_DIARIO' | 'BOLETO_CLIENTE' ...`), em vez de uma procedure por tipo de e-mail. A procedure de cálculo/negócio **chama** a orquestradora no final; nunca monta HTML dentro da procedure de negócio.
8. **Early return** se a lista de destinatários vier vazia (registra o motivo em `SIS.Log_Erro`, não dá erro).
9. **`@bRunLocal`** (ver PADRAO_SQL regra 36): em teste, todos os e-mails vão só para o endereço de teste, com `[TESTE]` no assunto, e nada é marcado como "já notificado".
10. **Grupos de destinatários** em tabela (`SIS.Grupo_Email` + `SIS.Grupo_Email_Destinatario`), nunca e-mail fixo no código. Um grupo pode misturar e-mails internos e externos: **nunca duplicar grupo** por causa disso. Se for preciso usar contas de envio diferentes (ex.: uma para avisos internos e outra para clientes), a separação é feita na hora do envio por uma function `SIS.fn_SIS_Filtrar_Emails_Por_Dominio(@Emails, @Interno)` (domínio da CMJ = interno; qualquer outro = externo), com um envio independente (e falha isolada) por conta. Padrão: conta interna; conta externa só quando o fluxo for de envio a clientes/terceiros.
11. **HTML montado inline** numa variável `@CorpoHTML` (`NVARCHAR(MAX)`); linhas de tabela concatenadas com `STRING_AGG` (ou `FOR XML PATH('')` + `.value('.','NVARCHAR(MAX)')`, exigindo `QUOTED_IDENTIFIER ON` na criação).
12. **Todo campo concatenado passa por `ISNULL`** (um NULL apaga o HTML inteiro) e todo texto livre digitado pelo usuário é **escapado** (`&`, `<`, `>`) por uma function única (`SIS.fn_SIS_Texto_HTML`) antes de entrar no HTML.
13. **Acentuação**: como o envio é feito pelo serviço da aplicação com `charset=UTF-8` declarado no MIME, o corpo pode ter acento normal. Se algum dia o envio voltar a ser feito pelo Database Mail, converter os acentos do corpo em entidades HTML (`&aacute;`...) com `NCHAR(código)` + `COLLATE Latin1_General_BIN2` (nunca o caractere literal no fonte).
14. **Assunto é sempre texto puro**: nunca entidade HTML no assunto. Acento direto (`N'...'`).
15. **Sem emoji** no assunto e no corpo. Padrão sóbrio.

## 3. Identidade visual

16. **Container** branco centralizado (largura máx. ~700 px), sombra sutil, fonte Arial/Segoe UI, margens internas. CSS **inline** (clientes de e-mail ignoram `<style>` externo e muitos ignoram o do `<head>`).
17. **Cabeçalho colorido por severidade**:
    - Informativo / relatório: **cor principal do cliente**, parâmetro `EMPRESA_COR_PRINCIPAL` (CMJ: vermelho `#D43414`, da logomarca), texto branco, negrito, maiúsculas.
    - Alerta / ação imediata (vencido, falha, divergência): parâmetro `EMAIL_COR_ALERTA` (laranja escuro `#E65100`, diferente da cor da CMJ) **e** a palavra "ALERTA" no cabeçalho, para não depender só da cor.
    - Cores lidas sempre por `SIS.fn_SIS_Parametro_Cor('CHAVE')`, nunca escritas no código (decidido em 15/11/2026: o sistema serve a outro cliente só trocando parâmetros).
    - Sucesso / confirmação (pagamento recebido): parâmetro `EMAIL_COR_SUCESSO` (verde `#2E7D32`).
    - **Logomarca** no topo do e-mail: arquivo do parâmetro `EMPRESA_LOGO_EMAIL` (na pasta `IDENTIDADE_PASTA`), anexado pelo serviço como imagem embutida (CID), nunca link externo.
18. **Tabelas zebradas**: linhas ímpares brancas, pares `#f5f5f5`; bordas discretas `#eeeeee`; **valores à direita**, códigos e datas centralizados; total em negrito na última linha.
19. **Caixas de destaque** para mensagens de atenção (fundo claro da cor da severidade, borda à esquerda na cor forte).
20. **Largura controlada**: antes de acrescentar coluna, tentar unificar duas correlatas (ex.: `Parcela` + `Vencimento` → `3/36 - 10/12/2026`). Pensar na leitura no celular.
21. **Formatos brasileiros**: valores `R$ 1.234,56`; datas `dd/MM/yyyy`; CPF/CNPJ mascarados. Para o **cliente**, mostrar CPF parcialmente mascarado (`***.456.789-**`).
22. **Assunto com o documento rastreador**: `CMJ - Boleto parcela 3/36 - Residencial X apto 104 - venc. 10/12/2026`, `CMJ - Contas a pagar vencendo hoje (12 títulos)`, `CMJ - FALHA no envio de e-mails`.

## 4. Rodapé de rastreio (obrigatório, nesta ordem)

Fundo `#f9f9f9`, letra pequena:

- `Gerado automaticamente pelo sistema SistemaCMJ: [schema].[procedure]` (usar a variável `@NomeProc`, nunca texto fixo)
- `Emitido em: dd/MM/yyyy HH:mm`
- `Grupo de Destinatários: <código do grupo>` (só em e-mail **interno**; no e-mail ao cliente, omitir)
- Assinatura em negrito: **razão social do cliente**, `SIS.fn_SIS_Empresa_Razao_Social()` (vem da licença)

E-mail ao **cliente** (boleto, confirmação de pagamento) tem rodapé próprio, sem detalhes técnicos: razão social, CNPJ, telefone/WhatsApp do financeiro, aviso "não responda este e-mail" se a caixa for só de envio, e aviso contra golpe do boleto ("confira se o beneficiário é ... e o banco é Sicredi 748 antes de pagar").

## 5. Anexos

23. O anexo (PDF do boleto, contrato, extrato) fica em disco; a fila guarda o **caminho** do arquivo. O serviço confere se o arquivo existe antes de enviar; se não existir, o e-mail vai para `ERRO` com motivo claro (não é enviado sem o anexo).
24. Nome do arquivo anexo legível para o cliente: `Boleto_CMJ_Parcela_03-36_Venc_2026-12-10.pdf` (sem acento, sem espaço).

## 6. Testes

25. Nunca testar com o e-mail real de um cliente, fornecedor ou funcionário. Endereço de teste externo do autor: `celsofreitas62@gmail.com` (cadastrar em `SIS.Parametro`, chave `EMAIL_TESTE`).
26. Teste de verdade passa pelo caminho real (procedure → fila → serviço → SMTP), não só pela procedure.
