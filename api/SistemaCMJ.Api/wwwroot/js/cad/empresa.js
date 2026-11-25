/* =============================================================================
   SistemaCMJ - js/cad/empresa.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (etapa 04e)
   Descrição : Ficha da empresa (CAD_EMPRESA): incluir, alterar, desativar,
               reativar e excluir (lixeira); CNPJ e CEP preenchem a ficha pela
               consulta do servidor; rodapé dos e-mails com prévia (P11); conta
               padrão entre as contas da própria empresa; pasta do OFX só para
               administrador; logomarca (anexo do tipo Logomarca); abas Contas
               bancárias, Centros de custo, Anexos e Histórico. Validações de verdade ficam no
               CAD_Empresa_Gravar.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao, acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const idEmpresa = parseInt(Util.parametro('id') || '0', 10) || null;
  const CAMPOS = ['razaoSocial', 'nomeFantasia', 'cnpj', 'cnpjCompras', 'tipo', 'regimeTributario', 'inscricaoEstadual', 'inscricaoMunicipal',
    'email', 'telefone', 'cep', 'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'rodapeEmail'];
  let sujo = false;
  let ativo = true;
  let naLixeira = false;
  let podePastaOfx = false;
  let podeEditar = idEmpresa ? acoes.has('ALTERAR') : acoes.has('INCLUIR');
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
  abas.forEach((a) => {
    a.addEventListener('click', () => abrirAba(a));
    a.addEventListener('keydown', (e) => {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      const visiveis = abas.filter((x) => !x.hidden);
      const pos = visiveis.indexOf(a);
      const prox = visiveis[(pos + (e.key === 'ArrowRight' ? 1 : visiveis.length - 1)) % visiveis.length];
      prox.focus();
      abrirAba(prox);
    });
  });

  // ---------- Rodapé dos e-mails: prévia (P11) ----------
  function previaRodape() {
    const caixa = $('rodape-previa');
    caixa.replaceChildren();
    const texto = $('rodapeEmail').value.trim();
    if (!texto) { caixa.append(Util.el('span', 'suave', '(sem rodapé: o e-mail sai só com o rodapé padrão do sistema)')); return; }
    const padrao = /([\w.+-]+@[\w-]+\.[\w.-]+)|((?:https?:\/\/|www\.)[^\s]+)/gi;
    texto.split(/\r?\n/).forEach((linha, i) => {
      if (i) caixa.append(Util.el('br'));
      let pos = 0;
      for (const m of linha.matchAll(padrao)) {
        caixa.append(document.createTextNode(linha.slice(pos, m.index)));
        const a = Util.el('a', null, m[0]);
        a.href = m[1] ? 'mailto:' + m[1] : (m[0].startsWith('http') ? m[0] : 'https://' + m[0]);
        a.target = '_blank';
        a.rel = 'noopener';
        caixa.append(a);
        pos = m.index + m[0].length;
      }
      caixa.append(document.createTextNode(linha.slice(pos)));
    });
  }
  $('rodapeEmail').addEventListener('input', previaRodape);

  // ---------- Contas da empresa ----------
  async function carregarContas() {
    const r = await Api.get('/api/banco/contas', { idEmpresa });
    if (!r.sucesso) return; // sem permissão nas contas: a aba fica vazia
    const contas = r.dados || [];
    const corpo = $('linhas-contas');
    corpo.replaceChildren();
    if (!contas.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhuma conta cadastrada para esta empresa.');
      td.colSpan = 6;
      tr.append(td);
      corpo.append(tr);
    }
    for (const c of contas) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      const abrir = () => sair('/banco/conta.html?id=' + encodeURIComponent(c.ID_CONTA));
      tr.addEventListener('click', abrir);
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(); });
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (c.ATIVO ? 'situacao-ativo' : 'situacao-inativo'), c.ATIVO ? 'Ativa' : 'Inativa'));
      tr.append(Util.el('td', 'forte', c.DESCRICAO), Util.el('td', null, Rotulos.de('contaTipo', c.TIPO)),
        Util.el('td', null, c.BANCO_CODIGO ? c.BANCO_CODIGO + ' - ' + c.BANCO_NOME : ''),
        Util.el('td', 'numero', c.AGENCIA ? [c.AGENCIA + (c.AGENCIA_DV ? '-' + c.AGENCIA_DV : ''), c.NUMERO + (c.NUMERO_DV ? '-' + c.NUMERO_DV : '')].join(' / ') : ''),
        Util.el('td', null, c.PADRAO_DA_EMPRESA ? 'Padrão' : ''), sit);
      corpo.append(tr);
    }
    $('aba-contas').textContent = 'Contas bancárias' + (contas.length ? ' (' + contas.length + ')' : '');
    const sel = $('idContaBancariaPadrao');
    const atual = sel.dataset.valor || '';
    const nenhuma = Util.el('option', null, '(nenhuma)');
    nenhuma.value = '';
    sel.replaceChildren(nenhuma);
    for (const c of contas.filter((x) => x.ATIVO || String(x.ID_CONTA) === atual)) {
      const op = Util.el('option', null, c.DESCRICAO + (c.ATIVO ? '' : ' (inativa)'));
      op.value = c.ID_CONTA;
      sel.append(op);
    }
    sel.value = atual;
  }

  // ---------- Centros de custo da empresa ----------
  async function carregarCentros() {
    const r = await Api.get('/api/cad/centros-custo', { idEmpresa });
    if (!r.sucesso) { $('aba-centros').hidden = true; return; }
    const centros = r.dados || [];
    const corpo = $('linhas-centros');
    corpo.replaceChildren();
    if (!centros.length) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum centro de custo cadastrado para esta empresa.');
      td.colSpan = 6;
      tr.append(td);
      corpo.append(tr);
    }
    for (const c of centros) {
      const tr = Util.el('tr', 'clicavel');
      tr.tabIndex = 0;
      const abrir = () => sair('/cad/centro-custo.html?id=' + encodeURIComponent(c.ID_CENTRO_CUSTO));
      tr.addEventListener('click', abrir);
      tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') abrir(); });
      const sit = Util.el('td');
      sit.append(Util.el('span', 'situacao ' + (c.ATIVO && !c.ENCERRADO ? 'situacao-ativo' : 'situacao-inativo'), !c.ATIVO ? 'Inativo' : (c.ENCERRADO ? 'Encerrado' : 'Em uso')));
      tr.append(Util.el('td', 'numero', c.CODIGO), Util.el('td', 'forte', c.DESCRICAO), Util.el('td', null, Rotulos.de('centroTipo', c.TIPO)),
        Util.el('td', null, c.CONTA_PADRAO_DESCRICAO || (c.CONTA_EFETIVA_DESCRICAO ? c.CONTA_EFETIVA_DESCRICAO + ' (da empresa)' : '')),
        Util.el('td', null, Util.data(c.DT_ENCERRAMENTO)), sit);
      corpo.append(tr);
    }
    const emUso = centros.filter((c) => c.ATIVO && !c.ENCERRADO).length;
    $('aba-centros').textContent = 'Centros de custo' + (centros.length ? ' (' + emUso + ' em uso)' : '');
  }

  // ---------- Logomarca (anexo do tipo LOGOMARCA mais recente) ----------
  async function carregarLogomarca() {
    const r = await Api.get('/api/sis/anexos', { item: 'CAD_EMPRESA', tabela: 'CAD.Empresa', idRegistro: idEmpresa });
    const logo = r.sucesso ? (r.dados || []).find((a) => a.TIPO_CODIGO === 'LOGOMARCA' && a.SITUACAO === 'ATIVO') : null;
    $('logomarca').hidden = !logo;
    if (logo) $('logomarca-imagem').src = '/api/sis/anexos/' + logo.ID_ANEXO + '/arquivo?item=CAD_EMPRESA';
  }

  // ---------- Anexos e Histórico (componentes padrão) ----------
  let anexos = null;
  async function carregarAnexos() {
    if (!anexos) anexos = Anexos.criar($('anexos'), {
      item: 'CAD_EMPRESA', tabela: 'CAD.Empresa', id: idEmpresa,
      podeAnexar: acoes.has('ALTERAR') && !naLixeira,
      aoMudar: (qtd) => { $('aba-anexos').textContent = 'Anexos' + (qtd ? ' (' + qtd + ')' : ''); carregarLogomarca(); }
    });
    if (await anexos.carregar()) carregadas.add('anexos');
  }
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico'), {
      item: 'CAD_EMPRESA', tabela: 'CAD.Empresa', id: idEmpresa, nomeRegistro: 'Empresa', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar('/cad/empresa.html?id=' + encodeURIComponent(idEmpresa) + '#historico'); }
    });
    if (await historico.carregar()) carregadas.add('historico');
  }

  // ---------- Carga ----------
  function atualizarCabecalho(e) {
    const nome = e ? (e.NOME_FANTASIA || e.RAZAO_SOCIAL) : 'Nova empresa';
    $('titulo').textContent = nome;
    document.title = 'SistemaCMJ – ' + nome;
    if (!e) { $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.'; return; }
    $('subtitulo').textContent = ['Código ' + String(e.ID_EMPRESA).padStart(4, '0'), Rotulos.de('empresaTipo', e.TIPO), e.CNPJ_FORMATADO,
      e.ATIVO ? 'Ativa' : 'Inativa'].filter(Boolean).join(' · ');
    const partes = [];
    if (e.DT_CRIACAO) partes.push('Criada em ' + Util.dataHora(e.DT_CRIACAO) + (e.USUARIO_CRIACAO ? ' por ' + e.USUARIO_CRIACAO : ''));
    if (e.DT_ALTERACAO) partes.push('Alterada em ' + Util.dataHora(e.DT_ALTERACAO) + (e.USUARIO_ALTERACAO ? ' por ' + e.USUARIO_ALTERACAO : ''));
    if (e.CODIGO_ACCESS) partes.push('Código no Access: ' + e.CODIGO_ACCESS);
    $('rodape').textContent = partes.join(' · ');
  }

  if (idEmpresa) {
    const r = await Api.get('/api/cad/empresas/' + idEmpresa);
    if (!(await Mensagens.tratar(r))) { location.href = '/cad/empresas.html'; return; }
    const e = r.dados;
    const colunas = { razaoSocial: 'RAZAO_SOCIAL', nomeFantasia: 'NOME_FANTASIA', cnpj: 'CNPJ_FORMATADO', cnpjCompras: 'CNPJ_COMPRAS_FORMATADO',
      tipo: 'TIPO', regimeTributario: 'REGIME_TRIBUTARIO', inscricaoEstadual: 'INSCRICAO_ESTADUAL', inscricaoMunicipal: 'INSCRICAO_MUNICIPAL',
      email: 'EMAIL', telefone: 'TELEFONE', cep: 'CEP', logradouro: 'LOGRADOURO', numero: 'NUMERO', complemento: 'COMPLEMENTO',
      bairro: 'BAIRRO', cidade: 'CIDADE', uf: 'UF', rodapeEmail: 'RODAPE_EMAIL', pastaOfx: 'PASTA_OFX' };
    for (const [campo, coluna] of Object.entries(colunas)) $(campo).value = e[coluna] ?? '';
    $('idContaBancariaPadrao').dataset.valor = e.ID_CONTA_BANCARIA_PADRAO ? String(e.ID_CONTA_BANCARIA_PADRAO) : '';
    ativo = !!e.ATIVO;
    naLixeira = !!e.NA_LIXEIRA;
    podePastaOfx = !!e.PODE_PASTA_OFX;
    atualizarCabecalho(e);
    for (const id of ['aba-contas', 'aba-centros', 'aba-anexos', 'aba-historico']) $(id).hidden = false;
    const incluirCentro = $('incluir-centro');
    incluirCentro.href = '/cad/centro-custo.html?empresa=' + encodeURIComponent(idEmpresa);
    incluirCentro.hidden = naLixeira || !ativo || !Layout.acoesDe('cad/centros-custo.html').has('INCLUIR');
    const incluirConta = $('incluir-conta');
    incluirConta.href = '/banco/conta.html?empresa=' + encodeURIComponent(idEmpresa);
    incluirConta.hidden = naLixeira || !ativo || !Layout.acoesDe('banco/contas.html').has('INCLUIR');
    if (naLixeira) {
      const aviso = $('aviso-lixeira');
      aviso.replaceChildren(document.createTextNode('Esta empresa está na lixeira: a ficha abre só para consulta. Para usar de novo, recupere na '));
      const link = Util.el('a', null, 'Lixeira');
      link.href = '/sis/lixeira.html?item=CAD_EMPRESA';
      aviso.append(link, document.createTextNode('.'));
      aviso.hidden = false;
    }
    $('botao-excluir').hidden = naLixeira || !acoes.has('EXCLUIR');
    $('botao-desativar').hidden = naLixeira || !ativo || !acoes.has('DESATIVAR');
    $('botao-reativar').hidden = naLixeira || ativo || !acoes.has('DESATIVAR');
    await Promise.all([carregarContas(), carregarCentros(), carregarLogomarca()]);
  } else {
    podePastaOfx = Number(sessao && sessao.nivelAdmin) >= 1;
    $('tipo').value = 'SPE';
    $('idContaBancariaPadrao').closest('label').hidden = true; // conta padrão: só depois de cadastrar as contas
    atualizarCabecalho(null);
  }
  $('campo-pasta-ofx').hidden = !podePastaOfx;
  previaRodape();

  if (naLixeira) podeEditar = false;
  $('botao-gravar').hidden = !podeEditar;
  if (!podeEditar) for (const el of $('ficha').querySelectorAll('input, select, textarea')) el.disabled = true;
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  if (podeEditar) $('razaoSocial').focus();

  // ---------- Consulta de CNPJ e CEP (mesma da ficha de Parceiros) ----------
  const soDigitos = (t) => (t || '').replace(/\D/g, '');
  async function preencher(valores, titulo) {
    const diferentes = Object.entries(valores).filter(([c, v]) => v && $(c).value.trim() && $(c).value.trim() !== v);
    const trocar = diferentes.length === 0 || await Mensagens.confirmar(titulo,
      'Já há dados digitados que são diferentes dos encontrados (' + diferentes.map(([c]) => $(c).closest('label').firstChild.textContent.trim()).join(', ') + '). Trocar pelos encontrados?', 'Trocar');
    for (const [c, v] of Object.entries(valores)) {
      if (!v) continue;
      if (!$(c).value.trim() || trocar) $(c).value = v;
    }
    sujo = true;
  }
  let ultimoCep = soDigitos($('cep').value);
  $('cep').addEventListener('change', async () => {
    const cep = soDigitos($('cep').value);
    if (!podeEditar || cep.length !== 8 || cep === ultimoCep) return;
    ultimoCep = cep;
    const r = await Api.get('/api/cad/consulta/cep/' + cep);
    if (!(await Mensagens.tratar(r, { foco: $('logradouro') }))) return;
    const e = r.dados || {};
    await preencher({ logradouro: e.logradouro, bairro: e.bairro, cidade: e.cidade, uf: e.uf }, 'Endereço do CEP');
    Mensagens.sucesso('Endereço preenchido pelo CEP. Confira e informe o número.');
    $('numero').focus();
  });
  let ultimoCnpj = soDigitos($('cnpj').value);
  $('cnpj').addEventListener('change', async () => {
    const cnpj = soDigitos($('cnpj').value);
    if (!podeEditar || cnpj.length !== 14 || cnpj === ultimoCnpj) return;
    ultimoCnpj = cnpj;
    const r = await Api.get('/api/cad/consulta/cnpj/' + cnpj);
    if (!(await Mensagens.tratar(r, { foco: $('razaoSocial') }))) return;
    const d = r.dados || {};
    if (d.situacao && !d.situacaoAtiva)
      await Mensagens.alerta('Atenção: na Receita Federal este CNPJ está com a situação "' + d.situacao + '" (não está ATIVA). Confira antes de gravar.', 'ATENCAO');
    await preencher({ razaoSocial: d.razaoSocial, nomeFantasia: d.nomeFantasia, cep: d.cep, logradouro: d.logradouro, numero: d.numero,
      complemento: d.complemento, bairro: d.bairro, cidade: d.cidade, uf: d.uf, email: d.email, telefone: d.telefone }, 'Dados da Receita Federal');
    ultimoCep = soDigitos($('cep').value);
    Mensagens.sucesso('Dados preenchidos pela Receita Federal. Confira as abas Dados principais e Endereço.');
  });

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!podeEditar) return;
    const faltando = [['razaoSocial', 'Informe a razão social.'], ['cnpj', 'Informe o CNPJ.']].find(([c]) => !$(c).value.trim());
    if (faltando) {
      abrirAba($('aba-dados'));
      await Mensagens.alerta(faltando[1], 'ATENCAO', { foco: $(faltando[0]) });
      return;
    }
    const nome = $('razaoSocial').value.trim();
    if (!(await Mensagens.confirmar('Gravar?', (idEmpresa ? 'Confirma a gravação das alterações de ' : 'Confirma a inclusão de ') + nome + '?', 'Gravar'))) return;
    const corpo = { idEmpresa };
    for (const c of CAMPOS) corpo[c] = $(c).value;
    corpo.idContaBancariaPadrao = $('idContaBancariaPadrao').value ? Number($('idContaBancariaPadrao').value) : null;
    corpo.pastaOfx = podePastaOfx ? $('pastaOfx').value : null;
    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/cad/empresas', corpo);
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Empresa gravada.');
    location.replace('/cad/empresa.html?id=' + encodeURIComponent((r.dados && r.dados.id) || idEmpresa));
  });

  // ---------- Desativar / reativar / excluir / sair ----------
  async function mudarSituacao(reativar) {
    const nome = $('razaoSocial').value.trim() || 'esta empresa';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Esta ação não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const ok = reativar
      ? await Mensagens.confirmar('Reativar empresa?', nome + ' volta a aparecer nas listas de escolha.', 'Reativar')
      : await Mensagens.confirmar('Desativar empresa?', nome + ' será desativada: some das listas de escolha, mas continua nos lançamentos e no histórico. Antes, desative as contas e os centros de custo dela.', 'Desativar');
    if (!ok) return;
    const r = await Api.post('/api/cad/empresas/' + idEmpresa + '/excluir', { reativar });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Situação alterada.');
    location.replace('/cad/empresa.html?id=' + encodeURIComponent(idEmpresa));
  }
  $('botao-desativar').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));
  $('botao-excluir').addEventListener('click', async () => {
    const nome = $('razaoSocial').value.trim() || 'esta empresa';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Excluir não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const motivo = await Mensagens.pedirTexto('Excluir empresa?',
      nome + ' vai para a lixeira: some de todas as telas e pode ser recuperada na Lixeira até o prazo acabar; depois é apagada de vez. '
      + 'Só dá para excluir empresa que não é usada em nenhum lugar (senão, use Desativar). Enquanto estiver na lixeira, o CNPJ continua ocupado.',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item: 'CAD_EMPRESA', tabela: 'CAD.Empresa', idRegistro: idEmpresa, motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Empresa enviada para a lixeira.');
    location.replace('/cad/empresas.html');
  });

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-cancelar').addEventListener('click', () => sair('/cad/empresas.html'));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair('/cad/empresas.html'); });
  if (idEmpresa && location.hash === '#historico') abrirAba($('aba-historico'));
  if (idEmpresa && location.hash === '#anexos') abrirAba($('aba-anexos'));
  if (idEmpresa && location.hash === '#contas') abrirAba($('aba-contas'));
  if (idEmpresa && location.hash === '#centros') abrirAba($('aba-centros'));
});
