/* =============================================================================
   SistemaCMJ - js/inicio.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Tela inicial = Agenda financeira (P03, P04; tela FIN_AGENDA).
               Sem VER na agenda, mostra só as boas-vindas.
               - período: semana, quinzena, mês, ano (calendário), bimestre,
                 trimestre e quadrimestre a partir do mês escolhido, vários
                 anos e datas escolhidas; setas ◀ ▶ e Hoje;
               - barra D / C / Saldo (D vermelho, C azul, S pelo sinal),
                 saldo previsto no fim do período e quadro "Em atraso";
                 sem VER_TOTAIS os valores somados não vêm (P04);
               - atalhos rápidos só para quem tem a permissão;
               - lista agrupada por dia (hoje em destaque), subtotal D/C/S e
                 saldo previsto de cada dia; a linha abre o lançamento e o
                 Voltar da ficha devolve aqui, no mesmo ponto;
               - lembra o último período usado neste computador; no primeiro
                 acesso do dia vale a preferência do usuário (sugestão
                 aprovada na 04h2);
               - atualiza sozinha a cada AGENDA_ATUALIZAR_MIN minutos
                 (0 = não atualiza; sugestão aprovada na 04h2).
               - visão Lista ou Calendário (04h3; js/agenda-calendario.js):
                 dia a dia na semana, quinzena e mês; um quadro por mês do
                 bimestre ao ano; faixas por ano em vários anos; a escolha
                 fica lembrada neste computador.
   Changelog:
     v2.0 (27/11/2026) - Agenda financeira (etapa 04h2).
     v2.1 (27/11/2026) - Visão calendário da semana, quinzena e mês (04h3a);
                         quadros por mês e faixas por ano (04h3b).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao, acoes } = await Layout.iniciar();
  if (!sessao) return;
  const $ = (id) => document.getElementById(id);
  const primeiroNome = (sessao.nome || sessao.login).split(' ')[0];

  if (!acoes.has('VER')) {
    $('titulo').textContent = 'Bem-vindo, ' + primeiroNome;
    $('sem-agenda').hidden = false;
    return;
  }
  $('boas-vindas').textContent = 'Bem-vindo, ' + primeiroNome;
  $('titulo').textContent = 'Agenda financeira';
  document.title = document.title.replace('Início', 'Agenda financeira');
  $('agenda').hidden = false;
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');

  const CHAVE_ESTADO = 'cmj.inicio.estado';   // localStorage: último período neste computador
  const CHAVE_VOLTA = 'cmj.inicio.volta';     // sessionStorage: página, atraso e rolagem ao abrir um lançamento
  const MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  const DIAS = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
  const MESES_GRUPO = { BIMESTRE: 2, TRIMESTRE: 3, QUADRIMESTRE: 4 };

  // ---------- datas (sempre em horário local, sem fuso) ----------
  const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  const lerIso = (t) => { const [a, m, d] = String(t).substring(0, 10).split('-').map(Number); return new Date(a, m - 1, d); };
  const hoje = () => { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), d.getDate()); };
  const somarDias = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  const inicioMes = (d, n = 0) => new Date(d.getFullYear(), d.getMonth() + n, 1);
  const fimMes = (d, n = 0) => new Date(d.getFullYear(), d.getMonth() + n + 1, 0);
  const curta = (d) => String(d.getDate()).padStart(2, '0') + '/' + String(d.getMonth() + 1).padStart(2, '0');
  const longa = (d) => curta(d) + '/' + d.getFullYear();
  const mesAno = (d) => MESES[d.getMonth()].substring(0, 3) + '/' + d.getFullYear();

  // ---------- estado ----------
  let estado = { visao: 'LISTA', periodo: 'MES', ref: iso(hoje()), anos: 2, de: '', ate: '', tipo: '', texto: '' };
  let soAtraso = false;
  let pagina = 1;
  let resumo = null;        // última resposta do resumo
  let pedido = 0;
  let rolagemVolta = null;

  async function estadoInicial() {
    let guardado = null;
    try { guardado = JSON.parse(localStorage.getItem(CHAVE_ESTADO) || 'null'); } catch { guardado = null; }
    let volta = null;
    try { volta = JSON.parse(sessionStorage.getItem(CHAVE_VOLTA) || 'null'); sessionStorage.removeItem(CHAVE_VOLTA); } catch { volta = null; }

    if (guardado && (guardado.dia === iso(hoje()) || volta)) {
      estado = { ...estado, ...guardado };
    } else {
      // Primeiro acesso do dia neste computador: vale a preferência do usuário.
      const r = await Api.get('/api/sis/preferencias', { grupo: 'Tela inicial' });
      if (r.sucesso) {
        const pref = Object.fromEntries((r.dados || []).map((p) => [p.CODIGO, p.VALOR]));
        if (pref.INICIO_PERIODO) estado.periodo = pref.INICIO_PERIODO;
        if (pref.INICIO_ANOS) estado.anos = parseInt(pref.INICIO_ANOS, 10) || 2;
      }
      estado.ref = iso(hoje());
    }
    if (volta) {
      soAtraso = !!volta.soAtraso;
      pagina = volta.pagina || 1;
      rolagemVolta = volta.rolagem ?? null;
    }
  }

  function guardarEstado() {
    try { localStorage.setItem(CHAVE_ESTADO, JSON.stringify({ ...estado, dia: iso(hoje()) })); } catch { /* sem armazenamento: só não lembra */ }
  }

  // ---------- cálculo do período ----------
  function intervalo() {
    const ref = lerIso(estado.ref);
    switch (estado.periodo) {
      case 'SEMANA': {
        const ini = somarDias(ref, -((ref.getDay() + 6) % 7)); // segunda-feira
        return [ini, somarDias(ini, 6)];
      }
      case 'QUINZENA':
        return ref.getDate() <= 15
          ? [new Date(ref.getFullYear(), ref.getMonth(), 1), new Date(ref.getFullYear(), ref.getMonth(), 15)]
          : [new Date(ref.getFullYear(), ref.getMonth(), 16), fimMes(ref)];
      case 'BIMESTRE': case 'TRIMESTRE': case 'QUADRIMESTRE':
        return [inicioMes(ref), fimMes(ref, MESES_GRUPO[estado.periodo] - 1)];
      case 'ANO':
        return [new Date(ref.getFullYear(), 0, 1), new Date(ref.getFullYear(), 11, 31)];
      case 'ANOS':
        return [new Date(ref.getFullYear(), 0, 1), new Date(ref.getFullYear() + estado.anos - 1, 11, 31)];
      case 'LIVRE':
        return estado.de && estado.ate ? [lerIso(estado.de), lerIso(estado.ate)] : [null, null];
      default:
        return [inicioMes(ref), fimMes(ref)];
    }
  }

  function andar(sentido) {
    const ref = lerIso(estado.ref);
    let nova;
    switch (estado.periodo) {
      case 'SEMANA': nova = somarDias(ref, 7 * sentido); break;
      case 'QUINZENA':
        if (ref.getDate() <= 15) nova = sentido > 0 ? new Date(ref.getFullYear(), ref.getMonth(), 16) : new Date(ref.getFullYear(), ref.getMonth() - 1, 16);
        else nova = sentido > 0 ? inicioMes(ref, 1) : new Date(ref.getFullYear(), ref.getMonth(), 1);
        break;
      case 'BIMESTRE': case 'TRIMESTRE': case 'QUADRIMESTRE': nova = inicioMes(ref, MESES_GRUPO[estado.periodo] * sentido); break;
      case 'ANO': nova = new Date(ref.getFullYear() + sentido, 0, 1); break;
      case 'ANOS': nova = new Date(ref.getFullYear() + estado.anos * sentido, 0, 1); break;
      case 'LIVRE': return;
      default: nova = inicioMes(ref, sentido);
    }
    estado.ref = iso(nova);
    mudouPeriodo();
  }

  function textoPeriodo([ini, fim]) {
    if (!ini || !fim) return 'Escolha as datas';
    switch (estado.periodo) {
      case 'MES': return MESES[ini.getMonth()] + ' de ' + ini.getFullYear();
      case 'BIMESTRE': case 'TRIMESTRE': case 'QUADRIMESTRE': return mesAno(ini) + ' a ' + mesAno(fim);
      case 'ANO': return String(ini.getFullYear());
      case 'ANOS': return ini.getFullYear() + ' a ' + fim.getFullYear();
      default: return (ini.getFullYear() === fim.getFullYear() ? curta(ini) : longa(ini)) + ' a ' + longa(fim);
    }
  }

  // ---------- campos do período ----------
  const campos = { periodo: $('periodo'), anos: $('anos'), de: $('de'), ate: $('ate'), tipo: $('tipo'), texto: $('texto') };

  function mostrarCampos() {
    campos.periodo.value = estado.periodo;
    campos.anos.value = estado.anos;
    campos.tipo.value = estado.tipo;
    campos.texto.value = estado.texto;
    const livre = estado.periodo === 'LIVRE';
    $('campo-anos').hidden = estado.periodo !== 'ANOS';
    $('campo-de').hidden = !livre;
    $('campo-ate').hidden = !livre;
    $('periodo-anterior').hidden = livre;
    $('periodo-proximo').hidden = livre;
    if (livre) {
      if (!estado.de || !estado.ate) {
        const [i, f] = [inicioMes(hoje()), fimMes(hoje())];
        estado.de = estado.de || iso(i);
        estado.ate = estado.ate || iso(f);
      }
      campos.de.value = estado.de;
      campos.ate.value = estado.ate;
    }
    $('periodo-texto').textContent = textoPeriodo(intervalo());
    const cal = estado.visao === 'CALENDARIO';
    $('visao-lista').setAttribute('aria-pressed', String(!cal));
    $('visao-calendario').setAttribute('aria-pressed', String(cal));
    $('campo-texto').hidden = cal;
  }

  // ---------- Lista ou Calendário ----------
  function trocarVisao(visao) {
    if (estado.visao === visao) return;
    estado.visao = visao;
    soAtraso = false;
    pagina = 1;
    guardarEstado();
    mostrarCampos();
    carregarCorpo();
  }
  $('visao-lista').addEventListener('click', () => trocarVisao('LISTA'));
  $('visao-calendario').addEventListener('click', () => trocarVisao('CALENDARIO'));

  function mudouPeriodo() {
    pagina = 1;
    soAtraso = false;
    guardarEstado();
    mostrarCampos();
    carregarTudo();
  }

  campos.periodo.addEventListener('change', () => {
    const anterior = estado.periodo;
    const [i, f] = intervalo(); // período que estava na tela
    estado.periodo = campos.periodo.value;
    // Ao sair de "datas escolhidas", o período começa no "de" que estava na tela;
    // ao entrar, as datas começam iguais ao período que estava na tela.
    if (anterior === 'LIVRE' && estado.de) estado.ref = estado.de;
    if (estado.periodo === 'LIVRE' && i && f) { estado.de = iso(i); estado.ate = iso(f); }
    mudouPeriodo();
  });
  campos.anos.addEventListener('change', () => {
    const n = parseInt(campos.anos.value, 10);
    estado.anos = Math.min(10, Math.max(2, Number.isFinite(n) ? n : 2));
    mudouPeriodo();
  });
  for (const c of [campos.de, campos.ate]) {
    c.addEventListener('change', async () => {
      if (!campos.de.value || !campos.ate.value) return;
      if (campos.ate.value < campos.de.value) {
        await Mensagens.alerta('A data final não pode ser antes da inicial.');
        c.focus();
        return;
      }
      estado.de = campos.de.value;
      estado.ate = campos.ate.value;
      mudouPeriodo();
    });
  }
  campos.tipo.addEventListener('change', () => { estado.tipo = campos.tipo.value; pagina = 1; guardarEstado(); carregarTudo(); });
  campos.texto.addEventListener('input', Util.atrasar(() => { estado.texto = campos.texto.value.trim(); pagina = 1; guardarEstado(); carregarLista(); }, 400));
  $('form-periodo').addEventListener('submit', (e) => e.preventDefault());
  $('periodo-anterior').addEventListener('click', () => andar(-1));
  $('periodo-proximo').addEventListener('click', () => andar(1));
  $('periodo-hoje').addEventListener('click', () => {
    if (estado.periodo === 'LIVRE') estado.periodo = 'MES';
    estado.ref = iso(hoje());
    mudouPeriodo();
  });
  document.addEventListener('keydown', (e) => {
    if (document.querySelector('.janela')) return;
    const campo = e.target.closest && e.target.closest('input, select, textarea');
    if (e.key === 'Escape' && soAtraso) { sairAtraso(); return; }
    if (campo || e.ctrlKey || e.altKey) return;
    if (e.key === 'ArrowLeft' && estado.periodo !== 'LIVRE') { e.preventDefault(); andar(-1); }
    if (e.key === 'ArrowRight' && estado.periodo !== 'LIVRE') { e.preventDefault(); andar(1); }
  });

  // ---------- "Em atraso" ----------
  $('quadro-atraso').addEventListener('click', () => {
    soAtraso = !soAtraso;
    pagina = 1;
    carregarCorpo();
  });
  function sairAtraso() { soAtraso = false; pagina = 1; carregarCorpo(); }
  $('botao-sair-atraso').addEventListener('click', sairAtraso);

  // ---------- pedidos à API ----------
  function base() {
    const [ini, fim] = intervalo();
    return { de: ini ? iso(ini) : '', ate: fim ? iso(fim) : '' };
  }

  async function carregarResumo() {
    const p = base();
    if (!p.de || !p.ate) return false;
    const r = await Api.get('/api/fin/agenda/resumo', p);
    if (!(await Mensagens.tratar(r))) return false;
    resumo = r.dados || {};
    desenharResumo(resumo);
    return true;
  }

  const textoValor = (v) => (v === null || v === undefined ? '—' : Util.moeda(v));
  const classeSinal = (v) => (v === null || v === undefined ? '' : (Number(v) < 0 ? ' valor-d' : ' valor-c'));
  const qtdTexto = (n, um, varios) => (Number(n) === 1 ? '1 ' + um : (Number(n) || 0) + ' ' + varios);

  function desenharResumo(d) {
    const semTotais = !d.VER_TOTAIS;
    const dicaSem = 'Você vê as contas uma a uma, mas não os totais somados (permissão "Ver totais" da agenda).';
    $('quadro-d').hidden = !d.VER_PAGAR;
    $('quadro-c').hidden = !d.VER_RECEBER;
    $('quadro-s').hidden = !(d.VER_PAGAR && d.VER_RECEBER);
    $('campo-tipo').hidden = !(d.VER_PAGAR && d.VER_RECEBER);

    $('valor-d').textContent = textoValor(d.TOTAL_D);
    $('qtd-d').textContent = qtdTexto(d.QTD_PAGAR, 'parcela', 'parcelas') + (d.INCLUI_REALIZADO && d.REALIZADO_D != null ? ' · pago ' + Util.moeda(d.REALIZADO_D) : '');
    $('valor-c').textContent = textoValor(d.TOTAL_C);
    $('qtd-c').textContent = qtdTexto(d.QTD_RECEBER, 'parcela', 'parcelas') + (d.INCLUI_REALIZADO && d.REALIZADO_C != null ? ' · recebido ' + Util.moeda(d.REALIZADO_C) : '');
    $('valor-s').textContent = textoValor(d.SALDO);
    $('valor-s').className = 'contador-valor' + classeSinal(d.SALDO);
    $('qtd-s').textContent = d.QTD_PREVISAO ? qtdTexto(d.QTD_PREVISAO, 'previsão', 'previsões') + ' no período' : 'C − D';

    $('quadro-previsto').hidden = !d.SALDO_ACUMULADO;
    if (d.SALDO_ACUMULADO) {
      $('valor-previsto').textContent = d.SALDO_PREVISTO_FIM == null ? 'período já passou' : Util.moeda(d.SALDO_PREVISTO_FIM);
      $('valor-previsto').className = 'contador-valor' + classeSinal(d.SALDO_PREVISTO_FIM);
      $('qtd-previsto').textContent = 'hoje nas contas: ' + textoValor(d.SALDO_CONTAS_HOJE);
    }

    const qtdAtraso = (d.VER_PAGAR ? d.ATRASO_QTD_PAGAR : 0) + (d.VER_RECEBER ? d.ATRASO_QTD_RECEBER : 0);
    const partes = [];
    if (d.VER_PAGAR) partes.push('D ' + textoValor(d.ATRASO_D));
    if (d.VER_RECEBER) partes.push('C ' + textoValor(d.ATRASO_C));
    $('valor-atraso').textContent = semTotais ? String(qtdAtraso) : partes.join(' · ');
    $('qtd-atraso').textContent = semTotais ? (qtdAtraso === 1 ? 'parcela' : 'parcelas')
      : [d.VER_PAGAR ? qtdTexto(d.ATRASO_QTD_PAGAR, 'a pagar', 'a pagar') : '', d.VER_RECEBER ? qtdTexto(d.ATRASO_QTD_RECEBER, 'a receber', 'a receber') : ''].filter(Boolean).join(' · ');
    $('quadro-atraso').hidden = qtdAtraso === 0 && !soAtraso;

    for (const id of ['quadro-d', 'quadro-c', 'quadro-s', 'quadro-previsto']) $(id).classList.toggle('sem-totais', semTotais);
    if (semTotais) for (const id of ['quadro-d', 'quadro-c', 'quadro-s']) $(id).dataset.dica = dicaSem;

    // Atalhos rápidos: só os que a pessoa pode usar.
    const atalhos = { 'atalho-pagar': d.PODE_INCLUIR_PAGAR, 'atalho-receber': d.PODE_INCLUIR_RECEBER, 'atalho-extrato': d.PODE_EXTRATO, 'atalho-caixa': d.PODE_CAIXA, 'atalho-transferir': d.PODE_TRANSFERIR };
    for (const [id, pode] of Object.entries(atalhos)) $(id).hidden = !pode;
    $('atalhos').hidden = !Object.values(atalhos).some(Boolean);
  }

  function pedidoLista(paginaPedida, porPagina) {
    const p = soAtraso ? {} : base();
    return { ...p, soAtraso: soAtraso ? 'true' : '', tipo: estado.tipo, texto: estado.texto, pagina: paginaPedida, porPagina };
  }

  // ---------- lista ----------
  const corpo = $('linhas');
  let totalLinhas = 0;
  let porPaginaAtual = 100;

  const textoParcela = (l) => (l.QTD_PARCELAS > 1 ? l.NUMERO + '/' + l.QTD_PARCELAS : 'única');
  function textoSituacao(l) {
    if (l.PROJECAO) return 'Projeção';
    if (l.VENCIDA) return l.DIAS_ATRASO === 1 ? 'Vencida há 1 dia' : 'Vencida há ' + l.DIAS_ATRASO + ' dias';
    const pagar = l.TIPO === 'P';
    switch (l.SITUACAO) {
      case 'PARCIAL': return pagar ? 'Paga em parte' : 'Recebida em parte';
      case 'PAGA': return pagar ? 'Paga' : 'Recebida';
      default: return lerIso(l.DT_VENCIMENTO).getTime() === hoje().getTime() ? 'Vence hoje' : 'Em aberto';
    }
  }
  function celula(texto, sub, classe) {
    const td = Util.el('td', classe || null, texto || '');
    if (sub) td.append(Util.el('span', 'sub', sub));
    return td;
  }

  function linhaDia(dataIso, totalDia) {
    const d = lerIso(dataIso);
    const ehHoje = d.getTime() === hoje().getTime();
    const tr = Util.el('tr', 'linha-dia' + (ehHoje ? ' dia-hoje' : '') + (d < hoje() ? ' dia-passado' : ''));
    const td = Util.el('td');
    td.colSpan = 7;
    const titulo = Util.el('span', 'dia-titulo', DIAS[d.getDay()] + ', ' + longa(d));
    if (ehHoje) titulo.append(Util.el('span', 'etiqueta-hoje', 'Hoje'));
    td.append(titulo);
    if (totalDia && resumo && resumo.VER_TOTAIS) {
      const tot = Util.el('span', 'dia-totais');
      if (resumo.VER_PAGAR) tot.append(Util.el('span', 'valor-d', 'D ' + Util.moeda(totalDia.TOTAL_D)));
      if (resumo.VER_RECEBER) tot.append(Util.el('span', 'valor-c', 'C ' + Util.moeda(totalDia.TOTAL_C)));
      if (resumo.VER_PAGAR && resumo.VER_RECEBER) tot.append(Util.el('span', classeSinal(totalDia.SALDO).trim(), 'S ' + Util.moeda(totalDia.SALDO)));
      if (resumo.SALDO_ACUMULADO && totalDia.SALDO_PREVISTO != null) {
        const prev = Util.el('span', 'dia-previsto' + classeSinal(totalDia.SALDO_PREVISTO), 'Saldo previsto ' + Util.moeda(totalDia.SALDO_PREVISTO));
        prev.dataset.dica = 'Saldo de hoje nas contas mais o que está em aberto de hoje até este dia.';
        tot.append(prev);
      }
      td.append(tot);
    }
    tr.append(td);
    return tr;
  }

  function abrirLancamento(l) {
    try {
      sessionStorage.setItem(CHAVE_VOLTA, JSON.stringify({ pagina, soAtraso, rolagem: window.scrollY }));
    } catch { /* sem armazenamento: volta para o começo da lista */ }
    guardarEstado();
    location.href = '/fin/lancamento.html?tipo=' + l.TIPO + '&id=' + encodeURIComponent(l.ID_LANCAMENTO) + '&voltar=%2F';
  }

  function desenhar(linhas, totaisDia) {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', soAtraso ? 'Nada em atraso. 🎉' : 'Nenhuma conta em aberto neste período.');
      td.colSpan = 7;
      tr.append(td);
      corpo.append(tr);
      return;
    }
    let diaAtual = '';
    for (const l of linhas) {
      const dia = Util.dataIso(l.DT_VENCIMENTO);
      if (dia !== diaAtual) { diaAtual = dia; corpo.append(linhaDia(dia, totaisDia.get(dia))); }
      const tr = Util.el('tr', 'clicavel' + (l.VENCIDA ? ' linha-vencida' : '') + (l.PREVISAO ? ' linha-previsao' : '') + (l.PROJECAO ? ' linha-projecao' : ''));
      tr.tabIndex = 0;
      tr.dataset.dica = 'Abre o lançamento nº ' + l.ID_LANCAMENTO + '. O Voltar da ficha traz de volta para a agenda.';
      tr.addEventListener('click', () => abrirLancamento(l));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrirLancamento(l); });
      const pagar = l.TIPO === 'P';
      const tipo = Util.el('td');
      tipo.append(Util.el('span', 'tipo-agenda ' + (pagar ? 'tipo-p' : 'tipo-r'), pagar ? 'Pagar' : 'Receber'));
      const valor = celula(Util.moeda(l.VALOR_AGENDA), Number(l.VALOR) !== Number(l.VALOR_AGENDA) ? 'de ' + Util.moeda(l.VALOR) : null, 'numero forte ' + (pagar ? 'valor-d' : 'valor-c'));
      const sit = Util.el('td');
      const classe = l.VENCIDA ? 'vencida' : String(l.SITUACAO || '').toLowerCase();
      sit.append(Util.el('span', 'situacao situacao-' + classe, textoSituacao(l)));
      if (l.PREVISAO) sit.append(Util.el('span', 'sub', 'previsão'));
      tr.append(
        tipo,
        celula(l.PESSOA_NOME || '(sem parceiro)', l.EMPRESA_NOME, 'forte'),
        celula(l.HISTORICO, [l.DOCUMENTO, 'nº ' + l.ID_LANCAMENTO].filter(Boolean).join(' · ')),
        celula(textoParcela(l)),
        celula(l.CENTRO_CODIGO ? l.CENTRO_CODIGO + ' – ' + l.CENTRO_DESCRICAO : ''),
        valor,
        sit);
      corpo.append(tr);
    }
  }

  async function totaisDosDias(linhas) {
    const mapa = new Map();
    if (soAtraso || !linhas.length || !resumo || !resumo.VER_TOTAIS) return mapa;
    const de = Util.dataIso(linhas[0].DT_VENCIMENTO);
    const ate = Util.dataIso(linhas[linhas.length - 1].DT_VENCIMENTO);
    const r = await Api.get('/api/fin/agenda/periodos', { de, ate, agrupamento: 'DIA' });
    if (r.sucesso) for (const p of r.dados || []) mapa.set(Util.dataIso(p.INICIO), p);
    return mapa;
  }

  function desenharRodape(linhas) {
    const primeira = linhas[0];
    totalLinhas = primeira ? primeira.TOTAL_LINHAS : 0;
    porPaginaAtual = primeira ? primeira.POR_PAGINA : porPaginaAtual;
    const paginas = Math.max(1, Math.ceil(totalLinhas / porPaginaAtual));
    $('contagem').textContent = totalLinhas === 1 ? '1 parcela' : totalLinhas + ' parcelas';
    $('paginacao').hidden = paginas <= 1;
    $('pagina-texto').textContent = 'Página ' + pagina + ' de ' + paginas;
    $('pagina-anterior').disabled = pagina <= 1;
    $('pagina-proxima').disabled = pagina >= paginas;
    $('atualizada').textContent = 'Atualizada às ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  }

  /** Qual área aparece: o atraso é sempre em lista. */
  function mostrarArea() {
    const cal = estado.visao === 'CALENDARIO' && !soAtraso;
    $('cartao-calendario').hidden = !cal;
    $('cartao-lista').hidden = cal;
    $('barra-atraso').hidden = !soAtraso;
    $('quadro-atraso').classList.toggle('ativo', soAtraso);
    return cal;
  }

  // ---------- calendário ----------
  /** Como agrupar os quadros do período: dia a dia, por mês ou por grupo de meses. */
  function agrupamento() {
    switch (estado.periodo) {
      case 'SEMANA': case 'QUINZENA': case 'MES': return { modo: 'DIA', meses: null };
      case 'LIVRE': {
        const [i, f] = intervalo();
        const dias = i && f ? Math.round((f - i) / 86400000) + 1 : 0;
        return { modo: dias <= 62 ? 'DIA' : 'MES', meses: null };
      }
      default: return { modo: 'MES', meses: null }; // bimestre a vários anos: um quadro por mês
    }
  }

  async function carregarCalendario() {
    const meu = ++pedido;
    const [ini, fim] = intervalo();
    if (!ini || !fim) return;
    const ag = agrupamento();
    $('contagem-calendario').textContent = 'Buscando…';
    const r = await Api.get('/api/fin/agenda/periodos', { de: iso(ini), ate: iso(fim), agrupamento: ag.modo, mesesGrupo: ag.meses || '' });
    if (meu !== pedido) return;
    if (!(await Mensagens.tratar(r))) { $('contagem-calendario').textContent = ''; return; }
    const quadros = r.dados || [];
    AgendaCalendario.desenhar($('calendario'), { quadros, modo: ag.modo, ini: iso(ini), fim: iso(fim), resumo: resumo || {}, tipo: estado.tipo, anos: estado.periodo === 'ANOS' });
    const qp = resumo && resumo.VER_PAGAR && estado.tipo !== 'R' ? quadros.reduce((t, q) => t + (Number(q.QTD_PAGAR) || 0), 0) : 0;
    const qr = resumo && resumo.VER_RECEBER && estado.tipo !== 'P' ? quadros.reduce((t, q) => t + (Number(q.QTD_RECEBER) || 0), 0) : 0;
    $('contagem-calendario').textContent = qtdTexto(qp + qr, 'parcela', 'parcelas') + ' no período';
    $('atualizada-calendario').textContent = 'Atualizada às ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  }

  function carregarCorpo() {
    return mostrarArea() ? carregarCalendario() : carregarLista();
  }

  async function carregarLista() {
    mostrarArea();
    const meu = ++pedido;
    $('contagem').textContent = 'Buscando…';
    const p = pedidoLista(pagina);
    if (!soAtraso && (!p.de || !p.ate)) { $('contagem').textContent = ''; return; }
    const r = await Api.get('/api/fin/agenda/lista', p);
    if (meu !== pedido) return; // chegou depois de um pedido mais novo
    if (!(await Mensagens.tratar(r, { foco: campos.texto }))) { $('contagem').textContent = ''; return; }
    const linhas = r.dados || [];
    const totaisDia = await totaisDosDias(linhas);
    if (meu !== pedido) return;
    desenhar(linhas, totaisDia);
    desenharRodape(linhas);
    if (rolagemVolta !== null) { const y = rolagemVolta; rolagemVolta = null; requestAnimationFrame(() => window.scrollTo(0, y)); }
  }

  async function carregarTudo() {
    if (await carregarResumo()) await carregarCorpo();
  }

  $('pagina-anterior').addEventListener('click', () => { if (pagina > 1) { pagina--; carregarLista(); } });
  $('pagina-proxima').addEventListener('click', () => { pagina++; carregarLista(); });

  // ---------- exportar ----------
  $('botao-exportar').addEventListener('click', async () => {
    const todas = [];
    for (let p = 1; p <= 50; p++) {
      const r = await Api.get('/api/fin/agenda/lista', pedidoLista(p, 1000));
      if (!(await Mensagens.tratar(r))) return;
      const linhas = r.dados || [];
      todas.push(...linhas);
      if (linhas.length < 1000 || todas.length >= (linhas[0] ? linhas[0].TOTAL_LINHAS : 0)) break;
    }
    Util.exportarCsv(soAtraso ? 'Agenda_em_atraso' : 'Agenda_financeira',
      ['Vencimento', 'Tipo', 'Nº', 'Parceiro', 'Empresa', 'Histórico', 'Documento', 'Parcela', 'Centro de custo', 'Valor da parcela', 'Valor na agenda', 'Situação'],
      todas.map((l) => [Util.data(l.DT_VENCIMENTO), l.TIPO === 'P' ? 'Pagar' : 'Receber', l.ID_LANCAMENTO, l.PESSOA_NOME, l.EMPRESA_NOME, l.HISTORICO, l.DOCUMENTO,
        textoParcela(l), l.CENTRO_CODIGO ? l.CENTRO_CODIGO + ' – ' + l.CENTRO_DESCRICAO : '', Util.moeda(l.VALOR), Util.moeda(l.VALOR_AGENDA), textoSituacao(l)]));
  });

  // ---------- começo ----------
  await estadoInicial();
  mostrarCampos();
  guardarEstado();
  await carregarTudo();

  // Atualiza sozinha (AGENDA_ATUALIZAR_MIN; 0 = não). Não atualiza com janela aberta nem com a aba escondida.
  const minutos = resumo ? Number(resumo.ATUALIZAR_MINUTOS) || 0 : 0;
  if (minutos > 0) {
    setInterval(() => {
      if (document.hidden || document.querySelector('.janela')) return;
      carregarTudo();
    }, minutos * 60000);
  }
});
