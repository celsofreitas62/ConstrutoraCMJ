import os, sys
BASE = os.environ.get('SISTEMACMJ_SQL', '/mnt/user-data/outputs/sql')

ORDEM_02A = [
    'objetos/_GERAL/Schemas.sql',
    'objetos/SIS/SIS.Modulo.sql',
    'objetos/SIS/SIS.Log_Erro.sql',
    'objetos/SIS/SIS.Log_Passo.sql',
    'objetos/SIS/SIS.Parametro.sql',
    'objetos/SIS/SIS.fn_SIS_Usuario_Atual.sql',
    'objetos/SIS/SIS.fn_SIS_Parametro.sql',
    'objetos/SIS/SIS.fn_SIS_Parametro_Inteiro.sql',
    'objetos/SIS/SIS.fn_SIS_Parametro_Decimal.sql',
    'objetos/SIS/SIS.fn_SIS_Parametro_SN.sql',
    'objetos/SIS/SIS.fn_SIS_Texto_HTML.sql',
    'objetos/SIS/SIS.fn_SIS_Formatar_Moeda.sql',
    'objetos/SIS/SIS.fn_SIS_Formatar_Data.sql',
    'objetos/SIS/SIS.fn_SIS_Formatar_Data_Hora.sql',
    'objetos/SIS/SIS.fn_SIS_Mascarar_CPF_CNPJ.sql',
    'objetos/SIS/SIS.SIS_Log_Erro_Gravar.sql',
    'objetos/SIS/SIS.SIS_Log_Erro_Listar.sql',
    'objetos/SIS/SIS.SIS_Parametro_Listar.sql',
    'objetos/SIS/SIS.SIS_Parametro_Gravar.sql',
    'objetos/SIS/SIS.SIS_Log_Limpar_Processar.sql',
    'objetos/SIS/Carga_SIS_Modulo.sql',
    'objetos/SIS/Carga_SIS_Parametro.sql',
]

def ler(p):
    t = open(os.path.join(BASE, p), encoding='utf-8-sig').read()
    return t.replace('\r\n', '\n')

def gravar(p, texto):
    texto = texto.replace('\r\n', '\n').rstrip('\n') + '\n'
    texto = texto.replace('\n', '\r\n')
    ascii_puro = all(ord(c) < 128 for c in texto)
    dados = texto.encode('utf-8')
    if not ascii_puro:
        dados = b'\xef\xbb\xbf' + dados
    open(os.path.join(BASE, p), 'wb').write(dados)

