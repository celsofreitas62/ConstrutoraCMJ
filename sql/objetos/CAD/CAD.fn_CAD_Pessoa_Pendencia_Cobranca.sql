/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : P10 - cadastro apto para cobrança (boleto). Devolve uma linha
                com APTO (1/0) e PENDENCIA (texto do que falta, separado por
                "; "; vazio = apto). Exigências em parâmetros
                COBRANCA_APTO_EXIGE_DOCUMENTO / _ENDERECO / _EMAIL / _TELEFONE.
                E-mail: contato ativo principal ou de finalidade COBRANCA, com
                formato válido. Usada pela lista e ficha de Parceiros (aviso)
                e, na fase 6, pela trava da emissão do boleto.
                Função em linha (sem custo por linha nas listas).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- SELECT p.ID_PESSOA, f.* FROM CAD.Pessoa p CROSS APPLY CAD.fn_CAD_Pessoa_Pendencia_Cobranca(p.ID_PESSOA) f WHERE f.APTO = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca] (@IdPessoa INT)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN x.PENDENCIA = N'' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS APTO,
           x.PENDENCIA
    FROM (
        SELECT CONCAT_WS(N'; ',
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_DOCUMENTO') = 1
                           AND (p.CPF_CNPJ = '' OR CAD.fn_CAD_Documento_Valido(p.CPF_CNPJ) = 0
                                OR LEN(p.CPF_CNPJ) <> CASE p.TIPO_PESSOA WHEN 'F' THEN 11 ELSE 14 END)
                      THEN CASE p.TIPO_PESSOA WHEN 'F' THEN N'CPF ausente ou inválido' ELSE N'CNPJ ausente ou inválido' END END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_ENDERECO') = 1
                           AND (LEN(p.CEP) <> 8 OR p.LOGRADOURO = N'' OR p.NUMERO = N'' OR p.BAIRRO = N'' OR p.CIDADE = N'' OR LEN(p.UF) <> 2)
                      THEN N'endereço incompleto (CEP, logradouro, número, bairro, cidade e UF)' END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_EMAIL') = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO = 'EMAIL'
                                             AND (c.PRINCIPAL = 1 OR c.FINALIDADE = 'COBRANCA')
                                             AND c.VALOR LIKE N'_%@_%._%' AND c.VALOR NOT LIKE N'% %' AND c.VALOR NOT LIKE N'%@%@%')
                      THEN N'sem e-mail principal ou de cobrança válido' END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_TELEFONE') = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO IN ('CELULAR', 'TELEFONE', 'WHATSAPP'))
                      THEN N'sem telefone' END) AS PENDENCIA
        FROM CAD.Pessoa p
        WHERE p.ID_PESSOA = @IdPessoa
    ) x
);
GO
