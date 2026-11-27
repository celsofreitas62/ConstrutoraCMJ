# Padrão das Telas do SistemaCMJ (HTML/CSS/JS)

Regras para toda tela do sistema. Criado em 16/11/2026 com os pedidos do Celso; vai crescendo na fase das telas (fases 3 e 4). Aplicar sempre, sem precisar repetir a cada pedido.

## 1. Mensagens ao usuário (pedido 1 do Celso, 16/11/2026)

1. **Recusa e erro em janela (pop-up) com botão OK**: toda vez que a procedure devolver `SUCESSO = 0` (ou, nas procedures "Listar", o erro 50001), a tela abre uma janela no centro com o texto de `MENSAGEM` e um botão **OK**. Nada continua até o usuário clicar em OK. A janela não fecha sozinha e não fecha clicando fora.
2. A janela de erro tem ícone e título conforme o tipo: **Atenção** (recusa de regra de negócio: campo faltando, valor inválido) ou **Erro** (falha técnica: "O erro foi registrado para análise"). O texto técnico nunca aparece para o usuário; ele está em `SIS.Log_Erro`.
3. Depois do OK, o foco volta para o campo que causou a recusa, quando der para saber qual é.
4. **Gravação em todas as telas** (revisto pelo Celso em 16/11/2026): ao clicar em Gravar, primeiro abre a janela **"Gravar?"** com **Confirmar/Cancelar**; depois de gravar, abre a janela **"Concluído"** dizendo que o registro foi gravado, com botão **OK** (`Mensagens.concluido`). Vale também para excluir, reativar e trocar senha. O aviso discreto que some sozinho (`Mensagens.sucesso`) fica só para ações pequenas que não são gravação.
5. **Confirmação antes de ação que não se desfaz fácil** (estornar, cancelar contrato, reabrir mês, excluir): janela com **Confirmar** e **Cancelar**, dizendo o que vai acontecer.
6. A mesma janela é um componente único (um arquivo JS/CSS), usado por todas as telas.

## 2. Permissões na tela

7. A tela esconde os botões das ações que o usuário não tem (lista `ACOES` de `SIS.SIS_Menu_Listar`). A procedure confere de novo no banco: esconder o botão não é a proteção, é só conforto.
8. Telas e módulos não habilitados ou fora da licença não aparecem no menu.

## 3. Ajuda

9. Toda tela tem o botão "?" (CLAUDE.md seção 3 item 9). Páginas de ajuda exclusivas do administrador geral (instalação, licença, parâmetros, comandos) só são entregues pela API ao nível 2 (22/11/2026, 03g): ficam em `AjudaGeral` (fora de `wwwroot`, embutidas, sem endereço direto), saem só por `/api/ajuda-geral/<página>`, e a tela exclusiva aponta o "?" para elas com `data-ajuda="geral:<página>"`. São geradas de `docs/ajuda_geral/` (fonte única, nunca editar o HTML gerado; `api/ferramentas/montar_ajuda.py`). A ajuda comum (`wwwroot/ajuda`) continua sem login (decisão do Celso, 22/11/2026) e por isso **nunca** leva informação de administração.

## 4. Dica ao passar o mouse (pedido do Celso, 16/11/2026)

10. **Todo campo de toda tela** tem dica ao passar o mouse (e ao receber o foco pelo teclado): para que serve o campo, se é **obrigatório** ou não, e o formato ou um exemplo quando ajudar (ex.: "CPF da pessoa. Obrigatório para cliente. Pode digitar com ou sem pontos.").
11. A dica fica no HTML do campo (atributo `data-dica`) e é mostrada por um componente único (mesmo arquivo JS/CSS para todas as telas); campo obrigatório também leva o `*` no rótulo.
12. Botões que não são óbvios também têm dica (o que acontece ao clicar). A dica é curta; o detalhe fica na ajuda "?" da tela.
12a. **A dica nunca cobre a caixa de digitação** (pedido do Celso, 22/11/2026): aparece **acima do rótulo** do campo; sem espaço acima, **ao lado** do campo; sem espaço ao lado, abaixo. Pela entrada no campo (foco, inclusive o foco automático ao abrir a tela) **some sozinha em 3 segundos**; pelo mouse, fica enquanto o mouse estiver sobre o campo.

## 5. Usuários: reiniciar senha (pedido do Celso, 16/11/2026)

13. A tela de Usuários tem o botão **Reiniciar senha**: volta a senha do usuário para a senha provisória padrão (`@12345`, definida pelo Celso) e obriga a criar uma nova senha no próximo login (`TROCAR_SENHA = 1`). Também desbloqueia o usuário e encerra as sessões abertas dele. Pede confirmação antes. Precisa da permissão `REDEFINIR_SENHA` (procedure `SIS_Usuario_Senha_Gravar`, já pronta desde a 02b). **A senha provisória vale só por um tempo** (decisão do Celso, opção (a), 16/11/2026): parâmetro `SENHA_PROVISORIA_HORAS` (padrão 24); passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar de novo. O texto da senha padrão também fica em parâmetro (`SENHA_PROVISORIA_PADRAO` = `@12345`), sem nada fixo no código. **Feito na 04a (22/11/2026)**: telas `sis/usuarios.html` e `sis/usuario.html`; o prazo não vale para o administrador geral (nível 2), para ele nunca ficar sem entrar; usuário novo já nasce com a senha provisória.

