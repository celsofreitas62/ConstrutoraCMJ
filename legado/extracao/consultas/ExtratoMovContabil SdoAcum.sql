-- Consulta: ExtratoMovContabil SdoAcum
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Extrato Movimento Contabil]!CodigoVinculada (Texto), Formulários![Extrato Movimento Contabil]!DTInicial (Texto)
-- Descrição: 

SELECT ArquivoMorto.EmpVinculada, ArquivoMorto.Integracao, ArquivoMorto.Efetuado, ArquivoMorto.DataPagto, ArquivoMorto.ValorDebito, ArquivoMorto.ValorCredito, ArquivoMorto.DataMovto
FROM ArquivoMorto
WHERE (((ArquivoMorto.EmpVinculada)=Formulários![Extrato Movimento Contabil]!CodigoVinculada) And ((ArquivoMorto.Integracao)=True) And ((ArquivoMorto.Efetuado)=True) And ((ArquivoMorto.DataPagto)<Formulários![Extrato Movimento Contabil]!DTInicial))
ORDER BY ArquivoMorto.DataPagto;
