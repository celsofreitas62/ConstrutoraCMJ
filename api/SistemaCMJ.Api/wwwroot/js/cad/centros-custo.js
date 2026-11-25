/* =============================================================================
   SistemaCMJ - js/cad/centros-custo.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Lista de Centros de custo (CAD_CENTRO_CUSTO): busca, filtros de
               empresa, tipo e situação (em uso, encerrados, inativos), feitos na
               própria tela, exportação e abertura da ficha. A conta padrão
               mostrada é a do centro ou, se vazia, a da empresa.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const busca = $('busca');
  const empresa = $('empresa');
  const tipo = $('tipo');
  const situacao = $('situacao');
  const corpo = $('linhas');
  const CHAVE_FILTROS = 'cmj_filtros_centros';
  let todos = [];
  let visiveis = [];

  $('botao-incluir').hidden = !acoes.has('INCLUIR');
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('link-lixeira').hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');

  let salvos = {};
  try { salvos = JSON.parse(sessionStorage.getItem(CHAVE_FILTROS) || '{}'); } catch { salvos = {}; }
  busca.value = salvos.busca || '';
  tipo.value = salvos.tipo || '';
  situacao.value = salvos.situacao || 'EM_USO';

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const nomeEmpresa = (c) => c.EMPRESA_NOME_FANTASIA || c.EMPRESA_RAZAO_SOCIAL;
  const contaPadrao = (c) => c.CONTA_PADRAO_DESCRICAO || (c.CONTA_EFETIVA_DESCRICAO ? c.CONTA_EFETIVA_DESCRICAO + ' (da empresa)' : '');
  const abrir = (id) => { location.href = '/cad/centro-custo.html?id=' + encodeURIComponent(id); };
  const naSituacao = (c) => ({
    EM_USO: c.ATIVO && !c.ENCERRADO, ENCERRADOS: c.ATIVO && c.ENCERRADO, INATIVOS: !c.ATIVO, TODOS: true
  })[situacao.value];

  function filtrar() {
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify({ busca: busca.value, empresa: empresa.value, tipo: tipo.value, situacao: situacao.value }));
    const termo = semAcento(busca.value.trim());
    visiveis = todos.filter((c) => naSituacao(c)
      && (!empresa.value || String(c.ID_EMPRESA) === empresa.value)
      && (!tipo.value || c.TIPO === tipo.value)
      && (!termo || semAcento(c.DESCRICAO).includes(termo) || semAcento(c.CODIGO).startsWith(termo)));
    desenhar();
  }

  function desenhar() {
    corpo.replaceChildren();
    if (visiveis.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum centro de custo encontrado com esses filtros.');
      td.colSpan = 8;
      tr.append(td);
      corpo.append(tr);
    }
    for (const c of visiveis) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(c.ID_CENTRO_CUSTO));
      tr.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') abrir(c.ID_CENTRO_CUSTO); });
      const desc = Util.el('td', 'forte');
      const link = Util.el('a', null, c.DESCRICAO);
      link.href = '/cad/centro-custo.html?id=' + encodeURIComponent(c.ID_CENTRO_CUSTO);
      desc.append(link);
      const sit = Util.el('td');
      const rotulo = !c.ATIVO ? 'Inativo' : (c.ENCERRADO ? 'Encerrado' : 'Em uso');
      sit.append(Util.el('span', 'situacao ' + (c.ATIVO && !c.ENCERRADO ? 'situacao-ativo' : 'situacao-inativo'), rotulo));
      tr.append(Util.el('td', 'numero', c.CODIGO), desc, Util.el('td', null, Rotulos.de('centroTipo', c.TIPO)),
        Util.el('td', null, nomeEmpresa(c)), Util.el('td', null, contaPadrao(c)),
        Util.el('td', null, c.CONTABIL ? 'Sim' : 'Não'), Util.el('td', null, Util.data(c.DT_ENCERRAMENTO)), sit);
      corpo.append(tr);
    }
    $('contagem').textContent = visiveis.length === 1 ? '1 centro de custo' : visiveis.length + ' centros de custo';
  }

  async function carregar() {
    $('contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/cad/centros-custo');
    if (!(await Mensagens.tratar(r, { foco: busca }))) { $('contagem').textContent = ''; return; }
    todos = r.dados || [];
    const empresas = new Map();
    for (const c of todos) empresas.set(String(c.ID_EMPRESA), nomeEmpresa(c));
    for (const [id, nome] of [...empresas].sort((a, b) => a[1].localeCompare(b[1], 'pt-BR'))) {
      const op = Util.el('option', null, nome);
      op.value = id;
      empresa.append(op);
    }
    empresa.value = Util.parametro('empresa') || salvos.empresa || '';
    if (!empresas.has(empresa.value)) empresa.value = '';
    filtrar();
  }

  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Centros_de_custo',
    ['Código', 'Descrição', 'Tipo', 'Empresa', 'Conta padrão', 'Contábil', 'Encerramento', 'Situação'],
    visiveis.map((c) => [c.CODIGO, c.DESCRICAO, Rotulos.de('centroTipo', c.TIPO), nomeEmpresa(c), contaPadrao(c), c.CONTABIL ? 'Sim' : 'Não',
      Util.data(c.DT_ENCERRAMENTO), !c.ATIVO ? 'Inativo' : (c.ENCERRADO ? 'Encerrado' : 'Em uso')])));
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); filtrar(); });
  busca.addEventListener('input', Util.atrasar(filtrar, 200));
  for (const s of [empresa, tipo, situacao]) s.addEventListener('change', filtrar);

  busca.focus();
  await carregar();
});