ORDEM_02B = [
    'objetos/SIS/SIS.Licenca.sql', 'objetos/SIS/SIS.Licenca_Empresa.sql', 'objetos/SIS/SIS.Item.sql', 'objetos/SIS/SIS.Acao.sql',
    'objetos/SIS/SIS.Item_Acao.sql', 'objetos/SIS/SIS.Perfil.sql', 'objetos/SIS/SIS.Perfil_Permissao.sql', 'objetos/SIS/SIS.Usuario.sql',
    'objetos/SIS/SIS.Usuario_Permissao.sql', 'objetos/SIS/SIS.Sessao.sql', 'objetos/SIS/SIS.Login_Log.sql',
    'objetos/SIS/SIS.vw_SIS_Permissao_Efetiva.sql',
    'objetos/SIS/SIS.fn_SIS_Usuario_Login.sql', 'objetos/SIS/SIS.fn_SIS_Usuario_Nivel_Admin.sql', 'objetos/SIS/SIS.fn_SIS_Tem_Permissao.sql',
    'objetos/SIS/SIS.fn_SIS_Empresa_Razao_Social.sql', 'objetos/SIS/SIS.fn_SIS_Empresa_CNPJ.sql',
    'objetos/SIS/SIS.SIS_Licenca_Modulos_Aplicar.sql', 'objetos/SIS/SIS.SIS_Licenca_Gravar.sql', 'objetos/SIS/SIS.SIS_Licenca_Obter.sql',
    'objetos/SIS/SIS.SIS_Usuario_Login_Obter.sql', 'objetos/SIS/SIS.SIS_Usuario_Login_Processar.sql',
    'objetos/SIS/SIS.SIS_Sessao_Validar.sql', 'objetos/SIS/SIS.SIS_Sessao_Encerrar.sql',
    'objetos/SIS/SIS.SIS_Usuario_Listar.sql', 'objetos/SIS/SIS.SIS_Usuario_Obter.sql', 'objetos/SIS/SIS.SIS_Usuario_Gravar.sql',
    'objetos/SIS/SIS.SIS_Usuario_Senha_Gravar.sql', 'objetos/SIS/SIS.SIS_Usuario_Desbloquear.sql',
    'objetos/SIS/SIS.SIS_Perfil_Listar.sql', 'objetos/SIS/SIS.SIS_Perfil_Gravar.sql',
    'objetos/SIS/SIS.SIS_Permissao_Listar.sql', 'objetos/SIS/SIS.SIS_Permissao_Gravar.sql', 'objetos/SIS/SIS.SIS_Menu_Listar.sql',
    'objetos/SIS/SIS.SIS_Log_Erro_Listar.sql', 'objetos/SIS/SIS.SIS_Parametro_Listar.sql', 'objetos/SIS/SIS.SIS_Parametro_Gravar.sql',
    'objetos/SIS/Carga_SIS_Parametro.sql', 'objetos/SIS/Carga_SIS_Acao.sql', 'objetos/SIS/Carga_SIS_Item.sql',
    'objetos/SIS/Carga_SIS_Perfil_Usuario.sql', 'objetos/SIS/Carga_SIS_Finalizar.sql',
]
ORDEM_02B2 = ['objetos/SIS/SIS.Parametro.sql', 'objetos/SIS/SIS.Usuario.sql', 'objetos/SIS/SIS.fn_SIS_Parametro_Cor.sql',
              'objetos/SIS/SIS.SIS_Parametro_Gravar.sql', 'objetos/SIS/SIS.SIS_Usuario_Gravar.sql', 'objetos/SIS/Carga_SIS_Parametro.sql']
