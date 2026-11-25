/* =============================================================================
   SistemaCMJ - js/banco/conta.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Ficha da conta bancária, caixa ou conta de permuta (BANCO_CONTA):
               incluir (?empresa= já escolhe a empresa), alterar, desativar,
               reativar e excluir (lixeira), abas Anexos e Histórico. Caixa e
               Permuta escondem banco, agência e conta. Com movimento
               (TEM_MOVIMENTO), empresa, tipo e saldo inicial ficam travados;
               a trava que vale está no BANCO_Conta_Gravar.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const idConta = parseInt(Util.parametro('id') || '0', 10) || null;
  const empresaInicial = Util.parametro('empresa') || '';
  let sujo = false;
  let ativo = true;
  let naLixeira = false;
  let temMovimento = false;
  let podeEditar = idConta ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
  const carregadas = new Set();

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    if (aba.id === 'aba-historico' && !carregadas.has('historico')) carregarHistorico();
    if (aba.id === 'aba-anexos' && !carregadas.has('anexos')) carregarAnexos();
  }
  abas.forEach((a) => a.addEventListener('click', () => abrirAba(a)));

  let anexos = null;
  async function carregarAnexos() {
    if (!anexos) anexos = Anexos.criar($('anexos'), {
      item: 'BANCO_CONTA', tabela: 'BANCO.Conta', id: idConta, podeAnexar: acoes.has('ALTERAR') && !naLixeira,
      aoMudar: (qtd) => { $('aba-anexos').textContent = 'Anexos' + (qtd ? ' (' + qtd + ')' : ''); }
    });
    if (await anexos.carregar()) carregadas.add('anexos');
  }
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico'), {
      item: 'BANCO_CONTA', tabela: 'BANCO.Conta', id: idConta, nomeRegistro: 'Conta', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar('/banco/conta.html?id=' + encodeURIComponent(idConta) + '#historico'); }
    });
    if (await historico.carregar()) carregadas.add('historico');
  }

  // ---------- Tipo: caixa e permuta não têm banco ----------
  const temBanco = () => !['CAIXA', 'PERMUTA'].includes($('tipo').value);
  function aplicarTipo() { for (const el of document.querySelectorAll('.so-banco')) el.hidden = !temBanco(); }
  $('tipo').addEventListener('change', aplicarTipo);

  // ---------- Listas de escolha ----------
  async function carregarEscolhas(conta) {
    const [rEmp, rBco] = await Promise.all([Api.get('/api/cad/empresas'), Api.get('/api/banco/bancos')]);
    for (const e of (rEmp.sucesso ? rEmp.dados || [] : []).filter((x) => x.ATIVO || (conta && x.ID_EMPRESA === conta.ID_EMPRESA))) {
      const op = Util.el('option', null, (e.NOME_FANTASIA || e.RAZAO_SOCIAL) + (e.ATIVO ? '' : ' (inativa)'));
      op.value = e.ID_EMPRESA;
      $('idEmpresa').append(op);
    }
    const bancos = rBco.sucesso ? rBco.dados || [] : [];
    if (conta && conta.ID_BANCO && !bancos.some((b) => b.ID_BANCO === conta.ID_BANCO))
      bancos.push({ ID_BANCO: conta.ID_BANCO, CODIGO: conta.BANCO_CODIGO, NOME: conta.BANCO_NOME + ' (inativo)' });
    for (const b of bancos) {
      const op = Util.el('option', null, b.CODIGO + ' - ' + b.NOME);
      op.value = b.ID_BANCO;
      $('idBanco').append(op);
    }
  }

  function atualizarCabecalho(c) {
    $('titulo').textContent = c ? c.DESCRICAO : 'Nova conta';
    document.title = 'SistemaCMJ – ' + (c ? c.DESCRICAO : 'Nova conta');
    if (!c) { $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.'; return; }
    $('subtitulo').textContent = [c.EMPRESA_NOME_FANTASIA || c.EMPRESA_RAZAO_SOCIAL, Rotulos.de('contaTipo', c.TIPO),
      c.PADRAO_DA_EMPRESA ? 'Conta padrão da empresa' : '', c.ATIVO ? 'Ativa' : 'Inativa'].filter(Boolean).join(' · ');
    const partes = [];
    if (c.DT_CRIACAO) partes.push('Criada em ' + Util.dataHora(c.DT_CRIACAO) + (c.USUARIO_CRIACAO ? ' por ' + c.USUARIO_CRIACAO : ''));
    if (c.DT_ALTERACAO) partes.push('Alterada em ' + Util.dataHora(c.DT_ALTERACAO) + (c.USUARIO_ALTERACAO ? ' por ' + c.USUARIO_ALTERACAO : ''));
    if (c.CODIGO_ACCESS) partes.push('Código no Access: ' + c.CODIGO_ACCESS);
    $('rodape').textContent = partes.join(' · ');
  }

  // ---------- Carga ----------
  if (idConta) {
    const r = await Api.get('/api/banco/contas/' + idConta);
    if (!(await Mensagens.tratar(r))) { location.href = '/banco/contas.html'; return; }
    const c = r.dados;
    await carregarEscolhas(c);
    $('idEmpresa').value = c.ID_EMPRESA;
    $('descricao').value = c.DESCRICAO;
    $('tipo').value = c.TIPO;
    $('idBanco').value = c.ID_BANCO ?? '';
    for (const [campo, coluna] of Object.entries({ agencia: 'AGENCIA', agenciaDv: 'AGENCIA_DV', numero: 'NUMERO', numeroDv: 'NUMERO_DV', contaContabilRef: 'CONTA_CONTABIL_REF', ordem: 'ORDEM' }))
      $(campo).value = c[coluna] ?? '';
    $('limiteCredito').value = Util.moeda(c.LIMITE_CREDITO);
    $('saldoInicial').value = Util.moeda(c.SALDO_INICIAL);
    $('dtSaldoInicial').value = Util.dataIso(c.DT_SALDO_INICIAL);
    $('concilia').checked = !!c.CONCILIA;
    $('mostraSaldo').checked = !!c.MOSTRA_SALDO;
    ativo = !!c.ATIVO;
    naLixeira = !!c.NA_LIXEIRA;
    temMovimento = !!c.TEM_MOVIMENTO;
    atualizarCabecalho(c);
    $('aba-anexos').hidden = false;
    $('aba-historico').hidden = false;
    $('aviso-movimento').hidden = !temMovimento;
    if (naLixeira) {
      const aviso = $('aviso-lixeira');
      aviso.replaceChildren(document.createTextNode('Esta conta está na lixeira: a ficha abre só para consulta. Para usar de novo, recupere na '));
      const link = Util.el('a', null, 'Lixeira');
      link.href = '/sis/lixeira.html?item=BANCO_CONTA';
      aviso.append(link, document.createTextNode('.'));
      aviso.hidden = false;
    }
    $('botao-excluir').hidden = naLixeira || temMovimento || !acoes.has('EXCLUIR');
    $('botao-desativar').hidden = naLixeira || !ativo || !acoes.has('DESATIVAR');
    $('botao-reativar').hidden = naLixeira || ativo || !acoes.has('DESATIVAR');
  } else {
    await carregarEscolhas(null);
    $('idEmpresa').value = empresaInicial;
    $('tipo').value = 'CORRENTE';
    const sicredi = [...$('idBanco').options].find((o) => o.textContent.startsWith('748 '));
    if (sicredi) $('idBanco').value = sicredi.value;
    atualizarCabecalho(null);
  }
  aplicarTipo();

  if (naLixeira) podeEditar = false;
  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) for (const el of $('ficha').querySelectorAll('input, select, textarea')) el.disabled = true;
  else if (temMovimento) for (const id of ['idEmpresa', 'tipo', 'saldoInicial', 'dtSaldoInicial']) $(id).disabled = true;
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  if (podeEditar) ($('idEmpresa').value ? $('descricao') : $('idEmpresa')).focus();

  for (const id of ['limiteCredito', 'saldoInicial']) {
    $(id).addEventListener('blur', () => {
      const v = Util.lerMoeda($(id).value);
      if (!Number.isNaN(v)) $(id).value = Util.moeda(v);
    });
  }

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!podeEditar) return;
    const limite = Util.lerMoeda($('limiteCredito').value);
    const saldo = Util.lerMoeda($('saldoInicial').value);
    const falta = !$('idEmpresa').value ? ['idEmpresa', 'Escolha a empresa titular da conta.']
      : !$('descricao').value.trim() ? ['descricao', 'Informe a descrição da conta (ex.: Sicredi Orion).']
      : (temBanco() && !$('idBanco').value) ? ['idBanco', 'Escolha o banco da conta.']
      : (temBanco() && (!$('agencia').value.trim() || !$('numero').value.trim())) ? [$('agencia').value.trim() ? 'numero' : 'agencia', 'Informe a agência e o número da conta.']
      : Number.isNaN(limite) ? ['limiteCredito', 'Limite de crédito inválido. Use só números, com vírgula nos centavos.']
      : Number.isNaN(saldo) ? ['saldoInicial', 'Saldo inicial inválido. Use só números, com vírgula nos centavos.']
      : (saldo !== 0 && !$('dtSaldoInicial').value) ? ['dtSaldoInicial', 'Informe a data do saldo inicial.'] : null;
    if (falta) { await Mensagens.alerta(falta[1], 'ATENCAO', { foco: $(falta[0]) }); return; }
    const desc = $('descricao').value.trim();
    if (!(await Mensagens.confirmar('Gravar?', (idConta ? 'Confirma a gravação das alterações da conta ' : 'Confirma a inclusão da conta ') + desc + '?', 'Gravar'))) return;
    const corpo = {
      idConta, idEmpresa: Number($('idEmpresa').value), descricao: desc, tipo: $('tipo').value,
      idBanco: temBanco() && $('idBanco').value ? Number($('idBanco').value) : null,
      agencia: $('agencia').value, agenciaDv: $('agenciaDv').value, numero: $('numero').value, numeroDv: $('numeroDv').value,
      limiteCredito: temBanco() ? limite : 0, saldoInicial: saldo, dtSaldoInicial: $('dtSaldoInicial').value || null,
      concilia: temBanco() && $('concilia').checked, mostraSaldo: $('mostraSaldo').checked,
      contaContabilRef: $('contaContabilRef').value, ordem: $('ordem').value === '' ? 0 : Number($('ordem').value)
    };
    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/banco/contas', corpo);
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Conta gravada.');
    location.replace('/banco/conta.html?id=' + encodeURIComponent((r.dados && r.dados.id) || idConta));
  });

  // ---------- Desativar / reativar / excluir / sair ----------
  async function mudarSituacao(reativar) {
    const desc = $('descricao').value.trim() || 'esta conta';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Esta ação não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const ok = reativar
      ? await Mensagens.confirmar('Reativar conta?', desc + ' volta a aparecer nas listas de escolha.', 'Reativar')
      : await Mensagens.confirmar('Desativar conta?', desc + ' será desativada: some das listas de escolha, mas o movimento e o histórico continuam.', 'Desativar');
    if (!ok) return;
    const r = await Api.post('/api/banco/contas/' + idConta + '/excluir', { reativar });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Situação alterada.');
    location.replace('/banco/conta.html?id=' + encodeURIComponent(idConta));
  }
  $('botao-desativar').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));
  $('botao-excluir').addEventListener('click', async () => {
    const desc = $('descricao').value.trim() || 'esta conta';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Excluir não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const motivo = await Mensagens.pedirTexto('Excluir conta?',
      desc + ' vai para a lixeira: some de todas as telas e pode ser recuperada na Lixeira até o prazo acabar; depois é apagada de vez. '
      + 'Só dá para excluir conta sem nenhum movimento (senão, use Desativar).',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item: 'BANCO_CONTA', tabela: 'BANCO.Conta', idRegistro: idConta, motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Conta enviada para a lixeira.');
    location.replace('/banco/contas.html');
  });

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  const voltar = empresaInicial && !idConta ? '/cad/empresa.html?id=' + encodeURIComponent(empresaInicial) + '#contas' : '/banco/contas.html';
  if (empresaInicial && !idConta) $('link-voltar').textContent = '‹ Voltar para a ficha da empresa';
  $('botao-cancelar').addEventListener('click', () => sair(voltar));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair(voltar); });
  if (idConta && location.hash === '#historico') abrirAba($('aba-historico'));
});
