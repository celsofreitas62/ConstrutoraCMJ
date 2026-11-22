/* =============================================================================
   SistemaCMJ - js/sis/usuarios.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Lista de Usuários (SIS_USUARIO): busca por login, nome ou
               e-mail, filtros de perfil e situação, situação da senha
               (provisória, vencida, bloqueado), exportação e abertura da
               ficha. Os filtros ficam guardados enquanto a aba estiver aberta.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();

  const busca = document.getElementById('busca');
  const perfil = document.getElementById('perfil');
  const situacao = document.getElementById('situacao');
  const corpo = document.getElementById('linhas');
  const contagem = document.getElementById('contagem');
  const CHAVE_FILTROS = 'cmj_filtros_usuarios';
  let ultima = [];
  let pedido = 0;

  document.getElementById('botao-incluir').hidden = !acoes.has('INCLUIR');
  const exportar = document.getElementById('botao-exportar');
  exportar.hidden = !acoes.has('EXPORTAR');

  const rPerfis = await Api.get('/api/sis/perfis', { situacao: 'TODOS' });
  if (rPerfis.sucesso) {
    for (const p of rPerfis.dados || []) {
      const o = Util.el('option', null, p.NOME + (p.ATIVO ? '' : ' (inativo)'));
      o.value = p.ID_PERFIL;
      perfil.append(o);
    }
  }

  try {
    const salvos = JSON.parse(sessionStorage.getItem(CHAVE_FILTROS) || '{}');
    busca.value = salvos.busca || '';
    perfil.value = salvos.perfil || '';
    situacao.value = salvos.situacao || 'ATIVOS';
  } catch { /* filtros guardados inválidos: usa o padrão */ }

  function abrir(id) { location.href = '/sis/usuario.html?id=' + encodeURIComponent(id); }

  function filtradas() {
    const id = parseInt(perfil.value || '0', 10);
    return id ? ultima.filter((u) => u.ID_PERFIL === id) : ultima;
  }

  function desenhar() {
    const linhas = filtradas();
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum usuário encontrado com esses filtros.');
      td.colSpan = 7;
      tr.append(td);
      corpo.append(tr);
    }
    for (const u of linhas) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.addEventListener('click', () => abrir(u.ID_USUARIO));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(u.ID_USUARIO); });

      const login = Util.el('td', 'forte');
      const link = Util.el('a', null, u.LOGIN);
      link.href = '/sis/usuario.html?id=' + encodeURIComponent(u.ID_USUARIO);
      login.append(link);
      if (u.PROPRIO) login.append(Util.el('div', 'suave', '(você)'));

      const perfilTd = Util.el('td', null, u.PERFIL_NOME || '');
      if (u.QTD_EXCECOES) perfilTd.append(Util.el('div', 'suave', u.QTD_EXCECOES === 1 ? '+ 1 exceção individual' : '+ ' + u.QTD_EXCECOES + ' exceções individuais'));

      const s = SituacaoSenha.de(u);
      const senha = Util.el('td');
      const etiqueta = Util.el('span', 'situacao ' + s.classe, s.texto);
      etiqueta.dataset.dica = s.dica;
      senha.append(etiqueta);

      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (u.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), u.ATIVO ? 'Ativo' : 'Inativo'));

      tr.append(
        login,
        Util.el('td', null, u.NOME || ''),
        Util.el('td', null, u.EMAIL || ''),
        perfilTd,
        senha,
        Util.el('td', 'numero', u.DT_ULTIMO_LOGIN ? Util.dataHora(u.DT_ULTIMO_LOGIN) : 'nunca entrou'),
        sit
      );
      corpo.append(tr);
    }
    contagem.textContent = linhas.length === 1 ? '1 usuário encontrado' : linhas.length + ' usuários encontrados';
  }

  async function carregar() {
    const filtros = { busca: busca.value.trim(), situacao: situacao.value };
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify({ ...filtros, perfil: perfil.value }));
    const meu = ++pedido;
    contagem.textContent = 'Buscando…';
    const r = await Api.get('/api/sis/usuarios', filtros);
    if (meu !== pedido) return;
    if (!(await Mensagens.tratar(r, { foco: busca }))) { contagem.textContent = ''; return; }
    ultima = r.dados || [];
    desenhar();
  }

  function exportarCsv() {
    const cab = ['Login', 'Nome', 'E-mail', 'Perfil', 'Exceções individuais', 'Senha', 'Último acesso', 'Situação'];
    const campo = (v) => {
      const t = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    };
    const linhas = filtradas().map((u) => [
      u.LOGIN, u.NOME, u.EMAIL, u.PERFIL_NOME, u.QTD_EXCECOES || 0, SituacaoSenha.de(u).texto,
      u.DT_ULTIMO_LOGIN ? Util.dataHora(u.DT_ULTIMO_LOGIN) : '', u.ATIVO ? 'Ativo' : 'Inativo'
    ].map(campo).join(';'));
    const texto = '﻿' + [cab.join(';'), ...linhas].join('\r\n');
    const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
    const a = Util.el('a');
    a.href = url;
    a.download = 'Usuarios_' + new Date().toISOString().substring(0, 10) + '.csv';
    document.body.append(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  document.getElementById('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });
  busca.addEventListener('input', Util.atrasar(carregar, 350));
  situacao.addEventListener('change', carregar);
  perfil.addEventListener('change', () => {
    sessionStorage.setItem(CHAVE_FILTROS, JSON.stringify({ busca: busca.value.trim(), situacao: situacao.value, perfil: perfil.value }));
    desenhar();
  });
  exportar.addEventListener('click', exportarCsv);

  busca.focus();
  carregar();
});
