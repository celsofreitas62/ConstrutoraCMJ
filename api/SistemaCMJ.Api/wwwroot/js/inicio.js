/* =============================================================================
   SistemaCMJ - js/inicio.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Tela inicial. Na fase 4 passa a ser a agenda da semana
               (CLAUDE.md seção 3.1 item 1).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao } = await Layout.iniciar();
  if (sessao) document.getElementById('boas-vindas').textContent = 'Bem-vindo, ' + (sessao.nome || sessao.login).split(' ')[0];
});
