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

9. Toda tela tem o botão "?" (CLAUDE.md seção 3 item 9). Páginas de ajuda exclusivas do administrador geral (instalação, licença, parâmetros, comandos) só são entregues pela API ao nível 2.

## 4. Dica ao passar o mouse (pedido do Celso, 16/11/2026)

10. **Todo campo de toda tela** tem dica ao passar o mouse (e ao receber o foco pelo teclado): para que serve o campo, se é **obrigatório** ou não, e o formato ou um exemplo quando ajudar (ex.: "CPF da pessoa. Obrigatório para cliente. Pode digitar com ou sem pontos.").
11. A dica fica no HTML do campo (atributo `data-dica`) e é mostrada por um componente único (mesmo arquivo JS/CSS para todas as telas); campo obrigatório também leva o `*` no rótulo.
12. Botões que não são óbvios também têm dica (o que acontece ao clicar). A dica é curta; o detalhe fica na ajuda "?" da tela.

## 5. Usuários: reiniciar senha (pedido do Celso, 16/11/2026)

13. A tela de Usuários tem o botão **Reiniciar senha**: volta a senha do usuário para a senha provisória padrão (`@12345`, definida pelo Celso) e obriga a criar uma nova senha no próximo login (`TROCAR_SENHA = 1`). Também desbloqueia o usuário e encerra as sessões abertas dele. Pede confirmação antes. Precisa da permissão `REDEFINIR_SENHA` (procedure `SIS_Usuario_Senha_Gravar`, já pronta desde a 02b). **A senha provisória vale só por um tempo** (decisão do Celso, opção (a), 16/11/2026): parâmetro `SENHA_PROVISORIA_HORAS` (padrão 24); passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar de novo. O texto da senha padrão também fica em parâmetro (`SENHA_PROVISORIA_PADRAO` = `@12345`), sem nada fixo no código.
