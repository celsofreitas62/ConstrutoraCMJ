/* =============================================================================
   SistemaCMJ - js/sis/comunicados.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 17/11/2026 (fase 3c)
   Descrição : Tela "Comunicados" (SIS_COMUNICADO): boletim semanal da
               implantação. Aba "Itens": introdução e itens (Implantado, Em
               teste, Próxima fase), gravados de uma vez. Aba "Prévias e
               envios": as edições geradas; ao clicar, mostra o e-mail exatamente
               como sai e permite "Aprovar e enviar" ou "Descartar prévia".
               Botões aparecem conforme as ações do usuário (VER, ALTERAR,
               ENVIAR, APROVAR).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);

  const SECOES = [['IMPLANTADO', 'Implantado'], ['EM_TESTE', 'Em teste'], ['PROXIMA_FASE', 'Próxima fase']];
  const SITUACOES = { PREVIA: 'Prévia (aguardando aprovação)', ENVIADA: 'Enviada', DESCARTADA: 'Descartada' };
  const podeAlterar = acoes.has('ALTERAR');
  let comunicado = null;
  let edicaoEscolhida = null;
  let sujo = false;

  $('botao-gravar').hidden = !podeAlterar;
  $('botao-item').hidden = !podeAlterar;
  $('botao-previa').hidden = !acoes.has('ENVIAR');

  // Abas
  const abas = [...document.querySelectorAll('.aba')];
  function ativarAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
  }
  abas.forEach((a) => a.addEventListener('click', () => ativarAba(a)));

  // ---- Itens ----------------------------------------------------------------
  function linhaItem(item) {
    const tr = Util.el('tr');
    tr.dataset.id = item.id || '';

    const secao = Util.el('select');
    secao.setAttribute('aria-label', 'Seção');
    secao.dataset.dica = 'Implantado = já em uso na empresa; Em teste = pronto e sendo conferido; Próxima fase = o que vem a seguir.';
    for (const [valor, texto] of SECOES) {
      const op = Util.el('option', null, texto);
      op.value = valor;
      secao.append(op);
    }
    secao.value = item.secao || 'EM_TESTE';

    const texto = Util.el('textarea', 'texto-item');
    texto.maxLength = 300;
    texto.value = item.texto || '';
    texto.setAttribute('aria-label', 'Texto do item');
    texto.dataset.dica = 'Frase curta, em linguagem simples, sem dados técnicos. Obrigatório.';
    texto.dataset.obrigatorio = '';

    const ordem = Util.el('input', 'ordem-item');
    ordem.type = 'number';
    ordem.min = '0';
    ordem.max = '999';
    ordem.value = item.ordem ?? 0;
    ordem.setAttribute('aria-label', 'Ordem');
    ordem.dataset.dica = 'Posição do item dentro da seção (menor aparece primeiro).';

    const remover = Util.el('button', 'botao botao-icone', '×');
    remover.type = 'button';
    remover.setAttribute('aria-label', 'Remover item');
    remover.dataset.dica = 'Tira o item do boletim (ao gravar, ele fica guardado como inativo).';
    remover.addEventListener('click', () => { tr.remove(); sujo = true; });

    for (const campo of [secao, texto, ordem]) {
      campo.disabled = !podeAlterar;
      campo.addEventListener('input', () => { sujo = true; });
    }
    remover.hidden = !podeAlterar;

    for (const c of [secao, texto, ordem, remover]) {
      const td = Util.el('td');
      td.append(c);
      tr.append(td);
    }
    return tr;
  }

  function desenharItens(itens) {
    const corpo = $('itens');
    corpo.replaceChildren();
    const ordenados = [...itens].sort((a, b) =>
      SECOES.findIndex((s) => s[0] === a.secao) - SECOES.findIndex((s) => s[0] === b.secao) || a.ordem - b.ordem);
    for (const item of ordenados) corpo.append(linhaItem(item));
  }

  $('botao-item').addEventListener('click', () => {
    const tr = linhaItem({ secao: 'EM_TESTE', ordem: 1 });
    $('itens').append(tr);
    tr.querySelector('textarea').focus();
    sujo = true;
  });

  $('botao-gravar').addEventListener('click', async () => {
    const itens = [...$('itens').querySelectorAll('tr')].map((tr) => ({
      id: tr.dataset.id ? Number(tr.dataset.id) : null,
      secao: tr.querySelector('select').value,
      texto: tr.querySelector('textarea').value.trim(),
      ordem: Number(tr.querySelector('input').value || 0)
    }));
    const vazio = [...$('itens').querySelectorAll('textarea')].find((t) => !t.value.trim());
    if (vazio) { await Mensagens.alerta('Há item sem texto. Preencha ou remova a linha.', 'ATENCAO', { foco: vazio }); return; }
    if (!(await Mensagens.confirmar('Gravar?', 'Confirma a gravação da introdução e dos ' + itens.length + ' itens do boletim?', 'Gravar'))) return;
    const r = await Api.post('/api/sis/comunicados/' + comunicado.ID_COMUNICADO, { introducao: $('introducao').value, itens });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido((r.mensagem || 'Comunicado gravado.') + ' Para ver como fica o e-mail, use "Gerar prévia agora".');
    await carregar();
  });

  $('introducao').addEventListener('input', () => { sujo = true; });

  // ---- Prévia e envio --------------------------------------------------------
  $('botao-previa').addEventListener('click', async () => {
    if (sujo) { await Mensagens.alerta('Há alterações nos itens que ainda não foram gravadas. Grave antes de gerar a prévia.'); return; }
    if (!(await Mensagens.confirmar('Gerar prévia?', 'O boletim desta semana será montado e a prévia irá só para: ' + (comunicado.DESTINATARIOS_APROVACAO || '(ninguém)') + '.', 'Gerar prévia'))) return;
    const r = await Api.post('/api/sis/comunicados/' + comunicado.ID_COMUNICADO + '/previa');
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Prévia gerada.');
    await carregar(r.dados && r.dados.id);
    ativarAba($('aba-edicoes'));
  });

  function escolherEdicao(ed) {
    edicaoEscolhida = ed;
    for (const tr of $('edicoes').querySelectorAll('tr')) tr.classList.toggle('selecionada', Number(tr.dataset.id) === ed.id);
    $('edicao-escolhida').textContent = 'E-mail da semana ' + Util.data(ed.inicio) + ' a ' + Util.data(ed.fim) + ' — ' + (SITUACOES[ed.situacao] || ed.situacao);
    const previa = ed.situacao === 'PREVIA';
    $('botao-aprovar').hidden = !(previa && acoes.has('APROVAR'));
    $('botao-descartar').hidden = !(previa && acoes.has('APROVAR'));
    const quadro = $('previa');
    quadro.src = '/api/sis/comunicados/edicoes/' + ed.id + '/html';
    quadro.hidden = false;
  }

  function desenharEdicoes(edicoes, escolher) {
    const corpo = $('edicoes');
    corpo.replaceChildren();
    if (edicoes.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma prévia gerada ainda.');
      td.colSpan = 5;
      tr.append(td);
      corpo.append(tr);
    }
    for (const ed of edicoes) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      tr.dataset.id = ed.id;
      tr.append(
        Util.el('td', null, Util.data(ed.inicio) + ' a ' + Util.data(ed.fim)),
        Util.el('td', null, ed.assunto),
        Util.el('td', ed.situacao === 'PREVIA' ? 'forte' : null, SITUACOES[ed.situacao] || ed.situacao),
        Util.el('td', null, Util.dataHora(ed.criada)),
        Util.el('td', null, ed.aprovada ? Util.dataHora(ed.aprovada) + ' (' + (ed.aprovadaPor || '') + ')' : ''));
      tr.addEventListener('click', () => escolherEdicao(ed));
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') escolherEdicao(ed); });
      corpo.append(tr);
    }
    const alvo = edicoes.find((e) => e.id === escolher) || edicoes.find((e) => e.situacao === 'PREVIA');
    if (alvo) escolherEdicao(alvo);
    else { $('previa').hidden = true; $('botao-aprovar').hidden = true; $('botao-descartar').hidden = true; }
  }

  $('botao-aprovar').addEventListener('click', async () => {
    if (!edicaoEscolhida) return;
    if (!(await Mensagens.confirmar('Aprovar e enviar?', 'O e-mail mostrado abaixo será enviado para: ' + (comunicado.DESTINATARIOS || '(ninguém)') + '. Depois de enviado, não dá para desfazer.', 'Aprovar e enviar'))) return;
    const r = await Api.post('/api/sis/comunicados/edicoes/' + edicaoEscolhida.id + '/aprovar');
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Comunicado aprovado.');
    await carregar(edicaoEscolhida.id);
  });

  $('botao-descartar').addEventListener('click', async () => {
    if (!edicaoEscolhida) return;
    if (!(await Mensagens.confirmar('Descartar prévia?', 'Nada será enviado. Você pode gerar outra prévia depois.', 'Descartar'))) return;
    const r = await Api.post('/api/sis/comunicados/edicoes/' + edicaoEscolhida.id + '/descartar');
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Prévia descartada.');
    await carregar(edicaoEscolhida.id);
  });

  // ---- Carga -----------------------------------------------------------------
  async function carregar(escolher) {
    const r = await Api.get('/api/sis/comunicados');
    if (!(await Mensagens.tratar(r))) return;
    comunicado = r.dados;
    $('titulo').textContent = comunicado.TITULO;
    const dias = { '1': 'domingo', '2': 'segunda', '3': 'terça', '4': 'quarta', '5': 'quinta', '6': 'sexta', '7': 'sábado' };
    const quando = (comunicado.ROTINA_DIAS || '').split(',').map((d) => dias[d.trim()]).filter(Boolean).join(', ');
    $('subtitulo').textContent = comunicado.ROTINA_ATIVA
      ? 'Prévia automática: ' + quando + ' às ' + comunicado.ROTINA_HORARIO + (comunicado.ROTINA_PROXIMA ? ' (próxima: ' + Util.dataHora(comunicado.ROTINA_PROXIMA) + ')' : '')
      : 'Prévia automática desligada (tela Rotinas automáticas).';
    $('introducao').value = comunicado.INTRODUCAO || '';
    $('introducao').disabled = !podeAlterar;
    $('destinatarios').textContent = 'Prévia para: ' + (comunicado.DESTINATARIOS_APROVACAO || '(ninguém)')
      + ' · Envio oficial para: ' + (comunicado.DESTINATARIOS || '(ninguém)') + ' (destinatários na tela Grupos de e-mail).';
    desenharItens(comunicado.ITENS_JSON || []);
    const edicoes = comunicado.EDICOES_JSON || [];
    const pendente = edicoes.find((e) => e.situacao === 'PREVIA');
    const aviso = $('aviso-previa');
    aviso.hidden = !pendente;
    if (pendente) aviso.textContent = 'Há uma prévia aguardando aprovação (semana ' + Util.data(pendente.inicio) + ' a ' + Util.data(pendente.fim) + '). Veja na aba "Prévias e envios".';
    desenharEdicoes(edicoes, escolher);
    sujo = false;
  }

  window.addEventListener('beforeunload', (e) => { if (sujo) { e.preventDefault(); e.returnValue = ''; } });
  await carregar();
});
