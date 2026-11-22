/* =============================================================================
   SistemaCMJ - js/sis/situacao-senha.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 22/11/2026 (fase 4, conversa 04a)
   Descrição : Situação da senha de um usuário em palavras, igual na lista e
               na ficha de Usuários.
   ========================================================================== */
'use strict';

/** Situação da senha de um usuário, em palavras (lista e ficha). */
const SituacaoSenha = {
  de(u) {
    if (!u.TEM_SENHA) return { texto: 'Sem senha', classe: 'situacao-pendente', dica: 'A senha ainda não foi definida: use "Reiniciar senha" na ficha.' };
    if (u.BLOQUEADO) return { texto: 'Bloqueado', classe: 'situacao-revisar', dica: 'Errou a senha várias vezes. Use "Desbloquear" ou "Reiniciar senha" na ficha.' };
    if (u.SENHA_PROVISORIA_VENCIDA) return { texto: 'Provisória vencida', classe: 'situacao-revisar', dica: 'A senha provisória passou do prazo sem ser trocada: use "Reiniciar senha" na ficha.' };
    if (u.TROCAR_SENHA) return { texto: 'Provisória', classe: 'situacao-pendente', dica: 'Vai criar a senha dele no próximo acesso.' };
    return { texto: 'Definida', classe: 'situacao-ativo', dica: 'O usuário já criou a senha dele.' };
  }
};
