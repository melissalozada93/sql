USE [DWCOOPAC]
GO

INSERT INTO[dbo].[ST_INDICADORES_SOSTENIBILIDAD_DATA]
SELECT [Id_Indicador]
      ,[Descripci�n]
      ,CONVERT(float,[Valor])
      ,[A�o]
      ,[Mes]
      ,dbo.InitCap ([Usuario])
	  ,CONVERT(DATE,Salida , 103)
      ,CONVERT(DATE,[Retorno],103)
      ,[Ruta]
      ,[Nviajes]
      ,[Origen]
      ,[Destino]
	  ,GETDATE()
  FROM [dbo].[temp_IndicadoresSostenibilidadData]

GO


SELECT * FROM [ST_INDICADORES_SOSTENIBILIDAD_DATA]