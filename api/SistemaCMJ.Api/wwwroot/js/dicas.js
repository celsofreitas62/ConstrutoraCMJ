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
   ========================================================================== */
'use strict';

(() => {
  let caixa = null;
  let alvoAtual = null;
  let contador = 0;

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

  function mostrar(alvo) {
    if (!caixa) criarCaixa();
    if (!alvo.dataset.dica) return;
    alvoAtual = alvo;
    caixa.textContent = textoDe(alvo);
    caixa.hidden = false;

    // O campo de verdade (input/select) recebe a descrição para leitores de tela.
    const campo = alvo.matches('input, select, textarea, button, a') ? alvo : alvo.querySelector('input, select, textarea');
    if (campo) campo.setAttribute('aria-describedby', caixa.id);

    const r = alvo.getBoundingClientRect();
    const largura = caixa.offsetWidth;
    const altura = caixa.offsetHeight;
    let x = r.left + window.scrollX;
    let y = r.bottom + window.scrollY + 6;
    if (x + largura > window.scrollX + document.documentElement.clientWidth - 8)
      x = window.scrollX + document.documentElement.clientWidth - largura - 8;
    if (r.bottom + altura + 12 > window.innerHeight) y = r.top + window.scrollY - altura - 6;
    caixa.style.left = Math.max(8, x) + 'px';
    caixa.style.top = Math.max(8, y) + 'px';
  }

  function esconder(alvo) {
    if (!caixa || (alvo && alvo !== alvoAtual)) return;
    caixa.hidden = true;
    alvoAtual = null;
  }

  document.addEventListener('mouseover', (e) => {
    const alvo = alvoDe(e.target);
    if (alvo && alvo !== alvoAtual) {
      const meu = ++contador;
      setTimeout(() => { if (meu === contador) mostrar(alvo); }, 350);
    } else if (!alvo) {
      contador++;
      if (alvoAtual && !alvoAtual.contains(document.activeElement)) esconder();
    }
  });
  document.addEventListener('focusin', (e) => { const alvo = alvoDe(e.target); if (alvo) { contador++; mostrar(alvo); } });
  document.addEventListener('focusout', (e) => { const alvo = alvoDe(e.target); if (alvo) esconder(alvo); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') esconder(); });
  window.addEventListener('scroll', () => esconder(), true);
})();
