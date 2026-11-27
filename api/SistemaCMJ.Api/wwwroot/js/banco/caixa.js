/* =============================================================================
   SistemaCMJ - js/banco/caixa.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04g4c)
   Descrição : Tela Bancos › Fechamento de caixa (BANCO_CAIXA).
               Fechar (ação INCLUIR): escolhe o caixa (contas dos tipos de
               FIN_CAIXA_FECHAMENTO_TIPOS, pela lista de saldos) e a data;
               a prévia (POST /api/banco/caixa/conferir sem o contado) mostra
               o último fechamento, entradas e saídas desde então e o saldo do
               sistema. Saldo contado digitado ou pela contagem de cédulas e
               moedas (sugestão aprovada em 27/11/2026; a contagem vai para a
               observação do fechamento); diferença na hora; com diferença,
               motivo obrigatório e "Lançar o ajuste" (só com AJUSTE_CAIXA).
               "Gravar?" › avisos pelo Mensagens.avisos › "Concluído".
               Histórico (GET /api/banco/caixa) com Reabrir no último
               fechamento de cada caixa (REABRIR + motivo; prévia diz o
               ajuste que será desfeito). Endereço: ?conta=ID.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeFechar = acoes.has('INCLUIR');
  const podeReabrir = acoes.has('REABRIR');
  const FACES = [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.25, 0.1, 0.05];
  let caixas = [];
  let previa = null;     // { saldoSistema, podeAjuste, ... }
  let lista = [];
  let sujo = false;

  $('secao-fechar').hidden = !podeFechar;
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('coluna-reabrir').hidden = !podeReabrir;
  const verExtrato = Layout.acoesDe('banco/extrato.html').has('VER');

  const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  const hojeIso = () => iso(new Date());
  const c = (v) => Math.round(Number(v || 0) * 100);
  const nomeFace = (f) => f >= 2 ? 'Cédula de ' + Util.moeda(f) : 'Moeda de ' + Util.moeda(f);

  // ------------------------------------------------------------ contagem por cédulas
  const qtds = new Map();
  for (const f of FACES) {
    const tr = Util.el('tr');
    const inp = document.createElement('input');
    inp.type = 'number';
    inp.min = '0';
    inp.step = '1';
    inp.inputMode = 'numeric';
    inp.setAttribute('aria-label', 'Quantidade: ' + nomeFace(f));
    inp.dataset.dica = 'Quantas ' + (f >= 2 ? 'cédulas' : 'moedas') + ' de ' + Util.moeda(f) + ' tem no caixa.';
    const sub = Util.el('td', 'numero', '');
    inp.addEventListener('input', () => { sujo = true; somarContagem(); });
    qtds.set(f, { inp, sub });
    const tdq = Util.el('td', 'numero');
    tdq.append(inp);
    tr.append(Util.el('td', null, nomeFace(f)), tdq, sub);
    $('contagem-linhas').append(tr);
  }
  function somarContagem() {
    let total = 0;
    for (const [f, { inp, sub }] of qtds) {
      const q = Math.max(0, parseInt(inp.value || '0', 10) || 0);
      const v = Math.round(f * 100) * q;
      sub.textContent = q ? Util.moeda(v / 100) : '';
      total += v;
    }
    $('contagem-total').textContent = Util.moeda(total / 100);
    if ($('usar-contagem').checked) { $('saldoContado').value = Util.moeda(total / 100); atualizarDiferenca(); }
    return total / 100;
  }
  function textoContagem() {
    if (!$('usar-contagem').checked) return '';
    const partes = [];
    for (const [f, { inp }] of qtds) {
      const q = parseInt(inp.value || '0', 10) || 0;
      if (q > 0) partes.push(Util.moeda(f) + ' x ' + q);
    }
    return partes.length ? 'Contagem: ' + partes.join('; ') + ' = ' + $('contagem-total').textContent + '.' : '';
  }
  $('usar-contagem').addEventListener('change', () => {
    $('contagem').hidden = !$('usar-contagem').checked;
    $('saldoContado').readOnly = $('usar-contagem').checked;
    if ($('usar-contagem').checked) { somarContagem(); const p = qtds.get(FACES[0]); if (p) p.inp.focus(); }
  });

  // ------------------------------------------------------------ prévia e diferença
  function mostrarPasso(visivel) {
    for (const id of ['area-contagem', 'area-contado', 'botoes-fechar']) $(id).hidden = !visivel;
  }

  function atualizarDiferenca() {
    const el = $('diferenca');
    const contado = Util.lerMoeda($('saldoContado').value);
    if (!previa || isNaN(contado)) { el.textContent = '–'; el.className = 'diferenca'; $('campo-motivo').hidden = true; $('campo-ajuste').hidden = true; return; }
    const dif = (c(contado) - c(previa.saldoSistema)) / 100;
    el.className = 'diferenca ' + (dif === 0 ? 'diferenca-zero' : (dif > 0 ? 'diferenca-sobra' : 'diferenca-falta'));
    el.textContent = dif === 0 ? 'Sem diferença' : (dif > 0 ? 'Sobra de ' : 'Falta de ') + Util.moeda(Math.abs(dif));
    $('campo-motivo').hidden = dif === 0;
    $('campo-ajuste').hidden = dif === 0 || !previa.podeAjuste;
    if (dif === 0 || !previa.podeAjuste) $('gerarAjuste').checked = false;
  }
  $('saldoContado').addEventListener('input', () => { sujo = true; atualizarDiferenca(); });
  $('saldoContado').addEventListener('blur', () => { const v = Util.lerMoeda($('saldoContado').value); if (!isNaN(v)) $('saldoContado').value = Util.moeda(v); });
  for (const id of ['motivo', 'observacao']) $(id).addEventListener('input', () => { sujo = true; });

  async function carregarPrevia() {
    previa = null;
    $('previa').hidden = true;
    $('previa-erro').hidden = true;
    mostrarPasso(false);
    atualizarDiferenca();
    const idConta = parseInt($('conta').value || '', 10);
    $('link-extrato').hidden = !verExtrato || !idConta;
    if (idConta) $('link-extrato').href = '/banco/extrato.html?conta=' + idConta;
    if (!idConta || !$('dtFechamento').value) return;
    const r = await Api.post('/api/banco/caixa/conferir', { idConta, dtFechamento: $('dtFechamento').value, saldoContado: null });
    const d = r.dados || {};
    const avisos = Array.isArray(d.avisos) ? d.avisos : [];
    if (!r.sucesso) {
      if (!avisos.length && r.tipo !== 'ATENCAO' && r.tipo !== 'PENDENTE') { await Mensagens.tratar(r); return; }
      const bloqueio = avisos.find((a) => a.nivel === 'BLOQUEIO');
      $('previa-erro').textContent = bloqueio ? bloqueio.mensagem : (r.mensagem || 'Não dá para fechar este caixa nesta data.');
      $('previa-erro').hidden = false;
      return;
    }
    previa = { saldoSistema: Number(d.saldoSistema || 0), podeAjuste: !!d.podeAjuste };
    $('p-ultimo').textContent = d.dtUltimoFechamento ? Util.data(d.dtUltimoFechamento) : 'Nunca';
    $('p-entradas').textContent = Util.moeda(d.entradas);
    $('p-saidas').textContent = Util.moeda(d.saidas);
    $('p-qtd').textContent = (Number(d.qtdMovimentos) === 1 ? '1 movimento' : Number(d.qtdMovimentos || 0) + ' movimentos') + ' no período';
    $('p-sistema').textContent = Util.moeda(previa.saldoSistema);
    $('p-sistema').classList.toggle('valor-negativo', previa.saldoSistema < 0);
    $('previa').hidden = false;
    mostrarPasso(true);
    atualizarDiferenca();
  }

  function limparFechamento() {
    $('saldoContado').value = '';
    $('motivo').value = '';
    $('observacao').value = '';
    $('gerarAjuste').checked = false;
    for (const { inp } of qtds.values()) inp.value = '';
    somarContagem();
    sujo = false;
  }

  async function trocar(ev) {
    if (sujo && !(await Mensagens.confirmar('Trocar sem gravar?', 'O fechamento que você começou ainda não foi gravado. Trocar mesmo assim?', 'Trocar'))) {
      ev.target.value = ev.target.dataset.anterior || '';
      return;
    }
    ev.target.dataset.anterior = ev.target.value;
    limparFechamento();
    carregarPrevia();
  }
  $('conta').addEventListener('change', trocar);
  $('dtFechamento').addEventListener('change', trocar);

  // ------------------------------------------------------------ gravar
  $('form-fechar').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!previa) return;
    const contado = Util.lerMoeda($('saldoContado').value);
    if (isNaN(contado)) { await Mensagens.alerta('Informe o saldo contado.', 'ATENCAO', { foco: $('saldoContado') }); return; }
    const dif = (c(contado) - c(previa.saldoSistema)) / 100;
    const motivo = $('motivo').value.trim();
    if (dif !== 0 && motivo.length < 5) { await Mensagens.alerta('Há diferença entre o contado e o sistema: informe o motivo (pelo menos 5 letras).', 'ATENCAO', { foco: $('motivo') }); return; }
    const caixa = caixas.find((x) => String(x.ID_CONTA) === $('conta').value);
    const ajuste = $('gerarAjuste').checked;
    const texto = 'Confirma o fechamento do caixa ' + (caixa ? caixa.DESCRICAO : '') + ' até ' + Util.data($('dtFechamento').value)
      + ', com saldo contado de ' + Util.moeda(contado) + (dif === 0 ? ' (sem diferença)' : ' (' + (dif > 0 ? 'sobra' : 'falta') + ' de ' + Util.moeda(Math.abs(dif))
      + (ajuste ? ', com ajuste' : ', sem ajuste') + ')') + '? Depois de fechado, o caixa não aceita lançamentos até essa data.';
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Fechar caixa'))) return;
    const obs = [textoContagem(), $('observacao').value.trim()].filter(Boolean).join(' ');
    const pedido = { idConta: parseInt($('conta').value, 10), dtFechamento: $('dtFechamento').value, saldoContado: contado,
      motivo: dif !== 0 ? motivo : null, gerarAjuste: ajuste, observacao: obs.substring(0, 400) };
    $('botao-fechar').disabled = true;
    try {
      for (let tentativa = 0; tentativa < 3; tentativa++) {
        const r = await Api.post('/api/banco/caixa', pedido);
        if (r.sucesso) {
          await Mensagens.concluido(r.mensagem || 'Caixa fechado.');
          limparFechamento();
          await Promise.all([carregarPrevia(), carregarLista()]);
          return;
        }
        const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
        if (!avisos.length) { await Mensagens.tratar(r); return; }
        const resposta = await Mensagens.avisos(avisos, { titulo: 'Confira antes de fechar o caixa' });
        if (!resposta) return;
        if (resposta.motivo) pedido.motivo = resposta.motivo;
      }
      await Mensagens.alerta('Os avisos mudaram durante a gravação. Confira os dados e grave de novo.', 'ATENCAO');
    } finally {
      $('botao-fechar').disabled = false;
    }
  });
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && (e.key === 's' || e.key === 'S') && !$('botoes-fechar').hidden && !document.querySelector('dialog[open]')) { e.preventDefault(); $('form-fechar').requestSubmit(); }
  });
  window.addEventListener('beforeunload', (e) => { if (sujo) { e.preventDefault(); e.returnValue = ''; } });

  // ------------------------------------------------------------ histórico
  function desenharLista() {
    const corpo = $('linhas');
    corpo.replaceChildren();
    const colunas = podeReabrir ? 10 : 9;
    if (!lista.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum fechamento encontrado com esses filtros.');
      td.colSpan = colunas;
      tr.append(td);
      corpo.append(tr);
    }
    for (const f of lista) {
      const reaberto = f.SITUACAO === 'REABERTO';
      const tr = Util.el('tr', reaberto ? 'linha-estornada' : '');
      const dif = Number(f.DIFERENCA || 0);
      const tdDif = Util.el('td', 'numero forte' + (dif < 0 ? ' valor-negativo' : ''), dif === 0 ? '–' : Util.moeda(dif));
      const tdMot = Util.el('td', null, f.MOTIVO_DIFERENCA || '');
      if (f.OBSERVACAO) tdMot.append(Util.el('span', 'sub', f.OBSERVACAO));
      const tdAj = Util.el('td', null, f.ID_MOVIMENTO_AJUSTE ? Util.moeda(f.VALOR_AJUSTE) + (f.AJUSTE_DESFEITO ? ' (desfeito)' : '') : '');
      const sit = Util.el('td');
      const et = Util.el('span', 'situacao ' + (reaberto ? 'situacao-cancelada' : 'situacao-ativo'), reaberto ? 'Reaberto' : 'Fechado');
      if (reaberto) et.dataset.dica = 'Reaberto em ' + Util.dataHora(f.DT_REABERTURA) + ' por ' + f.USUARIO_REABERTURA + '. Motivo: ' + f.MOTIVO_REABERTURA;
      sit.append(et);
      tr.append(Util.el('td', 'numero', Util.data(f.DT_FECHAMENTO)), Util.el('td', 'forte', f.CONTA), Util.el('td', 'numero', Util.moeda(f.SALDO_SISTEMA)),
        Util.el('td', 'numero', Util.moeda(f.SALDO_CONTADO)), tdDif, tdMot, tdAj, sit, Util.el('td', null, f.USUARIO_CRIACAO || ''));
      if (podeReabrir) {
        const td = Util.el('td', 'col-acao-lista');
        if (f.PODE_REABRIR) {
          const b = Util.el('button', 'botao botao-pequeno', 'Reabrir');
          b.type = 'button';
          b.dataset.dica = 'Reabre este fechamento (só o último de cada caixa): o caixa volta a aceitar lançamentos nessas datas e o ajuste, se houver, é desfeito. Pede o motivo.';
          b.addEventListener('click', () => reabrir(f));
          td.append(b);
        }
        tr.append(td);
      }
      corpo.append(tr);
    }
    $('lista-contagem').textContent = lista.length === 1 ? '1 fechamento' : lista.length + ' fechamentos';
  }

  async function carregarLista() {
    $('lista-contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/banco/caixa', { idConta: $('f-conta').value, de: $('f-de').value, ate: $('f-ate').value,
      situacao: $('f-situacao').value, soComDiferenca: $('f-diferenca').checked ? 'true' : '' });
    if (!(await Mensagens.tratar(r))) { $('lista-contagem').textContent = ''; return; }
    lista = r.dados || [];
    desenharLista();
  }
  for (const id of ['f-conta', 'f-de', 'f-ate', 'f-situacao', 'f-diferenca']) $(id).addEventListener('change', carregarLista);
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregarLista(); });

  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Fechamentos_de_caixa',
    ['Data', 'Caixa', 'Empresa', 'Saldo do sistema', 'Saldo contado', 'Diferença', 'Motivo', 'Observação', 'Ajuste', 'Situação', 'Fechado por', 'Reaberto em', 'Reaberto por', 'Motivo da reabertura'],
    lista.map((f) => [Util.data(f.DT_FECHAMENTO), f.CONTA, f.EMPRESA, Util.moeda(f.SALDO_SISTEMA), Util.moeda(f.SALDO_CONTADO), Util.moeda(f.DIFERENCA), f.MOTIVO_DIFERENCA,
      f.OBSERVACAO, f.ID_MOVIMENTO_AJUSTE ? Util.moeda(f.VALOR_AJUSTE) + (f.AJUSTE_DESFEITO ? ' (desfeito)' : '') : '', f.SITUACAO === 'REABERTO' ? 'Reaberto' : 'Fechado',
      f.USUARIO_CRIACAO, f.DT_REABERTURA ? Util.dataHora(f.DT_REABERTURA) : '', f.USUARIO_REABERTURA, f.MOTIVO_REABERTURA])));

  // ------------------------------------------------------------ reabrir
  function reabrir(f) {
    return new Promise((resolver) => {
      let pronto = false;
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'janela-reabrir-titulo');
      const topo = Util.el('div', 'janela-topo');
      const h2 = Util.el('h2', null, 'Reabrir fechamento de caixa');
      h2.id = 'janela-reabrir-titulo';
      topo.append(h2);
      const explica = Util.el('p', 'janela-texto', 'Caixa ' + f.CONTA + ', fechado até ' + Util.data(f.DT_FECHAMENTO) + '. Reaberto, o caixa volta a aceitar baixas, estornos e transferências nessas datas. Nada é apagado: o fechamento fica como Reaberto.');
      const grade = Util.el('div', 'grade');
      const motivo = document.createElement('textarea');
      motivo.rows = 3;
      motivo.maxLength = 400;
      const lab = Util.el('label', 'campo s-4', 'Motivo *');
      lab.dataset.dica = 'Por que o fechamento está sendo reaberto (ex.: lançamento esquecido no dia). Obrigatório, pelo menos 5 letras. Fica registrado.';
      lab.append(motivo);
      grade.append(lab);
      const info = Util.el('div', 'aviso-faixa');
      info.hidden = true;
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;
      const barra = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      cancelar.dataset.dica = 'Fecha sem reabrir (Esc).';
      const ok = Util.el('button', 'botao botao-perigo', 'Reabrir');
      ok.type = 'button';
      ok.disabled = true;
      ok.dataset.dica = 'Confere e reabre (pede confirmação antes).';
      barra.append(cancelar, ok);
      const fechar = (v) => { janela.close(); janela.remove(); resolver(v); };
      cancelar.addEventListener('click', () => fechar(false));
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(false); });

      (async () => {
        const r = await Api.post('/api/banco/caixa/' + f.ID_CAIXA_FECHAMENTO + '/reabrir/conferir', { motivo: null });
        const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
        const bloqueio = avisos.find((a) => a.nivel === 'BLOQUEIO');
        if (!r.sucesso && (bloqueio || !avisos.length)) {
          if (!avisos.length && r.tipo !== 'ATENCAO' && r.tipo !== 'PENDENTE') { await Mensagens.tratar(r); fechar(false); return; }
          erro.textContent = bloqueio ? bloqueio.mensagem : (r.mensagem || 'Não dá para reabrir este fechamento.');
          erro.hidden = false;
          return;
        }
        const aj = Number((r.dados || {}).valorAjuste || 0);
        info.textContent = aj ? 'O ajuste de ' + Util.moeda(aj) + ' gravado neste fechamento será desfeito (movimento inverso na mesma data).' : 'Este fechamento não tem ajuste.';
        info.hidden = false;
        pronto = true;
        ok.disabled = false;
      })();

      ok.addEventListener('click', async () => {
        const m = motivo.value.trim();
        if (m.length < 5) { erro.textContent = 'Informe o motivo da reabertura (pelo menos 5 letras).'; erro.hidden = false; motivo.focus(); return; }
        if (!pronto) return;
        if (!(await Mensagens.confirmar('Reabrir?', 'Confirma a reabertura do fechamento do caixa ' + f.CONTA + ' de ' + Util.data(f.DT_FECHAMENTO) + '?', 'Reabrir'))) return;
        ok.disabled = true;
        try {
          const r = await Api.post('/api/banco/caixa/' + f.ID_CAIXA_FECHAMENTO + '/reabrir', { motivo: m });
          if (!r.sucesso) {
            const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
            if (avisos.length) { erro.textContent = avisos.map((a) => a.mensagem).join(' '); erro.hidden = false; }
            else await Mensagens.tratar(r);
            return;
          }
          janela.close(); janela.remove();
          await Mensagens.concluido(r.mensagem || 'Fechamento reaberto.');
          resolver(true);
        } finally {
          ok.disabled = !pronto;
        }
      });

      janela.append(topo, explica, grade, info, erro, barra);
      document.body.append(janela);
      janela.showModal();
      motivo.focus();
    }).then((feito) => { if (feito) { carregarLista(); carregarPrevia(); } });
  }

  // ------------------------------------------------------------ início
  const r = await Api.get('/api/banco/saldos', { data: hojeIso(), todas: 'true' });
  if (await Mensagens.tratar(r)) caixas = (r.dados || []).filter((s) => s.USA_FECHAMENTO);
  for (const sel of [$('conta'), $('f-conta')]) {
    for (const x of caixas) {
      const op = Util.el('option', null, x.DESCRICAO + (caixas.some((y) => y.ID_EMPRESA !== x.ID_EMPRESA) ? ' (' + x.EMPRESA + ')' : '') + (x.FECHAMENTO_ATRASADO ? ' – fechamento atrasado' : ''));
      op.value = x.ID_CONTA;
      sel.append(op);
    }
  }
  if (!caixas.length) {
    const op = Util.el('option', null, 'Nenhum caixa para fechar');
    op.value = '';
    $('conta').append(op);
  }
  const contaUrl = Util.parametro('conta');
  const atrasado = caixas.find((x) => x.FECHAMENTO_ATRASADO);
  $('conta').value = contaUrl && caixas.some((x) => String(x.ID_CONTA) === contaUrl) ? contaUrl : String((atrasado || caixas[0] || {}).ID_CONTA || '');
  $('conta').dataset.anterior = $('conta').value;
  $('dtFechamento').value = hojeIso();
  $('dtFechamento').dataset.anterior = $('dtFechamento').value;
  if (contaUrl) $('f-conta').value = contaUrl;
  const d = new Date();
  $('f-de').value = iso(new Date(d.getFullYear(), d.getMonth() - 2, 1));
  await Promise.all([podeFechar ? carregarPrevia() : Promise.resolve(), carregarLista()]);
});
