/* =============================================================================
   SistemaCMJ - js/cad/pessoas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Lista de Parceiros (CAD_PESSOA): busca por parte do nome, CPF/CNPJ
               ou código, filtros de tipo, situação e pendências, exportação e abertura da
               ficha. Os filtros ficam guardados enquanto a aba do navegador
               estiver aberta (voltar da ficha mantém a busca).
               04d2 (25/11/2026): rótulo pelo parâmetro (PARCEIRO_ROTULO_PLURAL,
               vindo da sessão), filtro por tipo de parceiro no lugar do papel,
               "Pendências de cadastro" e coluna Cobrança (P10: o que falta).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao, acoes } = await Layout.iniciar();
  const ROTULO = (sessao && sessao.parceiroRotuloPlural) || 'Parceiros';
  document.title = 'SistemaCMJ – ' + ROTULO;
  document.getElementById('titulo').textContent = ROTULO;
  document.getElementById('caminho').textContent = 'Cadastros › ' + ROTULO;

  const busca = document.getElementById('busca');
  const tipo = document.getElementById('tipo');
  const pendencias = document.getElementById('pendencias');
  const situacao = document.getElementById('situacao');
  const corpo = document.getElementById('linhas');
  const contagem = document.getElementById('contagem');
  const CHAVE_FILTROS = 'cmj_filtros_pessoas';
  let ultima = [];
  let pedido = 0;

  document.getElementById('botao-incluir').hidden = !acoes.has('INCLUIR');
  document.getElementById('link-lixeira').hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');
  const exportar = document.getElementById('botao-exportar');
  exportar.hidden = !acoes.has('EXPORTAR');

  try {
    const salvos = JSON.parse(sessionStorage.getItem(CHAVE_FILTROS) || '{}');
    busca.value = salvos.busca || '';
    tipo.dataset.salvo = salvos.idParceiroTipo || '';
    pendencias.checked = salvos.pendenciaCobranca === true;
    situacao.value = salvos.situacao || 'ATIVOS';
  } catch { /* filtros guardados inválidos: usa o padrão */ }

  async function carregarTipos() {
    const r = await Api.get('/api/cad/parceiro-tipos', { somenteAtivos: true });
    if (!r.sucesso) return; // sem a lista de tipos o filtro fica só com "Todos"
    for (const t of r.dados || []) {
      const op = Util.el('option', null, t.DESCRICAO);
      op.value = t.ID_PARCEIRO_TIPO;
      tipo.append(op);
    }
    tipo.value = tipo.dataset.salvo || '';
    if (tipo.value !== (tipo.dataset.salvo || '')) tipo.value = '';
  }

  const separar = (texto, sep) => (texto || '').split(sep).map((t) => t.trim()).filter(Boolean);

  function abrir(id) { location.href = '/cad/pessoa.html?id=' + encodeURIComponent(id); }

  function desenhar(linhas) {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum parceiro encontrado com esses filtros.');
      td.colSpan = 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const p of linhas) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(p.ID_PESSOA));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(p.ID_PESSOA); });

      const nome = Util.el('td', 'forte');
      const link = Util.el('a', null, p.NOME);
      link.href = '/cad/pessoa.html?id=' + encodeURIComponent(p.ID_PESSOA);
      nome.append(link);
      if (p.NOME_FANTASIA) nome.append(Util.el('div', 'suave', p.NOME_FANTASIA));

      const tipos = Util.el('td');
      const etiquetas = Util.el('div', 'etiquetas');
      for (const t of separar(p.TIPOS, ',')) etiquetas.append(Util.el('span', 'etiqueta', t));
      tipos.append(etiquetas);

      // P10: só clientes têm a conferência (APTO_COBRANCA vem nulo para os demais).
      const cobranca = Util.el('td');
      if (p.APTO_COBRANCA === true) cobranca.append(Util.el('span', 'etiqueta etiqueta-novo', 'Apto'));
      else if (p.APTO_COBRANCA === false) {
        const falta = Util.el('div', 'etiquetas');
        for (const f of separar(p.PENDENCIA_COBRANCA, ';')) falta.append(Util.el('span', 'etiqueta etiqueta-correcao', f));
        cobranca.append(falta);
        if (p.TITULO_ABERTO) cobranca.append(Util.el('div', 'suave', 'tem parcela em aberto'));
      }

      const contato = Util.el('td');
      if (p.EMAIL_PRINCIPAL) contato.append(Util.el('div', null, p.EMAIL_PRINCIPAL));
      if (p.TELEFONE_PRINCIPAL) contato.append(Util.el('div', 'suave', p.TELEFONE_PRINCIPAL));

      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (p.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), p.ATIVO ? 'Ativo' : 'Inativo'));

      tr.append(
        Util.el('td', 'numero suave', String(p.ID_PESSOA).padStart(6, '0')),
        nome,
        Util.el('td', 'numero', p.DOCUMENTO || ''),
        Util.el('td', null, p.TIPO_PESSOA === 'J' ? 'PJ' : 'PF'),
        tipos,
        contato,
        Util.el('td', null, [p.CIDADE, p.UF].filter(Boolean).join('/')),
        cobranca,
        sit
      );
      corpo.append(tr);
    }
    contagem.textContent = linhas.length === 1 ? '1 parceiro encontrado' : linhas.length + ' parceiros encontrados'
      + (linhas.length >= 500 ? ' (mostrando as 500 primeiras: refine a busca)' : '');
  }

  async function carregar() {
    const filtros = { busca: busca.value.trim(), idParceiroTipo: tipo.value, situacao: situacao.value, pendenciaCobranca: pendencias.checked };
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify(filtros));
    const meu = ++pedido;
    contagem.textContent = 'Buscando…';
    const r = await Api.get('/api/cad/pessoas', filtros);
    if (meu !== pedido) return; // chegou resposta de uma busca mais nova
    if (!(await Mensagens.tratar(r, { foco: busca }))) { contagem.textContent = ''; return; }
    ultima = r.dados || [];
    desenhar(ultima);
  }

  function exportarCsv() {
    const cab = ['Código', 'Nome', 'Nome fantasia', 'CPF/CNPJ', 'PF/PJ', 'Tipos', 'E-mail', 'Telefone', 'Cidade', 'UF', 'Cobrança', 'Parcela em aberto', 'Situação'];
    const campo = (v) => {
      const t = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    };
    const linhas = ultima.map((p) => [
      p.ID_PESSOA, p.NOME, p.NOME_FANTASIA, p.DOCUMENTO, p.TIPO_PESSOA === 'J' ? 'PJ' : 'PF',
      p.TIPOS, p.EMAIL_PRINCIPAL, p.TELEFONE_PRINCIPAL, p.CIDADE, p.UF,
      p.APTO_COBRANCA === true ? 'Apto' : (p.APTO_COBRANCA === false ? 'Falta: ' + p.PENDENCIA_COBRANCA : ''),
      p.TITULO_ABERTO ? 'Sim' : 'Não', p.ATIVO ? 'Ativo' : 'Inativo'
    ].map(campo).join(';'));
    const texto = '﻿' + [cab.join(';'), ...linhas].join('\r\n');
    const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
    const a = Util.el('a');
    a.href = url;
    a.download = ROTULO.replace(/\s+/g, '_') + '_' + new Date().toISOString().substring(0, 10) + '.csv';
    document.body.append(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  document.getElementById('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });
  busca.addEventListener('input', Util.atrasar(carregar, 350));
  tipo.addEventListener('change', carregar);
  pendencias.addEventListener('change', carregar);
  situacao.addEventListener('change', carregar);
  exportar.addEventListener('click', exportarCsv);

  busca.focus();
  await carregarTipos();
  carregar();
});
