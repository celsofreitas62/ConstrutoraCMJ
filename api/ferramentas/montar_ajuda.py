# =============================================================================
#  SistemaCMJ - api/ferramentas/montar_ajuda.py
#  Autor     : Celso de Freitas / Refatorado: Claude
#  v1.0 (22/11/2026) - Criação (etapa 03g). Gera a ajuda do administrador
#                      geral a partir das fontes em docs/ajuda_geral/*.md
#                      (fonte única: trechos de outros documentos entram por
#                      <!-- incluir: ... -->). Saída: api/SistemaCMJ.Api/AjudaGeral/
#                      (<página>.html e indice.json), embutida no executável.
#  v1.1 (22/11/2026) - Linha recuada fora de lista não vira bloco de código.
#  Uso       : python3 api/ferramentas/montar_ajuda.py            (gera)
#              python3 api/ferramentas/montar_ajuda.py --conferir (só confere;
#              sai com código 1 se alguma página estiver desatualizada)
# =============================================================================
import hashlib, html, json, os, re, sys
import markdown

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONTES = os.path.join(RAIZ, 'docs', 'ajuda_geral')
SAIDA = os.path.join(RAIZ, 'api', 'SistemaCMJ.Api', 'AjudaGeral')
CSPROJ = os.path.join(RAIZ, 'api', 'SistemaCMJ.Api', 'SistemaCMJ.Api.csproj')
VERSAO_BANCO = os.path.join(RAIZ, 'api', 'SistemaCMJ.Api', 'Infra', 'VersaoBanco.cs')

def ler(caminho):
    return open(caminho, encoding='utf-8-sig').read().replace('\r\n', '\n')

def versoes():
    prog = re.search(r'<Version>([^<]+)</Version>', ler(CSPROJ)).group(1)
    banco = re.search(r'VersaoExigida\s*=\s*"([^"]+)"', ler(VERSAO_BANCO)).group(1)
    return prog, banco

def secao(texto, prefixo):
    """Trecho que começa no título '#... <prefixo>' e vai até o próximo título do mesmo nível ou acima."""
    linhas = texto.split('\n')
    inicio = nivel = None
    em_codigo = False
    for i, l in enumerate(linhas):
        if l.startswith('```'): em_codigo = not em_codigo
        if em_codigo: continue
        m = re.match(r'^(#+)\s+(.*)$', l)
        if not m: continue
        if inicio is None:
            if m.group(2).strip().startswith(prefixo):
                inicio, nivel = i, len(m.group(1))
        elif len(m.group(1)) <= nivel:
            return '\n'.join(linhas[inicio:i]).rstrip()
    if inicio is None:
        raise SystemExit('ERRO: seção "' + prefixo + '" não encontrada')
    return '\n'.join(linhas[inicio:]).rstrip()

def incluir(texto, pasta, usadas):
    def troca(m):
        alvo, _, pref = m.group(1).partition('#')
        caminho = os.path.normpath(os.path.join(pasta, alvo.strip()))
        if not os.path.isfile(caminho): raise SystemExit('ERRO: arquivo a incluir não existe: ' + caminho)
        usadas.add(caminho)
        doc = ler(caminho)
        if pref.strip():
            return secao(doc, pref.strip())
        return re.sub(r'\A# [^\n]*\n', '', doc, count=1).strip()   # documento inteiro, sem o título
    return re.sub(r'<!--\s*incluir:\s*(.+?)\s*-->', troca, texto)

def cabecalho(texto, arquivo):
    m = re.match(r'\s*<!--\s*(pagina:.*?)-->', texto, re.S)
    if not m: raise SystemExit('ERRO: ' + arquivo + ' sem a linha <!-- pagina: ... -->')
    meta = {}
    for parte in m.group(1).split('|'):
        chave, _, valor = parte.partition(':')
        meta[chave.strip()] = valor.strip()
    if not re.fullmatch(r'[a-z0-9-]{1,60}', meta.get('pagina', '')): raise SystemExit('ERRO: nome de página inválido em ' + arquivo)
    return meta, texto[m.end():]

