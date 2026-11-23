/* =============================================================================
   SistemaCMJ - js/mensagens.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Componente ÚNICO de mensagens (padroes/PADRAO_TELAS.md, seção 1):
     Mensagens.alerta(texto, tipo, {foco})  janela com OK ("ATENCAO" ou "ERRO");
                                            nada continua até o OK; não fecha
                                            com Esc nem clicando fora; depois do
                                            OK o cursor volta ao campo indicado.
     Mensagens.confirmar(titulo, texto, botao) janela Confirmar/Cancelar -> true/false
     Mensagens.concluido(texto)             janela com OK: registro gravado (todas as telas)
     Mensagens.sucesso(texto)               aviso discreto que some sozinho
     Mensagens.pedirTexto(titulo, texto, {rotulo, botao, obrigatorio, minimo,
                          tipo, valor, dica})   janela com um campo (ex.: motivo,
                                            número de dias) -> texto ou null
                                            se cancelar (04b2, 23/11/2026)
     Mensagens.tratar(resposta, {foco})     resposta da API: mostra a janela se
                                            não deu certo; devolve true/false
   ========================================================================== */
'use strict';

const Mensagens = (() => {
  const ICONES = {
    ATENCAO: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 3l9.5 17h-19z"/><path d="M12 10v4"/><path d="M12 17.5v.5"/></svg>',
    ERRO: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/></svg>',
    PERGUNTA: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .8-1 1.5v.7"/><path d="M12 17v.5"/></svg>',
    OK: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
  };

  // Uma janela por vez: as seguintes esperam na fila.
  let fila = Promise.resolve();

  function criarJanela({ icone, classeIcone, titulo, texto, botoes, escFecha }) {
    return new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela';
      janela.setAttribute('aria-labelledby', 'janela-titulo');

      const topo = document.createElement('div');
      topo.className = 'janela-topo';
      const spanIcone = document.createElement('span');
      spanIcone.className = classeIcone || '';
      spanIcone.innerHTML = icone;
      const h2 = document.createElement('h2');
      h2.id = 'janela-titulo';
      h2.textContent = titulo;
      topo.append(spanIcone, h2);

      const p = document.createElement('p');
      p.className = 'janela-texto';
      p.textContent = texto;

      const barra = document.createElement('div');
      barra.className = 'janela-botoes';
      let botaoPadrao = null;
      for (const b of botoes) {
        const botao = document.createElement('button');
        botao.type = 'button';
        botao.className = 'botao' + (b.principal ? ' botao-principal' : '');
        botao.textContent = b.texto;
        botao.addEventListener('click', () => { janela.close(); janela.remove(); resolver(b.valor); });
        barra.append(botao);
        if (b.principal) botaoPadrao = botao;
      }

      janela.addEventListener('cancel', (e) => {
        e.preventDefault();
        if (escFecha !== undefined) { janela.close(); janela.remove(); resolver(escFecha); }
      });

      janela.append(topo, p, barra);
      document.body.append(janela);
      janela.showModal();
      (botaoPadrao || barra.lastElementChild)?.focus();
    });
  }

  function enfileirar(fn) {
    const proxima = fila.then(fn, fn);
    fila = proxima.catch(() => {});
    return proxima;
  }

  function alerta(texto, tipo = 'ATENCAO', opcoes = {}) {
    const erro = tipo === 'ERRO';
    return enfileirar(async () => {
      await criarJanela({
        icone: erro ? ICONES.ERRO : ICONES.ATENCAO,
        classeIcone: erro ? 'icone-erro' : 'icone-atencao',
        titulo: erro ? 'Erro' : 'Atenção',
        texto: texto || (erro ? 'Não foi possível concluir a operação. O erro foi registrado para análise.' : ''),
        botoes: [{ texto: 'OK', valor: true, principal: true }]
      });
      if (opcoes.foco && typeof opcoes.foco.focus === 'function') opcoes.foco.focus();
    });
  }

  function concluido(texto) {
    return enfileirar(() => criarJanela({
      icone: ICONES.OK,
      classeIcone: 'icone-ok',
      titulo: 'Concluído',
      texto: texto || 'Registro gravado.',
      botoes: [{ texto: 'OK', valor: true, principal: true }],
      escFecha: true
    }));
  }

  function confirmar(titulo, texto, textoBotao = 'Confirmar') {
    return enfileirar(() => criarJanela({
      icone: ICONES.PERGUNTA,
      titulo,
      texto,
      botoes: [{ texto: 'Cancelar', valor: false }, { texto: textoBotao, valor: true, principal: true }],
      escFecha: false
    }));
  }

  function sucesso(texto, segundos = 4) {
    if (!texto) return;
    let area = document.querySelector('.avisos');
    if (!area) {
      area = document.createElement('div');
      area.className = 'avisos';
      area.setAttribute('role', 'status');
      area.setAttribute('aria-live', 'polite');
      document.body.append(area);
    }
    const aviso = document.createElement('div');
    aviso.className = 'aviso';
    const icone = document.createElement('span');
    icone.innerHTML = ICONES.OK;
    const t = document.createElement('span');
    t.textContent = texto;
    aviso.append(icone, t);
    area.append(aviso);
    setTimeout(() => aviso.remove(), segundos * 1000);
  }

  async function tratar(resposta, opcoes = {}) {
    if (resposta && resposta.sucesso) return true;
    const tipo = resposta && resposta.tipo === 'ERRO' ? 'ERRO' : 'ATENCAO';
    await alerta(resposta ? resposta.mensagem : '', tipo, opcoes);
    return false;
  }

  function pedirTexto(titulo, texto, opcoes = {}) {
    const { rotulo = 'Motivo', botao = 'Confirmar', obrigatorio = false, minimo = 3, tipo = 'text', valor = '', dica = '' } = opcoes;
    return enfileirar(() => new Promise((resolver) => {
      const janela = document.createElement('dialog');
      janela.className = 'janela';
      janela.setAttribute('aria-labelledby', 'janela-titulo');
      const topo = document.createElement('div');
      topo.className = 'janela-topo';
      const spanIcone = document.createElement('span');
      spanIcone.innerHTML = ICONES.PERGUNTA;
      const h2 = document.createElement('h2');
      h2.id = 'janela-titulo';
      h2.textContent = titulo;
      topo.append(spanIcone, h2);
      const p = document.createElement('p');
      p.className = 'janela-texto';
      p.textContent = texto;
      const rot = document.createElement('label');
      rot.className = 'campo janela-campo';
      rot.textContent = rotulo + (obrigatorio ? ' *' : '');
      if (dica) rot.dataset.dica = dica;
      const campo = document.createElement(tipo === 'textarea' ? 'textarea' : 'input');
      if (tipo !== 'textarea') campo.type = tipo;
      if (tipo === 'number') { campo.min = '1'; campo.step = '1'; }
      campo.maxLength = 400;
      campo.value = valor;
      rot.append(campo);
      const erro = document.createElement('div');
      erro.className = 'aviso-revisar';
      erro.hidden = true;
      const barra = document.createElement('div');
      barra.className = 'janela-botoes';
      const cancelar = document.createElement('button');
      cancelar.type = 'button';
      cancelar.className = 'botao';
      cancelar.textContent = 'Cancelar';
      const ok = document.createElement('button');
      ok.type = 'button';
      ok.className = 'botao botao-principal';
      ok.textContent = botao;
      barra.append(cancelar, ok);
      const fechar = (v) => { janela.close(); janela.remove(); resolver(v); };
      cancelar.addEventListener('click', () => fechar(null));
      ok.addEventListener('click', () => {
        const v = campo.value.trim();
        if (obrigatorio && v.length < minimo) {
          erro.textContent = tipo === 'number' ? 'Informe o número.' : 'Escreva pelo menos ' + minimo + ' letras.';
          erro.hidden = false;
          campo.focus();
          return;
        }
        fechar(v);
      });
      campo.addEventListener('keydown', (e) => { if (e.key === 'Enter' && tipo !== 'textarea') { e.preventDefault(); ok.click(); } });
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(null); });
      janela.append(topo, p, rot, erro, barra);
      document.body.append(janela);
      janela.showModal();
      campo.focus();
    }));
  }

  return { alerta, confirmar, concluido, sucesso, tratar, pedirTexto };
})();
