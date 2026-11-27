/* =============================================================================
   SistemaCMJ - js/banco/extrato.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04g4a)
   Descrição : Tela Bancos › Extrato e saldos (BANCO_EXTRATO).
               Em cima, os saldos das contas numa data (GET /api/banco/saldos:
               saldo, limite, disponível, último movimento, não conciliados,
               último fechamento de caixa e "fechamento atrasado"); clicar na
               linha abre o extrato do mês, clicar no Disponível abre os últimos
               30 dias. Embaixo, o extrato da conta no período
               (GET /api/banco/extrato): saldo anterior, saldo inicial quando
               cai no período, saldo acumulado em cada linha, totais, origem
               clicável (lançamento ou transferência), esconder estornados,
               exportar. Endereço: ?conta=ID[&de=aaaa-mm-dd&ate=aaaa-mm-dd]
               abre direto no extrato (atalho da ficha e da lista de contas).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const CHAVE = 'cmj_filtros_extrato';
  const podeExportar = acoes.has('EXPORTAR');
  let saldos = [];
  let linhas = [];
  let contaAtual = null; // linha do saldo da conta escolhida (quando houver)

  $('exportar-saldos').hidden = !podeExportar;
  $('exportar-extrato').hidden = !podeExportar;
  $('link-transferencias').hidden = !Layout.acoesDe('banco/transferencias.html').has('VER');
  $('link-caixa').hidden = !Layout.acoesDe('banco/caixa.html').has('VER');

  // ------------------------------------------------------------ datas
  const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  const hoje = () => iso(new Date());
  function periodo(tipo) {
    const d = new Date();
    if (tipo === 'anterior') return { de: iso(new Date(d.getFullYear(), d.getMonth() - 1, 1)), ate: iso(new Date(d.getFullYear(), d.getMonth(), 0)) };
    if (tipo === '30') { const ini = new Date(d); ini.setDate(ini.getDate() - 29); return { de: iso(ini), ate: iso(d) }; }
    return { de: iso(new Date(d.getFullYear(), d.getMonth(), 1)), ate: iso(d) };
  }

  let salvos = {};
  try { salvos = JSON.parse(sessionStorage.getItem(CHAVE) || '{}'); } catch { salvos = {}; }
  const guardar = () => sessionStorage.setItem(CHAVE, JSON.stringify({
    conta: seletor.valor(), de: $('extrato-de').value, ate: $('extrato-ate').value,
    ocultar: $('extrato-ocultar').checked, todas: $('saldo-todas').checked, inativas: $('saldo-inativas').checked, empresa: $('saldo-empresa').value
  }));

  const seletor = Seletor.criar($('seletor-conta'), { tipo: 'CONTA', rotulo: 'Conta do extrato', aoMudar: () => carregarExtrato() });

  // ------------------------------------------------------------ saldos
  const moedaComSinal = (v) => Util.moeda(v);
  const classeValor = (v) => 'numero' + (Number(v) < 0 ? ' valor-negativo' : '');

  function abrirExtrato(idConta, tipoPeriodo) {
    const p = periodo(tipoPeriodo);
    $('extrato-de').value = p.de;
    $('extrato-ate').value = p.ate;
    seletor.definir(idConta).then(() => {
      carregarExtrato();
      $('secao-extrato').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  function textoFechamento(s) {
    if (!s.USA_FECHAMENTO) return null;
    const caixa = Util.el('span');
    if (s.FECHAMENTO_ATRASADO) {
      const et = Util.el('span', 'etiqueta etiqueta-apaga', 'Fechamento atrasado');
      et.dataset.dica = 'Há movimento desde ' + Util.data(s.DT_PRIMEIRO_SEM_FECHAR) + ' ainda sem fechamento de caixa (prazo no parâmetro FIN_CAIXA_FECHAMENTO_ATRASO_DIAS).';
      caixa.append(et, ' ');
    }
    caixa.append(s.DT_ULTIMO_FECHAMENTO ? 'Último: ' + Util.data(s.DT_ULTIMO_FECHAMENTO) : 'Nunca fechado');
    return caixa;
  }

  function desenharSaldos() {
    const corpo = $('saldos');
    corpo.replaceChildren();
    if (!saldos.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma conta para mostrar.');
      td.colSpan = 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const s of saldos) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.dataset.dica = 'Abre o extrato deste mês da conta ' + s.DESCRICAO + '.';
      tr.addEventListener('click', () => abrirExtrato(s.ID_CONTA, 'mes'));
      tr.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') abrirExtrato(s.ID_CONTA, 'mes'); });
      if (contaAtual && contaAtual.ID_CONTA === s.ID_CONTA) tr.classList.add('linha-marcada');

      const conta = Util.el('td', 'forte', s.DESCRICAO);
      if (!s.ATIVO) conta.append(' ', Util.el('span', 'situacao situacao-inativo', 'Inativa'));
      if (s.BANCO) conta.append(Util.el('span', 'sub', s.BANCO + (s.AGENCIA ? ' · ag. ' + s.AGENCIA : '') + (s.NUMERO ? ' · c/c ' + s.NUMERO : '')));

      const disp = Util.el('td', classeValor(s.DISPONIVEL));
      const link = Util.el('button', 'botao-link', moedaComSinal(s.DISPONIVEL));
      link.type = 'button';
      link.dataset.dica = 'Abre o extrato dos últimos 30 dias desta conta.';
      link.addEventListener('click', (ev) => { ev.stopPropagation(); abrirExtrato(s.ID_CONTA, '30'); });
      disp.append(link);

      const saldo = Util.el('td', classeValor(s.SALDO), s.TEM_SALDO ? moedaComSinal(s.SALDO) : '');
      if (!s.TEM_SALDO) {
        saldo.append(Util.el('span', 'sub', 'antes do saldo inicial'));
      }
      const conc = Util.el('td', null, s.CONCILIA ? (s.QTD_NAO_CONCILIADOS ? s.QTD_NAO_CONCILIADOS + ' não conciliado(s)' : 'Em dia') : '');
      const fech = Util.el('td');
      const tf = textoFechamento(s);
      if (tf) fech.append(tf);

      tr.append(Util.el('td', null, s.EMPRESA), conta, Util.el('td', null, Rotulos.de('contaTipo', s.TIPO)), saldo,
        Util.el('td', 'numero', s.LIMITE_CREDITO ? Util.moeda(s.LIMITE_CREDITO) : ''), disp,
        Util.el('td', null, s.DT_ULTIMO_MOVIMENTO ? Util.data(s.DT_ULTIMO_MOVIMENTO) : ''), conc, fech);
      corpo.append(tr);
    }
    const total = saldos.reduce((t, s) => ({ saldo: t.saldo + Number(s.SALDO || 0), disp: t.disp + Number(s.DISPONIVEL || 0), lim: t.lim + Number(s.LIMITE_CREDITO || 0) }), { saldo: 0, disp: 0, lim: 0 });
    const rodape = $('saldos-total');
    rodape.replaceChildren();
    if (saldos.length > 1) {
      const tr = Util.el('tr', 'linha-total');
      const rot = Util.el('td', 'forte', 'Total');
      rot.colSpan = 3;
      tr.append(rot, Util.el('td', classeValor(total.saldo) + ' forte', Util.moeda(total.saldo)), Util.el('td', 'numero', Util.moeda(total.lim)),
        Util.el('td', classeValor(total.disp) + ' forte', Util.moeda(total.disp)), Util.el('td'), Util.el('td'), Util.el('td'));
      rodape.append(tr);
    }
    $('saldos-contagem').textContent = saldos.length === 1 ? '1 conta' : saldos.length + ' contas';
  }

  async function carregarSaldos() {
    $('saldos-contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/banco/saldos', {
      data: $('saldo-data').value || hoje(), idEmpresa: $('saldo-empresa').value,
      todas: $('saldo-todas').checked ? 'true' : '', inativas: $('saldo-inativas').checked ? 'true' : ''
    });
    if (!(await Mensagens.tratar(r))) { $('saldos-contagem').textContent = ''; return; }
    saldos = r.dados || [];
    const sel = $('saldo-empresa');
    if (sel.options.length === 1) {
      const empresas = new Map();
      for (const s of saldos) empresas.set(String(s.ID_EMPRESA), s.EMPRESA);
      for (const [id, nome] of [...empresas].sort((a, b) => a[1].localeCompare(b[1], 'pt-BR'))) {
        const op = Util.el('option', null, nome);
        op.value = id;
        sel.append(op);
      }
      if (salvos.empresa && empresas.has(salvos.empresa)) { sel.value = salvos.empresa; if (sel.value) { saldos = saldos.filter((s) => String(s.ID_EMPRESA) === sel.value); } }
    }
    contaAtual = saldos.find((s) => s.ID_CONTA === seletor.valor()) || null;
    desenharSaldos();
  }

  // ------------------------------------------------------------ extrato
  function origem(l) {
    const td = Util.el('td');
    if (l.ID_LANCAMENTO) {
      const a = Util.el('a', null, (l.LANCAMENTO_TIPO === 'P' ? 'A pagar' : 'A receber') + ' nº ' + l.ID_LANCAMENTO);
      a.href = '/fin/lancamento.html?id=' + encodeURIComponent(l.ID_LANCAMENTO) + '#baixas';
      a.dataset.dica = 'Abre a ficha do lançamento, na aba Baixas.';
      td.append(a);
      const sub = [l.PESSOA, l.QTD_BAIXAS > 1 ? 'pagamento em lote: ' + l.QTD_BAIXAS + ' parcelas' : ''].filter(Boolean).join(' · ');
      if (sub) td.append(Util.el('span', 'sub', sub));
    } else if (l.ID_TRANSFERENCIA) {
      const a = Util.el('a', null, 'Transferência ' + (Number(l.VALOR) < 0 ? 'para ' : 'de ') + (l.OUTRA_CONTA || 'outra conta'));
      const dia = Util.dataIso(l.DT_MOVIMENTO);
      a.href = '/banco/transferencias.html?idConta=' + encodeURIComponent(seletor.valor()) + '&de=' + dia + '&ate=' + dia + '&destacar=' + encodeURIComponent(l.ID_TRANSFERENCIA);
      a.dataset.dica = 'Abre a tela de transferências mostrando esta transferência.';
      td.append(a);
    } else if (l.TIPO !== 'SALDO_ANTERIOR' && l.TIPO !== 'SALDO_INICIAL') {
      td.textContent = Rotulos.de('movimentoTipo', l.TIPO);
    }
    return td;
  }

  function situacao(l) {
    const td = Util.el('td');
    const et = Util.el('span', 'etiquetas');
    if (l.SITUACAO === 'ESTORNADO') et.append(Util.el('span', 'etiqueta etiqueta-estornado', 'Estornado'));
    if (l.ID_MOVIMENTO && !l.CONTA_SALDO) {
      const h = Util.el('span', 'etiqueta', 'Histórico');
      h.dataset.dica = 'Movimento antes do saldo inicial da conta: aparece só como histórico e não mexe no saldo.';
      et.append(h);
    }
    if (l.CONCILIADO) et.append(Util.el('span', 'etiqueta etiqueta-conciliado', 'Conciliado'));
    td.append(et);
    return td;
  }

  function desenharExtrato() {
    const corpo = $('extrato');
    corpo.replaceChildren();
    const resumo = $('extrato-resumo');
    if (!linhas.length) {
      resumo.hidden = true;
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', seletor.valor() ? 'Nenhum movimento neste período.' : 'Escolha a conta e o período para ver o extrato.');
      td.colSpan = 8;
      tr.append(td);
      corpo.append(tr);
      $('extrato-contagem').textContent = '';
      return;
    }
    const p = linhas[0];
    resumo.hidden = false;
    $('rotulo-anterior').textContent = 'Saldo em ' + Util.data(p.DT_MOVIMENTO);
    $('valor-anterior').textContent = Util.moeda(p.SALDO_ANTERIOR);
    $('valor-entradas').textContent = Util.moeda(p.TOTAL_ENTRADAS);
    $('valor-saidas').textContent = Util.moeda(p.TOTAL_SAIDAS);
    $('rotulo-final').textContent = 'Saldo em ' + Util.data($('extrato-ate').value);
    $('valor-final').textContent = Util.moeda(p.SALDO_FINAL);
    for (const v of ['valor-anterior', 'valor-final']) $(v).classList.toggle('valor-negativo', Number($(v).textContent.replace(/\./g, '').replace(',', '.')) < 0);

    let qtd = 0;
    for (const l of linhas) {
      const especial = l.TIPO === 'SALDO_ANTERIOR' || l.TIPO === 'SALDO_INICIAL';
      const tr = Util.el('tr', especial ? 'linha-saldo' : (l.SITUACAO === 'ESTORNADO' ? 'linha-estornada' : ''));
      if (!especial) qtd++;
      const hist = Util.el('td', especial ? 'forte' : null, l.HISTORICO);
      if (l.USUARIO_CRIACAO && !especial) hist.title = 'Incluído por ' + l.USUARIO_CRIACAO;
      tr.append(Util.el('td', 'numero', Util.data(l.DT_MOVIMENTO)), hist, Util.el('td', null, l.DOCUMENTO || ''), origem(l),
        Util.el('td', 'numero', !especial && l.ENTRADA ? Util.moeda(l.ENTRADA) : (l.TIPO === 'SALDO_INICIAL' ? Util.moeda(l.VALOR) : '')),
        Util.el('td', 'numero', !especial && l.SAIDA ? Util.moeda(l.SAIDA) : ''),
        Util.el('td', classeValor(l.SALDO_ACUMULADO) + ' forte', Util.moeda(l.SALDO_ACUMULADO)), situacao(l));
      corpo.append(tr);
    }
    $('extrato-contagem').textContent = qtd === 1 ? '1 movimento' : qtd + ' movimentos';
  }

  async function carregarExtrato() {
    guardar();
    const idConta = seletor.valor();
    contaAtual = saldos.find((s) => s.ID_CONTA === idConta) || null;
    desenharSaldos();
    if (!idConta) { linhas = []; desenharExtrato(); return; }
    const de = $('extrato-de').value;
    const ate = $('extrato-ate').value;
    if (!de || !ate) { await Mensagens.alerta('Informe o período do extrato (De e Até).', 'ATENCAO', { foco: de ? $('extrato-ate') : $('extrato-de') }); return; }
    if (de > ate) { await Mensagens.alerta('A data "De" tem que ser antes da data "Até".', 'ATENCAO', { foco: $('extrato-de') }); return; }
    $('extrato-contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/banco/extrato', {
      idConta, de, ate, ocultarEstornados: $('extrato-ocultar').checked ? 'true' : '', texto: $('extrato-texto').value.trim()
    });
    if (!(await Mensagens.tratar(r, { foco: $('extrato-de') }))) { linhas = []; desenharExtrato(); return; }
    linhas = r.dados || [];
    desenharExtrato();
  }

  // ------------------------------------------------------------ exportar
  $('exportar-saldos').addEventListener('click', () => Util.exportarCsv('Saldos_' + ($('saldo-data').value || hoje()),
    ['Empresa', 'Conta', 'Tipo', 'Banco', 'Saldo', 'Limite', 'Disponível', 'Último movimento', 'Não conciliados', 'Último fechamento', 'Fechamento atrasado'],
    saldos.map((s) => [s.EMPRESA, s.DESCRICAO, Rotulos.de('contaTipo', s.TIPO), s.BANCO, Util.moeda(s.SALDO), Util.moeda(s.LIMITE_CREDITO), Util.moeda(s.DISPONIVEL),
      Util.data(s.DT_ULTIMO_MOVIMENTO), s.CONCILIA ? s.QTD_NAO_CONCILIADOS : '', Util.data(s.DT_ULTIMO_FECHAMENTO), s.FECHAMENTO_ATRASADO ? 'Sim' : ''])));
  $('exportar-extrato').addEventListener('click', () => {
    if (!linhas.length) return;
    const nome = (contaAtual ? contaAtual.DESCRICAO : 'conta') + '_' + $('extrato-de').value + '_a_' + $('extrato-ate').value;
    Util.exportarCsv('Extrato_' + nome.replace(/[^\w\-]+/g, '_'),
      ['Data', 'Histórico', 'Documento', 'Origem', 'Parceiro', 'Entrada', 'Saída', 'Saldo', 'Situação', 'Conciliado', 'Incluído por'],
      linhas.map((l) => [Util.data(l.DT_MOVIMENTO), l.HISTORICO, l.DOCUMENTO,
        l.ID_LANCAMENTO ? 'Lançamento ' + l.ID_LANCAMENTO : (l.ID_TRANSFERENCIA ? 'Transferência ' + l.ID_TRANSFERENCIA + ' (' + l.OUTRA_CONTA + ')' : Rotulos.de('movimentoTipo', l.TIPO)),
        l.PESSOA, l.ENTRADA ? Util.moeda(l.ENTRADA) : '', l.SAIDA ? Util.moeda(l.SAIDA) : '', Util.moeda(l.SALDO_ACUMULADO),
        l.SITUACAO === 'ESTORNADO' ? 'Estornado' : '', l.CONCILIADO ? 'Sim' : '', l.USUARIO_CRIACAO]));
  });

  // ------------------------------------------------------------ eventos
  $('filtros-saldos').addEventListener('submit', (e) => { e.preventDefault(); carregarSaldos(); });
  $('filtros-extrato').addEventListener('submit', (e) => { e.preventDefault(); carregarExtrato(); });
  $('saldo-data').addEventListener('change', carregarSaldos);
  $('saldo-empresa').addEventListener('change', () => { guardar(); carregarSaldos(); });
  for (const c of ['saldo-todas', 'saldo-inativas']) $(c).addEventListener('change', () => { guardar(); carregarSaldos(); });
  for (const c of ['extrato-de', 'extrato-ate', 'extrato-ocultar']) $(c).addEventListener('change', carregarExtrato);
  $('extrato-texto').addEventListener('input', Util.atrasar(carregarExtrato, 400));
  for (const b of document.querySelectorAll('[data-periodo]')) {
    b.addEventListener('click', () => { const p = periodo(b.dataset.periodo); $('extrato-de').value = p.de; $('extrato-ate').value = p.ate; carregarExtrato(); });
  }

  // ------------------------------------------------------------ início
  $('saldo-data').value = hoje();
  $('saldo-todas').checked = !!salvos.todas;
  $('saldo-inativas').checked = !!salvos.inativas;
  $('extrato-ocultar').checked = !!salvos.ocultar;
  const contaUrl = parseInt(Util.parametro('conta') || '', 10);
  const p = periodo('mes');
  $('extrato-de').value = Util.parametro('de') || (contaUrl ? p.de : salvos.de) || p.de;
  $('extrato-ate').value = Util.parametro('ate') || (contaUrl ? p.ate : salvos.ate) || p.ate;
  await carregarSaldos();
  const conta = contaUrl || salvos.conta;
  if (conta) {
    await seletor.definir(conta);
    await carregarExtrato();
    if (contaUrl) $('secao-extrato').scrollIntoView({ block: 'start' });
  } else {
    desenharExtrato();
  }
});
