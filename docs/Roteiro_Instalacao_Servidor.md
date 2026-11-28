# Roteiro de instalação do SisCMJ no servidor da CMJ

Versão 1.3 (22/11/2026, conversa 04a: um usuário por pessoa pela tela de Usuários, item 8). Versão 1.2 (22/11/2026, conversa 03h: atualização em um clique, item 14). Versão 1.1 (22/11/2026, conversa 03e). Versão 1.0 de 20/11/2026 (03d2), escrita a partir do ensaio no notebook; v1.1 com os achados do ensaio num Windows limpo (máquina virtual, 3d-C). **Manter atualizado a cada mudança no instalador, no MASTER ou no modo de trabalhar.**

Quem executa: **Celso**, como administrador do servidor. Tempo estimado: **2 a 3 horas** na primeira instalação (sem a migração do Access, que é a virada, fase 8).

Convenções: `[ ]` = marcar quando feito. **⚠️** = ponto em que um erro dá trabalho para desfazer.

## Regras de ouro (pedido do Celso, 22/11/2026)

1. **Ensaiar toda versão nova na máquina virtual antes de levar à CMJ.** Leva uns 10 minutos com os scripts prontos (como fazer: item 14).
2. **Pedir IP fixo e rede Privada ao técnico como pré-requisito**, antes de marcar o dia da instalação (item 1). Sem isso, os usuários podem não conseguir entrar no sistema.
3. **Guardar a chave do BitLocker do servidor junto com a chave da licença.** As duas são as "chaves de casa" do sistema: sem a do BitLocker, uma troca de placa ou de disco pode deixar o banco e os backups ilegíveis; sem a da licença, não se gera licença nova. Lugar: gerenciador de senhas do Celso + cópia no Google Drive dele (como a chave da licença) e uma cópia impressa guardada pela CMJ (item 2).

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
  - **pré-requisito para marcar o dia (regra de ouro 2)**: o técnico confirmou o **IP fixo** do servidor e que a rede dele fica como **Privada**; e respondeu se o **nome do servidor é achado** pelos outros computadores (senão, instalar com `-EnderecoUsuarios <IP fixo>`, item 6);
  - nobreak (responsabilidade da CMJ);
  - CNPJ da CMJ para a licença: **25.686.528/0001-97** (Construtora Marcílio Judice Ltda.).
- [ ] **Levantamento do servidor** (desde 28/11/2026, P28a): no servidor, `instalacao\levantamento_servidor.cmd` do pacote (ou da pasta do projeto) › Executar como administrador. Só lê, não muda nada; grava `levantamento_<computador>_<data>.txt` com os pontos de atenção (IP por DHCP, rede Pública, falta de D:, BitLocker, SQL já instalado, .NET, sqlcmd, saída HTTPS e SMTP 587, antivírus). Resolver os pontos antes de marcar o dia.
- [ ] Forma de levar o pacote ao servidor: pasta do Google Drive ou cópia pela rede/acesso remoto (pen drive não é usado).

## 2. Preparar o servidor (Windows 11 Pro; Ryzen 5, 16 GB, SSD 240 GB + HD 1 TB)

