-- Consulta: ~sq_fSeManutencao
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Switchboard Items].[SwitchboardID], [Switchboard Items].[ItemNumber], [Switchboard Items].[ItemText], [Switchboard Items].[Command], [Switchboard Items].[Argument], [Switchboard Items].[Senha]
FROM [Switchboard Items]
WHERE ((([Switchboard Items].[ItemNumber])<>0) And (([Switchboard Items].[ItemText])<>"Menu Principal" And ([Switchboard Items].[ItemText])<>"Retorna") And (([Switchboard Items].[Command])<>6))
ORDER BY [Switchboard Items].[SwitchboardID], [Switchboard Items].[ItemNumber];
