/* =============================================================================
   SistemaCMJ - js/banco/bancos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Bancos (BANCO_BANCO): grade com edição na própria linha (código
               de 3 dígitos da Febraban, nome, ISPB, ativo). Validações no
               BANCO_Banco_Gravar.
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
  let todos = [];
  let linhas = [];

  $('botao-incluir').hidden = !podeIncluir;
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');

  function campo(valor, rotulo, dica, max, largura) {
    const c = Util.el('input');
    c.value = valor ?? '';
    c.maxLength = max;
    c.setAttribute('aria-label', rotulo);
    c.dataset.dica = dica;
    if (largura) c.style.width = largura;
    return c;
  }

  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  function filtrar() {
    const termo = semAcento(busca.value.trim());
    linhas = todos.filter((b) => !b.ID_BANCO || ((inativos.checked || b.ATIVO)
      && (!termo || semAcento(b.NOME).includes(termo) || (b.CODIGO || '').startsWith(termo))));
    desenhar();
  }

  function desenhar() {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum banco encontrado.');
      td.colSpan = 5;
      tr.append(td);
      corpo.append(tr);
    }
    for (const b of linhas) {
      const novo = !b.ID_BANCO;
      const editavel = novo ? podeIncluir : podeAlterar;
      const tr = Util.el('tr');
      const codigo = campo(b.CODIGO, 'Código', 'Obrigatório. Código do banco com 3 números (ex.: 748 para o Sicredi).', 3, '5em');
      codigo.inputMode = 'numeric';
      const nome = campo(b.NOME, 'Nome', 'Obrigatório. Nome do banco como aparece nas escolhas.', 80);
      const ispb = campo(b.ISPB, 'ISPB', 'Opcional. Código ISPB de 8 números (usado no PIX e na TED).', 8, '8em');
      for (const c of [codigo, nome, ispb]) c.disabled = !editavel;
      const marca = Util.el('label', 'marcacao');
      const ativo = Util.el('input');
      ativo.type = 'checkbox';
      ativo.checked = novo || !!b.ATIVO;
      ativo.disabled = novo || !podeAlterar;
      marca.append(ativo, Util.el('span', 'so-leitor', 'Ativo'));
      marca.dataset.dica = 'Desmarque e grave para desativar: o banco some das escolhas novas, mas as contas que já o usam continuam.';
      const gravar = Util.el('button', 'botao', 'Gravar');
      gravar.type = 'button';
      gravar.hidden = !editavel;
      gravar.dataset.dica = 'Grava esta linha (pede confirmação).';
      gravar.addEventListener('click', () => gravarLinha(b, { codigo, nome, ispb, ativo }, gravar));
      const td = (el) => { const c = Util.el('td'); c.append(el); return c; };
      tr.append(td(codigo), td(nome), td(ispb), td(marca), td(gravar));
      corpo.append(tr);
    }
    const qtd = linhas.filter((b) => b.ID_BANCO).length;
    $('contagem').textContent = qtd === 1 ? '1 banco' : qtd + ' bancos';
  }

  async function gravarLinha(b, c, botao) {
    const nome = c.nome.value.trim();
    if (!/^\d{3}$/.test(c.codigo.value.trim())) { await Mensagens.alerta('O código do banco tem 3 números (ex.: 748).', 'ATENCAO', { foco: c.codigo }); return; }
    if (!nome) { await Mensagens.alerta('Informe o nome do banco.', 'ATENCAO', { foco: c.nome }); return; }
    const texto = b.ID_BANCO && !c.ativo.checked && b.ATIVO ? 'Confirma desativar o banco "' + nome + '"?'
      : (b.ID_BANCO ? 'Confirma a gravação das alterações do banco "' : 'Confirma a inclusão do banco "') + nome + '"?';
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;
    botao.disabled = true;
    const r = await Api.post('/api/banco/bancos', { idBanco: b.ID_BANCO || null, codigo: c.codigo.value.trim(), ispb: c.ispb.value.trim(), nome, ativo: c.ativo.checked });
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Banco gravado.');
    await carregar();
  }

  async function carregar() {
    const r = await Api.get('/api/banco/bancos/todos');
    if (!(await Mensagens.tratar(r))) return;
    todos = r.dados || [];
    filtrar();
  }

  $('botao-incluir').addEventListener('click', () => {
    if (todos.some((b) => !b.ID_BANCO)) return;
    todos.push({ ID_BANCO: null, CODIGO: '', NOME: '', ISPB: '', ATIVO: true });
    filtrar();
    corpo.lastElementChild?.querySelector('input')?.focus();
  });
  $('botao-exportar').addEventListener('click', () => Util.exportarCsv('Bancos', ['Código', 'Nome', 'ISPB', 'Situação'],
    linhas.filter((b) => b.ID_BANCO).map((b) => [b.CODIGO, b.NOME, b.ISPB, b.ATIVO ? 'Ativo' : 'Inativo'])));
  busca.addEventListener('input', Util.atrasar(filtrar, 200));
  inativos.addEventListener('change', filtrar);
  $('filtros').addEventListener('submit', (e) => { e.preventDefault(); filtrar(); });

  await carregar();
});
