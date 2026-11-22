<!-- pagina: diagnostico | titulo: Diagnóstico | resumo: Como saber se o sistema está bem: endereço de saúde, versão do banco e do programa, registros e onde olhar quando algo der errado. | palavras: saude api/saude log erro registro versao banco desatualizado licenca invalida servico parado services.msc logs -->

## Endereço de saúde

Abrir **`https://localhost:5443/api/saude`** no servidor (ou com o endereço dos usuários, de outro computador). Não precisa de login.

| Campo | O que diz |
|---|---|
| `situacao` | **`ok`**; `banco_fora` (o banco não respondeu); `banco_desatualizado` (banco e programa em versões diferentes); `licenca_invalida` |
| `versao` | versão do programa |
| `versaoBanco` / `versaoBancoExigida` | versão gravada no banco e a que o programa precisa (têm de ser iguais) |
| `licenca` | `ok` ou o motivo da recusa |
| `codigoServidor` | código deste servidor, para gerar a licença |
| `banco`, `tempoBancoMs` | se o banco respondeu e em quanto tempo |

A resposta vem com o código **200** quando está tudo bem e **503** quando não está (serve para monitoramento automático).

## O que fazer em cada situação

- **`banco_fora`**: conferir o serviço do SQL Server (`services.msc` › **SQL Server (SQL2025)**) e o espaço em disco; depois o registro da API.
- **`banco_desatualizado`**: o programa foi atualizado sem o MASTER (ou o contrário). Rodar o **MASTER da mesma versão** no banco `SISTEMACMJ` (roteiro, item 14). Enquanto isso, só `/api/saude` responde e as telas mostram o aviso.
- **`licenca_invalida`**: ver a página **Licença**.
- **Não abre nada** (nem `/api/saude`): serviço **SisCMJ** parado (`services.msc`), endereço sem `https://` (dá "não enviou dados") ou firewall/rede Pública (roteiro, item 2).
- **Erro numa tela** ("O erro foi registrado para análise"): o texto técnico está em `SIS.Log_Erro` (abaixo). O usuário nunca vê o detalhe.

## Registros

- **API**: um arquivo por dia em `C:\ProgramData\SisCMJ\logs\` (guardados 30 dias; parâmetros `Registro:Pasta` e `Registro:DiasManter` da configuração do servidor).
- **Banco**: `SIS.Log_Erro` (erros) e `SIS.Log_Passo` (passo a passo das rotinas e as consultas a esta ajuda).

```sql
SELECT TOP 50 * FROM SIS.Log_Erro ORDER BY ID_LOG_ERRO DESC;
SELECT TOP 50 * FROM SIS.Log_Passo ORDER BY ID_LOG_PASSO DESC;
SELECT TOP 20 * FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]' ORDER BY ID_LOG_PASSO DESC;  -- quem abriu esta ajuda
```

<!-- incluir: ../Roteiro_Instalacao_Servidor.md # 15. -->
