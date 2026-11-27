/* =============================================================================
   SistemaCMJ - js/fin/lancamentos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04f2a)
   Descrição : Lista das telas Contas a pagar (?tipo=P, FIN_PAGAR) e Contas a
               receber (?tipo=R, FIN_RECEBER). Contadores do topo (vencidas,
               hoje, a vencer, em aberto; clicar filtra), filtros (busca,
               situação, período por vencimento/emissão/competência, empresa,
               parceiro, centro, conta do plano, documento), visão por parcela
               ou por lançamento, ordem, paginação e totais do filtro feitos no
               banco (FIN_Lancamento_Listar / _Resumo), Exportar Excel de todas
               as linhas do filtro, filtros salvos por usuário (★ = abre com a
               tela) e o último filtro lembrado neste navegador.
               04f2b: a linha abre a ficha (fin/lancamento.html) e entra o
               botão "+ Incluir".
               04f2c2: pendências (P27): contadores "Com pendência" e "Minhas
               pendências", filtros Pendência e Tipo de pendência, etiqueta na
               linha com as 3 primeiras ao passar o mouse (+N), vermelha quando
               a previsão já passou, cadeado quando bloqueia a baixa.
               04g3c: na visão por parcela, quem tem BAIXAR marca as parcelas
               em aberto (caixa na 1ª coluna; marca a página no cabeçalho) e
               clica em "Baixar marcadas" (janela js/fin/baixa.js). As marcas
               valem entre as páginas e são limpas ao mudar o filtro.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const tipo = (Util.parametro('tipo') || 'P').toUpperCase() === 'R' ? 'R' : 'P';
  const item = tipo === 'P' ? 'FIN_PAGAR' : 'FIN_RECEBER';
  const pagar = tipo === 'P';
  document.body.dataset.menu = 'fin/lancamentos.html?tipo=' + tipo;
  document.body.dataset.tela = 'fin/lancamentos.html?tipo=' + tipo;
  const nomeTela = pagar ? 'Contas a pagar' : 'Contas a receber';
  document.title = 'SistemaCMJ – ' + nomeTela;

  const { sessao, acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  $('titulo').textContent = nomeTela;
  // caminho acima do título: montado pelo menu (js/layout.js, 04h2)
  $('rotulo-parceiro').textContent = pagar ? 'Fornecedor (parceiro)' : 'Cliente (parceiro)';
  $('coluna-parceiro').textContent = pagar ? 'Fornecedor' : 'Cliente';
  $('coluna-baixado').textContent = pagar ? 'Pago' : 'Recebido';
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  const incluir = $('botao-incluir');
  incluir.href = '/fin/lancamento.html?tipo=' + tipo;
  incluir.hidden = !acoes.has('INCLUIR');
  const lixeira = $('link-lixeira');
  lixeira.href = '/sis/lixeira.html?item=' + item;
  lixeira.hidden = !Layout.acoesDe('sis/lixeira.html').has('VER');

  const campos = {
    texto: $('texto'), situacao: $('situacao'), campoData: $('campo-data'), de: $('de'), ate: $('ate'),
    idEmpresa: $('empresa'), documento: $('documento'), visao: $('visao'), ordem: $('ordem'),
    pendencia: $('pendencia'), pendenciaCodigo: $('pendencia-codigo')
  };
  const corpo = $('linhas');
  const CHAVE_ULTIMO = 'cmj.fin.lista.' + tipo + '.' + ((sessao && sessao.login) || '');
  let parametros = { SITUACAO_INICIAL: 'EM_ABERTO', VISAO_INICIAL: 'PARCELA', DIAS_A_VENCER: 7, POR_PAGINA: 100 };
  let pagina = 1;
  let totalLinhas = 0;
  let pedido = 0;
  let aplicando = false;
  let filtrosSalvos = [];

  const recarregarTudo = () => { if (!aplicando) { pagina = 1; carregar(); carregarResumo(); } };
  const seletorPessoa = Seletor.criar($('seletor-pessoa'), {
    tipo: 'PESSOA', rotulo: $('rotulo-parceiro').textContent, placeholder: '(todos)', aoMudar: recarregarTudo,
    dica: 'Digite parte do nome, do nome fantasia ou o CPF/CNPJ e escolha na lista. Em branco = todos.'
  });
  const seletorCentro = Seletor.criar($('seletor-centro'), {
    tipo: 'CENTRO', rotulo: 'Centro de custo', placeholder: '(todos)', aoMudar: recarregarTudo,
    idEmpresa: () => Number(campos.idEmpresa.value) || null
  });
  const seletorPlano = Seletor.criar($('seletor-plano'), { tipo: 'PLANO', rotulo: 'Conta do plano', placeholder: '(todas)', aoMudar: recarregarTudo });

  // ---------- filtro <-> tela ----------
  function lerFiltro() {
    const f = {};
    for (const [nome, campo] of Object.entries(campos)) f[nome] = campo.value.trim();
    f.idPessoa = seletorPessoa.valor() || '';
    f.idCentroCusto = seletorCentro.valor() || '';
    f.idPlanoConta = seletorPlano.valor() || '';
    return f;
  }

  function filtroInicial() {
    return {
      texto: '', situacao: parametros.SITUACAO_INICIAL === 'TODAS' ? '' : parametros.SITUACAO_INICIAL, campoData: 'VENCIMENTO',
      de: '', ate: '', idEmpresa: '', documento: '', visao: parametros.VISAO_INICIAL, ordem: 'VENCIMENTO',
      idPessoa: '', idCentroCusto: '', idPlanoConta: '', pendencia: '', pendenciaCodigo: ''
    };
  }

  async function aplicarFiltro(f) {
    aplicando = true;
    const base = filtroInicial();
    for (const [nome, campo] of Object.entries(campos)) {
      const valor = f[nome] !== undefined && f[nome] !== null ? String(f[nome]) : base[nome];
      campo.value = valor;
      if (campo.tagName === 'SELECT' && campo.value !== valor) campo.value = base[nome]; // opção que não existe mais
    }
    await Promise.all([
      seletorPessoa.definir(Number(f.idPessoa) || null),
      seletorCentro.definir(Number(f.idCentroCusto) || null),
      seletorPlano.definir(Number(f.idPlanoConta) || null)
    ]);
    aplicando = false;
  }

  function guardarUltimo() {
    try { localStorage.setItem(CHAVE_ULTIMO, JSON.stringify(lerFiltro())); } catch { /* navegador sem armazenamento: só não lembra */ }
  }

  function lerUltimo() {
    try { return JSON.parse(localStorage.getItem(CHAVE_ULTIMO) || 'null'); } catch { return null; }
  }

  function pedidoApi(f, paginaPedida, porPagina) {
    return {
      tipo, visao: f.visao, situacao: f.situacao, campoData: f.campoData, vencDe: f.de, vencAte: f.ate,
      idEmpresa: f.idEmpresa, idPessoa: f.idPessoa, idCentroCusto: f.idCentroCusto, idPlanoConta: f.idPlanoConta,
      documento: f.documento, texto: f.texto, ordem: f.ordem, pagina: paginaPedida, porPagina,
      pendencia: f.pendencia, pendenciaCodigo: f.pendenciaCodigo
    };
  }

  // ---------- contadores ----------
  async function carregarResumo() {
    const f = lerFiltro();
    const r = await Api.get('/api/fin/lancamentos/resumo', {
      tipo, idEmpresa: f.idEmpresa, idPessoa: f.idPessoa, idCentroCusto: f.idCentroCusto, idPlanoConta: f.idPlanoConta
    });
    if (!r.sucesso) return; // a lista já mostra a recusa
    desenharResumo(r.dados || {});
  }

  function desenharResumo(d) {
    const qtd = (n) => (n === 1 ? '1 parcela' : (n || 0) + ' parcelas');
    $('valor-vencidas').textContent = Util.moeda(d.VALOR_VENCIDAS || 0);
    $('qtd-vencidas').textContent = qtd(d.QTD_VENCIDAS);
    $('valor-hoje').textContent = Util.moeda(d.VALOR_HOJE || 0);
    $('qtd-hoje').textContent = qtd(d.QTD_HOJE);
    $('valor-a-vencer').textContent = Util.moeda(d.VALOR_A_VENCER || 0);
    $('qtd-a-vencer').textContent = qtd(d.QTD_A_VENCER);
    $('rotulo-a-vencer').textContent = 'A vencer (' + (d.DIAS_A_VENCER || parametros.DIAS_A_VENCER) + ' dias)';
    $('valor-aberto').textContent = Util.moeda(d.VALOR_EM_ABERTO || 0);
    $('qtd-aberto').textContent = qtd(d.QTD_EM_ABERTO);
    $('qtd-pendencia').textContent = String(d.QTD_COM_PENDENCIA || 0);
    $('qtd-minhas').textContent = String(d.QTD_MINHAS_PENDENCIAS || 0);
    marcarContador();
  }

  function marcarContador() {
    for (const b of document.querySelectorAll('.contador')) {
      const ativo = b.dataset.pendencia
        ? b.dataset.pendencia === campos.pendencia.value
        : !campos.pendencia.value && b.dataset.situacao === campos.situacao.value;
      b.classList.toggle('ativo', ativo);
    }
  }

  // ---------- lista ----------
  const ROTULO_SITUACAO = { ABERTA: 'Aberta', PARCIAL: 'Paga em parte', PAGA: 'Quitada', CANCELADA: 'Cancelada' };
  const textoSituacao = (l) => {
    if (l.SITUACAO === 'PAGA') return pagar ? 'Paga' : 'Recebida';
    if (l.SITUACAO === 'PARCIAL') return pagar ? 'Paga em parte' : 'Recebida em parte';
    if (l.VENCIDA) return 'Vencida há ' + l.DIAS_ATRASO + (l.DIAS_ATRASO === 1 ? ' dia' : ' dias');
    return ROTULO_SITUACAO[l.SITUACAO] || l.SITUACAO;
  };
  const textoParcela = (l) => (l.ID_PARCELA ? (l.NUMERO + '/' + l.QTD_PARCELAS) : (l.QTD_PARCELAS === 1 ? '1 parcela' : l.QTD_PARCELAS + ' parcelas'));
  const textoCentro = (l) => [l.CENTRO_CODIGO, l.CENTRO_DESCRICAO].filter(Boolean).join(' - ');
  const textoPlano = (l) => [l.PLANO_CODIGO, l.PLANO_DESCRICAO].filter(Boolean).join(' - ');

  // Etiqueta das pendências: as 3 primeiras na dica, "+N" para o resto (P27)
  const MAX_DICA_PENDENCIAS = 3;
  function etiquetaPendencias(l) {
    const qtdPend = Number(l.QTD_PENDENCIAS) || 0;
    if (qtdPend === 0) return null;
    const itens = String(l.PENDENCIAS || '').split('; ').filter(Boolean);
    const linhas = itens.slice(0, MAX_DICA_PENDENCIAS).map((t) => '• ' + t);
    if (qtdPend > linhas.length) linhas.push('e mais ' + (qtdPend - linhas.length) + ' (veja na ficha)');
    if (l.PENDENCIA_ATRASADA) linhas.push('A previsão de resolver já passou.');
    if (l.PENDENCIA_BLOQUEIA) linhas.push('Bloqueia a baixa até ser resolvida.');
    const texto = (l.PENDENCIA_BLOQUEIA ? '🔒 ' : '⚠ ') + (qtdPend === 1 ? '1 pendência' : qtdPend + ' pendências');
    const span = Util.el('span', 'etiqueta-pendencia' + (l.PENDENCIA_ATRASADA ? ' atrasada' : ''), texto);
    span.dataset.dica = (qtdPend === 1 ? 'Pendência:' : 'Pendências:') + '\n' + linhas.join('\n');
    return span;
  }

  function celula(texto, sub, classe) {
    const td = Util.el('td', classe || null, texto || '');
    if (sub) td.append(Util.el('span', 'sub', sub));
    return td;
  }

  // ---------- 04g3c: marcar parcelas para baixar ----------
  const podeBaixar = acoes.has('BAIXAR');
  const marcadas = new Map();   // ID_PARCELA -> saldo
  let chaveFiltro = '';
  let linhasNaTela = [];
  const marcavel = (l) => podeBaixar && !!l.ID_PARCELA && !l.PREVISAO && Number(l.SALDO) > 0 && (l.SITUACAO === 'ABERTA' || l.SITUACAO === 'PARCIAL');
  function atualizarMarcadas() {
    const soma = [...marcadas.values()].reduce((s, v) => s + Math.round(Number(v) * 100), 0) / 100;
    $('barra-marcadas').hidden = !marcadas.size;
    $('marcadas-texto').textContent = marcadas.size + (marcadas.size === 1 ? ' parcela marcada' : ' parcelas marcadas') + ' · saldo ' + Util.moeda(soma);
    const daPagina = linhasNaTela.filter(marcavel);
    $('marcar-pagina').checked = daPagina.length > 0 && daPagina.every((l) => marcadas.has(l.ID_PARCELA));
    $('marcar-pagina').disabled = !daPagina.length;
  }
  $('marcar-pagina').addEventListener('change', () => {
    const ligar = $('marcar-pagina').checked;
    for (const l of linhasNaTela.filter(marcavel)) { if (ligar) marcadas.set(l.ID_PARCELA, l.SALDO); else marcadas.delete(l.ID_PARCELA); }
    desenhar(linhasNaTela);
  });
  $('botao-desmarcar').addEventListener('click', () => { marcadas.clear(); desenhar(linhasNaTela); });
  $('botao-baixar').addEventListener('click', async () => {
    if (!marcadas.size) return;
    if (await Baixa.abrir({ parcelas: [...marcadas.keys()] })) {
      marcadas.clear();
      await carregar();
      carregarResumo();
    }
  });

  function desenhar(linhas) {
    linhasNaTela = linhas;
    const comMarcas = podeBaixar && campos.visao.value !== 'LANCAMENTO';
    $('tabela-lancamentos').classList.toggle('sem-marcar', !comMarcas);
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum lançamento encontrado com esses filtros.');
      td.colSpan = 10;
      tr.append(td);
      corpo.append(tr);
    }
    for (const l of linhas) {
      const tr = Util.el('tr', 'clicavel' + (l.VENCIDA ? ' linha-vencida' : '') + (marcadas.has(l.ID_PARCELA) ? ' linha-marcada' : ''));
      const tdMarcar = Util.el('td', 'col-marcar');
      if (comMarcas && marcavel(l)) {
        const marca = Util.el('input');
        marca.type = 'checkbox';
        marca.checked = marcadas.has(l.ID_PARCELA);
        marca.setAttribute('aria-label', 'Marcar a parcela ' + textoParcela(l) + ' de ' + (l.PESSOA_NOME || 'sem parceiro') + ' para baixar');
        marca.dataset.dica = 'Marca a parcela para baixar junto com outras (botão "Baixar marcadas").';
        marca.addEventListener('click', (e) => e.stopPropagation());
        marca.addEventListener('keydown', (e) => e.stopPropagation());
        marca.addEventListener('change', () => {
          if (marca.checked) marcadas.set(l.ID_PARCELA, l.SALDO); else marcadas.delete(l.ID_PARCELA);
          tr.classList.toggle('linha-marcada', marca.checked);
          atualizarMarcadas();
        });
        tdMarcar.append(marca);
        tdMarcar.addEventListener('click', (e) => { e.stopPropagation(); if (e.target === tdMarcar) marca.click(); });
      }
      tr.tabIndex = 0;
      const abrir = () => { location.href = '/fin/lancamento.html?tipo=' + tipo + '&id=' + encodeURIComponent(l.ID_LANCAMENTO); };
      tr.addEventListener('click', abrir);
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(); });
      const sit = Util.el('td');
      const classe = l.VENCIDA ? 'vencida' : String(l.SITUACAO || '').toLowerCase();
      sit.append(Util.el('span', 'situacao situacao-' + classe, textoSituacao(l)));
      if (l.PREVISAO) sit.append(Util.el('span', 'sub', 'previsão'));
      const etiqueta = etiquetaPendencias(l);
      if (etiqueta) { sit.append(Util.el('br'), etiqueta); }
      tr.append(
        tdMarcar,
        celula(Util.data(l.DT_VENCIMENTO), l.ID_PARCELA ? null : 'primeiro em aberto', 'col-vencimento'),
        celula(l.PESSOA_NOME || '(sem parceiro)', l.EMPRESA_NOME, 'forte'),
        celula(l.HISTORICO, [l.DOCUMENTO, 'nº ' + l.ID_LANCAMENTO].filter(Boolean).join(' · ')),
        celula(textoParcela(l)),
        celula(textoCentro(l), textoPlano(l)),
        celula(Util.moeda(l.VALOR), null, 'numero'),
        celula(Util.moeda(l.VALOR_BAIXADO), null, 'numero'),
        celula(Util.moeda(l.SALDO), null, 'numero forte'),
        sit);
      corpo.append(tr);
    }
    atualizarMarcadas();
  }

  function desenharRodape(linhas) {
    const primeira = linhas[0];
    totalLinhas = primeira ? primeira.TOTAL_LINHAS : 0;
    const porPagina = parametros.POR_PAGINA || 100;
    const paginas = Math.max(1, Math.ceil(totalLinhas / porPagina));
    const unidade = campos.visao.value === 'LANCAMENTO' ? ['lançamento', 'lançamentos'] : ['parcela', 'parcelas'];
    $('contagem').textContent = totalLinhas === 1 ? '1 ' + unidade[0] : totalLinhas + ' ' + unidade[1];
    $('totais').hidden = !primeira;
    if (primeira) {
      $('total-valor').textContent = Util.moeda(primeira.TOTAL_VALOR);
      $('total-baixado').textContent = Util.moeda(primeira.TOTAL_BAIXADO);
      $('total-saldo').textContent = Util.moeda(primeira.TOTAL_SALDO);
    }
    $('paginacao').hidden = paginas <= 1;
    $('pagina-texto').textContent = 'Página ' + pagina + ' de ' + paginas;
    $('pagina-anterior').disabled = pagina <= 1;
    $('pagina-proxima').disabled = pagina >= paginas;
  }

  async function carregar() {
    const meu = ++pedido;
    const f = lerFiltro();
    const chave = JSON.stringify({ ...f });
    if (chave !== chaveFiltro) { chaveFiltro = chave; marcadas.clear(); }
    guardarUltimo();
    marcarContador();
    $('contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/fin/lancamentos', pedidoApi(f, pagina, parametros.POR_PAGINA));
    if (meu !== pedido) return; // chegou depois de um pedido mais novo
    if (!(await Mensagens.tratar(r, { foco: campos.texto }))) { $('contagem').textContent = ''; return; }
    const linhas = r.dados || [];
    desenhar(linhas);
    desenharRodape(linhas);
  }

  // ---------- exportar ----------
  $('botao-exportar').addEventListener('click', async () => {
    const f = lerFiltro();
    const todas = [];
    for (let p = 1; p <= 50; p++) {
      const r = await Api.get('/api/fin/lancamentos', pedidoApi(f, p, 1000));
      if (!(await Mensagens.tratar(r))) return;
      const linhas = r.dados || [];
      todas.push(...linhas);
      if (linhas.length < 1000 || todas.length >= (linhas[0] ? linhas[0].TOTAL_LINHAS : 0)) break;
    }
    Util.exportarCsv(pagar ? 'Contas_a_pagar' : 'Contas_a_receber',
      ['Nº', 'Vencimento', pagar ? 'Fornecedor' : 'Cliente', 'Empresa', 'Histórico', 'Documento', 'Parcela', 'Centro de custo', 'Conta do plano',
        'Emissão', 'Competência', 'Valor', pagar ? 'Pago' : 'Recebido', 'Saldo', 'Situação'],
      todas.map((l) => [l.ID_LANCAMENTO, Util.data(l.DT_VENCIMENTO), l.PESSOA_NOME, l.EMPRESA_NOME, l.HISTORICO, l.DOCUMENTO, textoParcela(l),
        textoCentro(l), textoPlano(l), Util.data(l.DT_EMISSAO), Util.data(l.DT_COMPETENCIA).substring(3),
        Util.moeda(l.VALOR), Util.moeda(l.VALOR_BAIXADO), Util.moeda(l.SALDO), textoSituacao(l)]));
  });

  // ---------- filtros salvos ----------
  async function carregarFiltrosSalvos(escolhido) {
    const r = await Api.get('/api/sis/filtros', { item });
    filtrosSalvos = r.sucesso ? (r.dados || []) : [];
    const lista = $('filtro-salvo');
    lista.replaceChildren(Util.el('option', null, '(nenhum)'));
    lista.firstChild.value = '';
    for (const f of filtrosSalvos) {
      const op = Util.el('option', null, (f.PADRAO ? '★ ' : '') + f.NOME);
      op.value = String(f.ID_FILTRO_SALVO);
      lista.append(op);
    }
    lista.value = escolhido ? String(escolhido) : '';
    $('botao-apagar-filtro').hidden = !lista.value;
  }

  $('filtro-salvo').addEventListener('change', async () => {
    const f = filtrosSalvos.find((x) => String(x.ID_FILTRO_SALVO) === $('filtro-salvo').value);
    $('botao-apagar-filtro').hidden = !f;
    if (!f) return;
    let filtro = {};
    try { filtro = JSON.parse(f.FILTRO); } catch { filtro = {}; }
    await aplicarFiltro(filtro);
    recarregarTudo();
  });

  $('botao-salvar-filtro').addEventListener('click', async () => {
    const atual = filtrosSalvos.find((x) => String(x.ID_FILTRO_SALVO) === $('filtro-salvo').value);
    const nome = await Mensagens.pedirTexto('Salvar filtro', 'Dê um nome para os filtros que estão na tela. Com um nome que já existe, o filtro é substituído.',
      { rotulo: 'Nome do filtro', botao: 'Continuar', obrigatorio: true, valor: atual ? atual.NOME : '', dica: 'Ex.: Vencidos da CMJ, Orion do mês.' });
    if (nome === null) return;
    const padrao = await Mensagens.confirmar('Abrir com este filtro?',
      'Quer que a tela ' + nomeTela + ' já abra com o filtro "' + nome.trim() + '"? (Cancelar = salva sem abrir com ele.)', 'Sim, abrir com ele');
    const r = await Api.post('/api/sis/filtros', { item, nome: nome.trim(), filtro: JSON.stringify(lerFiltro()), padrao });
    if (!(await Mensagens.tratar(r))) return;
    await carregarFiltrosSalvos(r.dados && r.dados.id);
    Mensagens.sucesso('Filtro salvo.');
  });

  $('botao-apagar-filtro').addEventListener('click', async () => {
    const f = filtrosSalvos.find((x) => String(x.ID_FILTRO_SALVO) === $('filtro-salvo').value);
    if (!f) return;
    if (!(await Mensagens.confirmar('Apagar filtro?', 'O filtro salvo "' + f.NOME + '" será apagado. Os lançamentos não mudam.', 'Apagar'))) return;
    const r = await Api.post('/api/sis/filtros/' + f.ID_FILTRO_SALVO + '/excluir');
    if (!(await Mensagens.tratar(r))) return;
    await carregarFiltrosSalvos(null);
    Mensagens.sucesso('Filtro apagado.');
  });

  $('botao-limpar').addEventListener('click', async () => {
    $('filtro-salvo').value = '';
    $('botao-apagar-filtro').hidden = true;
    await aplicarFiltro(filtroInicial());
    recarregarTudo();
    campos.texto.focus();
  });

  // ---------- eventos ----------
  for (const b of document.querySelectorAll('.contador')) {
    b.addEventListener('click', () => {
      if (b.dataset.pendencia) {
        // os contadores de pendência contam lançamentos: mostra todas as situações por lançamento
        campos.pendencia.value = b.dataset.pendencia;
        campos.pendenciaCodigo.value = '';
        campos.situacao.value = '';
        campos.visao.value = 'LANCAMENTO';
        pagina = 1;
        carregar();
        return;
      }
      campos.pendencia.value = '';
      campos.pendenciaCodigo.value = '';
      campos.situacao.value = b.dataset.situacao;
      if (campos.campoData.value === 'VENCIMENTO') { campos.de.value = ''; campos.ate.value = ''; }
      pagina = 1;
      carregar();
    });
  }
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); pagina = 1; carregar(); });
  campos.texto.addEventListener('input', Util.atrasar(() => { pagina = 1; carregar(); }, 350));
  campos.documento.addEventListener('input', Util.atrasar(() => { pagina = 1; carregar(); }, 350));
  for (const nome of ['situacao', 'campoData', 'de', 'ate', 'visao', 'ordem', 'pendencia', 'pendenciaCodigo']) {
    campos[nome].addEventListener('change', () => { if (!aplicando) { pagina = 1; carregar(); } });
  }
  campos.idEmpresa.addEventListener('change', recarregarTudo);
  $('pagina-anterior').addEventListener('click', () => { if (pagina > 1) { pagina--; carregar(); } });
  $('pagina-proxima').addEventListener('click', () => { pagina++; carregar(); });

  // ---------- tipos de pendência do filtro ----------
  // Regras automáticas (FIN.fn_FIN_Lancamento_Pendencias; cada uma ligada por parâmetro FIN_PEND_*)
  const REGRAS_AUTOMATICAS = [
    { codigo: 'SEM_CENTRO', nome: 'Sem centro de custo', tipos: 'PR' },
    { codigo: 'SEM_PLANO', nome: 'Sem conta do plano', tipos: 'PR' },
    { codigo: 'SEM_DOCUMENTO', nome: 'Sem número de documento', tipos: 'PR' },
    { codigo: 'SEM_ANEXO', nome: 'Sem anexo (valor alto)', tipos: 'P' },
    { codigo: 'NAO_APTO', nome: 'Cliente não apto para cobrança', tipos: 'R' },
    { codigo: 'VENCIDA', nome: 'Vencida há muito tempo', tipos: 'PR' }
  ];
  function montarTiposPendencia(manuais) {
    const lista = campos.pendenciaCodigo;
    const grupo = (rotulo) => { const g = document.createElement('optgroup'); g.label = rotulo; lista.append(g); return g; };
    const auto = grupo('Automáticas');
    for (const regra of REGRAS_AUTOMATICAS.filter((x) => x.tipos.includes(tipo))) {
      const op = Util.el('option', null, regra.nome);
      op.value = regra.codigo;
      auto.append(op);
    }
    const daTela = manuais.filter((t) => t.ATIVO !== false && (t.APLICA_A === 'A' || t.APLICA_A === tipo));
    if (daTela.length) {
      const man = grupo('Lançadas por alguém');
      for (const t of daTela) {
        const op = Util.el('option', null, t.DESCRICAO);
        op.value = t.CODIGO;
        man.append(op);
      }
    }
  }

  // ---------- abertura ----------
  const [rResumo, rEmpresas, , rTiposPend] = await Promise.all([
    Api.get('/api/fin/lancamentos/resumo', { tipo }),
    Api.get('/api/cad/empresas'),
    carregarFiltrosSalvos(null),
    Api.get('/api/fin/pendencia-tipos', { somenteAtivos: true, tipo })
  ]);
  montarTiposPendencia(rTiposPend && rTiposPend.sucesso ? (rTiposPend.dados || []) : []);
  if (rResumo.sucesso && rResumo.dados) parametros = { ...parametros, ...rResumo.dados };
  if (rEmpresas.sucesso) {
    for (const e of (rEmpresas.dados || []).filter((x) => x.ATIVO !== false)) {
      const op = Util.el('option', null, e.NOME_FANTASIA || e.RAZAO_SOCIAL);
      op.value = String(e.ID_EMPRESA);
      campos.idEmpresa.append(op);
    }
  }

  // ordem: endereço (?situacao=) > filtro salvo com ★ > último filtro deste navegador > parâmetros da tela
  const padrao = filtrosSalvos.find((f) => f.PADRAO);
  let inicial = filtroInicial();
  if (padrao) {
    try { inicial = { ...inicial, ...JSON.parse(padrao.FILTRO) }; } catch { /* filtro estragado: usa o inicial */ }
    $('filtro-salvo').value = String(padrao.ID_FILTRO_SALVO);
    $('botao-apagar-filtro').hidden = false;
  } else {
    const ultimo = lerUltimo();
    if (ultimo) inicial = { ...inicial, ...ultimo };
  }
  for (const nome of ['situacao', 'idPessoa', 'idEmpresa', 'idCentroCusto', 'pendencia', 'visao']) {
    const v = Util.parametro(nome);
    if (v !== null) inicial[nome] = v;
  }
  await aplicarFiltro(inicial);
  if (rResumo.sucesso) desenharResumo(rResumo.dados || {});
  campos.texto.focus();
  await carregar();
  if (inicial.idEmpresa || inicial.idPessoa || inicial.idCentroCusto || inicial.idPlanoConta) carregarResumo();
});
