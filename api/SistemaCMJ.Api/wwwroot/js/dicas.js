/* =============================================================================
   SistemaCMJ - js/dicas.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Componente ÚNICO de dicas (padroes/PADRAO_TELAS.md, seção 4):
               todo campo ou botão com o atributo data-dica mostra, ao passar o
               mouse ou ao receber o foco pelo teclado, para que serve, se é
               obrigatório e o formato. data-obrigatorio acrescenta
               "Obrigatório." no início. Funciona também nos campos criados
               depois (linhas de contatos, dados bancários...).
   Alteração : 22/11/2026 (03e, pedido do Celso) - a dica NUNCA cobre a caixa
               de digitação: fica acima do rótulo do campo (sem espaço acima:
               ao lado do campo; sem espaço ao lado: abaixo). Quando aparece
               pelo foco (inclusive o foco automático ao abrir a tela), some
               sozinha em 3 segundos; pelo mouse, fica enquanto o mouse estiver
               sobre o campo.
   ========================================================================== */
'use strict';

(() => {
  const SEGUNDOS_FOCO = 3;
  let caixa = null;
  let alvoAtual = null;
  let alvoMouse = null;
  let contador = 0;
  let timerFoco = null;

  function criarCaixa() {
    caixa = document.createElement('div');
    caixa.className = 'dica';
    caixa.id = 'dica-flutuante';
    caixa.setAttribute('role', 'tooltip');
    caixa.hidden = true;
    document.body.append(caixa);
  }

  function alvoDe(elemento) {
    if (!(elemento instanceof Element)) return null;
    return elemento.closest('[data-dica]');
  }

  function textoDe(alvo) {
    const obrigatorio = alvo.hasAttribute('data-obrigatorio') ? 'Obrigatório. ' : '';
    return obrigatorio + alvo.dataset.dica;
  }

  function campoDe(alvo) {
    return alvo.matches('input, select, textarea, button, a') ? alvo : alvo.querySelector('input, select, textarea');
  }

  // Rótulo que fica logo acima do campo (label for=, ou label que envolve o campo).
  function rotuloDe(alvo, campo) {
    let rotulo = null;
    if (campo && campo.id) rotulo = document.querySelector('label[for="' + CSS.escape(campo.id) + '"]');
    if (!rotulo) rotulo = alvo.closest('label');
    return rotulo;
  }

  function posicionar(alvo, campo) {
    const r = alvo.getBoundingClientRect();
    const largura = caixa.offsetWidth;
    const altura = caixa.offsetHeight;
    const larguraTela = document.documentElement.clientWidth;
    const rotulo = rotuloDe(alvo, campo);
    const rr = rotulo ? rotulo.getBoundingClientRect() : null;
    // Topo de referência: o rótulo, se estiver acima do campo; senão o próprio campo.
    const topo = rr && rr.bottom <= r.top + 4 ? Math.min(rr.top, r.top) : r.top;

    let x, y;
    if (topo - altura - 6 >= 4) {                       // 1) acima do rótulo
      x = r.left; y = topo - altura - 6;
    } else if (r.right + 8 + largura <= larguraTela - 8) { // 2) ao lado do campo
      x = r.right + 8; y = r.top;
    } else {                                            // 3) abaixo do campo
      x = r.left; y = r.bottom + 6;
    }
    if (x + largura > larguraTela - 8) x = larguraTela - largura - 8;
    caixa.style.left = (Math.max(8, x) + window.scrollX) + 'px';
    caixa.style.top = (Math.max(4, y) + window.scrollY) + 'px';
  }

  function mostrar(alvo, peloFoco) {
    if (!caixa) criarCaixa();
    if (!alvo.dataset.dica) return;
    clearTimeout(timerFoco);
    alvoAtual = alvo;
    caixa.textContent = textoDe(alvo);
    caixa.hidden = false;

    // O campo de verdade (input/select) recebe a descrição para leitores de tela.
    const campo = campoDe(alvo);
    if (campo) campo.setAttribute('aria-describedby', caixa.id);
    posicionar(alvo, campo);

    if (peloFoco) {
      timerFoco = setTimeout(() => { if (alvoAtual === alvo && alvoMouse !== alvo) esconder(alvo); }, SEGUNDOS_FOCO * 1000);
    }
  }

  function esconder(alvo) {
    if (!caixa || (alvo && alvo !== alvoAtual)) return;
    clearTimeout(timerFoco);
    caixa.hidden = true;
    alvoAtual = null;
  }

  document.addEventListener('mouseover', (e) => {
    const alvo = alvoDe(e.target);
    alvoMouse = alvo;
    if (alvo && alvo !== alvoAtual) {
      const meu = ++contador;
      setTimeout(() => { if (meu === contador) mostrar(alvo, false); }, 350);
    } else if (!alvo) {
      contador++;
      if (alvoAtual) esconder();
    }
  });
  document.addEventListener('focusin', (e) => { const alvo = alvoDe(e.target); if (alvo) { contador++; mostrar(alvo, true); } });
  document.addEventListener('focusout', (e) => { const alvo = alvoDe(e.target); if (alvo) esconder(alvo); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') esconder(); });
  window.addEventListener('scroll', () => esconder(), true);
})();
