/* =============================================================================
   SistemaCMJ - js/cad/rotulos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Nomes na tela dos códigos gravados no banco, usados por mais de
               uma tela dos cadastros-base (empresas, contas, centros, plano).
               04h2: preferencia = opções das Preferências do usuário e dos
               padrões delas na tela Parâmetros de uso.
   ========================================================================== */
'use strict';

const Rotulos = Object.freeze({
  empresaTipo: { CONSTRUTORA: 'Construtora', SPE: 'SPE', HOLDING: 'Holding', OUTRA: 'Outra' },
  regime: { '': '', SIMPLES: 'Simples Nacional', LUCRO_PRESUMIDO: 'Lucro Presumido', LUCRO_REAL: 'Lucro Real', RET: 'RET' },
  contaTipo: { CORRENTE: 'Conta corrente', POUPANCA: 'Poupança', APLICACAO: 'Aplicação', CAIXA: 'Caixa', PERMUTA: 'Permuta' },
  centroTipo: { OBRA: 'Obra', ADMINISTRATIVO: 'Administrativo', IMOVEL_PROPRIO: 'Imóvel próprio', PARTICULAR: 'Particular' },
  movimentoTipo: { BAIXA: 'Baixa', TRANSFERENCIA: 'Transferência', TARIFA: 'Tarifa', AJUSTE: 'Ajuste', SALDO_INICIAL: 'Saldo inicial' },
  grupoTipo: { RECEITA: 'Receita', DESPESA: 'Despesa', NAO_OPERACIONAL: 'Não operacional' },
  preferencia: { CALENDARIO: 'Calendário', LISTA: 'Lista', SEMANA: 'Semana', QUINZENA: 'Quinzena', MES: 'Mês', BIMESTRE: 'Bimestre',
    TRIMESTRE: 'Trimestre', QUADRIMESTRE: 'Quadrimestre', ANO: 'Ano', ANOS: 'Vários anos', SISTEMA: 'Seguir o Windows (claro ou escuro)',
    CLARO: 'Sempre claro', ESCURO: 'Sempre escuro' },
  /** Nome da tabela; se o código não estiver nela, devolve o próprio código. */
  de(tabela, codigo) { const t = this[tabela] || {}; return codigo in t ? t[codigo] : (codigo ?? ''); }
});
