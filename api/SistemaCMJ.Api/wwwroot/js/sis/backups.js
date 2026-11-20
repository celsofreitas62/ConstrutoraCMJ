/* =============================================================================
   SistemaCMJ - js/sis/backups.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 20/11/2026 (etapa 03d2)
   Descrição : Tela "Backups e restauração" (SIS_BACKUP). Topo: até onde dá
               para voltar e os últimos backups. Abas: lista dos backups;
               Restaurar (só com a ação RESTAURAR): dia e hora ou backup
               escolhido, motivo, a palavra RESTAURAR e a senha; pedidos de
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
    $('sit-de').textContent = s.DT_PODE_VOLTAR_DE ? Util.dataHora(s.DT_PODE_VOLTAR_DE) : 'sem backup completo';
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

    const minimo = paraCampo(s.DT_PODE_VOLTAR_DE);
    const maximo = paraCampo(s.DT_PODE_VOLTAR_ATE);
    $('dt-ponto').min = minimo;
    $('dt-ponto').max = maximo;
    $('botao-restaurar').disabled = s.ID_RESTAURACAO_ABERTA > 0;
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
      td.colSpan = 8;
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
        Util.el('td', 'suave', b.MENSAGEM || ''));
      corpo.append(tr);
    }

    const select = $('id-backup');
    const atual = select.value;
    select.replaceChildren(Util.el('option', null, '(escolha)'));
    select.firstChild.value = '';
    for (const b of (dados.backups || []).filter((x) => x.PODE_ESCOLHER)) {
      const op = Util.el('option', null, Util.dataHora(b.DT_FIM || b.DT_INICIO) + ' · ' + b.TIPO_NOME + ' · ' + b.ARQUIVO_NOME);
      op.value = String(b.ID_BACKUP);
      select.append(op);
    }
    select.value = atual;
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

  // ---- Restaurar ---------------------------------------------------------------
  function tipoPonto() { return document.querySelector('input[name="tipo-ponto"]:checked').value; }
  function mostrarTipo() {
    const porData = tipoPonto() === 'DATA_HORA';
    $('campo-ponto').hidden = !porData;
    $('campo-backup').hidden = porData;
    resumir();
  }
  function resumir() {
    let texto = '';
    if (tipoPonto() === 'DATA_HORA' && $('dt-ponto').value) texto = 'O banco volta para ' + Util.dataHora($('dt-ponto').value) + '.';
    if (tipoPonto() === 'BACKUP' && $('id-backup').value) texto = 'O banco volta para o backup ' + $('id-backup').selectedOptions[0].textContent + '.';
    $('resumo-pedido').textContent = texto;
  }
  document.querySelectorAll('input[name="tipo-ponto"]').forEach((r) => r.addEventListener('change', mostrarTipo));
  $('dt-ponto').addEventListener('input', resumir);
  $('id-backup').addEventListener('change', resumir);

  $('botao-restaurar').addEventListener('click', async () => {
    const tipo = tipoPonto();
    if (tipo === 'DATA_HORA' && !$('dt-ponto').value) { await Mensagens.alerta('Informe o dia e a hora para voltar.', 'ATENCAO', { foco: $('dt-ponto') }); return; }
    if (tipo === 'BACKUP' && !$('id-backup').value) { await Mensagens.alerta('Escolha o backup para voltar.', 'ATENCAO', { foco: $('id-backup') }); return; }
    if (!$('motivo').value.trim()) { await Mensagens.alerta('Informe o motivo da restauração.', 'ATENCAO', { foco: $('motivo') }); return; }
    if ($('confirmacao').value.trim().toUpperCase() !== 'RESTAURAR') { await Mensagens.alerta('Para confirmar, escreva a palavra RESTAURAR.', 'ATENCAO', { foco: $('confirmacao') }); return; }
    if (!$('senha').value) { await Mensagens.alerta('Digite a sua senha para confirmar.', 'ATENCAO', { foco: $('senha') }); return; }
    const destino = tipo === 'DATA_HORA' ? Util.dataHora($('dt-ponto').value) : $('id-backup').selectedOptions[0].textContent;
    if (!(await Mensagens.confirmar('Restaurar o banco?',
      'O banco volta para ' + destino + '. Tudo o que foi feito depois disso some do sistema. O sistema sai do ar por alguns minutos para todos. Esta ação não se desfaz pela tela (só com o backup de segurança).',
      'Restaurar'))) return;
    const r = await Api.post('/api/sis/backups/restaurar', {
      tipoPonto: tipo,
      idBackup: tipo === 'BACKUP' ? Number($('id-backup').value) : null,
      dtPonto: tipo === 'DATA_HORA' ? $('dt-ponto').value : null,
      motivo: $('motivo').value.trim(),
      confirmacao: $('confirmacao').value.trim(),
      senha: $('senha').value
    });
    $('senha').value = '';
    if (!(await Mensagens.tratar(r))) return;
    $('confirmacao').value = '';
    $('motivo').value = '';
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
    resumir();
    clearTimeout(relogio);
    if ((dados.situacao || {}).ID_RESTAURACAO_ABERTA > 0) relogio = setTimeout(() => carregar().catch(() => {}), 20000);
  }

  $('botao-atualizar').addEventListener('click', () => carregar());
  mostrarTipo();
  await carregar();
});