## 6. Digitação rápida (aprovado pelo Celso, 16/11/2026)

14. **Atalhos de teclado** em toda tela de manutenção: **Ctrl+S** grava (com a mesma confirmação do botão), **Esc** cancela/volta, **Enter** passa para o próximo campo (não grava). Os atalhos aparecem na dica do botão.
15. **Endereço pelo CEP e dados da empresa pelo CNPJ** por serviços públicos gratuitos, preenchendo os campos (o usuário confere antes de gravar). Depende de internet no servidor: liga/desliga em parâmetro. Implementar na fase 4.

## 7. Topo e menu fixos (pedido do Celso, 18/11/2026)

16. No computador, o **topo e o menu lateral ficam parados**; só a área da tela rola. Quando o menu for maior que a janela, ele rola sozinho, sem mexer na tela. No celular, tudo rola junto. Fica no `app.css`, vale para todas as telas.

## 7a. Navegação, tamanho das letras e menu recolhível (pedido do Celso, 27/11/2026, 04h2e)

16a. **Início sempre à mão**: o menu tem o item fixo **🏠 Início** no alto, em qualquer nível; a logomarca também leva ao início.
16b. **Caminho acima do título** (`.cabecalho .caminho`) é **montado pelo menu** (`js/layout.js`, `montarCaminho`), nunca escrito à mão nem trocado pelo JS da tela: `Início › módulo › grupo`; cada grupo clicado abre aquele nível no menu lateral; numa ficha aberta pela lista (`data-menu` diferente do arquivo), o último pedaço leva de volta à lista. Tela nova só precisa do `<div class="caminho">` vazio (ou com um texto provisório).
16c. **Tamanho das letras** pela preferência `FONTE_TAMANHO` (classe `fonte-*` no `<html>`, com `zoom`); medidas que dependem da altura da janela usam `calc(100vh / var(--zoom, 1) ...)`.
16d. **☰ recolhe o menu lateral** (classe `menu-recolhido` no `<html>`, lembrada no computador). Toda tela tem de caber em **1366 × 768 e 1280 × 720**, com o menu aberto e recolhido: tabelas largas rolam dentro de `.rolagem`, nunca a página para o lado (passo 15 dos testes das telas).

## 7b. Cores e tema claro/escuro (P06, aprovado pelo Celso, 27/11/2026, 04h4)

16e. **Nenhuma cor fixa nas regras do `app.css`**: toda cor vem de uma variável com nome de função, definida no `:root` do início (`--texto`, `--texto-suave`, `--branco` = superfície, `--superficie-suave`, `--borda`, `--verde-fundo`/`--verde-texto`, `--vermelho-*`, `--laranja-*`, `--amarelo-*`, `--azul-*`, `--roxo`, `--calor-d-*`/`--calor-c-*`, `--cor-principal-texto` para texto na cor da empresa, `--texto-sobre-cor` para texto em cima da cor da empresa...). O tema escuro só troca os valores (`html[data-tema="escuro"]`, no fim do `app.css`). Cor nova = variável nova nos dois blocos.
16f. **Tema** pela preferência `TEMA` (SISTEMA segue o Windows, CLARO, ESCURO), aplicado por `js/layout.js` no `data-tema` do `<html>` e guardado no computador (`localStorage` `cmj.tema`) para não piscar e para o login.
16g. **Contraste WCAG AA**: texto comum 4,5:1, texto grande 3:1, nos dois temas (conferido nos testes das telas).
16h. **Impressão e PDF sempre no claro** (o escuro fica dentro de `@media screen`). A **prévia do e-mail** aparece sempre clara, como o e-mail sai. **Logomarca** no escuro ganha uma placa clara (`--placa-logo`).

## 8. Testes automáticos das telas (aprovado pelo Celso na 03h; feito na 04a, 22/11/2026)

17. Toda tela nova entra sozinha nos testes automáticos (`testes/telas`, Playwright + Edge invisível): o teste abre cada tela do menu e confere que carrega, tem título (`h1`), não abre janela de erro ou recusa, não tem erro de JavaScript e nenhuma chamada da API responde 500. **Ficha** que não fica no menu (aberta pela lista) vai na lista `fichasSemMenu` do `testes/telas/config.json`.
18. Cada tela que grava ganha, quando fizer sentido, um passo de **gravação de teste pelo caminho do usuário** (Gravar › "Gravar?" › Confirmar › "Concluído"), num registro de teste que não atrapalha (ex.: usuário `teste.automatico`, inativo).
19. Os testes rodam pelo executor (`entrada\testar_telas.pedido`, com o `rodar.cmd` aberto) **antes de cada publicação**: o `publicar` recusa se o último resultado não for OK ou for mais velho que o código do programa.
20. **Ficha com abas**: o endereço `ficha.html?id=N#permissoes` (ou outra aba) abre direto na aba; depois de gravar, a ficha volta na mesma aba (`Util.recarregar`).
