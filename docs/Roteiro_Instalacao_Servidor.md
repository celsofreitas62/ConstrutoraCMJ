# Roteiro de instalação do SisCMJ no servidor da CMJ

Versão 1.0 (20/11/2026, conversa 03d2). Escrito a partir do ensaio no notebook (serviço `SisCMJ_Ensaio`, porta 5445). **Manter atualizado a cada mudança no instalador, no MASTER ou no modo de trabalhar.**

Quem executa: **Celso**, como administrador do servidor. Tempo estimado: **2 a 3 horas** na primeira instalação (sem a migração do Access, que é a virada, fase 8).

Convenções: `[ ]` = marcar quando feito. **⚠️** = ponto em que um erro dá trabalho para desfazer.

---

## 0. Visão geral

| Etapa | Onde | O quê |
|---|---|---|
| 1 | notebook do Celso | gerar o pacote, separar senhas, conferir pendências da CMJ |
| 2 | servidor | preparar o Windows (nome, IP fixo, energia, discos) |
| 3 | servidor | instalar SQL Server 2025 Express, SSMS e .NET 10 |
| 4 | servidor | copiar o pacote |
| 5 | servidor (SSMS) | criar o banco, rodar o MASTER, ajustar parâmetros |
| 6 | servidor | instalar o serviço (instalador como administrador) |
| 7 | notebook → servidor | licença |
| 8 | servidor | primeiro acesso (senhas dos administradores) |
| 9 | servidor | e-mail do sistema |
| 10 | computadores dos usuários | certificado e atalho |
| 11 | servidor e um computador de usuário | conferências finais (inclui um ensaio de restauração) |
| 12 | com o técnico | acesso de fora (VPN) |
| 13 | fase 8 | migração do Access e virada |
| 14 | sempre que houver versão nova | atualização |

---

## 1. Antes de ir (no notebook)

