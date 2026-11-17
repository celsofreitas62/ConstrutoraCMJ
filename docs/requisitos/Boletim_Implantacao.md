# E-mail semanal: boletim da implantação do SistemaCMJ (proposta)

Pedido do Celso em 17/11/2026 (documento "Instruções ao Claude"). Conversa "03c – Financeiro e ensaio da migração".

> **Situação: PROPOSTA, aguardando a aprovação do Celso.** Nada criado.

## 1. O pedido

- E-mail **semanal automático** sobre a evolução da implantação: **o que já foi implantado, o que está em teste e a próxima fase**.
- **Resumido e sem dados técnicos**; não listar tudo o que está pronto no desenvolvimento, só esses três pontos.
- Destinatários em **parâmetro** (grupo de e-mail), hoje:
  - Escritório Construtora Marcílio Judice: construtora.m.judice@gmail.com
  - Danielle M. Judice Daher: dmjdaher@gmail.com
- **Antes de cada envio oficial, o Celso recebe uma prévia para aprovar e liberar.** Sem aprovação, nada sai.
- Acesso (telas e destinatários) só do Celso / administrador geral (nível 2).
- Depois da implantação, o mesmo mecanismo serve para **outros comunicados da empresa**, trocando só o conteúdo.

## 2. Desenho proposto (genérico desde já: "comunicado periódico")

### 2.1 Tabelas (`SIS`)
- `SIS.Comunicado`: um por tipo de comunicado (o primeiro: `BOLETIM_IMPLANTACAO`). Título, grupo de destinatários oficial (`SIS.Grupo_Email`), grupo de aprovação (o Celso), dia da semana e hora da prévia, **exige aprovação** (S/N), ativo (liga/desliga, regra 46).
- `SIS.Comunicado_Item`: os itens do boletim, em linguagem simples, cada um com a seção (`IMPLANTADO` / `EM_TESTE` / `PROXIMA_FASE`), ordem, data e ativo. Ex.: "Cadastro de clientes e fornecedores" em teste. O Claude atualiza os itens no fim de cada fase (por script, junto com o diário); o Celso pode ajustar pela tela.
- `SIS.Comunicado_Edicao`: cada semana gerada: número, período, texto montado (HTML), situação (`PREVIA` → `APROVADA` → `ENVIADA`, ou `DESCARTADA`), quem aprovou e quando, e os e-mails gerados na fila.

### 2.2 Fluxo semanal
1. **Rotina agendada** (`SIS.Rotina`, a do serviço da aplicação; dia e hora em parâmetro, proposta: **sexta-feira, 9h**) monta a edição da semana com os itens ativos e envia a **prévia só para o Celso** (assunto `[PRÉVIA] CMJ - Boletim da implantação - semana 17/11 a 21/11/2026`).
2. O Celso abre a tela **Comunicados** (nível 2), lê, ajusta se quiser e clica **Aprovar e enviar**. Só então o e-mail oficial vai para o grupo `BOLETIM_IMPLANTACAO`.
3. Se não aprovar, a edição fica como prévia e **não sai**; a da semana seguinte substitui a pendente (sem acumular).
4. Visual no padrão `PADRAO_EMAIL.md` (cabeçalho na cor da CMJ, logomarca, três blocos curtos), **sem** o rodapé técnico de rotina/grupo no e-mail oficial (é externo; vai só a assinatura).

### 2.3 Envio de verdade (ponto de atenção)
- O envio usa a fila de e-mail e o SMTP do serviço (já prontos desde a 02d/3b), mas **ainda não existe conta de envio da CMJ** (pendência 10 da seção 6). Proposta: enquanto o e-mail próprio não for definido, usar a conta **construtora.m.judice@gmail.com** como remetente (com "senha de app" do Google, guardada na configuração protegida do serviço, nunca em tabela), ou a do Celso só para a prévia.
- Enquanto o sistema roda só no notebook do Celso, o boletim sai quando o serviço estiver ligado (a rotina recupera a execução perdida). Depois da fase 3d, roda no servidor da CMJ.
- No `SISTEMACMJ_LOCAL` tudo vai só para o e-mail de teste (regra 36).

### 2.4 Quando entra
Proposta: logo depois das tabelas do `FIN` desta etapa (é pequeno: 3 tabelas, 4 procedures, 1 rotina e 1 tela simples), para o primeiro boletim sair ainda nesta semana ou na próxima.

## 3. Perguntas ao Celso
1. Dia e hora da prévia: sexta-feira às 9h está bom?
2. Remetente até a CMJ ter e-mail próprio: pode ser `construtora.m.judice@gmail.com` (precisa criar uma "senha de app" nessa conta)?
3. "Acesso por mim e admin geral do sistema": hoje o administrador geral (nível 2) é só você (`celso`). Ninguém da CMJ (nem a Renata) vê essa tela: confirma?
4. Primeiro texto: proposta de conteúdo inicial na conversa, para você aprovar.