- [ ] Windows atualizado (Windows Update até não ter mais nada) e reiniciado.
- [ ] Entrar com um usuário **administrador**.
- [ ] **Nome do computador** definitivo (ex.: `SERVIDOR-CMJ`). ⚠️ Trocar o nome depois exige refazer o certificado (instalador de novo) e o atalho dos usuários.
- [ ] **IP fixo** (no Windows ou reserva no roteador, com o técnico). Anotar: IP ____________. Fazer **antes** do instalador (item 6): o certificado grava os IPs do servidor.
- [ ] **Rede como Privada** (Configurações › Rede e Internet › a conexão › Tipo de perfil de rede › **Rede privada**). O Windows marca rede nova como **Pública**, e aí o firewall não deixa os usuários entrarem (achado no ensaio 3d-C; o instalador v1.6 para com aviso se encontrar rede Pública).
- [ ] **O nome do servidor é achado na rede?** De outro computador da CMJ, abrir o Prompt de Comando e rodar `ping <nome do servidor>`. Se responder, os usuários usam o nome. Se der "não pôde encontrar o host" (comum em rede pequena; aconteceu no ensaio), usar o **IP fixo** no item 6 (`-EnderecoUsuarios <IP fixo>`) ou pedir ao técnico para cadastrar o nome no roteador/DNS. Anotar a escolha: ____________.
- [ ] Energia: **nunca suspender nem hibernar** (Configurações › Sistema › Energia); o disco não desliga. Ligar sozinho depois de falta de luz, se a placa permitir (BIOS).
- [ ] Discos: SSD = Windows, SQL Server e banco; **HD de 1 TB = backups, na pasta `D:\SisCMJ_Backup`** (decidido pelo Celso em 20/11/2026). Backup em outro disco protege contra a falha do SSD. Conferir a letra do HD no servidor; se não for `D:`, ajustar no parâmetro `BACKUP_PASTA` (item 5).
- [ ] Google Drive para computador já instalado e sincronizando de madrugada (informação da CMJ). Anotar a pasta que sincroniza: ____________ (ex.: `G:\Meu Drive\SisCMJ_Backup` ou uma pasta espelhada). Vai no parâmetro `BACKUP_PASTA_EXTERNA` (cópia **sem senha**, decisão de 20/11/2026).
- [ ] **BitLocker**: o Windows 11 pode criptografar o C: (e discos novos) sozinho (achado no ensaio 3d-C). Conferir em Configurações › Privacidade e segurança › Criptografia do dispositivo (ou Gerenciamento de Disco: "BitLocker Criptografado"). Se estiver ligado: **guardar a chave de recuperação junto com a chave da licença** (regra de ouro 3: gerenciador de senhas e Google Drive do Celso, e cópia impressa com a CMJ); sem ela, uma troca de placa ou de disco pode deixar o banco e os backups ilegíveis.
- [ ] Antivírus: se houver um além do Defender, excluir a pasta do banco do SQL e a pasta de backups da varredura em tempo real (pedir ao técnico).

## 3. Instalar SQL Server, SSMS e .NET

- [ ] **SQL Server 2025 Express** (download gratuito da Microsoft), instalação **Personalizada**:
  - só **Mecanismo de Banco de Dados** (Database Engine);
  - instância nomeada **`SQL2025`** (o instalador do SisCMJ usa `.\SQL2025`; outro nome = passar `-Instancia` no passo 6);
  - ⚠️ o campo **ID da instância** não acompanha o nome sozinho (fica `SQLEXPRESS`): trocar também para **`SQL2025`** (pasta `MSSQL17.SQL2025`; achado no ensaio 3d-C, 21/11/2026);
  - collation **`Latin1_General_CI_AS`**;
  - autenticação: Windows (o SisCMJ não usa senha de SQL); modo misto é opcional;
  - SSMS novo: no primeiro uso, "Ignorar e adicionar contas mais tarde" (não precisa de conta Microsoft/GitHub); ao conectar em `.\SQL2025`, marcar **"Confiar no certificado do servidor"**;
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
  - `-EnderecoUsuarios <nome ou IP fixo>`: o endereço que vai no atalho dos usuários e no certificado (padrão: o nome do servidor). Usar o **IP fixo** se o nome não for achado na rede (item 2). Exemplo: `instalar_servico.cmd -EnderecoUsuarios 192.168.0.10` numa janela de comando como administrador.
  - `-NomesExtras` nomes/IPs extras no certificado (ex.: o endereço pela VPN), separados por vírgula
