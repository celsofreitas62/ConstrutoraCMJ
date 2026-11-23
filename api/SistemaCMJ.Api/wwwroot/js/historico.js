/* =============================================================================
   SistemaCMJ - js/historico.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 23/11/2026 (fase 4, conversa 04b2, pedido P20)
   Descrição : Componente ÚNICO da aba Histórico de todas as fichas e da
               prévia do desfazer (docs/requisitos/Lixeira_Desfazer.md, seção 3).
     Historico.criar(destino, { item, tabela, id, podeDesfazer, aoDesfazer })
         monta a aba: filtros (período, usuário, parte, campo) e a linha do
         tempo agrupada por operação (o que foi gravado junto), com os botões
         "Voltar para como estava aqui" e "Desfazer esta operação".
         Devolve { carregar }.
     Historico.desfazer({ item, modo, tabela, idRegistro, idAuditoria, idLote,
                          titulo, explicacao })
         abre a prévia (agora × como vai ficar), pede o motivo e desfaz tudo
         ou nada. Devolve true se desfez. Usado também pela tela Auditoria.
     Historico.resumoFoto(texto)   "foto" JSON de inclusão/exclusão em texto curto.
   Permissão e regras ficam nas procedures (SIS_Historico_*); a tela só
   esconde o que o usuário não pode fazer.
   ========================================================================== */
'use strict';

