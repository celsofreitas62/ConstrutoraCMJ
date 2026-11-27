/* =============================================================================
   SistemaCMJ - js/cad/parceiro-tipos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (04d2 passo 4)
   Descrição : Tela Cadastros › Tipos de parceiro (CAD_PARCEIRO_TIPO): lista
               editável na própria tela (código, descrição, ordem, ativo) com a
               quantidade de parceiros de cada tipo; Gravar em cada linha. Tipos do
               sistema (SISTEMA = 1): código travado e não desativam; o N/A não
               aparece. Validação e permissão em CAD_Parceiro_Tipo_Gravar.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao, acoes } = await Layout.iniciar();
  const ROTULO = (sessao && sessao.parceiroRotulo) || 'Parceiro';
  const titulo = 'Tipos de ' + ROTULO.toLowerCase();
  document.title = 'SistemaCMJ – ' + titulo;
  document.getElementById('titulo').textContent = titulo;
  // caminho acima do título: montado pelo menu (js/layout.js, 04h2)

  const busca = document.getElementById('busca');
  const inativos = document.getElementById('inativos');
  const corpo = document.getElementById('linhas');
  const contagem = document.getElementById('contagem');
  const podeIncluir = acoes.has('INCLUIR');
  const podeAlterar = acoes.has('ALTERAR');
  const podeDesativar = acoes.has('DESATIVAR');
  let linhas = [];
  let pedido = 0;

  const incluir = document.getElementById('botao-incluir');
  incluir.hidden = !podeIncluir;

  function campo(tipo, valor, rotulo, dica, max) {
    const c = Util.el('input');
    c.type = tipo;
    c.value = valor ?? '';
    if (max) c.maxLength = max;
    c.setAttribute('aria-label', rotulo);
    c.dataset.dica = dica;
    return c;
  }

  function desenhar() {
    corpo.replaceChildren();
    if (linhas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum tipo encontrado.');
      td.colSpan = 6;
      tr.append(td);
      corpo.append(tr);
    }
    for (const t of linhas) {
      const novo = !t.ID_PARCEIRO_TIPO;
      const editavel = novo ? podeIncluir : podeAlterar;
      const sistema = t.SISTEMA === true || t.SISTEMA === 1;
      const tr = Util.el('tr');

      const codigo = campo('text', t.CODIGO, 'Código', 'Obrigatório. Código curto, sem espaços (ex.: PRESTADOR). Nos tipos do sistema não muda.', 20);
      codigo.disabled = !editavel || sistema;
      codigo.addEventListener('input', () => { codigo.value = codigo.value.toUpperCase().replace(/\s/g, '_'); });
      const descricao = campo('text', t.DESCRICAO, 'Descrição', 'Obrigatório. Nome do tipo como aparece nas fichas e nos filtros (ex.: Prestador de serviço).', 60);
      descricao.disabled = !editavel;
      const ordem = campo('number', t.ORDEM, 'Ordem', 'Opcional. Posição do tipo nas listas (menor aparece primeiro).');
      ordem.min = 0;
      ordem.style.width = '6em';
      ordem.disabled = !editavel;

      const marca = Util.el('label', 'marcacao');
      const ativo = Util.el('input');
      ativo.type = 'checkbox';
      ativo.checked = novo || t.ATIVO === true || t.ATIVO === 1;
      ativo.disabled = novo || sistema || !podeDesativar;
      marca.append(ativo, Util.el('span', 'so-leitor', 'Ativo'));
      marca.dataset.dica = sistema ? 'Os tipos do sistema não podem ser desativados.' : 'Desmarque e grave para desativar o tipo: ele some das fichas novas, mas os parceiros que já o têm continuam com ele.';

      const gravar = Util.el('button', 'botao', 'Gravar');
      gravar.type = 'button';
      gravar.hidden = !editavel && !(podeDesativar && !sistema && !novo);
      gravar.dataset.dica = 'Grava esta linha (pede confirmação).';
      gravar.addEventListener('click', () => gravarLinha(t, { codigo, descricao, ordem, ativo }, gravar));

      const td = (el) => { const c = Util.el('td'); c.append(el); return c; };
      tr.append(td(codigo), td(descricao), td(ordem), td(marca),
        Util.el('td', 'numero', novo ? '' : String(t.QTD_PARCEIROS ?? 0)), td(gravar));
      corpo.append(tr);
    }
    const qtd = linhas.filter((t) => t.ID_PARCEIRO_TIPO).length;
    contagem.textContent = qtd === 1 ? '1 tipo' : qtd + ' tipos';
  }

  async function gravarLinha(t, c, botao) {
    const desc = c.descricao.value.trim();
    const desativando = t.ID_PARCEIRO_TIPO && !c.ativo.checked && (t.ATIVO === true || t.ATIVO === 1);
    const texto = desativando
      ? 'Confirma desativar o tipo "' + desc + '"?' + (t.QTD_PARCEIROS ? ' ' + t.QTD_PARCEIROS + ' parceiro(s) continuam com ele.' : '')
      : (t.ID_PARCEIRO_TIPO ? 'Confirma a gravação das alterações do tipo "' : 'Confirma a inclusão do tipo "') + desc + '"?';
    if (!(await Mensagens.confirmar('Gravar?', texto, 'Gravar'))) return;
    botao.disabled = true;
    const r = await Api.post('/api/cad/parceiro-tipos', {
      idParceiroTipo: t.ID_PARCEIRO_TIPO || null,
      codigo: c.codigo.value.trim(),
      descricao: desc,
      ordem: c.ordem.value === '' ? null : Number(c.ordem.value),
      ativo: c.ativo.checked
    });
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Tipo gravado.');
    await carregar();
  }

  async function carregar() {
    const meu = ++pedido;
    const r = await Api.get('/api/cad/parceiro-tipos', { busca: busca.value.trim(), somenteAtivos: !inativos.checked });
    if (meu !== pedido) return;
    if (!(await Mensagens.tratar(r))) return;
    linhas = (r.dados || []).filter((t) => t.CODIGO !== 'NA');
    desenhar();
  }

  incluir.addEventListener('click', () => {
    if (linhas.some((t) => !t.ID_PARCEIRO_TIPO)) return; // já tem uma linha nova esperando
    linhas.push({ ID_PARCEIRO_TIPO: null, CODIGO: '', DESCRICAO: '', ORDEM: null, ATIVO: true, SISTEMA: false });
    desenhar();
    corpo.lastElementChild?.querySelector('input')?.focus();
  });

  let espera;
  busca.addEventListener('input', () => { clearTimeout(espera); espera = setTimeout(carregar, 300); });
  inativos.addEventListener('change', carregar);
  document.getElementById('filtros').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });

  await carregar();
});
