/* =============================================================================
   SistemaCMJ - js/sis/parametros.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 26/11/2026 (etapa 04f2d)
   Descrição : Telas Sistema › Configuração › Parâmetros (SIS_PARAMETRO, só o
               administrador geral, todos os parâmetros) e Parâmetros de uso
               (?uso=1, SIS_PARAMETRO_USO, os dois administradores, só os de
               nível 1). Uma linha por parâmetro, agrupada por assunto:
               campo conforme o tipo (liga/desliga, lista de opções, número,
               data, cor), valor padrão, quem alterou e quando, Gravar e
               "Voltar ao padrão" por linha, Histórico do parâmetro.
               Antes de gravar: prévia (SIS_Parametro_Conferir) com o efeito
               nas pendências dos lançamentos em aberto (FIN_PEND_*) e o
               motivo, obrigatório quando a troca afrouxa uma proteção (regra
               de bloqueio que desce de nível, trava de datas desligada).
               Conferência de verdade no SIS_Parametro_Gravar.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const uso = Util.parametro('uso') === '1';
  const tela = uso ? 'sis/parametros.html?uso=1' : 'sis/parametros.html';
  document.body.dataset.tela = tela;
  document.body.dataset.menu = tela;
  const nomeTela = uso ? 'Parâmetros de uso' : 'Parâmetros';
  const item = uso ? 'SIS_PARAMETRO_USO' : 'SIS_PARAMETRO';
  document.title = 'SistemaCMJ – ' + nomeTela;

  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  $('titulo').textContent = nomeTela;
  $('caminho').textContent = 'Sistema › Configuração › ' + nomeTela;
  $('botao-exportar').hidden = !acoes.has('EXPORTAR');
  const podeAlterar = acoes.has('ALTERAR');
  const caixa = $('grupos');
  let todos = [];

  // ---------- assunto (grupo) de cada parâmetro ----------
  const ASSUNTOS = [
    [/^FIN_(REGRA_|VALOR_FORA_|DUPLIC_)/, 'Financeiro › Avisos ao lançar (proteção contra erro de digitação)'],
    [/^FIN_PEND_/, 'Financeiro › Pendências automáticas dos lançamentos'],
    [/^FIN_(TRAVA_|DATA_|EMISSAO_|VENCIMENTO_|BAIXA_|COMPETENCIA_|DIAS_TOLERANCIA)/, 'Financeiro › Trava de datas'],
    [/^FIN_LISTA_/, 'Financeiro › Lista de contas a pagar e a receber']
  ];
  const assunto = (p) => (ASSUNTOS.find(([re]) => re.test(p.CHAVE)) || [null, p.MODULO_NOME])[1];
  const ROTULO_OPCAO = { AVISO: 'Avisa (pede "Estou ciente")', BLOQUEIO: 'Bloqueia', NAO: 'Não confere', S: 'Sim', N: 'Não',
    P: 'Só contas a pagar', R: 'Só contas a receber', A: 'Pagar e receber', EM_ABERTO: 'Em aberto', VENCIDA: 'Vencidas', HOJE: 'Vencem hoje',
    A_VENCER: 'A vencer', TODAS: 'Todas', PARCELA: 'Por parcela', LANCAMENTO: 'Por lançamento' };
  const opcoes = (p) => (p.OPCOES || '').split(';').map((o) => o.trim()).filter(Boolean);

  // ---------- valor <-> tela ----------
  /** Valor como a tela mostra (decimal com vírgula). */
  const paraTela = (p, v) => (p.TIPO === 'DECIMAL' ? String(v ?? '').replace('.', ',') : (v ?? ''));
  /** Texto do valor para leitura (padrão, exportar). */
  function textoValor(p, v) {
    if (v === null || v === undefined || v === '') return '(vazio)';
    if (opcoes(p).length || p.TIPO === 'SN') return ROTULO_OPCAO[String(v).toUpperCase()] || v;
    if (p.TIPO === 'DATA') return Util.data(v);
    return paraTela(p, v);
  }

  function criarCampo(p) {
    const ops = opcoes(p);
    let c;
    if (ops.length || p.TIPO === 'SN') {
      c = Util.el('select');
      for (const o of (ops.length ? ops : ['S', 'N'])) {
        const op = Util.el('option', null, ROTULO_OPCAO[o] || o);
        op.value = o;
        c.append(op);
      }
      c.value = String(p.VALOR || '').toUpperCase();
    } else {
      c = Util.el('input');
      c.type = { INTEIRO: 'number', DATA: 'date', COR: 'color', EMAIL: 'email' }[p.TIPO] || 'text';
      if (p.TIPO === 'INTEIRO') c.step = '1';
      if (p.TIPO === 'DECIMAL') c.inputMode = 'decimal';
      c.value = paraTela(p, p.VALOR);
      if (p.TIPO === 'TEXTO' || p.TIPO === 'EMAIL' || p.TIPO === 'ARQUIVO') c.maxLength = 400;
    }
    c.setAttribute('aria-label', p.DESCRICAO || p.CHAVE);
    c.disabled = !podeAlterar || !p.EDITAVEL_ADMIN;
    return c;
  }

  // ---------- grade ----------
  const semAcento = (t) => (t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  function filtrados() {
    const termo = semAcento($('busca').value.trim());
    const so = $('so-alterados').checked;
    return todos.filter((p) => (!termo || semAcento(p.DESCRICAO).includes(termo) || semAcento(p.CHAVE).includes(termo) || semAcento(assunto(p)).includes(termo))
      && (!so || String(p.VALOR) !== String(p.VALOR_PADRAO)));
  }

  function desenhar() {
    const lista = filtrados();
    caixa.replaceChildren();
    $('contagem').textContent = lista.length === 1 ? '1 parâmetro' : lista.length + ' parâmetros';
    if (!lista.length) { caixa.append(Util.el('p', 'vazio', 'Nenhum parâmetro com esses filtros.')); return; }
    const grupos = new Map();
    for (const p of lista) {
      const g = assunto(p);
      if (!grupos.has(g)) grupos.set(g, []);
      grupos.get(g).push(p);
    }
    for (const [nome, itens] of grupos) {
      const secao = Util.el('section', 'grupo-parametros');
      secao.append(Util.el('h2', 'grupo-parametros-titulo', nome));
      const rolagem = Util.el('div', 'rolagem');
      const tabela = Util.el('table', 'tabela tabela-parametros');
      const cab = Util.el('tr');
      for (const t of ['Parâmetro', 'Valor', 'Padrão de fábrica', 'Última alteração', '']) cab.append(Util.el('th', null, t));
      const thead = Util.el('thead');
      thead.append(cab);
      const tbody = Util.el('tbody');
      for (const p of itens) tbody.append(linha(p));
      tabela.append(thead, tbody);
      rolagem.append(tabela);
      secao.append(rolagem);
      caixa.append(secao);
    }
  }

  function linha(p) {
    const tr = Util.el('tr');
    const tdNome = Util.el('td', 'parametro-nome');
    tdNome.append(Util.el('span', 'forte', p.DESCRICAO || p.CHAVE), Util.el('span', 'sub', p.CHAVE));
    if (!p.EDITAVEL_ADMIN) tdNome.append(Util.el('span', 'sub', 'Só muda na instalação do sistema.'));

    const campo = criarCampo(p);
    const tdValor = Util.el('td');
    tdValor.append(campo);
    const diferente = String(p.VALOR) !== String(p.VALOR_PADRAO);
    if (diferente) tr.classList.add('parametro-alterado');

    const tdPadrao = Util.el('td', null, textoValor(p, p.VALOR_PADRAO));
    const tdAlt = Util.el('td', 'suave', p.DT_ALTERACAO ? Util.dataHora(p.DT_ALTERACAO) + (p.USUARIO_ALTERACAO ? ' por ' + p.USUARIO_ALTERACAO : '') : '—');

    const tdAcoes = Util.el('td', 'acoes-linha');
    const gravar = Util.el('button', 'botao botao-principal', 'Gravar');
    gravar.type = 'button';
    gravar.disabled = true;
    gravar.dataset.dica = 'Grava o valor novo deste parâmetro (mostra antes o efeito e, se afrouxar uma proteção, pede o motivo).';
    const padrao = Util.el('button', 'botao', 'Voltar ao padrão');
    padrao.type = 'button';
    padrao.dataset.dica = 'Volta este parâmetro para o valor de fábrica (' + textoValor(p, p.VALOR_PADRAO) + ').';
    padrao.hidden = !diferente || campo.disabled;
    const hist = Util.el('button', 'botao', 'Histórico');
    hist.type = 'button';
    hist.dataset.dica = 'Quem mudou este parâmetro, quando, de quanto para quanto e o motivo.';
    if (!campo.disabled) tdAcoes.append(gravar, padrao);
    tdAcoes.append(hist);

    const lerValor = () => (p.TIPO === 'DECIMAL' ? campo.value.trim().replace(',', '.') : campo.value.trim());
    const marcar = () => { gravar.disabled = String(lerValor()).toUpperCase() === String(p.VALOR ?? '').toUpperCase(); };
    campo.addEventListener('input', marcar);
    campo.addEventListener('change', marcar);
    gravar.addEventListener('click', () => salvar(p, lerValor(), gravar));
    padrao.addEventListener('click', () => salvar(p, p.VALOR_PADRAO, padrao, true));
    hist.addEventListener('click', () => verHistorico(p));

    tr.append(tdNome, tdValor, tdPadrao, tdAlt, tdAcoes);
    return tr;
  }

  // ---------- gravar (prévia + motivo) ----------
  async function salvar(p, valor, botao, voltarPadrao) {
    botao.disabled = true;
    try {
      const rc = await Api.post('/api/sis/parametros/conferir', { chave: p.CHAVE, valor });
      if (!(await Mensagens.tratar(rc))) return;
      const c = rc.dados || {};
      const de = textoValor(p, p.VALOR);
      const para = textoValor(p, valor);
      let texto = (p.DESCRICAO || p.CHAVE) + ': de "' + de + '" para "' + para + '".';
      if (c.EFEITO) texto += '\n\n' + c.EFEITO;
      let motivo = '';
      if (c.PEDE_MOTIVO) {
        motivo = await Mensagens.pedirTexto(voltarPadrao ? 'Voltar ao padrão?' : 'Gravar parâmetro?',
          texto + '\n\nEsta alteração afrouxa uma proteção do sistema: informe o motivo. Ele fica no histórico.',
          { rotulo: 'Motivo', botao: 'Gravar', obrigatorio: true, tipo: 'textarea', dica: 'Por que a proteção está sendo afrouxada. Obrigatório. Aparece no histórico do parâmetro.' });
        if (motivo === null) return;
      } else if (!(await Mensagens.confirmar(voltarPadrao ? 'Voltar ao padrão?' : 'Gravar parâmetro?', texto + '\n\nVale na hora para todos os usuários.', 'Gravar'))) {
        return;
      }
      const r = await Api.post('/api/sis/parametros/gravar', { chave: p.CHAVE, valor, motivo });
      if (!(await Mensagens.tratar(r))) return;
      Mensagens.sucesso(r.mensagem || 'Parâmetro gravado.');
      await carregar();
    } finally {
      botao.disabled = false;
    }
  }

  // ---------- histórico do parâmetro ----------
  function verHistorico(p) {
    const janela = Util.el('dialog', 'janela janela-larga');
    janela.setAttribute('aria-label', 'Histórico do parâmetro');
    const topo = Util.el('div', 'janela-topo');
    topo.append(Util.el('h2', null, 'Histórico: ' + (p.DESCRICAO || p.CHAVE)));
    const corpo = Util.el('div', 'rolagem');
    const barra = Util.el('div', 'janela-botoes');
    const fechar = Util.el('button', 'botao', 'Fechar');
    fechar.type = 'button';
    barra.append(fechar);
    janela.append(topo, corpo, barra);
    document.body.append(janela);
    const sair = () => { janela.close(); janela.remove(); };
    fechar.addEventListener('click', sair);
    janela.addEventListener('cancel', (e) => { e.preventDefault(); sair(); });
    janela.showModal();
    Historico.criar(corpo, { item, tabela: 'SIS.Parametro', id: p.ID_PARAMETRO, nomeRegistro: 'Parâmetro', podeDesfazer: false }).carregar();
  }

  // ---------- exportar ----------
  $('botao-exportar').addEventListener('click', () => {
    const lista = filtrados();
    Util.exportarCsv(uso ? 'Parametros_de_uso' : 'Parametros', ['Assunto', 'Parâmetro', 'Chave', 'Valor', 'Padrão de fábrica', 'Alterado em', 'Alterado por'],
      lista.map((p) => [assunto(p), p.DESCRICAO, p.CHAVE, textoValor(p, p.VALOR), textoValor(p, p.VALOR_PADRAO),
        p.DT_ALTERACAO ? Util.dataHora(p.DT_ALTERACAO) : '', p.USUARIO_ALTERACAO || '']));
  });

  // ---------- carga ----------
  async function carregar() {
    const r = await Api.get('/api/sis/parametros', uso ? { uso: 'true' } : {});
    if (!(await Mensagens.tratar(r))) return;
    todos = r.dados || [];
    desenhar();
  }
  $('filtros').addEventListener('submit', (e) => e.preventDefault());
  $('busca').addEventListener('input', Util.atrasar(desenhar, 250));
  $('so-alterados').addEventListener('change', desenhar);
  await carregar();
  $('busca').focus();
});
