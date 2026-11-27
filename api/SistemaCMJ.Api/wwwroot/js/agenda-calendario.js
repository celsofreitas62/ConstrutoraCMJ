/* =============================================================================
   SistemaCMJ - js/agenda-calendario.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04h3)
   Descrição : Visão calendário da agenda financeira (tela inicial, P03/P04).
               Desenha os quadros que vêm do /api/fin/agenda/periodos:
                 - modo DIA (semana, quinzena, mês): grade de segunda a
                   domingo; dias fora do período ficam apagados;
               Em cada quadro: D, C e S alinhados à direita (cores do P03),
               saldo previsto em letra menor, contagem a pagar / a receber,
               hoje em destaque, borda vermelha quando há vencida em aberto
               e marca de previsão. Sem VER_TOTAIS (P04) só as contagens.
               Mapa de calor discreto (sugestão aprovada na 04h3): o fundo
               fica mais forte nos quadros de maior saída (D; de entrada C
               quando a tela mostra só a receber). Por classe (calor-1 a
               calor-4): a política de segurança não aceita estilo no HTML.
               Uso: AgendaCalendario.desenhar(alvo, { quadros, modo, ini,
               fim, resumo, tipo, aoClicar }).
   Changelog:
     v1.0 (27/11/2026) - Modo DIA (etapa 04h3a).
   ========================================================================== */
'use strict';

