-- Consulta: ~sq_cSwitchboard Sistema~sq_cSeManutencao
-- Tipo: Seleção (0)
-- Parâmetros: __SwitchboardID (Texto)
-- Descrição: 

PARAMETERS __SwitchboardID Value;
SELECT DISTINCTROW *
FROM (SELECT [Switchboard Items].[SwitchboardID], [Switchboard Items].[ItemNumber], [Switchboard Items].[ItemText], [Switchboard Items].[Command], [Switchboard Items].[Argument], [Switchboard Items].[Senha] FROM [Switchboard Items] WHERE ((([Switchboard Items].[ItemNumber])<>0) And (([Switchboard Items].[ItemText])<>"Menu Principal" And ([Switchboard Items].[ItemText])<>"Retorna") And (([Switchboard Items].[Command])<>6)) ORDER BY [Switchboard Items].[SwitchboardID], [Switchboard Items].[ItemNumber]; )  AS [Switchboard Sistema]
WHERE ([__SwitchboardID] = SwitchboardID);
