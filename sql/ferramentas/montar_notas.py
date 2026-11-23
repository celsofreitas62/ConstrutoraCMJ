# -*- coding: utf-8 -*-
# montar_notas.py - gera sql/objetos/SIS/Carga_SIS_Versao_Nota.sql a partir de docs/NOTAS_DA_VERSAO.md
# (fonte unica das notas da versao). Autor: Celso de Freitas / Refatorado: Claude.
# v1.0 (23/11/2026) - Criacao (etapa 04c, P22).
# Uso: python3 montar_notas.py            (gera)
#      python3 montar_notas.py --conferir (so confere se o gerado esta atualizado; sai com 1 se nao estiver)
# Regras do .md: secao "## <versao> (dd/mm/aaaa)"; itens "- Novo: ...", "- Melhoria: ...", "- Correção: ...";
# "Novo (só para o administrador geral): ..." = PUBLICO GERAL. **negrito** e `codigo` viram <b> e <code> no TEXTO_HTML.
import os, re, sys, html
BASE = os.environ.get('SISTEMACMJ_SQL', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
RAIZ = os.path.abspath(os.path.join(BASE, '..'))
MD = os.path.join(RAIZ, 'docs', 'NOTAS_DA_VERSAO.md')
SAIDA = os.path.join(BASE, 'objetos', 'SIS', 'Carga_SIS_Versao_Nota.sql')
TIPOS = {'novo': 'NOVO', 'melhoria': 'MELHORIA', 'correção': 'CORRECAO', 'correcao': 'CORRECAO'}

def ler_notas():
    notas, versao, data, ordem = [], None, None, 0
    for linha in open(MD, encoding='utf-8-sig'):
        linha = linha.rstrip()
        m = re.match(r'^##\s+([0-9]+(?:\.[0-9]+){0,2})\s*\((\d{2})/(\d{2})/(\d{4})\)', linha)
        if m:
            versao, data, ordem = m.group(1), '%s-%s-%s' % (m.group(4), m.group(3), m.group(2)), 0
            continue
        if linha.startswith('## '):
            versao = None
            continue
        if versao and linha.startswith('- '):
            m = re.match(r'^-\s+(Novo|Melhoria|Correção|Correcao)\s*(\(([^)]*)\))?\s*:\s*(.+)$', linha, re.I)
            if not m:
                sys.exit('Item sem tipo (Novo/Melhoria/Correção) na versao %s: %s' % (versao, linha))
            ordem += 1
            publico = 'GERAL' if m.group(3) and 'administrador geral' in m.group(3).lower() else 'TODOS'
            texto_md = m.group(4).strip()
            texto = texto_md.replace('**', '').replace('`', '')
            h = html.escape(texto_md, quote=False)
            h = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', h)
            h = re.sub(r'`(.+?)`', r'<code>\1</code>', h)
            if len(texto) > 2000 or len(h) > 4000:
                sys.exit('Item longo demais na versao %s (limite 2000/4000).' % versao)
            notas.append((versao, data, ordem, TIPOS[m.group(1).lower()], publico, texto, h))
    if not notas:
        sys.exit('Nenhuma nota encontrada em ' + MD)
    return notas

def q(s):
    return "N'" + s.replace("'", "''") + "'"

def montar():
    notas = ler_notas()
    linhas = []
    for i, (v, d, o, t, p, tx, h) in enumerate(notas):
        pre = '       ' if i == 0 else '      ,'
        if i == 0:
            linhas.append(pre + "(CAST('%s' AS VARCHAR(20)), CAST('%s' AS DATE), CAST(%d AS SMALLINT), CAST('%s' AS VARCHAR(10)), CAST('%s' AS VARCHAR(10)),\n         CAST(%s AS NVARCHAR(2000)), CAST(%s AS NVARCHAR(4000)))" % (v, d, o, t, p, q(tx), q(h)))
        else:
            linhas.append(pre + "('%s', '%s', %d, '%s', '%s',\n         %s,\n         %s)" % (v, d, o, t, p, q(tx), q(h)))
    versoes = sorted(set(n[0] for n in notas), key=lambda x: [int(y) for y in x.split('.')], reverse=True)
    return """/*******************************************************************************
  Objeto      : carga de [SIS].[Versao_Nota] (notas de cada versão)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : GERADO por sql/ferramentas/montar_notas.py a partir de
                docs/NOTAS_DA_VERSAO.md (fonte única). NÃO EDITAR À MÃO:
                corrigir o .md e gerar de novo.
                Sincroniza a tabela com o .md (as notas são do sistema, não da
                CMJ): inclui o que falta, acerta o texto do que mudou e tira o
                item que saiu do .md. Idempotente.
                Versões no arquivo: """ + ', '.join(versoes) + """.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaNota;
SELECT v.VERSAO, SIS.fn_SIS_Versao_Numero(v.VERSAO) AS VERSAO_NUMERO, v.DT_VERSAO, v.ORDEM, v.TIPO, v.PUBLICO, v.TEXTO, v.TEXTO_HTML
INTO #CargaNota
FROM (VALUES
""" + '\n'.join(linhas) + """
     ) v (VERSAO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML);

MERGE SIS.Versao_Nota AS d
USING #CargaNota AS o
   ON d.VERSAO = o.VERSAO AND d.ORDEM = o.ORDEM
WHEN MATCHED AND (d.TIPO <> o.TIPO OR d.PUBLICO <> o.PUBLICO OR d.TEXTO <> o.TEXTO OR d.TEXTO_HTML <> o.TEXTO_HTML
                  OR d.VERSAO_NUMERO <> o.VERSAO_NUMERO OR ISNULL(d.DT_VERSAO, '19000101') <> ISNULL(o.DT_VERSAO, '19000101')) THEN
    UPDATE SET d.VERSAO_NUMERO = o.VERSAO_NUMERO, d.DT_VERSAO = o.DT_VERSAO, d.TIPO = o.TIPO, d.PUBLICO = o.PUBLICO,
               d.TEXTO = o.TEXTO, d.TEXTO_HTML = o.TEXTO_HTML
WHEN NOT MATCHED BY TARGET THEN
    INSERT (VERSAO, VERSAO_NUMERO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML)
    VALUES (o.VERSAO, o.VERSAO_NUMERO, o.DT_VERSAO, o.ORDEM, o.TIPO, o.PUBLICO, o.TEXTO, o.TEXTO_HTML)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;

DROP TABLE IF EXISTS #CargaNota;
PRINT N'Notas das versões carregadas.';
GO
"""

def gravar(texto):
    dados = b'\\xef\\xbb\\xbf'.decode('unicode_escape').encode('latin-1') + texto.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8')
    open(SAIDA, 'wb').write(dados)

if __name__ == '__main__':
    texto = montar()
    if '--conferir' in sys.argv:
        atual = open(SAIDA, encoding='utf-8-sig').read().replace('\r\n', '\n') if os.path.exists(SAIDA) else ''
        if atual.rstrip('\n') != texto.rstrip('\n'):
            print('DESATUALIZADO: rode python3 sql/ferramentas/montar_notas.py'); sys.exit(1)
        print('OK: Carga_SIS_Versao_Nota.sql em dia com o NOTAS_DA_VERSAO.md'); sys.exit(0)
    gravar(texto)
    print('Gerado: ' + SAIDA + ' (' + str(len(ler_notas())) + ' itens)')
