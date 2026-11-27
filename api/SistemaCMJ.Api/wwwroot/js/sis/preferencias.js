/* =============================================================================
   SistemaCMJ - js/sis/preferencias.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 27/11/2026 (etapa 04h2)
   Descrição : Minhas preferências (P03, P06), para todos os usuários: abre
               pelo botão ⚙ do topo. Lê o catálogo do banco
               (SIS_Preferencia_Listar: grupo, tipo, opções, faixa, padrão da
               empresa e a escolha do usuário) e monta um campo por
               preferência; "Voltar ao padrão" faz a preferência seguir o
               padrão da empresa (grava vazio). Gravar segue o padrão:
               "Gravar?" › "Concluído". Opções ainda não prontas aparecem
               marcadas "em breve" (tema: 04h4; o calendário ficou pronto na
               04h3).
   ========================================================================== */
'use strict';

document.addEventListener('DOMContentLoaded', async () => {
  const { sessao } = await Layout.iniciar();
  if (!sessao) return;
  const $ = (id) => document.getElementById(id);

  // O que ainda não funciona nesta versão (some quando a etapa chegar).
  const EM_BREVE_OPCAO = {};
  const EM_BREVE_PREF = new Set();   // TEMA ficou pronto na 04h4

  const rotulo = (v) => Rotulos.de('preferencia', v);
  const opcoes = (p) => (p.OPCOES || '').split(';').map((o) => o.trim()).filter(Boolean);
  const textoValor = (p, v) => (p.TIPO === 'SN' ? (v === 'S' ? 'Sim' : 'Não') : (opcoes(p).length ? rotulo(v) : v));

  let prefs = [];
  const escolha = new Map();   // CODIGO -> valor na tela ('' = segue o padrão)
  let sujo = false;

  function campoDe(p) {
    let campo;
    const emBreve = EM_BREVE_PREF.has(p.CODIGO);
    if (p.TIPO === 'SN' || opcoes(p).length) {
      campo = Util.el('select');
      const lista = p.TIPO === 'SN' ? ['S', 'N'] : opcoes(p);
      for (const o of lista) {
        const breve = (EM_BREVE_OPCAO[p.CODIGO] || []).includes(o);
        const op = Util.el('option', null, (p.TIPO === 'SN' ? (o === 'S' ? 'Sim' : 'Não') : rotulo(o)) + (breve ? ' (em breve)' : ''));
        op.value = o;
        campo.append(op);
      }
    } else {
      campo = Util.el('input');
      campo.type = p.TIPO === 'INTEIRO' ? 'number' : 'text';
      if (p.TIPO === 'INTEIRO') {
        campo.step = '1';
        if (p.VALOR_MAXIMO) { campo.min = p.VALOR_MINIMO; campo.max = p.VALOR_MAXIMO; }
      }
    }
    campo.id = 'pref-' + p.CODIGO;
    campo.disabled = emBreve;
    campo.value = p.VALOR;
    return campo;
  }

  function desenhar() {
    const caixa = $('grupos');
    caixa.replaceChildren();
    const grupos = [...new Set(prefs.map((p) => p.GRUPO))];
    for (const g of grupos) {
      const secao = Util.el('fieldset', 'grupo-preferencias');
      secao.append(Util.el('legend', null, g));
      for (const p of prefs.filter((x) => x.GRUPO === g)) {
        const emBreve = EM_BREVE_PREF.has(p.CODIGO);
        const linha = Util.el('div', 'linha-preferencia');
        const rot = Util.el('label', 'campo');
        const campo = campoDe(p);
        const faixa = p.TIPO === 'INTEIRO' && p.VALOR_MAXIMO ? ' De ' + p.VALOR_MINIMO + ' a ' + p.VALOR_MAXIMO + '.' : '';
        rot.dataset.dica = p.DESCRICAO + faixa + (emBreve ? ' Fica pronto numa das próximas versões.' : '');
        rot.htmlFor = campo.id;
        rot.append(p.NOME + (emBreve ? ' (em breve)' : ''), campo);

        const info = Util.el('div', 'info-preferencia');
        const padrao = Util.el('span', 'suave', 'Padrão da empresa: ' + (p.VALOR_PADRAO === '' ? '(não definido)' : textoValor(p, p.VALOR_PADRAO)));
        const etiqueta = Util.el('span', 'situacao situacao-aberta', 'Sua escolha');
        const voltar = Util.el('button', 'botao botao-pequeno', 'Voltar ao padrão');
        voltar.type = 'button';
        voltar.dataset.dica = 'Esta preferência passa a seguir o padrão da empresa (e acompanha se ele mudar).';
        info.append(padrao, etiqueta, voltar);

        const atualizar = () => {
          const segue = escolha.get(p.CODIGO) === '';
          etiqueta.hidden = segue;
          voltar.hidden = segue || emBreve;
        };
        escolha.set(p.CODIGO, p.PERSONALIZADA ? p.VALOR_USUARIO : '');
        campo.addEventListener('change', () => {
          const v = campo.value.trim();
          escolha.set(p.CODIGO, v === p.VALOR_PADRAO && !p.PERSONALIZADA ? '' : v);
          sujo = true;
          atualizar();
        });
        voltar.addEventListener('click', () => {
          campo.value = p.VALOR_PADRAO;
          escolha.set(p.CODIGO, '');
          sujo = true;
          atualizar();
        });
        atualizar();
        linha.append(rot, info);
        secao.append(linha);
      }
      caixa.append(secao);
    }
  }

  async function carregar() {
    const r = await Api.get('/api/sis/preferencias');
    if (!(await Mensagens.tratar(r))) return;
    prefs = r.dados || [];
    escolha.clear();
    sujo = false;
    desenhar();
  }

  $('form-preferencias').addEventListener('submit', async (e) => {
    e.preventDefault();
    // Só manda o que mudou em relação ao que está gravado.
    const mudou = prefs
      .filter((p) => !EM_BREVE_PREF.has(p.CODIGO))
      .map((p) => ({ codigo: p.CODIGO, valor: escolha.get(p.CODIGO) ?? '' }))
      .filter((i) => i.valor !== (prefs.find((p) => p.CODIGO === i.codigo).PERSONALIZADA ? prefs.find((p) => p.CODIGO === i.codigo).VALOR_USUARIO : ''));
    if (!mudou.length) { await Mensagens.alerta('Nada foi alterado.'); return; }
    if (!(await Mensagens.confirmar('Gravar?', 'Gravar as suas preferências?', 'Confirmar'))) return;
    const r = await Api.post('/api/sis/preferencias', { preferencias: mudou });
    if (!(await Mensagens.tratar(r, { foco: $('pref-' + (mudou[0] || {}).codigo) }))) return;
    // A agenda deste computador passa a abrir pela preferência nova.
    try { localStorage.removeItem('cmj.inicio.estado'); } catch { /* sem armazenamento */ }
    await Layout.aplicarAparencia(true);   // tamanho das letras e tema valem na hora
    await Mensagens.concluido('Preferências gravadas.');
    await carregar();
  });

  async function sair() {
    if (sujo && !(await Mensagens.confirmar('Descartar alterações?', 'Há alterações que ainda não foram gravadas. Elas serão perdidas.', 'Descartar'))) return;
    location.href = '/';
  }
  $('botao-voltar').addEventListener('click', sair);
  $('link-voltar').addEventListener('click', (e) => { e.preventDefault(); sair(); });
  document.addEventListener('keydown', (e) => {
    if (document.querySelector('.janela')) return;
    if (e.ctrlKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); $('form-preferencias').requestSubmit(); }
    else if (e.key === 'Escape') sair();
  });

  await carregar();
});
