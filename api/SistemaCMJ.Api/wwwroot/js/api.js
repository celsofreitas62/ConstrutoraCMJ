/* =============================================================================
   SistemaCMJ - js/api.js
   Autor     : Celso de Freitas
   Refatorado: Claude
   Criação   : 16/11/2026 (fase 3b)
   Descrição : Chamada única da API pelas telas. Toda resposta tem o formato
               { sucesso, tipo, mensagem, dados } (Infra/Resposta.cs).
               - Sessão terminada  -> volta ao login (e retorna à tela depois);
               - Senha a trocar    -> vai para a troca de senha;
               - Sem comunicação   -> resposta de ERRO com texto simples.
               Cabeçalhos: X-CMJ (proteção contra envio de outro site) e
               X-Tela (tela de origem, gravada na auditoria e no log).
   ========================================================================== */
'use strict';

const Api = (() => {
  const SEM_COMUNICACAO = {
    sucesso: false, tipo: 'ERRO', dados: null,
    mensagem: 'Sem comunicação com o servidor do sistema. Confira a rede e tente de novo.'
  };

  function irParaLogin() {
    const volta = location.pathname + location.search;
    location.href = '/login.html' + (volta && volta !== '/login.html' ? '?volta=' + encodeURIComponent(volta) : '');
  }

  async function chamar(metodo, url, corpo) {
    const opcoes = {
      method: metodo,
      credentials: 'same-origin',
      headers: { 'X-CMJ': '1', 'X-Tela': document.body.dataset.tela || '' }
    };
    if (corpo !== undefined) {
      opcoes.headers['Content-Type'] = 'application/json';
      opcoes.body = JSON.stringify(corpo);
    }

    let resposta;
    try {
      resposta = await fetch(url, opcoes);
    } catch {
      return SEM_COMUNICACAO;
    }

    let json = null;
    try { json = await resposta.json(); } catch { /* resposta sem JSON */ }

    if (json && json.tipo === 'SESSAO' && !document.body.dataset.publica) {
      irParaLogin();
      return new Promise(() => {}); // a página vai sair; não continua o fluxo
    }
    if (json && json.tipo === 'TROCAR_SENHA' && location.pathname !== '/trocar-senha.html') {
      location.href = '/trocar-senha.html';
      return new Promise(() => {});
    }
    return json || { ...SEM_COMUNICACAO, mensagem: 'O servidor respondeu de um jeito inesperado (código ' + resposta.status + ').' };
  }

  function montarUrl(url, parametros) {
    if (!parametros) return url;
    const q = new URLSearchParams();
    for (const [k, v] of Object.entries(parametros)) if (v !== undefined && v !== null && v !== '') q.set(k, v);
    const texto = q.toString();
    return texto ? url + '?' + texto : url;
  }

  return {
    get: (url, parametros) => chamar('GET', montarUrl(url, parametros)),
    post: (url, corpo) => chamar('POST', url, corpo ?? {}),
    irParaLogin
  };
})();

/* Utilidades de tela usadas por todas as páginas. */
const Util = {
  el(tag, classe, texto) {
    const e = document.createElement(tag);
    if (classe) e.className = classe;
    if (texto !== undefined && texto !== null) e.textContent = texto;
    return e;
  },
  dataHora(valor) {
    if (!valor) return '';
    const d = new Date(valor);
    if (isNaN(d)) return String(valor);
    return d.toLocaleDateString('pt-BR') + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  },
  data(valor) {
    if (!valor) return '';
    const d = new Date(valor);
    return isNaN(d) ? String(valor) : d.toLocaleDateString('pt-BR');
  },
  /** "2026-03-14T00:00:00" -> "2026-03-14" (campo type=date) */
  dataIso(valor) { return valor ? String(valor).substring(0, 10) : ''; },
  parametro(nome) { return new URLSearchParams(location.search).get(nome); },
  /** Abre o endereço recarregando a página mesmo quando só muda o "#" (ex.: ficha?id=1#permissoes). */
  recarregar(destino) {
    const alvo = new URL(destino, location.href);
    if (alvo.pathname === location.pathname && alvo.search === location.search) {
      history.replaceState(null, '', alvo.href);
      location.reload();
    } else {
      location.replace(alvo.href);
    }
  },
  atrasar(fn, ms = 300) {
    let t;
    return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
  }
};
