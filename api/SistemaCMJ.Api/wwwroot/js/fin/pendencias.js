/* =============================================================================
   SistemaCMJ - js/fin/pendencias.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 26/11/2026 (etapa 04f2c2, P27)
   Descrição : Quadro de Pendências da ficha do lançamento (componente único).
               Automáticas (calculadas pelo banco, FIN.fn_FIN_Lancamento_
               Pendencias): só leitura, com o "como resolver" e um atalho para
               o campo ou a aba certa; somem sozinhas quando o dado é corrigido.
               Manuais (FIN.Lancamento_Pendencia): Resolver (com nota),
               Alterar (tipo, parcela, responsável, previsão, observação; ou
               tirar a lançada por engano) e Reabrir. "+ Pendência" só com a
               ação PENDENCIA (o banco confere de novo). Previsão com atalhos
               Amanhã / +7 dias / Fim do mês.
               Uso:
                 const q = Pendencias.criar(elemento, { idLancamento, tipo,
                   podeIncluir, parcelas: () => [{ id, numero, total, vencimento }],
                   irPara: (codigo) => {...}, aoMudar: (linhas) => {...} });
                 await q.carregar();
   ========================================================================== */
'use strict';

const Pendencias = (() => {
  const hojeIso = () => { const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().substring(0, 10); };
  const somarDias = (dias) => { const d = new Date(); d.setDate(d.getDate() + dias); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().substring(0, 10); };
  const fimDoMes = () => { const h = new Date(); const d = new Date(h.getFullYear(), h.getMonth() + 1, 0); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().substring(0, 10); };

  // Atalho de cada regra automática (o texto do "como resolver" vem do banco)
  const ATALHOS = {
    SEM_CENTRO: 'Ir para o centro de custo',
    SEM_PLANO: 'Ir para a conta do plano',
    SEM_DOCUMENTO: 'Ir para o documento',
    SEM_ANEXO: 'Abrir a aba Anexos',
    NAO_APTO: 'Abrir o cadastro do parceiro',
    VENCIDA: 'Ver as parcelas'
  };

  function criar(alvo, opcoes) {
    const { idLancamento, tipo, podeIncluir = false, parcelas = () => [], irPara = () => {}, aoMudar = () => {} } = opcoes;
    let tipos = null;          // tipos manuais (carregados na primeira vez que precisar)
    let responsaveis = null;
    let linhas = [];

    alvo.classList.add('quadro-pendencias');
    const topo = Util.el('div', 'quadro-pendencias-topo');
    const titulo = Util.el('h2', null, 'Pendências');
    const incluir = Util.el('button', 'botao botao-contorno', '+ Pendência');
    incluir.type = 'button';
    incluir.dataset.dica = 'Anota algo que falta resolver neste lançamento (ex.: aguardando nota fiscal), com responsável e previsão. Alguns tipos bloqueiam a baixa até serem resolvidos.';
    incluir.hidden = !podeIncluir;
    incluir.addEventListener('click', () => abrirJanela(null));
    topo.append(titulo, incluir);
    const corpo = Util.el('div', 'quadro-pendencias-corpo');
    alvo.replaceChildren(topo, corpo);

    async function carregar() {
      const r = await Api.get('/api/fin/lancamentos/' + idLancamento + '/pendencias', { incluirResolvidas: true });
      if (!(await Mensagens.tratar(r))) return false;
      linhas = r.dados || [];
      desenhar();
      aoMudar(linhas);
      return true;
    }

    function desenhar() {
      corpo.replaceChildren();
      const abertas = linhas.filter((l) => l.SITUACAO === 'ABERTA');
      const resolvidas = linhas.filter((l) => l.SITUACAO !== 'ABERTA');
      titulo.textContent = 'Pendências' + (abertas.length ? ' (' + abertas.length + ')' : '');
      alvo.classList.toggle('com-pendencia', abertas.length > 0);
      if (!abertas.length) corpo.append(Util.el('p', 'suave', 'Nenhuma pendência aberta neste lançamento.'));
      else {
        const ul = Util.el('ul', 'lista-pendencias');
        for (const l of abertas) ul.append(item(l));
        corpo.append(ul);
      }
      if (resolvidas.length) {
        const det = document.createElement('details');
        det.className = 'pendencias-resolvidas';
        det.append(Util.el('summary', null, 'Resolvidas (' + resolvidas.length + ')'));
        const ul = Util.el('ul', 'lista-pendencias');
        for (const l of resolvidas) ul.append(item(l));
        det.append(ul);
        corpo.append(det);
      }
    }

    function item(l) {
      const auto = l.ORIGEM === 'AUTOMATICA';
      const li = Util.el('li', 'pendencia-item' + (l.SITUACAO !== 'ABERTA' ? ' resolvida' : '') + (l.ATRASADA ? ' atrasada' : '') + (l.BLOQUEIA_BAIXA && l.SITUACAO === 'ABERTA' ? ' bloqueia' : ''));
      const linha1 = Util.el('div', 'pendencia-linha');
      linha1.append(Util.el('span', 'pendencia-origem', auto ? 'Automática' : 'Manual'));
      linha1.append(Util.el('strong', null, (l.BLOQUEIA_BAIXA && l.SITUACAO === 'ABERTA' ? '🔒 ' : '') + l.DESCRICAO));
      if (l.PARCELA) linha1.append(Util.el('span', 'suave', 'parcela ' + l.PARCELA));
      li.append(linha1);

      const info = [];
      if (!auto) {
        if (l.RESPONSAVEL) info.push('Responsável: ' + l.RESPONSAVEL);
        if (l.DT_PREVISAO) info.push('Previsão: ' + Util.data(l.DT_PREVISAO) + (l.ATRASADA ? ' (já passou)' : ''));
        if (l.USUARIO_CRIACAO) info.push('Lançada por ' + l.USUARIO_CRIACAO + (l.DT_CRIACAO ? ' em ' + Util.dataHora(l.DT_CRIACAO) : ''));
      }
      if (info.length) li.append(Util.el('div', 'pendencia-info', info.join(' · ')));
      if (l.OBSERVACAO) li.append(Util.el('div', 'pendencia-info', l.OBSERVACAO));
      if (l.SITUACAO === 'ABERTA' && l.ORIENTACAO) li.append(Util.el('div', 'pendencia-como', 'Como resolver: ' + l.ORIENTACAO));
      if (l.SITUACAO !== 'ABERTA') {
        li.append(Util.el('div', 'pendencia-info', 'Resolvida' + (l.USUARIO_RESOLUCAO ? ' por ' + l.USUARIO_RESOLUCAO : '')
          + (l.DT_RESOLUCAO ? ' em ' + Util.dataHora(l.DT_RESOLUCAO) : '') + (l.RESOLUCAO ? ': ' + l.RESOLUCAO : '')));
      }

      const botoes = Util.el('div', 'pendencia-botoes');
      if (auto && ATALHOS[l.CODIGO]) botoes.append(botao(ATALHOS[l.CODIGO], 'Leva ao lugar da ficha onde a pendência é corrigida. Ela some sozinha depois de gravar a correção.', () => irPara(l.CODIGO)));
      if (l.PODE_ALTERAR) {
        botoes.append(botao('Resolver', 'Marca a pendência como resolvida, com uma nota do que foi feito.', () => resolver(l)));
        botoes.append(botao('Alterar', 'Muda o tipo, a parcela, o responsável, a previsão ou a observação. Também tira a pendência lançada por engano.', () => abrirJanela(l)));
      }
      if (l.PODE_REABRIR) botoes.append(botao('Reabrir', 'Volta a pendência para aberta (ex.: a nota chegou errada).', () => reabrir(l)));
      if (botoes.childNodes.length) li.append(botoes);
      return li;
    }

    function botao(texto, dica, acao) {
      const b = Util.el('button', 'botao botao-pequeno', texto);
      b.type = 'button';
      b.dataset.dica = dica;
      b.addEventListener('click', acao);
      return b;
    }

    async function resolver(l) {
      const nota = await Mensagens.pedirTexto('Resolver pendência', 'Pendência: ' + l.DESCRICAO + '.\nEscreva o que foi feito para resolver (fica no histórico).',
        { rotulo: 'O que foi feito', botao: 'Resolver', obrigatorio: true, tipo: 'textarea', dica: 'Ex.: nota fiscal 1234 recebida e anexada.' });
      if (nota === null) return;
      const r = await Api.post('/api/fin/pendencias/' + l.ID_LANCAMENTO_PENDENCIA + '/resolver', { resolucao: nota });
      if (!(await Mensagens.tratar(r))) return;
      Mensagens.sucesso('Pendência resolvida.');
      await carregar();
    }

    async function reabrir(l) {
      if (!(await Mensagens.confirmar('Reabrir pendência?', 'A pendência "' + l.DESCRICAO + '" volta a ficar aberta' + (l.BLOQUEIA_BAIXA ? ' e bloqueia a baixa de novo' : '') + '.', 'Reabrir'))) return;
      const r = await Api.post('/api/fin/pendencias/' + l.ID_LANCAMENTO_PENDENCIA + '/reabrir');
      if (!(await Mensagens.tratar(r))) return;
      Mensagens.sucesso('Pendência reaberta.');
      await carregar();
    }

    async function carregarListas() {
      if (!tipos) {
        const [rt, rr] = await Promise.all([
          Api.get('/api/fin/pendencia-tipos', { somenteAtivos: true, tipo }),
          Api.get('/api/fin/pendencias/responsaveis')
        ]);
        if (!(await Mensagens.tratar(rt)) || !(await Mensagens.tratar(rr))) return false;
        tipos = (rt.dados || []).filter((t) => t.ATIVO !== false);
        responsaveis = rr.dados || [];
      }
      return true;
    }

    // Janela de incluir (l = null) ou alterar uma pendência manual
    async function abrirJanela(l) {
      if (!(await carregarListas())) return;
      // tipo do sistema (ex.: "Veio da migração") só aparece se já for o desta pendência
      const opcoesTipo = tipos.filter((t) => !t.SISTEMA || (l && t.ID_PENDENCIA_TIPO === l.ID_PENDENCIA_TIPO));
      const janela = document.createElement('dialog');
      janela.className = 'janela janela-larga';
      janela.setAttribute('aria-labelledby', 'janela-pend-titulo');
      const h2 = Util.el('h2', null, l ? 'Alterar pendência' : 'Nova pendência');
      h2.id = 'janela-pend-titulo';
      const topoJ = Util.el('div', 'janela-topo');
      topoJ.append(h2);

      const grade = Util.el('div', 'grade');
      const campo = (rotulo, el, classe, dica) => {
        const lab = Util.el('label', 'campo' + (classe ? ' ' + classe : ''), rotulo);
        if (dica) lab.dataset.dica = dica;
        lab.append(el);
        grade.append(lab);
        return el;
      };
      const selTipo = document.createElement('select');
      selTipo.append(Util.el('option', null, '(escolha)'));
      selTipo.firstChild.value = '';
      for (const t of opcoesTipo) {
        const op = Util.el('option', null, t.DESCRICAO + (t.BLOQUEIA_BAIXA ? ' (bloqueia a baixa)' : ''));
        op.value = String(t.ID_PENDENCIA_TIPO);
        selTipo.append(op);
      }
      campo('Tipo *', selTipo, 's-2', 'O que está faltando. Os tipos são cadastrados em Financeiro › Tipos de pendência.');
      const orientacao = Util.el('div', 'campo s-2 suave pendencia-orientacao');
      grade.append(orientacao);
      const mostrarOrientacao = () => {
        const t = opcoesTipo.find((x) => String(x.ID_PENDENCIA_TIPO) === selTipo.value);
        orientacao.textContent = t && t.ORIENTACAO ? 'Como resolver: ' + t.ORIENTACAO : '';
      };
      selTipo.addEventListener('change', mostrarOrientacao);

      const selParcela = document.createElement('select');
      selParcela.append(Util.el('option', null, 'Lançamento todo'));
      selParcela.firstChild.value = '';
      for (const p of parcelas().filter((x) => x.id)) {
        const op = Util.el('option', null, 'Parcela ' + p.numero + '/' + p.total + (p.vencimento ? ' – vence ' + Util.data(p.vencimento) : ''));
        op.value = String(p.id);
        selParcela.append(op);
      }
      campo('Parcela', selParcela, null, 'Se a pendência é só de uma parcela, escolha qual. Em branco = o lançamento todo.');

      const selResp = document.createElement('select');
      selResp.append(Util.el('option', null, '(ninguém)'));
      selResp.firstChild.value = '';
      for (const u of responsaveis) {
        const op = Util.el('option', null, u.NOME);
        op.value = String(u.ID_USUARIO);
        selResp.append(op);
      }
      campo('Responsável', selResp, null, 'Quem vai resolver. A pendência aparece em "Minhas pendências" na lista dessa pessoa.');

      const dtPrev = document.createElement('input');
      dtPrev.type = 'date';
      campo('Previsão', dtPrev, null, 'Até quando deve estar resolvida. Depois dessa data a etiqueta fica vermelha na lista.');
      const atalhos = Util.el('div', 'campo atalhos-data');
      atalhos.append(Util.el('span', null, ' '));
      const barraAtalhos = Util.el('div', 'atalhos-data-botoes');
      for (const [texto, valor] of [['Amanhã', () => somarDias(1)], ['+7 dias', () => somarDias(7)], ['Fim do mês', fimDoMes]]) {
        const b = Util.el('button', 'botao botao-pequeno', texto);
        b.type = 'button';
        b.addEventListener('click', () => { dtPrev.value = valor(); });
        barraAtalhos.append(b);
      }
      atalhos.append(barraAtalhos);
      grade.append(atalhos);

      const obs = document.createElement('textarea');
      obs.rows = 3;
      obs.maxLength = 1000;
      campo('Observação', obs, 's-4', 'Detalhe para quem for resolver (opcional).');

      if (l) {
        selTipo.value = String(l.ID_PENDENCIA_TIPO || '');
        selParcela.value = l.ID_PARCELA ? String(l.ID_PARCELA) : '';
        selResp.value = l.ID_USUARIO_RESPONSAVEL ? String(l.ID_USUARIO_RESPONSAVEL) : '';
        dtPrev.value = l.DT_PREVISAO ? Util.dataIso(l.DT_PREVISAO) : '';
        obs.value = l.OBSERVACAO || '';
      }
      mostrarOrientacao();

      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;
      const barra = Util.el('div', 'janela-botoes');
      const fechar = () => { janela.close(); janela.remove(); };
      if (l) {
        const tirar = Util.el('button', 'botao botao-perigo', 'Tirar (lançada por engano)');
        tirar.type = 'button';
        tirar.dataset.dica = 'Tira a pendência que foi lançada por engano (fica no histórico). Para o que foi resolvido, use Resolver.';
        tirar.addEventListener('click', async () => {
          fechar();
          if (!(await Mensagens.confirmar('Tirar pendência?', 'A pendência "' + l.DESCRICAO + '" sai do lançamento (fica registrada no histórico).', 'Tirar'))) return;
          await gravar(l, { ativo: false, idPendenciaTipo: l.ID_PENDENCIA_TIPO, idParcela: l.ID_PARCELA, idResponsavel: l.ID_USUARIO_RESPONSAVEL,
            dtPrevisao: l.DT_PREVISAO ? Util.dataIso(l.DT_PREVISAO) : null, observacao: l.OBSERVACAO }, 'Pendência retirada.');
        });
        barra.append(tirar);
      }
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      cancelar.addEventListener('click', fechar);
      const ok = Util.el('button', 'botao botao-principal', l ? 'Gravar' : 'Incluir');
      ok.type = 'button';
      ok.addEventListener('click', async () => {
        if (!selTipo.value) { erro.textContent = 'Escolha o tipo da pendência.'; erro.hidden = false; selTipo.focus(); return; }
        if (dtPrev.value && !l && dtPrev.value < hojeIso()) { erro.textContent = 'A previsão não pode ser antes de hoje.'; erro.hidden = false; dtPrev.focus(); return; }
        const dados = {
          idPendenciaTipo: Number(selTipo.value), idParcela: Number(selParcela.value) || null, idResponsavel: Number(selResp.value) || null,
          dtPrevisao: dtPrev.value || null, observacao: obs.value.trim(), ativo: true
        };
        fechar();
        await gravar(l, dados, l ? 'Pendência alterada.' : 'Pendência incluída.');
      });
      barra.append(cancelar, ok);
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(); });
      janela.append(topoJ, grade, erro, barra);
      document.body.append(janela);
      janela.showModal();
      selTipo.focus();
    }

    async function gravar(l, dados, textoOk) {
      const corpoPedido = { ...dados, idLancamentoPendencia: l ? l.ID_LANCAMENTO_PENDENCIA : null };
      const r = await Api.post('/api/fin/lancamentos/' + idLancamento + '/pendencias', corpoPedido);
      if (!(await Mensagens.tratar(r))) return;
      Mensagens.sucesso(textoOk);
      await carregar();
    }

    return { carregar, linhas: () => linhas };
  }

  return { criar };
})();
