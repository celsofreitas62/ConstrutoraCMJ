/* =============================================================================
   SistemaCMJ - js/anexos.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 25/11/2026 (04d2 passo 5)
   Descrição : Aba "Anexos" padrão das fichas (componente único, como o
               js/historico.js). Lista os anexos do registro (tipo, nome,
               descrição, validade com etiqueta "Vencido", quem enviou e quando),
               Anexar (tipo, arquivo, descrição, validade), Baixar e Excluir (com
               motivo; o arquivo fica guardado e aparece em "Mostrar excluídos").
               API: /api/sis/anexos (Endpoints/AnexoEndpoints.cs).
   Uso       : const anexos = Anexos.criar(elemento, { item, tabela, id, podeAnexar,
                 aoMudar });  await anexos.carregar();
   ========================================================================== */
'use strict';

const Anexos = (() => {
  const formatarTamanho = (b) => b >= 1048576 ? (b / 1048576).toFixed(1).replace('.', ',') + ' MB' : Math.max(1, Math.round(b / 1024)) + ' KB';
  const dataBr = (v) => { if (!v) return ''; const [a, m, d] = String(v).slice(0, 10).split('-'); return d + '/' + m + '/' + a; };
  const dataHoraBr = (v) => v ? dataBr(v) + ' ' + String(v).slice(11, 16) : '';

  function criar(raiz, opcoes) {
    const { item, tabela, id, podeAnexar = false, aoMudar = null } = opcoes;
    let tipos = null;

    const barra = Util.el('div', 'barra-lista');
    const texto = Util.el('span', 'suave', 'Contratos, documentos, certidões e outros arquivos deste registro.');
    const marca = Util.el('label', 'marcacao');
    const excluidos = Util.el('input');
    excluidos.type = 'checkbox';
    marca.append(excluidos, document.createTextNode(' Mostrar excluídos'));
    marca.dataset.dica = 'Mostra também os anexos excluídos, com quem excluiu, quando e o motivo.';
    const anexar = Util.el('button', 'botao botao-contorno', '+ Anexar arquivo');
    anexar.type = 'button';
    anexar.hidden = !podeAnexar;
    anexar.dataset.dica = 'Envia um arquivo para este registro (escolha o tipo, o arquivo e, se quiser, descrição e validade).';
    barra.append(texto, marca, anexar);

    const rolagem = Util.el('div', 'rolagem');
    const tabelaEl = Util.el('table', 'tabela tabela-larga');
    const cab = Util.el('thead');
    const linhaCab = Util.el('tr');
    for (const t of ['Tipo', 'Arquivo', 'Descrição', 'Validade', 'Enviado por', '']) {
      const th = Util.el('th', null, t);
      th.scope = 'col';
      linhaCab.append(th);
    }
    cab.append(linhaCab);
    const corpo = Util.el('tbody');
    tabelaEl.append(cab, corpo);
    rolagem.append(tabelaEl);
    raiz.replaceChildren(barra, rolagem);

    async function carregar() {
      const r = await Api.get('/api/sis/anexos', { item, tabela, idRegistro: id, incluirExcluidos: excluidos.checked });
      if (!(await Mensagens.tratar(r))) return false;
      desenhar(r.dados || []);
      return true;
    }

    function desenhar(linhas) {
      corpo.replaceChildren();
      if (!linhas.length) {
        const tr = Util.el('tr');
        const td = Util.el('td', 'vazio', 'Nenhum anexo.');
        td.colSpan = 6;
        tr.append(td);
        corpo.append(tr);
      }
      for (const a of linhas) {
        const excluido = a.SITUACAO !== 'ATIVO';
        const tr = Util.el('tr', excluido ? 'suave' : null);
        const validade = Util.el('td', null, dataBr(a.DT_VALIDADE));
        if (a.VENCIDO && !excluido) validade.append(' ', Util.el('span', 'etiqueta etiqueta-apaga', 'Vencido'));
        const arquivo = Util.el('td', 'forte', a.NOME_ORIGINAL);
        arquivo.append(Util.el('span', 'suave', ' (' + formatarTamanho(Number(a.TAMANHO_BYTES || 0)) + ')'));
        const descricao = Util.el('td', null, a.DESCRICAO || '');
        if (excluido) descricao.append(Util.el('div', 'suave', 'Excluído por ' + a.USUARIO_EXCLUSAO + ' em ' + dataHoraBr(a.DT_EXCLUSAO) + (a.MOTIVO_EXCLUSAO ? ': ' + a.MOTIVO_EXCLUSAO : '')));
        const acoes = Util.el('td');
        if (!excluido) {
          const baixar = Util.el('button', 'botao botao-contorno', 'Baixar');
          baixar.type = 'button';
          baixar.dataset.dica = 'Baixa o arquivo para o seu computador.';
          baixar.addEventListener('click', () => baixarArquivo(a, baixar));
          acoes.append(baixar);
          if (podeAnexar) {
            const excluir = Util.el('button', 'botao botao-contorno', 'Excluir');
            excluir.type = 'button';
            excluir.dataset.dica = 'Tira o anexo da lista (pede o motivo). O arquivo fica guardado e aparece em "Mostrar excluídos".';
            excluir.addEventListener('click', () => excluirAnexo(a));
            acoes.append(' ', excluir);
          }
        }
        tr.append(Util.el('td', null, a.TIPO_NOME), arquivo, descricao, validade,
          Util.el('td', null, a.USUARIO_CRIACAO + ' em ' + dataHoraBr(a.DT_CRIACAO)), acoes);
        corpo.append(tr);
      }
      if (aoMudar) aoMudar(linhas.filter((a) => a.SITUACAO === 'ATIVO').length);
    }

    async function baixarArquivo(a, botao) {
      botao.disabled = true;
      let resposta;
      try {
        resposta = await fetch('/api/sis/anexos/' + encodeURIComponent(a.ID_ANEXO) + '/arquivo?item=' + encodeURIComponent(item),
          { credentials: 'same-origin', headers: { 'X-CMJ': '1', 'X-Tela': document.body.dataset.tela || '' } });
      } catch {
        resposta = null;
      }
      botao.disabled = false;
      const tipo = resposta ? (resposta.headers.get('Content-Type') || '') : '';
      if (!resposta || tipo.includes('application/json') || !resposta.ok) {
        let json = null;
        try { json = resposta ? await resposta.json() : null; } catch { /* sem JSON */ }
        await Mensagens.tratar(json || { sucesso: false, tipo: 'ERRO', mensagem: 'Não foi possível baixar o arquivo.' });
        return;
      }
      const url = URL.createObjectURL(await resposta.blob());
      const link = Util.el('a');
      link.href = url;
      link.download = a.NOME_ORIGINAL;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    }

    async function excluirAnexo(a) {
      const motivo = await Mensagens.pedirTexto('Excluir anexo?', 'O anexo "' + a.NOME_ORIGINAL + '" sai da lista. O arquivo fica guardado e aparece em "Mostrar excluídos".',
        { rotulo: 'Motivo', botao: 'Excluir', obrigatorio: true });
      if (motivo === null) return;
      const r = await Api.post('/api/sis/anexos/' + encodeURIComponent(a.ID_ANEXO) + '/excluir', { item, motivo });
      if (!(await Mensagens.tratar(r))) return;
      await Mensagens.concluido(r.mensagem || 'Anexo excluído.');
      await carregar();
    }

    async function janelaAnexar() {
      if (!tipos) {
        const r = await Api.get('/api/sis/anexos/tipos', { item });
        if (!(await Mensagens.tratar(r))) return;
        tipos = r.dados || [];
      }
      const maxMb = tipos.length ? Number(tipos[0].TAMANHO_MAX_MB || 0) : 0;
      const janela = Util.el('dialog', 'janela janela-larga');
      const h2 = Util.el('h2', null, 'Anexar arquivo');
      const topo = Util.el('div', 'janela-topo');
      topo.append(h2);

      const campo = (rotulo, el, dica) => { const l = Util.el('label', 'campo janela-campo', rotulo); l.dataset.dica = dica; l.append(el); return l; };
      const tipo = Util.el('select');
      for (const t of tipos) { const o = Util.el('option', null, t.NOME); o.value = t.CODIGO; tipo.append(o); }
      const arquivo = Util.el('input');
      arquivo.type = 'file';
      const aceitas = Util.el('div', 'suave');
      const atualizarAceitas = () => {
        const t = tipos.find((x) => x.CODIGO === tipo.value);
        const ext = t ? t.EXTENSOES.split(',').map((e) => e.trim()).filter(Boolean) : [];
        arquivo.accept = ext.map((e) => '.' + e).join(',');
        aceitas.textContent = 'Aceita: ' + ext.join(', ') + (maxMb ? ' · até ' + maxMb + ' MB' : '');
      };
      tipo.addEventListener('change', atualizarAceitas);
      atualizarAceitas();
      const descricao = Util.el('input');
      descricao.type = 'text';
      descricao.maxLength = 400;
      const validade = Util.el('input');
      validade.type = 'date';
      const erro = Util.el('div', 'aviso-revisar');
      erro.hidden = true;

      const botoes = Util.el('div', 'janela-botoes');
      const cancelar = Util.el('button', 'botao', 'Cancelar');
      cancelar.type = 'button';
      const enviar = Util.el('button', 'botao botao-principal', 'Anexar');
      enviar.type = 'button';
      botoes.append(cancelar, enviar);
      janela.append(topo,
        campo('Tipo de anexo *', tipo, 'Obrigatório. O tipo define as extensões aceitas.'),
        campo('Arquivo *', arquivo, 'Obrigatório. Escolha o arquivo no seu computador.'), aceitas,
        campo('Descrição', descricao, 'Opcional. Ex.: contrato social atualizado, certidão negativa federal.'),
        campo('Validade', validade, 'Opcional. Data em que o documento vence (certidões, contratos). Depois dela aparece "Vencido".'),
        erro, botoes);
      document.body.append(janela);
      janela.addEventListener('cancel', (e) => e.preventDefault());
      janela.showModal();
      tipo.focus();

      const fechar = () => { janela.close(); janela.remove(); };
      cancelar.addEventListener('click', fechar);
      enviar.addEventListener('click', async () => {
        const f = arquivo.files && arquivo.files[0];
        const aviso = (t) => { erro.textContent = t; erro.hidden = false; };
        if (!f) return aviso('Escolha o arquivo.');
        if (maxMb && f.size > maxMb * 1048576) return aviso('O arquivo precisa ter até ' + maxMb + ' MB.');
        const form = new FormData();
        form.append('item', item);
        form.append('tabela', tabela);
        form.append('idRegistro', String(id));
        form.append('codigoTipo', tipo.value);
        form.append('descricao', descricao.value.trim());
        form.append('dtValidade', validade.value);
        form.append('arquivo', f, f.name);
        enviar.disabled = true;
        cancelar.disabled = true;
        const r = await Api.enviarArquivo('/api/sis/anexos', form);
        enviar.disabled = false;
        cancelar.disabled = false;
        if (!r.sucesso) {
          aviso(r.mensagem || 'Não foi possível anexar o arquivo.');
          return;
        }
        fechar();
        await Mensagens.concluido(r.mensagem || 'Arquivo anexado.');
        await carregar();
      });
    }

    anexar.addEventListener('click', janelaAnexar);
    excluidos.addEventListener('change', carregar);
    return { carregar };
  }

  return { criar };
})();
