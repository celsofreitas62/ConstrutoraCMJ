/*******************************************************************************
  Carga       : classificação dos cadastros do Access (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Decisões da migração dos cadastros (etapa 03c2), conferidas
                pela CMJ nos documentos de perguntas de 17/11/2026
                (docs/requisitos/Migracao_Movimento.md, seção 8, e
                docs/requisitos/Migracao_Cadastros.md). Este arquivo é a fonte
                das decisões: rodar de novo aplica as correções (MERGE).
                O que não está aqui segue a regra automática do
                MIG.MIG_Cadastros_Processar e aparece na conferência.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f: respostas da CMJ ao 3º documento
                        (docs/requisitos/Migracao_Cadastros.md, seção 6):
                        CNPJ e razão social das 4 SPEs; conta padrão da Holding
                        = Sicredi Holding; Casa Danielle e Casa 66 passam para a
                        Holding; La Sante Sala 110, Allegro 52 e Giuseppina 12
                        inativos (vendidos), Sala 113 ativa até a CMJ confirmar;
                        grupos 11 a 14 entram no custo de obra.
    v1.2 (23/11/2026) - Respostas da Renata à conferência 03f: Sala 113
                        vendida (centro inativo); a vaga vendida junto é a
                        15 (o Access dizia vaga 40; confirmado pelo Celso).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 1. Empresas (EmpMaster)
--    EMPRESA     = empresa do grupo (CAD.Empresa)
--    CONSTRUTORA = não é empresa do grupo (cliente de obra por administração,
--                  particular, estudo): as obras dela ficam na empresa principal
--    NAO_MIGRA   = registros de sistema do Access
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Empresa AS d
USING (VALUES
    ( 1, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'Master: registro do Access'),
    ( 2, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 3, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 4, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 5, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 6, 'EMPRESA',     1, 'CONSTRUTORA', N'Construtora Marcilio Judice Sociedade Empresária Ltda', N'Construtora Marcilio Judice', '25686528000197', '', '', N''),
    (21, 'EMPRESA',     0, 'SPE',         N'Ilha das Gales Incorporadora SPE Ltda',     N'Ilha das Galès',          '18757133000172', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (22, 'EMPRESA',     0, 'SPE',         N'Edifício Comercial La Sante SPE',           N'La Sante',                '21126427000100', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (23, 'EMPRESA',     0, 'SPE',         N'Judice e Daher Incorporadora e Construtora SPE Ltda', N'Villagio Allegro', '23465751000189', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (25, 'EMPRESA',     0, 'HOLDING',     N'Judice e Filhos Administração de Bens Ltda', N'Holding Judice e Filhos', '27546995000147', '', '', N''),
    (28, 'EMPRESA',     0, 'SPE',         N'MJ Incorporadora SPE Ltda',                 N'Res. Square',             '34939234000110', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (31, 'EMPRESA',     0, 'SPE',         N'Marcilio Judice Incorporadora SPE Ltda',    N'Maui',                    '36451082000138', '', 'RET', N''),
    (32, 'EMPRESA',     0, 'SPE',         N'Orion Incorporadora SPE Ltda',              N'Orion',                   '52095394000102', '', '', N'ainda sem RET'),
    (34, 'EMPRESA',     0, 'SPE',         N'Opera Residences',                          N'Opera',                   '56304064000130', '56304064000211', 'RET', N'razão social completa a confirmar; /0002-11 = CNPJ do RET (notas de compra e DDA)'),
    (35, 'EMPRESA',     0, 'SPE',         N'Music Incorporadora SPE Ltda',              N'Music',                   '68542803000101', '', '', N'ainda sem RET'),
    ( 7, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Climepe: cliente de obra por administração'),
    ( 8, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Adm. Bens Claudia: cliente de obra por administração'),
    ( 9, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Cond. Res. Vila Faria Lobato: obra a preço de custo'),
    (10, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Buenos Aires: obra a preço de custo'),
    (11, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Bolivar Zotti: cliente de obra por administração'),
    (12, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Construtora Epura: cliente de obra por administração'),
    (13, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'DMAE: cliente'),
    (14, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Fundação Jd. Botânico: cliente'),
    (15, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Cond. Res. Justino Ribeiro: cliente'),
    (16, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Carneiro Casa & Construção (reforma): cliente'),
    (17, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Giuseppina: obra a preço de custo (associação)'),
    (18, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Attualità: obra a preço de custo (associação)'),
    (19, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Luiz Henrique Costa da Cunha: cliente'),
    (20, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Carneiro Casa & Construção Ltda: cliente'),
    (24, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Adriana Granato: cliente (reforma do hotel)'),
    (26, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Res. Trix - Jd. Elvira Dias'),
    (27, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Empreendimento Country Club'),
    (29, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Novo Empreendimento Claudia Carneiro (Res. Mellia)'),
    (30, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'CADAP: cliente das obras por administração Indiara e Paladium (CMJ, 17/11/2026)'),
    (33, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Ronaldo Dellaroli: estudo de viabilidade, obra não executada (CMJ, 17/11/2026)')
) AS s (CODIGO_MASTER, DESTINO, PRINCIPAL, TIPO, RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, REGIME_TRIBUTARIO, OBSERVACAO)
ON d.CODIGO_MASTER = s.CODIGO_MASTER
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.PRINCIPAL = s.PRINCIPAL, d.TIPO = s.TIPO, d.RAZAO_SOCIAL = s.RAZAO_SOCIAL,
     d.NOME_FANTASIA = s.NOME_FANTASIA, d.CNPJ = s.CNPJ, d.CNPJ_COMPRAS = s.CNPJ_COMPRAS, d.REGIME_TRIBUTARIO = s.REGIME_TRIBUTARIO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_MASTER, DESTINO, PRINCIPAL, TIPO, RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, REGIME_TRIBUTARIO, OBSERVACAO)
     VALUES (s.CODIGO_MASTER, s.DESTINO, s.PRINCIPAL, s.TIPO, s.RAZAO_SOCIAL, s.NOME_FANTASIA, s.CNPJ, s.CNPJ_COMPRAS, s.REGIME_TRIBUTARIO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 2. Centros de custo (EmpVinculada). Campos vazios seguem a regra automática:
--    código "A" + código do Access, descrição do Access, tipo OBRA quando a
--    obra controla custo, é administração ou tem imóvel à venda.
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Centro AS d
USING (VALUES
    ( 1, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'N/A: caixinha e contrapartida do Access (cada lançamento recebe o centro pela regra do seu tipo)'),
    ( 2, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'Escolha a Empresa (sistema)'),
    ( 3, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    ( 4, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    ( 5, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    (70, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'TESTE'),
    ( 6, 'CENTRO',    'CMJ',          N'Construtora - administrativo',                     'ADMINISTRATIVO', NULL, NULL, NULL, N''),
    ( 9, 'CENTRO',    'PART-FAMILIA', N'Despesas particulares da família',                 'PARTICULAR',     6,    NULL, NULL, N'"Marco Aurelio" no Access (CMJ, 17/11/2026)'),
    (46, 'CENTRO',    '58',           N'58 - Ilha das Galès',                              'OBRA',           NULL, NULL, NULL, N''),
    (49, 'CENTRO',    '59',           N'59 - Edifício La Sante',                           'OBRA',           NULL, NULL, NULL, N''),
    (54, 'CENTRO',    '59-ANTES-SPE', N'La Sante - antes da SPE (conta 01321-7)',          'OBRA',           6,    NULL, NULL, N'controle da obra La Sante até sair a documentação da SPE (CMJ, 17/11/2026)'),
    (57, 'CENTRO',    '61',           N'61 - Villagio Allegro',                            'OBRA',           NULL, NULL, NULL, N''),
    (60, 'CENTRO',    'JD-CAROLINA',  N'Jd. Carolina - obra particular dos proprietários', 'PARTICULAR',     6,    NULL, NULL, N'CMJ, 17/11/2026'),
    (62, 'CENTRO',    'HOLDING',      N'Holding - administrativo',                         'ADMINISTRATIVO', NULL, NULL, 28  , N'conta padrão Sicredi Holding 0217/28656-3 (CMJ, 20/11/2026)'),
    (65, 'CENTRO',    '62',           N'62 - Res. Square',                                 'OBRA',           NULL, NULL, NULL, N''),
    (69, 'CENTRO',    '65',           N'65 - Res. Indiara (CADAP)',                        'OBRA',           6,    1029, NULL, N'obra por administração; cliente CADAP (CMJ, 17/11/2026)'),
    (72, 'CENTRO',    '63',           N'63 - Maui',                                        'OBRA',           NULL, NULL, NULL, N''),
    (73, 'CENTRO',    '66',           N'66 - Res. Paladium (CADAP)',                       'OBRA',           6,    1195, NULL, N'obra por administração; cliente CADAP (CMJ, 17/11/2026)'),
    (75, 'CENTRO',    '67',           N'67 - Orion',                                       'OBRA',           NULL, NULL, NULL, N''),
    (76, 'CENTRO',    'DELLAROLI',    N'Ronaldo Dellaroli - estudo de viabilidade',        'ADMINISTRATIVO', 6,    NULL, NULL, N'obra não executada (CMJ, 17/11/2026)'),
    (77, 'CENTRO',    '68',           N'68 - Opera Residences',                            'OBRA',           NULL, NULL, NULL, N''),
    (43, 'CENTRO',    '55',           N'55 - Residencial Attualità',                       'OBRA',           6,    NULL, NULL, N'obra a preço de custo (associação); 1 lançamento desde o corte'),
    (78, 'CENTRO',    '69',           N'69 - Music',                                       'OBRA',           NULL, NULL, NULL, N''),
    -- obras antigas por administração: só o cliente (o resto pela regra automática)
    (14, 'CENTRO',    '',             N'',                                                 '',               NULL, 880, NULL, N'cliente Climepe'),
    (15, 'CENTRO',    '',             N'',                                                 '',               NULL, 880, NULL, N'cliente Climepe'),
    (16, 'CENTRO',    '',             N'',                                                 '',               NULL, 623, NULL, N'cliente Adm. de Bens Claudia'),
    (22, 'CENTRO',    '',             N'',                                                 '',               NULL, 40, NULL, N'cliente DMAE'),
    (52, 'CENTRO',    '',             N'',                                                 '',               NULL, 633, NULL, N'cliente DMAE - ETA V'),
    (30, 'CENTRO',    '',             N'',                                                 '',               NULL, 607, NULL, N'cliente Cond. Res. Justino Ribeiro'),
    (35, 'CENTRO',    '',             N'',                                                 '',               NULL, 190, NULL, N'cliente Carneiro Casa & Construção'),
    (50, 'CENTRO',    '',             N'',                                                 '',               NULL, 586, NULL, N'cliente Carneiro Casa & Construção - Loja Nova'),
    (55, 'CENTRO',    '',             N'',                                                 '',               NULL, 902, NULL, N'cliente Hotel Granato')
) AS s (CODIGO_VINCULADA, DESTINO, CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, PARCEIRO_CLIENTE, CODIGO_CONTA_PADRAO, OBSERVACAO)
ON d.CODIGO_VINCULADA = s.CODIGO_VINCULADA
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.CODIGO = s.CODIGO, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO,
     d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.PARCEIRO_CLIENTE = s.PARCEIRO_CLIENTE, d.CODIGO_CONTA_PADRAO = s.CODIGO_CONTA_PADRAO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_VINCULADA, DESTINO, CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, PARCEIRO_CLIENTE, CODIGO_CONTA_PADRAO, OBSERVACAO)
     VALUES (s.CODIGO_VINCULADA, s.DESTINO, s.CODIGO, s.DESCRICAO, s.TIPO, s.CODIGO_MASTER_EMPRESA, s.PARCEIRO_CLIENTE, s.CODIGO_CONTA_PADRAO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 3. Centros que não existem no Access: imóveis próprios e particulares que lá
--    eram contas do plano (decisão do plano de contas, 16/11/2026: conta
--    genérica + imóvel pelo centro de custo). Dona: a empresa que lança.
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Centro_Extra AS d
USING (VALUES
    ('IMO-LS-110',   N'La Sante - Sala 110 e vaga 9',           'IMOVEL_PROPRIO', 25, 0   , N'contas antigas 460 e 670 (aluguel); vendida (CMJ, 20/11/2026)'),
    ('IMO-LS-112',   N'La Sante - Sala 112 e vaga 10',          'IMOVEL_PROPRIO', 25, NULL, N'conta antiga 461; alugada pela Construtora (CMJ, 20/11/2026)'),
    ('IMO-LS-113',   N'La Sante - Sala 113 e vaga 15',          'IMOVEL_PROPRIO', 25, 0   , N'conta antiga 462 (no Access: vaga 40); vendida com a vaga 15 (CMJ, 23/11/2026)'),
    ('IMO-LS-VAGAS', N'La Sante - Vagas de estacionamento',     'IMOVEL_PROPRIO', 25, NULL, N'conta antiga 463'),
    ('IMO-ALG-13',   N'Allegro - Apto. 13',                     'IMOVEL_PROPRIO', 25, NULL, N'contas antigas 506 e 692 (aluguel)'),
    ('IMO-ALG-52',   N'Allegro - Apto. 52',                     'IMOVEL_PROPRIO', 25, 0   , N'conta antiga 507; vendido (CMJ, 20/11/2026)'),
    ('IMO-GIU-12',   N'Giuseppina - Apto. 12',                  'IMOVEL_PROPRIO',  6, 0   , N'conta antiga 669 (aluguel); vendido (CMJ, 20/11/2026)'),
    ('PART-CASA-DAN',N'Casa Danielle',                          'PARTICULAR', 25, NULL, N'conta antiga 381; dona: Holding (CMJ, 20/11/2026)'),
    ('PART-CASA-66', N'Casa 66 - Marco Bosque Araucárias',      'PARTICULAR', 25, NULL, N'conta antiga 465; dona: Holding (CMJ, 20/11/2026)')
) AS s (CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, ATIVO, OBSERVACAO)
ON d.CODIGO = s.CODIGO
WHEN MATCHED THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.ATIVO = s.ATIVO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, ATIVO, OBSERVACAO)
     VALUES (s.CODIGO, s.DESCRICAO, s.TIPO, s.CODIGO_MASTER_EMPRESA, s.ATIVO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 4. Contas (F Contas Financeiras). Dona = empresa que mais usa a conta no
--    Access. Contas de clientes de obra antiga ficam na Construtora (inativas).
--    Itaú: agência 0267 (observação das contas no Access).
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Conta AS d
USING (VALUES
    ( 1, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Créditos: conta de sistema (contrapartida)'),
    ( 2, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Débitos: conta de sistema (contrapartida)'),
    ( 3, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Pagto em Lote: conta de sistema'),
    ( 9, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'N/A: caixinha (vira o Caixa de cada empresa na transformação)'),
    ( 4, 'CONTA',  6, N'Itaú Construtora',            'CORRENTE', '341', '0267', '25629', '5', N''),
    ( 5, 'CONTA',  6, N'Itaú Faria Lobato',           'CORRENTE', '341', '0267', '58051', '2', N'obra a preço de custo (Vila Faria Lobato)'),
    ( 6, 'CONTA',  6, N'Itaú Buenos Aires',           'CORRENTE', '341', '0267', '65086', '3', N'obra a preço de custo (Buenos Aires)'),
    ( 7, 'CONTA',  6, N'Caixa Buenos Aires',          'CAIXA',    NULL,  '',     '',      '',  N'obra a preço de custo (Buenos Aires)'),
    (10, 'CONTA',  6, N'Caixa Construtora',           'CAIXA',    NULL,  '',     '',      '',  N''),
    (11, 'CONTA',  6, N'Permuta',                     'PERMUTA',  NULL,  '',     '',      '',  N'usada por várias empresas no Access'),
    (12, 'CONTA',  6, N'Itaú Construtora 2',          'CORRENTE', '341', '0267', '01321', '7', N'conta da obra La Sante antes da SPE'),
    (13, 'CONTA',  6, N'Itaú Giuseppina',             'CORRENTE', '341', '0267', '02005', '5', N'Associação Pró-construção do Ed. Res. Giuseppina'),
    (14, 'CONTA',  6, N'Itaú Attualità',              'CORRENTE', '341', '0267', '03877', '9', N'Associação Pró-construção do Ed. Res. Attualità'),
    (15, 'CONTA', 21, N'Itaú Ilha das Galès',         'CORRENTE', '341', '0267', '07284', '1', N''),
    (16, 'CONTA', 22, N'Itaú La Sante',               'CORRENTE', '341', '0267', '10556', '7', N''),
    (18, 'CONTA', 23, N'Itaú Allegro',                'CORRENTE', '341', '0267', '13861', '8', N''),
    (19, 'CONTA', 28, N'Itaú Square',                 'CORRENTE', '341', '0267', '28450', '3', N''),
    (20, 'CONTA', 31, N'Itaú Maui',                   'CORRENTE', '341', '0267', '28906', '4', N''),
    (21, 'CONTA', 32, N'Sicredi Orion',               'CORRENTE', '748', '0217', '73623', '5', N'cobrança: posto 55, beneficiário 55.73623'),
    (22, 'CONTA', 32, N'Caixa Orion',                 'CAIXA',    NULL,  '',     '',      '',  N''),
    (23, 'CONTA', 34, N'Sicredi Opera',               'CORRENTE', '748', '0217', '77315', '4', N'cobrança: posto 55, beneficiário 55.77315'),
    (24, 'CONTA', 34, N'Caixa Opera',                 'CAIXA',    NULL,  '',     '',      '',  N''),
    (25, 'CONTA', 31, N'Caixa Maui',                  'CAIXA',    NULL,  '',     '',      '',  N''),
    (26, 'CONTA',  6, N'Sicredi Construtora',         'CORRENTE', '748', '0217', '74953', '7', N''),
    (27, 'CONTA', 25, N'Caixa Holding',               'CAIXA',    NULL,  '',     '',      '',  N''),
    (28, 'CONTA', 25, N'Sicredi Holding',             'CORRENTE', '748', '0217', '28656', '3', N''),
    (29, 'CONTA', 35, N'Sicredi Music',               'CORRENTE', '748', '0217', '94652', '1', N'cobrança: posto 55, beneficiário 55.94652')
) AS s (CODIGO_CONTA, DESTINO, CODIGO_MASTER_EMPRESA, DESCRICAO, TIPO, BANCO_CODIGO, AGENCIA, NUMERO, NUMERO_DV, OBSERVACAO)
ON d.CODIGO_CONTA = s.CODIGO_CONTA
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO,
     d.BANCO_CODIGO = s.BANCO_CODIGO, d.AGENCIA = s.AGENCIA, d.NUMERO = s.NUMERO, d.NUMERO_DV = s.NUMERO_DV, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_CONTA, DESTINO, CODIGO_MASTER_EMPRESA, DESCRICAO, TIPO, BANCO_CODIGO, AGENCIA, NUMERO, NUMERO_DV, OBSERVACAO)
     VALUES (s.CODIGO_CONTA, s.DESTINO, s.CODIGO_MASTER_EMPRESA, s.DESCRICAO, s.TIPO, s.BANCO_CODIGO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 5. Grupos do plano de contas. 00 a 18: plano novo do Access (número tirado do
--    nome); 20 e 21: grupos novos aprovados em 16/11/2026; 90 a 92: plano
--    antigo como histórico inativo (só consulta). CUSTO_OBRA = entra no custo
--    da obra e no painel (proposta, a CMJ confere; muda pela tela).
-- -----------------------------------------------------------------------------
MERGE MIG.Config_Plano_Grupo AS d
USING (VALUES
    ( 0, N'Permutas',                              'DESPESA',         1, 1, NULL),
    ( 1, N'Mão de obra',                           'DESPESA',         1, 1, NULL),
    ( 2, N'Despesas administrativas gerais',       'DESPESA',         0, 1, NULL),
    ( 3, N'Encargos sociais',                      'DESPESA',         1, 1, NULL),
    ( 4, N'Equipamentos',                          'DESPESA',         1, 1, NULL),
    ( 5, N'Empreitas',                             'DESPESA',         1, 1, NULL),
    ( 6, N'Fundação e estrutura',                  'DESPESA',         1, 1, NULL),
    ( 7, N'Segurança do trabalho',                 'DESPESA',         1, 1, NULL),
    ( 8, N'Vedação e massa',                       'DESPESA',         1, 1, NULL),
    ( 9, N'Acabamentos',                           'DESPESA',         1, 1, NULL),
    (10, N'Projetos',                              'DESPESA',         1, 1, NULL),
    (11, N'Despesas de vendas',                    'DESPESA',         1, 1, NULL),
    (12, N'Impostos e taxas municipais',           'DESPESA',         1, 1, NULL),
    (13, N'Impostos e taxas estaduais',            'DESPESA',         1, 1, NULL),
    (14, N'Impostos e taxas federais',             'DESPESA',         1, 1, NULL),
    (15, N'Cartórios',                             'DESPESA',         1, 1, NULL),
    (16, N'Canteiro de obras',                     'DESPESA',         1, 1, NULL),
    (17, N'Reembolsos e acertos',                  'DESPESA',         0, 1, NULL),
    (18, N'Medidas compensatórias',                'DESPESA',         1, 1, NULL),
    (20, N'Receitas',                              'RECEITA',         0, 1, NULL),
    (21, N'Não operacional',                       'NAO_OPERACIONAL', 0, 1, NULL),
    (90, N'Receitas (plano antigo)',               'RECEITA',         0, 0, 4),
    (91, N'Despesas (plano antigo)',               'DESPESA',         0, 0, 5),
    (92, N'Distribuição de lucros (plano antigo)', 'NAO_OPERACIONAL', 0, 0, 6)
) AS s (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ATIVO, PLANO1_ACCESS)
ON d.NUMERO = s.NUMERO
WHEN MATCHED THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CUSTO_OBRA = s.CUSTO_OBRA, d.ATIVO = s.ATIVO, d.PLANO1_ACCESS = s.PLANO1_ACCESS
WHEN NOT MATCHED THEN INSERT (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ATIVO, PLANO1_ACCESS)
     VALUES (s.NUMERO, s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ATIVO, s.PLANO1_ACCESS);
GO

-- -----------------------------------------------------------------------------
-- 6. Contas do plano que mudam de lugar (aprovado pela CMJ em 17/11/2026:
--    receitas e despesas do plano antigo usadas desde 2022 ganham de-para;
--    não operacional tirado de receita e de despesa administrativa).
--    ALVO_PLANO3_ACCESS = vai para a conta do plano novo que veio daquele
--    Plano3; senão, para a conta grupo.subgrupo.conta informada.
-- -----------------------------------------------------------------------------
MERGE MIG.DePara_Plano_Excecao AS d
USING (VALUES
    -- receitas (grupo 20)
    ( 41, NULL, 20, 1, N'Vendas',                 1, N'Venda de imóveis',                      NULL,            N'Venda Imoveis'),
    (410, NULL, 20, 1, N'Vendas',                 2, N'Permutas recebidas',                    NULL,            N'Permuta'),
    ( 43, NULL, 20, 1, N'Vendas',                 3, N'Outras vendas',                         NULL,            N'Outras Vendas'),
    (453, NULL, 20, 1, N'Vendas',                 4, N'Juros e multas recebidos',              NULL,            N'Juros e Multas'),
    ( 31, NULL, 20, 2, N'Administração',          1, N'Taxa de administração de obras',        NULL,            N'Administracao Obras'),
    ( 28, NULL, 20, 2, N'Administração',          2, N'Administração de condomínios',          NULL,            N'Administracao Condominios'),
    (669, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-GIU-12',    N'Aluguel - Giuseppina apto. 12'),
    (670, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-LS-110',    N'Aluguel Sala 110 La Sante'),
    (692, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-ALG-13',    N'Aluguel - Allegro apto. 13'),
    (127, NULL, 20, 4, N'Outras receitas',        1, N'Rendimentos de aplicações',             NULL,            N'Rendimento Autom.'),
    (679, NULL, 20, 4, N'Outras receitas',        2, N'Reembolsos recebidos',                  NULL,            N'Reembolsos'),
    ( 47, NULL, 20, 4, N'Outras receitas',        3, N'Outras receitas',                       NULL,            N'Outros Diversos'),
    -- não operacional (grupo 21)
    (705, NULL, 21, 1, N'Entradas',               1, N'Empréstimos recebidos',                 NULL,            N'Empréstimo (estava em receitas)'),
    (665, NULL, 21, 1, N'Entradas',               2, N'Lucros recebidos de participações',     NULL,            N'Distribuição de Lucros (estava em receitas)'),
    (704, NULL, 21, 2, N'Saídas',                 1, N'Amortização de empréstimos',            NULL,            N'2.1.9 - Amortizações'),
    (713, NULL, 21, 2, N'Saídas',                 2, N'Juros de empréstimos e financiamentos', NULL,            N'2.1.10 - Juros Senior'),
    (714, NULL, 21, 2, N'Saídas',                 2, N'Juros de empréstimos e financiamentos', NULL,            N'2.1.11 - Juros Subordinada'),
    (575, NULL, 21, 2, N'Saídas',                 3, N'Distribuição de lucros',                NULL,            N'2.1.4 - Distribuição Lucros'),
    ( 90, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      NULL,            N'Despesas Particulares - Despesas Diversas'),
    (381, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      'PART-CASA-DAN', N'Bens Imóveis - Casa Danielle'),
    (465, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      'PART-CASA-66',  N'Bens Imóveis - Casa 66'),
    -- imóveis próprios (grupo 02, subgrupo novo 3)
    (460, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-110',    N'Bens Imóveis - La Sante Sala 110 e Vaga 9'),
    (461, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-112',    N'Bens Imóveis - La Sante Sala 112 e Vaga 10'),
    (462, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-113',    N'Bens Imóveis - La Sante Sala 113 e Vaga 40'),
    (463, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-VAGAS',  N'Bens Imóveis - La Sante Vagas'),
    (506, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-ALG-13',    N'Bens Imóveis - Apto. 13 Allegro'),
    (507, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-ALG-52',    N'Bens Imóveis - Apto. 52 Allegro'),
    -- despesas do plano antigo para contas que já existem no plano novo
    (221, 521,  NULL, NULL, N'', NULL, N'', NULL, N'Pró-Labore -> 2.1.2 Pro Labore'),
    ( 72, 522,  NULL, NULL, N'', NULL, N'', NULL, N'Telefone -> 2.1.3 Desp. Fixas'),
    ( 75, 522,  NULL, NULL, N'', NULL, N'', NULL, N'Internet e Informatica -> 2.1.3 Desp. Fixas'),
    (498, 532,  NULL, NULL, N'', NULL, N'', NULL, N'INSS PRO LABORE -> 3.1.4 INSS Pro Labore'),
    ( 97, 613,  NULL, NULL, N'', NULL, N'', NULL, N'ISSQN de terceiros -> 12.1.2 ISSQN'),
    (362, 625,  NULL, NULL, N'', NULL, N'', NULL, N'RET (plano antigo) -> 14.1.1 RET'),
    (499, 531,  NULL, NULL, N'', NULL, N'', NULL, N'Contrib. Previdenciária - Desoneração (CPRB, plano antigo) -> 3.1.3 INSS: a CMJ confere')
) AS s (PLANO3_ACCESS, ALVO_PLANO3_ACCESS, GRUPO_NUMERO, SUBGRUPO_NUMERO, SUBGRUPO_DESCRICAO, CONTA_NUMERO, CONTA_DESCRICAO, CENTRO_CODIGO, OBSERVACAO)
ON d.PLANO3_ACCESS = s.PLANO3_ACCESS
WHEN MATCHED THEN UPDATE SET d.ALVO_PLANO3_ACCESS = s.ALVO_PLANO3_ACCESS, d.GRUPO_NUMERO = s.GRUPO_NUMERO, d.SUBGRUPO_NUMERO = s.SUBGRUPO_NUMERO,
     d.SUBGRUPO_DESCRICAO = s.SUBGRUPO_DESCRICAO, d.CONTA_NUMERO = s.CONTA_NUMERO, d.CONTA_DESCRICAO = s.CONTA_DESCRICAO,
     d.CENTRO_CODIGO = s.CENTRO_CODIGO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (PLANO3_ACCESS, ALVO_PLANO3_ACCESS, GRUPO_NUMERO, SUBGRUPO_NUMERO, SUBGRUPO_DESCRICAO, CONTA_NUMERO, CONTA_DESCRICAO, CENTRO_CODIGO, OBSERVACAO)
     VALUES (s.PLANO3_ACCESS, s.ALVO_PLANO3_ACCESS, s.GRUPO_NUMERO, s.SUBGRUPO_NUMERO, s.SUBGRUPO_DESCRICAO, s.CONTA_NUMERO, s.CONTA_DESCRICAO, s.CENTRO_CODIGO, s.OBSERVACAO);
GO