- [ ] O instalador faz, em 10 passos: conferências; programa em `C:\SisCMJ\programa`; serviço **SisCMJ** (início automático atrasado, reinicia se cair); permissões; configuração em `C:\ProgramData\SisCMJ\appsettings.Servidor.json`; acesso do serviço ao banco sem senha; **certificado HTTPS** (5 anos); **firewall** só na porta 5443 e na rede local; inicia e confere `/api/saude`; **backup** (tarefas do Windows como SYSTEM: completo diário, log de hora em hora, teste de restauração aos domingos 4h, pedidos de restauração da tela a cada minuto) e roda **um backup completo e um teste na hora**.
- [ ] Conferir no fim: "Backup completo (agora): OK" e "Teste de restauracao (agora): OK". Erro: ver `<pasta de backup>\backup.log`.
- [ ] Guardar o que o instalador deixou na pasta `instalacao\`: `codigo_servidor.txt` (item 7), `SisCMJ_certificado.cer` e `preparar_computador_usuario.cmd` (item 10), `instalacao_<data>.log`.

## 7. Licença

- [ ] Copiar o **código do servidor** de `codigo_servidor.txt`.
- [ ] No notebook: `api\gerar_licenca.cmd` › opção **2) Gerar uma licença** › senha da chave privada › código do servidor, **CNPJ 25.686.528/0001-97**, razão social **Construtora Marcílio Judice Ltda.**, módulos liberados (sem validade). ⚠️ Nunca levar o gerador nem a chave privada para o servidor.
- [ ] Copiar o arquivo gerado para o servidor como **`C:\ProgramData\SisCMJ\licenca.lic`**. Vale em até 1 minuto, sem reiniciar. Sem licença, o sistema abre bloqueado mostrando o código do servidor.

## 8. Primeiro acesso

- [ ] ⚠️ Digitar sempre o endereço **com `https://`**: sem ele o navegador tenta `http` e mostra "não enviou dados" (ERR_EMPTY_RESPONSE), parecendo que o sistema caiu (achado no ensaio 3d-C). O atalho dos usuários (item 10) já vai com `https://`.
- [ ] No servidor: **`https://localhost:5443/instalacao.html`**. Definir as senhas de **`celso`** (administrador geral, nível 2) e **`admin`** (administrador da CMJ, nível 1). Só funciona enquanto os administradores não têm senha.
- [ ] Entrar em `https://localhost:5443` como `celso` e conferir o menu.
- [ ] **Um usuário por pessoa** (desde a 1.9): em **Sistema › Segurança › Usuários**, incluir **`renata`** (perfil Administrador) e quem mais for usar, cada um com o seu perfil (Financeiro, Consulta ou outro criado em Perfis e permissões). Cada usuário nasce com a senha provisória padrão (`@12345`, parâmetro `SENHA_PROVISORIA_PADRAO`), que vale **24 horas**: passar pessoalmente e pedir para entrar no mesmo dia. O `admin` fica guardado só para emergência (senha no gerenciador de senhas).

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
- [ ] Botão direito no `.cmd` › **Executar como administrador** (uma vez): instala o certificado (tirando o antigo, se houver) e cria o atalho **SisCMJ** na área de trabalho (`https://<endereço dos usuários>:5443/`). Se o instalador avisar **"certificado NOVO"** numa atualização, rodar o `.cmd` de novo em todos os computadores.
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

**Atualização em um clique** (desde a versão 1.8, conversa 03h): o pacote traz o `atualizar.cmd` na raiz, que faz tudo sozinho e volta para a versão anterior se algo falhar.

