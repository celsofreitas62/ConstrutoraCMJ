# SistemaCMJ - monta sql/MASTER/SISTEMACMJ_MASTER_Instalacao.sql (PADRAO_SQL regras 58 a 60)
# Autor: Celso de Freitas / Refatorado: Claude
# v1.0 (20/11/2026) - Criacao (etapa 03d).
# v1.1 (20/11/2026) - Versao lida de Carga_SIS_Versao.sql, que vai por ultimo. Junta os arquivos de sql/objetos que ja
#                     passaram pelos pacotes homologados, sem o schema MIG, na ordem
#                     da regra 59; dentro de cada parte, a ordem dos pacotes.
# v1.2 (22/11/2026) - Etapa 03g: pacote 03g (ajuda do administrador geral; banco 1.7).
# v1.3 (22/11/2026) - Etapa 03h: pacote 03h (atualizacao em um clique; banco 1.8).
# v1.4 (22/11/2026) - Etapa 04a: pacote 04a (telas de Usuarios e Perfis; banco 1.9).
# Uso: python3 sql/ferramentas/montar_master.py   (SISTEMACMJ_SQL = pasta sql)
import os, re, datetime
BASE = os.environ.get('SISTEMACMJ_SQL', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
# A versao do banco vem de Carga_SIS_Versao.sql (fonte unica).
VERSAO = re.search(r"@Versao\s+VARCHAR\(20\)\s*=\s*'([0-9.]+)'", open(os.path.join(BASE, 'objetos', 'SIS', 'Carga_SIS_Versao.sql'), encoding='utf-8-sig').read()).group(1)
src = open(os.path.join(BASE, 'ferramentas', 'montar_pacote.py'), encoding='utf-8').read()
ns = {}
exec(src.split('PARTE = sys.argv')[0], ns)
PACOTES = ['ORDEM_02A', 'ORDEM_02B', 'ORDEM_02B2', 'ORDEM_02C', 'ORDEM_02D', 'ORDEM_03A', 'ORDEM_03C', 'ORDEM_03C2', 'ORDEM_03C2B', 'ORDEM_03D', 'ORDEM_03G', 'ORDEM_03H', 'ORDEM_04A']
ordem = []
for k in PACOTES:
    for f in ns[k]:
        if f not in ordem and '/MIG/' not in f:
            ordem.append(f)

def ler(p):
    return open(os.path.join(BASE, p), encoding='utf-8-sig').read().replace('\r\n', '\n')

ESPECIAL = {'objetos/CAD/CAD.Empresa_Pasta_OFX.sql': 3, 'objetos/CAD/CAD.FK_Conta_Padrao.sql': 3,
            'objetos/SIS/SIS.rl_sistemacmj_api.sql': 8.5, 'objetos/SIS/Carga_SIS_Finalizar.sql': 9.9,
            'objetos/SIS/Carga_SIS_Versao.sql': 9.95}
def parte(f):
    if f in ESPECIAL: return ESPECIAL[f]
    n = os.path.basename(f); t = ler(f)
    if n == 'Schemas.sql': return 2
    if n.startswith('Carga_'): return 9
    if re.search(r'CREATE\s+(OR\s+ALTER\s+)?PROC', t, re.I): return 7
    if re.search(r'CREATE\s+(OR\s+ALTER\s+)?TRIGGER', t, re.I): return 8
    if re.search(r'CREATE\s+(OR\s+ALTER\s+)?VIEW', t, re.I): return 6
    if re.search(r'CREATE\s+(OR\s+ALTER\s+)?FUNCTION', t, re.I): return 5
    if re.search(r'CREATE\s+SEQUENCE', t, re.I) and not re.search(r'CREATE\s+TABLE', t, re.I): return 4
    if re.search(r'CREATE\s+TABLE', t, re.I): return 3
    raise SystemExit('Nao sei classificar: ' + f)

NOMES = {2: '2. SCHEMAS', 3: '3. TABELAS E RESTRICOES', 4: '4. SEQUENCES', 5: '5. FUNCTIONS', 6: '6. VIEWS',
         7: '7. PROCEDURES', 8: '8. TRIGGERS', 8.5: '8b. SEGURANCA (papel da API)', 9: '9. PARAMETROS E CARGA INICIAL',
         9.9: '9. (fim) FINALIZACAO DA INSTALACAO', 9.95: '9. (fim) REGISTRO DA VERSAO DO BANCO'}
grupos = {}
for f in ordem:
    grupos.setdefault(parte(f), []).append(f)

hoje = datetime.date.today().strftime('%d/%m/%Y')
cab = """/*******************************************************************************
  Arquivo     : SISTEMACMJ_MASTER_Instalacao.sql   (MASTER v""" + VERSAO + """)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Gerado em   : """ + hoje + """ por sql/ferramentas/montar_master.py, juntando os
                arquivos de sql/objetos aprovados (pacotes 02a a 03g), sem o schema
                MIG (regra 60). NAO EDITAR ESTE ARQUIVO: corrigir o arquivo do
                objeto e gerar o MASTER de novo.
  Descricao   : Instala (ou atualiza) TODO o banco do SisCMJ no servidor do
                cliente, de uma vez (PADRAO_SQL regras 58 a 60). Idempotente:
                roda de novo sem erro e sem perder dado.
  Ordem       : 1) conferencia do banco, 2) schemas, 3) tabelas e restricoes,
                4) sequences, 5) functions, 6) views, 7) procedures,
                8) triggers, 8b) seguranca, 9) parametros e carga inicial.
  Banco       : SISTEMACMJ (o banco ja tem de existir:
                sql/MASTER/SISTEMACMJ_00_Criar_Banco.sql).
  Depois      : criar o login da API e colocar o usuario no papel
                rl_sistemacmj_api (roteiro de instalacao; a senha nao fica em
                arquivo).
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > conferir o banco > F5.
  Objetos     : """ + str(len(ordem)) + """ arquivos.
*******************************************************************************/
"""
partes = [cab, """-- =============================================================================
-- 1. CONFERENCIA DO BANCO
-- =============================================================================
IF DB_NAME() <> N'SISTEMACMJ'
BEGIN
    RAISERROR(N'Banco errado: o MASTER so roda no banco SISTEMACMJ. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
PRINT N'MASTER v""" + VERSAO + """: inicio da instalacao em ' + DB_NAME() + N' (' + CONVERT(NVARCHAR(30), SYSDATETIME(), 120) + N').';
GO
"""]
for p in sorted(grupos):
    partes.append('\n-- =============================================================================\n-- ' + NOMES[p] + '\n-- =============================================================================\n')
    partes.append("PRINT N'" + NOMES[p] + "';\nGO\n")
    for f in grupos[p]:
        partes.append('\n-- -----------------------------------------------------------------------------\n-- Arquivo: sql/' + f + '\n-- -----------------------------------------------------------------------------\n')
        partes.append(ler(f).rstrip('\n') + '\nGO\n')
partes.append("\nPRINT N'MASTER v" + VERSAO + " concluido sem erro.';\nGO\n\nSET NOEXEC OFF;\nGO\n")
texto = ''.join(partes).replace('\n', '\r\n')
os.makedirs(os.path.join(BASE, 'MASTER'), exist_ok=True)
dados = texto.encode('utf-8')
if any(ord(c) > 127 for c in texto): dados = b'\xef\xbb\xbf' + dados
open(os.path.join(BASE, 'MASTER', 'SISTEMACMJ_MASTER_Instalacao.sql'), 'wb').write(dados)
for p in sorted(grupos): print(NOMES[p], len(grupos[p]))
print('total', len(ordem))