ORDEM_02C = [
    'objetos/SIS/SIS.Modulo.sql', 'objetos/SIS/SIS.Item.sql',
    'objetos/SIS/SIS.Auditoria.sql', 'objetos/SIS/SIS.Lote.sql', 'objetos/SIS/SIS.Anexo_Tipo.sql', 'objetos/SIS/SIS.Anexo.sql',
    'objetos/SIS/SIS.vw_SIS_Permissao_Efetiva.sql',
    'objetos/SIS/SIS.fn_SIS_Item_Tem_Tabela.sql',
    'objetos/SIS/SIS.SIS_Contexto_Gravar.sql', 'objetos/SIS/SIS.SIS_Auditoria_Trigger_Gerar.sql',
    'objetos/SIS/SIS.SIS_Auditoria_Registro_Listar.sql', 'objetos/SIS/SIS.SIS_Auditoria_Listar.sql',
    'objetos/SIS/SIS.SIS_Lote_Gerar.sql', 'objetos/SIS/SIS.SIS_Lote_Concluir.sql', 'objetos/SIS/SIS.SIS_Lote_Listar.sql',
    'objetos/SIS/SIS.SIS_Anexo_Gravar.sql', 'objetos/SIS/SIS.SIS_Anexo_Listar.sql', 'objetos/SIS/SIS.SIS_Anexo_Obter.sql', 'objetos/SIS/SIS.SIS_Anexo_Excluir.sql',
    'objetos/SIS/SIS.SIS_Modulo_Listar.sql', 'objetos/SIS/SIS.SIS_Habilitacao_Gravar.sql',
    'objetos/SIS/SIS.tg_SIS_Auditoria_Protecao.sql',
    'objetos/SIS/Carga_SIS_Modulo.sql', 'objetos/SIS/Carga_SIS_Item.sql', 'objetos/SIS/Carga_SIS_Anexo_Tipo.sql',
    'objetos/SIS/Carga_SIS_Auditoria_Triggers.sql',
]
ORDEM_02D = [
    'objetos/_GERAL/Schemas.sql',
    'objetos/SIS/Carga_SIS_Modulo.sql', 'objetos/SIS/Carga_SIS_Acao.sql', 'objetos/SIS/Carga_SIS_Parametro.sql',
    'objetos/SIS/SIS.Grupo_Email.sql', 'objetos/SIS/SIS.Grupo_Email_Destinatario.sql',
    'objetos/SIS/SIS.Email_Fila.sql', 'objetos/SIS/SIS.Email_Fila_Anexo.sql', 'objetos/SIS/SIS.Email_Log.sql',
    'objetos/SIS/SIS.Rotina.sql', 'objetos/SIS/SIS.Rotina_Execucao.sql',
    'objetos/SIS/SIS.Comando.sql', 'objetos/SIS/SIS.Comando_Fila.sql',
    'objetos/SIS/SIS.fn_SIS_Email_Valido.sql', 'objetos/SIS/SIS.fn_SIS_Emails_Do_Grupo.sql',
    'objetos/SIS/SIS.fn_SIS_Filtrar_Emails_Por_Dominio.sql', 'objetos/SIS/SIS.fn_SIS_Email_HTML.sql',
    'objetos/SIS/SIS.fn_SIS_Rotina_Proxima.sql',
    'objetos/SIS/SIS.SIS_Email_Enfileirar.sql', 'objetos/SIS/SIS.SIS_Email_Capturar.sql', 'objetos/SIS/SIS.SIS_Email_Resultado_Gravar.sql',
    'objetos/SIS/SIS.SIS_Email_Presos_Liberar.sql', 'objetos/SIS/SIS.SIS_Email_Listar.sql', 'objetos/SIS/SIS.SIS_Email_Obter.sql',
    'objetos/SIS/SIS.SIS_Email_Situacao_Gravar.sql',
    'objetos/SIS/SIS.SIS_Grupo_Email_Listar.sql', 'objetos/SIS/SIS.SIS_Grupo_Email_Gravar.sql',
    'objetos/SIS/SIS.SIS_Rotina_Processar.sql', 'objetos/SIS/SIS.SIS_Rotina_Listar.sql', 'objetos/SIS/SIS.SIS_Rotina_Gravar.sql',
    'objetos/SIS/SIS.SIS_Rotina_Executar_Agora.sql', 'objetos/SIS/SIS.SIS_Rotina_Execucao_Listar.sql',
    'objetos/SIS/SIS.SIS_Comando_Listar.sql', 'objetos/SIS/SIS.SIS_Comando_Solicitar.sql', 'objetos/SIS/SIS.SIS_Comando_Cancelar.sql',
    'objetos/SIS/SIS.SIS_Comando_Fila_Listar.sql', 'objetos/SIS/SIS.SIS_Comando_Capturar.sql', 'objetos/SIS/SIS.SIS_Comando_Resultado_Gravar.sql',
    'objetos/SIS/Carga_SIS_Item.sql', 'objetos/SIS/Carga_SIS_Rotina.sql', 'objetos/SIS/Carga_SIS_Comando.sql',
    'objetos/SIS/Carga_SIS_Auditoria_Triggers.sql',
    'objetos/SIS/SIS.rl_sistemacmj_api.sql',
]
ORDEM_03A = [
    'objetos/BANCO/BANCO.Banco.sql', 'objetos/CAD/CAD.Empresa.sql', 'objetos/BANCO/BANCO.Conta.sql', 'objetos/CAD/CAD.FK_Conta_Padrao.sql',
    'objetos/CAD/CAD.Centro_Custo.sql', 'objetos/CAD/CAD.Pessoa.sql', 'objetos/CAD/CAD.Pessoa_Contato.sql', 'objetos/CAD/CAD.Pessoa_Vinculo.sql',
    'objetos/CAD/CAD.Pessoa_Dado_Bancario.sql', 'objetos/CAD/CAD.Plano_Grupo.sql', 'objetos/CAD/CAD.Plano_Subgrupo.sql', 'objetos/CAD/CAD.Plano_Conta.sql',
    'objetos/CAD/CAD.fn_CAD_Somente_Digitos.sql', 'objetos/CAD/CAD.fn_CAD_Documento_Limpo.sql', 'objetos/CAD/CAD.fn_CAD_Documento_Valido.sql',
    'objetos/CAD/CAD.vw_CAD_Plano_Conta.sql',
    'objetos/BANCO/BANCO.BANCO_Banco_Listar.sql', 'objetos/BANCO/BANCO.BANCO_Banco_Gravar.sql',
    'objetos/BANCO/BANCO.BANCO_Conta_Listar.sql', 'objetos/BANCO/BANCO.BANCO_Conta_Gravar.sql', 'objetos/BANCO/BANCO.BANCO_Conta_Excluir.sql',
    'objetos/CAD/CAD.CAD_Empresa_Listar.sql', 'objetos/CAD/CAD.CAD_Empresa_Gravar.sql', 'objetos/CAD/CAD.CAD_Empresa_Excluir.sql',
    'objetos/CAD/CAD.CAD_Centro_Custo_Listar.sql', 'objetos/CAD/CAD.CAD_Centro_Custo_Gravar.sql', 'objetos/CAD/CAD.CAD_Centro_Custo_Excluir.sql',
    'objetos/CAD/CAD.CAD_Pessoa_Listar.sql', 'objetos/CAD/CAD.CAD_Pessoa_Obter.sql', 'objetos/CAD/CAD.CAD_Pessoa_Gravar.sql', 'objetos/CAD/CAD.CAD_Pessoa_Excluir.sql',
    'objetos/CAD/CAD.CAD_Plano_Conta_Listar.sql', 'objetos/CAD/CAD.CAD_Plano_Grupo_Gravar.sql', 'objetos/CAD/CAD.CAD_Plano_Subgrupo_Gravar.sql',
    'objetos/CAD/CAD.CAD_Plano_Conta_Gravar.sql', 'objetos/CAD/CAD.CAD_Plano_Excluir.sql',
    'objetos/SIS/SIS.SIS_Rotina_Executar_Agora.sql',
    'objetos/BANCO/Carga_BANCO_Banco.sql', 'objetos/CAD/Carga_CAD_Item.sql', 'objetos/CAD/Carga_CAD_Auditoria_Triggers.sql',
]
ORDEM_03C = [
    'objetos/CAD/CAD.Empresa_Pasta_OFX.sql',
    'objetos/SIS/Carga_SIS_Parametro.sql', 'objetos/SIS/SIS.SIS_Email_Enfileirar.sql',
    'objetos/SIS/SIS.fn_SIS_Email_HTML.sql', 'objetos/SIS/SIS.SIS_Email_Resultado_Gravar.sql',
    'objetos/FIN/FIN.Historico_Padrao.sql', 'objetos/FIN/FIN.Mes_Fechado.sql',
    'objetos/BANCO/BANCO.Extrato_Arquivo.sql', 'objetos/BANCO/BANCO.Extrato_Linha.sql',
    'objetos/FIN/FIN.Transferencia.sql', 'objetos/BANCO/BANCO.Movimento.sql',
    'objetos/FIN/FIN.Lancamento.sql', 'objetos/FIN/FIN.Parcela.sql', 'objetos/FIN/FIN.Baixa.sql',
    'objetos/FIN/FIN.Arquivo_Morto.sql',
    'objetos/SIS/SIS.Comunicado.sql', 'objetos/SIS/SIS.Comunicado_Item.sql', 'objetos/SIS/SIS.Comunicado_Edicao.sql',
    'objetos/SIS/SIS.fn_SIS_Comunicado_Conteudo.sql',
    'objetos/FIN/FIN.FIN_Arquivo_Morto_Listar.sql',
    'objetos/SIS/SIS.SIS_Comunicado_Previa_Gerar.sql', 'objetos/SIS/SIS.SIS_Comunicado_Previa_Processar.sql',
    'objetos/SIS/SIS.SIS_Comunicado_Obter.sql', 'objetos/SIS/SIS.SIS_Comunicado_Edicao_Obter.sql',
    'objetos/SIS/SIS.SIS_Comunicado_Gravar.sql', 'objetos/SIS/SIS.SIS_Comunicado_Edicao_Aprovar.sql',
    'objetos/SIS/SIS.SIS_Comunicado_Edicao_Descartar.sql',
    'objetos/FIN/FIN.tg_FIN_Baixa_Saldo.sql',
    'objetos/FIN/Carga_FIN_Item.sql', 'objetos/SIS/Carga_SIS_Comunicado.sql', 'objetos/FIN/Carga_FIN_Auditoria_Triggers.sql',
]
ORDEM_03C_MIG = [
    'objetos/MIG/MIG.Tabelas_Access.sql', 'objetos/MIG/MIG.MIG_Carga_Processar.sql',
    'objetos/MIG/MIG.MIG_Movimento_Preparar.sql', 'objetos/MIG/MIG.MIG_Arquivo_Morto_Processar.sql',
    'objetos/MIG/MIG.MIG_Conferencia_Listar.sql',
]
ORDEM_03C2 = [
    'objetos/CAD/CAD.Empresa.sql', 'objetos/CAD/CAD.CAD_Empresa_Listar.sql', 'objetos/CAD/CAD.CAD_Empresa_Gravar.sql',
    'objetos/CAD/Carga_CAD_Auditoria_Triggers.sql',
    'objetos/MIG/MIG.Tabelas_Cadastros.sql', 'objetos/MIG/MIG.fn_MIG_Plano_Desmontar.sql',
    'objetos/MIG/MIG.MIG_Cadastros_Processar.sql', 'objetos/MIG/MIG.MIG_Cadastros_Conferencia_Listar.sql',
    'objetos/MIG/Carga_MIG_Classificacao.sql',
]
ORDEM_03C2B = [
    'objetos/SIS/SIS.SIS_Auditoria_Trigger_Gerar.sql', 'objetos/SIS/Carga_SIS_Auditoria_Triggers.sql', 'objetos/SIS/Carga_SIS_Comunicado.sql',
    'objetos/CAD/Carga_CAD_Auditoria_Triggers.sql', 'objetos/FIN/Carga_FIN_Auditoria_Triggers.sql',
    'objetos/MIG/MIG.Tabelas_Transformacao.sql', 'objetos/MIG/MIG.fn_MIG_Hash_Unidade.sql', 'objetos/MIG/MIG.vw_MIG_Linha_Unidade.sql', 'objetos/MIG/MIG.fn_MIG_Linhas_Documento.sql', 'objetos/MIG/MIG.MIG_Movimento_Transformar.sql',
    'objetos/MIG/MIG.MIG_Movimento_Conferencia_Listar.sql',
    'objetos/MIG/MIG.MIG_Caso_Listar.sql', 'objetos/MIG/MIG.MIG_Caso_Obter.sql', 'objetos/MIG/MIG.MIG_Caso_Opcoes.sql',
    'objetos/MIG/MIG.MIG_Caso_Gravar.sql', 'objetos/MIG/MIG.MIG_Caso_Conferir.sql', 'objetos/MIG/MIG.MIG_Caso_Lote_Gravar.sql', 'objetos/MIG/MIG.MIG_Caso_Correcao_Exportar.sql', 'objetos/MIG/Carga_MIG_Tela_Casos.sql',
    'objetos/MIG/MIG.MIG_Arquivo_Morto_Processar.sql',
]
ORDEM_03D = ['objetos/SIS/SIS.fn_SIS_Email_HTML.sql', 'objetos/SIS/Carga_SIS_Parametro.sql',
             'objetos/SIS/SIS.Login_Log.sql', 'objetos/SIS/SIS.SIS_Usuario_Login_Processar.sql',
             'objetos/SIS/SIS.Versao_Banco.sql', 'objetos/SIS/SIS.fn_SIS_Versao_Banco.sql',
             'objetos/SIS/SIS.SIS_Instalacao_Situacao.sql', 'objetos/SIS/SIS.SIS_Instalacao_Senha_Gravar.sql',
             'objetos/SIS/SIS.SIS_Registro_Existe.sql', 'objetos/SIS/SIS.SIS_Anexo_Gravar.sql',
             'objetos/SIS/Carga_SIS_Versao.sql']
