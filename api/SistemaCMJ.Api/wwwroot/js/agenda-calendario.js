/* =============================================================================
   SistemaCMJ - js/agenda-calendario.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04h3)
   Descrição : Visão calendário da agenda financeira (tela inicial, P03/P04).
               Desenha os quadros que vêm do /api/fin/agenda/periodos:
                 - modo DIA (semana, quinzena, mês e datas escolhidas até
                   62 dias): grade de segunda a domingo; dias fora do
                   período ficam apagados;
                 - modo MES: um quadro por mês (bimestre, trimestre e
                   quadrimestre lado a lado; ano em 4 × 3; datas escolhidas
                   longas); em "Vários anos" (opção anos: true) uma faixa
                   por ano com os 12 meses e o total do ano na faixa;
               Em cada quadro: D, C e S alinhados à direita (cores do P03),
               saldo previsto em letra menor, contagem a pagar / a receber,
               hoje em destaque, borda vermelha quando há vencida em aberto
               e marca de previsão. Sem VER_TOTAIS (P04) só as contagens.
               Mapa de calor discreto (sugestão aprovada na 04h3): o fundo
               fica mais forte nos quadros de maior saída (D; de entrada C
               quando a tela mostra só a receber). Por classe (calor-1 a
               calor-4): a política de segurança não aceita estilo no HTML.
               Quadro com contas é botão: aoClicar(quadro) abre a lista dele.
               Dica ao passar o mouse (sugestão aprovada na 04h3): as 3
               maiores contas do quadro e "e mais N" (AgendaCalendario.dicas,
               com as linhas do /lista do período).
               Uso: AgendaCalendario.desenhar(alvo, { quadros, modo, ini,
               fim, resumo, tipo, anos, aoClicar }) e
               AgendaCalendario.dicas(alvo, linhas).
   Changelog:
     v1.0 (27/11/2026) - Modo DIA (etapa 04h3a).
     v1.1 (27/11/2026) - Modo MES, faixas por ano (etapa 04h3b).
     v1.2 (27/11/2026) - Clique no quadro e dica das 3 maiores (04h3c).
   ========================================================================== */
'use strict';

