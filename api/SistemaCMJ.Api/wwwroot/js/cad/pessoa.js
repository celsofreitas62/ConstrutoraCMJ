/* =============================================================================
   SistemaCMJ - js/cad/pessoa.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Ficha da pessoa (CAD_PESSOA): incluir, alterar, excluir
               (desativar) e reativar, com contatos, dados bancários, vínculos
               e histórico. Tudo é gravado de uma vez pelo CAD_Pessoa_Gravar
               (tudo ou nada); validações de verdade ficam na procedure.
               Botões e edição seguem as ações do usuário na tela.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);

  const idPessoa = parseInt(Util.parametro('id') || '0', 10) || null;
  const CAMPOS = ['nome', 'nomeFantasia', 'cpfCnpj', 'rg', 'orgaoEmissor', 'inscricaoEstadual', 'inscricaoMunicipal',
    'dtNascimento', 'nacionalidade', 'profissao', 'estadoCivil', 'regimeBens', 'cep', 'logradouro', 'numero',
    'complemento', 'bairro', 'cidade', 'uf', 'observacao'];
  const PAPEIS = ['cliente', 'fornecedor', 'funcionario', 'corretor'];

  let tipo = 'F';
  let ativo = true;
  let contatos = [];
  let bancarios = [];
  let vinculos = [];
  let bancos = [];
  let sujo = false;
  let historicoCarregado = false;
  const podeEditar = idPessoa ? acoes.has('ALTERAR') : acoes.has('INCLUIR');

  // ---------- Abas ----------
  const abas = [...document.querySelectorAll('.aba')];
  function abrirAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      a.tabIndex = ativa ? 0 : -1;
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
    if (aba.id === 'aba-historico' && !historicoCarregado) carregarHistorico();
  }
  abas.forEach((a, i) => {
    a.addEventListener('click', () => abrirAba(a));
    a.addEventListener('keydown', (e) => {
      const visiveis = abas.filter((x) => !x.hidden);
      const pos = visiveis.indexOf(a);
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        const prox = visiveis[(pos + (e.key === 'ArrowRight' ? 1 : visiveis.length - 1)) % visiveis.length];
        prox.focus();
        abrirAba(prox);
      }
    });
  });

  function contarAbas() {
    $('aba-contatos').textContent = 'Contatos' + (contatos.length ? ' (' + contatos.length + ')' : '');
    $('aba-bancarios').textContent = 'Dados bancários' + (bancarios.length ? ' (' + bancarios.length + ')' : '');
    $('aba-vinculos').textContent = 'Vínculos' + (vinculos.length ? ' (' + vinculos.length + ')' : '');
  }

  // ---------- Tipo PF/PJ ----------
  function aplicarTipo(novo) {
    tipo = novo;
    for (const b of document.querySelectorAll('[data-tipo]')) {
      const marcado = b.dataset.tipo === tipo;
      b.classList.toggle('ativa', marcado);
      b.setAttribute('aria-checked', marcado ? 'true' : 'false');
    }
    for (const e of document.querySelectorAll('.so-pf')) e.hidden = tipo !== 'F';
    for (const e of document.querySelectorAll('.so-pj')) e.hidden = tipo !== 'J';
    $('rotulo-nome').textContent = tipo === 'F' ? 'Nome completo *' : 'Razão social *';
    $('rotulo-documento').textContent = tipo === 'F' ? 'CPF' : 'CNPJ';
  }
  for (const b of document.querySelectorAll('[data-tipo]')) {
    b.addEventListener('click', () => { if (podeEditar && b.dataset.tipo !== tipo) { aplicarTipo(b.dataset.tipo); sujo = true; } });
  }

  // ---------- Construtores de campos das listas ----------
  function campoTexto(valor, max, rotulo, aoMudar) {
    const i = Util.el('input');
    i.value = valor ?? '';
    i.maxLength = max;
    i.setAttribute('aria-label', rotulo);
    i.addEventListener('input', () => aoMudar(i.value));
    return i;
  }
  function campoLista(valor, opcoes, rotulo, aoMudar) {
    const s = Util.el('select');
    for (const [v, t] of opcoes) {
      const o = Util.el('option', null, t);
      o.value = v;
      s.append(o);
    }
    s.value = valor ?? '';
    s.setAttribute('aria-label', rotulo);
    s.addEventListener('change', () => aoMudar(s.value));
    return s;
  }
  function campoMarca(valor, rotulo, aoMudar) {
    const l = Util.el('label', 'marcacao');
    const c = Util.el('input');
    c.type = 'checkbox';
    c.checked = !!valor;
    c.addEventListener('change', () => aoMudar(c.checked));
    l.append(c, Util.el('span', 'so-leitor', rotulo));
    return l;
  }
  function botaoRemover(rotulo, aoRemover) {
    const b = Util.el('button', 'botao-icone editavel', '×');
    b.type = 'button';
    b.setAttribute('aria-label', rotulo);
    b.title = rotulo;
    b.addEventListener('click', () => { aoRemover(); sujo = true; });
    return b;
  }
  function celula(...filhos) { const td = Util.el('td'); td.append(...filhos); return td; }
  function linhaVazia(corpo, colunas, texto) {
    const tr = Util.el('tr');
    const td = Util.el('td', 'vazio', texto);
    td.colSpan = colunas;
    tr.append(td);
    corpo.append(tr);
  }

  // ---------- Contatos ----------
  const TIPOS_CONTATO = [['EMAIL', 'E-mail'], ['CELULAR', 'Celular'], ['WHATSAPP', 'WhatsApp'], ['TELEFONE', 'Telefone']];
  function desenharContatos() {
    const corpo = $('linhas-contatos');
    corpo.replaceChildren();
    if (!contatos.length) linhaVazia(corpo, 6, 'Nenhum contato cadastrado.');
    contatos.forEach((c, i) => {
      const tr = Util.el('tr');
      tr.append(
        celula(campoLista(c.tipo, TIPOS_CONTATO, 'Tipo do contato', (v) => { c.tipo = v; })),
        celula(campoTexto(c.valor, 256, 'Contato (e-mail ou número)', (v) => { c.valor = v; })),
        celula(campoTexto(c.nome, 80, 'Nome do contato', (v) => { c.nome = v; })),
        celula(campoMarca(c.principal, 'Principal', (v) => { c.principal = v; })),
        celula(campoMarca(c.recebeCobranca, 'Recebe cobrança', (v) => { c.recebeCobranca = v; })),
        celula(botaoRemover('Remover contato', () => { contatos.splice(i, 1); desenharContatos(); }))
      );
      corpo.append(tr);
    });
    contarAbas();
    aplicarEdicao();
  }
  $('incluir-contato').addEventListener('click', () => {
    contatos.push({ id: null, tipo: 'EMAIL', valor: '', nome: '', principal: contatos.length === 0, recebeCobranca: false });
    sujo = true;
    desenharContatos();
    $('linhas-contatos').lastElementChild?.querySelector('input')?.focus();
  });

  // ---------- Dados bancários ----------
  const TIPOS_PIX = [['DOCUMENTO', 'CPF/CNPJ'], ['EMAIL', 'E-mail'], ['CELULAR', 'Celular'], ['ALEATORIA', 'Chave aleatória']];
  const TIPOS_CONTA = [['CORRENTE', 'Corrente'], ['POUPANCA', 'Poupança'], ['PAGAMENTO', 'Pagamento']];
  function desenharBancarios() {
    const corpo = $('linhas-bancarios');
    corpo.replaceChildren();
    if (!bancarios.length) linhaVazia(corpo, 8, 'Nenhum dado bancário cadastrado.');
    bancarios.forEach((d, i) => {
      const tr = Util.el('tr');
      const forma = campoLista(d.tipo, [['TED', 'TED'], ['PIX', 'PIX']], 'Forma', (v) => { d.tipo = v; desenharBancarios(); });
      let c2, c3, c4, c5;
      if (d.tipo === 'PIX') {
        c2 = celula(campoLista(d.pixTipo || 'DOCUMENTO', TIPOS_PIX, 'Tipo da chave PIX', (v) => { d.pixTipo = v; }));
        c3 = celula(campoTexto(d.pixChave, 140, 'Chave PIX', (v) => { d.pixChave = v; }));
        c4 = celula(Util.el('span', 'suave', '—'));
        c5 = celula(Util.el('span', 'suave', '—'));
        if (!d.pixTipo) d.pixTipo = 'DOCUMENTO';
      } else {
        const opcoesBanco = [['', '(escolha)'], ...bancos.map((b) => [String(b.ID_BANCO), b.CODIGO + ' – ' + b.NOME])];
        c2 = celula(campoLista(d.idBanco ? String(d.idBanco) : '', opcoesBanco, 'Banco', (v) => { d.idBanco = v ? parseInt(v, 10) : null; }));
        const ag = campoTexto(d.agencia, 10, 'Agência', (v) => { d.agencia = v; });
        const agDv = campoTexto(d.agenciaDv, 2, 'Dígito da agência', (v) => { d.agenciaDv = v; });
        agDv.size = 2;
        const ct = campoTexto(d.conta, 20, 'Conta', (v) => { d.conta = v; });
        const ctDv = campoTexto(d.contaDv, 2, 'Dígito da conta', (v) => { d.contaDv = v; });
        ctDv.size = 2;
        const par = (a, b) => { const d = Util.el('div', 'par'); d.append(a, b); return d; };
        c3 = celula(par(ag, agDv));
        c4 = celula(par(ct, ctDv));
        c5 = celula(campoLista(d.tipoConta || 'CORRENTE', TIPOS_CONTA, 'Tipo de conta', (v) => { d.tipoConta = v; }));
        if (!d.tipoConta) d.tipoConta = 'CORRENTE';
      }
      const titular = Util.el('div');
      titular.append(
        campoTexto(d.titularNome, 150, 'Nome do titular, se for outro', (v) => { d.titularNome = v; }),
        campoTexto(d.titularDocumento, 20, 'CPF/CNPJ do titular, se for outro', (v) => { d.titularDocumento = v; })
      );
      titular.lastElementChild.placeholder = 'CPF/CNPJ';
      titular.firstElementChild.placeholder = 'Nome';
      tr.append(
        celula(forma), c2, c3, c4, c5, celula(titular),
        celula(campoMarca(d.principal, 'Principal', (v) => { d.principal = v; })),
        celula(botaoRemover('Remover dado bancário', () => { bancarios.splice(i, 1); desenharBancarios(); }))
      );
      corpo.append(tr);
    });
    contarAbas();
    aplicarEdicao();
  }
  $('incluir-bancario').addEventListener('click', () => {
    bancarios.push({ id: null, tipo: 'PIX', pixTipo: 'DOCUMENTO', pixChave: '', idBanco: null, agencia: '', agenciaDv: '', conta: '', contaDv: '',
      tipoConta: 'CORRENTE', titularNome: '', titularDocumento: '', principal: bancarios.length === 0 });
    sujo = true;
    desenharBancarios();
  });

  // ---------- Vínculos ----------
  const TIPOS_VINCULO = [['CONJUGE', 'Cônjuge'], ['SOCIO', 'Sócio'], ['REPRESENTANTE', 'Representante'], ['PROCURADOR', 'Procurador']];
  function desenharVinculos() {
    const corpo = $('linhas-vinculos');
    corpo.replaceChildren();
    if (!vinculos.length) linhaVazia(corpo, 4, 'Nenhum vínculo cadastrado.');
    vinculos.forEach((v, i) => {
      const tr = Util.el('tr');
      const pessoa = Util.el('td');
      const link = Util.el('a', null, v.nome || '(pessoa ' + v.idPessoaVinculada + ')');
      link.href = '/cad/pessoa.html?id=' + encodeURIComponent(v.idPessoaVinculada);
      pessoa.append(link);
      tr.append(
        celula(campoLista(v.tipo, TIPOS_VINCULO, 'Tipo do vínculo', (x) => { v.tipo = x; })),
        pessoa,
        celula(campoTexto(v.observacao, 200, 'Observação do vínculo', (x) => { v.observacao = x; })),
        celula(botaoRemover('Remover vínculo', () => { vinculos.splice(i, 1); desenharVinculos(); }))
      );
      corpo.append(tr);
    });
    contarAbas();
    aplicarEdicao();
  }
  $('incluir-vinculo').addEventListener('click', async () => {
    const escolhida = await escolherPessoa();
    if (!escolhida) return;
    if (escolhida.ID_PESSOA === idPessoa) { await Mensagens.alerta('A pessoa não pode ter vínculo com ela mesma.'); return; }
    vinculos.push({ idPessoaVinculada: escolhida.ID_PESSOA, nome: escolhida.NOME, tipo: 'CONJUGE', observacao: '' });
    sujo = true;
    desenharVinculos();
  });

  /** Janela de escolha de pessoa (busca por parte do nome). */
  function escolherPessoa() {
    return new Promise((resolver) => {
      const janela = Util.el('dialog', 'janela janela-larga');
      janela.setAttribute('aria-label', 'Escolher pessoa');
      const topo = Util.el('div', 'janela-topo');
      topo.append(Util.el('h2', null, 'Escolher pessoa'));
      const rotulo = Util.el('label', 'campo', 'Nome, parte do nome ou CPF/CNPJ');
      const campo = Util.el('input');
      campo.type = 'search';
      rotulo.append(campo);
      const lista = Util.el('div', 'rolagem');
      const tabela = Util.el('table', 'tabela');
      const corpo = Util.el('tbody');
      tabela.append(corpo);
      lista.append(tabela);
      const barra = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      barra.append(cancelar);
      janela.append(topo, rotulo, lista, barra);
      document.body.append(janela);

      const fechar = (valor) => { janela.close(); janela.remove(); resolver(valor); };
      cancelar.addEventListener('click', () => fechar(null));
      janela.addEventListener('cancel', (e) => { e.preventDefault(); fechar(null); });

      let pedido = 0;
      const buscar = Util.atrasar(async () => {
        const termo = campo.value.trim();
        corpo.replaceChildren();
        if (termo.length < 2) { linhaVazia(corpo, 3, 'Digite pelo menos 2 letras.'); return; }
        const meu = ++pedido;
        const r = await Api.get('/api/cad/pessoas', { busca: termo, situacao: 'ATIVOS' });
        if (meu !== pedido) return;
        if (!r.sucesso) { linhaVazia(corpo, 3, r.mensagem || 'Não foi possível buscar.'); return; }
        const achadas = (r.dados || []).filter((p) => p.ID_PESSOA !== idPessoa).slice(0, 50);
        if (!achadas.length) linhaVazia(corpo, 3, 'Nenhuma pessoa encontrada.');
        for (const p of achadas) {
          const tr = Util.el('tr', 'clicavel');
          tr.tabIndex = 0;
          tr.addEventListener('click', () => fechar(p));
          tr.addEventListener('keydown', (e) => { if (e.key === 'Enter') fechar(p); });
          tr.append(Util.el('td', 'forte', p.NOME), Util.el('td', 'numero', p.DOCUMENTO || ''), Util.el('td', null, [p.CIDADE, p.UF].filter(Boolean).join('/')));
          corpo.append(tr);
        }
      }, 300);
      campo.addEventListener('input', buscar);
      linhaVazia(corpo, 3, 'Digite pelo menos 2 letras.');
      janela.showModal();
      campo.focus();
    });
  }

  // ---------- Histórico ----------
  async function carregarHistorico() {
    const corpo = $('linhas-historico');
    corpo.replaceChildren();
    linhaVazia(corpo, 7, 'Carregando…');
    const r = await Api.get('/api/cad/pessoas/' + idPessoa + '/historico');
    corpo.replaceChildren();
    if (!r.sucesso) { await Mensagens.tratar(r); linhaVazia(corpo, 7, 'Histórico indisponível.'); return; }
    historicoCarregado = true;
    const linhas = r.dados || [];
    if (!linhas.length) linhaVazia(corpo, 7, 'Nenhuma alteração registrada.');
    for (const h of linhas) {
      const tr = Util.el('tr');
      tr.append(
        Util.el('td', 'numero', Util.dataHora(h.DT_OPERACAO)),
        Util.el('td', null, h.USUARIO || ''),
        Util.el('td', null, h.PARTE || ''),
        Util.el('td', null, h.OPERACAO_NOME || ''),
        Util.el('td', null, h.CAMPO || (h.OPERACAO === 'A' ? '' : '(registro)')),
        Util.el('td', 'suave', h.VALOR_ANTES || ''),
        Util.el('td', null, h.VALOR_DEPOIS || '')
      );
      corpo.append(tr);
    }
  }

  // ---------- Permissões ----------
  function aplicarEdicao() {
    if (podeEditar) return;
    for (const e of $('ficha').querySelectorAll('input, select, textarea')) e.disabled = true;
    for (const e of document.querySelectorAll('.editavel')) e.hidden = true;
  }

  function atualizarCabecalho(p) {
    $('titulo').textContent = p ? p.NOME : 'Nova pessoa';
    document.title = 'SistemaCMJ – ' + (p ? p.NOME : 'Nova pessoa');
    if (!p) { $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.'; return; }
    const papeis = [['CLIENTE', 'Cliente'], ['FORNECEDOR', 'Fornecedor'], ['FUNCIONARIO', 'Funcionário'], ['CORRETOR', 'Corretor']]
      .filter(([c]) => p[c]).map(([, t]) => t).join(', ');
    $('subtitulo').textContent = ['Código ' + String(p.ID_PESSOA).padStart(6, '0'), papeis, p.ATIVO ? 'Ativo' : 'Inativo'].filter(Boolean).join(' · ');
    const partes = [];
    if (p.DT_CRIACAO) partes.push('Criado em ' + Util.dataHora(p.DT_CRIACAO) + (p.USUARIO_CRIACAO ? ' por ' + p.USUARIO_CRIACAO : ''));
    if (p.DT_ALTERACAO) partes.push('Alterado em ' + Util.dataHora(p.DT_ALTERACAO) + (p.USUARIO_ALTERACAO ? ' por ' + p.USUARIO_ALTERACAO : ''));
    if (p.CODIGO_ACCESS) partes.push('Código no Access: ' + p.CODIGO_ACCESS);
    $('rodape').textContent = partes.join(' · ');
    const repetido = p.DOCUMENTO_REPETIDO || 0;
    $('aviso-documento').hidden = repetido === 0;
    $('aviso-documento').textContent = repetido === 1
      ? 'Atenção: existe outra pessoa cadastrada com este mesmo documento.'
      : 'Atenção: existem ' + repetido + ' outras pessoas cadastradas com este mesmo documento.';
  }

  // ---------- Carga ----------
  const rBancos = await Api.get('/api/banco/bancos');
  if (rBancos.sucesso) bancos = rBancos.dados || [];

  if (idPessoa) {
    const r = await Api.get('/api/cad/pessoas/' + idPessoa);
    if (!(await Mensagens.tratar(r))) { location.href = '/cad/pessoas.html'; return; }
    const p = r.dados;
    aplicarTipo(p.TIPO_PESSOA === 'J' ? 'J' : 'F');
    ativo = !!p.ATIVO;
    const colunas = {
      nome: 'NOME', nomeFantasia: 'NOME_FANTASIA', cpfCnpj: 'DOCUMENTO_FORMATADO', rg: 'RG', orgaoEmissor: 'ORGAO_EMISSOR',
      inscricaoEstadual: 'INSCRICAO_ESTADUAL', inscricaoMunicipal: 'INSCRICAO_MUNICIPAL', nacionalidade: 'NACIONALIDADE',
      profissao: 'PROFISSAO', estadoCivil: 'ESTADO_CIVIL', regimeBens: 'REGIME_BENS', cep: 'CEP', logradouro: 'LOGRADOURO',
      numero: 'NUMERO', complemento: 'COMPLEMENTO', bairro: 'BAIRRO', cidade: 'CIDADE', uf: 'UF', observacao: 'OBSERVACAO'
    };
    for (const [campo, coluna] of Object.entries(colunas)) $(campo).value = p[coluna] ?? '';
    $('dtNascimento').value = Util.dataIso(p.DT_NASCIMENTO);
    for (const papel of PAPEIS) $(papel).checked = !!p[papel.toUpperCase()];
    contatos = (p.CONTATOS || []).map((c) => ({ ...c, nome: c.nome ?? '' }));
    bancarios = (p.DADOS_BANCARIOS || []).map((d) => ({ ...d }));
    vinculos = (p.VINCULOS || []).map((v) => ({ ...v }));
    atualizarCabecalho(p);
    $('aba-historico').hidden = false;
    $('botao-excluir').hidden = !ativo || !acoes.has('EXCLUIR');
    $('botao-reativar').hidden = ativo || !acoes.has('EXCLUIR');
  } else {
    aplicarTipo('F');
    $('cliente').checked = true;
    $('nacionalidade').value = 'Brasileira';
    atualizarCabecalho(null);
  }

  $('botao-gravar').hidden = !podeEditar;
  desenharContatos();
  desenharBancarios();
  desenharVinculos();
  aplicarEdicao();
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  if (podeEditar) $('nome').focus();

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!podeEditar) return;
    if (!$('nome').value.trim()) {
      abrirAba($('aba-dados'));
      await Mensagens.alerta(tipo === 'F' ? 'Informe o nome completo.' : 'Informe a razão social.', 'ATENCAO', { foco: $('nome') });
      return;
    }
    if (!PAPEIS.some((p) => $(p).checked)) {
      abrirAba($('aba-dados'));
      await Mensagens.alerta('Marque pelo menos um papel (cliente, fornecedor, funcionário ou corretor).', 'ATENCAO', { foco: $('cliente') });
      return;
    }

    const nomeGravar = $('nome').value.trim();
    if (!(await Mensagens.confirmar('Gravar?', (idPessoa ? 'Confirma a gravação das alterações de ' : 'Confirma a inclusão de ') + nomeGravar + '?', 'Gravar'))) return;

    const corpo = { idPessoa, tipoPessoa: tipo };
    for (const c of CAMPOS) corpo[c] = $(c).value;
    for (const p of PAPEIS) corpo[p] = $(p).checked;
    if (tipo === 'F') { corpo.nomeFantasia = ''; corpo.inscricaoEstadual = ''; corpo.inscricaoMunicipal = ''; }
    else { corpo.rg = ''; corpo.orgaoEmissor = ''; corpo.dtNascimento = ''; corpo.estadoCivil = ''; corpo.regimeBens = ''; }
    corpo.contatos = contatos.map((c) => ({ id: c.id ?? null, tipo: c.tipo, valor: (c.valor || '').trim(), nome: (c.nome || '').trim(), principal: !!c.principal, recebeCobranca: !!c.recebeCobranca }));
    corpo.dadosBancarios = bancarios.map((d) => d.tipo === 'PIX'
      ? { id: d.id ?? null, tipo: 'PIX', pixTipo: d.pixTipo, pixChave: (d.pixChave || '').trim(), titularNome: d.titularNome || '', titularDocumento: d.titularDocumento || '', principal: !!d.principal }
      : { id: d.id ?? null, tipo: 'TED', idBanco: d.idBanco ?? null, agencia: d.agencia || '', agenciaDv: d.agenciaDv || '', conta: d.conta || '', contaDv: d.contaDv || '',
          tipoConta: d.tipoConta || 'CORRENTE', titularNome: d.titularNome || '', titularDocumento: d.titularDocumento || '', principal: !!d.principal });
    corpo.vinculos = vinculos.map((v) => ({ idPessoaVinculada: v.idPessoaVinculada, tipo: v.tipo, observacao: v.observacao || '' }));

    const botao = $('botao-gravar');
    botao.disabled = true;
    const r = await Api.post('/api/cad/pessoas', corpo);
    botao.disabled = false;
    if (!(await Mensagens.tratar(r))) return;

    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Pessoa gravada.');
    const novoId = r.dados && r.dados.id ? r.dados.id : idPessoa;
    location.replace('/cad/pessoa.html?id=' + encodeURIComponent(novoId));
  });

  // ---------- Excluir / reativar / cancelar ----------
  async function mudarSituacao(reativar) {
    const nome = $('nome').value.trim() || 'esta pessoa';
    const ok = reativar
      ? await Mensagens.confirmar('Reativar pessoa?', 'A pessoa ' + nome + ' volta a aparecer nas listas de escolha.', 'Reativar')
      : await Mensagens.confirmar('Excluir pessoa?', 'A pessoa ' + nome + ' será desativada: some das listas de escolha, mas continua nos lançamentos e no histórico.', 'Excluir');
    if (!ok) return;
    const r = await Api.post('/api/cad/pessoas/' + idPessoa + '/excluir', { reativar });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Situação alterada.');
    location.replace('/cad/pessoa.html?id=' + encodeURIComponent(idPessoa));
  }
  $('botao-excluir').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-cancelar').addEventListener('click', () => sair('/cad/pessoas.html'));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair('/cad/pessoas.html'); });
});
