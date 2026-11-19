/* =============================================================================
   SistemaCMJ - js/sis/migracao-casos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 18/11/2026 (etapa 03c2)
   Descrição : Tela "Casos da migração" (MIG_CASOS). Lista dos documentos do
               sistema antigo que não se encaixam nas regras da migração, com
               resumo por situação e por motivo (clicáveis), filtros e
               exportação para planilha. Ao clicar num documento, abre as
               linhas dele para corrigir linha a linha (conta, obra, pessoa,
               plano, datas, valores, confirmado, ignorar a linha); o campo
               alterado fica destacado com o valor original embaixo. Gravar
               confere o documento de novo e mostra se passou a se encaixar.
               Também: ignorar o documento, mandar para o arquivo morto e
               desfazer as correções (todas pedem motivo/confirmação).
               Botões conforme as ações do usuário (VER, ALTERAR).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeAlterar = acoes.has('ALTERAR');

  const SITUACOES = [
    ['REVISAR', 'Revisar'], ['PENDENTE', 'Pendentes'], ['EM_CORRECAO', 'Em correção'], ['RESOLVIDO', 'Resolvidos'],
    ['IGNORADO', 'Ignorados'], ['ARQUIVO_MORTO', 'Arquivo morto']
  ];
  const NOME_SITUACAO = { REVISAR: 'Revisar', PENDENTE: 'Pendente', EM_CORRECAO: 'Em correção', RESOLVIDO: 'Resolvido', IGNORADO: 'Ignorado', ARQUIVO_MORTO: 'Arquivo morto' };
  const NOME_REGRA = {
    LOTE: 'pagamento em lote', VENDA: 'parcela de venda', AVULSO: 'pagamento ou recebimento avulso',
    TRANSF: 'transferência', TRANSF_PAR: 'transferência', IGNORAR: 'não migra (ignorado)', ARQUIVO_MORTO: 'arquivo morto'
  };
  const moeda = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  let casos = [];
  let opcoes = { OBRAS_JSON: [], CONTAS_JSON: [], PLANOS_JSON: [], PESSOAS_JSON: [] };
  let filtroSituacao = 'PENDENTE';
  let filtroMotivo = '';
  let aberto = null;     // caso aberto (cabeçalho + linhas)
  const marcados = new Set();   // documentos marcados na lista (ações em lote)
  let proximoLoteNovo = 900001; // lote novo da migração (separar linhas num lote só delas)
  let sujo = false;

  for (const id of ['botao-gravar', 'botao-ignorar', 'botao-arquivo', 'botao-desfazer', 'botao-baixar-correcoes']) $(id).hidden = !podeAlterar;
  $('motivo').disabled = !podeAlterar;

  // ---- Lista -------------------------------------------------------------------
  async function carregar() {
    const [r, ro] = await Promise.all([Api.get('/api/mig/casos'), opcoes.carregadas ? null : Api.get('/api/mig/casos/opcoes')]);
    if (!(await Mensagens.tratar(r))) return;
    casos = r.dados || [];
    if (ro) {
      if (!(await Mensagens.tratar(ro))) return;
      opcoes = { ...ro.dados, carregadas: true };
      const dl = $('lista-pessoas');
      dl.replaceChildren(...opcoes.PESSOAS_JSON.map((p) => { const o = Util.el('option'); o.value = p.c + ' – ' + p.n; return o; }));
    }
    preencherFiltros();
    desenhar();
  }

  function preencherFiltros() {
    const manter = (sel, valores) => {
      const atual = sel.value;
      sel.replaceChildren(sel.options[0]);
      for (const v of valores) { const o = Util.el('option', null, String(v)); o.value = String(v); sel.append(o); }
      sel.value = valores.map(String).includes(atual) ? atual : '';
    };
    manter($('empresa'), [...new Set(casos.map((c) => c.EMPRESA).filter(Boolean))].sort());
    manter($('ano'), [...new Set(casos.map((c) => c.ANO).filter(Boolean))].sort());
  }

  function filtrados(semSituacao = false, semMotivo = false) {
    const busca = $('busca').value.trim().toLowerCase();
    const empresa = $('empresa').value;
    const ano = $('ano').value;
    return casos.filter((c) =>
      (semSituacao || !filtroSituacao || c.SITUACAO === filtroSituacao) &&
      (semMotivo || !filtroMotivo || c.MOTIVO === filtroMotivo) &&
      (!empresa || c.EMPRESA === empresa) &&
      (!ano || String(c.ANO) === ano) &&
      (!busca || [c.DOCUMENTO, c.HISTORICO, c.EMPRESA, c.UNIDADE, c.MOTIVO].join(' ').toLowerCase().includes(busca)));
  }

  function pilula(texto, ativa, dica, acao) {
    const b = Util.el('button', 'pilula' + (ativa ? ' ativa' : ''), texto);
    b.type = 'button';
    b.setAttribute('aria-pressed', ativa ? 'true' : 'false');
    if (dica) b.dataset.dica = dica;
    b.addEventListener('click', acao);
    return b;
  }

  function desenharResumo() {
    const base = filtrados(true, false);
    const sit = $('situacoes');
    sit.replaceChildren(pilula('Todos (' + base.length + ')', !filtroSituacao, 'Mostra todas as situações.', () => { filtroSituacao = ''; desenhar(); }));
    for (const [cod, nome] of SITUACOES) {
      const n = base.filter((c) => c.SITUACAO === cod).length;
      sit.append(pilula(nome + ' (' + n + ')', filtroSituacao === cod, null, () => { filtroSituacao = cod; desenhar(); }));
    }
    const porMotivo = new Map();
    for (const c of filtrados(false, true)) porMotivo.set(c.MOTIVO, (porMotivo.get(c.MOTIVO) || 0) + 1);
    if (filtroMotivo && !porMotivo.has(filtroMotivo)) porMotivo.set(filtroMotivo, 0);
    const sel = $('motivo-filtro');
    sel.replaceChildren(sel.options[0]);
    for (const [motivo, n] of [...porMotivo.entries()].sort((a, b) => b[1] - a[1])) {
      const o = Util.el('option', null, motivo + ' (' + n + ')');
      o.value = motivo;
      sel.append(o);
    }
    sel.value = filtroMotivo;
  }

  function desenhar() {
    desenharResumo();
    const lista = filtrados();
    const corpo = $('lista');
    corpo.replaceChildren();
    if (lista.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', casos.length ? 'Nenhum documento com esses filtros.' : 'Nenhum caso: todos os documentos se encaixam nas regras.');
      td.colSpan = 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const c of lista) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.dataset.unidade = c.UNIDADE;
      if (aberto && aberto.UNIDADE === c.UNIDADE) tr.classList.add('selecionada');
      const tdMarca = Util.el('td', 'celula-marca');
      const marca = Util.el('input');
      marca.type = 'checkbox';
      marca.checked = marcados.has(c.UNIDADE);
      marca.setAttribute('aria-label', 'Selecionar ' + c.DOCUMENTO);
      marca.hidden = !podeAlterar;
      marca.addEventListener('click', (e) => e.stopPropagation());
      marca.addEventListener('change', () => { if (marca.checked) marcados.add(c.UNIDADE); else marcados.delete(c.UNIDADE); atualizarLote(); });
      tdMarca.append(marca);
      tdMarca.addEventListener('click', (e) => e.stopPropagation());
      tr.append(tdMarca);
      const motivo = Util.el('td', null, c.MOTIVO);
      if (c.DETALHE) motivo.append(Util.el('div', 'suave', c.DETALHE));
      if (c.REVISAR) motivo.append(Util.el('div', 'aviso-revisar', c.REVISAR));
      tr.append(
        Util.el('td', null, Util.data(c.DT_DOCUMENTO)),
        Util.el('td', null, c.DOCUMENTO),
        Util.el('td', null, c.EMPRESA),
        Util.el('td', null, c.HISTORICO),
        motivo,
        Util.el('td', 'numero', moeda.format(c.VALOR_DEBITO || 0)),
        Util.el('td', 'numero', moeda.format(c.VALOR_CREDITO || 0)));
      const td = Util.el('td');
      td.append(Util.el('span', 'situacao situacao-' + c.SITUACAO.toLowerCase(), NOME_SITUACAO[c.SITUACAO] || c.SITUACAO));
      tr.append(td);
      tr.addEventListener('click', () => abrir(c.UNIDADE));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(c.UNIDADE); });
      corpo.append(tr);
    }
    atualizarLote();
    const total = lista.reduce((s, c) => s + Number(c.VALOR_DEBITO || 0), 0);
    $('contagem').textContent = lista.length + ' de ' + casos.length + ' documentos · débitos R$ ' + moeda.format(total)
      + (lista.length ? ' · clique num documento para abrir as linhas' : '');
  }

  // ---- Ações em lote (documentos marcados) -------------------------------------
  // Trocar um filtro desmarca tudo: a ação vale sempre só para o que está na tela.
  function atualizarLote() {
    const visiveis = new Set(filtrados().map((c) => c.UNIDADE));
    for (const u of [...marcados]) if (!visiveis.has(u)) marcados.delete(u);
    const sel = casos.filter((c) => marcados.has(c.UNIDADE));
    const todos = $('marcar-todos');
    todos.hidden = !podeAlterar;
    todos.checked = sel.length > 0 && sel.length === visiveis.size;
    todos.indeterminate = sel.length > 0 && sel.length < visiveis.size;
    $('barra-lote').hidden = sel.length === 0;
    const valor = sel.reduce((s, c) => s + Number(c.VALOR_DEBITO || 0), 0);
    $('lote-contagem').textContent = sel.length + (sel.length === 1 ? ' documento marcado' : ' documentos marcados') + ' · débitos R$ ' + moeda.format(valor);
  }
  function filtroMudou() { marcados.clear(); desenhar(); }

  $('marcar-todos').addEventListener('change', () => {
    marcados.clear();
    if ($('marcar-todos').checked) for (const c of filtrados()) marcados.add(c.UNIDADE);
    desenhar();
  });
  $('lote-limpar').addEventListener('click', () => { marcados.clear(); desenhar(); });

  function resumoConferencia(linhas) {
    const conta = {};
    for (const l of linhas || []) {
      const chave = l.REVISAR ? 'Revisar' : l.REGRA === 'CASO' ? 'ainda não se encaixam' : (NOME_REGRA[l.REGRA] || l.REGRA);
      conta[chave] = (conta[chave] || 0) + 1;
    }
    return Object.entries(conta).map(([k, n]) => n + ' ' + k).join('; ');
  }

  async function lote(acao, titulo, verbo) {
    const unidades = [...marcados];
    if (!unidades.length) return;
    const motivo = $('lote-motivo').value.trim();
    if (acao !== 'DESFAZER' && motivo.length < 5) {
      await Mensagens.alerta('Escreva o motivo da decisão em lote (pelo menos 5 letras).', 'ATENCAO', { foco: $('lote-motivo') });
      return;
    }
    const valor = casos.filter((c) => marcados.has(c.UNIDADE)).reduce((s, c) => s + Number(c.VALOR_DEBITO || 0), 0);
    if (!(await Mensagens.confirmar(titulo, unidades.length + ' documentos (débitos R$ ' + moeda.format(valor) + ') ' + verbo + ' Dá para desfazer depois.', 'Confirmar'))) return;
    const r = await Api.post('/api/mig/casos/lote', { acao, motivo, unidades });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido((r.mensagem || 'Gravado.') + ' Conferência: ' + resumoConferencia(r.dados) + '.');
    marcados.clear();
    $('lote-motivo').value = '';
    await carregar();
  }
  $('lote-ignorar').addEventListener('click', () => lote('IGNORAR', 'Ignorar os documentos marcados?', 'não vão para o sistema novo.'));
  $('lote-arquivo').addEventListener('click', () => lote('ARQUIVO_MORTO', 'Mandar para o arquivo morto?', 'vão para o arquivo morto (consulta), não para o financeiro novo.'));
  $('lote-desfazer').addEventListener('click', () => lote('DESFAZER', 'Desfazer as correções?', 'voltam a ser como estão no Access (todas as correções e decisões deles são apagadas).'));
  $('lote-conferir').addEventListener('click', async () => {
    const r = await Api.post('/api/mig/casos/conferir-lote', { unidades: [...marcados] });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido('Conferência de ' + marcados.size + ' documentos: ' + resumoConferencia(r.dados) + '.');
    await carregar();
  });
  for (const id of ['lote-ignorar', 'lote-arquivo', 'lote-desfazer']) $(id).hidden = !podeAlterar;
  $('lote-motivo').disabled = !podeAlterar;

  $('filtros').addEventListener('submit', (e) => e.preventDefault());
  $('busca').addEventListener('input', Util.atrasar(filtroMudou, 200));
  $('empresa').addEventListener('change', filtroMudou);
  $('motivo-filtro').addEventListener('change', () => { filtroMotivo = $('motivo-filtro').value; filtroMudou(); });
  $('ano').addEventListener('change', filtroMudou);
  $('botao-atualizar').addEventListener('click', carregar);

  // ---- Exportar --------------------------------------------------------------
  $('botao-exportar').addEventListener('click', () => {
    const cel = (v) => '"' + String(v ?? '').replace(/"/g, '""') + '"';
    const num = (v) => moeda.format(Number(v || 0)).replace(/\./g, '');
    const linhas = [['Data', 'Documento', 'Código', 'Empresa', 'Histórico', 'Motivo', 'Detalhe', 'Débitos', 'Créditos', 'Situação', 'Corrigido por'].map(cel).join(';')];
    for (const c of filtrados())
      linhas.push([Util.data(c.DT_DOCUMENTO), c.DOCUMENTO, c.UNIDADE, c.EMPRESA, c.HISTORICO, c.MOTIVO, c.DETALHE,
        num(c.VALOR_DEBITO), num(c.VALOR_CREDITO), NOME_SITUACAO[c.SITUACAO] || c.SITUACAO, c.CORRIGIDO_POR].map(cel).join(';'));
    const blob = new Blob(['﻿' + linhas.join('\r\n')], { type: 'text/csv;charset=utf-8' });
    const a = Util.el('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'casos-migracao-' + new Date().toISOString().substring(0, 10) + '.csv';
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  });

  // ---- Detalhe: linhas do documento ------------------------------------------
  function select(lista, valor, rotulo, dica, vazio) {
    const s = Util.el('select');
    s.setAttribute('aria-label', rotulo);
    s.dataset.dica = dica;
    if (vazio) { const o = Util.el('option', null, vazio); o.value = ''; s.append(o); }
    let achou = false;
    for (const x of lista) {
      const o = Util.el('option', null, x.c + ' – ' + x.n);
      o.value = String(x.c);
      if (x.c === valor) achou = true;
      s.append(o);
    }
    if (valor !== null && valor !== undefined && !achou) {
      const o = Util.el('option', null, valor + ' – (sem correspondência no sistema novo)');
      o.value = String(valor);
      s.append(o);
    }
    s.value = valor === null || valor === undefined ? '' : String(valor);
    return s;
  }

  function nomeDe(lista, cod) {
    if (cod === null || cod === undefined || cod === '') return '(vazio)';
    const x = lista.find((i) => i.c === cod);
    return cod + (x ? ' – ' + x.n : '');
  }

  /** Marca o campo como alterado (diferente do Access) e mostra o original embaixo. */
  function vigiar(td, campo, ler, original, textoOriginal) {
    const nota = Util.el('div', 'original');
    td.append(campo, nota);
    const atualizar = () => {
      const mudou = String(ler() ?? '') !== String(original ?? '');
      td.classList.toggle('alterado', mudou);
      nota.textContent = mudou ? 'Access: ' + textoOriginal : '';
    };
    const mexeu = () => { sujo = true; atualizar(); totais(); };
    campo.addEventListener('input', mexeu);
    campo.addEventListener('change', mexeu);
    atualizar();
  }

  function codigoPessoa(texto) {
    const m = String(texto || '').trim().match(/^(\d+)/);
    return m ? Number(m[1]) : 0;
  }

  function linhaCaso(l) {
    const tr = Util.el('tr');
    tr.dataset.origem = l.origem;
    tr.dataset.num = l.num;
    if (l.mudou) {
      tr.classList.add('linha-mudou');
      tr.title = 'Esta linha mudou no Access depois da correção: confira.';
    }
    const campos = {};
    const td = () => { const t = Util.el('td'); tr.append(t); return t; };

    campos.ignorar = Util.el('input');
    campos.ignorar.type = 'checkbox';
    campos.ignorar.checked = !!l.ignorar;
    campos.ignorar.setAttribute('aria-label', 'Ignorar a linha');
    campos.ignorar.dataset.dica = 'Marque para a linha não entrar na migração (ex.: lançada em dobro no Access).';
    const tIgn = td(); tIgn.classList.add('celula-marca');
    vigiar(tIgn, campos.ignorar, () => (campos.ignorar.checked ? 1 : 0), 0, 'não ignorada');
    const marcarIgnorada = () => tr.classList.toggle('linha-ignorada', campos.ignorar.checked);
    campos.ignorar.addEventListener('change', marcarIgnorada);
    marcarIgnorada();

    const tNum = td();
    tNum.append(Util.el('div', 'numero', String(l.num)), Util.el('div', 'suave', (l.tipoConta || '') + (l.lado ? ' ' + l.lado : '')));
    campos.lote = Util.el('input', 'numero');
    campos.lote.type = 'number';
    campos.lote.min = '0';
    campos.lote.step = '1';
    campos.lote.value = String(l.lote ?? 0);
    campos.lote.setAttribute('aria-label', 'Lote');
    campos.lote.dataset.dica = 'Lote de pagamento. Outro lote do Access: move a linha para ele. Lote novo (só para separar linhas): use ' + proximoLoteNovo + ' nas linhas que vão juntas. 0 = tirar a linha do lote.';
    const tLote = td(); tLote.classList.add('numero');
    vigiar(tLote, campos.lote, () => String(Number(campos.lote.value || 0)), String(l.loteOrig ?? 0), l.loteOrig ? 'lote ' + l.loteOrig : 'sem lote');

    const tHist = td();
    tHist.append(Util.el('div', null, l.complemento || l.historico || ''));
    if (l.numDoc) tHist.append(Util.el('div', 'suave', 'Doc. ' + l.numDoc));

    campos.conta = select(opcoes.CONTAS_JSON, l.conta, 'Conta', 'Conta do Access: banco, caixinha, Créditos, Débitos ou Pagto em Lote. Obrigatório.');
    vigiar(td(), campos.conta, () => campos.conta.value, l.contaOrig, nomeDe(opcoes.CONTAS_JSON, l.contaOrig));
    campos.emp = select(opcoes.OBRAS_JSON, l.emp, 'Obra', 'Obra ou empresa vinculada do Access. Obrigatório.');
    vigiar(td(), campos.emp, () => campos.emp.value, l.empOrig, nomeDe(opcoes.OBRAS_JSON, l.empOrig));

    campos.parceiro = Util.el('input');
    campos.parceiro.setAttribute('list', 'lista-pessoas');
    campos.parceiro.setAttribute('aria-label', 'Pessoa');
    campos.parceiro.dataset.dica = 'Fornecedor ou cliente. Digite parte do nome ou o código e escolha na lista. Vazio = sem pessoa.';
    campos.parceiro.value = l.parceiro > 1 ? nomeDe(opcoes.PESSOAS_JSON, l.parceiro) : '';
    vigiar(td(), campos.parceiro, () => codigoPessoa(campos.parceiro.value), l.parceiroOrig > 1 ? l.parceiroOrig : 0,
      l.parceiroOrig > 1 ? nomeDe(opcoes.PESSOAS_JSON, l.parceiroOrig) : '(sem pessoa)');

    campos.plano = select(opcoes.PLANOS_JSON, l.plano, 'Plano', 'Conta do plano do Access (nível 3).', '(sem plano)');
    vigiar(td(), campos.plano, () => campos.plano.value, l.planoOrig ?? '', nomeDe(opcoes.PLANOS_JSON, l.planoOrig));

    for (const [k, rot] of [['dtMovto', 'Data do movimento'], ['dtVencto', 'Vencimento'], ['dtPagto', 'Data do pagamento']]) {
      const i = Util.el('input');
      i.type = 'date';
      i.value = Util.dataIso(l[k]);
      i.setAttribute('aria-label', rot);
      i.dataset.dica = rot + '. Vazio = sem data (na data do pagamento, vazio deixa a parcela em aberto).';
      campos[k] = i;
      vigiar(td(), i, () => i.value, Util.dataIso(l[k + 'Orig']), Util.data(l[k + 'Orig']) || '(sem data)');
    }
    for (const [k, rot] of [['debito', 'Débito'], ['credito', 'Crédito']]) {
      const i = Util.el('input', 'numero');
      i.type = 'number';
      i.step = '0.01';
      i.min = '0';
      i.value = Number(l[k] || 0).toFixed(2);
      i.setAttribute('aria-label', rot);
      i.dataset.dica = rot + ' da linha. Cada linha tem débito ou crédito, não os dois.';
      campos[k] = i;
      const t = td(); t.classList.add('numero');
      vigiar(t, i, () => Number(i.value || 0).toFixed(2), Number(l[k + 'Orig'] || 0).toFixed(2), moeda.format(l[k + 'Orig'] || 0));
    }
    campos.confirmado = Util.el('input');
    campos.confirmado.type = 'checkbox';
    campos.confirmado.checked = !!l.confirmado;
    campos.confirmado.setAttribute('aria-label', 'Confirmado');
    campos.confirmado.dataset.dica = 'Confirmado no banco (compensado). Sem confirmação, uma transferência vira caso; um pagamento com data vira cheque não compensado.';
    const tConf = td(); tConf.classList.add('celula-marca');
    vigiar(tConf, campos.confirmado, () => (campos.confirmado.checked ? 1 : 0), l.confirmadoOrig ? 1 : 0, l.confirmadoOrig ? 'sim' : 'não');

    for (const c of Object.values(campos)) c.disabled = !podeAlterar;
    tr._campos = campos;
    return tr;
  }

  // Cabeçalho "Ignorar" e "Confirmado": marcar ou desmarcar todas as linhas
  function marcarCabecalhos() {
    for (const [id, campo] of [['ignorar-todas', 'ignorar'], ['confirmar-todas', 'confirmado']]) {
      const linhas = [...$('linhas').querySelectorAll('tr')];
      const n = linhas.filter((tr) => tr._campos[campo].checked).length;
      $(id).checked = linhas.length > 0 && n === linhas.length;
      $(id).indeterminate = n > 0 && n < linhas.length;
      $(id).disabled = !podeAlterar;
    }
  }
  for (const [id, campo] of [['ignorar-todas', 'ignorar'], ['confirmar-todas', 'confirmado']]) {
    $(id).addEventListener('change', () => {
      for (const tr of $('linhas').querySelectorAll('tr')) {
        const c = tr._campos[campo];
        if (c.checked !== $(id).checked) { c.checked = $(id).checked; c.dispatchEvent(new Event('change')); }
      }
      marcarCabecalhos();
    });
  }
  $('linhas').addEventListener('change', marcarCabecalhos);

  function lerLinhas() {
    return [...$('linhas').querySelectorAll('tr')].map((tr) => {
      const c = tr._campos;
      return {
        origem: tr.dataset.origem,
        num: Number(tr.dataset.num),
        ignorar: c.ignorar.checked,
        conta: c.conta.value === '' ? null : Number(c.conta.value),
        emp: c.emp.value === '' ? null : Number(c.emp.value),
        parceiro: codigoPessoa(c.parceiro.value),
        plano: c.plano.value === '' ? null : Number(c.plano.value),
        dtMovto: c.dtMovto.value || null,
        dtVencto: c.dtVencto.value || null,
        dtPagto: c.dtPagto.value || null,
        debito: Number(c.debito.value || 0),
        credito: Number(c.credito.value || 0),
        confirmado: c.confirmado.checked,
        lote: Number(c.lote.value || 0)
      };
    });
  }

  function totais() {
    const ls = lerLinhas().filter((l) => !l.ignorar);
    const d = ls.reduce((s, l) => s + l.debito, 0);
    const c = ls.reduce((s, l) => s + l.credito, 0);
    $('total-debito').textContent = moeda.format(d);
    $('total-credito').textContent = moeda.format(c);
    $('total-diferenca').textContent = Math.abs(d - c) < 0.005 ? 'débitos = créditos' : 'diferença ' + moeda.format(d - c);
  }

  function mostrarResultado(r) {
    const faixa = $('resultado');
    if (!r || !r.REGRA) { faixa.hidden = true; return; }
    faixa.hidden = false;
    if (r.REVISAR) {
      faixa.classList.remove('faixa-ok');
      faixa.textContent = 'Revisar: ' + r.REVISAR + '. Confira as linhas com o Access e grave de novo (ou repita a decisão) para tirar o aviso.';
      return;
    }
    faixa.classList.toggle('faixa-ok', r.REGRA !== 'CASO');
    faixa.textContent = r.REGRA === 'CASO'
      ? 'Ainda não se encaixa: ' + r.MOTIVO + (r.DETALHE ? ' (' + r.DETALHE + ')' : '') + '.'
      : 'Este documento se encaixa: ' + (NOME_REGRA[r.REGRA] || r.REGRA) + '. Vale na próxima rodada da migração.';
  }

  async function abrir(unidade, resultado) {
    if (sujo && aberto && aberto.UNIDADE !== unidade &&
        !(await Mensagens.confirmar('Descartar alterações?', 'As alterações das linhas de ' + aberto.titulo + ' não foram gravadas. Descartar?', 'Descartar'))) return;
    const r = await Api.get('/api/mig/caso', { unidade });
    if (!(await Mensagens.tratar(r))) return;
    const caso = r.dados;
    const item = casos.find((c) => c.UNIDADE === unidade) || {};
    aberto = { ...caso, titulo: item.DOCUMENTO || unidade };
    sujo = false;
    $('detalhe-titulo').textContent = aberto.titulo + (item.EMPRESA ? ' · ' + item.EMPRESA : '') + (item.DT_DOCUMENTO ? ' · ' + Util.data(item.DT_DOCUMENTO) : '');
    const situacao = NOME_SITUACAO[item.SITUACAO] || '';
    let texto = 'Motivo: ' + (caso.MOTIVO_ORIGINAL || caso.MOTIVO || '') + (caso.DETALHE ? ' (' + caso.DETALHE + ')' : '') + (situacao ? ' · Situação: ' + situacao : '');
    if (caso.ACAO) texto += ' · Decisão: ' + (caso.ACAO === 'IGNORAR' ? 'não migrar' : 'arquivo morto') + ' (' + caso.ACAO_MOTIVO + ', por ' + caso.ACAO_USUARIO + ')';
    $('detalhe-motivo').textContent = texto;
    $('motivo').value = caso.ACAO ? caso.ACAO_MOTIVO : caso.CORRECAO_MOTIVO || '';
    proximoLoteNovo = caso.PROXIMO_LOTE_NOVO || 900001;
    $('nota-lote-novo').textContent = 'Para separar linhas num lote só delas, digite ' + proximoLoteNovo + ' na coluna Lote dessas linhas e grave.';
    $('linhas').replaceChildren(...(caso.LINHAS_JSON || []).map(linhaCaso));
    marcarCabecalhos();
    sujo = false;
    totais();
    $('botao-desfazer').hidden = !podeAlterar || !(caso.ACAO || (caso.LINHAS_JSON || []).some((l) => l.corrigida));
    mostrarResultado(resultado || (caso.REVISAR ? { REGRA: caso.REGRA_ATUAL, REVISAR: caso.REVISAR }
      : caso.REGRA_ATUAL && caso.REGRA_ATUAL !== 'CASO' ? { REGRA: caso.REGRA_ATUAL } : null));
    $('detalhe').hidden = false;
    for (const tr of $('lista').querySelectorAll('tr')) tr.classList.toggle('selecionada', tr.dataset.unidade === unidade);
    $('detalhe').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  async function gravar(acao, titulo, texto, botao) {
    if (!aberto) return;
    const motivo = $('motivo').value.trim();
    if ((acao === 'IGNORAR' || acao === 'ARQUIVO_MORTO') && motivo.length < 5) {
      await Mensagens.alerta('Escreva o motivo da decisão (pelo menos 5 letras).', 'ATENCAO', { foco: $('motivo') });
      return;
    }
    if (!(await Mensagens.confirmar(titulo, texto, botao))) return;
    const r = await Api.post('/api/mig/caso/gravar', { unidade: aberto.UNIDADE, acao, motivo, linhas: acao === 'CORRIGIR' ? lerLinhas() : null });
    if (!(await Mensagens.tratar(r, { foco: $('motivo') }))) return;
    const outros = Array.isArray(r.dados) ? r.dados.slice(1) : [];
    let extra = '';
    if (outros.length) extra = ' Lote de destino: ' + outros.map((o) => o.UNIDADE.replace(/^L:/, 'lote ').replace(/^V:/, 'venda ').replace(/^A:[MQ]:/, 'avulso ')
      + ' — ' + (o.REVISAR ? 'revisar' : o.REGRA === 'CASO' ? 'virou caso (' + o.MOTIVO + ')' : 'se encaixa')).join('; ') + '.';
    await Mensagens.concluido((r.mensagem || 'Gravado.') + extra);
    const unidade = aberto.UNIDADE;
    sujo = false;
    await carregar();
    await abrir(unidade, Array.isArray(r.dados) ? r.dados[0] : r.dados);
  }

  $('botao-gravar').addEventListener('click', () => aberto &&
    gravar('CORRIGIR', 'Gravar?', 'Grava as correções das linhas de ' + aberto.titulo + ' e confere o documento de novo. O sistema antigo não muda.', 'Gravar'));
  $('botao-ignorar').addEventListener('click', () => aberto &&
    gravar('IGNORAR', 'Ignorar documento?', aberto.titulo + ' não vai para o sistema novo. Dá para desfazer depois.', 'Ignorar'));
  $('botao-arquivo').addEventListener('click', () => aberto &&
    gravar('ARQUIVO_MORTO', 'Mandar para o arquivo morto?', aberto.titulo + ' vai para o arquivo morto (consulta) e não para o financeiro novo. Dá para desfazer depois.', 'Mandar'));
  $('botao-desfazer').addEventListener('click', () => aberto &&
    gravar('DESFAZER', 'Desfazer correções?', 'Todas as correções e decisões de ' + aberto.titulo + ' serão apagadas: ele volta a ser como está no sistema antigo.', 'Desfazer'));

  $('botao-conferir').addEventListener('click', async () => {
    if (!aberto) return;
    if (sujo) await Mensagens.alerta('Há alterações que ainda não foram gravadas: a conferência usa só o que já está gravado.');
    const r = await Api.post('/api/mig/caso/conferir', { unidade: aberto.UNIDADE });
    if (!(await Mensagens.tratar(r))) return;
    mostrarResultado(r.dados);
  });

  function fechar() {
    $('detalhe').hidden = true;
    aberto = null;
    sujo = false;
    for (const tr of $('lista').querySelectorAll('tr.selecionada')) tr.classList.remove('selecionada');
  }
  $('botao-fechar').addEventListener('click', async () => {
    if (sujo && !(await Mensagens.confirmar('Descartar alterações?', 'As alterações das linhas não foram gravadas. Descartar?', 'Descartar'))) return;
    fechar();
  });

  document.addEventListener('keydown', (e) => {
    if ($('detalhe').hidden || document.querySelector('dialog.janela[open]')) return;
    if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); if (podeAlterar) $('botao-gravar').click(); }
    else if (e.key === 'Escape') $('botao-fechar').click();
  });
  window.addEventListener('beforeunload', (e) => { if (sujo) { e.preventDefault(); e.returnValue = ''; } });

  await carregar();
});
