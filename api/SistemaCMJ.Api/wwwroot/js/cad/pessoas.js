/* =============================================================================
   SistemaCMJ - js/cad/pessoas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Lista de Pessoas (CAD_PESSOA): busca por parte do nome, CPF/CNPJ
               ou código, filtros de papel e situação, exportação e abertura da
               ficha. Os filtros ficam guardados enquanto a aba do navegador
               estiver aberta (voltar da ficha mantém a busca).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();

  const busca = document.getElementById('busca');
  const papel = document.getElementById('papel');
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
    papel.value = salvos.papel || '';
    situacao.value = salvos.situacao || 'ATIVOS';
  } catch { /* filtros guardados inválidos: usa o padrão */ }

  const PAPEIS = [['CLIENTE', 'Cliente'], ['FORNECEDOR', 'Fornecedor'], ['FUNCIONARIO', 'Funcionário'], ['CORRETOR', 'Corretor']];

  function abrir(id) { location.href = '/cad/pessoa.html?id=' + encodeURIComponent(id); }

  function desenhar(linhas) {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma pessoa encontrada com esses filtros.');
      td.colSpan = 8;
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

      const papeis = Util.el('td');
      const etiquetas = Util.el('div', 'etiquetas');
      for (const [coluna, texto] of PAPEIS) if (p[coluna]) etiquetas.append(Util.el('span', 'etiqueta', texto));
      papeis.append(etiquetas);

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
        papeis,
        contato,
        Util.el('td', null, [p.CIDADE, p.UF].filter(Boolean).join('/')),
        sit
      );
      corpo.append(tr);
    }
    contagem.textContent = linhas.length === 1 ? '1 pessoa encontrada' : linhas.length + ' pessoas encontradas'
      + (linhas.length >= 500 ? ' (mostrando as 500 primeiras: refine a busca)' : '');
  }

  async function carregar() {
    const filtros = { busca: busca.value.trim(), papel: papel.value, situacao: situacao.value };
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
    const cab = ['Código', 'Nome', 'Nome fantasia', 'CPF/CNPJ', 'Tipo', 'Cliente', 'Fornecedor', 'Funcionário', 'Corretor', 'E-mail', 'Telefone', 'Cidade', 'UF', 'Situação'];
    const campo = (v) => {
      const t = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    };
    const linhas = ultima.map((p) => [
      p.ID_PESSOA, p.NOME, p.NOME_FANTASIA, p.DOCUMENTO, p.TIPO_PESSOA === 'J' ? 'PJ' : 'PF',
      p.CLIENTE ? 'Sim' : 'Não', p.FORNECEDOR ? 'Sim' : 'Não', p.FUNCIONARIO ? 'Sim' : 'Não', p.CORRETOR ? 'Sim' : 'Não',
      p.EMAIL_PRINCIPAL, p.TELEFONE_PRINCIPAL, p.CIDADE, p.UF, p.ATIVO ? 'Ativo' : 'Inativo'
    ].map(campo).join(';'));
    const texto = '﻿' + [cab.join(';'), ...linhas].join('\r\n');
    const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
    const a = Util.el('a');
    a.href = url;
    a.download = 'Pessoas_' + new Date().toISOString().substring(0, 10) + '.csv';
    document.body.append(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  document.getElementById('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });
  busca.addEventListener('input', Util.atrasar(carregar, 350));
  papel.addEventListener('change', carregar);
  situacao.addEventListener('change', carregar);
  exportar.addEventListener('click', exportarCsv);

  busca.focus();
  carregar();
});
