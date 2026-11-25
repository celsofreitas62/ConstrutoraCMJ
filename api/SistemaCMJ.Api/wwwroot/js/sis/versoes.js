/* =============================================================================
   SistemaCMJ - js/sis/versoes.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (fase 4, conversa 04c2, pedido P22)
   Descrição : Tela Sistema › Versões (SIS_VERSOES).
               Aba Notas: o que é novo, melhorou ou foi corrigido em cada
               versão instalada, com filtro de versão, tipo e busca, e
               Exportar (EXPORTAR). Aberta para todos os usuários (a versão no
               topo das telas traz para cá); itens só do administrador geral
               já vêm filtrados pela procedure.
               Aba Histórico de atualizações: só para quem tem VER na tela.
               Regras e permissões: SIS_Versao_Nota_Listar e SIS_Versao_Listar (04c).
               Endereço ?versao=2.2 abre já filtrada.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeHistorico = acoes.has('VER');
  let notas = [];
  let versoesCarregadas = false;
  let historicoCarregado = false;
  let pedido = 0;

  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('aba-historico').hidden = !podeHistorico;

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    $('botao-exportar').hidden = !acoes.has('EXPORTAR') || aba.id !== 'aba-notas';
    if (aba.id === 'aba-historico' && !historicoCarregado) carregarHistorico();
  }
  abas.forEach((a) => a.addEventListener('click', () => abrirAba(a)));

  /** Texto da nota com só <b> e <code> (o resto vira texto puro). */
  function textoNota(n) {
    const span = Util.el('span');
    if (!n.TEXTO_HTML) { span.textContent = n.TEXTO || ''; return span; }
    const doc = new DOMParser().parseFromString('<body>' + n.TEXTO_HTML + '</body>', 'text/html');
    for (const no of doc.body.childNodes) {
      if (no.nodeType === Node.ELEMENT_NODE && (no.tagName === 'B' || no.tagName === 'CODE')) {
        span.append(Util.el(no.tagName.toLowerCase(), null, no.textContent));
      } else {
        span.append(document.createTextNode(no.textContent));
      }
    }
    return span;
  }

  function etiquetaTipo(n) {
    return Util.el('span', 'etiqueta etiqueta-' + String(n.TIPO || '').toLowerCase(), n.TIPO_NOME);
  }

  // ---------- Notas ----------
  function desenharNotas() {
    const area = $('notas');
    area.replaceChildren();
    if (!notas.length) {
      area.append(Util.el('p', 'vazio', 'Nenhuma nota encontrada com esses filtros.'));
      $('contagem').textContent = '';
      return;
    }
    let grupo = null;
    let lista = null;
    for (const n of notas) {
      if (!grupo || grupo.dataset.versao !== n.VERSAO) {
        grupo = Util.el('section', 'versao-bloco');
        grupo.dataset.versao = n.VERSAO;
        const titulo = Util.el('h2', 'versao-titulo', 'Versão ' + n.VERSAO + (n.DT_VERSAO ? ' (' + n.DT_VERSAO + ')' : ''));
        if (n.ATUAL) titulo.append(' ', Util.el('span', 'etiqueta etiqueta-atual', 'instalada'));
        lista = Util.el('ul', 'versao-itens');
        grupo.append(titulo, lista);
        area.append(grupo);
      }
      const li = Util.el('li');
      li.append(etiquetaTipo(n), ' ', textoNota(n));
      if (n.PUBLICO === 'GERAL') li.append(' ', Util.el('span', 'etiqueta', 'só administrador geral'));
      lista.append(li);
    }
    const qtdVersoes = new Set(notas.map((n) => n.VERSAO)).size;
    $('contagem').textContent = notas.length + (notas.length === 1 ? ' item' : ' itens') + ' em ' + qtdVersoes + (qtdVersoes === 1 ? ' versão' : ' versões');
  }

  async function carregarNotas() {
    const meu = ++pedido;
    const r = await Api.get('/api/sis/versoes/notas', { versao: $('versao').value, tipo: $('tipo').value, busca: $('busca').value.trim() });
    if (meu !== pedido) return;
    if (!(await Mensagens.tratar(r))) return;
    notas = r.dados || [];
    if (!versoesCarregadas && !$('versao').value && !$('tipo').value && !$('busca').value.trim()) {
      // A lista de versões do filtro sai da primeira consulta completa.
      const sel = $('versao');
      for (const v of [...new Set(notas.map((n) => n.VERSAO))]) sel.append(new Option(v, v));
      versoesCarregadas = true;
      const atual = notas.find((n) => n.ATUAL);
      $('subtitulo').textContent = atual ? 'Versão instalada: ' + atual.VERSAO : '';
    }
    desenharNotas();
  }

  function exportarCsv() {
    const campo = (v) => {
      const t = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    };
    const cab = ['Versão', 'Data', 'Tipo', 'Nota'];
    const linhas = notas.map((n) => [n.VERSAO, n.DT_VERSAO, n.TIPO_NOME, n.TEXTO].map(campo).join(';'));
    const texto = '﻿' + [cab.join(';'), ...linhas].join('\r\n');
    const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
    const a = Util.el('a');
    a.href = url;
    a.download = 'Versoes_' + new Date().toISOString().substring(0, 10) + '.csv';
    document.body.append(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  // ---------- Histórico de atualizações ----------
  function tempoFora(seg) {
    if (seg === null || seg === undefined || seg === '') return '';
    const s = Number(seg);
    if (s < 60) return s + ' s';
    return Math.floor(s / 60) + ' min ' + (s % 60) + ' s';
  }

  async function carregarHistorico() {
    const r = await Api.get('/api/sis/versoes/historico', { inicio: $('inicio').value, fim: $('fim').value });
    if (!(await Mensagens.tratar(r))) return;
    historicoCarregado = true;
    const corpo = $('linhas-historico');
    corpo.replaceChildren();
    const dados = r.dados || [];
    if (!dados.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma atualização no período.');
      td.colSpan = 7;
      tr.append(td);
      corpo.append(tr);
      return;
    }
    for (const h of dados) {
      const tr = Util.el('tr');
      const de = h.VERSAO_BANCO_DE || '';
      const para = h.VERSAO_BANCO_PARA || '';
      tr.append(
        Util.el('td', null, Util.dataHora(h.DT_INICIO)),
        Util.el('td', null, h.ORIGEM_NOME),
        Util.el('td', null, de ? de + ' → ' + para : para),
        Util.el('td', null, tempoFora(h.SEGUNDOS_FORA)),
        Util.el('td', null, h.SITUACAO_NOME || h.SITUACAO || ''),
        Util.el('td', null, [h.USUARIO, h.ESTACAO].filter(Boolean).join(' / ')),
        Util.el('td', null, h.MENSAGEM || '')
      );
      corpo.append(tr);
    }
  }

  // ---------- Eventos ----------
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregarNotas(); });
  $('filtros-historico').addEventListener('submit', (e) => { e.preventDefault(); carregarHistorico(); });
  $('versao').addEventListener('change', carregarNotas);
  $('tipo').addEventListener('change', carregarNotas);
  $('busca').addEventListener('input', Util.atrasar(carregarNotas, 350));
  $('inicio').addEventListener('change', carregarHistorico);
  $('fim').addEventListener('change', carregarHistorico);
  $('botao-exportar').addEventListener('click', exportarCsv);
  $('botao-atualizar').addEventListener('click', () => {
    if ($('aba-historico').getAttribute('aria-selected') === 'true') carregarHistorico(); else carregarNotas();
  });

  await carregarNotas();
  const pedida = Util.parametro('versao');
  if (pedida && [...$('versao').options].some((o) => o.value === pedida)) {
    $('versao').value = pedida;
    await carregarNotas();
  }
});