PARTE = sys.argv[1] if len(sys.argv) > 1 else '02a'
ORDEM = {'02a': ORDEM_02A, '02b': ORDEM_02B, '02b2': ORDEM_02B2, '02c': ORDEM_02C, '02d': ORDEM_02D, '03a': ORDEM_03A, '03c': ORDEM_03C, '03c_mig': ORDEM_03C_MIG, '03c2': ORDEM_03C2, '03c2b': ORDEM_03C2B, '03d': ORDEM_03D}[PARTE]
TITULO = {'03d': '03d - ajustes da base SIS na etapa 03d (rodapé dos e-mails sem CNPJ, limite de login por computador, versão do banco)',
          '02a': '02a - base SIS (schemas, logs, parâmetros, functions de formatação)',
          '02b': '02b - base SIS (licença, usuários, perfis, permissões, sessão, menu, dois níveis de administrador)',
          '02b2': '02b2 - ajuste da base SIS: identidade visual por cliente (logomarcas e cores) e correção de nomes com "_"',
          '02c': '02c - base SIS (habilitação de módulo e tela, contexto, auditoria, lote, anexo)',
          '02d': '02d - base SIS (e-mail, agenda das rotinas, comandos de instalação, papel da API, módulo Compras)',
          '03a': '03a - cadastros (CAD: empresas, pessoas, centros de custo, plano de contas) e cadastro do BANCO (bancos e contas)',
          '03c2': '03c2 - migração dos cadastros: CNPJ para notas de compra e DDA na empresa (CAD, vai para o MASTER) e classificação, de-paras e carga dos cadastros do Access (schema MIG, NÃO vai para o MASTER)',
          '03c2b': '03c2 parte B - auditoria rápida em carga grande (SIS_Auditoria_Trigger_Gerar v1.1, vai para o MASTER) e transformação, tela de casos do movimento do Access em lançamento, parcela, baixa, movimento e transferência; casos e correções (schema MIG, NÃO vai para o MASTER)',
          '03c_mig': '03c - ensaio da migração do movimento (schema MIG: carga crua do Access, classificação, arquivo morto, conferência). NÃO vai para o MASTER',
          '03c': '03c - financeiro (FIN: lançamento, parcela, baixa, transferência, fechamento de mês, arquivo morto), movimento e extrato do BANCO, boletim semanal (comunicados)'}[PARTE]
