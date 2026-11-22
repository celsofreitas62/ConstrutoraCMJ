# Fontes da ajuda do administrador geral (etapa 03g)

Cada arquivo `NN_<página>.md` desta pasta vira uma página da tela **Sistema › Configuração › Ajuda do administrador geral**, que só o nível 2 (`celso`) vê.

- **Fonte única** (decisão do Celso, 22/11/2026): o que já está escrito em outro documento não é copiado. A página puxa o trecho com `<!-- incluir: ../Roteiro_Instalacao_Servidor.md -->` (o documento inteiro, sem o título) ou `<!-- incluir: ../Roteiro_Instalacao_Servidor.md # 7. -->` (só a seção cujo título começa com `7.`, até a próxima seção do mesmo nível).
- Primeira linha de cada arquivo: `<!-- pagina: <nome> | titulo: <título> | resumo: <uma linha> | palavras: <palavras extras para a busca> -->`.
- **Nunca escrever senha, chave ou senha de app** aqui: a ajuda diz só *onde* cada coisa está.
- Depois de mudar qualquer fonte (inclusive o roteiro): `python3 api/ferramentas/montar_ajuda.py` (o Claude roda). Ele grava `api/SistemaCMJ.Api/AjudaGeral/` (embutido no executável). `--conferir` só diz se alguma página ficou desatualizada; roda antes de compilar e de publicar.
- A versão do programa e do banco que aparece no selo de cada página sai do `SistemaCMJ.Api.csproj` e do `Infra/VersaoBanco.cs`: nada fixo aqui.
