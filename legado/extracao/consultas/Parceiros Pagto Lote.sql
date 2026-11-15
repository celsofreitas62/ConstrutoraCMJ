-- Consulta: Parceiros Pagto Lote
-- Tipo: Seleção (0)
-- Descrição: 

SELECT Parceiros.CodigoParceiro, Parceiros.NomeParceiro, Parceiros.PagtoLote, Parceiros.Master, Parceiros.Inativo
FROM Parceiros
WHERE (((Parceiros.PagtoLote)=True) AND ((Parceiros.Master)=False) AND ((Parceiros.Inativo)=False));