# pacote
cab = """/*******************************************************************************
  Pacote      : """ + TITULO + """
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : """ + __import__('datetime').date.today().strftime('%d/%m/%Y') + """ pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: """ + {'02a': 'sql/local/00_SISTEMACMJ_LOCAL_Criar_Banco.sql já rodado.', '02b': 'pacote 02a já rodado.', '02b2': 'pacotes 02a e 02b já rodados.', '02c': 'pacotes 02a, 02b e 02b2 já rodados.', '02d': 'pacotes 02a, 02b, 02b2 e 02c já rodados.', '03a': 'pacotes 02a a 02d já rodados.', '03c': 'pacotes 02a a 02d e 03a já rodados.', '03c_mig': 'pacote 03c já rodado; CSV do Access na pasta legado/dados_brutos.', '03c2': 'pacotes 03c e 03c_mig já rodados.', '03c2b': 'pacote 03c2 e sql/local/03c2_Migracao_Cadastros_LOCAL.sql já rodados.', '03d': 'pacotes 02a a 03c2b já rodados.'}[PARTE] + """
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : """ + {'03d': 'enviar um comunicado de teste e conferir o rodapé sem CNPJ.', '02a': 'rodar sql/testes/SIS/02a_Homologacao_SIS.sql.', '02b': 'rodar sql/testes/SIS/02b_Homologacao_SIS.sql e depois\n                sql/testes/SIS/02a_Homologacao_SIS.sql (v1.1).', '02b2': 'rodar sql/testes/SIS/02b2_Homologacao_SIS.sql.', '02c': 'rodar sql/testes/SIS/02c_Homologacao_SIS.sql e depois\n                02b_Homologacao_SIS.sql (v1.2), para conferir que nada quebrou.',
          '02d': 'rodar sql/testes/SIS/02d_Homologacao_SIS.sql e depois\n                02c_Homologacao_SIS.sql (v1.3) e 02b_Homologacao_SIS.sql.',
          '03a': 'rodar sql/testes/CAD/03a_Homologacao_CAD.sql e depois\n                02d, 02c e 02b, para conferir que nada quebrou.',
          '03c_mig': 'rodar sql/local/03c_Ensaio_Migracao_LOCAL.sql.',
          '03c2b': 'rodar sql/local/03c2b_Migracao_Movimento_LOCAL.sql.',
          '03c2': 'rodar sql/testes/CAD/03c2_Homologacao_CAD.sql e 03a_Homologacao_CAD.sql;\n                depois sql/local/03c2_Migracao_Cadastros_LOCAL.sql.',
          '03c': 'rodar sql/testes/FIN/03c_Homologacao_FIN.sql e depois\n                03a e 02d, para conferir que nada quebrou.'}[PARTE] + """
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
"""
partes = [cab]
for p in ORDEM:
    partes.append('\n-- =============================================================================\n-- Arquivo: sql/' + p + '\n-- =============================================================================\n')
    partes.append(ler(p).rstrip('\n') + '\n')
