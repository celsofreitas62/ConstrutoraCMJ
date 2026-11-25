/* =============================================================================
   SistemaCMJ - js/cad/rotulos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Nomes na tela dos códigos gravados no banco, usados por mais de
               uma tela dos cadastros-base (empresas, contas, centros, plano).
   ========================================================================== */
'use strict';

const Rotulos = Object.freeze({
  empresaTipo: { CONSTRUTORA: 'Construtora', SPE: 'SPE', HOLDING: 'Holding', OUTRA: 'Outra' },
  regime: { '': '', SIMPLES: 'Simples Nacional', LUCRO_PRESUMIDO: 'Lucro Presumido', LUCRO_REAL: 'Lucro Real', RET: 'RET' },
  contaTipo: { CORRENTE: 'Conta corrente', POUPANCA: 'Poupança', APLICACAO: 'Aplicação', CAIXA: 'Caixa', PERMUTA: 'Permuta' },
  centroTipo: { OBRA: 'Obra', ADMINISTRATIVO: 'Administrativo', IMOVEL_PROPRIO: 'Imóvel próprio', PARTICULAR: 'Particular' },
  grupoTipo: { RECEITA: 'Receita', DESPESA: 'Despesa', NAO_OPERACIONAL: 'Não operacional' },
  /** Nome da tabela; se o código não estiver nela, devolve o próprio código. */
  de(tabela, codigo) { const t = this[tabela] || {}; return codigo in t ? t[codigo] : (codigo ?? ''); }
});
