/* =============================================================================
   SistemaCMJ - js/sis/ajuda-geral.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (etapa 03g)
   Descrição : Tela "Ajuda do administrador geral" (SIS_AJUDA_GERAL, só nível 2).
               Índice com busca (sem acento) e a página escolhida, ambos pela
               API (/api/ajuda-geral): as páginas não têm endereço direto.
               Endereço com #<página> abre a página (link de outra tela).
               Botão "Copiar" em todo bloco de comando.
               v1.1 (22/11/2026, pedido do Celso): navegação dentro da página:
               "Nesta página" (tópicos) no topo das páginas longas, "↑ topo"
               em cada seção e linhas de tabela que começam pelo número de
               uma seção (ex.: Visão geral do roteiro) levam direto a ela.
               Endereço #<página>/<seção> abre já na seção.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  if (!acoes.has('VER')) return;
  const $ = (id) => document.getElementById(id);
  const semAcento = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  let paginas = [];
  let atual = '';

  const resp = await Api.get('/api/ajuda-geral');
  if (!(await Mensagens.tratar(resp))) return;
  paginas = (resp.dados.paginas || []).sort((a, b) => a.ordem - b.ordem);
  for (const p of paginas) p.chave = semAcento(p.busca);
  $('subtitulo').textContent = 'Válida para o programa ' + resp.dados.versaoPrograma + ' e o banco ' + resp.dados.versaoBanco + '. Só o administrador geral vê esta ajuda.';

  function desenharLista() {
    const palavras = semAcento($('busca').value).split(/\s+/).filter(Boolean);
    const achadas = paginas.filter((p) => palavras.every((w) => p.chave.includes(w)));
    const itens = achadas.map((p) => {
      const a = Util.el('a', 'ajuda-geral-item' + (p.pagina === atual ? ' ativo' : ''));
      a.href = '#' + p.pagina;
      a.append(Util.el('strong', null, p.titulo), Util.el('span', 'suave', p.resumo));
      if (p.pagina === atual) a.setAttribute('aria-current', 'page');
      return a;
    });
    $('lista').replaceChildren(...(itens.length ? itens : [Util.el('p', 'vazio', 'Nada encontrado.')]));
  }

  function botoesCopiar(raiz) {
    for (const pre of raiz.querySelectorAll('pre')) {
      const b = Util.el('button', 'botao botao-copiar', 'Copiar');
      b.type = 'button';
      b.dataset.dica = 'Copia o comando para colar no SSMS, no PowerShell ou no Prompt de Comando.';
      b.addEventListener('click', async () => {
        try {
          await navigator.clipboard.writeText(pre.innerText.replace(/\n$/, ''));
          Mensagens.sucesso('Copiado.');
        } catch {
          await Mensagens.alerta('Não foi possível copiar. Selecione o texto e use Ctrl+C.');
        }
      });
      const caixa = Util.el('div', 'bloco-comando');
      pre.replaceWith(caixa);
      caixa.append(b, pre);
    }
  }

  const slug = (texto) => 'sec-' + semAcento(texto).replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').substring(0, 60);

  function irPara(id) {
    const alvo = id && document.getElementById(id);
    if (alvo) alvo.scrollIntoView({ block: 'start', behavior: 'smooth' });
    else { $('pagina').scrollIntoView({ block: 'start' }); }
  }

  /** Ids nas seções, "Nesta página", "↑ topo" e tabelas com número de seção viram links. */
  function navegacao(corpo, pagina) {
    const titulos = [...corpo.querySelectorAll('h2, h3')];
    const porNumero = new Map();
    const usados = new Set();
    for (const h of titulos) {
      let id = slug(h.textContent);
      while (usados.has(id)) id += '-x';
      usados.add(id);
      h.id = id;
      const n = /^(\d+[a-z]?)\.\s/.exec(h.textContent.trim());
      if (n && h.tagName === 'H2' && !porNumero.has(n[1])) porNumero.set(n[1], id);
    }
    const link = (id, texto, classe) => { const a = Util.el('a', classe, texto); a.href = '#' + pagina + '/' + id; return a; };

    const h2 = titulos.filter((h) => h.tagName === 'H2');
    if (h2.length >= 4) {
      const nav = Util.el('nav', 'ajuda-geral-sumario');
      nav.setAttribute('aria-label', 'Nesta página');
      nav.id = 'sec-topo';
      nav.append(Util.el('strong', null, 'Nesta página'));
      const lista = Util.el('ol');
      for (const h of h2) { const li = Util.el('li'); li.append(link(h.id, h.textContent)); lista.append(li); }
      nav.append(lista);
      corpo.prepend(nav);
      for (const h of h2) h.append(link('sec-topo', '↑ topo', 'ajuda-geral-topo'));
    }

    for (const tr of corpo.querySelectorAll('tbody tr')) {
      const primeira = tr.cells[0];
      const id = primeira && porNumero.get(primeira.textContent.trim());
      if (!id) continue;
      const a = link(id, primeira.textContent.trim());
      a.dataset.dica = 'Vai direto para esta etapa.';
      primeira.replaceChildren(a);
      tr.classList.add('clicavel');
      tr.addEventListener('click', (e) => { if (e.target.closest('a')) return; location.hash = pagina + '/' + id; });
    }
  }

  async function ir() {
    const [nome, secao] = location.hash.substring(1).split('/');
    if (nome && nome === atual) { irPara(secao); return; }
    await abrir(nome || (paginas[0] ? paginas[0].pagina : ''));
    if (secao) irPara(secao);
  }

  async function abrir(nome) {
    if (!nome) { atual = ''; desenharLista(); return; }
    $('pagina').replaceChildren(Util.el('p', 'suave', 'Carregando…'));
    const r = await Api.get('/api/ajuda-geral/' + encodeURIComponent(nome));
    if (!r.sucesso) {
      $('pagina').replaceChildren(Util.el('p', 'suave', 'Escolha uma página à esquerda.'));
      await Mensagens.tratar(r);
      return;
    }
    atual = r.dados.pagina;
    const doc = new DOMParser().parseFromString('<body>' + r.dados.html + '</body>', 'text/html');
    const corpo = Util.el('div', 'ajuda-geral-texto');
    corpo.append(...[...doc.body.childNodes].map((n) => document.importNode(n, true)));
    botoesCopiar(corpo);
    for (const t of corpo.querySelectorAll('table')) { t.classList.add('tabela'); const c = Util.el('div', 'rolagem'); t.replaceWith(c); c.append(t); }
    navegacao(corpo, r.dados.pagina);
    $('pagina').replaceChildren(Util.el('h2', 'ajuda-geral-titulo', r.dados.titulo), corpo);
    $('pagina').scrollTop = 0;
    window.scrollTo({ top: 0 });
    desenharLista();
  }

  $('busca').addEventListener('input', Util.atrasar(desenharLista, 150));
  window.addEventListener('hashchange', ir);
  desenharLista();
  await ir();
});
