/* =============================================================================
   SistemaCMJ - js/sis/perfis.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Lista de Perfis (SIS_PERFIL): tipo (administrador ou comum),
               quantos usuários ativos e quantas permissões, filtro de
               situação, exportação e abertura da ficha.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();

  const situacao = document.getElementById('situacao');
  const corpo = document.getElementById('linhas');
  const contagem = document.getElementById('contagem');
  const CHAVE_FILTROS = 'cmj_filtros_perfis';
  let ultima = [];

  document.getElementById('botao-incluir').hidden = !acoes.has('INCLUIR');
  const exportar = document.getElementById('botao-exportar');
  exportar.hidden = !acoes.has('EXPORTAR');
  situacao.value = sessionStorage.getItem(CHAVE_FILTROS) || 'ATIVOS';

  const tipo = (p) => p.NIVEL_ADMIN >= 2 ? 'Administrador geral' : p.NIVEL_ADMIN === 1 ? 'Administrador' : 'Comum';
  const permissoes = (p) => p.NIVEL_ADMIN >= 1 ? 'Todas' : String(p.QTD_PERMISSOES || 0);
  function abrir(id) { location.href = '/sis/perfil.html?id=' + encodeURIComponent(id); }

  function desenhar() {
    corpo.replaceChildren();
    if (ultima.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum perfil encontrado.');
      td.colSpan = 6;
      tr.append(td);
      corpo.append(tr);
    }
    for (const p of ultima) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(p.ID_PERFIL));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(p.ID_PERFIL); });
      const nome = Util.el('td', 'forte');
      const link = Util.el('a', null, p.NOME);
      link.href = '/sis/perfil.html?id=' + encodeURIComponent(p.ID_PERFIL);
      nome.append(link);
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (p.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), p.ATIVO ? 'Ativo' : 'Inativo'));
      tr.append(nome, Util.el('td', 'suave', p.DESCRICAO || ''), Util.el('td', null, tipo(p)),
        Util.el('td', 'numero', String(p.QTD_USUARIOS_ATIVOS || 0)), Util.el('td', 'numero', permissoes(p)), sit);
      corpo.append(tr);
    }
    contagem.textContent = ultima.length === 1 ? '1 perfil' : ultima.length + ' perfis';
  }

  async function carregar() {
    sessionStorage.setItem(CHAVE_FILTROS, situacao.value);
    contagem.textContent = 'Buscando…';
    const r = await Api.get('/api/sis/perfis', { situacao: situacao.value });
    if (!(await Mensagens.tratar(r))) { contagem.textContent = ''; return; }
    ultima = r.dados || [];
    desenhar();
  }

  function exportarCsv() {
    const campo = (v) => {
      const t = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    };
    const linhas = ultima.map((p) => [p.NOME, p.DESCRICAO, tipo(p), p.QTD_USUARIOS_ATIVOS || 0, permissoes(p), p.ATIVO ? 'Ativo' : 'Inativo'].map(campo).join(';'));
    const texto = '﻿' + [['Perfil', 'Para que serve', 'Tipo', 'Usuários ativos', 'Permissões', 'Situação'].join(';'), ...linhas].join('\r\n');
    const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
    const a = Util.el('a');
    a.href = url;
    a.download = 'Perfis_' + new Date().toISOString().substring(0, 10) + '.csv';
    document.body.append(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  document.getElementById('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });
  situacao.addEventListener('change', carregar);
  exportar.addEventListener('click', exportarCsv);
  carregar();
});
