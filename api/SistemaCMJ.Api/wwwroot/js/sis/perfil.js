/* =============================================================================
   SistemaCMJ - js/sis/perfil.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Ficha do perfil (SIS_PERFIL): incluir, alterar, desativar,
               permissões por tela e ação (grade única, js/sis/permissoes.js),
               usuários do perfil e histórico. Regras (nome único, perfil de
               administrador não desativa nem recebe marcação, perfil com
               usuário ativo não desativa) ficam nas procedures.
               Atalhos: Ctrl+S grava, Esc volta (PADRAO_TELAS regra 14).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);

  const idPerfil = parseInt(Util.parametro('id') || '0', 10) || null;
  const podeEditar = idPerfil ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
  let grade = null;
  let dados = null;
  let sujo = false;
  const carregadas = new Set();

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    if (!carregadas.has(aba.id)) {
      if (aba.id === 'aba-permissoes') carregarPermissoes();
      if (aba.id === 'aba-usuarios') carregarUsuarios();
      if (aba.id === 'aba-historico') carregarHistorico();
    }
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

  async function carregarPermissoes() {
    const destino = $('grade-permissoes');
    destino.replaceChildren(Util.el('div', 'suave', 'Carregando…'));
    const r = await Api.get('/api/sis/perfis/' + idPerfil + '/permissoes');
    if (!(await Mensagens.tratar(r))) { destino.replaceChildren(Util.el('div', 'vazio', 'Permissões indisponíveis.')); return; }
    carregadas.add('aba-permissoes');
    grade = GradePermissoes.criar(destino, 'PERFIL', r.dados || [], {
      editavel: podeEditar,
      aoMudar: (n) => {
        sujo = true;
        $('aba-permissoes').textContent = 'Permissões' + (n ? ' (' + n + ' a gravar)' : '');
      }
    });
  }

  async function carregarUsuarios() {
    const corpo = $('linhas-usuarios');
    corpo.replaceChildren();
    const r = await Api.get('/api/sis/perfis/' + idPerfil + '/usuarios');
    if (!r.sucesso) { linhaVazia(corpo, 5, r.mensagem || 'Usuários indisponíveis.'); return; }
    carregadas.add('aba-usuarios');
    const linhas = r.dados || [];
    if (!linhas.length) linhaVazia(corpo, 5, 'Nenhum usuário neste perfil.');
    for (const u of linhas) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      const abrir = () => { location.href = '/sis/usuario.html?id=' + encodeURIComponent(u.ID_USUARIO); };
      tr.addEventListener('click', abrir);
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(); });
      const s = SituacaoSenha.de(u);
      const senha = Util.el('td');
      senha.append(Util.el('span', 'situacao ' + s.classe, s.texto));
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (u.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), u.ATIVO ? 'Ativo' : 'Inativo'));
      tr.append(Util.el('td', 'forte', u.LOGIN), Util.el('td', null, u.NOME || ''), Util.el('td', 'numero', String(u.QTD_EXCECOES || 0)), senha, sit);
      corpo.append(tr);
    }
  }

  async function carregarHistorico() {
    const corpo = $('linhas-historico');
    corpo.replaceChildren();
    const r = await Api.get('/api/sis/perfis/' + idPerfil + '/historico');
    if (!r.sucesso) { await Mensagens.tratar(r); linhaVazia(corpo, 6, 'Histórico indisponível.'); return; }
    carregadas.add('aba-historico');
    const linhas = r.dados || [];
    if (!linhas.length) linhaVazia(corpo, 6, 'Nenhuma alteração registrada.');
    for (const h of linhas) {
      const tr = Util.el('tr');
      tr.append(
        Util.el('td', 'numero', Util.dataHora(h.DT_OPERACAO)),
        Util.el('td', null, h.USUARIO || ''),
        Util.el('td', null, h.OPERACAO_NOME || ''),
        Util.el('td', null, h.CAMPO || (h.OPERACAO === 'A' ? '' : '(registro)')),
        Util.el('td', 'suave', h.VALOR_ANTES || ''),
        Util.el('td', null, h.VALOR_DEPOIS || '')
      );
      corpo.append(tr);
    }
  }

  // ---------- Carga ----------
  const tipo = (p) => p.NIVEL_ADMIN >= 2 ? 'Administrador geral' : p.NIVEL_ADMIN === 1 ? 'Administrador' : 'Perfil comum';
  if (idPerfil) {
    const r = await Api.get('/api/sis/perfis/' + idPerfil);
    if (!(await Mensagens.tratar(r))) { location.href = '/sis/perfis.html'; return; }
    dados = r.dados;
    $('nome').value = dados.NOME || '';
    $('descricao').value = dados.DESCRICAO || '';
    $('ativo').checked = !!dados.ATIVO;
    if (dados.NIVEL_ADMIN >= 1) $('ativo').disabled = true;
    $('titulo').textContent = dados.NOME;
    document.title = 'SistemaCMJ – ' + dados.NOME;
    $('subtitulo').textContent = [tipo(dados), dados.ATIVO ? 'Ativo' : 'Inativo',
      (dados.QTD_USUARIOS_ATIVOS || 0) === 1 ? '1 usuário ativo' : (dados.QTD_USUARIOS_ATIVOS || 0) + ' usuários ativos',
      dados.NIVEL_ADMIN >= 1 ? 'todas as permissões' : (dados.QTD_PERMISSOES || 0) + ' permissões'].join(' · ');
    for (const id of ['aba-permissoes', 'aba-usuarios', 'aba-historico']) $(id).hidden = false;
  } else {
    $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.';
    $('nota-novo').hidden = false;
  }

  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) for (const e of $('painel-dados').querySelectorAll('input, textarea')) e.disabled = true;
  $('painel-dados').addEventListener('input', () => { sujo = true; });
  $('painel-dados').addEventListener('change', () => { sujo = true; });
  if (podeEditar) $('nome').focus();

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!podeEditar) return;
    const nome = $('nome').value.trim();
    if (!nome) { abrirAba($('aba-dados')); await Mensagens.alerta('Informe o nome do perfil.', 'ATENCAO', { foco: $('nome') }); return; }

    const mudancas = grade ? grade.mudancas() : [];
    let texto = (idPerfil ? 'Confirma a gravação das alterações do perfil ' : 'Confirma a inclusão do perfil ') + nome + '?';
    if (mudancas.length) texto += ' ' + (mudancas.length === 1 ? '1 permissão muda' : mudancas.length + ' permissões mudam')
      + ' para todos os usuários do perfil' + (dados && dados.QTD_USUARIOS_ATIVOS ? ' (' + dados.QTD_USUARIOS_ATIVOS + (dados.QTD_USUARIOS_ATIVOS === 1 ? ' ativo)' : ' ativos)') : '') + '.';
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;

    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/sis/perfis', { idPerfil, nome, descricao: $('descricao').value.trim(), ativo: $('ativo').checked });
    if (!(await Mensagens.tratar(r))) { botao.disabled = false; return; }
    const novoId = r.dados && r.dados.id ? r.dados.id : idPerfil;
    let mensagem = r.mensagem || 'Perfil gravado.';
    if (mudancas.length && idPerfil) {
      const rp = await Api.post('/api/sis/perfis/' + idPerfil + '/permissoes', { lista: mudancas });
      if (!rp.sucesso) {
        botao.disabled = false;
        await Mensagens.alerta('Os dados foram gravados, mas as permissões não: ' + rp.mensagem, rp.tipo === 'ERRO' ? 'ERRO' : 'ATENCAO');
        return;
      }
      mensagem += ' ' + rp.mensagem;
    }
    botao.disabled = false;
    sujo = false;
    await Mensagens.concluido(mensagem);
    Util.recarregar('/sis/perfil.html?id=' + encodeURIComponent(novoId) + (!idPerfil || mudancas.length ? '#permissoes' : ''));
  });

  if (idPerfil && location.hash === '#permissoes') abrirAba($('aba-permissoes'));

  // ---------- Cancelar / atalhos ----------
  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-cancelar').addEventListener('click', () => sair('/sis/perfis.html'));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair('/sis/perfis.html'); });
  document.addEventListener('keydown', (e) => {
    if (document.querySelector('.janela')) return;
    if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); if (podeEditar) $('ficha').requestSubmit(); }
    else if (e.key === 'Escape') sair('/sis/perfis.html');
  });
});
