/* =============================================================================
   SistemaCMJ - js/trocar-senha.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Troca da própria senha. No primeiro acesso (TROCAR_SENHA = 1)
               é obrigatória: sem Cancelar, e a API não deixa abrir outra tela
               antes. A senha atual é a provisória recebida do administrador.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  Layout.aplicarIdentidade();

  const r = await Api.get('/api/sessao');
  if (!r.sucesso) { await Mensagens.tratar(r); return; }
  const obrigatoria = !!r.dados.trocarSenha;

  const atual = document.getElementById('senha-atual');
  const nova = document.getElementById('nova-senha');
  const confirmacao = document.getElementById('confirmacao');
  const botao = document.getElementById('botao-gravar');

  if (obrigatoria) {
    document.getElementById('etiqueta').textContent = 'Primeiro acesso';
    document.getElementById('titulo').textContent = 'Crie a sua senha';
    document.getElementById('explicacao').textContent =
      'A senha provisória precisa ser trocada antes de usar o sistema. Em "Senha atual", digite a senha provisória que você recebeu.';
    document.getElementById('botao-cancelar').hidden = true;
  }
  atual.focus();

  document.getElementById('form-senha').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!atual.value) { await Mensagens.alerta('Informe a senha atual.', 'ATENCAO', { foco: atual }); return; }
    if (!nova.value) { await Mensagens.alerta('Informe a nova senha.', 'ATENCAO', { foco: nova }); return; }
    if (nova.value !== confirmacao.value) {
      await Mensagens.alerta('A nova senha e a repetição não estão iguais.', 'ATENCAO', { foco: confirmacao });
      return;
    }

    if (!(await Mensagens.confirmar('Gravar nova senha?', 'Confirma a troca da sua senha?', 'Gravar'))) return;

    botao.disabled = true;
    const resp = await Api.post('/api/senha', { senhaAtual: atual.value, novaSenha: nova.value, confirmacao: confirmacao.value });
    botao.disabled = false;
    if (!resp.sucesso) {
      const foco = /atual/i.test(resp.mensagem || '') ? atual : nova;
      await Mensagens.tratar(resp, { foco });
      return;
    }
    await Mensagens.concluido(resp.mensagem || 'Senha alterada.');
    location.href = '/';
  });
});
