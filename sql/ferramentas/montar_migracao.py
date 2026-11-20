# SistemaCMJ - monta sql/MASTER/SISTEMACMJ_MIGRACAO_Instalacao.sql
# Autor: Celso de Freitas / Refatorado: Claude
# v1.0 (20/11/2026) - Criacao (etapa 03d, decisao do Celso: o MIG nao entra no
#                     MASTER, vai num arquivo proprio para o servidor, rodado na
#                     virada e removido depois). Junta so os arquivos de
#                     sql/objetos/MIG, na ordem dos pacotes homologados.
#                     MIG.Movimento e criada pela MIG_Movimento_Preparar (SELECT INTO);
#                     em banco novo ela ainda nao existe: antes da view e da function
#                     que a leem, roda a preparacao (com as tabelas do Access vazias
#                     so cria a estrutura; em reinstalacao refaz a partir do Access).
# Uso: python3 sql/ferramentas/montar_migracao.py   (SISTEMACMJ_SQL = pasta sql)
import os, datetime
BASE = os.environ.get('SISTEMACMJ_SQL', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
VERSAO = '1.0'
src = open(os.path.join(BASE, 'ferramentas', 'montar_pacote.py'), encoding='utf-8').read()
ns = {}
exec(src.split('PARTE = sys.argv')[0], ns)
ordem = []
for k in ['ORDEM_03C_MIG', 'ORDEM_03C2', 'ORDEM_03C2B']:
    for f in ns[k]:
        if '/MIG/' in f and f not in ordem:
            ordem.append(f)
def ler(p):
    return open(os.path.join(BASE, p), encoding='utf-8-sig').read().replace('\r\n', '\n')
hoje = datetime.date.today().strftime('%d/%m/%Y')
cab = """/*******************************************************************************
  Arquivo     : SISTEMACMJ_MIGRACAO_Instalacao.sql   (MIGRACAO v""" + VERSAO + """)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Gerado em   : """ + hoje + """ por sql/ferramentas/montar_migracao.py, juntando
                os arquivos de sql/objetos/MIG dos pacotes homologados (03c_mig,
                03c2 e 03c2b). NAO EDITAR: corrigir o arquivo do objeto e gerar de
                novo.
  Descricao   : Instala no servidor o schema MIG (migracao do Access): tabelas de
                carga crua, classificacao, transformacao, tela "Casos da
                migracao" e arquivo morto. Fica FORA do MASTER (PADRAO_SQL regra
                60): roda so na virada e e removido depois que a migracao e os
                casos resolvidos terminarem. Idempotente.
  Pre-requisito: banco SISTEMACMJ com o MASTER ja rodado.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > conferir o banco > F5.
  Objetos     : """ + str(len(ordem)) + """ arquivos.
*******************************************************************************/
"""
partes = [cab, """IF DB_NAME() <> N'SISTEMACMJ'
BEGIN
    RAISERROR(N'Banco errado: a migracao so e instalada no banco SISTEMACMJ. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
IF OBJECT_ID(N'SIS.Modulo') IS NULL OR OBJECT_ID(N'FIN.Lancamento') IS NULL
BEGIN
    RAISERROR(N'O MASTER ainda nao foi rodado neste banco. Rode o SISTEMACMJ_MASTER_Instalacao.sql primeiro. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
PRINT N'MIGRACAO v""" + VERSAO + """: inicio em ' + DB_NAME() + N' (' + CONVERT(NVARCHAR(30), SYSDATETIME(), 120) + N').';
GO
"""]
PASSO_MOVIMENTO = """
-- -----------------------------------------------------------------------------
-- Estrutura de MIG.Movimento (criada pela MIG_Movimento_Preparar): necessaria
-- para a view e a function a seguir. Banco novo: so a estrutura, vazia.
-- -----------------------------------------------------------------------------
IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
BEGIN
    PRINT N'MIG.Movimento ainda nao existe: rodando MIG.MIG_Movimento_Preparar para criar a estrutura.';
    EXEC MIG.MIG_Movimento_Preparar;
END;
GO
"""
for f in ordem:
    if f.endswith('MIG.vw_MIG_Linha_Unidade.sql'):
        partes.append(PASSO_MOVIMENTO)
    partes.append('\n-- -----------------------------------------------------------------------------\n-- Arquivo: sql/' + f + '\n-- -----------------------------------------------------------------------------\n')
    partes.append(ler(f).rstrip('\n') + '\nGO\n')
partes.append("\nPRINT N'MIGRACAO v" + VERSAO + " concluida sem erro.';\nGO\n\nSET NOEXEC OFF;\nGO\n")
texto = ''.join(partes).replace('\n', '\r\n')
dados = texto.encode('utf-8')
if any(ord(c) > 127 for c in texto): dados = b'\xef\xbb\xbf' + dados
open(os.path.join(BASE, 'MASTER', 'SISTEMACMJ_MIGRACAO_Instalacao.sql'), 'wb').write(dados)
print('\n'.join(ordem)); print('total', len(ordem))
