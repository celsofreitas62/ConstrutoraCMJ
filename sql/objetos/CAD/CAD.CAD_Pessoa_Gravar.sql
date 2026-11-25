/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPessoa NULL) ou altera uma pessoa, junto com os contatos,
                vínculos e dados bancários, tudo ou nada.
                Regras: nome e pelo menos um papel obrigatórios; CPF (F) ou CNPJ (J)
                conferido quando informado (aceita o CNPJ alfanumérico); documento PODE
                repetir: grava e avisa na MENSAGEM (decisão do Celso, 16/11/2026).
                Listas em JSON (mesmo formato do CAD_Pessoa_Obter); NULL = não mexe;
                informada = a lista gravada fica igual (o que saiu é DESATIVADO):
                  @Contatos       [{"id":null,"tipo":"EMAIL","valor":"a@b.com","nome":"","principal":true,"recebeCobranca":true}]
                                  tipos EMAIL, CELULAR, TELEFONE, WHATSAPP (telefone só dígitos, 10 a 13)
                  @Vinculos       [{"idPessoaVinculada":5,"tipo":"CONJUGE","observacao":""}]
                                  tipos CONJUGE, SOCIO, REPRESENTANTE, PROCURADOR
                  @DadosBancarios [{"id":null,"tipo":"TED","idBanco":3,"agencia":"0217","agenciaDv":"","conta":"123456",
                                    "contaDv":"7","tipoConta":"CORRENTE","titularNome":"","titularDocumento":"","principal":true},
                                   {"tipo":"PIX","pixTipo":"EMAIL","pixChave":"a@b.com"}]
                                  PIX: DOCUMENTO, EMAIL, CELULAR, ALEATORIA (chave conferida)
                Recusa com a linha do item errado (nada é gravado).
                Permissão: INCLUIR ou ALTERAR em CAD_PESSOA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04d (P12, P17): @Tipos (JSON [2,6] com os ID_PARCEIRO_TIPO; NULL = tipos
                        do sistema pelas marcas @Cliente.. + os outros tipos que o parceiro já tem);
                        sem tipo = N/A; N/A some quando há outro tipo; as marcas CLIENTE/FORNECEDOR/
                        FUNCIONARIO/CORRETOR são acertadas pelos tipos do sistema. Contato com
                        "finalidade" (COBRANCA, COMPRAS, FINANCEIRO); contatos retirados são desativados
                        antes de gravar os demais (um só principal ativo por tipo). @IdPlanoContaPadrao e
                        @IdCentroCustoPadrao (NULL = não mexe, 0 = limpa).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = 2, @TipoPessoa = 'F', @Nome = N'Maria Teste', @CpfCnpj = '529.982.247-25', @Cliente = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Gravar]
    @IdUsuario           INT,
    @IdPessoa            INT            = NULL,
    @TipoPessoa          CHAR(1),
    @Nome                NVARCHAR(150),
    @NomeFantasia        NVARCHAR(100)  = NULL,
    @CpfCnpj             VARCHAR(30)    = NULL,
    @Rg                  VARCHAR(20)    = NULL,
    @OrgaoEmissor        VARCHAR(20)    = NULL,
    @InscricaoEstadual   VARCHAR(20)    = NULL,
    @InscricaoMunicipal  VARCHAR(20)    = NULL,
    @DtNascimento        DATE           = NULL,
    @Nacionalidade       NVARCHAR(40)   = NULL,
    @Profissao           NVARCHAR(60)   = NULL,
    @EstadoCivil         VARCHAR(15)    = NULL,
    @RegimeBens          VARCHAR(25)    = NULL,
    @Cep                 VARCHAR(10)    = NULL,
    @Logradouro          NVARCHAR(150)  = NULL,
    @Numero              NVARCHAR(20)   = NULL,
    @Complemento         NVARCHAR(60)   = NULL,
    @Bairro              NVARCHAR(60)   = NULL,
    @Cidade              NVARCHAR(60)   = NULL,
    @Uf                  CHAR(2)        = NULL,
    @Cliente             BIT            = 0,
    @Fornecedor          BIT            = 0,
    @Funcionario         BIT            = 0,
    @Corretor            BIT            = 0,
    @Observacao          NVARCHAR(2000) = NULL,
    @Contatos            NVARCHAR(MAX)  = NULL,
    @Vinculos            NVARCHAR(MAX)  = NULL,
    @DadosBancarios      NVARCHAR(MAX)  = NULL,
    @Tipos               NVARCHAR(MAX)  = NULL,
    @IdPlanoContaPadrao  INT            = NULL,
    @IdCentroCustoPadrao INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Repetidos  INT           = 0;
    DECLARE @Mensagem   NVARCHAR(400);
    DECLARE @Cont  TABLE (LINHA INT, ID INT, TIPO VARCHAR(20), VALOR NVARCHAR(256), NOME NVARCHAR(80), PRINCIPAL BIT, RECEBE BIT, FINALIDADE VARCHAR(20));
    DECLARE @Tip   TABLE (ID INT PRIMARY KEY, CODIGO VARCHAR(20), SISTEMA BIT);
    DECLARE @IdNA  INT = (SELECT t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = 'NA');
    DECLARE @Vinc  TABLE (LINHA INT, ID_VINCULADA INT, TIPO VARCHAR(20), OBSERVACAO NVARCHAR(200));
    DECLARE @Banc  TABLE (LINHA INT, ID INT, TIPO VARCHAR(10), ID_BANCO INT, AGENCIA VARCHAR(20), AGENCIA_DV VARCHAR(5), CONTA VARCHAR(30),
                          CONTA_DV VARCHAR(5), TIPO_CONTA VARCHAR(20), TITULAR_NOME NVARCHAR(150), TITULAR_DOC VARCHAR(30),
                          PIX_TIPO VARCHAR(20), PIX_CHAVE NVARCHAR(140), PRINCIPAL BIT);

    BEGIN TRY
        SET @TipoPessoa         = UPPER(LTRIM(RTRIM(ISNULL(@TipoPessoa, ''))));
        SET @Nome               = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @CpfCnpj            = CAD.fn_CAD_Documento_Limpo(@CpfCnpj);
        SET @Rg                 = LTRIM(RTRIM(ISNULL(@Rg, '')));
        SET @OrgaoEmissor       = UPPER(LTRIM(RTRIM(ISNULL(@OrgaoEmissor, ''))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @Nacionalidade      = LTRIM(RTRIM(ISNULL(@Nacionalidade, N'')));
        SET @Profissao          = LTRIM(RTRIM(ISNULL(@Profissao, N'')));
        SET @EstadoCivil        = UPPER(LTRIM(RTRIM(ISNULL(@EstadoCivil, ''))));
        SET @RegimeBens         = UPPER(LTRIM(RTRIM(ISNULL(@RegimeBens, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Cliente            = ISNULL(@Cliente, 0);
        SET @Fornecedor         = ISNULL(@Fornecedor, 0);
        SET @Funcionario        = ISNULL(@Funcionario, 0);
        SET @Corretor           = ISNULL(@Corretor, 0);
        SET @Observacao         = LTRIM(RTRIM(ISNULL(@Observacao, N'')));

        -- Pessoa
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', CASE WHEN @IdPessoa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar pessoas.';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', @IdPessoa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa)
            SET @Recusa = N'Pessoa não encontrada.';
        IF @Recusa = N'' AND @TipoPessoa NOT IN ('F', 'J')
            SET @Recusa = N'Escolha pessoa física (F) ou jurídica (J).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'F' AND (LEN(@CpfCnpj) <> 11 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CPF inválido. Confira os números.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'J' AND (LEN(@CpfCnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND @Tipos IS NOT NULL AND ISJSON(@Tipos) = 0
            SET @Recusa = N'Lista de tipos de parceiro em formato inválido.';
        IF @Recusa = N'' AND ISNULL(@IdPlanoContaPadrao, 0) > 0
           AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @IdPlanoContaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'Conta do plano padrão não encontrada ou inativa.';
        IF @Recusa = N'' AND ISNULL(@IdCentroCustoPadrao, 0) > 0
           AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCustoPadrao AND c.ATIVO = 1)
            SET @Recusa = N'Centro de custo padrão não encontrado ou inativo.';

        -- Tipos de parceiro (P12): lista informada, ou marcas antigas + outros tipos que já tem
        IF @Recusa = N''
        BEGIN
            IF @Tipos IS NOT NULL
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT DISTINCT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM OPENJSON(@Tipos) k
                INNER JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = TRY_CONVERT(INT, k.value)
                WHERE t.DT_EXCLUSAO IS NULL
                  AND (t.ATIVO = 1 OR EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = ISNULL(@IdPessoa, 0)
                                                AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO AND x.ATIVO = 1));
            ELSE
            BEGIN
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM (VALUES ('CLIENTE', @Cliente), ('FORNECEDOR', @Fornecedor), ('FUNCIONARIO', @Funcionario), ('CORRETOR', @Corretor)) m (CODIGO, MARCA)
                INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = m.CODIGO
                WHERE m.MARCA = 1;
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM CAD.Pessoa_Tipo x
                INNER JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                WHERE x.ID_PESSOA = ISNULL(@IdPessoa, 0) AND x.ATIVO = 1
                  AND t.CODIGO NOT IN ('CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR', 'NA');
            END;

            IF @Tipos IS NOT NULL AND (SELECT COUNT(*) FROM @Tip) <> (SELECT COUNT(DISTINCT k.value) FROM OPENJSON(@Tipos) k)
                SET @Recusa = N'Tipo de parceiro não encontrado, inativo ou na lixeira. Atualize a tela e marque de novo.';

            IF EXISTS (SELECT 1 FROM @Tip WHERE CODIGO <> 'NA') DELETE FROM @Tip WHERE CODIGO = 'NA';
            IF NOT EXISTS (SELECT 1 FROM @Tip) INSERT INTO @Tip (ID, CODIGO, SISTEMA) VALUES (@IdNA, 'NA', 1);

            SELECT @Cliente     = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'CLIENTE')     THEN 1 ELSE 0 END,
                   @Fornecedor  = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'FORNECEDOR')  THEN 1 ELSE 0 END,
                   @Funcionario = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'FUNCIONARIO') THEN 1 ELSE 0 END,
                   @Corretor    = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'CORRETOR')    THEN 1 ELSE 0 END;
        END;
        IF @Recusa = N'' AND @EstadoCivil NOT IN ('', 'SOLTEIRO', 'CASADO', 'DIVORCIADO', 'VIUVO', 'SEPARADO', 'UNIAO_ESTAVEL')
            SET @Recusa = N'Estado civil inválido.';
        IF @Recusa = N'' AND @RegimeBens NOT IN ('', 'COMUNHAO_PARCIAL', 'COMUNHAO_UNIVERSAL', 'SEPARACAO_TOTAL', 'PARTICIPACAO_AQUESTOS')
            SET @Recusa = N'Regime de bens inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @DtNascimento IS NOT NULL AND (@DtNascimento < '1900-01-01' OR @DtNascimento > CONVERT(DATE, @Agora))
            SET @Recusa = N'Data de nascimento inválida.';
        IF @Recusa = N'' AND (   (@Contatos IS NOT NULL AND ISJSON(@Contatos) = 0)
                              OR (@Vinculos IS NOT NULL AND ISJSON(@Vinculos) = 0)
                              OR (@DadosBancarios IS NOT NULL AND ISJSON(@DadosBancarios) = 0))
            SET @Recusa = N'Lista de contatos, vínculos ou dados bancários em formato inválido.';

        -- Contatos
        IF @Recusa = N'' AND @Contatos IS NOT NULL
        BEGIN
            INSERT INTO @Cont (LINHA, ID, TIPO, VALOR, NOME, PRINCIPAL, RECEBE, FINALIDADE)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N''))),
                   LTRIM(RTRIM(ISNULL(j.nome, N''))), ISNULL(j.principal, 0), ISNULL(j.recebeCobranca, 0), UPPER(LTRIM(RTRIM(ISNULL(j.finalidade, ''))))
            FROM OPENJSON(@Contatos) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(20) '$.tipo', valor NVARCHAR(256) '$.valor',
                                               nome NVARCHAR(80) '$.nome', principal BIT '$.principal', recebeCobranca BIT '$.recebeCobranca',
                                               finalidade VARCHAR(20) '$.finalidade') j
            WHERE k.[type] = 5;

            UPDATE c SET c.VALOR = CASE WHEN c.TIPO = 'EMAIL' THEN LOWER(c.VALOR) ELSE CONVERT(NVARCHAR(256), CAD.fn_CAD_Somente_Digitos(c.VALOR)) END
            FROM @Cont c;

            SELECT TOP 1 @Recusa = N'Contato ' + CONVERT(NVARCHAR(5), c.LINHA) + N': ' +
                   CASE WHEN c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP') THEN N'tipo inválido (e-mail, celular, telefone ou WhatsApp).'
                        WHEN c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0 THEN N'e-mail inválido.'
                        WHEN c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13 THEN N'telefone inválido (informe DDD + número).'
                        WHEN c.FINALIDADE NOT IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO') THEN N'finalidade inválida (cobrança, compras ou financeiro).'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Cont c
            WHERE c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')
               OR (c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0)
               OR (c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13)
               OR c.FINALIDADE NOT IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO')
               OR (c.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato pc WHERE pc.ID_PESSOA_CONTATO = c.ID AND pc.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY c.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Cont c WHERE c.PRINCIPAL = 1 GROUP BY c.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'Marque só um contato principal de cada tipo.';
        END;

        -- Vínculos
        IF @Recusa = N'' AND @Vinculos IS NOT NULL
        BEGIN
            INSERT INTO @Vinc (LINHA, ID_VINCULADA, TIPO, OBSERVACAO)
            SELECT CONVERT(INT, k.[key]) + 1, j.idPessoaVinculada, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.observacao, N'')))
            FROM OPENJSON(@Vinculos) k
            CROSS APPLY OPENJSON(k.value) WITH (idPessoaVinculada INT '$.idPessoaVinculada', tipo VARCHAR(20) '$.tipo', observacao NVARCHAR(200) '$.observacao') j
            WHERE k.[type] = 5;

            SELECT TOP 1 @Recusa = N'Vínculo ' + CONVERT(NVARCHAR(5), v.LINHA) + N': ' +
                   CASE WHEN v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR') THEN N'tipo inválido (cônjuge, sócio, representante ou procurador).'
                        WHEN v.ID_VINCULADA = ISNULL(@IdPessoa, 0) THEN N'a pessoa não pode ser vinculada a ela mesma.'
                        ELSE N'pessoa vinculada não encontrada.' END
            FROM @Vinc v
            WHERE v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR')
               OR v.ID_VINCULADA = ISNULL(@IdPessoa, 0)
               OR NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = v.ID_VINCULADA AND p.DT_EXCLUSAO IS NULL)
            ORDER BY v.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Vinc v GROUP BY v.ID_VINCULADA, v.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'O mesmo vínculo foi informado duas vezes.';
        END;

        -- Dados bancários
        IF @Recusa = N'' AND @DadosBancarios IS NOT NULL
        BEGIN
            INSERT INTO @Banc (LINHA, ID, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME, TITULAR_DOC, PIX_TIPO, PIX_CHAVE, PRINCIPAL)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), j.idBanco,
                   CAD.fn_CAD_Somente_Digitos(j.agencia), UPPER(LTRIM(RTRIM(ISNULL(j.agenciaDv, '')))),
                   CAD.fn_CAD_Somente_Digitos(j.conta), UPPER(LTRIM(RTRIM(ISNULL(j.contaDv, '')))),
                   UPPER(LTRIM(RTRIM(ISNULL(j.tipoConta, '')))), LTRIM(RTRIM(ISNULL(j.titularNome, N''))),
                   CAD.fn_CAD_Documento_Limpo(j.titularDocumento), UPPER(LTRIM(RTRIM(ISNULL(j.pixTipo, '')))),
                   LTRIM(RTRIM(ISNULL(j.pixChave, N''))), ISNULL(j.principal, 0)
            FROM OPENJSON(@DadosBancarios) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(10) '$.tipo', idBanco INT '$.idBanco', agencia NVARCHAR(20) '$.agencia',
                                               agenciaDv VARCHAR(5) '$.agenciaDv', conta NVARCHAR(30) '$.conta', contaDv VARCHAR(5) '$.contaDv',
                                               tipoConta VARCHAR(20) '$.tipoConta', titularNome NVARCHAR(150) '$.titularNome',
                                               titularDocumento NVARCHAR(30) '$.titularDocumento', pixTipo VARCHAR(20) '$.pixTipo',
                                               pixChave NVARCHAR(140) '$.pixChave', principal BIT '$.principal') j
            WHERE k.[type] = 5;

            -- Cada tipo guarda só os seus campos; chave PIX normalizada
            UPDATE b
               SET b.ID_BANCO   = CASE WHEN b.TIPO = 'TED' THEN b.ID_BANCO END,
                   b.AGENCIA    = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA ELSE '' END,
                   b.AGENCIA_DV = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA_DV ELSE '' END,
                   b.CONTA      = CASE WHEN b.TIPO = 'TED' THEN b.CONTA ELSE '' END,
                   b.CONTA_DV   = CASE WHEN b.TIPO = 'TED' THEN b.CONTA_DV ELSE '' END,
                   b.TIPO_CONTA = CASE WHEN b.TIPO = 'TED' THEN b.TIPO_CONTA ELSE '' END,
                   b.PIX_TIPO   = CASE WHEN b.TIPO = 'PIX' THEN b.PIX_TIPO ELSE '' END,
                   b.PIX_CHAVE  = CASE WHEN b.TIPO <> 'PIX' THEN N''
                                       WHEN b.PIX_TIPO = 'DOCUMENTO' THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Documento_Limpo(b.PIX_CHAVE))
                                       WHEN b.PIX_TIPO = 'CELULAR'   THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Somente_Digitos(b.PIX_CHAVE))
                                       ELSE LOWER(b.PIX_CHAVE) END
            FROM @Banc b;

            SELECT TOP 1 @Recusa = N'Dado bancário ' + CONVERT(NVARCHAR(5), b.LINHA) + N': ' +
                   CASE WHEN b.TIPO NOT IN ('TED', 'PIX') THEN N'escolha TED ou PIX.'
                        WHEN b.TIPO = 'TED' AND NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1) THEN N'escolha o banco.'
                        WHEN b.TIPO = 'TED' AND (b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20) THEN N'informe a agência e a conta.'
                        WHEN b.TIPO = 'TED' AND b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO') THEN N'tipo de conta inválido.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA') THEN N'escolha o tipo da chave PIX.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (CPF/CNPJ) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (e-mail) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13 THEN N'chave PIX (celular) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%') THEN N'chave PIX aleatória inválida.'
                        WHEN b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0 THEN N'documento do titular inválido.'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Banc b
            WHERE b.TIPO NOT IN ('TED', 'PIX')
               OR (b.TIPO = 'TED' AND (   NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1)
                                       OR b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20
                                       OR b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO')))
               OR (b.TIPO = 'PIX' AND (   b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA')
                                       OR (b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13)
                                       OR (b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%'))))
               OR (b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0)
               OR (b.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA_DADO_BANCARIO = b.ID AND d.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY b.LINHA;

            IF @Recusa = N'' AND (SELECT COUNT(*) FROM @Banc b WHERE b.PRINCIPAL = 1) > 1
                SET @Recusa = N'Marque só um dado bancário como principal.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        IF @CpfCnpj <> ''
            SELECT @Repetidos = COUNT(*) FROM CAD.Pessoa p WHERE p.CPF_CNPJ = @CpfCnpj AND p.ID_PESSOA <> ISNULL(@IdPessoa, 0);

        SET @EtapaAtual = 'Gravação da pessoa';
        BEGIN TRANSACTION;

        IF @IdPessoa IS NULL
        BEGIN
            INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, NOME_FANTASIA, CPF_CNPJ, RG, ORGAO_EMISSOR, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL,
                                    DT_NASCIMENTO, NACIONALIDADE, PROFISSAO, ESTADO_CIVIL, REGIME_BENS, CEP, LOGRADOURO, NUMERO, COMPLEMENTO,
                                    BAIRRO, CIDADE, UF, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR, OBSERVACAO,
                                    ID_PLANO_CONTA_PADRAO, ID_CENTRO_CUSTO_PADRAO, USUARIO_CRIACAO)
            VALUES (@TipoPessoa, @Nome, @NomeFantasia, @CpfCnpj, @Rg, @OrgaoEmissor, @InscricaoEstadual, @InscricaoMunicipal,
                    @DtNascimento, @Nacionalidade, @Profissao, @EstadoCivil, @RegimeBens, @Cep, @Logradouro, @Numero, @Complemento,
                    @Bairro, @Cidade, @Uf, @Cliente, @Fornecedor, @Funcionario, @Corretor, @Observacao,
                    NULLIF(@IdPlanoContaPadrao, 0), NULLIF(@IdCentroCustoPadrao, 0), @Usuario);
            SET @IdPessoa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE p
               SET p.TIPO_PESSOA = @TipoPessoa, p.NOME = @Nome, p.NOME_FANTASIA = @NomeFantasia, p.CPF_CNPJ = @CpfCnpj, p.RG = @Rg,
                   p.ORGAO_EMISSOR = @OrgaoEmissor, p.INSCRICAO_ESTADUAL = @InscricaoEstadual, p.INSCRICAO_MUNICIPAL = @InscricaoMunicipal,
                   p.DT_NASCIMENTO = @DtNascimento, p.NACIONALIDADE = @Nacionalidade, p.PROFISSAO = @Profissao, p.ESTADO_CIVIL = @EstadoCivil,
                   p.REGIME_BENS = @RegimeBens, p.CEP = @Cep, p.LOGRADOURO = @Logradouro, p.NUMERO = @Numero, p.COMPLEMENTO = @Complemento,
                   p.BAIRRO = @Bairro, p.CIDADE = @Cidade, p.UF = @Uf, p.CLIENTE = @Cliente, p.FORNECEDOR = @Fornecedor,
                   p.FUNCIONARIO = @Funcionario, p.CORRETOR = @Corretor, p.OBSERVACAO = @Observacao,
                   p.ID_PLANO_CONTA_PADRAO  = CASE WHEN @IdPlanoContaPadrao  IS NULL THEN p.ID_PLANO_CONTA_PADRAO  ELSE NULLIF(@IdPlanoContaPadrao, 0)  END,
                   p.ID_CENTRO_CUSTO_PADRAO = CASE WHEN @IdCentroCustoPadrao IS NULL THEN p.ID_CENTRO_CUSTO_PADRAO ELSE NULLIF(@IdCentroCustoPadrao, 0) END,
                   p.DT_ALTERACAO = @Agora, p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

        SET @EtapaAtual = 'Gravação dos tipos';
        UPDATE x SET x.ATIVO = 0, x.DT_ALTERACAO = @Agora, x.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa_Tipo x
        WHERE x.ID_PESSOA = @IdPessoa AND x.ATIVO = 1 AND NOT EXISTS (SELECT 1 FROM @Tip t WHERE t.ID = x.ID_PARCEIRO_TIPO);
        UPDATE x SET x.ATIVO = 1, x.DT_ALTERACAO = @Agora, x.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa_Tipo x
        INNER JOIN @Tip t ON t.ID = x.ID_PARCEIRO_TIPO
        WHERE x.ID_PESSOA = @IdPessoa AND x.ATIVO = 0;
        INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
        SELECT @IdPessoa, t.ID, @Usuario
        FROM @Tip t
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = @IdPessoa AND x.ID_PARCEIRO_TIPO = t.ID);

        -- Listas: NULL = não mexe; informada = fica igual à lista (o que saiu é desativado, não apagado)
        IF @Contatos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos contatos';
            -- primeiro os retirados (um só principal ativo por tipo: índice único)
            UPDATE pc
               SET pc.ATIVO = 0, pc.PRINCIPAL = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);
            UPDATE pc
               SET pc.TIPO = c.TIPO, pc.VALOR = c.VALOR, pc.NOME_CONTATO = c.NOME, pc.PRINCIPAL = c.PRINCIPAL, pc.RECEBE_COBRANCA = c.RECEBE, pc.FINALIDADE = c.FINALIDADE,
                   pc.ATIVO = 1, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            INNER JOIN @Cont c ON c.ID = pc.ID_PESSOA_CONTATO
            WHERE pc.ID_PESSOA = @IdPessoa;

            UPDATE pc
               SET pc.ATIVO = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);

            INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, NOME_CONTATO, PRINCIPAL, RECEBE_COBRANCA, FINALIDADE, USUARIO_CRIACAO)
            SELECT @IdPessoa, c.TIPO, c.VALOR, c.NOME, c.PRINCIPAL, c.RECEBE, c.FINALIDADE, @Usuario
            FROM @Cont c
            WHERE c.ID IS NULL
            ORDER BY c.LINHA;
        END;

        IF @Vinculos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos vínculos';
            UPDATE pv
               SET pv.OBSERVACAO = v.OBSERVACAO, pv.ATIVO = 1, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            INNER JOIN @Vinc v ON v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO
            WHERE pv.ID_PESSOA = @IdPessoa;

            UPDATE pv
               SET pv.ATIVO = 0, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            WHERE pv.ID_PESSOA = @IdPessoa AND pv.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Vinc v WHERE v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO);

            INSERT INTO CAD.Pessoa_Vinculo (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO, OBSERVACAO, USUARIO_CRIACAO)
            SELECT @IdPessoa, v.ID_VINCULADA, v.TIPO, v.OBSERVACAO, @Usuario
            FROM @Vinc v
            WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Vinculo pv WHERE pv.ID_PESSOA = @IdPessoa AND pv.ID_PESSOA_VINCULADA = v.ID_VINCULADA AND pv.TIPO = v.TIPO)
            ORDER BY v.LINHA;
        END;

        IF @DadosBancarios IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos dados bancários';
            UPDATE d
               SET d.TIPO = b.TIPO, d.ID_BANCO = b.ID_BANCO, d.AGENCIA = b.AGENCIA, d.AGENCIA_DV = b.AGENCIA_DV, d.CONTA = b.CONTA,
                   d.CONTA_DV = b.CONTA_DV, d.TIPO_CONTA = b.TIPO_CONTA, d.TITULAR_NOME = b.TITULAR_NOME, d.TITULAR_DOCUMENTO = b.TITULAR_DOC,
                   d.PIX_TIPO = b.PIX_TIPO, d.PIX_CHAVE = b.PIX_CHAVE, d.PRINCIPAL = b.PRINCIPAL, d.ATIVO = 1,
                   d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            INNER JOIN @Banc b ON b.ID = d.ID_PESSOA_DADO_BANCARIO
            WHERE d.ID_PESSOA = @IdPessoa;

            UPDATE d
               SET d.ATIVO = 0, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            WHERE d.ID_PESSOA = @IdPessoa AND d.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Banc b WHERE b.ID = d.ID_PESSOA_DADO_BANCARIO);

            INSERT INTO CAD.Pessoa_Dado_Bancario (ID_PESSOA, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME,
                                                  TITULAR_DOCUMENTO, PIX_TIPO, PIX_CHAVE, PRINCIPAL, USUARIO_CRIACAO)
            SELECT @IdPessoa, b.TIPO, b.ID_BANCO, b.AGENCIA, b.AGENCIA_DV, b.CONTA, b.CONTA_DV, b.TIPO_CONTA, b.TITULAR_NOME,
                   b.TITULAR_DOC, b.PIX_TIPO, b.PIX_CHAVE, b.PRINCIPAL, @Usuario
            FROM @Banc b
            WHERE b.ID IS NULL
            ORDER BY b.LINHA;
        END;

        COMMIT TRANSACTION;

        SET @Mensagem = N'Pessoa gravada (código ' + CONVERT(NVARCHAR(10), @IdPessoa) + N').'
                      + CASE WHEN @Repetidos > 0
                             THEN N' Atenção: já existe(m) ' + CONVERT(NVARCHAR(10), @Repetidos) + N' outra(s) pessoa(s) com este CPF/CNPJ.'
                             ELSE N'' END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a pessoa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END CATCH;
END;
GO
