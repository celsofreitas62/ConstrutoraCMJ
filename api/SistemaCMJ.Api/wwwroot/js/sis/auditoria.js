/* =============================================================================
   SistemaCMJ - js/sis/auditoria.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 23/11/2026 (fase 4, conversa 04b2, pedido P20)
   Descrição : Tela Sistema › Auditoria (SIS_AUDITORIA), o histórico geral:
               filtros por período, usuário, tabela, registro, operação e
               lote; linhas agrupadas por operação (TRANSACAO). Quem tem
               DESFAZER nesta tela pode "Desfazer esta operação" e "Desfazer
               o lote inteiro", sempre pela prévia do componente Historico
               (tudo ou nada, com motivo). A procedure confere também a
               permissão DESFAZER na tela de cada registro que vai mudar.
               Endereço aceita ?lote=, ?tabela= e ?id= (filtros já prontos).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeDesfazer = acoes.has('DESFAZER');
  let pedido = 0;

  function linhaVazia(corpo, texto) {
    const tr = Util.el('tr');
    const td = Util.el('td', 'vazio', texto);
    td.colSpan = 6;
    tr.append(td);
    corpo.append(tr);
  }

  function celula(texto, classe) {
    const resumo = Historico.resumoFoto(texto);
    const td = Util.el('td', 'celula-valor' + (classe ? ' ' + classe : ''), resumo.length > 160 ? resumo.substring(0, 157) + '…' : resumo);
    if (resumo !== (texto || '') || resumo.length > 160) td.title = texto;
    return td;
  }

  function botao(texto, dica, acao) {
    const b = Util.el('button', 'botao botao-pequeno', texto);
    b.type = 'button';
    b.dataset.dica = dica;
    b.addEventListener('click', acao);
    return b;
  }

  async function desfazer(o) {
    if (await Historico.desfazer({ item: 'SIS_AUDITORIA', ...o })) listar();
  }

  function desenhar(linhas) {
    const corpo = $('linhas');
    corpo.replaceChildren();
    if (!linhas.length) { linhaVazia(corpo, 'Nada encontrado com esses filtros.'); $('contagem').textContent = ''; return; }
    const grupos = new Map();
    for (const l of linhas) {
      const chave = l.TRANSACAO != null ? 't' + l.TRANSACAO : 'a' + l.ID_AUDITORIA;
      if (!grupos.has(chave)) grupos.set(chave, []);
      grupos.get(chave).push(l);
    }
    for (const g of grupos.values()) {
      g.sort((a, b) => a.ID_AUDITORIA - b.ID_AUDITORIA);
      const topo = g[g.length - 1];
      const cab = Util.el('tr', 'linha-grupo');
      const td = Util.el('td');
      td.colSpan = 6;
      const info = Util.el('span', 'grupo-info');
      info.append(Util.el('strong', 'numero', Util.dataHora(topo.DT_OPERACAO)), document.createTextNode(' · ' + (topo.USUARIO || '')));
      if (topo.ESTACAO) info.append(Util.el('span', 'suave', ' · ' + topo.ESTACAO));
      if (topo.ORIGEM) info.append(Util.el('span', 'suave', ' · ' + topo.ORIGEM));
      if (topo.ID_LOTE) {
        info.append(document.createTextNode(' · '));
        const link = Util.el('a', null, 'lote ' + topo.ID_LOTE);
        link.href = '#';
        link.dataset.dica = 'Mostra só o que este lote fez.';
        link.addEventListener('click', (e) => { e.preventDefault(); $('lote').value = topo.ID_LOTE; $('inicio').value = '2000-01-01'; $('fim').value = ''; listar(); });
        info.append(link);
      }
      td.append(info);
      if (podeDesfazer) {
        const caixa = Util.el('span', 'grupo-acoes');
        caixa.append(botao('Desfazer esta operação', 'Desfaz só o que foi gravado nesta operação. Recusa se alguém mexeu depois nos mesmos campos. Mostra a prévia e pede o motivo.',
          () => desfazer({ modo: 'OPERACAO', idAuditoria: topo.ID_AUDITORIA, titulo: 'Desfazer a operação de ' + Util.dataHora(topo.DT_OPERACAO) + '?',
            explicacao: 'O que foi gravado nesta operação volta como estava antes dela (inclusões vão para a lixeira ou são desativadas).' })));
        if (topo.ID_LOTE) {
          caixa.append(botao('Desfazer o lote ' + topo.ID_LOTE, 'Desfaz tudo o que este lote fez, em todas as telas, na ordem inversa. Tudo ou nada. Mostra a prévia e pede o motivo.',
            () => desfazer({ modo: 'LOTE', idLote: topo.ID_LOTE, titulo: 'Desfazer o lote ' + topo.ID_LOTE + '?',
              explicacao: 'Tudo o que o lote ' + topo.ID_LOTE + ' fez volta como estava antes. Se alguém mexeu depois num dos campos, nada é desfeito.' })));
        }
        td.append(caixa);
      }
      cab.append(td);
      corpo.append(cab);
      for (const l of g) {
        const tr = Util.el('tr');
        const reg = Util.el('td');
        reg.append(Util.el('div', 'numero', l.TABELA + ' #' + l.ID_REGISTRO));
        tr.append(Util.el('td', null, l.TELA_NOME || ''), reg, Util.el('td', null, l.OPERACAO_NOME || ''),
          Util.el('td', null, l.CAMPO || '(registro)'), celula(l.VALOR_ANTES, 'suave'), celula(l.VALOR_DEPOIS));
        corpo.append(tr);
      }
    }
    $('contagem').textContent = grupos.size + (grupos.size === 1 ? ' operação' : ' operações') + ' · ' + linhas.length + ' mudanças'
      + (linhas.length >= 2000 ? ' (mostrando as 2000 mais recentes: use os filtros para ver as outras)' : '');
  }

  async function listar() {
    const meu = ++pedido;
    const corpo = $('linhas');
    corpo.replaceChildren();
    linhaVazia(corpo, 'Carregando…');
    const r = await Api.get('/api/sis/auditoria', {
      inicio: $('inicio').value, fim: $('fim').value, usuario: $('usuario').value.trim(), tabela: $('tabela').value.trim(),
      idRegistro: $('registro').value, operacao: $('operacao').value, lote: $('lote').value
    });
    if (meu !== pedido) return;
    if (!r.sucesso) { corpo.replaceChildren(); await Mensagens.tratar(r); linhaVazia(corpo, 'Lista indisponível.'); return; }
    desenhar(r.dados || []);
  }

  if (Util.parametro('lote')) $('lote').value = Util.parametro('lote');
  if (Util.parametro('tabela')) $('tabela').value = Util.parametro('tabela');
  if (Util.parametro('id')) $('registro').value = Util.parametro('id');
  if (Util.parametro('lote')) $('inicio').value = '2000-01-01';
  else {
    const hoje = new Date();
    const antes = new Date(hoje.getTime() - 7 * 86400000);
    const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    $('fim').value = iso(hoje);
    $('inicio').value = iso(antes);
  }
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); listar(); });
  $('botao-atualizar').addEventListener('click', listar);
  listar();
});
