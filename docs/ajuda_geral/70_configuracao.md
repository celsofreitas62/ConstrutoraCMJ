<!-- pagina: configuracao | titulo: Configuração do servidor | resumo: Pastas, arquivo de configuração, serviço do Windows, certificado HTTPS, firewall e e-mail do sistema. | palavras: appsettings servidor json programdata pasta servico windows conta virtual certificado https firewall porta 5443 smtp gmail externa interna kestrel registro agendador -->

## Pastas no servidor

| Pasta | O que tem | Quem mexe |
|---|---|---|
| `C:\SisCMJ\programa` | o programa (telas e ajuda embutidas no executável) | só o instalador; **só leitura** para o serviço |
| `C:\SisCMJ\scripts` | `backup_servidor.ps1`, usado pelas tarefas de backup | só o instalador |
| `C:\ProgramData\SisCMJ` | `appsettings.Servidor.json`, `licenca.lic` e `logs\` | só administradores e o serviço |
| `C:\SistemaCMJ_Arquivos` | `Anexos`, `Identidade` (logomarcas), `Remessa`, `Retorno`, `OFX`, `Atualizacoes` | o serviço grava |
| `D:\SisCMJ_Backup` | backups (parâmetro `BACKUP_PASTA`) | as tarefas de backup |
| `instalacao\` do pacote | `codigo_servidor.txt`, `SisCMJ_certificado.cer`, `preparar_computador_usuario.cmd`, `instalacao_<data>.log` | guardar |

## Arquivo de configuração (`C:\ProgramData\SisCMJ\appsettings.Servidor.json`)

Criado pelo instalador **só na primeira vez** (depois ele mantém o que está lá). Abrir com o Bloco de Notas como administrador. Depois de mudar: `Restart-Service SisCMJ`.

| Seção | Para quê |
|---|---|
| `ConnectionStrings:SistemaCMJ` | conexão com o banco pela conta do serviço, **sem senha** (`Integrated Security`) |
| `Kestrel:Endpoints:Https:Url` | porta do sistema (padrão `https://*:5443`) |
| `Identidade:PastaReserva` | pasta das logomarcas (`C:\SistemaCMJ_Arquivos\Identidade`) |
| `Smtp:Interna` | conta que envia os e-mails (hoje o Gmail da CMJ): `Servidor`, `Porta`, `Usuario`, `Remetente`, `Senha`, `NomeRemetente` |
| `Smtp:Externa` | conta para clientes e fornecedores; **vazia = usa a Interna** |
| `Agendador:Ligado` | rotinas automáticas (e-mails, avisos); `false` só em ensaio |
| `Registro:Pasta`, `Registro:DiasManter` | registro da API em arquivo (padrão `C:\ProgramData\SisCMJ\logs`, 30 dias) |
| `Licenca:Arquivo` | outro caminho para a licença (padrão `C:\ProgramData\SisCMJ\licenca.lic`) |

⚠️ Este arquivo tem a senha de app do e-mail: **nunca copiar para o projeto, o Drive ou o Git.**

## Serviço do Windows

- Nome **SisCMJ** (`-NomeServico` do instalador), conta virtual **`NT SERVICE\SisCMJ`**, sem senha, com acesso ao banco pelo papel `rl_sistemacmj_api` (só executa as procedures).
- Início **automático atrasado**; reinicia sozinho se cair.
- Parar, iniciar e ver: `services.msc` ou `Stop-Service SisCMJ`, `Start-Service SisCMJ`, `Get-Service SisCMJ` (PowerShell como administrador).

## Certificado HTTPS

- Autoassinado, **5 anos**, no repositório do Windows (Computador local › Pessoal), com o nome do servidor, os IPs e os `-NomesExtras`. Os computadores dos usuários confiam nele pelo `SisCMJ_certificado.cer`.
- **Renovar, ou trocar o nome ou o IP do servidor**: rodar o instalador de novo. Se ele avisar **"certificado NOVO"**, rodar o `preparar_computador_usuario.cmd` em todos os computadores.

## Firewall

- Uma regra só, para a porta do sistema e só para as redes de `-RedesPermitidas` (padrão: rede local; acrescentar a rede da VPN quando existir). A rede do servidor tem de estar como **Privada**.
- O SQL Server **não** é aberto na rede.

<!-- incluir: ../Roteiro_Instalacao_Servidor.md # 9. -->
