/* =============================================================================
   SistemaCMJ - js/fin/lancamento.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 26/11/2026 (etapa 04f2b)
   Descrição : Ficha do lançamento das telas Contas a pagar (?tipo=P,
               FIN_PAGAR) e Contas a receber (?tipo=R, FIN_RECEBER): incluir,
               alterar, gerar parcelas, cancelar (com motivo), excluir
               (lixeira) e copiar (?copiar=ID abre um novo com os mesmos
               dados). Janela de avisos contra erro de digitação (P17):
               a gravação devolve PENDENTE com os avisos; o usuário marca
               "Estou ciente" e, na trava de datas, informa o motivo; a
               gravação é repetida com os avisos confirmados. Parceiro novo
               puxa conta do plano e centro de custo padrão (FIN_Lancamento_
               Padroes_Obter). Abas Parcelas, Baixas (consulta), Anexos e
               Histórico (componentes padrão). Regras de verdade ficam no
               FIN_Lancamento_Gravar.
               04f2c2: quadro de Pendências (js/fin/pendencias.js, P27) acima
               das abas, com atalho para o campo de cada pendência automática
               e a faixa vermelha quando alguma bloqueia a baixa.
               04f2d: ?idPessoa= já escolhe o parceiro (vem da aba Movimentação).
               04g3a: baixa pela aba Parcelas (botão Pagar/Receber em cada
               parcela em aberto e "Baixar marcadas"; janela js/fin/baixa.js),
               só com a ação BAIXAR, lançamento ativo e que não é previsão.
               04g3b: botão Estornar em cada baixa da aba Baixas (ação ESTORNAR;
               janela Baixa.estornar com data, motivo e prévia).
               04h2: ?voltar=/ (vem da agenda da tela inicial): o Voltar, o
               Esc e o fim de uma exclusão devolvem à agenda, no mesmo ponto.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const idLancamento = parseInt(Util.parametro('id') || '0', 10) || null;
  const idCopiar = idLancamento ? null : (parseInt(Util.parametro('copiar') || '0', 10) || null);
  const tipo = (Util.parametro('tipo') || 'P').toUpperCase() === 'R' ? 'R' : 'P';
  const pagar = tipo === 'P';
  const item = pagar ? 'FIN_PAGAR' : 'FIN_RECEBER';
  // Endereço de volta: só caminhos do próprio sistema (começa com "/" e não com "//").
  const voltar = Util.parametro('voltar');
  const voltarValido = voltar && voltar.startsWith('/') && !voltar.startsWith('//') ? voltar : null;
  const lista = voltarValido || '/fin/lancamentos.html?tipo=' + tipo;
  const nomeTipo = pagar ? 'conta a pagar' : 'conta a receber';
  const rotuloParceiro = pagar ? 'Fornecedor' : 'Cliente';
  document.body.dataset.menu = 'fin/lancamentos.html?tipo=' + tipo;
  document.body.dataset.tela = 'fin/lancamentos.html?tipo=' + tipo;

  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  $('link-voltar').href = lista;
  $('link-voltar').textContent = '‹ Voltar para ' + (voltarValido ? (voltarValido === '/' || voltarValido === '/index.html' ? 'a agenda' : 'a tela anterior') : (pagar ? 'Contas a pagar' : 'Contas a receber'));
  $('rotulo-parceiro').textContent = rotuloParceiro + ' (parceiro) *';
  $('coluna-baixado').textContent = pagar ? 'Pago' : 'Recebido';

  let sujo = false;
  let podeEditar = idLancamento ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
  let lanc = null;          // lançamento carregado (alteração)
  let parcelas = [];        // [{ id, vencimento, valor, idContaPrevista, contaPrevista, valorBaixado, saldo, situacao, travada }]
  let temBaixa = false;
  let podeBaixar = false;   // 04g3a: ação BAIXAR, lançamento ativo e que não é previsão
  let podeEstornar = false; // 04g3b: ação ESTORNAR e lançamento fora da lixeira
  const marcadas = new Set(); // ID_PARCELA marcados para "Baixar marcadas"
  const carregadas = new Set();

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    if (aba.id === 'aba-historico' && !carregadas.has('historico')) carregarHistorico();
    if (aba.id === 'aba-anexos' && !carregadas.has('anexos')) carregarAnexos();
  }
  abas.forEach((a) => {
    a.addEventListener('click', () => abrirAba(a));
    a.addEventListener('keydown', (e) => {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      const visiveis = abas.filter((x) => !x.hidden);
      const pos = visiveis.indexOf(a);
      const prox = visiveis[(pos + (e.key === 'ArrowRight' ? 1 : visiveis.length - 1)) % visiveis.length];
      prox.focus();
      abrirAba(prox);
    });
  });

  // ---------- Escolhas com busca ----------
  const marcarSujo = () => { sujo = true; };
  const seletorPessoa = Seletor.criar($('seletor-pessoa'), {
    tipo: 'PESSOA', rotulo: rotuloParceiro,
    dica: 'Digite parte do nome, do nome fantasia ou o CPF/CNPJ e escolha na lista. Obrigatório. Ao escolher, o sistema sugere a conta do plano e o centro de custo padrão do parceiro (quando estiverem em branco).',
    aoMudar: (id) => { marcarSujo(); if (id) sugerirPadroes(id); }
  });
  const seletorCentro = Seletor.criar($('seletor-centro'), {
    tipo: 'CENTRO', rotulo: 'Centro de custo', aoMudar: marcarSujo,
    dica: 'Obra, escritório ou imóvel do lançamento. Obrigatório. A empresa do lançamento é a do centro de custo.'
  });
  const seletorPlano = Seletor.criar($('seletor-plano'), {
    tipo: 'PLANO', rotulo: 'Conta do plano', aoMudar: marcarSujo,
    dica: 'Conta do plano de contas (ex.: material de construção). Obrigatória. Digite parte do nome ou o número.'
  });
  const seletorHistorico = Seletor.criar($('seletor-historico'), {
    tipo: 'HISTORICO', rotulo: 'Histórico padrão',
    dica: 'Texto pronto para o histórico. Opcional. Ao escolher, preenche o campo Histórico se ele estiver vazio.',
    aoMudar: (id, h) => { marcarSujo(); if (h && !$('historico').value.trim()) $('historico').value = h.DESCRICAO; }
  });
  const seletores = [seletorPessoa, seletorCentro, seletorPlano, seletorHistorico];

  async function sugerirPadroes(idPessoa) {
    if (!podeEditar || (seletorPlano.valor() && seletorCentro.valor())) return;
    const r = await Api.get('/api/fin/lancamentos/padroes', { idPessoa, tipo });
    if (!r.sucesso || !r.dados) return;
    const d = r.dados;
    const usados = [];
    if (!seletorPlano.valor() && d.ID_PLANO_CONTA) { await seletorPlano.definir(d.ID_PLANO_CONTA); usados.push('conta do plano'); }
    if (!seletorCentro.valor() && d.ID_CENTRO_CUSTO) { await seletorCentro.definir(d.ID_CENTRO_CUSTO); usados.push('centro de custo'); }
    if (usados.length) Mensagens.sucesso('Preenchido pelo padrão do parceiro (ou pelo último lançamento dele): ' + usados.join(' e ') + '. Confira.');
  }

  // ---------- Parcelas ----------
  const hojeIso = () => {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  };
  function somarData(iso, intervalo, vezes) {
    const [a, m, d] = iso.split('-').map(Number);
    const passo = Number(intervalo.substring(1)) * vezes;
    if (intervalo[0] === 'D') {
      const dt = new Date(a, m - 1, d + passo);
      return dt.getFullYear() + '-' + String(dt.getMonth() + 1).padStart(2, '0') + '-' + String(dt.getDate()).padStart(2, '0');
    }
    const total = (m - 1) + passo;
    const ano = a + Math.floor(total / 12);
    const mes = (total % 12) + 1;
    const ultimo = new Date(ano, mes, 0).getDate();
    return ano + '-' + String(mes).padStart(2, '0') + '-' + String(Math.min(d, ultimo)).padStart(2, '0');
  }
  const centavos = (v) => Math.round(Number(v || 0) * 100);

  const baixavel = (p) => podeBaixar && !!p.id && Number(p.saldo) > 0 && (p.situacao === 'ABERTA' || p.situacao === 'PARCIAL');

  async function baixar(ids) {
    if (sujo) { await Mensagens.alerta('Há alterações na ficha que ainda não foram gravadas. Grave (ou descarte) antes de baixar.', 'ATENCAO'); return; }
    if (await Baixa.abrir({ parcelas: ids })) Util.recarregar(fichaUrl(idLancamento) + '#baixas');
  }

  function atualizarMarcadas() {
    const validas = parcelas.filter(baixavel).map((p) => p.id);
    for (const id of [...marcadas]) if (!validas.includes(id)) marcadas.delete(id);
    const botao = $('botao-baixar-marcadas');
    botao.textContent = 'Baixar marcadas' + (marcadas.size ? ' (' + marcadas.size + ')' : '');
    botao.disabled = !marcadas.size;
    const todas = $('marcar-todas');
    todas.checked = validas.length > 0 && marcadas.size === validas.length;
    todas.disabled = !validas.length;
  }

  function desenharParcelas() {
    const corpo = $('linhas-parcelas');
    corpo.replaceChildren();
    if (!parcelas.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma parcela. Informe o valor total e clique em "Gerar parcelas" na aba Dados principais, ou em "+ Parcela".');
      td.colSpan = 10;
      tr.append(td);
      corpo.append(tr);
    }
    const ordem = parcelas.map((p, i) => i).sort((x, y) => String(parcelas[x].vencimento || '9').localeCompare(String(parcelas[y].vencimento || '9')));
    const numero = new Map(ordem.map((i, n) => [i, n + 1]));
    parcelas.forEach((p, i) => {
      const tr = Util.el('tr');
      const travada = !!p.travada || !podeEditar;
      const venc = Util.el('input');
      venc.type = 'date';
      venc.value = Util.dataIso(p.vencimento);
      venc.disabled = travada;
      venc.setAttribute('aria-label', 'Vencimento da parcela ' + numero.get(i));
      venc.dataset.dica = 'Vencimento da parcela. Obrigatório.' + (p.travada ? ' Parcela com baixa: não muda.' : '');
      venc.addEventListener('change', () => { p.vencimento = venc.value; sujo = true; desenharParcelas(); });
      const valor = Util.el('input');
      valor.inputMode = 'decimal';
      valor.value = p.valor === null || p.valor === undefined || p.valor === '' ? '' : Util.moeda(p.valor);
      valor.disabled = travada;
      valor.setAttribute('aria-label', 'Valor da parcela ' + numero.get(i));
      valor.dataset.dica = 'Valor da parcela. Obrigatório.' + (p.travada ? ' Parcela com baixa: não muda.' : '');
      valor.addEventListener('change', () => {
        const v = Util.lerMoeda(valor.value);
        p.valor = isNaN(v) ? valor.value : v;
        if (!isNaN(v)) valor.value = Util.moeda(v);
        sujo = true;
        atualizarSoma();
      });
      const tdVenc = Util.el('td'); tdVenc.append(venc);
      const tdValor = Util.el('td'); tdValor.append(valor);
      const tdSit = Util.el('td');
      if (p.id) tdSit.append(Util.el('span', 'situacao situacao-' + String(p.situacao || 'aberta').toLowerCase(), textoSituacao(p.situacao)));
      else tdSit.append(Util.el('span', 'suave', 'nova'));
      const tdMarcar = Util.el('td', 'col-marcar');
      const tdBaixar = Util.el('td', 'col-baixar');
      if (baixavel(p)) {
        const marca = Util.el('input');
        marca.type = 'checkbox';
        marca.checked = marcadas.has(p.id);
        marca.setAttribute('aria-label', 'Marcar a parcela ' + numero.get(i) + ' para baixar');
        marca.dataset.dica = 'Marca a parcela para baixar junto com outras (botão "Baixar marcadas").';
        marca.addEventListener('change', () => { if (marca.checked) marcadas.add(p.id); else marcadas.delete(p.id); atualizarMarcadas(); });
        tdMarcar.append(marca);
        const b = Util.el('button', 'botao botao-pequeno', pagar ? 'Pagar' : 'Receber');
        b.type = 'button';
        b.dataset.dica = 'Abre a janela de baixa desta parcela (' + (pagar ? 'pagamento' : 'recebimento') + ' total ou parcial).';
        b.addEventListener('click', () => baixar([p.id]));
        tdBaixar.append(b);
      }
      const tdAcao = Util.el('td', 'col-acao');
      if (!travada && !p.fixa) {
        const tirar = Util.el('button', 'botao botao-icone', '×');
        tirar.type = 'button';
        tirar.setAttribute('aria-label', 'Tirar a parcela ' + numero.get(i));
        tirar.dataset.dica = 'Tira esta parcela (só sai de verdade ao gravar).';
        tirar.addEventListener('click', () => { parcelas.splice(i, 1); sujo = true; desenharParcelas(); });
        tdAcao.append(tirar);
      }
      tr.append(tdMarcar, Util.el('td', 'numero col-numero', numero.get(i) + '/' + parcelas.length), tdVenc, tdValor,
        Util.el('td', null, p.contaPrevista || ''), Util.el('td', 'numero', p.id ? Util.moeda(p.valorBaixado) : ''),
        Util.el('td', 'numero', p.id ? Util.moeda(p.saldo) : ''), tdSit, tdBaixar, tdAcao);
      corpo.append(tr);
    });
    $('aba-parcelas').textContent = 'Parcelas' + (parcelas.length ? ' (' + parcelas.length + ')' : '');
    atualizarMarcadas();
    atualizarSoma();
  }

  function atualizarSoma() {
    const soma = parcelas.reduce((s, p) => s + (typeof p.valor === 'number' ? centavos(p.valor) : 0), 0);
    $('soma-parcelas').textContent = Util.moeda(soma / 100);
    const total = Util.lerMoeda($('valorTotal').value);
    const dif = isNaN(total) ? 0 : centavos(total) - soma;
    const aviso = $('diferenca-parcelas');
    aviso.hidden = !parcelas.length || dif === 0;
    aviso.textContent = dif > 0 ? 'Faltam ' + Util.moeda(dif / 100) + ' para o valor total' : 'Passa ' + Util.moeda(-dif / 100) + ' do valor total';
  }

  function textoSituacao(s) {
    return { ABERTA: 'Em aberto', PARCIAL: 'Parcial', PAGA: pagar ? 'Paga' : 'Recebida', CANCELADA: 'Cancelada' }[String(s || '').toUpperCase()] || (s || '');
  }

  async function gerarParcelas() {
    const total = Util.lerMoeda($('valorTotal').value);
    const qtd = parseInt($('qtdParcelas').value, 10);
    const primeiro = $('primeiroVencimento').value;
    if (isNaN(total) || total <= 0) { await Mensagens.alerta('Informe o valor total antes de gerar as parcelas.', 'ATENCAO', { foco: $('valorTotal') }); return; }
    if (!(qtd >= 1 && qtd <= 360)) { await Mensagens.alerta('Informe o nº de parcelas (de 1 a 360).', 'ATENCAO', { foco: $('qtdParcelas') }); return; }
    if (!primeiro) { await Mensagens.alerta('Informe o 1º vencimento.', 'ATENCAO', { foco: $('primeiroVencimento') }); return; }
    const fixas = parcelas.filter((p) => p.travada);
    // parcela só com baixa estornada (fixa) é reaproveitada primeiro: ela muda, mas não pode sair
    const livres = parcelas.filter((p) => !p.travada && p.id).sort((a, b) => (b.fixa ? 1 : 0) - (a.fixa ? 1 : 0));
    const restante = centavos(total) - fixas.reduce((s, p) => s + centavos(p.valor), 0);
    const novas = qtd - fixas.length;
    if (fixas.length && novas < 1) {
      await Mensagens.alerta('Há ' + fixas.length + ' parcela(s) com baixa, que não mudam. O nº de parcelas tem que ser maior que isso.', 'ATENCAO', { foco: $('qtdParcelas') });
      return;
    }
    if (restante <= 0) { await Mensagens.alerta('As parcelas com baixa já somam o valor total: não sobra valor para novas parcelas.', 'ATENCAO'); return; }
    const semBaixa = parcelas.filter((p) => !p.travada).length;
    if (semBaixa && !(await Mensagens.confirmar('Gerar parcelas?', 'As ' + semBaixa + ' parcela(s) sem baixa serão trocadas pelas novas' + (fixas.length ? ' (as ' + fixas.length + ' com baixa ficam como estão)' : '') + '. Continuar?', 'Gerar'))) return;
    const base = Math.floor(restante / novas);
    const geradas = [];
    for (let n = 0; n < novas; n++) {
      const valor = (n === novas - 1 ? restante - base * (novas - 1) : base) / 100;
      const reaproveitar = livres[n];
      geradas.push({ id: reaproveitar ? reaproveitar.id : null, vencimento: somarData(primeiro, $('intervalo').value, n + fixas.length), valor,
        idContaPrevista: reaproveitar ? reaproveitar.idContaPrevista : null, contaPrevista: reaproveitar ? reaproveitar.contaPrevista : '',
        valorBaixado: 0, saldo: valor, situacao: 'ABERTA', travada: false, fixa: reaproveitar ? !!reaproveitar.fixa : false });
    }
    parcelas = [...fixas, ...geradas];
    sujo = true;
    desenharParcelas();
    Mensagens.sucesso(geradas.length + ' parcela(s) gerada(s). Confira na aba Parcelas.');
  }
  $('botao-gerar').addEventListener('click', gerarParcelas);
  $('marcar-todas').addEventListener('change', () => {
    marcadas.clear();
    if ($('marcar-todas').checked) for (const p of parcelas.filter(baixavel)) marcadas.add(p.id);
    desenharParcelas();
  });
  $('botao-baixar-marcadas').addEventListener('click', () => { if (marcadas.size) baixar([...marcadas]); });
  $('botao-mais-parcela').addEventListener('click', () => {
    const ultima = parcelas.map((p) => p.vencimento).filter(Boolean).sort().pop();
    parcelas.push({ id: null, vencimento: ultima ? somarData(Util.dataIso(ultima), 'M1', 1) : ($('primeiroVencimento').value || ''), valor: '',
      idContaPrevista: null, contaPrevista: '', valorBaixado: 0, saldo: 0, situacao: 'ABERTA', travada: false });
    sujo = true;
    desenharParcelas();
    const campos = $('linhas-parcelas').querySelectorAll('input');
    if (campos.length) campos[campos.length - 1].focus();
  });
  $('valorTotal').addEventListener('change', () => {
    const v = Util.lerMoeda($('valorTotal').value);
    if (!isNaN(v) && $('valorTotal').value.trim()) $('valorTotal').value = Util.moeda(v);
    // lançamento novo com uma parcela só: acompanha o valor total
    if (!idLancamento && parcelas.length === 1 && !parcelas[0].id && !isNaN(v)) { parcelas[0].valor = v; desenharParcelas(); }
    atualizarSoma();
  });
  $('dtEmissao').addEventListener('change', () => {
    if (!$('primeiroVencimento').value && $('dtEmissao').value) $('primeiroVencimento').value = $('dtEmissao').value;
  });

  // ---------- Baixas (consulta) ----------
  async function estornarBaixa(b) {
    if (sujo) { await Mensagens.alerta('Há alterações na ficha que ainda não foram gravadas. Grave (ou descarte) antes de estornar.', 'ATENCAO'); return; }
    const descricao = 'parcela ' + b.parcela + ', ' + Util.dataIso(b.data).split('-').reverse().join('/') + ', ' + Util.moeda(b.liquido) + (b.conta ? ', ' + b.conta : '');
    if (await Baixa.estornar({ idBaixa: b.id, descricao })) Util.recarregar(fichaUrl(idLancamento) + '#baixas');
  }

  function desenharBaixas(baixas) {
    const corpo = $('linhas-baixas');
    corpo.replaceChildren();
    if (!baixas.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma baixa.');
      td.colSpan = 10;
      tr.append(td);
      corpo.append(tr);
    }
    for (const b of baixas) {
      const tr = Util.el('tr', b.estornada || b.idBaixaEstornada ? 'linha-estornada' : null);
      const acrescimo = Number(b.juros || 0) + Number(b.multa || 0) + Number(b.correcao || 0);
      const desconto = Number(b.desconto || 0) + Number(b.abatimento || 0);
      const sit = b.idBaixaEstornada ? 'Estorno' : (b.estornada ? 'Estornada' : (b.compensado ? 'Compensada' : 'A compensar'));
      tr.append(Util.el('td', null, Util.data(b.data)), Util.el('td', 'numero', b.parcela), Util.el('td', null, b.conta || ''),
        Util.el('td', null, b.forma || ''), Util.el('td', 'numero', Util.moeda(b.principal)), Util.el('td', 'numero', acrescimo ? Util.moeda(acrescimo) : ''),
        Util.el('td', 'numero', desconto ? Util.moeda(desconto) : ''), Util.el('td', 'numero forte', Util.moeda(b.liquido)), Util.el('td', null, sit));
      const tdEstornar = Util.el('td', 'col-baixar');
      if (podeEstornar && !b.estornada && !b.idBaixaEstornada) {
        const bt = Util.el('button', 'botao botao-pequeno', 'Estornar');
        bt.type = 'button';
        bt.dataset.dica = 'Desfaz esta baixa com data e motivo: a parcela volta a ficar em aberto e a conta ganha o movimento inverso. Pagamento em lote estorna inteiro.';
        bt.addEventListener('click', () => estornarBaixa(b));
        tdEstornar.append(bt);
      }
      tr.append(tdEstornar);
      if (b.observacao) tr.title = b.observacao;
      corpo.append(tr);
    }
    $('aba-baixas').textContent = 'Baixas' + (baixas.length ? ' (' + baixas.length + ')' : '');
  }

  // ---------- Avisos já confirmados ----------
  function desenharConfirmados(lista) {
    const ul = $('lista-confirmados');
    ul.replaceChildren();
    for (const a of lista) {
      const li = Util.el('li', null, a.mensagem + (a.motivo ? ' — motivo: ' + a.motivo : ''));
      li.append(Util.el('span', 'suave', ' (' + [a.usuario, Util.dataHora(a.data)].filter(Boolean).join(', ') + ')'));
      ul.append(li);
    }
    $('bloco-confirmados').hidden = !lista.length;
  }

  // ---------- Anexos e Histórico (componentes padrão) ----------
  let anexos = null;
  async function carregarAnexos() {
    if (!anexos) anexos = Anexos.criar($('anexos'), {
      item, tabela: 'FIN.Lancamento', id: idLancamento,
      podeAnexar: acoes.has('ALTERAR') && !(lanc && lanc.NA_LIXEIRA),
      aoMudar: (qtd) => {
        $('aba-anexos').textContent = 'Anexos' + (qtd ? ' (' + qtd + ')' : '');
        if (quadroPendencias && carregadas.has('anexos')) quadroPendencias.carregar(); // anexar pode resolver "Sem anexo"
      }
    });
    if (await anexos.carregar()) carregadas.add('anexos');
  }
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico-lanc'), {
      item, tabela: 'FIN.Lancamento', id: idLancamento, nomeRegistro: 'Lançamento', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar(fichaUrl(idLancamento) + '#historico'); }
    });
    if (await historico.carregar()) carregadas.add('historico');
  }
  // ---------- Pendências (P27) ----------
  let quadroPendencias = null;
  function irParaPendencia(codigo) {
    if (codigo === 'SEM_CENTRO') focarCampo('idCentroCusto');
    else if (codigo === 'SEM_PLANO') focarCampo('idPlanoConta');
    else if (codigo === 'SEM_DOCUMENTO') focarCampo('documento');
    else if (codigo === 'SEM_ANEXO') abrirAba($('aba-anexos'));
    else if (codigo === 'VENCIDA') abrirAba($('aba-parcelas'));
    else if (codigo === 'NAO_APTO' && lanc && lanc.ID_PESSOA) sair('/cad/pessoa.html?id=' + encodeURIComponent(lanc.ID_PESSOA));
  }
  function parcelasDaPendencia() {
    const comId = parcelas.filter((p) => p.id && p.situacao !== 'CANCELADA')
      .sort((a, b) => String(a.vencimento).localeCompare(String(b.vencimento)));
    return comId.map((p, i) => ({ id: p.id, numero: i + 1, total: comId.length, vencimento: p.vencimento }));
  }
  function mostrarBloqueio(linhas) {
    const faixa = $('aviso-bloqueio');
    const bloqueiam = (linhas || []).filter((l) => l.SITUACAO === 'ABERTA' && l.BLOQUEIA_BAIXA);
    faixa.hidden = bloqueiam.length === 0;
    faixa.textContent = bloqueiam.length
      ? '🔒 A baixa deste lançamento está bloqueada até resolver: ' + bloqueiam.map((l) => l.DESCRICAO).join('; ') + '.'
      : '';
  }
  function iniciarPendencias() {
    const quadro = $('quadro-pendencias');
    quadro.hidden = false;
    quadroPendencias = Pendencias.criar(quadro, {
      idLancamento, tipo,
      podeIncluir: !!lanc.PODE_PENDENCIA,
      parcelas: parcelasDaPendencia,
      irPara: irParaPendencia,
      aoMudar: mostrarBloqueio
    });
    quadroPendencias.carregar();
  }

  const fichaUrl = (id) => '/fin/lancamento.html?tipo=' + tipo + '&id=' + encodeURIComponent(id) + (voltarValido ? '&voltar=' + encodeURIComponent(voltarValido) : '');

  // ---------- Carga ----------
  async function preencher(l, copia) {
    await Promise.all([seletorPessoa.definir(l.ID_PESSOA), seletorCentro.definir(l.ID_CENTRO_CUSTO),
      seletorPlano.definir(l.ID_PLANO_CONTA), seletorHistorico.definir(l.ID_HISTORICO_PADRAO)]);
    $('historico').value = l.HISTORICO || '';
    $('documento').value = copia ? '' : (l.DOCUMENTO || '');
    $('observacao').value = l.OBSERVACAO || '';
    $('previsao').checked = !!l.PREVISAO;
    $('dtEmissao').value = copia ? hojeIso() : Util.dataIso(l.DT_EMISSAO);
    $('dtCompetencia').value = copia ? '' : Util.dataIso(l.DT_COMPETENCIA).substring(0, 7);
    $('valorTotal').value = Util.moeda(l.VALOR_TOTAL);
    const lista = Array.isArray(l.PARCELAS) ? l.PARCELAS : [];
    parcelas = lista.map((p) => ({
      id: copia ? null : p.id, vencimento: Util.dataIso(p.vencimento), valor: Number(p.valor), idContaPrevista: p.idContaPrevista,
      contaPrevista: p.contaPrevista || '', valorBaixado: copia ? 0 : Number(p.valorBaixado || 0), saldo: copia ? Number(p.valor) : Number(p.saldo || 0),
      situacao: copia ? 'ABERTA' : p.situacao, travada: copia ? false : !!p.travada, fixa: copia ? false : !!p.fixa
    }));
    $('qtdParcelas').value = Math.max(1, parcelas.length);
    const primeira = parcelas.map((p) => p.vencimento).filter(Boolean).sort()[0];
    $('primeiroVencimento').value = primeira || '';
  }

  function atualizarCabecalho() {
    if (!lanc) {
      const titulo = idCopiar ? 'Nova ' + nomeTipo + ' (cópia do nº ' + idCopiar + ')' : 'Nova ' + nomeTipo;
      $('titulo').textContent = titulo;
      document.title = 'SistemaCMJ – ' + titulo;
      $('subtitulo').textContent = idCopiar ? 'Confira as datas e o documento e clique em Gravar.' : 'Preencha os dados e clique em Gravar.';
      return;
    }
    const titulo = (pagar ? 'Conta a pagar' : 'Conta a receber') + ' nº ' + lanc.ID_LANCAMENTO;
    $('titulo').textContent = titulo;
    document.title = 'SistemaCMJ – ' + titulo;
    const vivas = parcelas.filter((p) => p.situacao !== 'CANCELADA');
    const sit = lanc.SITUACAO === 'CANCELADO' ? 'Cancelado'
      : (vivas.length && vivas.every((p) => p.situacao === 'PAGA') ? (pagar ? 'Pago' : 'Recebido')
        : (vivas.some((p) => p.situacao === 'PAGA' || p.situacao === 'PARCIAL') ? 'Parcial' : 'Em aberto'));
    $('subtitulo').textContent = [lanc.PESSOA_NOME, lanc.EMPRESA_NOME, sit, lanc.PREVISAO ? 'previsão' : '',
      lanc.ORIGEM && lanc.ORIGEM !== 'MANUAL' ? 'origem: ' + String(lanc.ORIGEM).toLowerCase() : ''].filter(Boolean).join(' · ');
    const partes = [];
    if (lanc.DT_CRIACAO) partes.push('Incluído em ' + Util.dataHora(lanc.DT_CRIACAO) + (lanc.USUARIO_CRIACAO ? ' por ' + lanc.USUARIO_CRIACAO : ''));
    if (lanc.DT_ALTERACAO) partes.push('Alterado em ' + Util.dataHora(lanc.DT_ALTERACAO) + (lanc.USUARIO_ALTERACAO ? ' por ' + lanc.USUARIO_ALTERACAO : ''));
    if (lanc.ID_LOTE) partes.push('Lote ' + lanc.ID_LOTE);
    if (lanc.CODIGO_ACCESS) partes.push('Nº no Access: ' + lanc.CODIGO_ACCESS);
    $('rodape').textContent = partes.join(' · ');
  }

  function mostrarFaixa() {
    const faixa = $('aviso-situacao');
    faixa.replaceChildren();
    if (!lanc) { faixa.hidden = true; return; }
    if (lanc.NA_LIXEIRA) {
      faixa.append(document.createTextNode('Este lançamento está na lixeira: a ficha abre só para consulta. Para usar de novo, recupere na '));
      const link = Util.el('a', null, 'Lixeira');
      link.href = '/sis/lixeira.html?item=' + item;
      faixa.append(link, document.createTextNode('.'));
    } else if (lanc.SITUACAO === 'CANCELADO') {
      faixa.textContent = 'Lançamento cancelado em ' + Util.dataHora(lanc.DT_CANCELAMENTO) + (lanc.USUARIO_CANCELAMENTO ? ' por ' + lanc.USUARIO_CANCELAMENTO : '')
        + (lanc.MOTIVO_CANCELAMENTO ? '. Motivo: ' + lanc.MOTIVO_CANCELAMENTO : '') + '. A ficha abre só para consulta.';
    } else if (lanc.MES_FECHADO) {
      faixa.textContent = 'O mês deste lançamento está fechado na contabilidade: a ficha abre só para consulta.';
    } else if (lanc.ORIGEM && lanc.ORIGEM !== 'MANUAL' && !lanc.PODE_ALTERAR) {
      faixa.textContent = 'Este lançamento veio de outra rotina (' + String(lanc.ORIGEM).toLowerCase() + '): altere pela tela de origem.';
    } else if (temBaixa && lanc.PODE_ALTERAR) {
      faixa.textContent = 'Este lançamento já tem baixa: o parceiro, o valor total e as parcelas com baixa não mudam. Para mudar, estorne a baixa antes.';
    } else { faixa.hidden = true; return; }
    faixa.hidden = false;
  }

  if (idLancamento || idCopiar) {
    const r = await Api.get('/api/fin/lancamentos/' + (idLancamento || idCopiar));
    if (!(await Mensagens.tratar(r))) { location.href = lista; return; }
    const l = r.dados;
    if (l.TIPO && l.TIPO !== tipo) { location.replace('/fin/lancamento.html?tipo=' + l.TIPO + '&' + (idLancamento ? 'id=' + idLancamento : 'copiar=' + idCopiar)); return; }
    await preencher(l, !!idCopiar);
    if (idLancamento) {
      lanc = l;
      temBaixa = !!l.TEM_BAIXA;
      podeEditar = !!l.PODE_ALTERAR;
      podeBaixar = acoes.has('BAIXAR') && !l.NA_LIXEIRA && l.SITUACAO !== 'CANCELADO' && !l.PREVISAO;
      podeEstornar = acoes.has('ESTORNAR') && !l.NA_LIXEIRA;
      $('tabela-parcelas').classList.toggle('sem-baixa', !podeBaixar);
      $('botao-baixar-marcadas').hidden = !podeBaixar;
      desenharBaixas(Array.isArray(l.BAIXAS) ? l.BAIXAS : []);
      desenharConfirmados(Array.isArray(l.AVISOS_CONFIRMADOS) ? l.AVISOS_CONFIRMADOS : []);
      for (const id of ['aba-baixas', 'aba-anexos', 'aba-historico']) $(id).hidden = false;
      $('botao-excluir').hidden = !l.PODE_EXCLUIR;
      $('botao-cancelar-lanc').hidden = !l.PODE_CANCELAR;
      iniciarPendencias();
    }
  } else {
    $('dtEmissao').value = hojeIso();
    $('primeiroVencimento').value = hojeIso();
    parcelas = [];
    // 04f2d: "+ Contas a pagar/receber" da aba Movimentação do Parceiro já vem com o parceiro
    const idPessoaInicial = parseInt(Util.parametro('idPessoa') || '0', 10) || null;
    if (idPessoaInicial) {
      await seletorPessoa.definir(idPessoaInicial);
      if (seletorPessoa.valor()) await sugerirPadroes(idPessoaInicial);
    }
  }
  $('botao-copiar').hidden = !idLancamento || !acoes.has('INCLUIR') || !!(lanc && lanc.NA_LIXEIRA);
  atualizarCabecalho();
  mostrarFaixa();
  desenharParcelas();

  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) {
    for (const el of $('ficha').querySelectorAll('input, select, textarea, #botao-gerar, #botao-mais-parcela')) el.disabled = true;
    seletores.forEach((s) => s.habilitar(false));
  } else if (temBaixa) {
    seletorPessoa.habilitar(false);
    $('valorTotal').disabled = true;
  }
  $('ficha').addEventListener('input', marcarSujo);
  $('ficha').addEventListener('change', marcarSujo);
  if (idCopiar) sujo = true;
  if (podeEditar && !idLancamento) seletorPessoa.focar();

  // ---------- Gravar (com a janela de avisos do P17) ----------
  function montarCorpo() {
    return {
      idLancamento, tipo,
      idPessoa: seletorPessoa.valor(), idCentroCusto: seletorCentro.valor(), idPlanoConta: seletorPlano.valor(),
      idHistoricoPadrao: seletorHistorico.valor(),
      documento: $('documento').value, historico: $('historico').value, observacao: $('observacao').value,
      dtEmissao: $('dtEmissao').value || null, dtCompetencia: $('dtCompetencia').value || null,
      valorTotal: Util.lerMoeda($('valorTotal').value), previsao: $('previsao').checked,
      integracao: lanc ? lanc.INTEGRACAO : null,
      parcelas: parcelas.map((p) => ({ id: p.id || null, vencimento: p.vencimento || null, valor: typeof p.valor === 'number' ? p.valor : null, idContaPrevista: p.idContaPrevista || null }))
    };
  }

  const CAMPOS_AVISO = { dtEmissao: 'aba-dados', dtCompetencia: 'aba-dados', documento: 'aba-dados', valorTotal: 'aba-dados', historico: 'aba-dados', parcelas: 'aba-parcelas' };
  function focarCampo(campo) {
    if (!campo) return;
    if (CAMPOS_AVISO[campo]) abrirAba($(CAMPOS_AVISO[campo]));
    const mapa = { idPessoa: seletorPessoa, idCentroCusto: seletorCentro, idPlanoConta: seletorPlano };
    if (mapa[campo]) { abrirAba($('aba-dados')); mapa[campo].focar(); return; }
    const el = $(campo);
    if (el && typeof el.focus === 'function') el.focus();
  }

  async function conferirNaTela() {
    const faltas = [
      [!seletorPessoa.valor(), 'Escolha o ' + rotuloParceiro.toLowerCase() + '.', 'idPessoa'],
      [!seletorCentro.valor(), 'Escolha o centro de custo.', 'idCentroCusto'],
      [!seletorPlano.valor(), 'Escolha a conta do plano.', 'idPlanoConta'],
      [!$('dtEmissao').value, 'Informe a data de emissão.', 'dtEmissao'],
      [isNaN(Util.lerMoeda($('valorTotal').value)) || Util.lerMoeda($('valorTotal').value) <= 0, 'Informe o valor total.', 'valorTotal'],
      [!parcelas.length, 'Gere as parcelas (botão "Gerar parcelas") ou inclua pelo menos uma na aba Parcelas.', 'qtdParcelas'],
      [parcelas.some((p) => !p.vencimento || typeof p.valor !== 'number' || p.valor <= 0), 'Toda parcela precisa de vencimento e valor maior que zero.', 'parcelas']
    ].find(([falta]) => falta);
    if (faltas) {
      focarCampo(faltas[2] === 'qtdParcelas' ? null : faltas[2]);
      await Mensagens.alerta(faltas[1], 'ATENCAO');
      if (faltas[2] === 'qtdParcelas') { abrirAba($('aba-dados')); $('qtdParcelas').focus(); } else focarCampo(faltas[2]);
      return false;
    }
    const soma = parcelas.reduce((s, p) => s + centavos(p.valor), 0);
    if (soma !== centavos(Util.lerMoeda($('valorTotal').value))) {
      abrirAba($('aba-parcelas'));
      await Mensagens.alerta('A soma das parcelas (' + Util.moeda(soma / 100) + ') não bate com o valor total (' + $('valorTotal').value + '). Ajuste as parcelas ou gere de novo.', 'ATENCAO');
      return false;
    }
    return true;
  }

  $('ficha').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!podeEditar || !(await conferirNaTela())) return;
    const pergunta = (idLancamento ? 'Confirma a gravação das alterações da ' : 'Confirma a inclusão da ') + nomeTipo + ' de ' + Util.moeda(Util.lerMoeda($('valorTotal').value))
      + ' em ' + parcelas.length + (parcelas.length === 1 ? ' parcela' : ' parcelas') + '?';
    if (!(await Mensagens.confirmar('Gravar?', pergunta, 'Gravar'))) return;
    const corpo = montarCorpo();
    const botao = $('botao-gravar');
    botao.disabled = true;
    try {
      for (let tentativa = 0; tentativa < 3; tentativa++) {
        const r = await Api.post('/api/fin/lancamentos', corpo);
        if (r.sucesso) {
          sujo = false;
          await Mensagens.concluido(r.mensagem || 'Lançamento gravado.');
          const novo = (r.dados && r.dados.id) || idLancamento;
          Util.recarregar(fichaUrl(novo) + (location.hash || ''));
          return;
        }
        const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
        if (!avisos.length) { await Mensagens.tratar(r); return; }
        const resposta = await Mensagens.avisos(avisos, {
          extra: (a) => a.codigo === 'TIPO_PARCEIRO' ? 'Marcar também o parceiro como ' + rotuloParceiro : null
        });
        if (!resposta) { const primeiro = avisos.find((a) => a.campo); if (primeiro) focarCampo(primeiro.campo); return; }
        corpo.avisosConfirmados = [...new Set([...(corpo.avisosConfirmados || []), ...resposta.confirmados])];
        if (resposta.motivo) corpo.motivoRetroativo = resposta.motivo;
        corpo.marcarTipoParceiro = resposta.extras.includes('TIPO_PARCEIRO');
      }
      await Mensagens.alerta('Os avisos mudaram durante a gravação. Confira os dados e grave de novo.', 'ATENCAO');
    } finally {
      botao.disabled = false;
    }
  });

  // ---------- Cancelar / excluir / copiar / sair ----------
  async function semAlteracaoPendente(acao) {
    return !sujo || !podeEditar || Mensagens.confirmar('Há alterações não gravadas', acao + ' não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar');
  }
  $('botao-cancelar-lanc').addEventListener('click', async () => {
    if (!(await semAlteracaoPendente('Cancelar o lançamento'))) return;
    const motivo = await Mensagens.pedirTexto('Cancelar lançamento?',
      'A ' + nomeTipo + ' nº ' + idLancamento + ' será cancelada: sai das contas em aberto e continua na lista (em "Todas"), riscada, com o motivo. Não dá para cancelar lançamento com baixa.',
      { rotulo: 'Motivo', obrigatorio: true, minimo: 5, botao: 'Cancelar lançamento', tipo: 'textarea', dica: 'Por que está cancelando. Obrigatório (pelo menos 5 letras). Fica registrado no lançamento.' });
    if (motivo === null) return;
    const r = await Api.post('/api/fin/lancamentos/' + idLancamento + '/cancelar', { motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Lançamento cancelado.');
    Util.recarregar(fichaUrl(idLancamento));
  });
  $('botao-excluir').addEventListener('click', async () => {
    if (!(await semAlteracaoPendente('Excluir'))) return;
    const motivo = await Mensagens.pedirTexto('Excluir lançamento?',
      'A ' + nomeTipo + ' nº ' + idLancamento + ' vai para a lixeira com as parcelas: some de todas as telas e pode ser recuperada na Lixeira até o prazo acabar; depois é apagada de vez.',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item, tabela: 'FIN.Lancamento', idRegistro: idLancamento, motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Lançamento enviado para a lixeira.');
    location.replace(lista);
  });
  $('botao-copiar').addEventListener('click', () => sair('/fin/lancamento.html?tipo=' + tipo + '&copiar=' + encodeURIComponent(idLancamento)));

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-voltar').addEventListener('click', () => sair(lista));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair(lista); });
  document.addEventListener('keydown', (e) => {
    if (document.querySelector('.janela')) return; // janela de mensagem aberta: ela cuida das teclas
    if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); if (podeEditar) $('ficha').requestSubmit(); }
    else if (e.key === 'Escape' && !document.querySelector('.seletor-lista:not([hidden])')) sair(lista);
  });
  for (const aba of ['parcelas', 'baixas', 'anexos', 'historico']) if (location.hash === '#' + aba && !$('aba-' + aba).hidden) abrirAba($('aba-' + aba));
});
