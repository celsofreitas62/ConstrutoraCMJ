/* =============================================================================
   SistemaCMJ - js/layout.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Moldura de toda tela do sistema (esboço aprovado em 16/11/2026):
               topo (logomarca, busca geral, usuário, ⚙ Preferências (04h2), Sair), menu lateral em
               árvore (CLAUDE.md seção 3 item 8) e painel de ajuda "?".
               A página informa no <body>:
                 data-tela   = tela de origem (auditoria/log), ex.: cad/pessoas.html
                 data-menu   = item do menu a destacar (padrão: data-tela)
                 data-ajuda  = arquivo de ajuda em /ajuda (sem .html)
                               ou geral:<página> = ajuda exclusiva do administrador
                               geral, pela API (/api/ajuda-geral; 22/11/2026, 03g)
               Layout.iniciar() devolve { sessao, acoes } -- acoes = ações
               permitidas na tela (Set: VER, INCLUIR, ALTERAR, EXCLUIR...),
               para esconder os botões (a procedure confere de novo).
               04h2 (pedido do Celso, 27/11/2026): item fixo "Início" no alto
               do menu e o caminho acima do título (.caminho) montado pelo
               menu, com cada pedaço clicável: Início volta à tela inicial e
               cada grupo abre aquele nível no menu lateral.
               04h2e: tamanho das letras pela preferência FONTE_TAMANHO
               (classe fonte-* no <html>, guardada na sessão do navegador
               para não piscar; Layout.aplicarAparencia(true) relê) e botão
               ☰ que recolhe o menu lateral (lembrado neste computador).
               04h4 (P06): tema claro/escuro pela preferência TEMA (SISTEMA =
               segue o Windows e troca sozinho quando o Windows muda; CLARO;
               ESCURO) no atributo data-tema do <html>. A escolha fica também
               neste computador (localStorage cmj.tema) para a tela não piscar
               e para o login abrir no tema de quem usou por último.
               Layout.acoesDe(caminho) = ações em OUTRA tela do menu (ex.: o
               atalho "Lixeira desta tela" só aparece para quem vê a Lixeira).
   ========================================================================== */
'use strict';