- [ ] **Pacote atualizado**: `api\publicar.cmd` (ou pedir ao Claude). Sai em `C:\SisCMJ_Publicacao\SisCMJ_<versão>_<data>\` com `programa\`, `sql\` (00_Criar_Banco, MASTER, MIGRACAO), `instalacao\`, `identidade\` e `LEIA-ME.txt`. Conferir no `LEIA-ME.txt` a versão do programa e do banco.
- [ ] Ensaio do mesmo pacote no notebook (`instalacao\ensaio\ensaio_instalar_notebook.cmd`, como administrador) sem erro.
- [ ] **Senhas à mão** (gerenciador de senhas, nunca em arquivo na pasta do Drive): administrador do Windows do servidor; senha da chave privada da licença; senha de app do Gmail da CMJ (item 9); as senhas que você vai definir para `celso` e `admin` no primeiro acesso.
- [ ] **Pendências da CMJ resolvidas ou aceitas** (CLAUDE.md, seção 6):
  - questionário do técnico (`CashBookCMJ/Preparacao_Servidor_TI_CMJ.docx`): IP fixo, rede, firewall do roteador, VPN, sincronização do Google Drive;
  - **Gmail `construtora.m.judice@gmail.com` com verificação em duas etapas ligada** e uma **senha de app** criada para o SisCMJ (sem isso o Gmail não aceita envio por programa);
  - nobreak (responsabilidade da CMJ);
  - CNPJ da CMJ para a licença: **25.686.528/0001-97** (Construtora Marcílio Judice Ltda.).
- [ ] Forma de levar o pacote ao servidor: pasta do Google Drive ou cópia pela rede/acesso remoto (pen drive não é usado).

## 2. Preparar o servidor (Windows 11 Pro; Ryzen 5, 16 GB, SSD 240 GB + HD 1 TB)

- [ ] Windows atualizado (Windows Update até não ter mais nada) e reiniciado.
- [ ] Entrar com um usuário **administrador**.
- [ ] **Nome do computador** definitivo (ex.: `SERVIDOR-CMJ`). ⚠️ Trocar o nome depois exige refazer o certificado (instalador de novo) e o atalho dos usuários.
- [ ] **IP fixo** (no Windows ou reserva no roteador, com o técnico). Anotar: IP ____________.
- [ ] Energia: **nunca suspender nem hibernar** (Configurações › Sistema › Energia); o disco não desliga. Ligar sozinho depois de falta de luz, se a placa permitir (BIOS).
- [ ] Discos: SSD = Windows, SQL Server e banco; **HD de 1 TB = backups, na pasta `D:\SisCMJ_Backup`** (decidido pelo Celso em 20/11/2026). Backup em outro disco protege contra a falha do SSD. Conferir a letra do HD no servidor; se não for `D:`, ajustar no parâmetro `BACKUP_PASTA` (item 5).
- [ ] Google Drive para computador já instalado e sincronizando de madrugada (informação da CMJ). Anotar a pasta que sincroniza: ____________ (ex.: `G:\Meu Drive\SisCMJ_Backup` ou uma pasta espelhada). Vai no parâmetro `BACKUP_PASTA_EXTERNA` (cópia **sem senha**, decisão de 20/11/2026).
- [ ] Antivírus: se houver um além do Defender, excluir a pasta do banco do SQL e a pasta de backups da varredura em tempo real (pedir ao técnico).

## 3. Instalar SQL Server, SSMS e .NET

- [ ] **SQL Server 2025 Express** (download gratuito da Microsoft), instalação **Personalizada**:
  - só **Mecanismo de Banco de Dados** (Database Engine);
  - instância nomeada **`SQL2025`** (o instalador do SisCMJ usa `.\SQL2025`; outro nome = passar `-Instancia` no passo 6);
  - collation **`Latin1_General_CI_AS`**;
  - autenticação: Windows (o SisCMJ não usa senha de SQL); modo misto é opcional;
  - administrador do SQL: o seu usuário do Windows;
  - serviço com início **automático**.
  - O SQL **não** precisa ser aberto na rede: o sistema roda no próprio servidor.
- [ ] **SSMS** (versão atual).
- [ ] **.NET 10: ASP.NET Core Runtime – Hosting Bundle** (download da Microsoft). O instalador confere e para se faltar.
- [ ] Reiniciar o servidor.

## 4. Copiar o pacote

- [ ] Copiar a pasta `SisCMJ_<versão>_<data>` inteira para o servidor, **fora** da pasta do Google Drive (ex.: `C:\SisCMJ_Instalacao\SisCMJ_<versão>_<data>`).

## 5. Banco de dados (SSMS)

- [ ] Abrir o SSMS e conectar em `.\SQL2025`.
- [ ] Arquivo › Abrir › `sql\SISTEMACMJ_00_Criar_Banco.sql` › **F5**. Cria o banco `SISTEMACMJ`.
- [ ] Selecionar o banco **SISTEMACMJ** na barra do SSMS; Arquivo › Abrir › `sql\SISTEMACMJ_MASTER_Instalacao.sql` › conferir o banco › **F5**. No fim aparece "Versão do banco registrada: x.y". Roda de novo sem erro (idempotente).
- [ ] **Não** rodar o `SISTEMACMJ_MIGRACAO_Instalacao.sql` agora: só na virada (item 13).
- [ ] **Parâmetros que precisam estar certos antes do instalador** (a tela de Parâmetros ainda não existe; por enquanto pelo SSMS, no banco SISTEMACMJ):

```sql
-- Ajustar os valores entre aspas e rodar (F5). Conferir com o SELECT do fim.
UPDATE SIS.Parametro SET VALOR = N'D:\SisCMJ_Backup'                  WHERE CHAVE = 'BACKUP_PASTA';          -- HD de 1 TB
UPDATE SIS.Parametro SET VALOR = N'<pasta sincronizada com o Drive>'  WHERE CHAVE = 'BACKUP_PASTA_EXTERNA';  -- vazio = não copia
UPDATE SIS.Parametro SET VALOR = N'celsofreitas62@gmail.com'          WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';    -- avisos de backup e restauração
SELECT CHAVE, VALOR FROM SIS.Parametro WHERE CHAVE LIKE 'BACKUP%' OR CHAVE = 'EMAIL_ADMIN_ALERTA' ORDER BY CHAVE;
```

  Outros parâmetros de backup (padrões): 7 dias guardados na pasta, 1 completo na nuvem, avisos de atraso (26 h completo, 3 h log, 8 dias teste), motivo da restauração com 10 letras.

## 6. Instalar o serviço

- [ ] Em `instalacao\`, botão direito em **`instalar_servico.cmd`** › **Executar como administrador**. Parâmetros, se precisar mudar o padrão (escrever depois do nome, numa janela de comando como administrador):
  - `-Instancia .\SQL2025` · `-Banco SISTEMACMJ` · `-Porta 5443` · `-NomeServico SisCMJ`
  - `-HoraBackupCompleto 23:00` (antes da sincronização do Drive de madrugada)
  - `-RedesPermitidas LocalSubnet` (mais a rede da VPN, quando existir: item 12)
  - `-NomesExtras` nomes/IPs extras no certificado (ex.: o IP fixo), separados por vírgula
- [ ] O instalador faz, em 10 passos: conferências; programa em `C:\SisCMJ\programa`; serviço **SisCMJ** (início automático atrasado, reinicia se cair); permissões; configuração em `C:\ProgramData\SisCMJ\appsettings.Servidor.json`; acesso do serviço ao banco sem senha; **certificado HTTPS** (5 anos); **firewall** só na porta 5443 e na rede local; inicia e confere `/api/saude`; **backup** (tarefas do Windows como SYSTEM: completo diário, log de hora em hora, teste de restauração aos domingos 4h, pedidos de restauração da tela a cada minuto) e roda **um backup completo e um teste na hora**.
- [ ] Conferir no fim: "Backup completo (agora): OK" e "Teste de restauracao (agora): OK". Erro: ver `<pasta de backup>\backup.log`.
- [ ] Guardar o que o instalador deixou na pasta `instalacao\`: `codigo_servidor.txt` (item 7), `SisCMJ_certificado.cer` e `preparar_computador_usuario.cmd` (item 10), `instalacao_<data>.log`.

## 7. Licença

- [ ] Copiar o **código do servidor** de `codigo_servidor.txt`.
- [ ] No notebook: `api\gerar_licenca.cmd` › opção **2) Gerar uma licença** › senha da chave privada › código do servidor, **CNPJ 25.686.528/0001-97**, razão social **Construtora Marcílio Judice Ltda.**, módulos liberados (sem validade). ⚠️ Nunca levar o gerador nem a chave privada para o servidor.
- [ ] Copiar o arquivo gerado para o servidor como **`C:\ProgramData\SisCMJ\licenca.lic`**. Vale em até 1 minuto, sem reiniciar. Sem licença, o sistema abre bloqueado mostrando o código do servidor.

## 8. Primeiro acesso

- [ ] No servidor: **`https://localhost:5443/instalacao.html`**. Definir as senhas de **`celso`** (administrador geral, nível 2) e **`admin`** (administrador da CMJ, nível 1: Renata, por enquanto com este login). Só funciona enquanto os administradores não têm senha.
- [ ] Entrar em `https://localhost:5443` como `celso` e conferir o menu.