1. No notebook: escrever a nota da versão em `docs/NOTAS_DA_VERSAO.md` (seção `## <versão do banco>`; o publicar recusa sem ela) e rodar `api\publicar.cmd` (ou pedir ao Claude).
1a. **Ensaio na máquina virtual (regra de ouro 1)**: a VM `SisCMJ-Servidor-Ensaio` fica no Hyper-V do notebook, desligada. Scripts em `instalacao\ensaio\`, todos como administrador:
   - `ligar_vm_hyperv.cmd` (não apertar tecla no boot; entrar como `AdminCMJ`);
   - `copiar_pacote_vm.cmd` (leva o pacote mais novo para `C:\SisCMJ_Instalacao\` dentro da VM);
   - na VM: **`atualizar.cmd` do pacote novo** (botão direito › Executar como administrador) e conferir que terminou com **ATUALIZAÇÃO CONCLUÍDA**;
   - conferir uma tela que mudou; se a versão mexe em backup, um ensaio de restauração pela tela;
   - só depois levar à CMJ. Se a VM sumir ou a avaliação do Windows (90 dias) vencer: `criar_vm_hyperv.cmd` cria outra, e o roteiro deste documento instala de novo.
2. Avisar os usuários (o sistema fica fora do ar de 1 a 3 minutos). O `atualizar.cmd` mostra quem está usando o sistema antes de começar.
3. No servidor: copiar o pacote e rodar o **`atualizar.cmd`** (botão direito › Executar como administrador). Ele faz, nesta ordem:
   - confere as versões: **pacote mais velho que o instalado = recusa** (nunca volta versão); mesma versão = pergunta se reinstala; mostra a nota da versão e pede **S** para continuar;
   - segura a trava do backup (nenhum backup ou restauração roda no meio);
   - para o sistema, faz um **backup de segurança** conferido (`<pasta do backup>\Atualizacao\SISTEMACMJ_ANTES_<versão>_<data>.bak`; não mexe nas cópias diárias) e guarda o programa atual em `C:\SisCMJ\programa_anterior`;
   - roda o **MASTER pelo `sqlcmd`** (exceção aprovada à regra 37 do PADRAO_SQL) e confere a versão do banco;
   - roda o **instalador do pacote com os mesmos parâmetros da instalação** (`C:\ProgramData\SisCMJ\instalacao.json`, gravado pelo instalador v1.7; numa instalação mais antiga ele pergunta uma vez o endereço dos usuários);
   - confere `/api/saude` (situação ok e as versões novas, até 1 minuto);
   - registra no banco (`SIS.Atualizacao`: versões, tempo fora do ar, resultado e a nota da versão) e faz um backup completo da versão nova.
   - ⚠️ **Se algo falhar** depois de parar o sistema: **volta sozinho** (restaura o backup de segurança, se o MASTER chegou a rodar; recoloca o programa anterior; religa e confere) e termina com **ATUALIZAÇÃO DESFEITA** e o motivo; o aviso vai também por e-mail (`EMAIL_ADMIN_ALERTA`). **ATUALIZAÇÃO COM ERRO** = nem a volta funcionou: o Celso resolve pelo SSMS com o backup de segurança e o `programa_anterior`.
   - Precisa do **`sqlcmd`** no servidor; sem ele, para antes de mexer em qualquer coisa e avisa (instalar o sqlcmd ou levar no pacote em `ferramentas\sqlcmd.exe`).
   - Registro: `instalacao\atualizacao_<data>.log` do pacote (cópia em `C:\ProgramData\SisCMJ\logs`) e a saída do MASTER em `instalacao\master_<data>.txt`.
   - Pelo Terminal (PowerShell) como administrador: entrar na pasta do pacote (`cd C:\SisCMJ_Instalacao\SisCMJ_<versão>_<data>`) e rodar **`.\atualizar.cmd`** (o PowerShell exige o `.\` antes do nome).
   - Ensaio da volta (só na VM): `.\atualizar.cmd -EnsaioFalha MASTER` ou `-EnsaioFalha SAUDE` (ensaiado em 22/11/2026: volta OK).
4. Conferir a tela de backups. O backup de segurança pode ser apagado depois de alguns dias.
5. ⚠️ Depois de cada atualização de versão, a restauração pela tela **só volta até o momento da atualização** (backups de versão anterior aparecem como indisponíveis). Voltar para antes: só com o Celso, restaurando pelo SSMS e rodando o MASTER de novo.
6. **Emergência, sem o `atualizar.cmd`** (o jeito antigo): SSMS › MASTER novo no banco SISTEMACMJ (F5) e depois `instalacao\instalar_servico.cmd` do pacote novo como administrador.

## 15. Se algo der errado

| Onde olhar | O quê |
|---|---|
| `instalacao\instalacao_<data>.log` | tudo o que o instalador fez |
| `instalacao\atualizacao_<data>.log` e `master_<data>.txt` | cada atualização em um clique (e a saída do MASTER); histórico no banco: `SELECT * FROM SIS.Atualizacao ORDER BY ID_ATUALIZACAO DESC` |
| `C:\ProgramData\SisCMJ\logs\` | registro da API (erros, avisos, pedidos de restauração) |
| `<pasta de backup>\backup.log` | cada backup, teste e restauração, passo a passo |
| SSMS: `SELECT TOP 50 * FROM SIS.Log_Erro ORDER BY ID_LOG_ERRO DESC` | erros dentro do banco (a tela Log de erros vem na fase 4) |
| `services.msc` | serviço **SisCMJ** (iniciar/parar) |
| Agendador de Tarefas › tarefas `SisCMJ (SisCMJ) - ...` | backup completo, log, teste, restauração (pedidos) |

- Desinstalar (programa, serviço, firewall, tarefas; **não** apaga o banco nem os backups): `instalacao\desinstalar_servico.cmd` como administrador.
- Restaurar sem a tela (servidor sem o serviço): SSMS › restaurar o último `_COMPLETO_*.bak` e os `_LOG_*.trn` seguintes da pasta de backup.