const Historico = (() => {
  const CONTROLE = /^(ID_|DT_CRIACAO$|USUARIO_CRIACAO$|DT_ALTERACAO$|USUARIO_ALTERACAO$|DT_EXCLUSAO$|USUARIO_EXCLUSAO$|SENHA_)/i;
  const ACAO = { ALTERAR: 'Altera', LIXEIRA: 'Vai para a lixeira', APAGAR: 'Retira', REINSERIR: 'Devolve', DESATIVAR: 'Desativa' };

  /** "Foto" JSON (inclusão/exclusão) em texto curto: CAMPO: valor; ... */
  function resumoFoto(texto) {
    if (!texto || texto[0] !== '{') return texto || '';
    try {
      const o = JSON.parse(texto);
      return Object.entries(o)
        .filter(([k, v]) => !CONTROLE.test(k) && v !== null && v !== '')
        .map(([k, v]) => k + ': ' + (v === true ? 'sim' : v === false ? 'não' : v))
        .join('; ');
    } catch { return texto; }
  }

  function celulaValor(texto, classe) {
    const resumo = resumoFoto(texto);
    const td = Util.el('td', 'celula-valor' + (classe ? ' ' + classe : ''), resumo.length > 180 ? resumo.substring(0, 177) + '…' : resumo);
    if (resumo.length > 180 || resumo !== (texto || '')) td.title = texto;
    return td;
  }

  function linhaVazia(corpo, colunas, texto) {
    const tr = Util.el('tr');
    const td = Util.el('td', 'vazio', texto);
    td.colSpan = colunas;
    tr.append(td);
    corpo.append(tr);
  }

  function opcoes(select, valores, todos) {
    const atual = select.value;
    select.replaceChildren(Util.el('option', null, todos));
    select.firstChild.value = '';
    for (const v of valores) { const o = Util.el('option', null, v); o.value = v; select.append(o); }
    select.value = valores.includes(atual) ? atual : '';
  }

  function campoFiltro(rotulo, dica, el, classe) {
    const l = Util.el('label', 'campo ' + (classe || 'f-1'), rotulo);
    l.dataset.dica = dica;
    l.append(el);
    return l;
  }

  /** Agrupa as linhas por operação (TRANSACAO), mais recente primeiro. */
  function agrupar(linhas) {
    const grupos = new Map();
    for (const l of linhas) {
      const chave = l.TRANSACAO != null ? 't' + l.TRANSACAO : 'a' + l.ID_AUDITORIA;
      if (!grupos.has(chave)) grupos.set(chave, { linhas: [], max: 0 });
      const g = grupos.get(chave);
      g.linhas.push(l);
      if (l.ID_AUDITORIA > g.max) { g.max = l.ID_AUDITORIA; g.topo = l; }
    }
    return [...grupos.values()].sort((a, b) => b.max - a.max);
  }

  function criar(destino, cfg) {
    let linhas = [];
    const de = Object.assign(document.createElement('input'), { type: 'date' });
    const ate = Object.assign(document.createElement('input'), { type: 'date' });
    const usuario = document.createElement('select');
    const parte = document.createElement('select');
    const campo = document.createElement('select');
    const filtros = Util.el('div', 'filtros historico-filtros');
    const lParte = campoFiltro('Parte', 'Mostra só uma parte da ficha (ex.: contatos, permissões).', parte);
    filtros.append(
      campoFiltro('De', 'Mostra só o que foi feito a partir desta data. Opcional.', de),
      campoFiltro('Até', 'Mostra só o que foi feito até esta data. Opcional.', ate),
      campoFiltro('Usuário', 'Mostra só o que um usuário fez.', usuario),
      lParte,
      campoFiltro('Campo', 'Mostra só as mudanças de um campo.', campo)
    );
    const nota = Util.el('div', 'suave', 'Quem mudou o quê e quando, agrupado por operação (o que foi gravado junto). Ninguém altera o histórico; desfazer grava uma alteração nova, com motivo.');
    const tabela = Util.el('table', 'tabela tabela-larga tabela-historico');
    tabela.innerHTML = '<thead><tr><th scope="col">Parte</th><th scope="col">Operação</th><th scope="col">Campo</th><th scope="col">Antes</th><th scope="col">Depois</th></tr></thead>';
    const corpo = document.createElement('tbody');
    tabela.append(corpo);
    const rolagem = Util.el('div', 'rolagem');
    rolagem.append(tabela);
    const contagem = Util.el('div', 'rodape-lista');
    destino.replaceChildren(nota, filtros, rolagem, contagem);
    for (const e of [de, ate, usuario, parte, campo]) e.addEventListener('change', desenhar);
    // Os filtros ficam dentro do formulário da ficha: não contam como alteração nem gravam com Enter.
    for (const tipo of ['input', 'change']) filtros.addEventListener(tipo, (e) => e.stopPropagation());
    filtros.addEventListener('keydown', (e) => { if (e.key === 'Enter') e.preventDefault(); });

    function passa(l) {
      const dia = String(l.DT_OPERACAO || '').substring(0, 10);
      if (de.value && dia < de.value) return false;
      if (ate.value && dia > ate.value) return false;
      if (usuario.value && l.USUARIO !== usuario.value) return false;
      if (parte.value && (l.PARTE || cfg.nomeRegistro || 'Registro') !== parte.value) return false;
      if (campo.value && (l.CAMPO || '(registro)') !== campo.value) return false;
      return true;
    }

    function botaoGrupo(texto, dica, acao) {
      const b = Util.el('button', 'botao botao-pequeno', texto);
      b.type = 'button';
      b.dataset.dica = dica;
      b.addEventListener('click', acao);
      return b;
    }

    function desenhar() {
      corpo.replaceChildren();
      const grupos = agrupar(linhas);
      let mostrados = 0;
      grupos.forEach((g, indice) => {
        const visiveis = g.linhas.filter(passa).sort((a, b) => a.ID_AUDITORIA - b.ID_AUDITORIA);
        if (!visiveis.length) return;
        mostrados++;
        const t = g.topo;
        const cab = Util.el('tr', 'linha-grupo');
        const td = Util.el('td');
        td.colSpan = 5;
        const info = Util.el('span', 'grupo-info');
        info.append(Util.el('strong', 'numero', Util.dataHora(t.DT_OPERACAO)), document.createTextNode(' · ' + (t.USUARIO || '')));
        if (t.ORIGEM) info.append(Util.el('span', 'suave', ' · ' + t.ORIGEM));
        if (t.ID_LOTE) info.append(Util.el('span', 'suave', ' · lote ' + t.ID_LOTE));
        td.append(info);
        if (cfg.podeDesfazer) {
          const acoes = Util.el('span', 'grupo-acoes');
          if (indice > 0) {
            acoes.append(botaoGrupo('Voltar para como estava aqui',
              'Volta este registro (e as partes dele) para como estava logo depois desta operação. Mostra a prévia e pede o motivo antes.',
              () => executar({ modo: 'REGISTRO', idAuditoria: g.max, titulo: 'Voltar para como estava em ' + Util.dataHora(t.DT_OPERACAO) + '?',
                explicacao: 'Tudo o que mudou neste registro depois desta operação volta como estava. É gravado como uma alteração nova, com o seu motivo.' })));
          }
          acoes.append(botaoGrupo('Desfazer esta operação',
            'Desfaz só o que foi gravado nesta operação. Recusa se alguém mexeu depois nos mesmos campos. Mostra a prévia antes.',
            () => executar({ modo: 'OPERACAO', idAuditoria: g.max, titulo: 'Desfazer a operação de ' + Util.dataHora(t.DT_OPERACAO) + '?',
              explicacao: 'O que foi gravado nesta operação volta como estava antes dela (inclusões vão para a lixeira ou são desativadas).' })));
          td.append(acoes);
        }
        cab.append(td);
        corpo.append(cab);
        for (const l of visiveis) {
          const tr = Util.el('tr');
          tr.append(
            Util.el('td', null, l.PARTE || cfg.nomeRegistro || 'Registro'),
            Util.el('td', null, l.OPERACAO_NOME || ''),
            Util.el('td', null, l.CAMPO || (l.DESCRICAO ? l.DESCRICAO : '(registro)')),
            celulaValor(l.VALOR_ANTES, 'suave'),
            celulaValor(l.VALOR_DEPOIS)
          );
          corpo.append(tr);
        }
      });
      if (!mostrados) linhaVazia(corpo, 5, linhas.length ? 'Nada com esses filtros.' : 'Nenhuma alteração registrada.');
      contagem.textContent = mostrados + (mostrados === 1 ? ' operação' : ' operações') + (linhas.length >= 1000 ? ' (mostrando as 1000 mudanças mais recentes)' : '');
    }

    async function executar(o) {
      const feito = await desfazer({ item: cfg.item, tabela: cfg.tabela, idRegistro: cfg.id, ...o });
      if (feito && cfg.aoDesfazer) cfg.aoDesfazer();
    }

    async function carregar() {
      corpo.replaceChildren();
      linhaVazia(corpo, 5, 'Carregando…');
      const r = await Api.get('/api/sis/historico', { item: cfg.item, tabela: cfg.tabela, id: cfg.id });
      corpo.replaceChildren();
      if (!r.sucesso) { await Mensagens.tratar(r); linhaVazia(corpo, 5, 'Histórico indisponível.'); return false; }
      linhas = r.dados || [];
      const unicos = (f) => [...new Set(linhas.map(f).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'pt-BR'));
      opcoes(usuario, unicos((l) => l.USUARIO), 'Todos');
      const partes = unicos((l) => l.PARTE || cfg.nomeRegistro || 'Registro');
      opcoes(parte, partes, 'Todas');
      lParte.hidden = partes.length < 2;
      opcoes(campo, unicos((l) => l.CAMPO || '(registro)'), 'Todos');
      desenhar();
      return true;
    }

    return { carregar };
  }

  /** Prévia + motivo + desfazer. Devolve true se desfez. */
  async function desfazer(o) {
    const pedido = { item: o.item, modo: o.modo, tabela: o.tabela || null, idRegistro: o.idRegistro || null,
      idAuditoria: o.idAuditoria || null, idLote: o.idLote || null };
    const r = await Api.post('/api/sis/historico/previa', pedido);
    if (!(await Mensagens.tratar(r))) return false;
    const plano = r.dados || [];
    if (!plano.length) { await Mensagens.alerta('Nada a desfazer: já está tudo como estava.'); return false; }
    const pode = !!plano[0].PODE_DESFAZER;

    const motivo = await new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'previa-titulo');
      const h2 = Util.el('h2', null, o.titulo || 'Desfazer?');
      h2.id = 'previa-titulo';
      const topo = Util.el('div', 'janela-topo');
      topo.append(h2);
      const explica = Util.el('p', 'janela-texto', o.explicacao || '');
      const resumo = Util.el('div', 'aviso-faixa' + (pode ? ' faixa-ok' : ''), plano[0].RESUMO || '');
      const tab = Util.el('table', 'tabela tabela-previa');
      tab.innerHTML = '<thead><tr><th scope="col">Registro</th><th scope="col">Campo</th><th scope="col">Agora</th><th scope="col">Como vai ficar</th><th scope="col">O que acontece</th></tr></thead>';
      const corpo = document.createElement('tbody');
      for (const p of plano) {
        const ruim = p.SITUACAO === 'CONFLITO' || p.SITUACAO === 'BLOQUEADO';
        const tr = Util.el('tr', ruim ? 'linha-conflito' : (p.SITUACAO === 'IGNORADO' || p.ACAO === 'NADA' ? 'linha-ignorada-previa' : ''));
        const reg = Util.el('td');
        reg.append(Util.el('div', 'forte', p.DESCRICAO || ('Código ' + p.ID_REGISTRO)), Util.el('div', 'suave', p.TELA_NOME || p.TABELA));
        const oque = ruim ? (p.MENSAGEM || 'Impede') : p.ACAO === 'NADA' ? 'Já está assim' : (p.SITUACAO === 'IGNORADO' ? 'Não muda' + (p.MENSAGEM ? ': ' + p.MENSAGEM : '') : (ACAO[p.ACAO] || p.ACAO) + (p.MENSAGEM ? ' (' + p.MENSAGEM + ')' : ''));
        tr.append(reg, Util.el('td', null, p.CAMPO || '(registro)'), celulaValor(p.VALOR_ATUAL, 'suave'), celulaValor(p.VALOR_NOVO), Util.el('td', null, oque));
        corpo.append(tr);
      }
      tab.append(corpo);
      const rol = Util.el('div', 'lista-pontos');
      rol.append(tab);
      const rot = Util.el('label', 'campo janela-campo', 'Motivo *');
      rot.dataset.dica = 'Por que está desfazendo. Obrigatório (pelo menos 3 letras). Fica gravado no histórico.';
      const campoMotivo = document.createElement('textarea');
      campoMotivo.maxLength = 400;
      campoMotivo.rows = 2;
      campoMotivo.disabled = !pode;
      rot.append(campoMotivo);
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;
      const barra = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', pode ? 'Cancelar' : 'Fechar');
      cancelar.type = 'button';
      barra.append(cancelar);
      const fechar = (v) => { janela.close(); janela.remove(); resolver(v); };
      cancelar.addEventListener('click', () => fechar(null));
      if (pode) {
        const ok = Util.el('button', 'botao botao-principal', 'Desfazer');
        ok.type = 'button';
        ok.addEventListener('click', () => {
          const v = campoMotivo.value.trim();
          if (v.length < 3) { erro.textContent = 'Informe o motivo (pelo menos 3 letras).'; erro.hidden = false; campoMotivo.focus(); return; }
          fechar(v);
        });
        barra.append(ok);
      }
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(null); });
      janela.append(topo, explica, resumo, rol, rot, erro, barra);
      document.body.append(janela);
      janela.showModal();
      (pode ? campoMotivo : cancelar).focus();
    });
    if (!motivo) return false;

    const rd = await Api.post('/api/sis/historico/desfazer', { ...pedido, motivo });
    if (!(await Mensagens.tratar(rd))) return false;
    await Mensagens.concluido(rd.mensagem || 'Desfeito.');
    return true;
  }

  return { criar, desfazer, resumoFoto };
})();
