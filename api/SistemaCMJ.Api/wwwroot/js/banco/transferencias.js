/* =============================================================================
   SistemaCMJ - js/banco/transferencias.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04g4b)
   Descrição : Tela Bancos › Transferências (BANCO_TRANSFERENCIA).
               Lista (GET /api/banco/transferencias: período, conta, situação,
               só entre empresas, procurar, paginação, total das ativas),
               exportar todo o filtro, "+ Transferir" (janela com data, conta de
               origem e de destino com busca, saldo disponível da origem, valor,
               documento, histórico; "Gravar?" › avisos pelo Mensagens.avisos:
               entre empresas, saldo insuficiente, trava de datas com motivo ›
               "Concluído") e Estornar (data, motivo, prévia pelo
               /estornar/conferir). Endereço: ?idConta=&de=&ate=&destacar=ID
               (vem do extrato) e ?transferir=1[&origem=ID].
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const CHAVE = 'cmj_filtros_transferencias';
  const podeEstornar = acoes.has('ESTORNAR');
  let pagina = 1;
  let totalLinhas = 0;
  let porPagina = 100;
  let linhas = [];
  const destacar = parseInt(Util.parametro('destacar') || '', 10) || null;

  $('botao-incluir').hidden = !acoes.has('INCLUIR');
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  $('link-extrato').hidden = !Layout.acoesDe('banco/extrato.html').has('VER');
  $('coluna-estornar').hidden = !podeEstornar;

  const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  const hojeIso = () => iso(new Date());
  const dataBr = (v) => Util.data(v);

  let salvos = {};
  try { salvos = JSON.parse(sessionStorage.getItem(CHAVE) || '{}'); } catch { salvos = {}; }
  const seletor = Seletor.criar($('seletor-conta'), { tipo: 'CONTA', rotulo: 'Conta', aoMudar: () => recarregar() });

  function filtros() {
    return {
      de: $('de').value, ate: $('ate').value, idConta: seletor.valor() || '', situacao: $('situacao').value,
      entreEmpresas: $('entre-empresas').checked ? 'true' : '', texto: $('texto').value.trim()
    };
  }
  function guardar() { sessionStorage.setItem(CHAVE, JSON.stringify({ ...filtros(), entreEmpresas: $('entre-empresas').checked })); }
  function recarregar() { pagina = 1; carregar(); }

  // ------------------------------------------------------------ lista
  function contaTexto(conta, empresa, entre) {
    const td = Util.el('td', 'forte', conta);
    if (entre) td.append(Util.el('span', 'sub', empresa));
    return td;
  }

  function desenhar() {
    const corpo = $('linhas');
    corpo.replaceChildren();
    const colunas = podeEstornar ? 9 : 8;
    if (!linhas.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma transferência encontrada com esses filtros.');
      td.colSpan = colunas;
      tr.append(td);
      corpo.append(tr);
    }
    for (const t of linhas) {
      const estornada = t.SITUACAO === 'ESTORNADA';
      const tr = Util.el('tr', estornada ? 'linha-estornada' : '');
      if (destacar && t.ID_TRANSFERENCIA === destacar) tr.classList.add('linha-marcada');
      const sit = Util.el('td');
      const et = Util.el('span', 'situacao ' + (estornada ? 'situacao-cancelada' : 'situacao-ativo'), estornada ? 'Estornada' : 'Ativa');
      if (estornada) et.dataset.dica = 'Estornada em ' + dataBr(t.DT_ESTORNO) + ' por ' + t.USUARIO_ESTORNO + '. Motivo: ' + t.MOTIVO_ESTORNO;
      sit.append(et);
      if (t.ENTRE_EMPRESAS) sit.append(' ', Util.el('span', 'etiqueta', 'Entre empresas'));
      if (t.MIGRADA) sit.append(' ', Util.el('span', 'etiqueta', 'Migrada'));
      const valor = Util.el('td', 'numero forte', Util.moeda(t.VALOR));
      tr.append(Util.el('td', 'numero', dataBr(t.DT_TRANSFERENCIA)), contaTexto(t.CONTA_ORIGEM, t.EMPRESA_ORIGEM, t.ENTRE_EMPRESAS),
        contaTexto(t.CONTA_DESTINO, t.EMPRESA_DESTINO, t.ENTRE_EMPRESAS), valor, Util.el('td', null, t.HISTORICO || ''),
        Util.el('td', null, t.DOCUMENTO || ''), sit, Util.el('td', null, t.USUARIO_CRIACAO || ''));
      if (podeEstornar) {
        const td = Util.el('td', 'col-acao-lista');
        if (t.PODE_ESTORNAR) {
          const b = Util.el('button', 'botao botao-pequeno', 'Estornar');
          b.type = 'button';
          b.dataset.dica = 'Desfaz esta transferência: as duas contas ganham o movimento inverso. Pede data e motivo.';
          b.addEventListener('click', () => estornar(t));
          td.append(b);
        }
        tr.append(td);
      }
      corpo.append(tr);
    }
    const rodape = $('total');
    rodape.replaceChildren();
    if (linhas.length) {
      const tr = Util.el('tr', 'linha-total');
      const rot = Util.el('td', 'forte', 'Total das ativas do filtro');
      rot.colSpan = 3;
      const resto = Util.el('td');
      resto.colSpan = colunas - 4;
      tr.append(rot, Util.el('td', 'numero forte', Util.moeda(linhas[0].TOTAL_VALOR)), resto);
      rodape.append(tr);
    }
    $('contagem').textContent = totalLinhas === 1 ? '1 transferência' : totalLinhas + ' transferências';
    const paginas = Math.max(1, Math.ceil(totalLinhas / porPagina));
    $('paginacao').hidden = paginas <= 1;
    $('pagina-texto').textContent = 'Página ' + pagina + ' de ' + paginas;
    $('pagina-anterior').disabled = pagina <= 1;
    $('pagina-proxima').disabled = pagina >= paginas;
  }

  async function carregar() {
    guardar();
    const f = filtros();
    if (f.de && f.ate && f.de > f.ate) { await Mensagens.alerta('A data "De" tem que ser antes da data "Até".', 'ATENCAO', { foco: $('de') }); return; }
    $('contagem').textContent = 'Buscando…';
    const r = await Api.get('/api/banco/transferencias', { ...f, pagina });
    if (!(await Mensagens.tratar(r))) { $('contagem').textContent = ''; return; }
    linhas = r.dados || [];
    totalLinhas = linhas.length ? Number(linhas[0].TOTAL_LINHAS) : 0;
    if (pagina === 1 && totalLinhas > linhas.length) porPagina = linhas.length; // tamanho da página vem do parâmetro FIN_LISTA_POR_PAGINA
    desenhar();
  }

  // ------------------------------------------------------------ exportar
  $('botao-exportar').addEventListener('click', async () => {
    const todas = [];
    for (let p = 1; p <= 100; p++) {
      const r = await Api.get('/api/banco/transferencias', { ...filtros(), pagina: p, porPagina: 1000 });
      if (!(await Mensagens.tratar(r))) return;
      const d = r.dados || [];
      todas.push(...d);
      if (!d.length || todas.length >= Number(d[0].TOTAL_LINHAS)) break;
    }
    Util.exportarCsv('Transferencias', ['Código', 'Data', 'Conta de origem', 'Empresa de origem', 'Conta de destino', 'Empresa de destino', 'Valor', 'Histórico',
      'Documento', 'Situação', 'Data do estorno', 'Motivo do estorno', 'Incluída por'],
    todas.map((t) => [t.ID_TRANSFERENCIA, dataBr(t.DT_TRANSFERENCIA), t.CONTA_ORIGEM, t.EMPRESA_ORIGEM, t.CONTA_DESTINO, t.EMPRESA_DESTINO, Util.moeda(t.VALOR),
      t.HISTORICO, t.DOCUMENTO, t.SITUACAO === 'ESTORNADA' ? 'Estornada' : 'Ativa', dataBr(t.DT_ESTORNO), t.MOTIVO_ESTORNO, t.USUARIO_CRIACAO]));
  });

  // ------------------------------------------------------------ janela: transferir
  function campoJanela(grade, rotulo, el, classe, dica) {
    const lab = Util.el(el.tagName === 'DIV' ? 'div' : 'label', 'campo' + (classe ? ' ' + classe : ''), rotulo);
    if (dica) lab.dataset.dica = dica;
    lab.append(el);
    grade.append(lab);
    return el;
  }

  function transferir(idOrigem) {
    return new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'janela-transf-titulo');
      const topo = Util.el('div', 'janela-topo');
      const h2 = Util.el('h2', null, 'Nova transferência');
      h2.id = 'janela-transf-titulo';
      topo.append(h2);
      const grade = Util.el('div', 'grade');
      const dt = document.createElement('input');
      dt.type = 'date';
      dt.value = hojeIso();
      dt.id = 'tr-data';
      campoJanela(grade, 'Data *', dt, null, 'Dia em que o dinheiro saiu de uma conta e entrou na outra. Obrigatória (padrão hoje). Valem a trava de datas, o mês fechado e o caixa fechado nas duas contas.');
      const valor = document.createElement('input');
      valor.inputMode = 'decimal';
      valor.placeholder = '0,00';
      valor.id = 'tr-valor';
      campoJanela(grade, 'Valor *', valor, null, 'Valor transferido, maior que zero. Com vírgula nos centavos (ex.: 1.500,00).');
      const caixaOrigem = Util.el('div');
      caixaOrigem.id = 'tr-origem';
      campoJanela(grade, 'De (conta de origem) *', caixaOrigem, 's-2', 'Conta ou caixa de onde sai o dinheiro. Obrigatória.');
      const saldoOrigem = Util.el('div', 'subtitulo saldo-origem');
      grade.append(saldoOrigem);
      const caixaDestino = Util.el('div');
      caixaDestino.id = 'tr-destino';
      campoJanela(grade, 'Para (conta de destino) *', caixaDestino, 's-2', 'Conta ou caixa para onde vai o dinheiro. Obrigatória e diferente da origem.');
      const doc = document.createElement('input');
      doc.maxLength = 40;
      campoJanela(grade, 'Documento', doc, null, 'Número do comprovante, do DOC/TED ou do cheque (opcional).');
      const hist = document.createElement('input');
      hist.maxLength = 200;
      hist.placeholder = 'Ex.: reforço do caixa';
      hist.id = 'tr-historico';
      campoJanela(grade, 'Histórico', hist, 's-3', 'Complemento que aparece no extrato das duas contas, depois de "Transferência para/de <conta>" (opcional).');
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;
      const barra = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      cancelar.dataset.dica = 'Fecha sem gravar (Esc).';
      const ok = Util.el('button', 'botao botao-principal', 'Transferir');
      ok.type = 'button';
      ok.dataset.dica = 'Confere e grava a transferência (pede confirmação antes). Atalho: Ctrl+S.';
      barra.append(cancelar, ok);

      let sujo = false;
      const fechar = async (v) => {
        if (!v && sujo && !(await Mensagens.confirmar('Sair sem gravar?', 'A transferência ainda não foi gravada. Sair mesmo assim?', 'Sair'))) return;
        janela.close(); janela.remove(); resolver(v);
      };
      for (const el of [dt, valor, doc, hist]) el.addEventListener('input', () => { sujo = true; });

      async function mostrarSaldo() {
        saldoOrigem.textContent = '';
        const id = selOrigem.valor();
        if (!id) return;
        const r = await Api.get('/api/banco/saldos', { data: dt.value || hojeIso(), todas: 'true', inativas: 'true' });
        if (!r.sucesso) return;
        const s = (r.dados || []).find((x) => x.ID_CONTA === id);
        if (!s) return;
        saldoOrigem.textContent = 'Saldo da origem em ' + dataBr(dt.value || hojeIso()) + ': ' + Util.moeda(s.SALDO)
          + (Number(s.LIMITE_CREDITO) ? ' · disponível com o limite: ' + Util.moeda(s.DISPONIVEL) : '');
        saldoOrigem.classList.toggle('valor-negativo', Number(s.DISPONIVEL) < 0);
      }
      const selOrigem = Seletor.criar(caixaOrigem, { tipo: 'CONTA', rotulo: 'Conta de origem', aoMudar: () => { sujo = true; mostrarSaldo(); } });
      const selDestino = Seletor.criar(caixaDestino, { tipo: 'CONTA', rotulo: 'Conta de destino', aoMudar: () => { sujo = true; } });
      dt.addEventListener('change', mostrarSaldo);

      function focarCampo(c) {
        ({ dtTransferencia: () => dt.focus(), valor: () => valor.focus(), idContaOrigem: () => selOrigem.focar(), idContaDestino: () => selDestino.focar() }[c] || (() => {}))();
      }

      cancelar.addEventListener('click', () => fechar(false));
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(false); });
      janela.addEventListener('keydown', (e) => { if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); ok.click(); } });

      ok.addEventListener('click', async () => {
        erro.hidden = true;
        const v = Util.lerMoeda(valor.value);
        const falta = !dt.value ? ['Informe a data da transferência.', () => dt.focus()]
          : !selOrigem.valor() ? ['Escolha a conta de origem (de onde sai o dinheiro).', () => selOrigem.focar()]
          : !selDestino.valor() ? ['Escolha a conta de destino (para onde vai o dinheiro).', () => selDestino.focar()]
          : selOrigem.valor() === selDestino.valor() ? ['A conta de origem e a de destino precisam ser diferentes.', () => selDestino.focar()]
          : (isNaN(v) || v <= 0) ? ['Informe o valor da transferência (maior que zero).', () => valor.focus()] : null;
        if (falta) { erro.textContent = falta[0]; erro.hidden = false; falta[1](); return; }
        const texto = 'Confirma a transferência de ' + Util.moeda(v) + ' em ' + dataBr(dt.value) + ', de ' + selOrigem.item().DESCRICAO
          + ' para ' + selDestino.item().DESCRICAO + '?';
        if (!(await Mensagens.confirmar('Gravar?', texto, 'Transferir'))) return;
        const pedido = {
          dtTransferencia: dt.value, idContaOrigem: selOrigem.valor(), idContaDestino: selDestino.valor(), valor: v,
          historico: hist.value.trim(), documento: doc.value.trim(), avisosConfirmados: [], motivo: null
        };
        ok.disabled = true;
        try {
          for (let tentativa = 0; tentativa < 3; tentativa++) {
            const r = await Api.post('/api/banco/transferencias', pedido);
            if (r.sucesso) {
              janela.close(); janela.remove();
              await Mensagens.concluido(r.mensagem || 'Transferência gravada.');
              resolver(true);
              return;
            }
            const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
            if (!avisos.length) { await Mensagens.tratar(r); return; }
            const resposta = await Mensagens.avisos(avisos, { titulo: 'Confira antes de transferir' });
            if (!resposta) { const primeiro = avisos.find((a) => a.campo); if (primeiro) focarCampo(primeiro.campo); return; }
            pedido.avisosConfirmados = [...new Set([...pedido.avisosConfirmados, ...resposta.confirmados])];
            if (resposta.motivo) pedido.motivo = resposta.motivo;
          }
          await Mensagens.alerta('Os avisos mudaram durante a gravação. Confira os dados e grave de novo.', 'ATENCAO');
        } finally {
          ok.disabled = false;
        }
      });

      janela.append(topo, grade, erro, barra);
      document.body.append(janela);
      janela.showModal();
      if (idOrigem) selOrigem.definir(idOrigem).then(() => { mostrarSaldo(); selDestino.focar(); });
      else selOrigem.focar();
    });
  }

  // ------------------------------------------------------------ janela: estornar
  function estornar(t) {
    return new Promise((resolver) => {
      let previa = false;
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'janela-estorno-titulo');
      const topo = Util.el('div', 'janela-topo');
      const h2 = Util.el('h2', null, 'Estornar transferência');
      h2.id = 'janela-estorno-titulo';
      topo.append(h2);
      const explica = Util.el('p', 'janela-texto', 'Transferência de ' + Util.moeda(t.VALOR) + ' em ' + dataBr(t.DT_TRANSFERENCIA) + ', de ' + t.CONTA_ORIGEM + ' para '
        + t.CONTA_DESTINO + '. Nada é apagado: as duas contas ganham o movimento inverso na data do estorno.');
      const grade = Util.el('div', 'grade');
      const dt = document.createElement('input');
      dt.type = 'date';
      dt.value = hojeIso();
      campoJanela(grade, 'Data do estorno *', dt, null, 'Dia em que o estorno entra no extrato das duas contas. Obrigatória (padrão hoje). Valem as travas de data, de mês fechado e de caixa fechado nas duas contas.');
      const motivo = document.createElement('textarea');
      motivo.rows = 3;
      motivo.maxLength = 400;
      campoJanela(grade, 'Motivo *', motivo, 's-3', 'Por que a transferência está sendo estornada (ex.: conta errada, valor errado). Obrigatório, pelo menos 5 letras. Fica registrado.');
      const info = Util.el('div', 'aviso-faixa');
      info.hidden = true;
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;
      const barra = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      cancelar.dataset.dica = 'Fecha sem estornar (Esc).';
      const ok = Util.el('button', 'botao botao-perigo', 'Estornar');
      ok.type = 'button';
      ok.dataset.dica = 'Confere e grava o estorno (pede confirmação antes).';
      barra.append(cancelar, ok);
      const fechar = (v) => { janela.close(); janela.remove(); resolver(v); };
      cancelar.addEventListener('click', () => fechar(false));
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(false); });

      async function conferir() {
        erro.hidden = true;
        info.hidden = true;
        ok.disabled = true;
        previa = false;
        if (!dt.value) { erro.textContent = 'Informe a data do estorno.'; erro.hidden = false; return; }
        const r = await Api.post('/api/banco/transferencias/' + t.ID_TRANSFERENCIA + '/estornar/conferir', { motivo: motivo.value.trim() || null, dtEstorno: dt.value });
        const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
        const bloqueio = avisos.find((a) => a.nivel === 'BLOQUEIO');
        if (!r.sucesso && (bloqueio || !avisos.length)) {
          if (!avisos.length && r.tipo !== 'ATENCAO' && r.tipo !== 'PENDENTE') { await Mensagens.tratar(r); fechar(false); return; }
          erro.textContent = bloqueio ? bloqueio.mensagem : (r.mensagem || 'Não dá para estornar esta transferência.');
          erro.hidden = false;
          return;
        }
        previa = true;
        const partes = ['Valor estornado: ' + Util.moeda(t.VALOR) + ', nas duas contas.'];
        if (avisos.some((a) => a.nivel === 'MOTIVO')) partes.push('A data está fora da trava de datas: o motivo do estorno fica registrado também como justificativa.');
        info.textContent = partes.join(' ');
        info.hidden = false;
        ok.disabled = false;
      }
      dt.addEventListener('change', conferir);

      ok.addEventListener('click', async () => {
        const m = motivo.value.trim();
        if (m.length < 5) { erro.textContent = 'Informe o motivo do estorno (pelo menos 5 letras).'; erro.hidden = false; motivo.focus(); return; }
        if (!previa) return;
        if (!(await Mensagens.confirmar('Estornar?', 'Confirma o estorno da transferência de ' + Util.moeda(t.VALOR) + ' com data de ' + dataBr(dt.value) + '?', 'Estornar'))) return;
        ok.disabled = true;
        try {
          const r = await Api.post('/api/banco/transferencias/' + t.ID_TRANSFERENCIA + '/estornar', { motivo: m, dtEstorno: dt.value });
          if (!r.sucesso) {
            const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
            if (avisos.length) { erro.textContent = avisos.map((a) => a.mensagem).join(' '); erro.hidden = false; }
            else await Mensagens.tratar(r);
            return;
          }
          janela.close(); janela.remove();
          await Mensagens.concluido(r.mensagem || 'Transferência estornada.');
          resolver(true);
        } finally {
          ok.disabled = !previa;
        }
      });

      janela.append(topo, explica, grade, info, erro, barra);
      document.body.append(janela);
      janela.showModal();
      motivo.focus();
      conferir();
    }).then((feito) => { if (feito) carregar(); });
  }

  // ------------------------------------------------------------ eventos e início
  $('botao-incluir').addEventListener('click', async () => { if (await transferir(seletor.valor())) carregar(); });
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); recarregar(); });
  for (const c of ['de', 'ate', 'situacao', 'entre-empresas']) $(c).addEventListener('change', recarregar);
  $('texto').addEventListener('input', Util.atrasar(recarregar, 400));
  $('pagina-anterior').addEventListener('click', () => { if (pagina > 1) { pagina--; carregar(); } });
  $('pagina-proxima').addEventListener('click', () => { pagina++; carregar(); });

  const d = new Date();
  const veioDoExtrato = Util.parametro('idConta') || Util.parametro('de');
  $('de').value = Util.parametro('de') || (veioDoExtrato ? '' : salvos.de) || iso(new Date(d.getFullYear(), d.getMonth() - 2, 1));
  $('ate').value = Util.parametro('ate') || (veioDoExtrato ? '' : salvos.ate) || '';
  $('situacao').value = veioDoExtrato ? '' : (salvos.situacao ?? 'ATIVA');
  $('entre-empresas').checked = !veioDoExtrato && !!salvos.entreEmpresas;
  $('texto').value = veioDoExtrato ? '' : (salvos.texto || '');
  const conta = Util.parametro('idConta') || (veioDoExtrato ? '' : salvos.idConta);
  if (conta) await seletor.definir(conta);
  await carregar();
  if (Util.parametro('transferir') && acoes.has('INCLUIR')) {
    if (await transferir(parseInt(Util.parametro('origem') || '', 10) || seletor.valor())) carregar();
  }
});