const AgendaCalendario = (() => {
  const SEMANA = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  const MESES = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  const iso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  const lerIso = (t) => { const [a, m, d] = String(t).substring(0, 10).split('-').map(Number); return new Date(a, m - 1, d); };
  const somarDias = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  const hoje = () => { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), d.getDate()); };
  const qtd = (n, um, varios) => (Number(n) === 1 ? '1 ' + um : (Number(n) || 0) + ' ' + varios);

  /** O que a tela mostra: D, C e S conforme a permissão e o filtro "Mostrar". */
  function mostra(resumo, tipo) {
    const d = !!resumo.VER_PAGAR && tipo !== 'R';
    const c = !!resumo.VER_RECEBER && tipo !== 'P';
    return { d, c, s: d && c, totais: !!resumo.VER_TOTAIS, previsto: !!resumo.SALDO_ACUMULADO };
  }

  /** Nível do mapa de calor (0 a 4) pelo valor do quadro diante do maior da tela. */
  function nivelCalor(valor, maior) {
    if (!(valor > 0) || !(maior > 0)) return 0;
    return Math.min(4, Math.max(1, Math.ceil((valor / maior) * 4)));
  }
  function medidaCalor(q, m) {
    if (m.d) return m.totais ? Number(q.TOTAL_D) || 0 : Number(q.QTD_PAGAR) || 0;
    if (m.c) return m.totais ? Number(q.TOTAL_C) || 0 : Number(q.QTD_RECEBER) || 0;
    return 0;
  }

  /** Conteúdo comum de um quadro (dia, mês ou grupo de meses). */
  function conteudo(caixa, q, m) {
    const qp = m.d ? Number(q.QTD_PAGAR) || 0 : 0;
    const qr = m.c ? Number(q.QTD_RECEBER) || 0 : 0;
    if (!qp && !qr) { caixa.classList.add('cal-vazio'); return; }

    if (m.totais) {
      const valores = Util.el('div', 'cal-valores');
      const linha = (rotulo, valor, classe) => {
        const l = Util.el('div', 'cal-linha ' + (Number(valor) === 0 ? 'cal-zero' : classe));
        l.append(Util.el('span', 'cal-letra', rotulo), Util.el('span', 'cal-numero', Util.moeda(valor)));
        valores.append(l);
      };
      if (m.d) linha('D', q.TOTAL_D, 'valor-d');
      if (m.c) linha('C', q.TOTAL_C, 'valor-c');
      if (m.s) linha('S', q.SALDO, Number(q.SALDO) < 0 ? 'valor-d cal-saldo' : 'valor-c cal-saldo');
      caixa.append(valores);
    }
    const partes = [];
    if (m.d && qp) partes.push(qtd(qp, 'a pagar', 'a pagar'));
    if (m.c && qr) partes.push(qtd(qr, 'a receber', 'a receber'));
    caixa.append(Util.el('div', 'cal-qtd', partes.join(' · ')));

    const marcas = Util.el('div', 'cal-marcas');
    if (q.QTD_VENCIDAS > 0) { caixa.classList.add('cal-tem-vencida'); marcas.append(Util.el('span', 'cal-marca cal-marca-vencida', qtd(q.QTD_VENCIDAS, 'vencida', 'vencidas'))); }
    if (q.QTD_PREVISAO > 0) marcas.append(Util.el('span', 'cal-marca cal-marca-previsao', qtd(q.QTD_PREVISAO, 'previsão', 'previsões')));
    if (marcas.childElementCount) caixa.append(marcas);
    if (m.totais && m.previsto && q.SALDO_PREVISTO != null) {
      caixa.append(Util.el('div', 'cal-previsto' + (Number(q.SALDO_PREVISTO) < 0 ? ' valor-d' : ''), 'prev. ' + Util.moeda(q.SALDO_PREVISTO)));
    }
  }

  /** Quadro clicável (botão) ou só leitura (div). */
  function quadro(q, m, opcoes, titulo, classeExtra) {
    const clicavel = typeof opcoes.aoClicar === 'function';
    const caixa = Util.el(clicavel ? 'button' : 'div', 'cal-quadro' + (classeExtra ? ' ' + classeExtra : ''));
    if (clicavel) {
      caixa.type = 'button';
      caixa.addEventListener('click', () => opcoes.aoClicar(q));
    }
    const topo = Util.el('div', 'cal-topo');
    topo.append(Util.el('span', 'cal-titulo', titulo));
    if (q.TEM_HOJE) { caixa.classList.add('cal-hoje'); topo.append(Util.el('span', 'etiqueta-hoje', 'Hoje')); }
    caixa.append(topo);
    conteudo(caixa, q, m);
    return caixa;
  }

  function aplicarCalor(caixas, m) {
    const maior = Math.max(0, ...caixas.map(([q]) => medidaCalor(q, m)));
    for (const [q, caixa] of caixas) {
      const n = nivelCalor(medidaCalor(q, m), maior);
      if (n) caixa.classList.add('calor-' + n);
    }
  }

  /** Modo DIA: grade de segunda a domingo do período. */
  function desenharDias(alvo, opcoes, m) {
    const ini = lerIso(opcoes.ini);
    const fim = lerIso(opcoes.fim);
    const porDia = new Map((opcoes.quadros || []).map((q) => [Util.dataIso(q.INICIO), q]));
    const comeco = somarDias(ini, -((ini.getDay() + 6) % 7));
    const termino = somarDias(fim, (7 - fim.getDay()) % 7);
    const grade = Util.el('div', 'cal-grade cal-grade-dias');
    if (!m.d) grade.classList.add('cal-calor-c');
    for (const nome of SEMANA) grade.append(Util.el('div', 'cal-cabeca', nome));
    const caixas = [];
    const h = hoje();
    for (let d = comeco; d <= termino; d = somarDias(d, 1)) {
      const q = porDia.get(iso(d));
      const fimDeSemana = d.getDay() === 0 || d.getDay() === 6;
      const titulo = d.getDate() === 1 || d.getTime() === comeco.getTime() ? d.getDate() + ' ' + MESES[d.getMonth()] : String(d.getDate());
      if (!q) {
        grade.append(Util.el('div', 'cal-quadro cal-fora', titulo));
        continue;
      }
      const caixa = quadro(q, m, opcoes, titulo, (fimDeSemana ? 'cal-fim-semana' : '') + (d < h ? ' cal-passado' : ''));
      caixa.setAttribute('aria-label', d.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' }));
      caixas.push([q, caixa]);
      grade.append(caixa);
    }
    aplicarCalor(caixas, m);
    alvo.append(grade);
  }

  function legenda(m) {
    const l = Util.el('div', 'cal-legenda');
    const base = m.d ? 'saída (D)' : 'entrada (C)';
    l.append(Util.el('span', 'cal-legenda-calor'), Util.el('span', null, 'Fundo mais forte = mais ' + base + (m.totais ? '' : ' em quantidade')));
    l.append(Util.el('span', 'cal-legenda-vencida'), Util.el('span', null, 'tem vencida em aberto'));
    return l;
  }

  function desenhar(alvo, opcoes) {
    alvo.replaceChildren();
    const m = mostra(opcoes.resumo || {}, opcoes.tipo || '');
    desenharDias(alvo, opcoes, m);
    alvo.append(legenda(m));
  }

  return { desenhar };
})();
