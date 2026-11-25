/* =============================================================================
   SistemaCMJ - js/cad/empresas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Lista de Empresas (CAD_EMPRESA): busca por razão social, nome
               fantasia ou CNPJ, filtros de tipo e situação (na própria tela:
               são poucas empresas), exportação e abertura da ficha. Os filtros
               ficam guardados enquanto a aba do navegador estiver aberta.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const busca = $('busca');
  const tipo = $('tipo');
  const situacao = $('situacao');
  const corpo = $('linhas');
  const CHAVE_FILTROS = 'cmj_filtros_empresas';
  let todas = [];
  let visiveis = [];

  $('botao-incluir').hidden = !acoes.has('INCLUIR');
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('link-lixeira').hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');

  try {
    const s = JSON.parse(sessionStorage.getItem(CHAVE_FILTROS) || '{}');
    busca.value = s.busca || '';
    tipo.value = s.tipo || '';
    situacao.value = s.situacao || 'ATIVOS';
  } catch { /* filtros guardados inválidos: usa o padrão */ }

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const abrir = (id) => { location.href = '/cad/empresa.html?id=' + encodeURIComponent(id); };

  function filtrar() {
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify({ busca: busca.value, tipo: tipo.value, situacao: situacao.value }));
    const termo = semAcento(busca.value.trim());
    const digitos = busca.value.replace(/\D/g, '');
    visiveis = todas.filter((e) =>
      (!tipo.value || e.TIPO === tipo.value)
      && (situacao.value === 'TODOS' || (situacao.value === 'ATIVOS') === !!e.ATIVO)
      && (!termo || semAcento(e.RAZAO_SOCIAL).includes(termo) || semAcento(e.NOME_FANTASIA).includes(termo)
          || (digitos.length >= 2 && (e.CNPJ || '').startsWith(digitos))));
    desenhar();
  }

  function desenhar() {
    corpo.replaceChildren();
    if (visiveis.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma empresa encontrada com esses filtros.');
      td.colSpan = 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const e of visiveis) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(e.ID_EMPRESA));
      tr.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') abrir(e.ID_EMPRESA); });
      const nome = Util.el('td', 'forte');
      const link = Util.el('a', null, e.RAZAO_SOCIAL);
      link.href = '/cad/empresa.html?id=' + encodeURIComponent(e.ID_EMPRESA);
      nome.append(link);
      if (e.NOME_FANTASIA) nome.append(Util.el('div', 'suave', e.NOME_FANTASIA));
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (e.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), e.ATIVO ? 'Ativa' : 'Inativa'));
      tr.append(nome,
        Util.el('td', 'numero', e.CNPJ_FORMATADO || ''),
        Util.el('td', null, Rotulos.de('empresaTipo', e.TIPO)),
        Util.el('td', null, Rotulos.de('regime', e.REGIME_TRIBUTARIO)),
        Util.el('td', null, [e.CIDADE, e.UF].filter(Boolean).join('/')),
        Util.el('td', null, e.CONTA_PADRAO_DESCRICAO || ''),
        Util.el('td', 'numero', String(e.QTD_CONTAS ?? 0)),
        Util.el('td', 'numero', String(e.QTD_CENTROS ?? 0)),
        sit);
      corpo.append(tr);
    }
    $('contagem').textContent = visiveis.length === 1 ? '1 empresa' : visiveis.length + ' empresas';
  }

  async function carregar() {
    $('contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/cad/empresas');
    if (!(await Mensagens.tratar(r, { foco: busca }))) { $('contagem').textContent = ''; return; }
    todas = r.dados || [];
    filtrar();
  }

  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Empresas',
    ['Código', 'Razão social', 'Nome fantasia', 'CNPJ', 'CNPJ compras/DDA', 'Tipo', 'Regime', 'Inscrição estadual', 'Inscrição municipal',
     'CEP', 'Endereço', 'Número', 'Complemento', 'Bairro', 'Cidade', 'UF', 'E-mail', 'Telefone', 'Conta padrão', 'Contas', 'Centros', 'Situação'],
    visiveis.map((e) => [e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ_FORMATADO, e.CNPJ_COMPRAS_FORMATADO, Rotulos.de('empresaTipo', e.TIPO),
      Rotulos.de('regime', e.REGIME_TRIBUTARIO), e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.CEP, e.LOGRADOURO, e.NUMERO,
      e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE, e.CONTA_PADRAO_DESCRICAO, e.QTD_CONTAS, e.QTD_CENTROS, e.ATIVO ? 'Ativa' : 'Inativa'])));
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); filtrar(); });
  busca.addEventListener('input', Util.atrasar(filtrar, 200));
  tipo.addEventListener('change', filtrar);
  situacao.addEventListener('change', filtrar);

  busca.focus();
  await carregar();
});
