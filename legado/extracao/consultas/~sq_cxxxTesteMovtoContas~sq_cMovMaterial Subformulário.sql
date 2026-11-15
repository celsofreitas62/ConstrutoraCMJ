-- Consulta: ~sq_cxxxTesteMovtoContas~sq_cMovMaterial Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __NumMovimento (Texto)
-- Descrição: 

PARAMETERS __NumMovimento Value;
SELECT DISTINCTROW *
FROM (SELECT [MovMaterial].[MovMaterial], [MovMaterial].[NumMovimento], [MovMaterial].[CodMaterial], [MovMaterial].[Quantidade], [MovMaterial].[PrecoUnitario], [Material].[Unidade] FROM Material INNER JOIN MovMaterial ON [Material].[CodMaterial]=[MovMaterial].[CodMaterial]; )  AS xxxTesteMovtoContas
WHERE ([__NumMovimento] = NumMovimento);
