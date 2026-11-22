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
    $('pagina').replaceChildren(Util.el('h2', 'ajuda-geral-titulo', r.dados.titulo), corpo);
    $('pagina').scrollTop = 0;
    window.scrollTo({ top: 0 });
    desenharLista();
  }

  $('busca').addEventListener('input', Util.atrasar(desenharLista, 150));
  window.addEventListener('hashchange', () => abrir(location.hash.substring(1)));
  desenharLista();
  await abrir(location.hash.substring(1) || (paginas[0] ? paginas[0].pagina : ''));
});
