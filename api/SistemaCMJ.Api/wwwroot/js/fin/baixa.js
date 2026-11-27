/* =============================================================================
   SistemaCMJ - js/fin/baixa.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04g3a, aprovada pelo Celso)
   Descrição : Janela de baixa (componente único: ficha do lançamento e lista
               de contas a pagar e a receber). Uma ou várias parcelas do mesmo
               tipo, total ou parcial:
                 - cabeçalho: data do pagamento (hoje), conta (escolha com
                   busca; vem a conta prevista da parcela ou a conta padrão
                   da empresa), forma (parâmetro FIN_BAIXA_FORMA_PADRAO),
                   documento, tarifa e observação;
                 - uma linha por parcela: saldo, valor quitado (parcial =
                   menor que o saldo), juros e multa sugeridos (a receber;
                   no a pagar só com FIN_BAIXA_CALCULA_PAGAR), desconto (com
                   o limite na dica) e total da linha;
                 - trocar a data refaz a sugestão; mudar o valor quitado
                   recalcula juros e multa da linha (se não foram mudados
                   à mão).
               Gravação: "Gravar?" › prévia/avisos (Mensagens.avisos: BLOQUEIO
               só mostra; AVISO pede "Estou ciente"; MOTIVO pede o motivo,
               ex.: liberar pendência que bloqueia e desconto acima do limite)
               › "Concluído". Regras e travas ficam no banco
               (FIN_Baixa_Preparar / FIN_Baixa_Gravar).
               Ctrl+S baixa; Esc fecha (pergunta se algo foi mudado).
               04g3b: Baixa.estornar = janela do estorno (data, padrão hoje;
               motivo obrigatório; prévia pelo /estornar/conferir: quantas
               baixas e o valor; pagamento em lote estorna inteiro, com a
               tarifa; bloqueio aparece na janela e não deixa confirmar).
   Uso       : const gravou = await Baixa.abrir({ parcelas: [12, 13] });
               const estornou = await Baixa.estornar({ idBaixa: 7, descricao: 'parcela 2/5, 10/11/2026, 1.000,00' });
   ========================================================================== */
'use strict';

