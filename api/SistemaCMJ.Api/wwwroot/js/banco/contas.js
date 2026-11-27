/* =============================================================================
   SistemaCMJ - js/banco/contas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Lista de Contas bancárias (BANCO_CONTA): contas correntes,
               caixas e contas de permuta de todas as empresas, com busca e
               filtros de empresa, tipo e situação (na própria tela), exportação
               e abertura da ficha. Filtros guardados enquanto a aba estiver aberta.
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
  const CHAVE_FILTROS = 'cmj_filtros_contas';
  let todas = [];
  let visiveis = [];

  $('botao-incluir').hidden = !acoes.has('INCLUIR');
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('link-lixeira').hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');
  const verExtrato = Layout.acoesDe('banco/extrato.html').has('VER'); // atalho "Ver extrato" (04g4a)
  $('coluna-extrato').hidden = !verExtrato;

  let salvos = {};
  try { salvos = JSON.parse(sessionStorage.getItem(CHAVE_FILTROS) || '{}'); } catch { salvos = {}; }
  busca.value = salvos.busca || '';
  tipo.value = salvos.tipo || '';
  situacao.value = salvos.situacao || 'ATIVOS';

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const nomeEmpresa = (c) => c.EMPRESA_NOME_FANTASIA || c.EMPRESA_RAZAO_SOCIAL;
  const agenciaConta = (c) => c.AGENCIA ? (c.AGENCIA + (c.AGENCIA_DV ? '-' + c.AGENCIA_DV : '')) + ' / ' + (c.NUMERO + (c.NUMERO_DV ? '-' + c.NUMERO_DV : '')) : '';
  const abrir = (id) => { location.href = '/banco/conta.html?id=' + encodeURIComponent(id); };

  function filtrar() {
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify({ busca: busca.value, empresa: empresa.value, tipo: tipo.value, situacao: situacao.value }));
    const termo = semAcento(busca.value.trim());
    visiveis = todas.filter((c) =>
      (!empresa.value || String(c.ID_EMPRESA) === empresa.value)
      && (!tipo.value || c.TIPO === tipo.value)
      && (situacao.value === 'TODOS' || (situacao.value === 'ATIVOS') === !!c.ATIVO)
      && (!termo || semAcento(c.DESCRICAO).includes(termo) || semAcento(c.BANCO_NOME).includes(termo)
          || (c.NUMERO || '').includes(termo) || semAcento(nomeEmpresa(c)).includes(termo)));
    desenhar();
  }

  function desenhar() {
    corpo.replaceChildren();
    if (visiveis.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma conta encontrada com esses filtros.');
      td.colSpan = verExtrato ? 10 : 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const c of visiveis) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(c.ID_CONTA));
      tr.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') abrir(c.ID_CONTA); });
      const desc = Util.el('td', 'forte');
      const link = Util.el('a', null, c.DESCRICAO);
      link.href = '/banco/conta.html?id=' + encodeURIComponent(c.ID_CONTA);
      desc.append(link);
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (c.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), c.ATIVO ? 'Ativa' : 'Inativa'));
      tr.append(Util.el('td', null, nomeEmpresa(c)), desc,
        Util.el('td', null, Rotulos.de('contaTipo', c.TIPO)),
        Util.el('td', null, c.BANCO_CODIGO ? c.BANCO_CODIGO + ' - ' + c.BANCO_NOME : ''),
        Util.el('td', 'numero', agenciaConta(c)),
        Util.el('td', 'numero', c.SALDO_INICIAL ? Util.moeda(c.SALDO_INICIAL) + (c.DT_SALDO_INICIAL ? ' em ' + Util.data(c.DT_SALDO_INICIAL) : '') : ''),
        Util.el('td', null, c.CONCILIA ? 'Sim' : ''),
        Util.el('td', null, c.PADRAO_DA_EMPRESA ? 'Padrão' : ''),
        sit);
      if (verExtrato) {
        const tdExt = Util.el('td', 'col-extrato');
        const ext = Util.el('a', 'botao botao-pequeno', 'Extrato');
        ext.href = '/banco/extrato.html?conta=' + encodeURIComponent(c.ID_CONTA);
        ext.dataset.dica = 'Abre o extrato deste mês desta conta.';
        ext.addEventListener('click', (ev) => ev.stopPropagation());
        tdExt.append(ext);
        tr.append(tdExt);
      }
      corpo.append(tr);
    }
    $('contagem').textContent = visiveis.length === 1 ? '1 conta' : visiveis.length + ' contas';
  }

  async function carregar() {
    $('contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/banco/contas');
    if (!(await Mensagens.tratar(r, { foco: busca }))) { $('contagem').textContent = ''; return; }
    todas = r.dados || [];
    const empresas = new Map();
    for (const c of todas) empresas.set(String(c.ID_EMPRESA), nomeEmpresa(c));
    for (const [id, nome] of [...empresas].sort((a, b) => a[1].localeCompare(b[1], 'pt-BR'))) {
      const op = Util.el('option', null, nome);
      op.value = id;
      empresa.append(op);
    }
    empresa.value = Util.parametro('empresa') || salvos.empresa || '';
    if (!empresas.has(empresa.value)) empresa.value = '';
    filtrar();
  }

  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Contas_bancarias',
    ['Código', 'Empresa', 'Descrição', 'Tipo', 'Banco', 'Agência', 'Dígito agência', 'Conta', 'Dígito conta', 'Limite de crédito',
     'Saldo inicial', 'Data do saldo inicial', 'Concilia OFX', 'Mostra saldo', 'Conta contábil', 'Ordem', 'Padrão da empresa', 'Situação'],
    visiveis.map((c) => [c.ID_CONTA, nomeEmpresa(c), c.DESCRICAO, Rotulos.de('contaTipo', c.TIPO), c.BANCO_CODIGO ? c.BANCO_CODIGO + ' - ' + c.BANCO_NOME : '',
      c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, Util.moeda(c.LIMITE_CREDITO), Util.moeda(c.SALDO_INICIAL), Util.data(c.DT_SALDO_INICIAL),
      c.CONCILIA ? 'Sim' : 'Não', c.MOSTRA_SALDO ? 'Sim' : 'Não', c.CONTA_CONTABIL_REF, c.ORDEM, c.PADRAO_DA_EMPRESA ? 'Sim' : 'Não', c.ATIVO ? 'Ativa' : 'Inativa'])));
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); filtrar(); });
  busca.addEventListener('input', Util.atrasar(filtrar, 200));
  for (const s of [empresa, tipo, situacao]) s.addEventListener('change', filtrar);

  busca.focus();
  await carregar();
});
