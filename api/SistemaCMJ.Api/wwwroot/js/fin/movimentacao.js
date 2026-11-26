/* =============================================================================
   SistemaCMJ - js/fin/movimentacao.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 26/11/2026 (etapa 04f2d)
   Descrição : Aba Movimentação da ficha do Parceiro: componente único
               Movimentacao.criar(caixa, { idPessoa, nome }).
               - resumo do topo (FIN_Parceiro_Movimento_Resumo): a pagar em
                 aberto, a receber em aberto, vencido, pago/recebido nos
                 últimos 12 meses com a média mensal e o último pagamento;
                 clicar filtra a grade;
               - grade dos lançamentos do parceiro (FIN_Lancamento_Listar sem
                 tipo, com o parceiro): tipo, filtros de situação e período,
                 paginação, totais, etiqueta de pendências; a linha abre o
                 lançamento;
               - "+ Contas a pagar" / "+ Contas a receber" abrem a ficha nova já
                 com o parceiro; Exportar Excel; "Ver na lista completa".
               Só mostra o que o usuário pode ver (VER em FIN_PAGAR /
               FIN_RECEBER); quem não vê nenhum dos dois não vê a aba.
   ========================================================================== */
'use strict';

const Movimentacao = (() => {
  const TELA = { P: 'fin/lancamentos.html?tipo=P', R: 'fin/lancamentos.html?tipo=R' };
  const POR_PAGINA = 20;

  /** Tipos que o usuário pode ver ('P', 'R'). Vazio = a aba não aparece. */
  function tiposVisiveis() {
    return ['P', 'R'].filter((t) => Layout.acoesDe(TELA[t]).has('VER'));
  }

  function criar(caixa, opcoes) {
    const idPessoa = opcoes.idPessoa;
    const tipos = tiposVisiveis();
    const acoesP = Layout.acoesDe(TELA.P);
    const acoesR = Layout.acoesDe(TELA.R);
    const el = (tag, classe, texto) => Util.el(tag, classe, texto);
    let pagina = 1;
    let pedido = 0;
    const filtro = { tipo: tipos.length === 1 ? tipos[0] : '', situacao: 'EM_ABERTO', de: '', ate: '' };

    // ---------- montagem ----------
    caixa.replaceChildren();
    const barra = el('div', 'movimentacao-barra');
    const novoP = el('a', 'botao', '+ Contas a pagar');
    novoP.href = '/fin/lancamento.html?tipo=P&idPessoa=' + encodeURIComponent(idPessoa);
    novoP.dataset.dica = 'Abre um lançamento a pagar novo, já com este parceiro escolhido.';
    novoP.hidden = !acoesP.has('INCLUIR');
    const novoR = el('a', 'botao', '+ Contas a receber');
    novoR.href = '/fin/lancamento.html?tipo=R&idPessoa=' + encodeURIComponent(idPessoa);
    novoR.dataset.dica = 'Abre um lançamento a receber novo, já com este parceiro escolhido.';
    novoR.hidden = !acoesR.has('INCLUIR');
    const exportar = el('button', 'botao', 'Exportar Excel');
    exportar.type = 'button';
    exportar.dataset.dica = 'Baixa num arquivo que o Excel abre todas as linhas do filtro desta aba.';
    exportar.hidden = !(acoesP.has('EXPORTAR') || acoesR.has('EXPORTAR'));
    const verLista = el('a', 'botao', 'Ver na lista completa');
    verLista.dataset.dica = 'Abre Contas a pagar ou a receber já filtrada por este parceiro, com todos os filtros da lista.';
    barra.append(novoP, novoR, exportar, verLista);

    const resumo = el('div', 'contadores');
    resumo.setAttribute('aria-live', 'polite');
    const extra = el('p', 'suave movimentacao-media');

    const filtros = el('div', 'filtros movimentacao-filtros');
    const campo = (rotulo, controle, dica) => {
      const l = el('label', 'campo', rotulo);
      if (dica) l.dataset.dica = dica;
      l.append(controle);
      filtros.append(l);
      return controle;
    };
    const lista = (pares) => {
      const s = el('select');
      for (const [v, t] of pares) { const o = el('option', null, t); o.value = v; s.append(o); }
      return s;
    };
    const selTipo = campo('Tipo', lista([['', 'A pagar e a receber'], ['P', 'A pagar'], ['R', 'A receber']].filter((x) => !x[0] || tipos.includes(x[0]))),
      'A pagar, a receber ou os dois.');
    const selSituacao = campo('Situação', lista([['EM_ABERTO', 'Em aberto'], ['VENCIDA', 'Vencida'], ['A_VENCER', 'A vencer'], ['PAGA', 'Quitada'],
      ['CANCELADA', 'Cancelada'], ['', 'Todas']]), 'Em aberto = aberta ou paga em parte. Vencida = em aberto com vencimento antes de hoje.');
    const de = el('input'); de.type = 'date';
    const ate = el('input'); ate.type = 'date';
    campo('Vencimento de', de, 'Começo do período pelo vencimento (pode deixar em branco).');
    campo('até', ate, 'Fim do período pelo vencimento (pode deixar em branco).');
    if (tipos.length === 1) selTipo.closest('label').hidden = true;

    const rolagem = el('div', 'rolagem');
    const tabela = el('table', 'tabela');
    const cab = el('thead');
    const trCab = el('tr');
    for (const [t, c] of [['Tipo'], ['Vencimento'], ['Histórico / documento'], ['Parcela'], ['Valor', 'numero'], ['Pago / recebido', 'numero'], ['Saldo', 'numero'], ['Situação']])
      trCab.append(el('th', c || null, t));
    cab.append(trCab);
    const corpo = el('tbody');
    tabela.append(cab, corpo);
    rolagem.append(tabela);

    const rodape = el('div', 'movimentacao-rodape');
    const contagem = el('span', 'suave');
    const totais = el('span', 'forte');
    const anterior = el('button', 'botao', '‹ Anterior'); anterior.type = 'button';
    const proxima = el('button', 'botao', 'Próxima ›'); proxima.type = 'button';
    const textoPagina = el('span', 'suave');
    const paginacao = el('span', 'paginacao');
    paginacao.append(anterior, textoPagina, proxima);
    rodape.append(contagem, totais, paginacao);

    caixa.append(barra, resumo, extra, filtros, rolagem, rodape);

    // ---------- resumo ----------
    let linhasResumo = [];
    function contador(rotulo, valor, qtd, classe, dica, acao) {
      const b = el('button', 'contador ' + classe);
      b.type = 'button';
      b.dataset.dica = dica;
      b.append(el('span', 'contador-rotulo', rotulo), el('span', 'contador-valor', Util.moeda(valor || 0)), el('span', 'contador-qtd', qtd));
      b.addEventListener('click', acao);
      resumo.append(b);
      return b;
    }
    const qtdParcelas = (n) => (n === 1 ? '1 parcela' : (n || 0) + ' parcelas');
    function desenharResumo() {
      resumo.replaceChildren();
      const de = (t) => linhasResumo.find((x) => x.TIPO === t) || {};
      const aplicar = (tipo, situacao) => () => {
        filtro.tipo = tipos.length === 1 ? tipos[0] : tipo;
        filtro.situacao = situacao;
        filtro.de = ''; filtro.ate = '';
        mostrarFiltro(); pagina = 1; carregar();
      };
      if (tipos.includes('P')) {
        const p = de('P');
        contador('A pagar em aberto', p.VALOR_EM_ABERTO, qtdParcelas(p.QTD_EM_ABERTO), 'contador-aberto', 'Parcelas a pagar abertas ou pagas em parte. Clique para ver só elas.', aplicar('P', 'EM_ABERTO'));
      }
      if (tipos.includes('R')) {
        const r = de('R');
        contador('A receber em aberto', r.VALOR_EM_ABERTO, qtdParcelas(r.QTD_EM_ABERTO), 'contador-aberto', 'Parcelas a receber abertas ou recebidas em parte. Clique para ver só elas.', aplicar('R', 'EM_ABERTO'));
      }
      const venc = linhasResumo.reduce((s, x) => s + Number(x.VALOR_VENCIDAS || 0), 0);
      const qtdVenc = linhasResumo.reduce((s, x) => s + Number(x.QTD_VENCIDAS || 0), 0);
      contador('Vencido', venc, qtdParcelas(qtdVenc), 'contador-vencidas', 'Parcelas em aberto com vencimento antes de hoje (a pagar e a receber). Clique para ver só elas.', aplicar('', 'VENCIDA'));
      for (const t of tipos) {
        const x = de(t);
        const rot = t === 'P' ? 'Pago (12 meses)' : 'Recebido (12 meses)';
        contador(rot, x.VALOR_PAGO_12M, 'média ' + Util.moeda(x.MEDIA_MENSAL_12M || 0) + '/mês', 'contador-a-vencer',
          (t === 'P' ? 'Total pago' : 'Total recebido') + ' a este parceiro nos últimos 12 meses (valor líquido das baixas; estornos descontados) e a média por mês. Clique para ver as quitadas.',
          aplicar(t, 'PAGA'));
      }
      const ultimos = tipos.map((t) => {
        const x = de(t);
        return x.DT_ULTIMO_PAGAMENTO ? (t === 'P' ? 'Último pagamento: ' : 'Último recebimento: ') + Util.data(x.DT_ULTIMO_PAGAMENTO) : null;
      }).filter(Boolean);
      extra.textContent = ultimos.length ? ultimos.join(' · ') : 'Nenhum pagamento ou recebimento registrado para este parceiro.';
    }

    // ---------- filtro <-> tela ----------
    function mostrarFiltro() {
      selTipo.value = filtro.tipo; selSituacao.value = filtro.situacao; de.value = filtro.de; ate.value = filtro.ate;
      verLista.href = '/' + TELA[filtro.tipo || tipos[0]] + '&idPessoa=' + encodeURIComponent(idPessoa)
        + '&situacao=' + encodeURIComponent(filtro.situacao || '');
    }
    function lerFiltro() {
      filtro.tipo = selTipo.value; filtro.situacao = selSituacao.value; filtro.de = de.value; filtro.ate = ate.value;
      mostrarFiltro();
    }
    for (const c of [selTipo, selSituacao, de, ate]) c.addEventListener('change', () => { lerFiltro(); pagina = 1; carregar(); });

    function pedidoApi(paginaPedida, porPagina) {
      return {
        tipo: filtro.tipo, idPessoa, situacao: filtro.situacao, campoData: 'VENCIMENTO', vencDe: filtro.de, vencAte: filtro.ate,
        visao: 'PARCELA', ordem: 'VENCIMENTO', pagina: paginaPedida, porPagina
      };
    }

    // ---------- grade ----------
    const textoSituacao = (l) => {
      const pagar = l.TIPO === 'P';
      if (l.SITUACAO === 'PAGA') return pagar ? 'Paga' : 'Recebida';
      if (l.SITUACAO === 'PARCIAL') return pagar ? 'Paga em parte' : 'Recebida em parte';
      if (l.SITUACAO === 'CANCELADA') return 'Cancelada';
      if (l.VENCIDA) return 'Vencida há ' + l.DIAS_ATRASO + (l.DIAS_ATRASO === 1 ? ' dia' : ' dias');
      return 'Aberta';
    };
    const textoParcela = (l) => (l.ID_PARCELA ? (l.NUMERO + '/' + l.QTD_PARCELAS) : '');
    function etiquetaPendencias(l) {
      const qtd = Number(l.QTD_PENDENCIAS) || 0;
      if (!qtd) return null;
      const itens = String(l.PENDENCIAS || '').split('; ').filter(Boolean).slice(0, 3).map((t) => '• ' + t);
      if (qtd > itens.length) itens.push('e mais ' + (qtd - itens.length) + ' (veja na ficha)');
      const span = el('span', 'etiqueta-pendencia' + (l.PENDENCIA_ATRASADA ? ' atrasada' : ''),
        (l.PENDENCIA_BLOQUEIA ? '🔒 ' : '⚠ ') + (qtd === 1 ? '1 pendência' : qtd + ' pendências'));
      span.dataset.dica = (qtd === 1 ? 'Pendência:' : 'Pendências:') + '\n' + itens.join('\n');
      return span;
    }
    function celula(texto, sub, classe) {
      const td = el('td', classe || null, texto || '');
      if (sub) td.append(el('span', 'sub', sub));
      return td;
    }
    function desenhar(linhas) {
      corpo.replaceChildren();
      if (!linhas.length) {
        const tr = el('tr');
        const td = el('td', 'vazio', 'Nenhum lançamento deste parceiro com esses filtros.');
        td.colSpan = 8;
        tr.append(td);
        corpo.append(tr);
      }
      for (const l of linhas) {
        const tr = el('tr', 'clicavel' + (l.VENCIDA ? ' linha-vencida' : ''));
        tr.tabIndex = 0;
        const abrir = () => { location.href = '/fin/lancamento.html?tipo=' + l.TIPO + '&id=' + encodeURIComponent(l.ID_LANCAMENTO); };
        tr.addEventListener('click', abrir);
        tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(); });
        const sit = el('td');
        sit.append(el('span', 'situacao situacao-' + (l.VENCIDA ? 'vencida' : String(l.SITUACAO || '').toLowerCase()), textoSituacao(l)));
        const etiqueta = etiquetaPendencias(l);
        if (etiqueta) sit.append(el('br'), etiqueta);
        tr.append(
          celula(l.TIPO === 'P' ? 'A pagar' : 'A receber', null, 'tipo-' + l.TIPO.toLowerCase()),
          celula(Util.data(l.DT_VENCIMENTO)),
          celula(l.HISTORICO, [l.DOCUMENTO, 'nº ' + l.ID_LANCAMENTO, l.EMPRESA_NOME].filter(Boolean).join(' · ')),
          celula(textoParcela(l)),
          celula(Util.moeda(l.VALOR), null, 'numero'),
          celula(Util.moeda(l.VALOR_BAIXADO), null, 'numero'),
          celula(Util.moeda(l.SALDO), null, 'numero forte'),
          sit);
        corpo.append(tr);
      }
    }
    function desenharRodape(linhas) {
      const primeira = linhas[0];
      const total = primeira ? primeira.TOTAL_LINHAS : 0;
      const paginas = Math.max(1, Math.ceil(total / POR_PAGINA));
      contagem.textContent = total === 1 ? '1 parcela' : total + ' parcelas';
      totais.textContent = primeira ? ' · Valor ' + Util.moeda(primeira.TOTAL_VALOR) + ' · Saldo ' + Util.moeda(primeira.TOTAL_SALDO) : '';
      paginacao.hidden = paginas <= 1;
      textoPagina.textContent = 'Página ' + pagina + ' de ' + paginas;
      anterior.disabled = pagina <= 1;
      proxima.disabled = pagina >= paginas;
    }
    anterior.addEventListener('click', () => { if (pagina > 1) { pagina--; carregar(); } });
    proxima.addEventListener('click', () => { pagina++; carregar(); });

    async function carregar() {
      const meu = ++pedido;
      contagem.textContent = 'Buscando…';
      const r = await Api.get('/api/fin/lancamentos', pedidoApi(pagina, POR_PAGINA));
      if (meu !== pedido) return false;
      if (!(await Mensagens.tratar(r))) { contagem.textContent = ''; return false; }
      const linhas = r.dados || [];
      desenhar(linhas);
      desenharRodape(linhas);
      return true;
    }

    exportar.addEventListener('click', async () => {
      const todas = [];
      for (let p = 1; p <= 50; p++) {
        const r = await Api.get('/api/fin/lancamentos', pedidoApi(p, 1000));
        if (!(await Mensagens.tratar(r))) return;
        const linhas = r.dados || [];
        todas.push(...linhas);
        if (linhas.length < 1000 || todas.length >= (linhas[0] ? linhas[0].TOTAL_LINHAS : 0)) break;
      }
      Util.exportarCsv('Movimentacao_' + String(idPessoa).padStart(6, '0'),
        ['Nº', 'Tipo', 'Vencimento', 'Empresa', 'Histórico', 'Documento', 'Parcela', 'Emissão', 'Valor', 'Pago/recebido', 'Saldo', 'Situação'],
        todas.map((l) => [l.ID_LANCAMENTO, l.TIPO === 'P' ? 'A pagar' : 'A receber', Util.data(l.DT_VENCIMENTO), l.EMPRESA_NOME, l.HISTORICO, l.DOCUMENTO,
          textoParcela(l), Util.data(l.DT_EMISSAO), Util.moeda(l.VALOR), Util.moeda(l.VALOR_BAIXADO), Util.moeda(l.SALDO), textoSituacao(l)]));
    });

    /** Carrega resumo e grade. Devolve false se não deu (a mensagem já apareceu). */
    async function carregarTudo() {
      mostrarFiltro();
      const r = await Api.get('/api/fin/parceiros/' + encodeURIComponent(idPessoa) + '/movimentacao/resumo');
      if (!(await Mensagens.tratar(r))) return false;
      linhasResumo = r.dados || [];
      desenharResumo();
      if (opcoes.aoContar) {
        const qtd = linhasResumo.reduce((s, x) => s + Number(x.QTD_EM_ABERTO || 0), 0);
        opcoes.aoContar(qtd);
      }
      return carregar();
    }

    return { carregar: carregarTudo };
  }

  return { criar, tiposVisiveis };
})();