const Baixa = (() => {
  const FORMAS = [['PIX', 'PIX'], ['BOLETO', 'Boleto'], ['TED', 'TED'], ['DOC', 'DOC'], ['DEBITO', 'Débito em conta'],
    ['DINHEIRO', 'Dinheiro'], ['CHEQUE', 'Cheque'], ['PERMUTA', 'Permuta'], ['CARTAO', 'Cartão'], ['OUTRA', 'Outra']];

  const hojeIso = () => {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  };
  const c = (v) => Math.round((Number(v) || 0) * 100 + (v >= 0 ? 1e-7 : -1e-7));   // em centavos
  const dataBr = (iso) => String(iso || '').substring(0, 10).split('-').reverse().join('/');   // sem passar por Date (fuso)
  const r2 = (v) => Math.round(((Number(v) || 0) + Number.EPSILON) * 100) / 100;     // ROUND(x, 2) do SQL

  async function preparar(ids, data) {
    const r = await Api.get('/api/fin/baixas/preparar?parcelas=' + encodeURIComponent(ids.join(',')) + '&data=' + encodeURIComponent(data));
    if (!(await Mensagens.tratar(r))) return null;
    return Array.isArray(r.dados) ? r.dados : [];
  }

  async function abrir({ parcelas: ids }) {
    const lista = [...new Set((ids || []).map(Number).filter((n) => n > 0))];
    if (!lista.length) { await Mensagens.alerta('Escolha pelo menos uma parcela para baixar.', 'ATENCAO'); return false; }
    let data = hojeIso();
    const linhasBanco = await preparar(lista, data);
    if (!linhasBanco) return false;
    if (!linhasBanco.length) { await Mensagens.alerta('Nenhuma das parcelas escolhidas pode ser baixada por você (falta a permissão de baixar).', 'ATENCAO'); return false; }
    const tipos = [...new Set(linhasBanco.map((l) => l.TIPO))];
    if (tipos.length > 1) { await Mensagens.alerta('Contas a pagar e a receber não podem ser baixadas juntas. Marque só um tipo.', 'ATENCAO'); return false; }
    const pagar = tipos[0] === 'P';
    const abertas = linhasBanco.filter((l) => Number(l.SALDO) > 0 && l.SITUACAO !== 'CANCELADA');
    if (!abertas.length) { await Mensagens.alerta('As parcelas escolhidas não têm saldo em aberto.', 'ATENCAO'); return false; }
    if (abertas.length < linhasBanco.length)
      await Mensagens.alerta((linhasBanco.length - abertas.length) + ' parcela(s) sem saldo em aberto (paga ou cancelada) ficaram fora da baixa.', 'ATENCAO');

    // estado de cada linha
    const itens = abertas.map((l) => ({
      l, principal: r2(l.SALDO), juros: 0, multa: 0, desconto: 0, encargoManual: false
    }));
    const multaDevida = (it) => !!it.l.CALCULA && !(Number(it.l.MULTA) === 0 && Number(it.l.MULTA_PERC) > 0);
    function sugerir(it) {
      if (it.encargoManual) return;
      const calcula = !!it.l.CALCULA;
      it.multa = calcula && multaDevida(it) ? r2(it.principal * Number(it.l.MULTA_PERC) / 100) : 0;
      it.juros = calcula ? r2(it.principal * Number(it.l.JUROS_PERC) / 100 / 30 * Number(it.l.DIAS_ATRASO)) : 0;
    }
    itens.forEach(sugerir);
    let mudou = false;

    return new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-baixa';
      janela.setAttribute('aria-labelledby', 'janela-baixa-titulo');
      const topo = Util.el('div', 'janela-topo');
      const h2 = Util.el('h2', null, (pagar ? 'Pagamento' : 'Recebimento') + ' de ' + itens.length + (itens.length === 1 ? ' parcela' : ' parcelas'));
      h2.id = 'janela-baixa-titulo';
      topo.append(h2);

      // ---------- cabeçalho ----------
      const grade = Util.el('div', 'grade');
      const campo = (rotulo, el, classe, dica) => {
        const lab = Util.el('label', 'campo' + (classe ? ' ' + classe : ''), rotulo);
        if (dica) lab.dataset.dica = dica;
        lab.append(el);
        grade.append(lab);
        return el;
      };
      const dtPag = document.createElement('input');
      dtPag.type = 'date';
      dtPag.value = data;
      dtPag.id = 'baixa-dtPagamento';
      campo('Data do ' + (pagar ? 'pagamento' : 'recebimento') + ' *', dtPag, null,
        'Dia em que o dinheiro ' + (pagar ? 'saiu' : 'entrou') + ' na conta. Obrigatória. Ao trocar, juros e multa são calculados de novo para essa data.');

      const caixaConta = Util.el('div');
      const labConta = Util.el('div', 'campo s-2', 'Conta *');
      labConta.dataset.dica = 'Conta bancária ou caixa onde o dinheiro ' + (pagar ? 'saiu' : 'entrou') + '. Obrigatória. Vem a conta prevista da parcela ou a conta padrão da empresa.';
      labConta.append(caixaConta);
      grade.append(labConta);
      const seletorConta = Seletor.criar(caixaConta, { tipo: 'CONTA', rotulo: 'Conta', aoMudar: () => { mudou = true; } });

      const selForma = document.createElement('select');
      selForma.id = 'baixa-forma';
      selForma.append(Util.el('option', null, '(escolha)'));
      selForma.firstChild.value = '';
      for (const [v, t] of FORMAS) { const op = Util.el('option', null, t); op.value = v; selForma.append(op); }
      const formaPadrao = String(abertas[0].FORMA_PADRAO || '');
      selForma.value = FORMAS.some(([v]) => v === formaPadrao) ? formaPadrao : '';
      campo('Forma *', selForma, null, 'Como foi ' + (pagar ? 'pago' : 'recebido') + '. Obrigatória. Cheque fica "a compensar" até a conciliação. A forma que já vem escolhida é um parâmetro de uso.');

      const doc = document.createElement('input');
      doc.maxLength = 40;
      campo('Documento', doc, null, 'Nº do comprovante, do cheque ou da transação (opcional). Aparece no extrato da conta.');

      const tarifa = document.createElement('input');
      tarifa.inputMode = 'decimal';
      tarifa.value = Util.moeda(0);
      campo('Tarifa', tarifa, null, 'Tarifa do banco nesta ' + (pagar ? 'operação' : 'entrada') + ' (opcional). Sai da conta como um movimento à parte, ligado a esta baixa. Ex.: 3,50.');

      const obs = document.createElement('input');
      obs.maxLength = 400;
      campo('Observação', obs, 's-3', 'Observação da baixa (opcional).');

      // ---------- parcelas ----------
      const rolagem = Util.el('div', 'rolagem');
      const tabela = Util.el('table', 'tabela tabela-larga tabela-baixa');
      const thead = Util.el('thead');
      const trh = Util.el('tr');
      for (const [t, cl] of [['Parcela', null], ['Vencimento', null], ['Atraso', 'numero'], ['Saldo', 'numero'], [pagar ? 'Valor pago' : 'Valor recebido', 'numero'],
        ['Juros', 'numero'], ['Multa', 'numero'], ['Desconto', 'numero'], ['Total', 'numero']]) {
        const th = Util.el('th', cl, t); th.scope = 'col'; trh.append(th);
      }
      thead.append(trh);
      const corpo = Util.el('tbody');
      tabela.append(thead, corpo);
      rolagem.append(tabela);

      const rodape = Util.el('div', 'baixa-rodape');
      const faixa = Util.el('div', 'aviso-faixa aviso-bloqueio-baixa');
      faixa.hidden = true;
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;

      const entradaMoeda = (valor, rotulo, dica, aoMudar) => {
        const inp = document.createElement('input');
        inp.inputMode = 'decimal';
        inp.value = Util.moeda(valor);
        inp.setAttribute('aria-label', rotulo);
        inp.dataset.dica = dica;
        inp.addEventListener('change', () => {
          const v = Util.lerMoeda(inp.value);
          aoMudar(isNaN(v) ? NaN : r2(v));
          mudou = true;
        });
        return inp;
      };

      function desenhar() {
        corpo.replaceChildren();
        for (const it of itens) {
          const l = it.l;
          const nome = 'parcela ' + l.NUMERO + '/' + l.QTD_PARCELAS;
          const tr = Util.el('tr', l.BLOQUEIA_BAIXA ? 'linha-bloqueada' : null);
          const tdParc = Util.el('td', 'baixa-parcela');
          const titulo = Util.el('div', null, (l.BLOQUEIA_BAIXA ? '🔒 ' : '') + (l.PESSOA || '(sem parceiro)'));
          if (l.BLOQUEIA_BAIXA) titulo.dataset.dica = 'Baixa bloqueada por pendência: ' + (l.MOTIVO_BLOQUEIO || '') + (l.PODE_LIBERAR_PENDENCIA ? '. Você pode liberar, informando a justificativa ao gravar.' : '. Resolva a pendência na ficha do lançamento.');
          const sub = Util.el('div', 'sub', 'Nº ' + l.ID_LANCAMENTO + ' · ' + nome + (l.DOCUMENTO ? ' · doc. ' + l.DOCUMENTO : ''));
          tdParc.append(titulo, sub);
          const atraso = Number(l.DIAS_ATRASO) > 0 ? l.DIAS_ATRASO + (Number(l.DIAS_ATRASO) === 1 ? ' dia' : ' dias') : '';
          const tdPrinc = Util.el('td', 'numero');
          tdPrinc.append(entradaMoeda(it.principal, 'Valor quitado da ' + nome,
            'Quanto desta parcela fica quitado. Obrigatório. Menor que o saldo = baixa parcial (o resto continua em aberto). Não pode passar do saldo.',
            (v) => { it.principal = v; if (!isNaN(v)) sugerir(it); desenhar(); }));
          const tdJuros = Util.el('td', 'numero');
          const regra = l.CALCULA ? ' Sugerido: ' + Number(l.JUROS_PERC).toLocaleString('pt-BR') + '% ao mês, proporcional aos dias de atraso.' : '';
          tdJuros.append(entradaMoeda(it.juros, 'Juros da ' + nome, 'Juros pelo atraso.' + regra + ' Pode mudar: valor diferente do calculado pede confirmação ao gravar.',
            (v) => { it.juros = v; it.encargoManual = true; desenhar(); }));
          const tdMulta = Util.el('td', 'numero');
          tdMulta.append(entradaMoeda(it.multa, 'Multa da ' + nome,
            'Multa pelo atraso.' + (l.CALCULA ? (multaDevida(it) ? ' Sugerida: ' + Number(l.MULTA_PERC).toLocaleString('pt-BR') + '% do valor quitado.' : ' A multa já foi cobrada numa baixa anterior desta parcela.') : '')
            + ' Pode mudar: valor diferente do calculado pede confirmação ao gravar.',
            (v) => { it.multa = v; it.encargoManual = true; desenhar(); }));
          const tdDesc = Util.el('td', 'numero');
          const limite = l.DESCONTO_LIMITE === null || l.DESCONTO_LIMITE === undefined ? null : Number(l.DESCONTO_LIMITE);
          tdDesc.append(entradaMoeda(it.desconto, 'Desconto da ' + nome,
            'Desconto concedido (opcional).' + (limite !== null ? ' Limite: ' + Util.moeda(limite) + '; acima disso só com a permissão "Desconto na baixa acima do limite" e o motivo.' : ''),
            (v) => { it.desconto = v; desenhar(); }));
          const total = isNaN(it.principal + it.juros + it.multa + it.desconto) ? NaN : (c(it.principal) + c(it.juros) + c(it.multa) - c(it.desconto)) / 100;
          tr.append(tdParc, Util.el('td', null, dataBr(l.DT_VENCIMENTO)), Util.el('td', 'numero', atraso), Util.el('td', 'numero', Util.moeda(l.SALDO)),
            tdPrinc, tdJuros, tdMulta, tdDesc, Util.el('td', 'numero baixa-total-linha', isNaN(total) ? '—' : Util.moeda(total)));
          corpo.append(tr);
        }
        // rodapé com os totais
        const soma = (f) => itens.reduce((s, it) => s + c(it[f]), 0) / 100;
        const liquido = (itens.reduce((s, it) => s + c(it.principal) + c(it.juros) + c(it.multa) - c(it.desconto), 0)) / 100;
        const tar = Util.lerMoeda(tarifa.value);
        rodape.replaceChildren();
        const parte = (rot, val, classe) => { const s = Util.el('span', classe || null); s.append(Util.el('span', 'suave', rot + ': '), Util.el('strong', 'numero', Util.moeda(val))); rodape.append(s); };
        parte('Quitado', soma('principal'));
        parte('Juros e multa', soma('juros') + soma('multa'));
        parte('Descontos', soma('desconto'));
        parte(pagar ? 'Sai da conta' : 'Entra na conta', liquido, 'baixa-liquido');
        if (!isNaN(tar) && tar > 0) parte('Tarifa (sai à parte)', tar);
        // faixa da pendência que bloqueia
        const bloq = itens.filter((it) => it.l.BLOQUEIA_BAIXA);
        if (bloq.length) {
          const podeLiberar = bloq.every((it) => it.l.PODE_LIBERAR_PENDENCIA);
          faixa.textContent = '🔒 ' + bloq.length + (bloq.length === 1 ? ' parcela tem pendência' : ' parcelas têm pendência') + ' que bloqueia a baixa'
            + (podeLiberar ? ': ao gravar, o sistema pede a justificativa para liberar.' : ': resolva a pendência na ficha do lançamento ou peça a quem pode liberar.');
          faixa.hidden = false;
        } else faixa.hidden = true;
      }

      tarifa.addEventListener('change', () => {
        const v = Util.lerMoeda(tarifa.value);
        if (!isNaN(v)) tarifa.value = Util.moeda(v);
        mudou = true;
        desenhar();
      });
      dtPag.addEventListener('change', async () => {
        if (!dtPag.value) return;
        mudou = true;
        const novas = await preparar(lista, dtPag.value);
        if (!novas) { dtPag.value = data; return; }
        data = dtPag.value;
        for (const it of itens) {
          const n = novas.find((x) => x.ID_PARCELA === it.l.ID_PARCELA);
          if (n) { it.l = n; sugerir(it); }
        }
        desenhar();
      });

      // ---------- botões ----------
      const barra = Util.el('div', 'janela-botoes');
      const fechar = (valor) => { janela.close(); janela.remove(); resolver(valor); };
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      cancelar.dataset.dica = 'Fecha a janela sem baixar (Esc).';
      const ok = Util.el('button', 'botao botao-principal', pagar ? 'Pagar' : 'Receber');
      ok.type = 'button';
      ok.dataset.dica = 'Confere e grava a baixa (Ctrl+S). Antes de gravar, o sistema mostra os avisos que precisarem de confirmação.';
      barra.append(cancelar, ok);

      async function sair() {
        if (mudou && !(await Mensagens.confirmar('Descartar a baixa?', 'O que foi preenchido nesta janela será perdido.', 'Descartar'))) return;
        fechar(false);
      }
      cancelar.addEventListener('click', sair);
      janela.addEventListener('cancel', (e) => {
        e.preventDefault();
        if (janela.querySelector('.seletor-lista:not([hidden])')) return;
        sair();
      });
      janela.addEventListener('keydown', (e) => {
        if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); e.stopPropagation(); ok.click(); }
      });

      const mostrarErro = (texto, foco) => { erro.textContent = texto; erro.hidden = false; if (foco) foco.focus(); return false; };
      function focarCampo(nome) {
        if (nome === 'dtPagamento' || nome === 'data') dtPag.focus();
        else if (nome === 'conta' || nome === 'idConta') seletorConta.focar();
        else if (nome === 'forma') selForma.focus();
        else if (nome === 'tarifa') tarifa.focus();
      }
      function conferir() {
        erro.hidden = true;
        if (!dtPag.value) return mostrarErro('Informe a data do ' + (pagar ? 'pagamento' : 'recebimento') + '.', dtPag);
        if (!seletorConta.valor()) { seletorConta.focar(); return mostrarErro('Escolha a conta.'); }
        if (!selForma.value) return mostrarErro('Escolha a forma.', selForma);
        const tar = Util.lerMoeda(tarifa.value);
        if (isNaN(tar) || tar < 0) return mostrarErro('A tarifa tem que ser um valor de zero para cima.', tarifa);
        for (const it of itens) {
          const nome = 'Parcela ' + it.l.NUMERO + '/' + it.l.QTD_PARCELAS + ' (nº ' + it.l.ID_LANCAMENTO + ')';
          if (isNaN(it.principal) || it.principal <= 0) return mostrarErro(nome + ': informe o valor ' + (pagar ? 'pago' : 'recebido') + ' (maior que zero).');
          if (c(it.principal) > c(it.l.SALDO)) return mostrarErro(nome + ': o valor ' + Util.moeda(it.principal) + ' passa do saldo em aberto ' + Util.moeda(it.l.SALDO) + '.');
          if ([it.juros, it.multa, it.desconto].some((v) => isNaN(v) || v < 0)) return mostrarErro(nome + ': juros, multa e desconto têm que ser valores de zero para cima.');
          if (c(it.desconto) > c(it.principal) + c(it.juros) + c(it.multa)) return mostrarErro(nome + ': o desconto passa do valor da linha.');
        }
        return true;
      }

      ok.addEventListener('click', async () => {
        if (!conferir()) return;
        const tar = r2(Util.lerMoeda(tarifa.value));
        const liquido = itens.reduce((s, it) => s + c(it.principal) + c(it.juros) + c(it.multa) - c(it.desconto), 0) / 100;
        const parciais = itens.filter((it) => c(it.principal) < c(it.l.SALDO)).length;
        const conta = seletorConta.item();
        const texto = 'Confirma o ' + (pagar ? 'pagamento' : 'recebimento') + ' de ' + Util.moeda(liquido) + ' (' + itens.length + (itens.length === 1 ? ' parcela' : ' parcelas')
          + (parciais ? ', ' + parciais + ' parcial' + (parciais === 1 ? '' : 'is') : '') + ') em ' + dataBr(dtPag.value)
          + ' na conta ' + (conta ? conta.DESCRICAO : '') + (tar > 0 ? ', com tarifa de ' + Util.moeda(tar) : '') + '?';
        if (!(await Mensagens.confirmar('Gravar?', texto, pagar ? 'Pagar' : 'Receber'))) return;
        const corpoPedido = {
          dtPagamento: dtPag.value, idConta: seletorConta.valor(), forma: selForma.value,
          itens: itens.map((it, i) => ({ idParcela: it.l.ID_PARCELA, principal: it.principal, juros: it.juros, multa: it.multa, correcao: 0,
            desconto: it.desconto, abatimento: 0, retencao: 0, tarifa: i === 0 ? tar : 0 })),
          documento: doc.value.trim(), observacao: obs.value.trim(), avisosConfirmados: [], motivo: null
        };
        ok.disabled = true;
        try {
          for (let tentativa = 0; tentativa < 3; tentativa++) {
            const r = await Api.post('/api/fin/baixas', corpoPedido);
            if (r.sucesso) {
              janela.close(); janela.remove();
              await Mensagens.concluido(r.mensagem || 'Baixa gravada.');
              resolver(true);
              return;
            }
            const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
            if (!avisos.length) { await Mensagens.tratar(r); return; }
            const resposta = await Mensagens.avisos(avisos, { titulo: 'Confira antes de ' + (pagar ? 'pagar' : 'receber') });
            if (!resposta) { const primeiro = avisos.find((a) => a.campo); if (primeiro) focarCampo(primeiro.campo); return; }
            corpoPedido.avisosConfirmados = [...new Set([...corpoPedido.avisosConfirmados, ...resposta.confirmados])];
            if (resposta.motivo) corpoPedido.motivo = resposta.motivo;
          }
          await Mensagens.alerta('Os avisos mudaram durante a gravação. Confira os dados e grave de novo.', 'ATENCAO');
        } finally {
          ok.disabled = false;
        }
      });

      janela.append(topo, grade, faixa, rolagem, rodape, erro, barra);
      document.body.append(janela);
      desenhar();
      janela.showModal();
      const idConta = abertas.map((l) => l.ID_CONTA_SUGERIDA).find(Boolean);
      (idConta ? seletorConta.definir(idConta) : Promise.resolve()).then(() => { if (idConta) selForma.focus(); else seletorConta.focar(); });
    });
  }

  // ---------- 04g3b: estorno ----------
  async function estornar({ idBaixa, descricao }) {
    let previa = null;   // { qtd, valor, motivoRetro, bloqueio }
    return new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'janela-estorno-titulo');
      const topo = Util.el('div', 'janela-topo');
      const h2 = Util.el('h2', null, 'Estornar baixa');
      h2.id = 'janela-estorno-titulo';
      topo.append(h2);
      const explica = Util.el('p', 'janela-texto', 'Baixa: ' + (descricao || 'nº ' + idBaixa) + '. Nada é apagado: a baixa ganha um lançamento de estorno, o movimento da conta ganha um movimento inverso e a parcela volta a ficar em aberto.');
      const grade = Util.el('div', 'grade');
      const dt = document.createElement('input');
      dt.type = 'date';
      dt.value = hojeIso();
      const labDt = Util.el('label', 'campo', 'Data do estorno *');
      labDt.dataset.dica = 'Dia em que o estorno entra no extrato da conta. Obrigatória (padrão hoje). Valem as travas de data, de mês fechado e de caixa fechado nesse dia.';
      labDt.append(dt);
      const motivo = document.createElement('textarea');
      motivo.rows = 3;
      motivo.maxLength = 400;
      const labMot = Util.el('label', 'campo s-3', 'Motivo *');
      labMot.dataset.dica = 'Por que a baixa está sendo estornada (ex.: baixa em dobro, valor errado, cheque devolvido). Obrigatório, pelo menos 5 letras. Fica registrado.';
      labMot.append(motivo);
      grade.append(labDt, labMot);
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
        previa = null;
        if (!dt.value) { erro.textContent = 'Informe a data do estorno.'; erro.hidden = false; return; }
        const r = await Api.post('/api/fin/baixas/' + idBaixa + '/estornar/conferir', { motivo: motivo.value.trim() || null, dtEstorno: dt.value });
        const d = r.dados || {};
        const avisos = Array.isArray(d.avisos) ? d.avisos : [];
        const bloqueio = avisos.find((a) => a.nivel === 'BLOQUEIO');
        if (!r.sucesso && (bloqueio || !avisos.length)) {
          if (!avisos.length && r.tipo !== 'ATENCAO' && r.tipo !== 'PENDENTE') { await Mensagens.tratar(r); fechar(false); return; }
          erro.textContent = bloqueio ? bloqueio.mensagem : (r.mensagem || 'Não dá para estornar esta baixa.');
          erro.hidden = false;
          return;
        }
        previa = { qtd: Number(d.qtdBaixas || 1), valor: Number(d.valor || 0), motivoRetro: avisos.some((a) => a.nivel === 'MOTIVO') };
        const partes = [];
        if (previa.qtd > 1) partes.push('Esta baixa foi paga junto com outras (pagamento em lote): as ' + previa.qtd + ' baixas do mesmo pagamento, inclusive de outros lançamentos, e a tarifa serão estornadas juntas.');
        partes.push('Valor estornado: ' + Util.moeda(previa.valor) + '.');
        if (previa.motivoRetro) partes.push('A data está fora da trava de datas: o motivo do estorno fica registrado também como justificativa.');
        info.textContent = partes.join(' ');
        info.hidden = false;
        ok.disabled = false;
      }
      dt.addEventListener('change', conferir);

      ok.addEventListener('click', async () => {
        const m = motivo.value.trim();
        if (m.length < 5) { erro.textContent = 'Informe o motivo do estorno (pelo menos 5 letras).'; erro.hidden = false; motivo.focus(); return; }
        if (!previa) return;
        const texto = 'Confirma o estorno de ' + Util.moeda(previa.valor) + (previa.qtd > 1 ? ' (' + previa.qtd + ' baixas do mesmo pagamento)' : '')
          + ' com data de ' + dataBr(dt.value) + '? A parcela volta a ficar em aberto.';
        if (!(await Mensagens.confirmar('Estornar?', texto, 'Estornar'))) return;
        ok.disabled = true;
        try {
          const r = await Api.post('/api/fin/baixas/' + idBaixa + '/estornar', { motivo: m, dtEstorno: dt.value });
          if (!r.sucesso) {
            const avisos = r.dados && Array.isArray(r.dados.avisos) ? r.dados.avisos : [];
            if (avisos.length) { erro.textContent = avisos.map((a) => a.mensagem).join(' '); erro.hidden = false; }
            else await Mensagens.tratar(r);
            return;
          }
          janela.close(); janela.remove();
          await Mensagens.concluido(r.mensagem || 'Baixa estornada.');
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
    });
  }

  return { abrir, estornar };
})();
