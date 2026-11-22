/* =============================================================================
   SistemaCMJ - js/sis/permissoes.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Grade de permissões usada pela ficha do perfil e pela ficha do
               usuário (componente único). Linhas = telas, agrupadas por
               módulo; colunas = ações. Só aparecem as telas dos módulos
               liberados na licença e nunca as exclusivas do administrador
               geral (SIS_Permissao_Listar).
               Modo PERFIL : marcado = o perfil tem a ação (S/N).
               Modo USUARIO: marcado = o usuário tem a ação de fato. Mudar em
                             relação ao perfil cria uma exceção individual:
                             "+" concedida além do perfil, "−" retirada.
                             Voltar ao que o perfil dá apaga a exceção.
               Perfil de administrador: tudo marcado, sem edição.
               A grade só guarda as mudanças; quem grava é a ficha
               (lista { id_item_acao, valor } para SIS_Permissao_Gravar).
   ========================================================================== */
'use strict';

const GradePermissoes = (() => {
  /**
   * @param {HTMLElement} destino   onde desenhar
   * @param {'PERFIL'|'USUARIO'} modo
   * @param {Array} linhas          resultado do SIS_Permissao_Listar
   * @param {{ editavel: boolean, aoMudar: Function }} opcoes
   */
  function criar(destino, modo, linhas, opcoes = {}) {
    const admin = linhas.length > 0 && (linhas[0].PERFIL_NIVEL_ADMIN || 0) >= 1;
    const editavel = !!opcoes.editavel && !admin;
    const aoMudar = opcoes.aoMudar || (() => {});

    // Estado de cada permissão: marcado agora x marcado ao carregar.
    const estado = new Map();
    for (const l of linhas) {
      estado.set(l.ID_ITEM_ACAO, {
        linha: l,
        original: modo === 'PERFIL' ? !!l.NO_PERFIL : !!l.EFETIVA,
        atual: modo === 'PERFIL' ? !!l.NO_PERFIL : !!l.EFETIVA,
        caixa: null,
        marca: null
      });
    }

    // Ações na ordem em que aparecem; telas na ordem do menu.
    const acoes = [];
    const nomesAcao = new Map();
    for (const l of linhas) {
      if (!nomesAcao.has(l.ACAO_CODIGO)) { acoes.push(l.ACAO_CODIGO); nomesAcao.set(l.ACAO_CODIGO, l.ACAO_NOME); }
    }
    const telas = [];
    const porTela = new Map();
    for (const l of linhas) {
      if (!porTela.has(l.ID_ITEM)) {
        porTela.set(l.ID_ITEM, new Map());
        telas.push({ id: l.ID_ITEM, nome: l.ITEM_NOME, modulo: l.MODULO_NOME, codigo: l.ITEM_CODIGO });
      }
      porTela.get(l.ID_ITEM).set(l.ACAO_CODIGO, l.ID_ITEM_ACAO);
    }

    destino.replaceChildren();
    if (admin) {
      destino.append(Util.el('div', 'aviso-faixa faixa-ok', modo === 'PERFIL'
        ? 'Perfil de administrador: tem todas as permissões de todas as telas liberadas. Não há o que marcar.'
        : 'Este usuário está num perfil de administrador: tem todas as permissões. Não há exceções a marcar.'));
    } else if (modo === 'USUARIO') {
      const nota = Util.el('div', 'nota');
      nota.append('Marcado = o usuário pode. O que vem do perfil aparece normal. ',
        Util.el('span', 'marca-excecao marca-mais', '+'), ' dado só a este usuário; ',
        Util.el('span', 'marca-excecao marca-menos', '−'), ' tirado só deste usuário. Desmarcar ou marcar de volta como no perfil desfaz a exceção.');
      destino.append(nota);
    }

    const rolagem = Util.el('div', 'rolagem');
    const tabela = Util.el('table', 'tabela tabela-larga tabela-permissoes');
    const cab = Util.el('thead');
    const trCab = Util.el('tr');
    trCab.append(Util.el('th', null, 'Tela'));
    if (editavel) trCab.append(Util.el('th', 'celula-marca', 'Tudo'));
    for (const a of acoes) {
      const th = Util.el('th', 'celula-marca', nomesAcao.get(a));
      th.scope = 'col';
      trCab.append(th);
    }
    cab.append(trCab);
    tabela.append(cab);

    const corpo = Util.el('tbody');
    let moduloAtual = null;
    for (const t of telas) {
      if (t.modulo !== moduloAtual) {
        moduloAtual = t.modulo;
        const trMod = Util.el('tr', 'linha-modulo');
        const td = Util.el('td', null, t.modulo);
        td.colSpan = acoes.length + (editavel ? 2 : 1);
        trMod.append(td);
        corpo.append(trMod);
      }
      const tr = Util.el('tr');
      const nome = t.nome.includes(' > ') ? t.nome.split(' > ').slice(1).join(' › ') : t.nome;
      tr.append(Util.el('td', 'forte', nome));

      const idsDaTela = [...porTela.get(t.id).values()];
      let caixaTudo = null;
      if (editavel) {
        const tdTudo = Util.el('td', 'celula-marca');
        caixaTudo = Util.el('input');
        caixaTudo.type = 'checkbox';
        caixaTudo.setAttribute('aria-label', 'Todas as ações de ' + nome);
        caixaTudo.dataset.dica = 'Marca ou desmarca todas as ações desta tela.';
        caixaTudo.addEventListener('change', () => {
          for (const id of idsDaTela) mudar(id, caixaTudo.checked);
          atualizarTudo();
        });
        tdTudo.append(caixaTudo);
        tr.append(tdTudo);
      }
      const atualizarTudo = () => {
        if (!caixaTudo) return;
        const marcados = idsDaTela.filter((id) => estado.get(id).atual).length;
        caixaTudo.checked = marcados === idsDaTela.length;
        caixaTudo.indeterminate = marcados > 0 && marcados < idsDaTela.length;
      };

      for (const a of acoes) {
        const td = Util.el('td', 'celula-marca');
        const id = porTela.get(t.id).get(a);
        if (id !== undefined) {
          const e = estado.get(id);
          const caixa = Util.el('input');
          caixa.type = 'checkbox';
          caixa.checked = e.atual;
          caixa.disabled = !editavel;
          caixa.setAttribute('aria-label', nomesAcao.get(a) + ' em ' + nome);
          caixa.dataset.dica = dicaAcao(a, nome);
          caixa.addEventListener('change', () => { mudar(id, caixa.checked); atualizarTudo(); });
          e.caixa = caixa;
          td.append(caixa);
          if (modo === 'USUARIO') {
            e.marca = Util.el('span', 'marca-excecao');
            td.append(e.marca);
          }
        }
        tr.append(td);
      }
      corpo.append(tr);
      atualizarTudo();
    }
    if (telas.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma tela liberada para dar permissão.');
      td.colSpan = acoes.length + 2;
      tr.append(td);
      corpo.append(tr);
    }
    tabela.append(corpo);
    rolagem.append(tabela);
    destino.append(rolagem);
    for (const id of estado.keys()) desenharMarca(id);

    function mudar(id, marcado) {
      const e = estado.get(id);
      e.atual = marcado;
      if (e.caixa) e.caixa.checked = marcado;
      desenharMarca(id);
      aoMudar(qtdMudancas());
    }

    function desenharMarca(id) {
      const e = estado.get(id);
      if (!e.marca) return;
      const doPerfil = !!e.linha.NO_PERFIL;
      const mais = e.atual && !doPerfil;
      const menos = !e.atual && doPerfil;
      e.marca.className = 'marca-excecao' + (mais ? ' marca-mais' : menos ? ' marca-menos' : '');
      e.marca.textContent = mais ? '+' : menos ? '−' : '';
      e.marca.title = mais ? 'Dado só a este usuário (o perfil não dá)' : menos ? 'Tirado só deste usuário (o perfil dá)' : '';
    }

    function qtdMudancas() {
      let n = 0;
      for (const e of estado.values()) if (e.atual !== e.original) n++;
      return n;
    }

    /** Lista para gravar: só o que mudou. */
    function mudancas() {
      const lista = [];
      for (const [id, e] of estado) {
        if (e.atual === e.original) continue;
        if (modo === 'PERFIL') lista.push({ id_item_acao: id, valor: e.atual ? 'S' : 'N' });
        else {
          const doPerfil = !!e.linha.NO_PERFIL;
          lista.push({ id_item_acao: id, valor: e.atual === doPerfil ? '' : (e.atual ? 'C' : 'R') });
        }
      }
      return lista;
    }

    return { mudancas, qtdMudancas, admin };
  }

  function dicaAcao(acao, tela) {
    const textos = {
      VER: 'Pode abrir e consultar a tela',
      INCLUIR: 'Pode incluir registros em',
      ALTERAR: 'Pode alterar registros em',
      EXCLUIR: 'Pode excluir ou cancelar registros em',
      EXPORTAR: 'Pode exportar para o Excel a lista de',
      IMPORTAR: 'Pode importar arquivos em',
      BAIXAR: 'Pode dar baixa (pagar/receber) em',
      ESTORNAR: 'Pode estornar em',
      CANCELAR: 'Pode cancelar (contrato, boleto) em',
      REABRIR: 'Pode reabrir (mês, contrato) em',
      APROVAR: 'Pode aprovar em',
      ENVIAR: 'Pode enviar (e-mail, remessa) em',
      DESBLOQUEAR: 'Pode desbloquear usuários em',
      REDEFINIR_SENHA: 'Pode reiniciar a senha de outros usuários em',
      EXECUTAR: 'Pode executar rotinas em',
      RESTAURAR: 'Pode pedir a restauração de um backup em'
    };
    return (textos[acao] || 'Ação ' + acao + ' em') + ' ' + tela + '.';
  }

  return { criar };
})();