## 9. E-mail do sistema

Decisão de 20/11/2026: até a CMJ ter o e-mail do domínio próprio, **tudo sai pelo Gmail `construtora.m.judice@gmail.com`** (conta Interna). O Hotmail não é usado para envio (a Microsoft exige OAuth2).

- [ ] Abrir **`C:\ProgramData\SisCMJ\appsettings.Servidor.json`** (Bloco de Notas como administrador) e preencher a seção `Smtp` › `Interna`:
  - `Servidor`: `smtp.gmail.com` · `Porta`: `587`
  - `Usuario` e `Remetente`: `construtora.m.judice@gmail.com`
  - `Senha`: a **senha de app** do Gmail (16 letras, sem espaços)
  - `NomeRemetente` (opcional): `Construtora CMJ`
  - `Externa`: deixar vazia. Quando o e-mail do domínio existir, preencher a `Externa` (servidor, porta, usuário, remetente, senha) e ele passa a ser usado para clientes e fornecedores sem mexer no programa.
- [ ] `Restart-Service SisCMJ` (PowerShell como administrador) ou reiniciar o serviço em `services.msc`.
- [ ] Testar: comunicado de teste ou um aviso (item 11). Se a saída na porta 587 estiver bloqueada, falar com o técnico.

## 10. Computadores dos usuários

- [ ] Copiar `SisCMJ_certificado.cer` e `preparar_computador_usuario.cmd` para cada computador (Renata e demais).
- [ ] Botão direito no `.cmd` › **Executar como administrador** (uma vez): instala o certificado e cria o atalho **SisCMJ** na área de trabalho (`https://<nome do servidor>:5443/`).
- [ ] Abrir o atalho, entrar e conferir: sem aviso de "conexão não segura".

## 11. Conferências finais

