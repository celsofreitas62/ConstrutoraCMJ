# Padrão das Telas do SistemaCMJ (HTML/CSS/JS)

Regras para toda tela do sistema. Criado em 16/11/2026 com os pedidos do Celso; vai crescendo na fase das telas (fases 3 e 4). Aplicar sempre, sem precisar repetir a cada pedido.

## 1. Mensagens ao usuário (pedido 1 do Celso, 16/11/2026)

1. **Recusa e erro em janela (pop-up) com botão OK**: toda vez que a procedure devolver `SUCESSO = 0` (ou, nas procedures "Listar", o erro 50001), a tela abre uma janela no centro com o texto de `MENSAGEM` e um botão **OK**. Nada continua até o usuário clicar em OK. A janela não fecha sozinha e não fecha clicando fora.
2. A janela de erro tem ícone e título conforme o tipo: **Atenção** (recusa de regra de negócio: campo faltando, valor inválido) ou **Erro** (falha técnica: "O erro foi registrado para análise"). O texto técnico nunca aparece para o usuário; ele está em `SIS.Log_Erro`.
3. Depois do OK, o foco volta para o campo que causou a recusa, quando der para saber qual é.
4. **Sucesso** (gravado, enviado) aparece como aviso discreto que some sozinho em poucos segundos (não pede OK), para não atrapalhar o trabalho rápido.
5. **Confirmação antes de ação que não se desfaz fácil** (estornar, cancelar contrato, reabrir mês, excluir): janela com **Confirmar** e **Cancelar**, dizendo o que vai acontecer.
6. A mesma janela é um componente único (um arquivo JS/CSS), usado por todas as telas.

## 2. Permissões na tela

7. A tela esconde os botões das ações que o usuário não tem (lista `ACOES` de `SIS.SIS_Menu_Listar`). A procedure confere de novo no banco: esconder o botão não é a proteção, é só conforto.
8. Telas e módulos não habilitados ou fora da licença não aparecem no menu.

## 3. Ajuda

9. Toda tela tem o botão "?" (CLAUDE.md seção 3 item 9). Páginas de ajuda exclusivas do administrador geral (instalação, licença, parâmetros, comandos) só são entregues pela API ao nível 2.
