/* =============================================================================
   SistemaCMJ - js/seletor.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e, sugestão "a" aprovada pelo Celso)
   Descrição : Escolha com busca (componente único) para conta do plano,
               centro de custo e conta bancária: digita parte do nome ou do
               número, aparece a lista (setas, Enter, Esc), escolhe. Mostra o
               código e um complemento (grupo › subgrupo, empresa, agência).
               Fonte: GET /api/cad/seletor/{PLANO|CENTRO|CONTA} (CAD_Seletor_Listar:
               só ativos, no máximo SELETOR_LIMITE linhas; o valor já gravado
               volta mesmo inativo).
   Uso       : const s = Seletor.criar(elemento, { tipo: 'CENTRO', rotulo,
                 idEmpresa: () => 3, aoMudar: (id, item) => {} });
               await s.definir(id);  s.valor();  s.habilitar(false);
   ========================================================================== */
'use strict';

const Seletor = (() => {
  let contador = 0;
  const DICAS = {
    PLANO: 'Digite parte do nome da conta, do grupo ou o número (ex.: 05.2) e escolha na lista. Só aparecem contas ativas.',
    CENTRO: 'Digite parte do nome ou o código do centro de custo e escolha na lista. Só aparecem centros ativos.',
    CONTA: 'Digite parte da descrição ou o número da conta e escolha na lista. Só aparecem contas ativas.'
  };

  function criar(raiz, opcoes) {
    const { tipo, rotulo = '', idEmpresa = null, aoMudar = null, placeholder = 'Digite para buscar…' } = opcoes;
    const idLista = 'seletor-lista-' + (++contador);
    let atual = null;       // { ID, CODIGO, DESCRICAO, COMPLEMENTO, ATIVO }
    let itens = [];
    let marcado = -1;
    let pedido = 0;
    let habilitado = true;

    const caixa = Util.el('div', 'seletor');
    const campo = Util.el('input', 'seletor-campo');
    campo.type = 'text';
    campo.autocomplete = 'off';
    campo.placeholder = placeholder;
    campo.setAttribute('role', 'combobox');
    campo.setAttribute('aria-autocomplete', 'list');
    campo.setAttribute('aria-expanded', 'false');
    campo.setAttribute('aria-controls', idLista);
    if (rotulo) campo.setAttribute('aria-label', rotulo);
    campo.dataset.dica = opcoes.dica || DICAS[tipo] || '';
    const limpar = Util.el('button', 'seletor-limpar', '×');
    limpar.type = 'button';
    limpar.setAttribute('aria-label', 'Limpar a escolha');
    limpar.dataset.dica = 'Tira a escolha (fica em branco).';
    const lista = Util.el('ul', 'seletor-lista');
    lista.id = idLista;
    lista.setAttribute('role', 'listbox');
    lista.hidden = true;
    caixa.append(campo, limpar, lista);
    raiz.replaceChildren(caixa);

    const texto = (i) => i ? (i.CODIGO && tipo !== 'CONTA' ? i.CODIGO + ' - ' : '') + i.DESCRICAO + (i.ATIVO === false ? ' (inativo)' : '') : '';
    const empresa = () => (typeof idEmpresa === 'function' ? idEmpresa() : idEmpresa) || null;

    function mostrarAtual() {
      campo.value = texto(atual);
      campo.title = atual && atual.COMPLEMENTO ? atual.COMPLEMENTO : '';
      limpar.hidden = !atual || !habilitado;
    }

    function fechar() {
      lista.hidden = true;
      campo.setAttribute('aria-expanded', 'false');
      campo.removeAttribute('aria-activedescendant');
      marcado = -1;
    }

    function marcar(i) {
      const opcoes = [...lista.children];
      opcoes.forEach((o, n) => o.setAttribute('aria-selected', n === i ? 'true' : 'false'));
      marcado = i;
      if (opcoes[i]) {
        campo.setAttribute('aria-activedescendant', opcoes[i].id);
        opcoes[i].scrollIntoView({ block: 'nearest' });
      }
    }

    function escolher(item) {
      const mudou = (atual && atual.ID) !== (item && item.ID);
      atual = item;
      fechar();
      mostrarAtual();
      if (mudou) {
        campo.dispatchEvent(new Event('change', { bubbles: true }));
        if (aoMudar) aoMudar(item ? item.ID : null, item);
      }
    }

    function desenhar() {
      lista.replaceChildren();
      if (!itens.length) {
        const vazio = Util.el('li', 'seletor-vazio', 'Nada encontrado. Tente outra parte do nome.');
        vazio.setAttribute('role', 'option');
        vazio.setAttribute('aria-disabled', 'true');
        lista.append(vazio);
      }
      itens.forEach((item, n) => {
        const li = Util.el('li', 'seletor-opcao');
        li.id = idLista + '-' + n;
        li.setAttribute('role', 'option');
        li.append(Util.el('span', 'seletor-descricao', texto(item)));
        if (item.COMPLEMENTO) li.append(Util.el('span', 'seletor-complemento', item.COMPLEMENTO));
        li.addEventListener('mousedown', (e) => { e.preventDefault(); escolher(item); });
        lista.append(li);
      });
      lista.hidden = false;
      campo.setAttribute('aria-expanded', 'true');
      marcar(itens.length ? 0 : -1);
    }

    async function buscar() {
      const meu = ++pedido;
      const r = await Api.get('/api/cad/seletor/' + tipo, { busca: campo.value.trim(), idEmpresa: empresa() });
      if (meu !== pedido || document.activeElement !== campo) return;
      itens = r.sucesso ? (r.dados || []).filter((i) => i.ATIVO) : [];
      desenhar();
    }
    const buscarDepois = Util.atrasar(buscar, 250);

    campo.addEventListener('focus', () => { if (habilitado) { campo.select(); buscar(); } });
    campo.addEventListener('input', () => { if (habilitado) buscarDepois(); });
    campo.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        if (lista.hidden) { buscar(); return; }
        if (itens.length) marcar((marcado + (e.key === 'ArrowDown' ? 1 : itens.length - 1)) % itens.length);
      } else if (e.key === 'Enter') {
        if (!lista.hidden) { e.preventDefault(); if (marcado >= 0) escolher(itens[marcado]); }
      } else if (e.key === 'Escape') {
        if (!lista.hidden) { e.preventDefault(); e.stopPropagation(); fechar(); mostrarAtual(); }
      }
    });
    campo.addEventListener('blur', () => {
      // Sair do campo sem escolher: apagou tudo = limpa; senão volta o que estava.
      if (!campo.value.trim() && atual) escolher(null);
      fechar();
      mostrarAtual();
    });
    limpar.addEventListener('click', () => { escolher(null); campo.focus(); });

    /** Mostra o valor gravado (busca o texto pelo id; volta mesmo se estiver inativo). */
    async function definir(id) {
      if (!id) { atual = null; mostrarAtual(); return; }
      const r = await Api.get('/api/cad/seletor/' + tipo, { idAtual: id }); // o valor atual vem sempre em primeiro
      atual = r.sucesso ? (r.dados || []).find((i) => i.ID === Number(id)) || null : null;
      if (!atual) atual = { ID: Number(id), CODIGO: '', DESCRICAO: 'Código ' + id, ATIVO: true };
      mostrarAtual();
    }

    function habilitar(sim) {
      habilitado = !!sim;
      campo.disabled = !habilitado;
      mostrarAtual();
    }

    mostrarAtual();
    return { definir, habilitar, valor: () => (atual ? atual.ID : null), item: () => atual, campo, focar: () => campo.focus() };
  }

  return { criar };
})();