const Layout = (() => {
  const CHAVE_ABERTOS = 'cmj_menu_abertos';
  let nos = new Map();
  let abertos = new Set();
  let telaMenu = '';

  const CHAVE_APARENCIA = 'cmj.aparencia';        // sessionStorage: { fonte, tema }
  const CHAVE_TEMA = 'cmj.tema';                  // localStorage: SISTEMA | CLARO | ESCURO
  const CHAVE_MENU_RECOLHIDO = 'cmj.menu.recolhido'; // localStorage: '1' = recolhido
  const CLASSES_FONTE = { PEQUENA: 'fonte-pequena', GRANDE: 'fonte-grande', MUITO_GRANDE: 'fonte-muito-grande' };

  function aplicarFonte(fonte) {
    const html = document.documentElement;
    for (const c of Object.values(CLASSES_FONTE)) html.classList.remove(c);
    if (CLASSES_FONTE[fonte]) html.classList.add(CLASSES_FONTE[fonte]);
  }
  // Tema (04h4): SISTEMA segue o Windows (prefers-color-scheme) e acompanha a troca.
  let temaEscolhido = 'SISTEMA';
  const escuroDoWindows = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  function aplicarTema(tema) {
    temaEscolhido = ['CLARO', 'ESCURO', 'SISTEMA'].includes(tema) ? tema : 'SISTEMA';
    const escuro = temaEscolhido === 'ESCURO' || (temaEscolhido === 'SISTEMA' && !!(escuroDoWindows && escuroDoWindows.matches));
    document.documentElement.dataset.tema = escuro ? 'escuro' : 'claro';
    try { localStorage.setItem(CHAVE_TEMA, temaEscolhido); } catch { /* sem armazenamento */ }
  }
  if (escuroDoWindows) escuroDoWindows.addEventListener('change', () => { if (temaEscolhido === 'SISTEMA') aplicarTema('SISTEMA'); });

  // Já ao carregar o script (antes da tela aparecer), para não piscar.
  try { aplicarTema(localStorage.getItem(CHAVE_TEMA) || 'SISTEMA'); } catch { aplicarTema('SISTEMA'); }
  try { aplicarFonte((JSON.parse(sessionStorage.getItem(CHAVE_APARENCIA) || 'null') || {}).fonte); } catch { /* sem armazenamento */ }
  try { if (localStorage.getItem(CHAVE_MENU_RECOLHIDO) === '1') document.documentElement.classList.add('menu-recolhido'); } catch { /* idem */ }

  async function aplicarAparencia(reler) {
    let guardada = null;
    try { guardada = JSON.parse(sessionStorage.getItem(CHAVE_APARENCIA) || 'null'); } catch { guardada = null; }
    if (guardada && guardada.tema && !reler) { aplicarFonte(guardada.fonte); aplicarTema(guardada.tema); return; }
    const r = await Api.get('/api/sis/preferencias', { grupo: 'Aparência' });
    if (!r.sucesso) return;
    const valor = (codigo, padrao) => ((r.dados || []).find((p) => p.CODIGO === codigo) || {}).VALOR || padrao;
    const fonte = valor('FONTE_TAMANHO', 'NORMAL');
    const tema = valor('TEMA', 'SISTEMA');
    try { sessionStorage.setItem(CHAVE_APARENCIA, JSON.stringify({ fonte, tema })); } catch { /* sem armazenamento */ }
    aplicarFonte(fonte);
    aplicarTema(tema);
  }

  const SETA_ABRIR = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>';
  const LUPA = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>';

  async function aplicarIdentidade() {
    const r = await Api.get('/api/identidade');
    if (r.sucesso && r.dados) {
      document.documentElement.style.setProperty('--cor-principal', r.dados.corPrincipal);
      document.documentElement.style.setProperty('--cor-secundaria', r.dados.corSecundaria);
      // Nome do sistema pelo parâmetro SISTEMA_NOME (17/11/2026): título da aba e textos marcados.
      if (r.dados.nomeSistema) {
        document.title = document.title.replace('SistemaCMJ', r.dados.nomeSistema);
        for (const e of document.querySelectorAll('[data-nome-sistema]')) e.textContent = e.dataset.nomeSistema.replace('{sistema}', r.dados.nomeSistema);
      }
    }
  }

  function montarTopo(sessao) {
    const topo = document.getElementById('topo');
    if (!topo) return;
    topo.replaceChildren();

    // ☰ recolhe ou mostra o menu lateral (04h2e): mais espaço em telas menores.
    const botaoMenu = Util.el('button', 'botao topo-menu', '☰');
    botaoMenu.type = 'button';
    botaoMenu.setAttribute('aria-label', 'Recolher ou mostrar o menu');
    botaoMenu.dataset.dica = 'Recolhe o menu ao lado, para a tela ficar mais larga (clique de novo para mostrar). O sistema lembra neste computador.';
    const marcarBotao = () => botaoMenu.setAttribute('aria-expanded', document.documentElement.classList.contains('menu-recolhido') ? 'false' : 'true');
    marcarBotao();
    botaoMenu.addEventListener('click', () => {
      const recolhido = document.documentElement.classList.toggle('menu-recolhido');
      try { localStorage.setItem(CHAVE_MENU_RECOLHIDO, recolhido ? '1' : '0'); } catch { /* sem armazenamento */ }
      marcarBotao();
    });
    topo.append(botaoMenu);

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
    if (sessao.versao) {
      // Versão do sistema: atalho para Sistema › Versões (04c2, P22).
      const linkVersao = Util.el('a', 'topo-versao', 'v' + sessao.versao);
      linkVersao.href = '/sis/versoes.html';
      linkVersao.dataset.dica = 'Versão do sistema. Clique para ver o que mudou em cada versão.';
      detalhe.append(' · ', linkVersao);
    }
    nome.append(Util.el('strong', null, sessao.nome || sessao.login), detalhe);
    // Minhas preferências (04h2, P03): para todos os usuários.
    const preferencias = Util.el('a', 'botao topo-preferencias', '⚙');
    preferencias.href = '/sis/preferencias.html';
    preferencias.setAttribute('aria-label', 'Minhas preferências');
    preferencias.dataset.dica = 'Minhas preferências: como a tela inicial abre (lista, período) e outras escolhas suas.';
    const sair = Util.el('button', 'botao', 'Sair');
    sair.type = 'button';
    sair.addEventListener('click', async () => {
      await Api.post('/api/logout');
      sessionStorage.removeItem(CHAVE_ABERTOS);
      sessionStorage.removeItem('cmj.novidades.conferidas');
      sessionStorage.removeItem(CHAVE_APARENCIA);
      location.href = '/login.html';
    });
    usuario.append(nome, preferencias, sair);

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

  /* Menu em árvore (pedido do Celso, 16/11/2026): clicar no módulo abre as telas
     logo abaixo dele, sem esconder o caminho; clicar de novo no nível de cima
     fecha (volta). Abrir um grupo fecha os irmãos dele, para a árvore não crescer. */
  function desenharMenu() {
    const menu = document.getElementById('menu');
    if (!menu) return;
    menu.replaceChildren();
    menu.setAttribute('aria-label', 'Menu do sistema');
    menu.append(Util.el('div', 'menu-titulo', 'Menu'));
    // Início sempre à mão, em qualquer nível do menu (04h2).
    const inicio = Util.el('a', 'menu-item nivel-0 menu-inicio');
    inicio.href = '/';
    inicio.dataset.dica = 'Volta para a tela inicial (agenda financeira).';
    if (telaMenu === 'index.html' && (location.pathname === '/' || location.pathname === '/index.html')) { inicio.classList.add('ativo'); inicio.setAttribute('aria-current', 'page'); }
    inicio.append(Util.el('span', null, '🏠 Início'));
    menu.append(inicio);

    const raiz = filhosDe('');
    if (raiz.length === 0) menu.append(Util.el('div', 'menu-rodape', 'Nenhuma tela liberada para o seu usuário.'));
    desenharNivel(menu, raiz, 0);
    menu.append(Util.el('div', 'menu-rodape', 'Aparecem só os módulos e as telas liberados para o seu usuário.'));
  }

  function desenharNivel(destino, itens, nivel) {
    const classeNivel = 'nivel-' + Math.min(nivel, 4);
    for (const n of itens) {
      if (n.TIPO === 'TELA') {
        const item = Util.el('a', 'menu-item ' + classeNivel);
        item.href = '/' + n.CAMINHO;
        if (n.CAMINHO === telaMenu) { item.classList.add('ativo'); item.setAttribute('aria-current', 'page'); }
        item.append(Util.el('span', null, n.NOME));
        destino.append(item);
        continue;
      }
      const aberto = abertos.has(n.CHAVE);
      const botao = Util.el('button', 'menu-item menu-grupo ' + classeNivel);
      botao.type = 'button';
      botao.dataset.chave = n.CHAVE;
      botao.setAttribute('aria-expanded', aberto ? 'true' : 'false');
      const seta = Util.el('span', 'menu-seta');
      seta.innerHTML = SETA_ABRIR;
      botao.append(seta, Util.el('span', null, n.NOME));
      botao.addEventListener('click', () => alternar(n));
      destino.append(botao);
      if (aberto) {
        const grupo = Util.el('div', 'menu-subnivel');
        grupo.setAttribute('role', 'group');
        grupo.setAttribute('aria-label', n.NOME);
        desenharNivel(grupo, n.filhos, nivel + 1);
        destino.append(grupo);
      }
    }
  }

  function fecharComDescendentes(chave) {
    abertos.delete(chave);
    for (const f of nos.get(chave)?.filhos ?? []) fecharComDescendentes(f.CHAVE);
  }

  function alternar(n) {
    if (abertos.has(n.CHAVE)) {
      fecharComDescendentes(n.CHAVE);
    } else {
      for (const irmao of filhosDe(n.CHAVE_PAI)) if (irmao.CHAVE !== n.CHAVE) fecharComDescendentes(irmao.CHAVE);
      abertos.add(n.CHAVE);
    }
    sessionStorage.setItem(CHAVE_ABERTOS, JSON.stringify([...abertos]));
    desenharMenu();
    document.querySelector('#menu [data-chave="' + n.CHAVE + '"]')?.focus();
  }

  /* Caminho acima do título (04h2): Início › módulo › grupo, montado pelo menu
     (nada escrito à mão nas telas). Clicar num grupo abre aquele nível no menu. */
  function montarCaminho(tela) {
    const caixa = document.querySelector('.cabecalho .caminho');
    if (!caixa || !tela || location.pathname === '/' || location.pathname === '/index.html') return;
    const cadeia = [];
    for (let pai = nos.get(tela.CHAVE_PAI); pai; pai = nos.get(pai.CHAVE_PAI)) cadeia.unshift(pai);
    const sep = () => Util.el('span', 'caminho-sep', ' › ');
    caixa.replaceChildren();
    const inicio = Util.el('a', 'caminho-link', 'Início');
    inicio.href = '/';
    inicio.dataset.dica = 'Volta para a tela inicial.';
    caixa.append(inicio);
    cadeia.forEach((n, i) => {
      const b = Util.el('button', 'caminho-link', n.NOME);
      b.type = 'button';
      b.dataset.dica = 'Abre "' + n.NOME + '" no menu ao lado, para escolher outra tela.';
      b.addEventListener('click', () => {
        abertos = new Set(cadeia.slice(0, i + 1).map((x) => x.CHAVE));
        sessionStorage.setItem(CHAVE_ABERTOS, JSON.stringify([...abertos]));
        desenharMenu();
        const alvo = document.querySelector('#menu [data-chave="' + n.CHAVE + '"]');
        if (alvo) { alvo.scrollIntoView({ block: 'nearest' }); alvo.focus(); }
      });
      caixa.append(sep(), b);
    });
    // Ficha aberta pela lista (ex.: lançamento): o último pedaço leva de volta à lista.
    const caminhoTela = '/' + String(tela.CAMINHO).split('?')[0];
    if (location.pathname !== caminhoTela) {
      const lista = Util.el('a', 'caminho-link', tela.NOME);
      lista.href = '/' + tela.CAMINHO;
      caixa.append(sep(), lista);
    }
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
          let doc;
          if (arquivo.startsWith('geral:')) {
            // Tela exclusiva do administrador geral: a ajuda vem só pela API (03g).
            const r = await Api.get('/api/ajuda-geral/' + encodeURIComponent(arquivo.substring(6)));
            if (!r.sucesso) throw new Error();
            doc = new DOMParser().parseFromString('<title></title><body>' + r.dados.html + '</body>', 'text/html');
            doc.title = r.dados.titulo;
          } else {
            const resp = await fetch('/ajuda/' + arquivo + '.html', { credentials: 'same-origin' });
            if (!resp.ok) throw new Error();
            doc = new DOMParser().parseFromString(await resp.text(), 'text/html');
          }
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

  /** Aviso "O que há de novo" (04c2, P22): uma vez por usuário e versão, depois do login.
      Confere só uma vez por sessão do navegador; Entendi marca como visto no banco. */
  async function verNovidades() {
    const CHAVE = 'cmj.novidades.conferidas';
    if (sessionStorage.getItem(CHAVE)) return;
    const r = await Api.get('/api/sis/novidades');
    if (!r.sucesso) return;           // aviso nunca atrapalha o uso da tela
    sessionStorage.setItem(CHAVE, '1');
    const itens = r.dados || [];
    if (!itens.length) return;

    const janela = document.createElement('dialog');
    janela.className = 'janela janela-novidades';
    janela.setAttribute('aria-labelledby', 'novidades-titulo');
    const topo = Util.el('div', 'janela-topo');
    const h2 = Util.el('h2', null, 'O que há de novo');
    h2.id = 'novidades-titulo';
    topo.append(h2);
    const corpo = Util.el('div', 'novidades-corpo');
    let lista = null;
    let versao = null;
    for (const n of itens) {
      if (n.VERSAO !== versao) {
        versao = n.VERSAO;
        corpo.append(Util.el('h3', 'versao-titulo', 'Versão ' + n.VERSAO + (n.DT_VERSAO ? ' (' + n.DT_VERSAO + ')' : '')));
        lista = Util.el('ul', 'versao-itens');
        corpo.append(lista);
      }
      const li = Util.el('li');
      li.append(Util.el('span', 'etiqueta etiqueta-' + String(n.TIPO || '').toLowerCase(), n.TIPO_NOME), ' ', n.TEXTO || '');
      lista.append(li);
    }
    const omitidas = itens[0].VERSOES_OMITIDAS || 0;
    if (omitidas > 0) corpo.append(Util.el('p', 'suave', 'Mais ' + omitidas + (omitidas === 1 ? ' versão anterior' : ' versões anteriores') + ' em Sistema › Versões.'));

    const barra = Util.el('div', 'janela-botoes');
    const fechar = async (destino) => {
      await Api.post('/api/sis/novidades/vista');
      janela.close();
      janela.remove();
      if (destino) location.href = destino;
    };
    const todas = Util.el('button', 'botao', 'Ver todas as versões');
    todas.type = 'button';
    todas.addEventListener('click', () => fechar('/sis/versoes.html'));
    const entendi = Util.el('button', 'botao botao-principal', 'Entendi');
    entendi.type = 'button';
    entendi.addEventListener('click', () => fechar(null));
    barra.append(todas, entendi);
    janela.addEventListener('cancel', (e) => e.preventDefault());
    janela.append(topo, corpo, barra);
    document.body.append(janela);
    janela.showModal();
    entendi.focus();
  }

  /** Monta a moldura. Devolve { sessao, acoes } ou não volta (vai ao login). */
  async function iniciar() {
    telaMenu = document.body.dataset.menu || document.body.dataset.tela || '';
    const [rSessao, rMenu] = await Promise.all([Api.get('/api/sessao'), Api.get('/api/menu'), aplicarIdentidade()]);
    if (!rSessao.sucesso) { await Mensagens.tratar(rSessao); return { sessao: null, acoes: new Set() }; }
    const sessao = rSessao.dados;
    montarTopo(sessao);
    aplicarAparencia(false);

    let acoes = new Set();
    if (rMenu.sucesso) {
      carregarMenu(rMenu.dados || []);
      const tela = [...nos.values()].find((n) => n.TIPO === 'TELA' && n.CAMINHO === telaMenu);
      try { abertos = new Set(JSON.parse(sessionStorage.getItem(CHAVE_ABERTOS) || '[]')); } catch { abertos = new Set(); }
      if (tela) {
        acoes = new Set((tela.ACOES || '').split(',').filter(Boolean));
        // Abre o caminho até a tela atual (e só ele).
        abertos = new Set();
        for (let pai = nos.get(tela.CHAVE_PAI); pai; pai = nos.get(pai.CHAVE_PAI)) abertos.add(pai.CHAVE);
        sessionStorage.setItem(CHAVE_ABERTOS, JSON.stringify([...abertos]));
      }
      desenharMenu();
      montarCaminho(tela);
    } else {
      await Mensagens.tratar(rMenu);
    }

    ligarAjuda();
    verNovidades();

    if (telaMenu && document.body.dataset.exigeTela !== undefined && !acoes.has('VER')) {
      await Mensagens.alerta('Você não tem acesso a esta tela ou ela não está liberada.');
      location.href = '/';
      return new Promise(() => {});
    }
    return { sessao, acoes };
  }

  /** Ações permitidas numa tela do menu (vazio = não vê ou não está pronta). Usar depois do iniciar(). */
  function acoesDe(caminho) {
    const tela = [...nos.values()].find((n) => n.TIPO === 'TELA' && n.CAMINHO === caminho);
    return new Set(tela ? (tela.ACOES || '').split(',').filter(Boolean) : []);
  }

  return { iniciar, aplicarIdentidade, acoesDe, aplicarAparencia };
})();