const AgendaCalendario = (() => {
  const SEMANA = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  const NOMES_MES = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
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
    const temConta = (m.d && Number(q.QTD_PAGAR) > 0) || (m.c && Number(q.QTD_RECEBER) > 0);
    const clicavel = typeof opcoes.aoClicar === 'function' && temConta;
    const caixa = Util.el(clicavel ? 'button' : 'div', 'cal-quadro' + (classeExtra ? ' ' + classeExtra : ''));
    if (clicavel) {
      caixa.type = 'button';
      caixa.addEventListener('click', () => opcoes.aoClicar(q, titulo));
      caixa.dataset.de = Util.dataIso(q.INICIO);
      caixa.dataset.ate = Util.dataIso(q.FIM);
      caixa.dataset.dica = 'Clique para ver a lista deste ' + (opcoes.modo === 'DIA' ? 'dia.' : 'período.');
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

  /** Título do quadro do mês: "Janeiro", "jan/2027" ou "10 a 30 nov" quando o período corta o mês. */
  function tituloMes(q, comAno) {
    const i = lerIso(q.INICIO);
    const f = lerIso(q.FIM);
    const inteiro = i.getDate() === 1 && somarDias(f, 1).getDate() === 1;
    if (!inteiro) return i.getDate() + ' a ' + f.getDate() + ' ' + MESES[i.getMonth()] + (comAno ? '/' + i.getFullYear() : '');
    return comAno ? MESES[i.getMonth()] + '/' + i.getFullYear() : NOMES_MES[i.getMonth()];
  }

  /** Soma de vários quadros (total do ano na faixa de "Vários anos"). */
  function somar(qs) {
    const t = { QTD_PAGAR: 0, QTD_RECEBER: 0, QTD_VENCIDAS: 0, QTD_PREVISAO: 0, TOTAL_D: 0, TOTAL_C: 0, SALDO: 0 };
    for (const q of qs) for (const k of Object.keys(t)) t[k] += Number(q[k]) || 0;
    t.SALDO_PREVISTO = qs.length ? qs[qs.length - 1].SALDO_PREVISTO : null;
    return t;
  }

  /** Modo MES: quadros por mês; em vários anos, uma faixa por ano. */
  function desenharMeses(alvo, opcoes, m) {
    const quadros = [...(opcoes.quadros || [])].sort((a, b) => a.ORDEM - b.ORDEM);
    const caixas = [];
    const variosAnos = new Set(quadros.map((q) => lerIso(q.INICIO).getFullYear())).size > 1;
    const montar = (lista, colunas, comAno) => {
      const grade = Util.el('div', 'cal-grade cal-grade-meses cal-colunas-' + colunas);
      if (!m.d) grade.classList.add('cal-calor-c');
      for (const q of lista) {
        const caixa = quadro(q, m, opcoes, tituloMes(q, comAno), 'cal-mes' + (lerIso(q.FIM) < hoje() ? ' cal-passado' : ''));
        caixas.push([q, caixa]);
        grade.append(caixa);
      }
      return grade;
    };
    if (opcoes.anos) {
      const porAno = new Map();
      for (const q of quadros) {
        const a = lerIso(q.INICIO).getFullYear();
        if (!porAno.has(a)) porAno.set(a, []);
        porAno.get(a).push(q);
      }
      for (const [ano, lista] of porAno) {
        const faixa = Util.el('section', 'cal-faixa-ano');
        const cab = Util.el('div', 'cal-faixa-cabeca');
        cab.append(Util.el('h3', 'cal-faixa-titulo', String(ano)));
        const total = somar(lista);
        const resumoAno = Util.el('div', 'cal-faixa-total');
        if (m.totais) {
          if (m.d) resumoAno.append(Util.el('span', 'valor-d', 'D ' + Util.moeda(total.TOTAL_D)));
          if (m.c) resumoAno.append(Util.el('span', 'valor-c', 'C ' + Util.moeda(total.TOTAL_C)));
          if (m.s) resumoAno.append(Util.el('span', 'cal-faixa-saldo ' + (total.SALDO < 0 ? 'valor-d' : 'valor-c'), 'S ' + Util.moeda(total.SALDO)));
          if (m.previsto && total.SALDO_PREVISTO != null) resumoAno.append(Util.el('span', 'cal-faixa-previsto', 'previsto no fim ' + Util.moeda(total.SALDO_PREVISTO)));
        }
        const qtds = [];
        if (m.d) qtds.push(qtd(total.QTD_PAGAR, 'a pagar', 'a pagar'));
        if (m.c) qtds.push(qtd(total.QTD_RECEBER, 'a receber', 'a receber'));
        resumoAno.append(Util.el('span', 'cal-qtd', qtds.join(' · ')));
        cab.append(resumoAno);
        faixa.append(cab, montar(lista, 6, false));
        alvo.append(faixa);
      }
    } else {
      const colunas = quadros.length <= 4 ? Math.max(1, quadros.length) : 4;
      alvo.append(montar(quadros, colunas, variosAnos));
    }
    aplicarCalor(caixas, m);
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
    if (opcoes.modo === 'DIA') desenharDias(alvo, opcoes, m);
    else desenharMeses(alvo, opcoes, m);
    alvo.append(legenda(m));
  }

  /** Dica de cada quadro: as 3 maiores contas e "e mais N" (linhas do /lista do período). */
  function dicas(alvo, linhas) {
    const quadros = [...alvo.querySelectorAll('button.cal-quadro[data-de]')];
    if (!quadros.length || !linhas || !linhas.length) return;
    const ordenadas = [...linhas].sort((a, b) => Number(b.VALOR_AGENDA) - Number(a.VALOR_AGENDA));
    for (const caixa of quadros) {
      const { de, ate } = caixa.dataset;
      const doQuadro = ordenadas.filter((l) => { const d = Util.dataIso(l.DT_VENCIMENTO); return d >= de && d <= ate; });
      if (!doQuadro.length) continue;
      const texto = ['Maiores contas:'];
      for (const l of doQuadro.slice(0, 3)) {
        texto.push((l.TIPO === 'P' ? 'Pagar' : 'Receber') + ' · ' + (l.PESSOA_NOME || '(sem parceiro)') + ' · ' + Util.moeda(l.VALOR_AGENDA)
          + (de !== ate ? ' (' + Util.data(l.DT_VENCIMENTO).substring(0, 5) + ')' : ''));
      }
      if (doQuadro.length > 3) texto.push('e mais ' + (doQuadro.length - 3));
      texto.push('Clique para ver a lista.');
      caixa.dataset.dica = texto.join('\n');
    }
  }

  return { desenhar, dicas };
})();