def para_html(md):
    md = re.sub(r'^(\s*[-*]) \[ \] ', r'\1 ☐ ', md, flags=re.M)
    md = re.sub(r'^(\s*[-*]) \[x\] ', r'\1 ☑ ', md, flags=re.M | re.I)
    # Ajustes para o Python-Markdown (os .md do projeto seguem o estilo do GitHub):
    #  - lista recuada com 2 ou 3 espaços: dobra o recuo (ele pede 4 para aninhar);
    #  - lista logo depois de um parágrafo: põe a linha em branco que ele exige.
    item = re.compile(r'^\s*(?:[-*]|\d+[a-z]?\.) ')
    #  - linha recuada fora de lista (ex.: depois de um bloco de código): tira o
    #    recuo, senão vira bloco de código (achado do Celso, 22/11/2026).
    saida, anterior, em_codigo, em_lista = [], '', False, False
    for l in md.split('\n'):
        cerca = l.lstrip().startswith('```')
        if cerca: em_codigo = not em_codigo
        if cerca and not l.startswith(' '): em_lista = False
        if not em_codigo or cerca:
            recuo = len(l) - len(l.lstrip(' '))
            if item.match(l): em_lista = True
            elif l.strip() and recuo == 0 and not cerca: em_lista = False
            if 0 < recuo < 8 and l.strip():
                l = (' ' * (recuo * 2) if em_lista else '') + l.lstrip(' ')
            if item.match(l) and anterior.strip() and not item.match(anterior) and not anterior.startswith(' ') and not anterior.startswith('|'):
                saida.append('')
        saida.append(l)
        anterior = l
    md = '\n'.join(saida)
    return markdown.markdown(md, extensions=['tables', 'fenced_code', 'sane_lists'], output_format='html5')

def texto_puro(h):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', h))).strip()

def montar():
    prog, banco = versoes()
    paginas, indice, usadas = {}, [], set()
    for nome in sorted(os.listdir(FONTES)):
        m = re.fullmatch(r'(\d+)_.+\.md', nome)
        if not m: continue
        bruto = ler(os.path.join(FONTES, nome))
        meta, corpo = cabecalho(bruto, nome)
        corpo = incluir(corpo, FONTES, usadas)
        conteudo = para_html(corpo)
        hash_fonte = hashlib.sha256((bruto + corpo + prog + banco).encode('utf-8')).hexdigest()[:16]
        doc = ('<!doctype html>\n<html lang="pt-BR">\n<head>\n  <meta charset="utf-8">\n'
               '  <title>' + html.escape(meta['titulo']) + '</title>\n'
               '  <meta name="gerado-por" content="api/ferramentas/montar_ajuda.py a partir de docs/ajuda_geral/' + nome + ' (NÃO EDITAR)">\n'
               '  <meta name="fonte-hash" content="' + hash_fonte + '">\n'
               '</head>\n<body>\n' + conteudo + '\n</body>\n</html>\n')
        paginas[meta['pagina'] + '.html'] = doc
        indice.append({'pagina': meta['pagina'], 'ordem': int(m.group(1)), 'titulo': meta['titulo'],
                       'resumo': meta.get('resumo', ''),
                       'busca': (meta['titulo'] + ' ' + meta.get('resumo', '') + ' ' + meta.get('palavras', '') + ' ' + texto_puro(conteudo)).lower()})
    nomes = [i['pagina'] for i in indice]
    if len(nomes) != len(set(nomes)): raise SystemExit('ERRO: nome de página repetido')
    paginas['indice.json'] = json.dumps({'versaoPrograma': prog, 'versaoBanco': banco, 'paginas': indice},
                                        ensure_ascii=False, indent=1) + '\n'
    return paginas

def main():
    conferir = '--conferir' in sys.argv
    paginas = montar()
    os.makedirs(SAIDA, exist_ok=True)
    existentes = {f for f in os.listdir(SAIDA) if f.endswith(('.html', '.json'))}
    diferentes = []
    for nome, texto in paginas.items():
        caminho = os.path.join(SAIDA, nome)
        atual = open(caminho, encoding='utf-8').read() if os.path.isfile(caminho) else None
        if atual != texto:
            diferentes.append(nome)
            if not conferir:
                open(caminho, 'w', encoding='utf-8', newline='\n').write(texto)
    sobrando = sorted(existentes - set(paginas))
    if conferir:
        if diferentes or sobrando:
            print('DESATUALIZADA: ' + ', '.join(diferentes + [s + ' (sem fonte)' for s in sobrando]))
            print('Rodar: python3 api/ferramentas/montar_ajuda.py')
            sys.exit(1)
        print('Ajuda do administrador geral em dia (' + str(len(paginas) - 1) + ' páginas).')
        return
    for s in sobrando: print('AVISO: ' + s + ' não tem mais fonte; apagar à mão.')
    print('Gerado: ' + (', '.join(diferentes) if diferentes else 'nada mudou') + ' (' + str(len(paginas) - 1) + ' páginas).')

main()