partes.append("\nPRINT N'Pacote " + PARTE + " concluído sem erro.';\nGO\n\nSET NOEXEC OFF;\nGO\n")

for root, _, files in os.walk(BASE):
    for f in files:
        if f.endswith('.sql'):
            rel = os.path.relpath(os.path.join(root, f), BASE)
            if rel.startswith('pacotes'): continue
            gravar(rel, ler(rel))
gravar('pacotes/' + PARTE + ('_SIS' if (PARTE.startswith('02') or PARTE == '03d') else ('_FIN' if PARTE == '03c' else ('' if PARTE == '03c_mig' else ('_mig' if PARTE in ('03c2', '03c2b') else '_CAD')))) + '_LOCAL.sql', ''.join(partes))

# conferência
for root, _, files in os.walk(BASE):
    for f in sorted(files):
        if not f.endswith('.sql'): continue
        b = open(os.path.join(root, f), 'rb').read()
        bom = b.startswith(b'\xef\xbb\xbf')
        lf_solto = b.replace(b'\r\n', b'').count(b'\n')
        cr_solto = b.replace(b'\r\n', b'').count(b'\r')
        asc = all(x < 128 for x in b[3:] if bom) if bom else all(x < 128 for x in b)
        ok = lf_solto == 0 and cr_solto == 0 and (bom != asc or (not bom and asc))
        print(('OK ' if ok else 'ERRO ') + os.path.relpath(os.path.join(root, f), BASE), 'BOM' if bom else 'sem BOM', len(b))
