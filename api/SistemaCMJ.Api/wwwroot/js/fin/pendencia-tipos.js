/* =============================================================================
   SistemaCMJ - js/fin/pendencia-tipos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 26/11/2026 (etapa 04f2c2, P27)
   Descrição : Financeiro › Tipos de pendência (FIN_PENDENCIA_TIPO): grade com
               edição na própria linha (código, descrição, vale para pagar /
               receber / ambos, bloqueia a baixa, orientação "como resolver",
               ordem, ativo) e a quantidade de pendências abertas de cada tipo.
               Tipos do sistema (ex.: "Veio da migração – conferir"): código e
               ativo travados. Regras de verdade no FIN_Pendencia_Tipo_Gravar.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const busca = $('busca');
  const inativos = $('inativos');
  const corpo = $('linhas');
  const podeIncluir = acoes.has('INCLUIR');
  const podeAlterar = acoes.has('ALTERAR');
  const podeDesativar = acoes.has('DESATIVAR') || acoes.has('EXCLUIR');
  const VALE_PARA = { A: 'Pagar e receber', P: 'Só contas a pagar', R: 'Só contas a receber' };
  let todos = [];
  let linhas = [];

  $('botao-incluir').hidden = !podeIncluir;
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');

  function campo(valor, rotulo, dica, max, classe) {
    const c = Util.el('input', classe || null);
    c.value = valor ?? '';
    c.maxLength = max;
    c.setAttribute('aria-label', rotulo);
    c.dataset.dica = dica;
    return c;
  }

  function marcacao(marcado, rotulo, dica) {
    const marca = Util.el('label', 'marcacao');
    const caixa = Util.el('input');
    caixa.type = 'checkbox';
    caixa.checked = !!marcado;
    marca.append(caixa, Util.el('span', 'so-leitor', rotulo));
    marca.dataset.dica = dica;
    return { marca, caixa };
  }

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  function filtrar() {
    const termo = semAcento(busca.value.trim());
    linhas = todos.filter((t) => !t.ID_PENDENCIA_TIPO || ((inativos.checked || t.ATIVO)
      && (!termo || semAcento(t.DESCRICAO).includes(termo) || semAcento(t.CODIGO).startsWith(termo))));
    desenhar();
  }

  function desenhar() {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum tipo de pendência encontrado.');
      td.colSpan = 9;
      tr.append(td);
      corpo.append(tr);
    }
    for (const t of linhas) {
      const novo = !t.ID_PENDENCIA_TIPO;
      const editavel = novo ? podeIncluir : podeAlterar;
      const tr = Util.el('tr');
      const codigo = campo(t.CODIGO, 'Código', 'Obrigatório. Letras sem acento, números e "_" (ex.: AGUARDA_MEDICAO). Tipo do sistema não muda de código.', 20, 'campo-codigo');
      const descricao = campo(t.DESCRICAO, 'Descrição', 'Obrigatória. Como o tipo aparece na ficha e na lista (ex.: Aguardando nota fiscal).', 60);
      const vale = document.createElement('select');
      vale.setAttribute('aria-label', 'Vale para');
      vale.dataset.dica = 'Em quais telas o tipo aparece no "+ Pendência".';
      for (const [v, texto] of Object.entries(VALE_PARA)) { const op = Util.el('option', null, texto); op.value = v; vale.append(op); }
      vale.value = t.APLICA_A || 'A';
      const bloqueia = marcacao(t.BLOQUEIA_BAIXA, 'Bloqueia a baixa', 'Marcado: enquanto a pendência estiver aberta, o lançamento não pode ser pago ou recebido (ex.: aguardando nota fiscal).');
      const orientacao = campo(t.ORIENTACAO, 'Como resolver', 'Opcional. Aparece na ficha como "Como resolver" (ex.: Anexar a nota e clicar em Resolver).', 400);
      const ordem = campo(t.ORDEM, 'Ordem', 'Opcional. Posição do tipo na lista de escolha (menor primeiro).', 4, 'campo-ordem');
      ordem.inputMode = 'numeric';
      const ativo = marcacao(novo || t.ATIVO, 'Ativo', t.SISTEMA ? 'Tipo do sistema: não pode ser desativado.' : 'Desmarque e grave para desativar: o tipo some do "+ Pendência", mas as pendências já lançadas continuam.');
      for (const c of [codigo, descricao, vale, bloqueia.caixa, orientacao, ordem]) c.disabled = !editavel;
      if (t.SISTEMA) codigo.disabled = true;
      ativo.caixa.disabled = novo || !podeDesativar || !!t.SISTEMA;
      const gravar = Util.el('button', 'botao', 'Gravar');
      gravar.type = 'button';
      gravar.hidden = !editavel;
      gravar.dataset.dica = 'Grava esta linha (pede confirmação).';
      gravar.addEventListener('click', () => gravarLinha(t, { codigo, descricao, vale, bloqueia: bloqueia.caixa, orientacao, ordem, ativo: ativo.caixa }, gravar));
      const td = (el) => { const c = Util.el('td'); c.append(el); return c; };
      const abertas = Util.el('td', 'numero', novo ? '' : String(t.QTD_ABERTAS || 0));
      const tdCodigo = td(codigo);
      if (t.SISTEMA) tdCodigo.append(Util.el('span', 'sub', 'do sistema'));
      tr.append(tdCodigo, td(descricao), td(vale), td(bloqueia.marca), td(orientacao), td(ordem), abertas, td(ativo.marca), td(gravar));
      corpo.append(tr);
    }
    const qtd = linhas.filter((t) => t.ID_PENDENCIA_TIPO).length;
    $('contagem').textContent = qtd === 1 ? '1 tipo' : qtd + ' tipos';
  }

  async function gravarLinha(t, c, botao) {
    const descricao = c.descricao.value.trim();
    const codigo = c.codigo.value.trim().toUpperCase();
    if (!/^[A-Z0-9_]+$/.test(codigo)) { await Mensagens.alerta('Código inválido: use letras sem acento, números e "_" (ex.: AGUARDA_MEDICAO).', 'ATENCAO', { foco: c.codigo }); return; }
    if (!descricao) { await Mensagens.alerta('Informe a descrição.', 'ATENCAO', { foco: c.descricao }); return; }
    const ordem = c.ordem.value.trim();
    if (ordem && !/^\d+$/.test(ordem)) { await Mensagens.alerta('A ordem é um número inteiro (ou deixe em branco).', 'ATENCAO', { foco: c.ordem }); return; }
    const texto = t.ID_PENDENCIA_TIPO && !c.ativo.checked && t.ATIVO ? 'Confirma desativar o tipo "' + descricao + '"?'
      : (t.ID_PENDENCIA_TIPO ? 'Confirma a gravação das alterações do tipo "' : 'Confirma a inclusão do tipo "') + descricao + '"?';
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;
    botao.disabled = true;
    const r = await Api.post('/api/fin/pendencia-tipos', {
      idPendenciaTipo: t.ID_PENDENCIA_TIPO || null, codigo, descricao, orientacao: c.orientacao.value.trim(), aplicaA: c.vale.value,
      bloqueiaBaixa: c.bloqueia.checked, ordem: ordem ? Number(ordem) : null, ativo: c.ativo.checked
    });
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Tipo de pendência gravado.');
    await carregar();
  }

  async function carregar() {
    const r = await Api.get('/api/fin/pendencia-tipos', { somenteAtivos: false });
    if (!(await Mensagens.tratar(r))) return;
    todos = r.dados || [];
    filtrar();
  }

  $('botao-incluir').addEventListener('click', () => {
    if (todos.some((t) => !t.ID_PENDENCIA_TIPO)) return;
    todos.push({ ID_PENDENCIA_TIPO: null, CODIGO: '', DESCRICAO: '', ORIENTACAO: '', APLICA_A: 'A', BLOQUEIA_BAIXA: false, ORDEM: '', ATIVO: true, SISTEMA: false });
    filtrar();
    corpo.lastElementChild?.querySelector('input')?.focus();
  });
  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Tipos_de_pendencia',
    ['Código', 'Descrição', 'Vale para', 'Bloqueia a baixa', 'Como resolver', 'Ordem', 'Abertas', 'Situação'],
    linhas.filter((t) => t.ID_PENDENCIA_TIPO).map((t) => [t.CODIGO, t.DESCRICAO, VALE_PARA[t.APLICA_A] || t.APLICA_A, t.BLOQUEIA_BAIXA ? 'Sim' : 'Não',
      t.ORIENTACAO, t.ORDEM, t.QTD_ABERTAS || 0, t.ATIVO ? 'Ativo' : 'Inativo'])));
  busca.addEventListener('input', Util.atrasar(filtrar, 200));
  inativos.addEventListener('change', filtrar);
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); filtrar(); });

  await carregar();
});
