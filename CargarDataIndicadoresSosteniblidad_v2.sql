USE [DWCOOPAC]
GO

INSERT INTO[dbo].[ST_INDICADORES_SOSTENIBILIDAD_DATA]
SELECT [Id_Indicador]
      ,[Descripción]
      ,CONVERT(float,[Valor])
	  ,CONVERT(float,[Porcentaje])
	  ,CONVERT(DATE,Fecha , 103)
      ,dbo.InitCap ([Usuario])
	  ,CONVERT(DATE,Salida , 103)
      ,CONVERT(DATE,[Retorno],103)
      ,[Ruta]
      ,[Nviajes]
      ,[Origen]
      ,[Destino1]
	  ,[Destino2]
	  ,[Tipo Vehiculo]
	  ,[Medio]
	  ,[Tipo Residuo]
	  ,[Sexo]
	  ,GETDATE()
  FROM [dbo].[temp_IndicadoresSostenibilidadData]

GO


INSERT INTO  [ST_INDICADORES_SOSTENIBILIDAD]
SELECT * FROM [dbo].[temp_IndicadoresSostenibilidad]

SELECT * FROM [ST_INDICADORES_SOSTENIBILIDAD_DATA]

truncate table[ST_INDICADORES_SOSTENIBILIDAD_DATA]

SELECT * FROM [ST_INDICADORES_SOSTENIBILIDAD]

truncate table [ST_INDICADORES_SOSTENIBILIDAD]

--drop table [dbo].[temp_IndicadoresSostenibilidad]

drop table  [dbo].[temp_IndicadoresSostenibilidadData]

insert into [ST_INDICADORES_SOSTENIBILIDAD]

select * from [dbo].[temp_IndicadoresSostenibilidad]



select * from  [dbo].[temp_IndicadoresSostenibilidadData]


SELECT * FROM [ST_INDICADORES_SOSTENIBILIDAD] where IdIndicador='HC-20'


