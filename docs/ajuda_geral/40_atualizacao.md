<!-- pagina: atualizacao | titulo: Atualização de versão | resumo: Como levar uma versão nova à CMJ: pacote, ensaio na VM, MASTER, instalador e o limite da restauração. | palavras: atualizar versao nova master publicar pacote instalador vm ensaio banco desatualizado atualizar.cmd um clique volta automatica sqlcmd notas da versao 1.8 -->

## A regra das versões

- O programa e o banco têm **versões casadas**. O número do banco fica num lugar só (`sql/objetos/SIS/Carga_SIS_Versao.sql`, última instrução do MASTER) e o programa exige o mesmo (`Infra/VersaoBanco.cs`). Toda mudança que vai para o MASTER sobe os dois juntos (PADRAO_SQL, regra 61).
- Banco e programa diferentes: o sistema **para de propósito**. Só `/api/saude` responde (`banco_desatualizado`) e as telas mostram o aviso. Isso evita o programa novo gravar num banco velho, ou o contrário.
- O MASTER é **idempotente**: roda por cima sem erro e sem perder dados. O instalador atualiza o programa e as tarefas sem perder configuração, licença nem dados.
- A versão de cada parte aparece no `LEIA-ME.txt` do pacote e em `/api/saude` (`versao`, `versaoBanco`, `versaoBancoExigida`).

## Ordem certa (PADRAO_SQL, regra 57)

1. Banco (MASTER) → 2. programa (instalador) → 3. conferir. Nunca o programa antes do banco.

O `atualizar.cmd` do pacote segue essa ordem sozinho, com backup de segurança antes e volta automática se falhar. O que mudou em cada versão: `docs/NOTAS_DA_VERSAO.md` (vai para o pacote como `NOTAS_DA_VERSAO.txt` e fica no banco em `SIS.Atualizacao`).

<!-- incluir: ../Roteiro_Instalacao_Servidor.md # 14. -->
