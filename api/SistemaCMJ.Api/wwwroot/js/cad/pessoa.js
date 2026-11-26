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
               04e (25/11/2026): conta do plano e centro de custo padrão pela
               escolha com busca (js/seletor.js).
               04f2d (26/11/2026): aba Movimentação (js/fin/movimentacao.js),
               só para quem vê contas a pagar ou a receber.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao, acoes } = await Layout.iniciar();
  // 04d2 (25/11/2026): rótulo pelo parâmetro PARCEIRO_ROTULO; tipos de parceiro (vários) no lugar dos papéis.
  const ROTULO = (sessao && sessao.parceiroRotulo) || 'Parceiro';
  const NOVO = 'Novo ' + ROTULO.toLowerCase();
  const $ = (id) => document.getElementById(id);

  const idPessoa = parseInt(Util.parametro('id') || '0', 10) || null;
  const CAMPOS = ['nome', 'nomeFantasia', 'cpfCnpj', 'rg', 'orgaoEmissor', 'inscricaoEstadual', 'inscricaoMunicipal',
    'dtNascimento', 'nacionalidade', 'profissao', 'estadoCivil', 'regimeBens', 'cep', 'logradouro', 'numero',
    'complemento', 'bairro', 'cidade', 'uf', 'observacao'];
  let tiposMarcados = new Set();

  /** Desenha uma marcação por tipo ativo (N/A é automático e não aparece) + os inativos que o parceiro já tem. */
  async function desenharTipos(tiposDoParceiro) {
    const r = await Api.get('/api/cad/parceiro-tipos', { somenteAtivos: true });
    const lista = (r.sucesso ? r.dados || [] : []).map((t) => ({ id: t.ID_PARCEIRO_TIPO, codigo: t.CODIGO, descricao: t.DESCRICAO }));
    for (const t of tiposDoParceiro) if (!lista.some((x) => x.id === t.id)) lista.push({ ...t, descricao: t.descricao + ' (inativo)' });
    const caixa = $('papeis');
    for (const t of lista.filter((x) => x.codigo !== 'NA')) {
      const label = Util.el('label', 'marcacao');
      const marca = Util.el('input');
      marca.type = 'checkbox';
      marca.dataset.idTipo = t.id;
      marca.id = 'tipo-' + t.codigo.toLowerCase();
      marca.checked = tiposMarcados.has(t.id);
      marca.addEventListener('change', () => { if (marca.checked) tiposMarcados.add(t.id); else tiposMarcados.delete(t.id); });
      label.append(marca, document.createTextNode(' ' + t.descricao));
      caixa.append(label);
    }
  }

  let tipo = 'F';
  let ativo = true;
  let contatos = [];
  let bancarios = [];
  let vinculos = [];
  let bancos = [];
  let sujo = false;
  let historicoCarregado = false;
  let anexosCarregados = false;
  let movimentacaoCarregada = false;
  let naLixeira = false;
  let podeEditar = idPessoa ? acoes.has('ALTERAR') : acoes.has('INCLUIR');

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
    if (aba.id === 'aba-anexos' && !anexosCarregados) carregarAnexos();
    if (aba.id === 'aba-movimentacao' && !movimentacaoCarregada) carregarMovimentacao();
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

  // ---------- Dicas dos campos das listas (PADRAO_TELAS seção 4) ----------
  const DICAS = {
    'Tipo do contato': 'Obrigatório. E-mail, celular, WhatsApp ou telefone.',
    'Contato (e-mail ou número)': 'Obrigatório. O e-mail ou o número com DDD (só números).',
    'Nome do contato': 'Opcional: com quem falar nesse contato (ex.: secretária).',
    'Principal': 'Marque o principal de cada tipo: é o que aparece nas listas e nos documentos.',
    'Recebe cobrança': 'Marque o e-mail que recebe boletos e avisos de cobrança.',
    'Finalidade do contato': 'Opcional: para que serve o contato (cobrança, compras ou financeiro). Cobrança já marca "Recebe cobrança".',
    'Forma': 'TED (banco, agência e conta) ou PIX (chave).',
    'Tipo da chave PIX': 'Obrigatório no PIX: CPF/CNPJ, e-mail, celular ou chave aleatória.',
    'Chave PIX': 'Obrigatório no PIX: a chave, do jeito que o banco informou.',
    'Banco': 'Obrigatório na TED: banco da conta (código e nome).',
    'Agência': 'Obrigatório na TED: número da agência, sem o dígito.',
    'Dígito da agência': 'Dígito da agência, se houver.',
    'Conta': 'Obrigatório na TED: número da conta, sem o dígito.',
    'Dígito da conta': 'Dígito da conta.',
    'Tipo de conta': 'Corrente, poupança ou conta de pagamento.',
    'Nome do titular, se for outro': 'Preencha só se a conta for de outra pessoa.',
    'CPF/CNPJ do titular, se for outro': 'Preencha só se a conta for de outra pessoa.',
    'Tipo do vínculo': 'Cônjuge, sócio, representante ou procurador.',
    'Observação do vínculo': 'Anotação livre (ex.: coobrigado nos contratos).',
    'Remover contato': 'Tira o contato da ficha ao gravar (fica no histórico).',
    'Remover dado bancário': 'Tira a conta ou chave da ficha ao gravar (fica no histórico).',
    'Remover vínculo': 'Tira o vínculo da ficha ao gravar (fica no histórico).'
  };
  const comDica = (el, rotulo) => { if (DICAS[rotulo]) el.dataset.dica = DICAS[rotulo]; return el; };

  // ---------- Construtores de campos das listas ----------
  function campoTexto(valor, max, rotulo, aoMudar) {
    const i = Util.el('input');
    i.value = valor ?? '';
    i.maxLength = max;
    i.setAttribute('aria-label', rotulo);
    i.addEventListener('input', () => aoMudar(i.value));
    return comDica(i, rotulo);
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
    return comDica(s, rotulo);
  }
  function campoMarca(valor, rotulo, aoMudar) {
    const l = Util.el('label', 'marcacao');
    const c = Util.el('input');
    c.type = 'checkbox';
    c.checked = !!valor;
    c.addEventListener('change', () => aoMudar(c.checked));
    l.append(c, Util.el('span', 'so-leitor', rotulo));
    return comDica(l, rotulo);
  }
  function botaoRemover(rotulo, aoRemover) {
    const b = Util.el('button', 'botao-icone editavel', '×');
    b.type = 'button';
    b.setAttribute('aria-label', rotulo);
    b.addEventListener('click', () => { aoRemover(); sujo = true; });
    return comDica(b, rotulo);
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
  const FINALIDADES_CONTATO = [['', '—'], ['COBRANCA', 'Cobrança'], ['COMPRAS', 'Compras'], ['FINANCEIRO', 'Financeiro']];
  function desenharContatos() {
    const corpo = $('linhas-contatos');
    corpo.replaceChildren();
    if (!contatos.length) linhaVazia(corpo, 7, 'Nenhum contato cadastrado.');
    contatos.forEach((c, i) => {
      const tr = Util.el('tr');
      const marcaCobranca = campoMarca(c.recebeCobranca, 'Recebe cobrança', (v) => { c.recebeCobranca = v; });
      tr.append(
        celula(campoLista(c.tipo, TIPOS_CONTATO, 'Tipo do contato', (v) => { c.tipo = v; })),
        celula(campoTexto(c.valor, 256, 'Contato (e-mail ou número)', (v) => { c.valor = v; })),
        celula(campoTexto(c.nome, 80, 'Nome do contato', (v) => { c.nome = v; })),
        celula(campoLista(c.finalidade, FINALIDADES_CONTATO, 'Finalidade do contato', (v) => {
          c.finalidade = v;
          // Finalidade Cobrança já marca "Recebe cobrança" (decisão do Celso, 25/11/2026, 04d2 passo 3c)
          if (v === 'COBRANCA' && !c.recebeCobranca) {
            c.recebeCobranca = true;
            marcaCobranca.querySelector('input').checked = true;
          }
        })),
        celula(campoMarca(c.principal, 'Principal', (v) => { c.principal = v; })),
        celula(marcaCobranca),
        celula(botaoRemover('Remover contato', () => { contatos.splice(i, 1); desenharContatos(); }))
      );
      corpo.append(tr);
    });
    contarAbas();
    aplicarEdicao();
  }
  $('incluir-contato').addEventListener('click', () => {
    contatos.push({ id: null, tipo: 'EMAIL', valor: '', nome: '', finalidade: '', principal: contatos.length === 0, recebeCobranca: false });
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

  // ---------- Anexos (componente js/anexos.js; 04d2 passo 5) ----------
  let anexos = null;
  async function carregarAnexos() {
    if (!anexos) anexos = Anexos.criar($('anexos'), {
      item: 'CAD_PESSOA', tabela: 'CAD.Pessoa', id: idPessoa,
      podeAnexar: acoes.has('ALTERAR') && !naLixeira,
      aoMudar: (qtd) => { $('aba-anexos').textContent = 'Anexos' + (qtd ? ' (' + qtd + ')' : ''); }
    });
    if (await anexos.carregar()) anexosCarregados = true;
  }

  // ---------- Movimentação (04f2d; componente js/fin/movimentacao.js) ----------
  let movimentacao = null;
  async function carregarMovimentacao() {
    if (!movimentacao) movimentacao = Movimentacao.criar($('movimentacao'), {
      idPessoa,
      aoContar: (qtd) => { $('aba-movimentacao').textContent = 'Movimentação' + (qtd ? ' (' + qtd + ' em aberto)' : ''); }
    });
    if (await movimentacao.carregar()) movimentacaoCarregada = true;
  }

  // ---------- Histórico ----------
  let historico = null;
  async function carregarHistorico() {
    if (!historico) historico = Historico.criar($('historico'), {
      item: 'CAD_PESSOA', tabela: 'CAD.Pessoa', id: idPessoa, nomeRegistro: 'Pessoa', podeDesfazer: acoes.has('DESFAZER'),
      aoDesfazer: () => { sujo = false; Util.recarregar('/cad/pessoa.html?id=' + encodeURIComponent(idPessoa) + '#historico'); }
    });
    if (await historico.carregar()) historicoCarregado = true;
  }

  // ---------- Permissões ----------
  function aplicarEdicao() {
    if (podeEditar) return;
    for (const e of $('ficha').querySelectorAll('input, select, textarea')) e.disabled = true;
    for (const e of document.querySelectorAll('.editavel')) e.hidden = true;
  }

  function atualizarCabecalho(p) {
    $('titulo').textContent = p ? p.NOME : NOVO;
    document.title = 'SistemaCMJ – ' + (p ? p.NOME : NOVO);
    if (!p) { $('subtitulo').textContent = 'Preencha os dados e clique em Gravar.'; return; }
    const papeis = (p.TIPOS || []).map((t) => t.descricao).join(', ');
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
      : 'Atenção: existem ' + repetido + ' outros parceiros cadastrados com este mesmo documento.';
  }

  // ---------- Conta do plano e centro de custo padrão (04e; escolha com busca) ----------
  const seletorPlano = Seletor.criar($('seletor-plano'), { tipo: 'PLANO', rotulo: 'Conta do plano padrão', placeholder: '(nenhuma)', aoMudar: () => { sujo = true; } });
  const seletorCentro = Seletor.criar($('seletor-centro'), { tipo: 'CENTRO', rotulo: 'Centro de custo padrão', placeholder: '(nenhum)', aoMudar: () => { sujo = true; } });

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
    tiposMarcados = new Set((p.TIPOS || []).filter((t) => t.codigo !== 'NA').map((t) => t.id));
    await desenharTipos(p.TIPOS || []);
    await Promise.all([seletorPlano.definir(p.ID_PLANO_CONTA_PADRAO), seletorCentro.definir(p.ID_CENTRO_CUSTO_PADRAO)]);
    contatos = (p.CONTATOS || []).map((c) => ({ ...c, nome: c.nome ?? '', finalidade: c.finalidade ?? '' }));
    bancarios = (p.DADOS_BANCARIOS || []).map((d) => ({ ...d }));
    vinculos = (p.VINCULOS || []).map((v) => ({ ...v }));
    atualizarCabecalho(p);
    $('aba-historico').hidden = false;
    $('aba-anexos').hidden = false;
    $('aba-movimentacao').hidden = Movimentacao.tiposVisiveis().length === 0;
    naLixeira = !!p.NA_LIXEIRA;
    if (naLixeira) {
      const aviso = $('aviso-lixeira');
      aviso.replaceChildren(document.createTextNode('Este registro está na lixeira: a ficha abre só para consulta. Para usar de novo, recupere na '));
      const link = Util.el('a', null, 'Lixeira');
      link.href = '/sis/lixeira.html?item=CAD_PESSOA';
      aviso.append(link, document.createTextNode('.'));
      aviso.hidden = false;
    }
    $('botao-excluir').hidden = naLixeira || !acoes.has('EXCLUIR');
    $('botao-desativar').hidden = naLixeira || !ativo || !acoes.has('DESATIVAR');
    $('botao-reativar').hidden = naLixeira || ativo || !acoes.has('DESATIVAR');
  } else {
    aplicarTipo('F');
    await desenharTipos([]);
    const cliente = $('tipo-cliente');
    if (cliente) { cliente.checked = true; tiposMarcados.add(parseInt(cliente.dataset.idTipo, 10)); }
    $('nacionalidade').value = 'Brasileira';
    atualizarCabecalho(null);
  }

  if (naLixeira) podeEditar = false;
  $('botao-gravar').hidden = !podeEditar;
  desenharContatos();
  desenharBancarios();
  desenharVinculos();
  aplicarEdicao();
  if (!podeEditar) { seletorPlano.habilitar(false); seletorCentro.habilitar(false); }
  $('ficha').addEventListener('input', () => { sujo = true; });
  $('ficha').addEventListener('change', () => { sujo = true; });
  if (podeEditar) $('nome').focus();

  // ---------- Consulta de CEP e CNPJ (04d2; a API consulta pelo servidor e guarda em cache) ----------
  const soDigitos = (t) => (t || '').replace(/\D/g, '');
  /** Preenche os campos: vazios sempre; já preenchidos e diferentes só se confirmar (uma pergunta só). */
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
    if (e.complemento && !$('complemento').value.trim()) $('complemento').value = e.complemento;
    Mensagens.sucesso('Endereço preenchido pelo CEP. Confira e informe o número.');
    $('numero').focus();
  });

  let ultimoCnpj = tipo === 'J' ? soDigitos($('cpfCnpj').value) : '';
  $('cpfCnpj').addEventListener('change', async () => {
    const cnpj = soDigitos($('cpfCnpj').value);
    if (!podeEditar || tipo !== 'J' || cnpj.length !== 14 || cnpj === ultimoCnpj) return;
    ultimoCnpj = cnpj;
    const r = await Api.get('/api/cad/consulta/cnpj/' + cnpj);
    if (!(await Mensagens.tratar(r, { foco: $('nome') }))) return;
    const d = r.dados || {};
    if (d.situacao && !d.situacaoAtiva)
      await Mensagens.alerta('Atenção: na Receita Federal este CNPJ está com a situação "' + d.situacao + '" (não está ATIVA). Confira antes de cadastrar.', 'ATENCAO');
    await preencher({ nome: d.razaoSocial, nomeFantasia: d.nomeFantasia, cep: d.cep, logradouro: d.logradouro, numero: d.numero,
      complemento: d.complemento, bairro: d.bairro, cidade: d.cidade, uf: d.uf }, 'Dados da Receita Federal');
    ultimoCep = soDigitos($('cep').value);
    const extras = [d.email && 'e-mail ' + d.email, d.telefone && 'telefone ' + d.telefone].filter(Boolean).join(' e ');
    Mensagens.sucesso('Dados preenchidos pela Receita Federal. Confira as abas Dados principais e Endereço.'
      + (extras ? ' Na Receita consta ' + extras + ': inclua na aba Contatos se for o caso.' : ''));
  });

  // ---------- Gravar ----------
  $('ficha').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!podeEditar) return;
    if (!$('nome').value.trim()) {
      abrirAba($('aba-dados'));
      await Mensagens.alerta(tipo === 'F' ? 'Informe o nome completo.' : 'Informe a razão social.', 'ATENCAO', { foco: $('nome') });
      return;
    }

    const nomeGravar = $('nome').value.trim();
    if (!(await Mensagens.confirmar('Gravar?', (idPessoa ? 'Confirma a gravação das alterações de ' : 'Confirma a inclusão de ') + nomeGravar + '?', 'Gravar'))) return;

    const corpo = { idPessoa, tipoPessoa: tipo };
    for (const c of CAMPOS) corpo[c] = $(c).value;
    corpo.tipos = [...tiposMarcados];
    // conta/centro padrão: 0 = limpa (só na alteração); na inclusão, vazio = nenhum
    corpo.idPlanoContaPadrao = seletorPlano.valor() ?? (idPessoa ? 0 : null);
    corpo.idCentroCustoPadrao = seletorCentro.valor() ?? (idPessoa ? 0 : null);
    if (tipo === 'F') { corpo.nomeFantasia = ''; corpo.inscricaoEstadual = ''; corpo.inscricaoMunicipal = ''; }
    else { corpo.rg = ''; corpo.orgaoEmissor = ''; corpo.dtNascimento = ''; corpo.estadoCivil = ''; corpo.regimeBens = ''; }
    corpo.contatos = contatos.map((c) => ({ id: c.id ?? null, tipo: c.tipo, valor: (c.valor || '').trim(), nome: (c.nome || '').trim(), finalidade: c.finalidade || '', principal: !!c.principal, recebeCobranca: !!c.recebeCobranca }));
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
    await Mensagens.concluido(r.mensagem || ROTULO + ' gravado.');
    const novoId = r.dados && r.dados.id ? r.dados.id : idPessoa;
    location.replace('/cad/pessoa.html?id=' + encodeURIComponent(novoId));
  });

  // ---------- Desativar / reativar / excluir (lixeira) / cancelar ----------
  async function mudarSituacao(reativar) {
    const nome = $('nome').value.trim() || 'esta pessoa';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Esta ação não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const ok = reativar
      ? await Mensagens.confirmar('Reativar ' + ROTULO.toLowerCase() + '?', nome + ' volta a aparecer nas listas de escolha.', 'Reativar')
      : await Mensagens.confirmar('Desativar ' + ROTULO.toLowerCase() + '?', nome + ' será desativada: some das listas de escolha, mas continua nos lançamentos e no histórico. Dá para reativar quando quiser.', 'Desativar');
    if (!ok) return;
    const r = await Api.post('/api/cad/pessoas/' + idPessoa + '/excluir', { reativar });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Situação alterada.');
    location.replace('/cad/pessoa.html?id=' + encodeURIComponent(idPessoa));
  }
  $('botao-desativar').addEventListener('click', () => mudarSituacao(false));
  $('botao-reativar').addEventListener('click', () => mudarSituacao(true));

  $('botao-excluir').addEventListener('click', async () => {
    const nome = $('nome').value.trim() || 'esta pessoa';
    if (sujo && !(await Mensagens.confirmar('Há alterações não gravadas', 'Excluir não grava as outras alterações da ficha, que serão perdidas. Continuar?', 'Continuar'))) return;
    const motivo = await Mensagens.pedirTexto('Excluir ' + ROTULO.toLowerCase() + '?',
      nome + ' vai para a lixeira: some de todas as telas e pode ser recuperada na Lixeira até o prazo acabar; depois é apagada de vez. '
      + 'Só dá para excluir quem não é usado em nenhum lugar (senão, use Desativar). Enquanto estiver na lixeira, o CPF/CNPJ continua ocupado.',
      { rotulo: 'Motivo (opcional)', botao: 'Excluir', tipo: 'textarea', dica: 'Por que está excluindo. Opcional. Aparece na Lixeira e no histórico.' });
    if (motivo === null) return;
    const r = await Api.post('/api/sis/lixeira/excluir', { item: 'CAD_PESSOA', tabela: 'CAD.Pessoa', idRegistro: idPessoa, motivo });
    if (!(await Mensagens.tratar(r))) return;
    sujo = false;
    await Mensagens.concluido(r.mensagem || 'Pessoa enviada para a lixeira.');
    location.replace('/cad/pessoas.html');
  });
  if (idPessoa && location.hash === '#historico') abrirAba($('aba-historico'));
  if (idPessoa && location.hash === '#anexos') abrirAba($('aba-anexos'));
  if (idPessoa && location.hash === '#movimentacao' && !$('aba-movimentacao').hidden) abrirAba($('aba-movimentacao'));

  async function sair(destino) {
    if (sujo && podeEditar && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = destino;
  }
  $('botao-cancelar').addEventListener('click', () => sair('/cad/pessoas.html'));
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair('/cad/pessoas.html'); });
});
