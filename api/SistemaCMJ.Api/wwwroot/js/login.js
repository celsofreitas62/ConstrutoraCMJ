/* =============================================================================
   SistemaCMJ - js/login.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Tela de login. Recusa (senha errada, bloqueio) em janela com OK;
               depois do OK o cursor volta para a senha. Com TROCAR_SENHA vai
               para a troca de senha; senão volta para a tela pedida antes.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', () => {
  Layout.aplicarIdentidade();

  const form = document.getElementById('form-login');
  const login = document.getElementById('login');
  const senha = document.getElementById('senha');
  const botao = document.getElementById('botao-entrar');
  login.focus();

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!login.value.trim()) { await Mensagens.alerta('Informe o usuário.', 'ATENCAO', { foco: login }); return; }
    if (!senha.value) { await Mensagens.alerta('Informe a senha.', 'ATENCAO', { foco: senha }); return; }

    botao.disabled = true;
    botao.textContent = 'Entrando…';
    const r = await Api.post('/api/login', { login: login.value.trim(), senha: senha.value });
    botao.disabled = false;
    botao.textContent = 'Entrar';

    if (!r.sucesso) {
      senha.value = '';
      await Mensagens.tratar(r, { foco: senha });
      return;
    }
    sessionStorage.removeItem('cmj.novidades.conferidas');  // login novo confere o aviso "O que há de novo" (04c2)
    if (r.dados && r.dados.trocarSenha) { location.href = '/trocar-senha.html'; return; }

    const volta = Util.parametro('volta') || '/';
    // Só volta para página do próprio sistema.
    location.href = volta.startsWith('/') && !volta.startsWith('//') ? volta : '/';
  });
});
