/* =============================================================================
   SistemaCMJ - js/sis/lixeira.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 23/11/2026 (fase 4, conversa 04b2, pedido P20)
   Descrição : Tela Sistema › Lixeira (SIS_LIXEIRA): o que foi excluído nas
               telas, agrupado por módulo, com Recuperar (RECUPERAR), Manter
               mais N dias (ALTERAR) e Esvaziar agora (ESVAZIAR); aba Prazos
               por tela (prazo próprio de cada tela; vazio = prazo geral do
               parâmetro LIXEIRA_DIAS_GUARDA). Cada usuário só vê as telas que
               pode ver. Endereço ?item=<TELA> abre já filtrada (atalho
               "Lixeira desta tela" das listas).
               Regras e permissões: procedures SIS_Lixeira_* (04b).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeEsvaziar = acoes.has('ESVAZIAR');
  const podeRecuperar = acoes.has('RECUPERAR');
  const podeAlterar = acoes.has('ALTERAR');
  let prazos = [];
  let linhas = [];
  let pedido = 0;

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    $('botao-esvaziar').hidden = !podeEsvaziar || aba.id !== 'aba-lista' || $('situacao').value !== 'LIXEIRA';
  }
  abas.forEach((a) => a.addEventListener('click', () => abrirAba(a)));

  function linhaVazia(corpo, colunas, texto) {
    const tr = Util.el('tr');
    const td = Util.el('td', 'vazio', texto);
    td.colSpan = colunas;
    tr.append(td);
    corpo.append(tr);
  }

  // ---------- Filtros (módulo e tela vêm dos prazos: só as telas que o usuário vê) ----------
  async function carregarPrazos() {
    const r = await Api.get('/api/sis/lixeira/prazos');
    if (!(await Mensagens.tratar(r))) return false;
    prazos = r.dados || [];
    const geral = prazos.length ? prazos[0].DIAS_GERAL : null;
    $('nota-prazo').textContent = geral ? 'Prazo geral: ' + geral + ' dias (cada tela pode ter o seu, na aba Prazos por tela)' : '';
    $('nota-geral').textContent = 'Quanto tempo o que foi excluído fica na lixeira antes de ser apagado de vez.'
      + (geral ? ' Prazo geral: ' + geral + ' dias (parâmetro do sistema). ' : ' ')
      + 'Deixe o prazo próprio em branco para usar o geral. O prazo novo vale para o que for excluído daqui em diante.';
    const modulos = new Map();
    for (const p of prazos) modulos.set(p.MODULO_CODIGO, p.MODULO_NOME);
    const sel = $('modulo');
    const atual = sel.value;
    sel.replaceChildren(Util.el('option', null, 'Todos'));
    sel.firstChild.value = '';
    for (const [codigo, nome] of modulos) { const o = Util.el('option', null, nome); o.value = codigo; sel.append(o); }
    sel.value = atual;
    montarTelas();
    desenharPrazos();
    return true;
  }

  function montarTelas() {
    const sel = $('tela');
    const atual = sel.value;
    const telas = new Map();
    for (const p of prazos) if (!$('modulo').value || p.MODULO_CODIGO === $('modulo').value) telas.set(p.ITEM_CODIGO, p.TELA_NOME);
    sel.replaceChildren(Util.el('option', null, 'Todas'));
    sel.firstChild.value = '';
    for (const [codigo, nome] of telas) { const o = Util.el('option', null, nome); o.value = codigo; sel.append(o); }
    sel.value = telas.has(atual) ? atual : '';
  }

  // ---------- Lista ----------
  function marcados() {
    return [...$('linhas').querySelectorAll('input.marca-linha:checked')].map((c) => Number(c.value));
  }

  function desenhar() {
    const corpo = $('linhas');
    corpo.replaceChildren();
    const naLixeira = $('situacao').value === 'LIXEIRA';
    const comMarca = podeEsvaziar && naLixeira;
    $('col-marca').hidden = !comMarca;
    $('marcar-todos').checked = false;
    const colunas = comMarca ? 7 : 6;
    if (!linhas.length) linhaVazia(corpo, colunas, naLixeira ? 'A lixeira está vazia com esses filtros.' : 'Nada encontrado com esses filtros.');
    let modulo = null;
    for (const l of linhas) {
      if (l.MODULO_CODIGO !== modulo) {
        modulo = l.MODULO_CODIGO;
        const qtd = linhas.filter((x) => x.MODULO_CODIGO === modulo).length;
        const tr = Util.el('tr', 'linha-modulo');
        const td = Util.el('td', null, l.MODULO_NOME + ' (' + qtd + ')');
        td.colSpan = colunas;
        tr.append(td);
        corpo.append(tr);
      }
      const tr = Util.el('tr');
      if (comMarca) {
        const td = Util.el('td', 'celula-marca');
        const c = Object.assign(document.createElement('input'), { type: 'checkbox', className: 'marca-linha', value: l.ID_LIXEIRA });
        c.setAttribute('aria-label', 'Marcar ' + (l.DESCRICAO || ''));
        td.append(c);
        tr.append(td);
      }
      const reg = Util.el('td');
      reg.append(Util.el('div', 'forte', l.DESCRICAO || ('Código ' + l.ID_REGISTRO)), Util.el('div', 'suave', 'Código ' + l.ID_REGISTRO));
      const exc = Util.el('td');
      exc.append(Util.el('div', 'numero', Util.dataHora(l.DT_EXCLUSAO)), Util.el('div', 'suave', 'por ' + (l.USUARIO_EXCLUSAO || '')));
      const prazo = Util.el('td');
      if (l.SITUACAO === 'LIXEIRA') {
        prazo.append(Util.el('div', 'numero', Util.data(l.DT_APAGAR)));
        const dias = l.DIAS_RESTANTES;
        prazo.append(Util.el('div', 'suave', dias <= 0 ? 'hoje' : dias === 1 ? 'amanhã' : 'em ' + dias + ' dias'));
        if (l.APAGA_LOGO) prazo.append(Util.el('span', 'etiqueta etiqueta-apaga', 'apaga logo'));
      } else {
        prazo.append(Util.el('span', 'situacao situacao-' + l.SITUACAO.toLowerCase(), l.SITUACAO === 'RECUPERADO' ? 'Recuperado' : 'Apagado de vez'));
        prazo.append(Util.el('div', 'suave', Util.dataHora(l.DT_SITUACAO) + (l.USUARIO_SITUACAO ? ' por ' + l.USUARIO_SITUACAO : '')));
        if (l.MOTIVO_SITUACAO) prazo.append(Util.el('div', 'suave', l.MOTIVO_SITUACAO));
      }
      const acoesTd = Util.el('td');
      const caixa = Util.el('div', 'acoes-linha');
      if (l.SITUACAO === 'LIXEIRA' && podeRecuperar) {
        const b = Util.el('button', 'botao botao-pequeno', 'Recuperar');
        b.type = 'button';
        b.dataset.dica = 'Tira da lixeira: o registro volta para as telas como estava antes de ser excluído (ativo ou desativado). Pede confirmação.';
        b.addEventListener('click', () => recuperar(l));
        caixa.append(b);
      }
      if (l.SITUACAO === 'LIXEIRA' && podeAlterar) {
        const b = Util.el('button', 'botao botao-pequeno', 'Manter mais…');
        b.type = 'button';
        b.dataset.dica = 'Adia o dia em que o registro é apagado de vez, sem tirar da lixeira.';
        b.addEventListener('click', () => manter(l));
        caixa.append(b);
      }
      acoesTd.append(caixa);
      tr.append(Util.el('td', null, l.TELA_NOME || ''), reg, exc, Util.el('td', 'suave', l.MOTIVO || ''), prazo, acoesTd);
      corpo.append(tr);
    }
    $('contagem').textContent = linhas.length === 1 ? '1 registro' : linhas.length + ' registros';
    $('subtitulo').textContent = naLixeira
      ? (linhas.length ? linhas.length + (linhas.length === 1 ? ' registro na lixeira' : ' registros na lixeira') + (linhas.some((l) => l.APAGA_LOGO) ? ' · alguns serão apagados de vez em breve' : '') : 'Nada na lixeira com esses filtros.')
      : '';
  }

  async function listar() {
    const meu = ++pedido;
    const corpo = $('linhas');
    const r = await Api.get('/api/sis/lixeira', {
      modulo: $('modulo').value, item: $('tela').value, inicio: $('inicio').value, fim: $('fim').value,
      usuario: $('usuario').value.trim(), texto: $('texto').value.trim(), situacao: $('situacao').value
    });
    if (meu !== pedido) return;
    if (!r.sucesso) { corpo.replaceChildren(); await Mensagens.tratar(r); linhaVazia(corpo, 7, 'Lista indisponível.'); return; }
    linhas = r.dados || [];
    desenhar();
  }

  // ---------- Ações ----------
  async function recuperar(l) {
    const motivo = await Mensagens.pedirTexto('Recuperar da lixeira?',
      (l.DESCRICAO || 'O registro') + ' (' + (l.TELA_NOME || '') + ') volta para as telas como estava antes de ser excluído. Se já existir outro cadastro com o mesmo documento ou código, a recuperação é recusada.',
      { rotulo: 'Motivo (opcional)', botao: 'Recuperar', tipo: 'textarea', dica: 'Por que está recuperando. Opcional. Fica no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/' + l.ID_LIXEIRA + '/recuperar', { motivo });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Registro recuperado.');
    listar();
  }

  async function manter(l) {
    const dias = await Mensagens.pedirTexto('Manter mais tempo na lixeira?',
      (l.DESCRICAO || 'O registro') + ' será apagado de vez em ' + Util.data(l.DT_APAGAR) + '. Quantos dias a mais ele deve ficar na lixeira?',
      { rotulo: 'Dias a mais', botao: 'Manter', tipo: 'number', valor: '30', obrigatorio: true, minimo: 1, dica: 'De 1 a 3650 dias, contados a partir da data atual de apagar.' });
    if (dias === null) return;
    const r = await Api.post('/api/sis/lixeira/' + l.ID_LIXEIRA + '/manter', { dias: parseInt(dias, 10) || 0 });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Prazo adiado.');
    listar();
  }

  $('botao-esvaziar').addEventListener('click', async () => {
    const ids = marcados();
    if (!ids.length) { await Mensagens.alerta('Marque na lista os registros que devem ser apagados de vez.'); return; }
    const motivo = await Mensagens.pedirTexto('Apagar de vez?',
      (ids.length === 1 ? '1 registro marcado será apagado' : ids.length + ' registros marcados serão apagados') + ' de vez, sem esperar o prazo. Não dá para recuperar depois (a cópia fica só no histórico). '
      + 'Se algum passou a ser usado em outro lugar, ele não é apagado e você é avisado.',
      { rotulo: 'Motivo (opcional)', botao: 'Apagar de vez', tipo: 'textarea', dica: 'Por que está apagando antes do prazo. Opcional. Fica no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/esvaziar', { ids, motivo });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem);
    listar();
  });

  $('marcar-todos').addEventListener('change', (e) => {
    for (const c of $('linhas').querySelectorAll('input.marca-linha')) c.checked = e.target.checked;
  });

  // ---------- Prazos por tela ----------
  function desenharPrazos() {
    const corpo = $('linhas-prazos');
    corpo.replaceChildren();
    if (!prazos.length) linhaVazia(corpo, 6, 'Nenhuma tela usa a lixeira.');
    for (const p of prazos) {
      const tr = Util.el('tr');
      const tdDias = Util.el('td');
      const campo = Object.assign(document.createElement('input'), { type: 'number', min: 1, max: 3650, step: 1, value: p.DIAS_GUARDA ?? '', placeholder: 'geral' });
      campo.setAttribute('aria-label', 'Prazo próprio de ' + p.TELA_NOME + ' (' + p.TABELA + ')');
      campo.dataset.dica = 'Dias que o que for excluído em ' + p.TELA_NOME + ' fica na lixeira. Em branco = prazo geral. De 1 a 3650.';
      campo.disabled = !podeAlterar;
      campo.style.width = '7em';
      tdDias.append(campo);
      const tdBotao = Util.el('td');
      if (podeAlterar) {
        const b = Util.el('button', 'botao botao-pequeno', 'Gravar');
        b.type = 'button';
        b.dataset.dica = 'Grava o prazo desta tela. Pede confirmação.';
        b.addEventListener('click', async () => {
          const v = campo.value.trim();
          const dias = v === '' ? null : parseInt(v, 10);
          if (!(await Mensagens.confirmar('Gravar?', dias === null
            ? 'O prazo próprio de ' + p.TELA_NOME + ' será retirado: vale o prazo geral.'
            : 'O que for excluído em ' + p.TELA_NOME + ' daqui em diante fica ' + dias + ' dias na lixeira. O que já está lá não muda.', 'Gravar'))) return;
          const r = await Api.post('/api/sis/lixeira/prazos', { tabela: p.TABELA, dias });
          if (!(await Mensagens.tratar(r, { foco: campo }))) return;
          await Mensagens.concluido(r.mensagem);
          carregarPrazos();
        });
        tdBotao.append(b);
      }
      const tela = Util.el('td');
      tela.append(Util.el('div', null, p.TELA_NOME), Util.el('div', 'suave', p.TABELA));
      tr.append(Util.el('td', null, p.MODULO_NOME), tela, tdDias, Util.el('td', 'numero', p.DIAS_VALE + ' dias'), Util.el('td', 'numero', String(p.QTD_NA_LIXEIRA)), tdBotao);
      corpo.append(tr);
    }
  }

  // ---------- Início ----------
  const itemPedido = Util.parametro('item');
  await carregarPrazos();
  if (itemPedido) {
    const p = prazos.find((x) => x.ITEM_CODIGO === itemPedido);
    if (p) { $('modulo').value = p.MODULO_CODIGO; montarTelas(); $('tela').value = p.ITEM_CODIGO; }
  }
  $('modulo').addEventListener('change', () => { montarTelas(); listar(); });
  for (const id of ['tela', 'inicio', 'fim', 'situacao']) $(id).addEventListener('change', () => { abrirAba($('aba-lista')); listar(); });
  const atrasado = Util.atrasar(listar, 350);
  for (const id of ['usuario', 'texto']) $(id).addEventListener('input', atrasado);
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); listar(); });
  $('botao-atualizar').addEventListener('click', async () => { await carregarPrazos(); listar(); });
  abrirAba($('aba-lista'));
  listar();
});
