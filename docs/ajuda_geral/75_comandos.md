<!-- pagina: comandos | titulo: Comandos e executor | resumo: Os comandos de instalação e manutenção previstos para a tela (lista do banco) e o executor que o Claude usa no notebook. | palavras: comando comandos botao instalacao manutencao executor pedido compilar publicar enviar github extrair access sql entrada saida fila -->

## Comandos de instalação e manutenção (pedidos 2 e 4 de 16/11/2026)

- Cada comando do roteiro vira um botão da tela **Sistema › Configuração › Instalação e manutenção** (só nível 2). A tela grava o pedido numa fila (`SIS.Comando_Fila`) e o serviço executa uma **lista fixa** de comandos, com a saída registrada. Nada do que vem da tela vira comando livre.
- Situação hoje: a lista e a fila estão no banco; **o lado do serviço e a tela ainda não foram feitos** (depois da virada, versões 1.x). Comando sem tratamento no serviço termina em ERRO "comando não disponível nesta versão". Até lá, tudo pelo roteiro (páginas Instalação e Atualização).

### Lista cadastrada (lida do banco agora)

<!-- dinamico: comandos -->

## Executor do Claude (só no notebook do Celso)

Programa que deixa o Claude rodar scripts e tarefas fixas no notebook **sem o SSMS e sem o PowerShell**. Fica em `C:\SistemaCMJ\executor_sql\`, rodando pela tarefa "SistemaCMJ - Executor SQL" (`instalar_executor.cmd`, como administrador; `parar_executor.cmd` para). **Nunca aponta para a produção.**

| O Claude grava em `entrada\` | O executor faz | Resultado em `saida\` |
|---|---|---|
| `<nº>_<nome>.sql` | roda no `SISTEMACMJ_LOCAL` (ou no `SISTEMACMJ` de ensaio do notebook, com a linha `-- EXECUTOR: BANCO=SISTEMACMJ`); recusa `USE` de outro banco, `DROP/RESTORE DATABASE`, `xp_cmdshell`, `sp_configure`, `SHUTDOWN` | `<nº>_<nome>.txt` (o script vai para `processados\`) |
| `compilar.pedido` | compila a API numa pasta separada, sem mexer no sistema que está rodando | `compilar.txt` |
| `publicar.pedido` | `api\publicar.ps1`: pacote de instalação em `C:\SisCMJ_Publicacao` | `publicar.txt` |
| `enviar_github.pedido` | `git push origin main` | `enviar_github.txt` |
| `extrair_access.pedido` | extração do Access (`Extrair_Access.ps1 -ExportarDados`, cerca de 20 min) | `extrair_access.txt` |

- `executor_sql\STATUS.txt` mostra se ele está ativo e o último pedido.
- Os pedidos são **fixos**: o executor não roda nada que venha dentro do arquivo de pedido.
