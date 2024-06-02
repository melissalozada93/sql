USE [DWCOOPAC]
GO
INSERT INTO [ST_INDICADORES_SOSTENIBILIDAD]
SELECT [IdIndicador]
      ,[Iniciativa]
	  ,[GrupoIndicador]=iif(IdIndicador in ('HC-10','HC-16','HC-17','HC-12','HC-15','HC-6','HC-11','HC-1','HC-8','HC-7','HC-18'),Concat([Iniciativa],' 1'),
						iif(IdIndicador not in ('HC-10','HC-16','HC-17','HC-12','HC-15','HC-6','HC-11','HC-1','HC-8','HC-7','HC-18') and left([Iniciativa],1)='H',Concat([Iniciativa],' 2'),[Iniciativa]))
      ,[Descripcion]
      ,[N]
      ,[Indicador]
      ,[Unidad Requerida]
      ,[Responsable]
      ,[TipoIndicador]
      ,[Periodicidad]
      ,[Prioridad]
  FROM [dbo].[temp_IndicadoresSostenibilidad]

GO


DELETE FROM [ST_INDICADORES_SOSTENIBILIDAD_DATA]
where Descripcion='Traslado casa-trabajo*' and year(fecha)=2021