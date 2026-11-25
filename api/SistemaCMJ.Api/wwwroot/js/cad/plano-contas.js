/* =============================================================================
   SistemaCMJ - js/cad/plano-contas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Plano de contas em árvore (CAD_PLANO_CONTA): grupo › subgrupo ›
               conta, com busca (abre os grupos do que bate), filtro de tipo,
               "Mostrar inativos", abrir/fechar tudo e, ao lado, a ficha do item
               escolhido (incluir, alterar, mudar de lugar, desativar, reativar,
               excluir para a lixeira, histórico). Os grupos abertos ficam
               guardados enquanto a aba estiver aberta. Validações e travas no
               banco (CAD_Plano_*_Gravar, CAD_Plano_Excluir).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const NIVEL = { 1: 'Grupo', 2: 'Subgrupo', 3: 'Conta' };
  const TABELA = { 1: 'CAD.Plano_Grupo', 2: 'CAD.Plano_Subgrupo', 3: 'CAD.Plano_Conta' };
  const CHAVE_ABERTOS = 'cmj_plano_abertos';
  const chave = (n) => n.NIVEL + ':' + n.ID;
  let itens = [];             // linhas do CAD_Plano_Conta_Listar
  let porChave = new Map();
  let abertos = new Set();
  let atual = null;           // item na ficha (ou { NIVEL, ID: null, ID_PAI } para novo)
  let sujo = false;

  try { abertos = new Set(JSON.parse(sessionStorage.getItem(CHAVE_ABERTOS) || '[]')); } catch { abertos = new Set(); }
  const guardarAbertos = () => sessionStorage.setItem(CHAVE_ABERTOS, JSON.stringify([...abertos]));

  $('botao-incluir-grupo').hidden = !acoes.has('INCLUIR');
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('link-lixeira').hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const filhos = (n) => itens.filter((x) => x.NIVEL === n.NIVEL + 1 && x.ID_PAI === n.ID);
  const pai = (n) => n.NIVEL > 1 ? porChave.get((n.NIVEL - 1) + ':' + n.ID_PAI) : null;

  // ---------- Árvore ----------
  function visiveisPelaBusca() {
    const termo = semAcento($('busca').value.trim());
    const tipo = $('tipo').value;
    const mostra = new Set();
    for (const n of itens) {
      if (!$('inativos').checked && !n.ATIVO_EFETIVO) continue;
      if (tipo && n.TIPO !== tipo) continue;
      if (termo && !semAcento(n.DESCRICAO).includes(termo) && !String(n.CODIGO).startsWith(termo)) continue;
      // o item e todos os de cima aparecem; o que está embaixo de um item achado também
      for (let p = n; p; p = pai(p)) mostra.add(chave(p));
      if (termo) {
        const pilha = [n];
        while (pilha.length) {
          const x = pilha.pop();
          for (const f of filhos(x)) if ($('inativos').checked || f.ATIVO_EFETIVO) { mostra.add(chave(f)); pilha.push(f); }
        }
      }
    }
    return { mostra, termo };
  }

  function desenhar() {
    const { mostra, termo } = visiveisPelaBusca();
    const raiz = $('arvore');
    raiz.replaceChildren();
    const lista = Util.el('ul', 'plano-nivel');
    lista.setAttribute('role', 'group');
    let qtdContas = 0;

    function no(n, destino) {
      if (!mostra.has(chave(n))) return;
      if (n.NIVEL === 3) qtdContas++;
      const li = Util.el('li');
      li.setAttribute('role', 'treeitem');
      const temFilhos = n.NIVEL < 3 && filhos(n).some((f) => mostra.has(chave(f)));
      const aberto = termo ? true : abertos.has(chave(n));
      if (n.NIVEL < 3) li.setAttribute('aria-expanded', aberto ? 'true' : 'false');
      const linha = Util.el('div', 'plano-linha plano-n' + n.NIVEL + (n.ATIVO_EFETIVO ? '' : ' plano-inativo') + (atual && atual.ID && chave(atual) === chave(n) ? ' plano-escolhido' : ''));
      linha.tabIndex = 0;
      const seta = Util.el('button', 'plano-seta', n.NIVEL < 3 ? (aberto ? '▾' : '▸') : '');
      seta.type = 'button';
      seta.tabIndex = -1;
      seta.setAttribute('aria-label', aberto ? 'Fechar' : 'Abrir');
      seta.disabled = !temFilhos;
      seta.addEventListener('click', (e) => { e.stopPropagation(); alternar(n); });
      linha.append(seta, Util.el('span', 'plano-codigo', n.CODIGO), Util.el('span', 'plano-descricao', n.DESCRICAO));
      const etiquetas = Util.el('span', 'etiquetas');
      if (n.NIVEL === 1) etiquetas.append(Util.el('span', 'etiqueta plano-tipo-' + n.TIPO.toLowerCase(), Rotulos.de('grupoTipo', n.TIPO)));
      if (n.NIVEL === 1 && n.CUSTO_OBRA) etiquetas.append(Util.el('span', 'etiqueta', 'Custo de obra'));
      if (n.NIVEL === 3 && n.CONTABIL) etiquetas.append(Util.el('span', 'etiqueta', 'Contábil'));
      if (!n.ATIVO) etiquetas.append(Util.el('span', 'etiqueta etiqueta-correcao', 'Inativo'));
      linha.append(etiquetas);
      if (n.QTD_LANCAMENTOS) linha.append(Util.el('span', 'suave plano-qtd', n.QTD_LANCAMENTOS.toLocaleString('pt-BR') + ' lanç.'));
      linha.addEventListener('click', () => escolher(n));
      linha.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') escolher(n);
        else if (e.key === 'ArrowRight' && n.NIVEL < 3 && !abertos.has(chave(n))) alternar(n);
        else if (e.key === 'ArrowLeft' && n.NIVEL < 3 && abertos.has(chave(n))) alternar(n);
      });
      li.append(linha);
      if (n.NIVEL < 3 && aberto && temFilhos) {
        const sub = Util.el('ul', 'plano-nivel');
        sub.setAttribute('role', 'group');
        for (const f of filhos(n)) no(f, sub);
        li.append(sub);
      }
      destino.append(li);
    }

    for (const g of itens.filter((x) => x.NIVEL === 1)) no(g, lista);
    if (!lista.children.length) raiz.append(Util.el('div', 'vazio', 'Nada encontrado com esses filtros.'));
    else raiz.append(lista);
    const contas = itens.filter((x) => x.NIVEL === 3 && x.ATIVO_EFETIVO).length;
    $('contagem').textContent = (termo || $('tipo').value ? qtdContas + ' conta(s) encontrada(s) · ' : '') + contas + ' contas ativas no plano';
  }

  function alternar(n) {
    if (abertos.has(chave(n))) abertos.delete(chave(n)); else abertos.add(chave(n));
    guardarAbertos();
    desenhar();
  }

  // ---------- Ficha do item ----------
  const podeIncluir = acoes.has('INCLUIR');
  const podeAlterar = acoes.has('ALTERAR');

  function preencherPais(nivel, idPai) {
    const sel = $('idPai');
    sel.replaceChildren();
    if (nivel === 2) {
      for (const g of itens.filter((x) => x.NIVEL === 1 && (x.ATIVO_EFETIVO || x.ID === idPai))) {
        const op = Util.el('option', null, g.CODIGO + ' - ' + g.DESCRICAO + (g.ATIVO_EFETIVO ? '' : ' (inativo)'));
        op.value = g.ID;
        sel.append(op);
      }
    } else if (nivel === 3) {
      for (const g of itens.filter((x) => x.NIVEL === 1)) {
        const grupo = Util.el('optgroup');
        grupo.label = g.CODIGO + ' - ' + g.DESCRICAO;
        for (const s of filhos(g).filter((x) => x.ATIVO_EFETIVO || x.ID === idPai)) {
          const op = Util.el('option', null, s.CODIGO + ' - ' + s.DESCRICAO + (s.ATIVO_EFETIVO ? '' : ' (inativo)'));
          op.value = s.ID;
          grupo.append(op);
        }
        if (grupo.children.length) sel.append(grupo);
      }
    }
    sel.value = idPai ?? '';
  }

  async function escolher(n, forcar = false) {
    if (!forcar && sujo && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas neste item. Elas serão perdidas.', 'Descartar'))) return;
    atual = n;
    sujo = false;
    const novo = !n.ID;
    const nivel = n.NIVEL;
    $('ficha-vazia').hidden = true;
    $('ficha-conteudo').hidden = false;
    $('ficha-nivel').textContent = (novo ? 'Novo ' : '') + NIVEL[nivel].toLowerCase();
    $('ficha-titulo').textContent = novo ? 'Novo ' + NIVEL[nivel].toLowerCase() : n.CODIGO + ' - ' + n.DESCRICAO;
    const p = novo ? (nivel > 1 ? porChave.get((nivel - 1) + ':' + n.ID_PAI) : null) : pai(n);
    $('ficha-subtitulo').textContent = novo ? (p ? 'Dentro de ' + p.CODIGO + ' - ' + p.DESCRICAO : 'Grupo novo no plano')
      : [p && pai(p) ? pai(p).DESCRICAO : null, p ? p.DESCRICAO : null, Rotulos.de('grupoTipo', n.TIPO),
         n.QTD_LANCAMENTOS ? n.QTD_LANCAMENTOS.toLocaleString('pt-BR') + ' lançamento(s)' : 'sem lançamentos'].filter(Boolean).join(' · ');
    for (const el of document.querySelectorAll('.so-grupo, .so-subgrupo, .so-conta')) {
      el.hidden = !((nivel === 1 && el.classList.contains('so-grupo')) || (nivel === 2 && el.classList.contains('so-subgrupo')) || (nivel === 3 && el.classList.contains('so-conta')));
    }
    $('campo-pai').hidden = nivel === 1;
    $('rotulo-pai').textContent = nivel === 2 ? 'Grupo' : 'Subgrupo';
    preencherPais(nivel, n.ID_PAI);
    $('numero').value = novo ? '' : n.NUMERO;
    $('numero').min = nivel === 1 ? 0 : 1;
    $('numero').max = nivel === 3 ? 999 : 99;
    $('descricao').value = novo ? '' : n.DESCRICAO;
    $('tipoGrupo').value = novo ? 'DESPESA' : n.TIPO;
    $('ordem').value = novo || !n.ORDEM ? '' : n.ORDEM;
    $('custoObra').checked = !novo && !!n.CUSTO_OBRA;
    $('contabil').checked = !novo && !!n.CONTABIL;
    $('contaContabilRef').value = novo ? '' : (n.CONTA_CONTABIL_REF || '');
    const pode = novo ? podeIncluir : podeAlterar;
    for (const el of $('ficha-conteudo').querySelectorAll('input, select')) el.disabled = !pode;
    if (!novo && n.QTD_LANCAMENTOS && nivel > 1) { $('idPai').disabled = true; }
    const aviso = $('ficha-aviso');
    aviso.hidden = novo || !n.QTD_LANCAMENTOS || nivel === 1;
    aviso.textContent = 'Já tem lançamentos: não muda mais de ' + (nivel === 2 ? 'grupo' : 'subgrupo') + '. Para mudar, crie um item novo no lugar certo e desative este.';
    if (!novo && !n.ATIVO_EFETIVO && n.ATIVO) { aviso.hidden = false; aviso.textContent = 'Este item está ativo, mas some das escolhas porque o ' + (nivel === 3 ? 'subgrupo ou o grupo' : 'grupo') + ' de cima está desativado.'; }
    $('botao-gravar').hidden = !pode;
    $('botao-filho').hidden = novo || nivel === 3 || !podeIncluir || !n.ATIVO_EFETIVO;
    $('botao-filho').textContent = nivel === 1 ? '+ Subgrupo' : '+ Conta';
    $('botao-desativar').hidden = novo || !n.ATIVO || !acoes.has('DESATIVAR');
    $('botao-reativar').hidden = novo || n.ATIVO || !acoes.has('DESATIVAR');
    $('botao-excluir').hidden = novo || !!n.QTD_LANCAMENTOS || filhos(n).length > 0 || !acoes.has('EXCLUIR');
    $('botao-historico').hidden = novo;
    $('historico').hidden = true;
    $('historico').replaceChildren();
    $('rodape').textContent = !novo && n.DT_ALTERACAO ? 'Alterado em ' + Util.dataHora(n.DT_ALTERACAO) + (n.USUARIO_ALTERACAO ? ' por ' + n.USUARIO_ALTERACAO : '') : '';
    desenhar();
    if (pode) $('descricao').focus();
  }

  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  $('botao-cancelar').addEventListener('click', () => {
    if (!atual) return;
    if (atual.ID) escolher(atual, true);
    else { atual = null; sujo = false; $('ficha-conteudo').hidden = true; $('ficha-vazia').hidden = false; desenhar(); }
  });
  $('botao-incluir-grupo').addEventListener('click', () => escolher({ NIVEL: 1, ID: null, ID_PAI: null }));
  $('botao-filho').addEventListener('click', () => {
    abertos.add(chave(atual));
    guardarAbertos();
    escolher({ NIVEL: atual.NIVEL + 1, ID: null, ID_PAI: atual.ID });
  });

  $('ficha').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!atual) return;
    const n = atual;
    const desc = $('descricao').value.trim();
    if (!desc) { await Mensagens.alerta('Informe a descrição.', 'ATENCAO', { foco: $('descricao') }); return; }
    if (n.NIVEL > 1 && !$('idPai').value) { await Mensagens.alerta('Escolha onde o item fica (' + $('rotulo-pai').textContent.toLowerCase() + ').', 'ATENCAO', { foco: $('idPai') }); return; }
    const mudouLugar = n.ID && n.NIVEL > 1 && Number($('idPai').value) !== n.ID_PAI;
    const texto = (n.ID ? 'Confirma a gravação das alterações de "' : 'Confirma a inclusão de "') + desc + '"?'
      + (mudouLugar ? ' O item vai mudar de lugar na árvore (e de número, se o número já estiver em uso no lugar novo, deixe em branco).' : '');
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;
    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/cad/plano-contas', {
      nivel: n.NIVEL, id: n.ID, idPai: n.NIVEL > 1 ? Number($('idPai').value) : null,
      numero: $('numero').value === '' ? null : Number($('numero').value), descricao: desc,
      tipo: $('tipoGrupo').value, custoObra: $('custoObra').checked, ordem: $('ordem').value === '' ? null : Number($('ordem').value),
      contabil: $('contabil').checked, contaContabilRef: $('contaContabilRef').value
    });
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    Mensagens.sucesso(r.mensagem || NIVEL[n.NIVEL] + ' gravado.');
    const id = (r.dados && r.dados.id) || n.ID;
    await carregar();
    const gravado = porChave.get(n.NIVEL + ':' + id);
    if (gravado) { for (let p = pai(gravado); p; p = pai(p)) abertos.add(chave(p)); guardarAbertos(); escolher(gravado, true); }
  });

  async function mudarSituacao(reativar) {
    const n = atual;
    const abaixo = n.NIVEL < 3 ? ' Tudo o que está abaixo dele também some das escolhas (sem ser desativado: volta quando ele for reativado).' : '';
    const ok = reativar
      ? await Mensagens.confirmar('Reativar?', '"' + n.DESCRICAO + '" volta a aparecer nas escolhas.', 'Reativar')
      : await Mensagens.confirmar('Desativar?', '"' + n.DESCRICAO + '" some das escolhas, mas os lançamentos continuam.' + abaixo, 'Desativar');
    if (!ok) return;
    const r = await Api.post('/api/cad/plano-contas/' + n.ID + '/excluir', { nivel: n.NIVEL, reativar });
    if (!(await Mensagens.tratar(r))) return;
    Mensagens.sucesso(r.mensagem || 'Situação alterada.');
    await carregar();
    const de = porChave.get(chave(n));
    if (de) escolher(de, true);
  }
  $('botao-desativar').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));
  $('botao-excluir').addEventListener('click', async () => {
    const n = atual;
    const motivo = await Mensagens.pedirTexto('Excluir?',
      '"' + n.DESCRICAO + '" vai para a lixeira: some de todas as telas e pode ser recuperado na Lixeira até o prazo acabar; depois é apagado de vez.',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item: 'CAD_PLANO_CONTA', tabela: TABELA[n.NIVEL], idRegistro: n.ID, motivo });
    if (!(await Mensagens.tratar(r))) return;
    Mensagens.sucesso(r.mensagem || 'Enviado para a lixeira.');
    atual = null;
    $('ficha-conteudo').hidden = true;
    $('ficha-vazia').hidden = false;
    await carregar();
  });
  $('botao-historico').addEventListener('click', async () => {
    const caixa = $('historico');
    if (!caixa.hidden) { caixa.hidden = true; return; }
    const n = atual;
    caixa.hidden = false;
    const h = Historico.criar(caixa, {
      item: 'CAD_PLANO_CONTA', tabela: TABELA[n.NIVEL], id: n.ID, nomeRegistro: NIVEL[n.NIVEL], podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: async () => { await carregar(); const de = porChave.get(chave(n)); if (de) escolher(de, true); }
    });
    await h.carregar();
  });

  // ---------- Lista, filtros, exportação ----------
  async function carregar() {
    const r = await Api.get('/api/cad/plano-contas');
    if (!(await Mensagens.tratar(r, { foco: $('busca') }))) return;
    itens = r.dados || [];
    porChave = new Map(itens.map((n) => [chave(n), n]));
    desenhar();
  }

  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); desenhar(); });
  $('busca').addEventListener('input', Util.atrasar(desenhar, 200));
  $('tipo').addEventListener('change', desenhar);
  $('inativos').addEventListener('change', desenhar);
  $('abrir-tudo').addEventListener('click', () => { for (const n of itens) if (n.NIVEL < 3) abertos.add(chave(n)); guardarAbertos(); desenhar(); });
  $('fechar-tudo').addEventListener('click', () => { abertos.clear(); guardarAbertos(); desenhar(); });
  $('botao-exportar').addEventListener('click', () => {
    const { mostra } = visiveisPelaBusca();
    Util.exportarCsv('Plano_de_contas', ['Nível', 'Código', 'Descrição', 'Tipo', 'Custo de obra', 'Contábil', 'Conta contábil', 'Lançamentos', 'Situação'],
      itens.filter((n) => mostra.has(chave(n))).map((n) => [NIVEL[n.NIVEL], n.CODIGO, n.DESCRICAO, Rotulos.de('grupoTipo', n.TIPO),
        n.NIVEL === 1 ? (n.CUSTO_OBRA ? 'Sim' : 'Não') : '', n.NIVEL === 3 ? (n.CONTABIL ? 'Sim' : 'Não') : '', n.CONTA_CONTABIL_REF,
        n.QTD_LANCAMENTOS || 0, n.ATIVO_EFETIVO ? 'Ativo' : 'Inativo']));
  });

  $('busca').focus();
  await carregar();
});
