/* =============================================================================
   SistemaCMJ - js/cad/centro-custo.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Ficha do centro de custo (CAD_CENTRO_CUSTO): incluir
               (?empresa= já escolhe a empresa), alterar, desativar, reativar e
               excluir (lixeira); conta padrão pela escolha com busca
               (js/seletor.js, só contas da empresa escolhida); data de
               encerramento (sugestão "b" aprovada); abas Anexos e Histórico.
               Com lançamentos, a empresa não muda (trava no
               CAD_Centro_Custo_Gravar).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const idCentro = parseInt(Util.parametro('id') || '0', 10) || null;
  const empresaInicial = Util.parametro('empresa') || '';
  let sujo = false;
  let ativo = true;
  let naLixeira = false;
  let qtdLancamentos = 0;
  let empresas = [];
  let podeEditar = idCentro ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
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
      item: 'CAD_CENTRO_CUSTO', tabela: 'CAD.Centro_Custo', id: idCentro, podeAnexar: acoes.has('ALTERAR') && !naLixeira,
      aoMudar: (qtd) => { $('aba-anexos').textContent = 'Anexos' + (qtd ? ' (' + qtd + ')' : ''); }
    });
    if (await anexos.carregar()) carregadas.add('anexos');
  }
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico'), {
      item: 'CAD_CENTRO_CUSTO', tabela: 'CAD.Centro_Custo', id: idCentro, nomeRegistro: 'Centro de custo', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar('/cad/centro-custo.html?id=' + encodeURIComponent(idCentro) + '#historico'); }
    });
    if (await historico.carregar()) carregadas.add('historico');
  }

  // ---------- Conta padrão (escolha com busca, só contas da empresa escolhida) ----------
  const conta = Seletor.criar($('seletor-conta'), {
    tipo: 'CONTA', rotulo: 'Conta bancária padrão', placeholder: '(em branco: usa a da empresa)',
    idEmpresa: () => Number($('idEmpresa').value) || -1,
    aoMudar: () => { sujo = true; }
  });
  function mostrarContaEmpresa() {
    const e = empresas.find((x) => String(x.ID_EMPRESA) === $('idEmpresa').value);
    $('conta-empresa').textContent = e && e.CONTA_PADRAO_DESCRICAO ? 'Conta padrão da empresa: ' + e.CONTA_PADRAO_DESCRICAO : '';
  }
  $('idEmpresa').addEventListener('change', async () => {
    mostrarContaEmpresa();
    if (conta.valor()) { await conta.definir(null); Mensagens.sucesso('A empresa mudou: escolha de novo a conta padrão, se for o caso.'); }
  });

  // ---------- Encerramento ----------
  function mostrarEncerramento() {
    const d = $('dtEncerramento').value;
    const aviso = $('aviso-encerrado');
    aviso.hidden = !d;
    if (d) aviso.textContent = (d <= new Date().toISOString().substring(0, 10) ? 'Centro encerrado em ' : 'Centro será encerrado em ')
      + Util.data(d + 'T00:00:00') + ': lançamento novo com data depois disso é bloqueado ou avisado, conforme a configuração do sistema.';
  }
  $('dtEncerramento').addEventListener('change', mostrarEncerramento);

  function atualizarCabecalho(c) {
    const nome = c ? c.CODIGO + ' - ' + c.DESCRICAO : 'Novo centro de custo';
    $('titulo').textContent = nome;
    document.title = 'SistemaCMJ – ' + nome;
    if (!c) { $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.'; return; }
    $('subtitulo').textContent = [c.EMPRESA_NOME_FANTASIA || c.EMPRESA_RAZAO_SOCIAL, Rotulos.de('centroTipo', c.TIPO),
      qtdLancamentos ? qtdLancamentos.toLocaleString('pt-BR') + ' lançamento(s)' : 'sem lançamentos',
      !c.ATIVO ? 'Inativo' : (c.ENCERRADO ? 'Encerrado' : 'Em uso')].join(' · ');
    const partes = [];
    if (c.DT_CRIACAO) partes.push('Criado em ' + Util.dataHora(c.DT_CRIACAO) + (c.USUARIO_CRIACAO ? ' por ' + c.USUARIO_CRIACAO : ''));
    if (c.DT_ALTERACAO) partes.push('Alterado em ' + Util.dataHora(c.DT_ALTERACAO) + (c.USUARIO_ALTERACAO ? ' por ' + c.USUARIO_ALTERACAO : ''));
    if (c.CODIGO_ACCESS) partes.push('Código no Access: ' + c.CODIGO_ACCESS);
    $('rodape').textContent = partes.join(' · ');
  }

  // ---------- Carga ----------
  const rEmp = await Api.get('/api/cad/empresas');
  empresas = rEmp.sucesso ? rEmp.dados || [] : [];
  let c = null;
  if (idCentro) {
    const r = await Api.get('/api/cad/centros-custo/' + idCentro);
    if (!(await Mensagens.tratar(r))) { location.href = '/cad/centros-custo.html'; return; }
    c = r.dados;
  }
  for (const e of empresas.filter((x) => x.ATIVO || (c && x.ID_EMPRESA === c.ID_EMPRESA))) {
    const op = Util.el('option', null, (e.NOME_FANTASIA || e.RAZAO_SOCIAL) + (e.ATIVO ? '' : ' (inativa)'));
    op.value = e.ID_EMPRESA;
    $('idEmpresa').append(op);
  }
  if (c) {
    $('idEmpresa').value = c.ID_EMPRESA;
    $('codigo').value = c.CODIGO;
    $('descricao').value = c.DESCRICAO;
    $('tipo').value = c.TIPO;
    $('contabil').checked = !!c.CONTABIL;
    $('dtEncerramento').value = Util.dataIso(c.DT_ENCERRAMENTO);
    await conta.definir(c.ID_CONTA_BANCARIA_PADRAO);
    ativo = !!c.ATIVO;
    naLixeira = !!c.NA_LIXEIRA;
    qtdLancamentos = c.QTD_LANCAMENTOS || 0;
    atualizarCabecalho(c);
    $('aba-anexos').hidden = false;
    $('aba-historico').hidden = false;
    if (naLixeira) {
      const aviso = $('aviso-lixeira');
      aviso.replaceChildren(document.createTextNode('Este centro está na lixeira: a ficha abre só para consulta. Para usar de novo, recupere na '));
      const link = Util.el('a', null, 'Lixeira');
      link.href = '/sis/lixeira.html?item=CAD_CENTRO_CUSTO';
      aviso.append(link, document.createTextNode('.'));
      aviso.hidden = false;
    }
    $('botao-excluir').hidden = naLixeira || qtdLancamentos > 0 || !acoes.has('EXCLUIR');
    $('botao-desativar').hidden = naLixeira || !ativo || !acoes.has('DESATIVAR');
    $('botao-reativar').hidden = naLixeira || ativo || !acoes.has('DESATIVAR');
  } else {
    $('idEmpresa').value = empresaInicial;
    $('tipo').value = 'OBRA';
    atualizarCabecalho(null);
  }
  mostrarContaEmpresa();
  mostrarEncerramento();

  if (naLixeira) podeEditar = false;
  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) { for (const el of $('ficha').querySelectorAll('input, select, textarea')) el.disabled = true; conta.habilitar(false); }
  else if (qtdLancamentos > 0) { $('idEmpresa').disabled = true; $('idEmpresa').closest('label').dataset.dica = 'O centro já tem lançamentos: a empresa não muda mais.'; }
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  $('codigo').addEventListener('input', () => { $('codigo').value = $('codigo').value.toUpperCase().replace(/\s/g, ''); });
  if (podeEditar) ($('idEmpresa').value ? $('codigo') : $('idEmpresa')).focus();

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!podeEditar) return;
    const falta = !$('idEmpresa').value ? ['idEmpresa', 'Escolha a empresa do centro de custo.']
      : !$('codigo').value.trim() ? ['codigo', 'Informe o código do centro de custo (ex.: 62 ou ESC).']
      : !$('descricao').value.trim() ? ['descricao', 'Informe a descrição do centro de custo.'] : null;
    if (falta) { await Mensagens.alerta(falta[1], 'ATENCAO', { foco: $(falta[0]) }); return; }
    const nome = $('codigo').value.trim() + ' - ' + $('descricao').value.trim();
    if (!(await Mensagens.confirmar('Gravar?', (idCentro ? 'Confirma a gravação das alterações de ' : 'Confirma a inclusão de ') + nome + '?', 'Gravar'))) return;
    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/cad/centros-custo', {
      idCentroCusto: idCentro, idEmpresa: Number($('idEmpresa').value), codigo: $('codigo').value.trim(), descricao: $('descricao').value.trim(),
      tipo: $('tipo').value, contabil: $('contabil').checked, idContaBancariaPadrao: conta.valor(), dtEncerramento: $('dtEncerramento').value || null
    });
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Centro de custo gravado.');
    location.replace('/cad/centro-custo.html?id=' + encodeURIComponent((r.dados && r.dados.id) || idCentro));
  });

  // ---------- Desativar / reativar / excluir / sair ----------
  async function mudarSituacao(reativar) {
    const nome = $('descricao').value.trim() || 'este centro';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Esta ação não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const ok = reativar
      ? await Mensagens.confirmar('Reativar centro de custo?', nome + ' volta a aparecer nas listas de escolha.', 'Reativar')
      : await Mensagens.confirmar('Desativar centro de custo?', nome + ' será desativado: some das listas de escolha, mas continua nos lançamentos e no histórico. Para obra entregue, prefira a data de encerramento.', 'Desativar');
    if (!ok) return;
    const r = await Api.post('/api/cad/centros-custo/' + idCentro + '/excluir', { reativar });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Situação alterada.');
    location.replace('/cad/centro-custo.html?id=' + encodeURIComponent(idCentro));
  }
  $('botao-desativar').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));
  $('botao-excluir').addEventListener('click', async () => {
    const nome = $('descricao').value.trim() || 'este centro';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Excluir não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const motivo = await Mensagens.pedirTexto('Excluir centro de custo?',
      nome + ' vai para a lixeira: some de todas as telas e pode ser recuperado na Lixeira até o prazo acabar; depois é apagado de vez. '
      + 'Só dá para excluir centro que não é usado em nenhum lugar (senão, use Desativar).',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item: 'CAD_CENTRO_CUSTO', tabela: 'CAD.Centro_Custo', idRegistro: idCentro, motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Centro de custo enviado para a lixeira.');
    location.replace('/cad/centros-custo.html');
  });

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  const voltar = empresaInicial && !idCentro ? '/cad/empresa.html?id=' + encodeURIComponent(empresaInicial) + '#centros' : '/cad/centros-custo.html';
  if (empresaInicial && !idCentro) $('link-voltar').textContent = '‹ Voltar para a ficha da empresa';
  $('botao-cancelar').addEventListener('click', () => sair(voltar));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair(voltar); });
  if (idCentro && location.hash === '#historico') abrirAba($('aba-historico'));
});