- [ ] `https://localhost:5443/api/saude` mostra `"situacao": "ok"` (banco no ar, versão do programa e do banco iguais, licença válida).
- [ ] Em um computador de usuário, o sistema abre pelo atalho (firewall e certificado OK).
- [ ] **Sistema › Backups › Backups e restauração**: backup completo e teste OK; depois da próxima hora e meia aparece o primeiro **backup de hora em hora**.
- [ ] **Ensaio de restauração no servidor** (agora, com o banco ainda vazio, sem risco): aba Restaurar › escolher o ponto mais recente › motivo, RESTAURAR, senha. Em até 2 minutos o pedido fica **Concluída** e chega o e-mail de resultado. Confere a tarefa, o serviço (para e volta) e o e-mail de uma vez.
- [ ] No dia seguinte: o arquivo `.bak` das 23h está na pasta do Drive (`BACKUP_PASTA_EXTERNA`) e sincronizado na nuvem.
- [ ] Registrar no diário (`docs/DIARIO_DECISOES.md`): data, versão, nome e IP do servidor, pastas, o que fugiu do roteiro.

## 12. Acesso de fora (VPN)

Decidido em 19/11/2026 (P08): **VPN** para a Renata (home office) e, depois da virada, para os proprietários (celular: módulo pago à parte). Depende das respostas do técnico (WireGuard no roteador ou no servidor). Quando estiver pronto:

- [ ] Rodar o instalador de novo com `-RedesPermitidas LocalSubnet,<rede da VPN>` (ex.: `10.8.0.0/24`) e, se o endereço pela VPN for outro, `-NomesExtras`.
- [ ] Testar do notebook da Renata, fora da rede da CMJ.

## 13. Migração do Access e virada (fase 8, roteiro detalhado a escrever)

O que já está decidido e entra no roteiro da virada:

1. Cópia **atualizada** do Access (`CashBookCMJ_be.mdb`) do dia.
2. SSMS: `sql\SISTEMACMJ_MIGRACAO_Instalacao.sql` no banco SISTEMACMJ (schema MIG; fica só até terminar os casos).
3. No notebook, tela **Casos da migração** › **Baixar correções** (`correcoes.sql`): rodar no servidor **depois** da migração instalada e **antes** de migrar.
4. Extração do Access, carga, transformação e **conferência dos totais com a Renata** (corte em 01/01/2022; antes disso, arquivo morto).
5. **Saldo inicial de cada conta = extrato do dia da virada**; movimento anterior nunca altera saldo.
6. Uso em paralelo com o Access pelo tempo combinado; treinamento.
7. Depois da virada: a Renata resolve os casos restantes; **"Migrar casos resolvidos"** (administrador geral).

## 14. Atualização (versão nova)

1. No notebook: `api\publicar.cmd`, ensaio no notebook.
2. Avisar os usuários (o sistema fica fora do ar 1 a 2 minutos).
3. No servidor: SSMS › **MASTER novo** no banco SISTEMACMJ (F5). Depois, **`instalar_servico.cmd` do pacote novo** como administrador (atualiza o programa e as tarefas; não perde configuração, licença nem dados).
4. Conferir `/api/saude` e a tela de backups.
5. ⚠️ Depois de cada atualização de versão, a restauração pela tela **só volta até o momento da atualização** (backups de versão anterior aparecem como indisponíveis). Voltar para antes: só com o Celso, restaurando pelo SSMS e rodando o MASTER de novo.

## 15. Se algo der errado

| Onde olhar | O quê |
|---|---|
| `instalacao\instalacao_<data>.log` | tudo o que o instalador fez |
| `C:\ProgramData\SisCMJ\logs\` | registro da API (erros, avisos, pedidos de restauração) |
| `<pasta de backup>\backup.log` | cada backup, teste e restauração, passo a passo |
| SSMS: `SELECT TOP 50 * FROM SIS.Log_Erro ORDER BY ID_LOG_ERRO DESC` | erros dentro do banco (a tela Log de erros vem na fase 4) |
| `services.msc` | serviço **SisCMJ** (iniciar/parar) |
| Agendador de Tarefas › tarefas `SisCMJ (SisCMJ) - ...` | backup completo, log, teste, restauração (pedidos) |

- Desinstalar (programa, serviço, firewall, tarefas; **não** apaga o banco nem os backups): `instalacao\desinstalar_servico.cmd` como administrador.
- Restaurar sem a tela (servidor sem o serviço): SSMS › restaurar o último `_COMPLETO_*.bak` e os `_LOG_*.trn` seguintes da pasta de backup.
