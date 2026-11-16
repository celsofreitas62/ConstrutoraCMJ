/* =============================================================================
   SistemaCMJ - js/layout.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Moldura de toda tela do sistema (esboço aprovado em 16/11/2026):
               topo (logomarca, busca geral, usuário, Sair), menu lateral em
               drill-down (CLAUDE.md seção 3 item 8) e painel de ajuda "?".
               A página informa no <body>:
                 data-tela   = tela de origem (auditoria/log), ex.: cad/pessoas.html
                 data-menu   = item do menu a destacar (padrão: data-tela)
                 data-ajuda  = arquivo de ajuda em /ajuda (sem .html)
               Layout.iniciar() devolve { sessao, acoes } -- acoes = ações
               permitidas na tela (Set: VER, INCLUIR, ALTERAR, EXCLUIR...),
               para esconder os botões (a procedure confere de novo).
   ========================================================================== */
'use strict';

const Layout = (() => {
  const CHAVE_NIVEL = 'cmj_menu_nivel';
  let nos = new Map();
  let nivelAtual = '';
  let telaMenu = '';

  const SETA_VOLTAR = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M15 18l-6-6 6-6"/></svg>';
  const SETA_ABRIR = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>';
  const LUPA = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>';

  async function aplicarIdentidade() {
    const r = await Api.get('/api/identidade');
    if (r.sucesso && r.dados) {
      document.documentElement.style.setProperty('--cor-principal', r.dados.corPrincipal);
      document.documentElement.style.setProperty('--cor-secundaria', r.dados.corSecundaria);
    }
  }

  function montarTopo(sessao) {
    const topo = document.getElementById('topo');
    if (!topo) return;
    topo.replaceChildren();

    const linkInicio = Util.el('a');
    linkInicio.href = '/';
    const logo = Util.el('img', 'topo-logo');
    logo.src = '/api/identidade/logo/horizontal';
    logo.alt = 'Logomarca da empresa - ir para o início';
    linkInicio.append(logo);

    const busca = Util.el('div', 'topo-busca');
    const rotulo = Util.el('label');
    const icone = Util.el('span');
    icone.innerHTML = LUPA;
    const textoRotulo = Util.el('span', 'so-leitor', 'Busca geral');
    const campo = Util.el('input');
    campo.type = 'search';
    campo.disabled = true;
    campo.placeholder = 'Busca geral: cliente, fornecedor, documento… (em breve)';
    rotulo.append(icone, textoRotulo, campo);
    busca.append(rotulo);

    const usuario = Util.el('div', 'topo-usuario');
    const nome = Util.el('div', 'topo-usuario-nome');
    const linkSenha = Util.el('a', null, 'Trocar senha');
    linkSenha.href = '/trocar-senha.html';
    const detalhe = Util.el('span', null, sessao.nivelNome ? sessao.nivelNome + ' · ' : '');
    detalhe.append(linkSenha);
    nome.append(Util.el('strong', null, sessao.nome || sessao.login), detalhe);
    const sair = Util.el('button', 'botao', 'Sair');
    sair.type = 'button';
    sair.addEventListener('click', async () => {
      await Api.post('/api/logout');
      sessionStorage.removeItem(CHAVE_NIVEL);
      location.href = '/login.html';
    });
    usuario.append(nome, sair);

    topo.append(linkInicio, busca, usuario);
  }

  function carregarMenu(linhas) {
    nos = new Map();
    for (const l of linhas) nos.set(l.CHAVE, { ...l, filhos: [] });
    for (const n of nos.values()) {
      const pai = nos.get(n.CHAVE_PAI);
      if (pai) pai.filhos.push(n);
    }
  }

  function filhosDe(chave) {
    if (!chave) return [...nos.values()].filter((n) => !n.CHAVE_PAI);
    return nos.get(chave)?.filhos ?? [];
  }

  function desenharMenu() {
    const menu = document.getElementById('menu');
    if (!menu) return;
    menu.replaceChildren();
    menu.setAttribute('aria-label', 'Menu do sistema');

    if (nivelAtual && !nos.has(nivelAtual)) nivelAtual = '';
    const atual = nos.get(nivelAtual);

    if (atual) {
      const voltar = Util.el('button', 'menu-voltar');
      voltar.type = 'button';
      voltar.innerHTML = SETA_VOLTAR;
      voltar.append('Voltar');
      voltar.addEventListener('click', () => irParaNivel(atual.CHAVE_PAI || ''));
      menu.append(voltar);
    }
    menu.append(Util.el('div', 'menu-titulo', atual ? atual.NOME : 'Módulos'));

    const itens = filhosDe(nivelAtual);
    if (itens.length === 0) menu.append(Util.el('div', 'menu-rodape', 'Nenhuma tela liberada para o seu usuário.'));

    for (const n of itens) {
      let item;
      if (n.TIPO === 'TELA') {
        item = Util.el('a', 'menu-item');
        item.href = '/' + n.CAMINHO;
        if (n.CAMINHO === telaMenu) { item.classList.add('ativo'); item.setAttribute('aria-current', 'page'); }
        item.append(Util.el('span', null, n.NOME));
      } else {
        item = Util.el('button', 'menu-item');
        item.type = 'button';
        item.append(Util.el('span', null, n.NOME));
        const seta = Util.el('span');
        seta.innerHTML = SETA_ABRIR;
        item.append(seta);
        item.addEventListener('click', () => irParaNivel(n.CHAVE));
      }
      menu.append(item);
    }
    menu.append(Util.el('div', 'menu-rodape', 'Aparecem só os módulos e as telas liberados para o seu usuário.'));
  }

  function irParaNivel(chave) {
    nivelAtual = chave;
    sessionStorage.setItem(CHAVE_NIVEL, chave);
    desenharMenu();
    document.querySelector('#menu .menu-item, #menu .menu-voltar')?.focus();
  }

  function ligarAjuda() {
    const botao = document.getElementById('botao-ajuda');
    const painel = document.getElementById('ajuda');
    const arquivo = document.body.dataset.ajuda;
    if (!botao || !painel || !arquivo) return;
    let carregada = false;

    const fechar = () => { painel.hidden = true; botao.setAttribute('aria-expanded', 'false'); botao.focus(); };
    botao.setAttribute('aria-expanded', 'false');
    botao.addEventListener('click', async () => {
      if (!painel.hidden) { fechar(); return; }
      if (!carregada) {
        painel.replaceChildren(Util.el('p', 'suave', 'Carregando a ajuda…'));
        try {
          const resp = await fetch('/ajuda/' + arquivo + '.html', { credentials: 'same-origin' });
          if (!resp.ok) throw new Error();
          const doc = new DOMParser().parseFromString(await resp.text(), 'text/html');
          const topo = Util.el('div', 'ajuda-topo');
          topo.append(Util.el('strong', null, doc.title || 'Ajuda'));
          const x = Util.el('button', 'botao-icone', '×');
          x.type = 'button';
          x.setAttribute('aria-label', 'Fechar ajuda');
          x.addEventListener('click', fechar);
          topo.append(x);
          painel.replaceChildren(topo, ...[...doc.body.children].map((n) => document.importNode(n, true)));
          carregada = true;
        } catch {
          painel.replaceChildren(Util.el('p', null, 'A ajuda desta tela ainda não está disponível.'));
        }
      }
      painel.hidden = false;
      botao.setAttribute('aria-expanded', 'true');
    });
  }

  /** Monta a moldura. Devolve { sessao, acoes } ou não volta (vai ao login). */
  async function iniciar() {
    telaMenu = document.body.dataset.menu || document.body.dataset.tela || '';
    const [rSessao, rMenu] = await Promise.all([Api.get('/api/sessao'), Api.get('/api/menu'), aplicarIdentidade()]);
    if (!rSessao.sucesso) { await Mensagens.tratar(rSessao); return { sessao: null, acoes: new Set() }; }
    const sessao = rSessao.dados;
    montarTopo(sessao);

    let acoes = new Set();
    if (rMenu.sucesso) {
      carregarMenu(rMenu.dados || []);
      const tela = [...nos.values()].find((n) => n.TIPO === 'TELA' && n.CAMINHO === telaMenu);
      if (tela) {
        acoes = new Set((tela.ACOES || '').split(',').filter(Boolean));
        nivelAtual = tela.CHAVE_PAI;
      } else {
        nivelAtual = sessionStorage.getItem(CHAVE_NIVEL) || '';
      }
      desenharMenu();
    } else {
      await Mensagens.tratar(rMenu);
    }

    ligarAjuda();

    if (telaMenu && document.body.dataset.exigeTela !== undefined && !acoes.has('VER')) {
      await Mensagens.alerta('Você não tem acesso a esta tela ou ela não está liberada.');
      location.href = '/';
      return new Promise(() => {});
    }
    return { sessao, acoes };
  }

  return { iniciar, aplicarIdentidade };
})();
