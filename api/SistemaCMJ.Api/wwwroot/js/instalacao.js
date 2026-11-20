/* =============================================================================
   SistemaCMJ - js/instalacao.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 20/11/2026 (fase 3d)
   Descrição : Primeiro acesso da instalação (só no próprio servidor): define a
               senha do administrador geral e a senha provisória do
               administrador da empresa, de uma vez. Pede confirmação antes de
               gravar e mostra "Concluído"; depois vai para o login.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  Layout.aplicarIdentidade();
  const $ = (id) => document.getElementById(id);
  const texto = $('texto-situacao');

  const r = await Api.get('/api/instalacao');
  if (!r || (!r.sucesso && /404/.test(r.mensagem || ''))) {
    texto.textContent = 'Esta tela só pode ser usada no próprio servidor.';
    return;
  }
  if (!r.sucesso) { await Mensagens.tratar(r); texto.textContent = 'Não foi possível conferir a instalação.'; return; }
  const s = r.dados;
  if (!s.pendente) {
    texto.textContent = 'A instalação já foi concluída: os administradores já têm senha.';
    const a = document.createElement('a'); a.href = '/login.html'; a.textContent = 'Ir para o login'; a.className = 'botao botao-principal';
    texto.after(a);
    return;
  }
  texto.textContent = 'Defina a senha do administrador geral (' + s.loginGeral + ') e a senha provisória do administrador da empresa (' +
    s.loginEmpresa + '). Mínimo de ' + s.tamanhoMinimo + ' caracteres, com letras e números.';
  $('rotulo-geral').textContent = 'Senha do administrador geral (' + s.loginGeral + ')';
  $('rotulo-empresa').textContent = 'Senha provisória do administrador da empresa (' + s.loginEmpresa + ')';
  $('campos').hidden = false;
  $('senha-geral').focus();

  $('form-instalacao').addEventListener('submit', async (e) => {
    e.preventDefault();
    const g = $('senha-geral').value, g2 = $('senha-geral-2').value, p = $('senha-empresa').value, p2 = $('senha-empresa-2').value;
    if (!g) { await Mensagens.alerta('Informe a senha do administrador geral.', 'ATENCAO', { foco: $('senha-geral') }); return; }
    if (g !== g2) { await Mensagens.alerta('As duas senhas do administrador geral não são iguais.', 'ATENCAO', { foco: $('senha-geral-2') }); return; }
    if (!p) { await Mensagens.alerta('Informe a senha provisória do administrador da empresa.', 'ATENCAO', { foco: $('senha-empresa') }); return; }
    if (p !== p2) { await Mensagens.alerta('As duas senhas provisórias não são iguais.', 'ATENCAO', { foco: $('senha-empresa-2') }); return; }
    if (!(await Mensagens.confirmar('Gravar?', 'Grava as senhas dos dois administradores. Esta tela não abre de novo depois disso.', 'Gravar'))) return;

    $('botao-gravar').disabled = true;
    const x = await Api.post('/api/instalacao/senhas', { senhaGeral: g, senhaEmpresa: p });
    $('botao-gravar').disabled = false;
    if (!(await Mensagens.tratar(x, { foco: $('senha-geral') }))) return;
    for (const id of ['senha-geral', 'senha-geral-2', 'senha-empresa', 'senha-empresa-2']) $(id).value = '';
    await Mensagens.concluido(x.mensagem || 'Senhas gravadas.');
    location.href = '/login.html';
  });
});
