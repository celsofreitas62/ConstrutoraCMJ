/* =============================================================================
   SistemaCMJ - js/sis/backups.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 20/11/2026 (etapa 03d2)
   Descrição : Tela "Backups e restauração" (SIS_BACKUP). Topo: até onde dá
               para voltar e os últimos backups. Abas: lista dos backups;
               Restaurar (só com a ação RESTAURAR): lista dos pontos de
               restauração, do mais recente para o mais antigo (só os que dá
               para restaurar: mesma versão, arquivos guardados; pedido do
               Celso, 20/11/2026), motivo, a palavra RESTAURAR e a senha; pedidos de
               restauração com o resultado (cancelar enquanto aguarda).
               A tela só registra o pedido: quem restaura é a tarefa do
               servidor. Com pedido em aberto, a tela se atualiza sozinha.
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { acoes } = await Layout.iniciar();
  const $ = (id) => document.getElementById(id);
  const podeRestaurar = acoes.has('RESTAURAR');
  const CLASSE_SIT = { OK: 'situacao-ativo', ERRO: 'situacao-revisar', PENDENTE: 'situacao-pendente', EXECUTANDO: 'situacao-pendente', CANCELADO: 'situacao-inativo' };
  let dados = null;
  let relogio = null;
  let ponto = null;   // linha escolhida na aba Restaurar

  $('aba-restaurar').hidden = !podeRestaurar;

  // Abas
  const abas = [...document.querySelectorAll('.aba')];
  function ativarAba(aba) {
    for (const a of abas) {
      const ativa = a === aba;
      a.setAttribute('aria-selected', ativa ? 'true' : 'false');
      $(a.getAttribute('aria-controls')).hidden = !ativa;
    }
  }
  abas.forEach((a) => a.addEventListener('click', () => ativarAba(a)));

  const pilula = (texto, sit) => Util.el('span', 'situacao ' + (CLASSE_SIT[sit] || 'situacao-inativo'), texto);
  const paraCampo = (valor) => (valor ? String(valor).substring(0, 16) : '');   // "2026-11-20T14:30:02" -> "2026-11-20T14:30"

  // ---- Topo --------------------------------------------------------------------
  function desenharSituacao(s) {
    const porVersao = s.DT_LIMITE_VERSAO && s.DT_PODE_VOLTAR_DE && paraCampo(s.DT_LIMITE_VERSAO) === paraCampo(s.DT_PODE_VOLTAR_DE);
    $('sit-de').textContent = s.DT_PODE_VOLTAR_DE
      ? Util.dataHora(s.DT_PODE_VOLTAR_DE) + (porVersao ? ' (atualização para a versão ' + s.VERSAO + ')' : '')
      : 'sem backup completo';
    $('sit-de').title = 'Não dá para voltar para antes da atualização do sistema para a versão atual: o banco ficaria numa versão diferente do programa.';
    $('sit-ate').textContent = s.DT_PODE_VOLTAR_ATE ? Util.dataHora(s.DT_PODE_VOLTAR_ATE) : '';
    $('sit-completo').textContent = Util.dataHora(s.DT_ULTIMO_COMPLETO) || 'nenhum';
    $('sit-log').textContent = Util.dataHora(s.DT_ULTIMO_LOG) || 'nenhum';
    $('sit-teste').textContent = Util.dataHora(s.DT_ULTIMO_TESTE) || 'nenhum';
    $('sit-erros').textContent = String(s.QTD_ERROS_7_DIAS || 0);
    $('sit-erros').className = s.QTD_ERROS_7_DIAS > 0 ? 'forte' : '';
    $('subtitulo').textContent = 'Banco ' + (s.BANCO || '') + ' · atualizado às ' + Util.dataHora(s.DT_AGORA).slice(-5);

    const aviso = $('aviso');
    aviso.classList.remove('faixa-ok');
    if (s.ID_RESTAURACAO_ABERTA > 0) {
      aviso.hidden = false;
      aviso.textContent = s.SITUACAO_ABERTA === 'EXECUTANDO'
        ? 'Restauração nº ' + s.ID_RESTAURACAO_ABERTA + ' em andamento: o sistema pode sair do ar a qualquer momento. Depois, entre de novo.'
        : 'Pedido de restauração nº ' + s.ID_RESTAURACAO_ABERTA + ' aguardando o servidor (começa em até 1 minuto). Ainda dá para cancelar na aba "Pedidos de restauração".';
    } else {
      aviso.hidden = true;
    }

    $('botao-restaurar').dataset.aberto = s.ID_RESTAURACAO_ABERTA > 0 ? '1' : '';
  }

  // ---- Backups -----------------------------------------------------------------
  function desenharBackups() {
    const corpo = $('backups');
    corpo.replaceChildren();
    const apagados = $('filtro-apagados').checked;
    const semLog = $('filtro-sem-log').checked;
    const lista = (dados.backups || []).filter((b) => (apagados || b.ARQUIVO_EXISTE || b.TIPO === 'TESTE') && !(semLog && b.TIPO === 'LOG'));
    if (lista.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum backup registrado ainda.');
      td.colSpan = 10;
      tr.append(td);
      corpo.append(tr);
    }
    for (const b of lista) {
      const tr = Util.el('tr');
      const arquivo = Util.el('td', null, b.ARQUIVO_NOME);
      arquivo.title = b.ARQUIVO || '';
      const sit = Util.el('td');
      sit.append(pilula(b.SITUACAO === 'OK' ? 'OK' : 'Erro', b.SITUACAO));
      tr.append(
        Util.el('td', null, Util.dataHora(b.DT_INICIO)),
        Util.el('td', b.TIPO === 'COMPLETO' || b.TIPO === 'SEGURANCA' ? 'forte' : null, b.TIPO_NOME),
        arquivo,
        Util.el('td', 'numero', b.TIPO === 'TESTE' ? '' : Number(b.TAMANHO_MB || 0).toLocaleString('pt-BR', { minimumFractionDigits: 1 })),
        sit,
        Util.el('td', null, b.TIPO === 'TESTE' ? '' : (b.ARQUIVO_EXISTE ? 'sim' : 'apagado pela limpeza')),
        Util.el('td', null, b.COPIA_NUVEM ? 'sim' : ''),
        Util.el('td', null, b.VERSAO || ''),
        Util.el('td', b.PODE_ESCOLHER ? null : 'suave', b.PODE_ESCOLHER ? 'disponível' : (b.TIPO === 'TESTE' ? '' : 'indisponível: ' + (b.MOTIVO_INDISPONIVEL || '').toLowerCase())),
        Util.el('td', 'suave', b.MENSAGEM || ''));
      corpo.append(tr);
    }
    desenharPontos();
  }

  // ---- Restaurar: lista de pontos -------------------------------------------------
  function quandoVolta(b) { return b.TIPO === 'LOG' ? b.DT_PONTO || b.DT_FIM : b.DT_FIM || b.DT_INICIO; }
  function desenharPontos() {
    const corpo = $('pontos');
    corpo.replaceChildren();
    const lista = (dados.backups || []).filter((b) => b.PODE_ESCOLHER)
      .sort((a, b) => String(quandoVolta(b)).localeCompare(String(quandoVolta(a))));
    if (ponto && !lista.some((b) => b.ID_BACKUP === ponto.ID_BACKUP)) ponto = null;
    if (lista.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum ponto de restauração disponível.');
      td.colSpan = 4;
      tr.append(td);
      corpo.append(tr);
    }
    lista.forEach((b, i) => {
      const tr = Util.el('tr', 'clicavel');
      const radio = Util.el('input');
      radio.type = 'radio';
      radio.name = 'ponto';
      radio.setAttribute('aria-label', 'Voltar para ' + Util.dataHora(quandoVolta(b)));
      radio.checked = !!ponto && ponto.ID_BACKUP === b.ID_BACKUP;
      const escolher = () => { ponto = b; radio.checked = true; marcar(); };
      radio.addEventListener('change', escolher);
      tr.addEventListener('click', escolher);
      const celRadio = Util.el('td', 'celula-marca');
      celRadio.append(radio);
      const quando = Util.el('td', 'forte', Util.dataHora(quandoVolta(b)));
      if (i === 0) quando.append(' ', Util.el('span', 'situacao situacao-ativo', 'mais recente'));
      tr.dataset.id = b.ID_BACKUP;
      tr.append(celRadio, quando, Util.el('td', null, b.TIPO_NOME), Util.el('td', null, b.VERSAO || ''));
      corpo.append(tr);
    });
    marcar();
  }
  function marcar() {
    for (const tr of $('pontos').querySelectorAll('tr')) tr.classList.toggle('selecionada', !!ponto && Number(tr.dataset.id) === ponto.ID_BACKUP);
    $('resumo-pedido').textContent = ponto ? 'O banco volta para como estava em ' + Util.dataHora(quandoVolta(ponto)) + ' (' + ponto.TIPO_NOME.toLowerCase() + ').' : 'Escolha um ponto na lista.';
    $('botao-restaurar').disabled = !ponto || $('botao-restaurar').dataset.aberto === '1';
  }
  $('filtro-apagados').addEventListener('change', desenharBackups);
  $('filtro-sem-log').addEventListener('change', desenharBackups);

  // ---- Pedidos -----------------------------------------------------------------
  function desenharPedidos() {
    const corpo = $('pedidos');
    corpo.replaceChildren();
    const lista = dados.pedidos || [];
    if (lista.length === 0) {
      const tr = Util.el('tr');
      const td = Util.el('td', 'vazio', 'Nenhum pedido de restauração.');
      td.colSpan = 8;
      tr.append(td);
      corpo.append(tr);
    }
    for (const p of lista) {
      const tr = Util.el('tr');
      const sit = Util.el('td');
      sit.append(pilula(p.SITUACAO_NOME, p.SITUACAO));
      const resultado = Util.el('td', 'suave', p.MENSAGEM || '');
      if (p.ARQUIVO_SEGURANCA) resultado.title = 'Backup de segurança feito antes: ' + p.ARQUIVO_SEGURANCA;
      const acao = Util.el('td');
      if (p.PODE_CANCELAR) {
        const b = Util.el('button', 'botao', 'Cancelar');
        b.type = 'button';
        b.dataset.dica = 'Cancela o pedido antes de o servidor começar. Depois que começou, não dá mais.';
        b.addEventListener('click', () => cancelar(p));
        acao.append(b);
      }
      tr.append(
        Util.el('td', 'numero', String(p.ID_RESTAURACAO)),
        Util.el('td', null, Util.dataHora(p.DT_PEDIDO)),
        Util.el('td', null, p.USUARIO_PEDIDO),
        Util.el('td', 'forte', Util.dataHora(p.DT_VOLTA_PARA) + (p.TIPO_PONTO === 'BACKUP' ? ' (backup escolhido)' : '')),
        Util.el('td', null, p.MOTIVO),
        sit, resultado, acao);
      corpo.append(tr);
    }
  }

  async function cancelar(p) {
    if (!(await Mensagens.confirmar('Cancelar pedido?', 'O pedido de restauração nº ' + p.ID_RESTAURACAO + ' será cancelado e o banco não será restaurado.', 'Cancelar pedido'))) return;
    const r = await Api.post('/api/sis/backups/cancelar', { idRestauracao: p.ID_RESTAURACAO });
    if (!(await Mensagens.tratar(r))) return;
    await Mensagens.concluido(r.mensagem || 'Pedido cancelado.');
    await carregar();
  }

  // ---- Restaurar: pedido -----------------------------------------------------------
  $('botao-restaurar').addEventListener('click', async () => {
    if (!ponto) { await Mensagens.alerta('Escolha na lista o ponto para onde o banco volta.'); return; }
    if (!$('motivo').value.trim()) { await Mensagens.alerta('Informe o motivo da restauração.', 'ATENCAO', { foco: $('motivo') }); return; }
    if ($('confirmacao').value.trim().toUpperCase() !== 'RESTAURAR') { await Mensagens.alerta('Para confirmar, escreva a palavra RESTAURAR.', 'ATENCAO', { foco: $('confirmacao') }); return; }
    if (!$('senha').value) { await Mensagens.alerta('Digite a sua senha para confirmar.', 'ATENCAO', { foco: $('senha') }); return; }
    const destino = Util.dataHora(quandoVolta(ponto));
    if (!(await Mensagens.confirmar('Restaurar o banco?',
      'O banco volta para como estava em ' + destino + '. Tudo o que foi feito depois disso some do sistema. O sistema sai do ar por alguns minutos para todos. Esta ação não se desfaz pela tela (só com o backup de segurança, que aparece na lista depois).',
      'Restaurar'))) return;
    const porLog = ponto.TIPO_PONTO === 'DATA_HORA';
    const r = await Api.post('/api/sis/backups/restaurar', {
      tipoPonto: ponto.TIPO_PONTO,
      idBackup: porLog ? null : ponto.ID_BACKUP,
      dtPonto: porLog ? String(ponto.DT_PONTO).substring(0, 19) : null,
      motivo: $('motivo').value.trim(),
      confirmacao: $('confirmacao').value.trim(),
      senha: $('senha').value
    });
    $('senha').value = '';
    if (!(await Mensagens.tratar(r))) return;
    $('confirmacao').value = '';
    $('motivo').value = '';
    ponto = null;
    await Mensagens.concluido(r.mensagem || 'Pedido registrado.');
    await carregar();
    ativarAba($('aba-pedidos'));
  });

  // ---- Carga -------------------------------------------------------------------
  async function carregar() {
    const r = await Api.get('/api/sis/backups');
    if (!(await Mensagens.tratar(r))) return;
    dados = r.dados;
    desenharSituacao(dados.situacao || {});
    desenharBackups();
    desenharPedidos();
    clearTimeout(relogio);
    if ((dados.situacao || {}).ID_RESTAURACAO_ABERTA > 0) relogio = setTimeout(() => carregar().catch(() => {}), 20000);
  }

  $('botao-atualizar').addEventListener('click', () => carregar());
  await carregar();
});
