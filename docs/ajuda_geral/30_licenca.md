<!-- pagina: licenca | titulo: Licença | resumo: Como a licença funciona, como gerar, instalar e conferir, e o que fazer ao trocar de servidor. | palavras: licenca lic chave privada publica ecdsa codigo do servidor cnpj modulos gerador -->

## Como funciona

- A licença é o arquivo **`licenca.lic`**, assinado com a **chave privada** do Celso (ECDSA). O programa tem embutida só a **chave pública**: confere a assinatura, mas não consegue gerar licença.
- A licença leva: razão social, **CNPJ** (um só), nome fantasia, **código do servidor**, **módulos liberados**, data de emissão e observação. **Não tem data de validade** (decisão de 20/11/2026).
- Ela fica **presa ao servidor**: o código do servidor sai do próprio computador. Copiada para outra máquina, não vale.
- O sistema confere a licença **ao subir, a cada login e a cada minuto**. Trocar o arquivo basta: vale em até 1 minuto, sem reiniciar.
- **Licença inválida ou ausente**: só respondem `/api/saude`, a logomarca do login e o primeiro acesso. As telas mostram o motivo e o **código deste servidor**, e as rotinas automáticas não rodam.
- **Módulos**: aparece para uso só o que está **na licença e habilitado** (chave `HABILITADO` do módulo e da tela, que só o nível 2 liga). O módulo `SIS` vai sempre.

## Onde fica cada coisa

| O quê | Onde |
|---|---|
| Gerador (só no notebook do Celso) | `api\gerar_licenca.cmd` |
| Chave privada (cifrada com senha) | `%USERPROFILE%\SisCMJ_Chave\chave_privada_siscmj.pem`, com cópia no Google Drive do Celso |
| Senha da chave privada | gerenciador de senhas do Celso, **fora** do Google Drive |
| Licenças geradas | `%USERPROFILE%\SisCMJ_Chave\licencas\<CNPJ>_<servidor>_<data>.lic` |
| Licença no servidor | `C:\ProgramData\SisCMJ\licenca.lic` |
| Licença de desenvolvimento (notebook) | `api\licenca\licenca.lic` |

⚠️ **Nunca levar o gerador nem a chave privada para o servidor.** Sem a chave privada e a senha não se gera licença nova (regra de ouro 3 do roteiro: guardar junto com a chave do BitLocker).

## O gerador (`api\gerar_licenca.cmd`)

| Opção | Para quê |
|---|---|
| 1) Criar o par de chaves | Só uma vez na vida. Já existindo chave, o gerador recusa: criar outra invalidaria todas as licenças emitidas. |
| 2) Gerar uma licença | Pede a senha da chave, razão social, CNPJ, nome fantasia, **código do servidor**, módulos (Enter = todos) e observação. Confere a assinatura antes de gravar. |
| 3) Código deste computador | Mostra o código do notebook (para a licença de desenvolvimento). |
| 4) Conferir um arquivo de licença | Diz se o arquivo é válido e mostra os dados dele (CNPJ, servidor, módulos, emissão). |

## Situações comuns

- **Instalação nova**: o instalador grava o código em `instalacao\codigo_servidor.txt`; gerar a licença com ele (passo 7 abaixo).
- **Troca de servidor, de placa-mãe ou Windows reinstalado**: o código muda. Abrir o sistema no servidor novo (a tela bloqueada mostra o código) ou ler `/api/saude` (campo `codigoServidor`), gerar uma licença nova com esse código e copiar para `C:\ProgramData\SisCMJ\licenca.lic`.
- **Liberar ou tirar um módulo**: gerar uma licença nova com a lista de módulos e trocar o arquivo. Depois, habilitar o módulo e as telas (nível 2).
- **Conferir o que está instalado**: `/api/saude` mostra `licenca` (ok ou o motivo) e `codigoServidor`; a opção 4 do gerador lê um arquivo `.lic`.

<!-- incluir: ../Roteiro_Instalacao_Servidor.md # 7. -->
