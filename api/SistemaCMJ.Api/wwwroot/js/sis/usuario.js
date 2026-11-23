/* =============================================================================
   SistemaCMJ - js/sis/usuario.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Ficha do usuário (SIS_USUARIO): incluir, alterar, desativar,
               reiniciar senha, desbloquear, permissões individuais
               (exceções ao perfil) e histórico. As regras (login único, dois
               níveis de administrador, sempre sobrar um administrador ativo,
               não desativar a si mesmo) ficam nas procedures.
               Atalhos: Ctrl+S grava, Esc volta (PADRAO_TELAS regra 14).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);

  const idUsuario = parseInt(Util.parametro('id') || '0', 10) || null;
  const podeEditar = idUsuario ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
  let perfis = [];
  let grade = null;
  let permissoesCarregadas = false;
  let historicoCarregado = false;
  let sujo = false;
  let dados = null;

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    if (aba.id === 'aba-permissoes' && !permissoesCarregadas) carregarPermissoes();
    if (aba.id === 'aba-historico' && !historicoCarregado) carregarHistorico();
  }
  abas.forEach((a) => {
    a.addEventListener('click', () => abrirAba(a));
    a.addEventListener('keydown', (e) => {
      const visiveis = abas.filter((x) => !x.hidden);
      const pos = visiveis.indexOf(a);
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        const prox = visiveis[(pos + (e.key === 'ArrowRight' ? 1 : visiveis.length - 1)) % visiveis.length];
        prox.focus();
        abrirAba(prox);
      }
    });
  });

  function linhaVazia(corpo, colunas, texto) {
    const tr = Util.el('tr');
    const td = Util.el('td', 'vazio', texto);
    td.colSpan = colunas;
    tr.append(td);
    corpo.append(tr);
  }

  // ---------- Perfis ----------
  const rPerfis = await Api.get('/api/sis/perfis', { situacao: 'TODOS' });
  if (rPerfis.sucesso) perfis = rPerfis.dados || [];
  function montarPerfis(idAtual) {
    const s = $('perfil');
    s.replaceChildren(Util.el('option', null, '(escolha)'));
    s.firstChild.value = '';
    for (const p of perfis) {
      if (!p.ATIVO && p.ID_PERFIL !== idAtual) continue;
      const o = Util.el('option', null, p.NOME + (p.ATIVO ? '' : ' (inativo)'));
      o.value = p.ID_PERFIL;
      s.append(o);
    }
    s.value = idAtual ? String(idAtual) : '';
    explicarPerfil();
  }
  function explicarPerfil() {
    const p = perfis.find((x) => String(x.ID_PERFIL) === $('perfil').value);
    $('nota-perfil').textContent = p ? (p.DESCRICAO || '') : '';
  }
  $('perfil').addEventListener('change', () => {
    explicarPerfil();
    if (permissoesCarregadas && dados && String(dados.ID_PERFIL) !== $('perfil').value) {
      $('grade-permissoes').replaceChildren(Util.el('div', 'aviso-faixa', 'O perfil foi trocado: grave primeiro para ver e ajustar as permissões do perfil novo.'));
      grade = null;
    }
  });

  // ---------- Permissões individuais ----------
  async function carregarPermissoes() {
    const destino = $('grade-permissoes');
    destino.replaceChildren(Util.el('div', 'suave', 'Carregando…'));
    const r = await Api.get('/api/sis/usuarios/' + idUsuario + '/permissoes');
    if (!(await Mensagens.tratar(r))) { destino.replaceChildren(Util.el('div', 'vazio', 'Permissões indisponíveis.')); return; }
    permissoesCarregadas = true;
    grade = GradePermissoes.criar(destino, 'USUARIO', r.dados || [], {
      editavel: podeEditar,
      aoMudar: (n) => {
        sujo = true;
        $('aba-permissoes').textContent = 'Permissões individuais' + (n ? ' (' + n + ' a gravar)' : '');
      }
    });
  }

  // ---------- Histórico ----------
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico'), {
      item: 'SIS_USUARIO', tabela: 'SIS.Usuario', id: idUsuario, nomeRegistro: 'Usuário', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar('/sis/usuario.html?id=' + encodeURIComponent(idUsuario) + '#historico'); }
    });
    if (await historico.carregar()) historicoCarregado = true;
  }

  // ---------- Cabeçalho e avisos ----------
  function atualizarCabecalho(u) {
    if (!u) {
      $('titulo').textContent = 'Novo usuário';
      $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.';
      document.title = 'SistemaCMJ – Novo usuário';
      return;
    }
    $('titulo').textContent = u.NOME;
    document.title = 'SistemaCMJ – ' + u.NOME;
    const s = SituacaoSenha.de(u);
    $('subtitulo').textContent = [u.LOGIN + (u.PROPRIO ? ' (você)' : ''), u.PERFIL_NOME, u.ATIVO ? 'Ativo' : 'Inativo', 'Senha: ' + s.texto.toLowerCase(),
      u.DT_ULTIMO_LOGIN ? 'Último acesso em ' + Util.dataHora(u.DT_ULTIMO_LOGIN) : 'Nunca entrou'].join(' · ');

    const aviso = $('aviso-senha');
    let texto = '';
    if (!u.ATIVO) texto = 'Usuário inativo: não consegue entrar no sistema.';
    else if (u.BLOQUEADO) texto = 'Usuário bloqueado' + (u.DT_BLOQUEIO ? ' desde ' + Util.dataHora(u.DT_BLOQUEIO) : '') + ' por errar a senha. Use "Desbloquear" (mantém a senha) ou "Reiniciar senha".';
    else if (!u.TEM_SENHA) texto = 'Este usuário ainda não tem senha: use "Reiniciar senha" para dar a senha provisória padrão.';
    else if (u.SENHA_PROVISORIA_VENCIDA) texto = 'A senha provisória venceu sem ser trocada (vale ' + u.SENHA_PROVISORIA_HORAS + ' horas). Use "Reiniciar senha" e avise o usuário para entrar logo.';
    else if (u.TROCAR_SENHA) texto = 'Senha provisória dada em ' + Util.dataHora(u.DT_SENHA) + '. O usuário cria a senha dele no próximo acesso'
      + (u.SENHA_PROVISORIA_HORAS > 0 && u.PERFIL_NIVEL_ADMIN < 2 ? ' (prazo: ' + u.SENHA_PROVISORIA_HORAS + ' horas).' : '.');
    aviso.hidden = !texto;
    aviso.textContent = texto;

    const partes = [];
    if (u.DT_CRIACAO) partes.push('Criado em ' + Util.dataHora(u.DT_CRIACAO) + (u.USUARIO_CRIACAO ? ' por ' + u.USUARIO_CRIACAO : ''));
    if (u.DT_ALTERACAO) partes.push('Alterado em ' + Util.dataHora(u.DT_ALTERACAO) + (u.USUARIO_ALTERACAO ? ' por ' + u.USUARIO_ALTERACAO : ''));
    $('rodape').textContent = partes.join(' · ');
  }

  // ---------- Carga ----------
  if (idUsuario) {
    const r = await Api.get('/api/sis/usuarios/' + idUsuario);
    if (!(await Mensagens.tratar(r))) { location.href = '/sis/usuarios.html'; return; }
    dados = r.dados;
    $('login').value = dados.LOGIN || '';
    $('nome').value = dados.NOME || '';
    $('email').value = dados.EMAIL || '';
    $('ativo').checked = !!dados.ATIVO;
    montarPerfis(dados.ID_PERFIL);
    atualizarCabecalho(dados);
    $('aba-permissoes').hidden = false;
    $('aba-historico').hidden = false;
    if (dados.QTD_EXCECOES) $('aba-permissoes').textContent = 'Permissões individuais (' + dados.QTD_EXCECOES + ')';
    $('botao-reiniciar').hidden = !acoes.has('REDEFINIR_SENHA') || !!dados.PROPRIO || !dados.ATIVO;
    $('botao-desbloquear').hidden = !acoes.has('DESBLOQUEAR') || !dados.BLOQUEADO;
    if (dados.PROPRIO) $('ativo').disabled = true;
  } else {
    montarPerfis(null);
    atualizarCabecalho(null);
    $('nota-novo').hidden = false;
  }

  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) for (const e of $('ficha').querySelectorAll('#painel-dados input, #painel-dados select')) e.disabled = true;
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  $('login').addEventListener('input', () => {
    const limpo = $('login').value.toLowerCase().replace(/\s/g, '');
    if (limpo !== $('login').value) $('login').value = limpo;
  });
  if (podeEditar) (idUsuario ? $('nome') : $('login')).focus();

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!podeEditar) return;
    const login = $('login').value.trim();
    const nome = $('nome').value.trim();
    if (login.length < 3) {
      abrirAba($('aba-dados'));
      await Mensagens.alerta('Informe o login (de 3 a 40 letras minúsculas, números, ponto, hífen ou sublinhado).', 'ATENCAO', { foco: $('login') });
      return;
    }
    if (!nome) { abrirAba($('aba-dados')); await Mensagens.alerta('Informe o nome do usuário.', 'ATENCAO', { foco: $('nome') }); return; }
    if (!$('perfil').value) { abrirAba($('aba-dados')); await Mensagens.alerta('Escolha o perfil do usuário.', 'ATENCAO', { foco: $('perfil') }); return; }

    const mudancas = grade ? grade.mudancas() : [];
    let texto = (idUsuario ? 'Confirma a gravação das alterações de ' : 'Confirma a inclusão de ') + nome + ' (' + login + ')?';
    if (idUsuario && dados && dados.ATIVO && !$('ativo').checked) texto += ' O usuário será desativado: não entra mais e as sessões abertas dele são encerradas.';
    if (mudancas.length) texto += ' ' + (mudancas.length === 1 ? '1 permissão individual muda.' : mudancas.length + ' permissões individuais mudam.');
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;

    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/sis/usuarios', {
      idUsuario, login, nome, email: $('email').value.trim(), idPerfil: parseInt($('perfil').value, 10), ativo: $('ativo').checked
    });
    if (!(await Mensagens.tratar(r))) { botao.disabled = false; return; }
    const novoId = r.dados && r.dados.id ? r.dados.id : idUsuario;
    let mensagem = r.mensagem || 'Usuário gravado.';

    if (mudancas.length && idUsuario) {
      const rp = await Api.post('/api/sis/usuarios/' + idUsuario + '/permissoes', { lista: mudancas });
      if (!rp.sucesso) {
        botao.disabled = false;
        await Mensagens.alerta('Os dados foram gravados, mas as permissões individuais não: ' + rp.mensagem, rp.tipo === 'ERRO' ? 'ERRO' : 'ATENCAO');
        return;
      }
      mensagem += ' ' + rp.mensagem;
    }
    botao.disabled = false;
    sujo = false;
    await Mensagens.concluido(mensagem);
    Util.recarregar('/sis/usuario.html?id=' + encodeURIComponent(novoId) + (mudancas.length ? '#permissoes' : ''));
  });
  if (idUsuario && location.hash === '#permissoes') abrirAba($('aba-permissoes'));
  if (idUsuario && location.hash === '#historico') abrirAba($('aba-historico'));

  // ---------- Reiniciar senha / desbloquear ----------
  $('botao-reiniciar').addEventListener('click', async () => {
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Reiniciar a senha não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const ok = await Mensagens.confirmar('Reiniciar senha?',
      'A senha de ' + dados.NOME + ' volta para a senha provisória padrão. Ele é desbloqueado, as sessões abertas são encerradas e no próximo acesso ele é obrigado a criar uma senha nova'
      + (dados.SENHA_PROVISORIA_HORAS > 0 && dados.PERFIL_NIVEL_ADMIN < 2 ? ' (em até ' + dados.SENHA_PROVISORIA_HORAS + ' horas).' : '.')
      + ' Passe a senha provisória para ele pessoalmente.', 'Reiniciar senha');
    if (!ok) return;
    const r = await Api.post('/api/sis/usuarios/' + idUsuario + '/reiniciar-senha');
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem);
    Util.recarregar('/sis/usuario.html?id=' + encodeURIComponent(idUsuario));
  });

  $('botao-desbloquear').addEventListener('click', async () => {
    if (!(await Mensagens.confirmar('Desbloquear?', dados.NOME + ' volta a poder entrar com a senha que já tem. Se ele esqueceu a senha, use "Reiniciar senha".', 'Desbloquear'))) return;
    const r = await Api.post('/api/sis/usuarios/' + idUsuario + '/desbloquear');
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem);
    Util.recarregar('/sis/usuario.html?id=' + encodeURIComponent(idUsuario));
  });

  // ---------- Cancelar / atalhos ----------
  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-cancelar').addEventListener('click', () => sair('/sis/usuarios.html'));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair('/sis/usuarios.html'); });
  document.addEventListener('keydown', (e) => {
    if (document.querySelector('.janela')) return; // janela de mensagem aberta: ela cuida das teclas
    if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); if (podeEditar) $('ficha').requestSubmit(); }
    else if (e.key === 'Escape') sair('/sis/usuarios.html');
  });
});
