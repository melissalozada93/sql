--USE [DWCOOPAC]
--GO
--/****** Object:  StoredProcedure [dbo].[usp_crear_st_soporte]    Script Date: 16/05/2024 11:36:21 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER procedure [dbo].[usp_cargar_datos_sostenibilidad]

--AS


---------Extrae los datos de los archivos externos------
--EXEC xp_cmdshell 'D:\Files\CargarArchivosExcelEquidadGenero.exe';
--EXEC xp_cmdshell 'D:\Files\CargarArchivosExcelKimochi.exe';
--EXEC xp_cmdshell 'D:\Files\CargarArchivosExcelSaras.exe';
--EXEC xp_cmdshell 'D:\Files\CargarArhivosExcelHuellaCarbono.exe';


----Datos Finales
 DROP TABLE IF EXISTS #DatosFinales
    SELECT identity(int,1,1)[ID],*
    INTO #DatosFinales
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Datos_Finales.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

	DROP TABLE IF EXISTS #TempDatosFinales
	SELECT *,COALESCE(indicador, LAG(indicador) OVER (ORDER BY id)) AS INDICADOR2
	INTO #TempDatosFinales
	FROM #DatosFinales	



	DROP TABLE IF EXISTS #HC1234
	SELECT 
	[N]=CASE WHEN INDICADOR='Total de emisiones de GEI' THEN 1
			 WHEN INDICADOR='Emisiones de GEI por colaborador' THEN 2
			 ELSE 0 END,
	[Id_Indicador]=CASE WHEN INDICADOR='Total de emisiones de GEI' THEN 'HC-1'
						WHEN INDICADOR='Emisiones de GEI por colaborador' THEN 'HC-2'
						ELSE '' END,
	[Indicador]=INDICADOR,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Medida]='tonCO2e'
	INTO #HC1234
	FROM #TempDatosFinales 
			WHERE INDICADOR2 IN ('Total de emisiones de GEI','Emisiones de GEI por colaborador')
	UNION
	SELECT 
	[N]=CASE WHEN A.INDICADOR2='Reducción de la Huella de Carbono' THEN 3
			 WHEN A.INDICADOR2='Neutralización de la Huella de Carbono' THEN 4
			 ELSE 0 END,
	[Id_Indicador]=CASE WHEN A.INDICADOR2='Reducción de la Huella de Carbono' THEN 'HC-3'
						WHEN A.INDICADOR2='Neutralización de la Huella de Carbono' THEN 'HC-4'
						ELSE '' END,
	[Indicador]=a.INDICADOR2,
	[Valor]=ISNULL(Porcentaje,0)/100,
	[Porcentaje]=ISNULL(Porcentaje,0)/100,
	[ValorOriginal]=ISNULL(ValorOriginal,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Medida]='tonCO2e'
	FROM (SELECT ID,ANNO,INDICADOR2,VALOR[Porcentaje] 
			FROM #TempDatosFinales 
			WHERE INDICADOR2 IN ('Reducción de la Huella de Carbono','Neutralización de la Huella de Carbono') AND  MEDIDA='%')  A
	LEFT JOIN 
	     (SELECT ANNO[AÑO],INDICADOR2,VALOR[ValorOriginal]
			FROM #TempDatosFinales 
			WHERE INDICADOR2 IN ('Reducción de la Huella de Carbono','Neutralización de la Huella de Carbono') AND INDICADOR IS NOT NULL) B
	ON A.ANNO=B.[AÑO] AND A.INDICADOR2=B.INDICADOR2
	

	DROP TABLE IF EXISTS #DatosFinales
	DROP TABLE IF EXISTS #TempDatosFinales


	
----Colaboradores
 DROP TABLE IF EXISTS #Colaboradores
 CREATE TABLE #Colaboradores(
	[TIPO] [nvarchar](255) NULL,
	[ENERO] [float] NULL,
	[FEBRERO] [float] NULL,
	[MARZO] [float] NULL,
	[ABRIL] [float] NULL,
	[MAYO] [float] NULL,
	[JUNIO] [float] NULL,
	[JULIO] [float] NULL,
	[AGOSTO] [float] NULL,
	[SETIEMBRE] [float] NULL,
	[OCTUBRE] [float] NULL,
	[NOVIEMBRE] [float] NULL,
	[DICIEMBRE] [float] NULL,
	[ANNO] [nvarchar](255) NULL
	) ON [PRIMARY]

	INSERT INTO #Colaboradores
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Colaboradores.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


	DROP TABLE IF EXISTS #TempColaboradores
	SELECT TIPO,ANNO, MES ,VALOR 
	INTO #TempColaboradores
	FROM   
	   (SELECT TIPO,ANNO,[ENERO],[FEBRERO],[MARZO],[ABRIL],[MAYO],[JUNIO],[JULIO],[AGOSTO],[SETIEMBRE],[OCTUBRE],[NOVIEMBRE],[DICIEMBRE]
	   FROM #Colaboradores WHERE TIPO NOT LIKE '%principal%') p  
	UNPIVOT  
	   (VALOR FOR MES IN   
		  (ENERO,FEBRERO, MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SETIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE)  
	)AS unpvt;  
	

   DROP TABLE IF EXISTS #HC6
   SELECT 
	[N]=6,
	[Id_Indicador]='HC-6',
	[Indicador]='Cantidad de colaboradores mensual solo de Pacific Tower (por modalidad - híbrida y presencial)',
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Modalidad]=CASE WHEN TIPO LIKE '%remoto%' THEN 'Remoto'
					 WHEN TIPO LIKE '%presencial%' THEN 'Presencial'
					 WHEN TIPO LIKE '%híbrida%' THEN 'Híbrido' END,
	[Medida]='Nro Colaboradores'
	INTO #HC6
	FROM #TempColaboradores

	DROP TABLE #Colaboradores
	DROP TABLE #TempColaboradores


----Equipos Fijos
 DROP TABLE IF EXISTS #EquiposFijos
 CREATE TABLE #EquiposFijos(
		[DESCRIPCION EQUIPO] [nvarchar](255) NULL,
		[CODIGO EQUIPO] [nvarchar](255) NULL,
		[COMBUSTIBLE] [nvarchar](255) NULL,
		[MEDIDA] [nvarchar](255) NULL,
		[ENERO]  [float] NULL,
		[FEBRERO] [float] NULL,
		[MARZO]  [float] NULL,
		[ABRIL] [float] NULL,
		[MAYO]  [float] NULL,
		[JUNIO] [float] NULL,
		[JULIO]  [float] NULL,
		[AGOSTO] [float] NULL,
		[SETIEMBRE]  [float] NULL,
		[OCTUBRE] [float] NULL,
		[NOVIEMBRE]  [float] NULL,
		[DICIEMBRE] [float] NULL,
		[ANNO] [nvarchar](255) NULL
	) ON [PRIMARY]
	

	INSERT INTO #EquiposFijos
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Equipos_Fijos.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');



	DROP TABLE IF EXISTS #TempEquiposFijos
		SELECT[DESCRIPCION EQUIPO],[CODIGO EQUIPO],ANNO,MES,VALOR 
	INTO #TempEquiposFijos
	FROM   
	   (SELECT [DESCRIPCION EQUIPO],[CODIGO EQUIPO],ANNO,ISNULL([ENERO],0)[ENERO],ISNULL([FEBRERO],0)[FEBRERO],
				ISNULL([MARZO],0)[MARZO],ISNULL([ABRIL],0)[ABRIL],ISNULL([MAYO],0)[MAYO],ISNULL([JUNIO],0)[JUNIO],
				ISNULL([JULIO],0)[JULIO],ISNULL([AGOSTO],0)[AGOSTO],[SETIEMBRE],ISNULL([OCTUBRE],0)[OCTUBRE],
				ISNULL([NOVIEMBRE],0)[NOVIEMBRE],ISNULL([DICIEMBRE],0)[DICIEMBRE]
	   FROM #EquiposFijos) p  
	UNPIVOT  
	   (VALOR FOR MES IN   
		  (ENERO,FEBRERO,MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SETIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE)  
	)AS unpvt;  
			
	


   DROP TABLE IF EXISTS #HC7
   SELECT 
	[N]=7,
	[Id_Indicador]='HC-7',
	[Indicador]='Consumo de combustible  de equipos fijos propios (grupo eletrógeno)',
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Descripcion]=[DESCRIPCION EQUIPO],
	[CodigoEquipo]=[CODIGO EQUIPO]
	INTO #HC7
	FROM #TempEquiposFijos

	DROP TABLE #EquiposFijos
	DROP TABLE #TempEquiposFijos


----Uso de extintores
 DROP TABLE IF EXISTS #UsoExtintores
 CREATE TABLE #UsoExtintores(
	[TIPO] [nvarchar](255) NULL,
	[MEDIDA] [nvarchar](255) NULL,
	[ENERO] [float] NULL,
	[FEBRERO] [float] NULL,
	[MARZO] [float] NULL,
	[ABRIL] [float] NULL,
	[MAYO] [float] NULL,
	[JUNIO] [float] NULL,
	[JULIO] [float] NULL,
	[AGOSTO] [float] NULL,
	[SETIEMBRE] [float] NULL,
	[OCTUBRE] [float] NULL,
	[NOVIEMBRE] [float] NULL,
	[DICIEMBRE] [float] NULL,
	[TOTAL] [float] NULL,
	[PISO] [nvarchar](255) NULL,
	[UBICACION] [float] NULL,
	[SERIE] [nvarchar](255) NULL,
	[MARCA] [nvarchar](255) NULL,
	[ANNO] [nvarchar](255) NULL
	) ON [PRIMARY]
 

	INSERT INTO #UsoExtintores
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Uso_Extintores.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

	
	DROP TABLE IF EXISTS #TempUsoExtintores
		SELECT  [TIPO],[MEDIDA],[ANNO],[PISO],[UBICACION],[SERIE],[MARCA],[MES],[VALOR]
	INTO #TempUsoExtintores
	FROM   
	   (SELECT [TIPO],[MEDIDA],[ANNO],[PISO],[UBICACION],[SERIE],[MARCA],
		[ENERO],[FEBRERO],[MARZO],[ABRIL],[MAYO],[JUNIO],[JULIO],[AGOSTO],[SETIEMBRE],[OCTUBRE],[NOVIEMBRE],[DICIEMBRE]
	   FROM #UsoExtintores  
	   WHERE 
	   TOTAL IS NOT NULL
	) p  
	UNPIVOT  
	   (VALOR FOR MES IN   
		  (ENERO,FEBRERO,MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SETIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE)  
	)AS unpvt;  




   DROP TABLE IF EXISTS #HC8
   SELECT 
	[N]=8,
	[Id_Indicador]='HC-8',
	[Indicador]='Recarga de extintores (PQS, CO2 y H2OD)',
	[Valor]=CASE WHEN MEDIDA like'%kg%' THEN ISNULL(VALOR,0)
				 WHEN MEDIDA like'%lb%' THEN ISNULL(VALOR,0)*0.453592 
				 WHEN MEDIDA like'%gl%' THEN ISNULL(VALOR,0)*3.785411
				 ELSE 0
			END,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Medida]=MEDIDA,
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Tipo],
	[Piso]=CASE WHEN PISO LIKE '%Oficina%' THEN PISO
				WHEN PISO LIKE '%piso%' AND PISO LIKE '%1%' THEN 'Piso 1'
				WHEN PISO LIKE '%piso%' AND PISO LIKE '%2%' THEN 'Piso 2'
				WHEN PISO LIKE '%piso%' AND PISO LIKE '%3%' THEN 'Piso 3'
				WHEN PISO LIKE '%piso%' AND PISO LIKE '%4%' THEN 'Piso 4'
		   END,
	[Ubicacion]=UBICACION,
	[Serie]=SERIE,
	[Marca]=[MARCA]
	INTO #HC8
	FROM #TempUsoExtintores


	DROP TABLE #UsoExtintores
	DROP TABLE #TempUsoExtintores


----Consumo de energía
 DROP TABLE IF EXISTS #EnergiaElectrica
 CREATE TABLE #EnergiaElectrica(
	[TIPO] [nvarchar](255) NULL,
	[ENERO] [float] NULL,
	[FEBRERO] [float] NULL,
	[MARZO] [float] NULL,
	[ABRIL] [float] NULL,
	[MAYO] [float] NULL,
	[JUNIO] [float] NULL,
	[JULIO] [float] NULL,
	[AGOSTO] [float] NULL,
	[SETIEMBRE] [float] NULL,
	[OCTUBRE] [float] NULL,
	[NOVIEMBRE] [float] NULL,
	[DICIEMBRE] [float] NULL,
	[TOTAL] [float] NULL,
	[ANNO] [nvarchar](255) NULL
	) ON [PRIMARY]

	INSERT INTO #EnergiaElectrica
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Energia_Electrica.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');
		
   	delete from #EnergiaElectrica where TIPO like 'Consumo total%' ------Borrar cuando ya envien la información en la plantilla indicada


	DROP TABLE IF EXISTS #TempEnergiaElectrica
		SELECT  [TIPO],[ANNO],[MES],[VALOR]
	INTO #TempEnergiaElectrica
	FROM   
	   (SELECT [TIPO],[ANNO],
		[ENERO],[FEBRERO],[MARZO],[ABRIL],[MAYO],[JUNIO],[JULIO],[AGOSTO],[SETIEMBRE],[OCTUBRE],[NOVIEMBRE],[DICIEMBRE]
	   FROM #EnergiaElectrica  ) p  
	UNPIVOT  
	   (VALOR FOR MES IN   
		  (ENERO,FEBRERO,MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SETIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE)  
	)AS unpvt;  
	

   DROP TABLE IF EXISTS #HC10
   SELECT 
	[N]=10,
	[Id_Indicador]='HC-10',
	[Indicador]='Consumo de energía eléctrica',
	[Valor]=VALOR,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Tipo]=CASE WHEN TIPO='Consumo en oficinas' THEN 'Oficinas'
		               WHEN TIPO='Consumo en áreas comunes' THEN 'Áreas Comunes' ELSE NULL END
	INTO #HC10
	FROM #TempEnergiaElectrica

	DROP TABLE #EnergiaElectrica
	DROP TABLE #TempEnergiaElectrica


----Consumo de consumo agua potable
 DROP TABLE IF EXISTS #ConsumoAguaPotable
 CREATE TABLE #ConsumoAguaPotable(
	[MEDIDOR] [nvarchar](255) NULL,
	[ENERO] [float] NULL,
	[FEBRERO] [float] NULL,
	[MARZO] [float] NULL,
	[ABRIL] [float] NULL,
	[MAYO] [float] NULL,
	[JUNIO] [float] NULL,
	[JULIO] [float] NULL,
	[AGOSTO] [float] NULL,
	[SETIEMBRE] [float] NULL,
	[OCTUBRE] [float] NULL,
	[NOVIEMBRE] [float] NULL,
	[DICIEMBRE] [float] NULL,
	[TOTAL] [float] NULL,
	[ANNO] [nvarchar](255) NULL
 ) ON [PRIMARY]

    INSERT INTO #ConsumoAguaPotable
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Consumo_Agua_Potable.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


	DROP TABLE IF EXISTS #TempConsumoAguaPotable
		SELECT  [MEDIDOR],[ANNO],[MES],[VALOR]
	INTO #TempConsumoAguaPotable
	FROM   
	   (SELECT [MEDIDOR],[ANNO],
		[ENERO],[FEBRERO],[MARZO],[ABRIL],[MAYO],[JUNIO],[JULIO],[AGOSTO],[SETIEMBRE],[OCTUBRE],[NOVIEMBRE],[DICIEMBRE]
	   FROM #ConsumoAguaPotable  ) p  
	UNPIVOT  
	   (VALOR FOR MES IN   
		  (ENERO,FEBRERO,MARZO,ABRIL,MAYO,JUNIO,JULIO,AGOSTO,SETIEMBRE,OCTUBRE,NOVIEMBRE,DICIEMBRE)  
	)AS unpvt;  
	 	

   DROP TABLE IF EXISTS #HC11
   SELECT 
	[N]=11,
	[Id_Indicador]='HC-11',
	[Indicador]='Consumo de agua potable',
	[Valor]=VALOR,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal'
	INTO #HC11
	FROM #TempConsumoAguaPotable
	
	DROP TABLE #ConsumoAguaPotable
	DROP TABLE #TempConsumoAguaPotable

----Consumo de consumo papel
 DROP TABLE IF EXISTS #ConsumoPapel
 CREATE TABLE #ConsumoPapel(
		[DESCRIPCION] [nvarchar](255) NULL,
		[MARCA] [nvarchar](255) NULL,
		[TIPO] [nvarchar](255) NULL,
		[GRAMAJE UNIDAD] [varchar](255) NULL,
		[TAMANO] [nvarchar](255) NULL,
		[EMPAQUES] [float] NULL,
		[UNIDAD EMPAQUE] [float] NULL,
		[DETALLE] [nvarchar](255) NULL,
		[AREA] [nvarchar](255) NULL,
		[ANNO] [nvarchar](255) NULL
	) ON [PRIMARY]
	


	INSERT INTO #ConsumoPapel
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Consumo_Papel.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

   DROP TABLE IF EXISTS #HC12
   SELECT 
	[N]=12,
	[Id_Indicador]='HC-12',
	[Indicador]='Consumo de papel',
	[Valor]=EMPAQUES,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(EMPAQUES,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Descripcion]=DESCRIPCION,
	[Marca]=MARCA,
	[Tipo]=TIPO,
	[Gramaje]=[GRAMAJE UNIDAD],
	[Tamaño]=TAMANO,
	[Unidad]=[UNIDAD EMPAQUE],
	[Detalle]=DETALLE,
	[Area]=AREA
	INTO #HC12
	FROM #ConsumoPapel

	DROP TABLE #ConsumoPapel


----Viajes aéreos
 DROP TABLE IF EXISTS #ViajesAereos
    SELECT *
    INTO #ViajesAereos
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Viajes_Aereos.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

 DROP TABLE IF EXISTS #HC13
   SELECT 
	[N]=13,
	[Id_Indicador]='HC-13',
	[Indicador]='Viajes aéreos a nivel nacional e internacional',
	[Valor]=DISTANCIA,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(DISTANCIA,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Usuario]=[dbo].[InitCap](USUARIO),
	[Salida]=SALIDA,
	[Retorno]=[RETORNO],
	[Ruta]=[dbo].[InitCap]([Ruta]),
	[Origen]=[dbo].[Funcion_separar_por_columnas](Ruta, 1, '/'),
	[Destino1]=[dbo].[Funcion_separar_por_columnas](Ruta, 2, '/'),
	[Destino2]=[dbo].[Funcion_separar_por_columnas](Ruta, 3, '/'),
	[Detalle]=[DETALLE FACTURA]
	INTO #HC13
	FROM #ViajesAereos WHERE USUARIO NOT IN ('Total Km')

	DROP TABLE #ViajesAereos


----Viajes terrestres
 DROP TABLE IF EXISTS #ViajesTerrestres
    SELECT *
    INTO #ViajesTerrestres
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Viajes_Terrestres.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

 DROP TABLE IF EXISTS #HC14
   SELECT 
	[N]=14,
	[Id_Indicador]='HC-14',
	[Indicador]='Viajes terrestres a nivel nacional',
	[Valor]=DISTANCIA,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(DISTANCIA,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Usuario]=USUARIO,
	[Salida]=SALIDA,
	[Retorno]=[RETORNO],
	[Origen]=ORIGEN,
	[Destino1]=DESTINO,
	[Detalle]=[DETALLE FACTURA]
	INTO #HC14
    FROM #ViajesTerrestres WHERE DISTANCIA IS NOT NULL

  DROP TABLE #ViajesTerrestres



----Uso taxi caja chica
 DROP TABLE IF EXISTS #TaxiCajaChica
    SELECT *
    INTO #TaxiCajaChica
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Taxi_Caja_Chica.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


  DROP TABLE IF EXISTS #HC15
   SELECT 
	[N]=15,
	[Id_Indicador]='HC-15',
	[Indicador]='Uso de taxi - caja chica',
	[Valor]=MONTO,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(MONTO,0),
	[Fecha]=CONVERT(DATE,FECHA),
	[Agencia]='Principal',
	[Origen]=ORIGEN,
	[Destino1]=DESTINO,
	[Detalle]=[DETALLE FACTURA]
	INTO #HC15
    FROM #TaxiCajaChica WHERE MONTO IS NOT NULL

  DROP TABLE #TaxiCajaChica



----Uso taxi 
 DROP TABLE IF EXISTS #Taxi
    SELECT *
    INTO #Taxi
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Uso_Taxi.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

   DROP TABLE IF EXISTS #HC16
   SELECT 
	[N]=16,
	[Id_Indicador]='HC-16',
	[Indicador]='Uso de taxi',
	[Valor]=MONTO,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(MONTO,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Proveedor]=PROVEEDOR,
	[Medio]=MEDIO,
	[Detalle]=[DETALLE FACTURA]
	INTO #HC16
    FROM #Taxi

  DROP TABLE #Taxi


----Residuos Sólidos
 DROP TABLE IF EXISTS #RRSS
    SELECT *
    INTO #RRSS
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Residuos_Solidos.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


----Traslado trabajo casa
 DROP TABLE IF EXISTS #TrasladoTrabajoCasa
    SELECT *
    INTO #TrasladoTrabajoCasa
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Casa_Trabajo.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

   DROP TABLE IF EXISTS #HC17
   SELECT 
	[N]=17,
	[Id_Indicador]='HC-17',
	[Indicador]='Traslado casa-trabajo*',
	[Valor]=[RECORRIDO ANUAL],
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL([RECORRIDO ANUAL],0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Dias]=DIAS,
	[IdaVuelta]=[IDA Y VUELTA],
	[Medio]=MEDIO,
	[Modalidad]=[MODALIDAD]
	INTO #HC17
    FROM #TrasladoTrabajoCasa

  DROP TABLE #TrasladoTrabajoCasa

  
----Residuos generales 
 DROP TABLE IF EXISTS #Residuos_Generales
 CREATE TABLE #Residuos_Generales(
	[MES] [nvarchar](255) NULL,
	[PLASTICO] [nvarchar](255) NULL,
	[PAPEL] [nvarchar](255) NULL,
	[CARTON] [nvarchar](255) NULL,
	[VIDRIO] [nvarchar](255) NULL,
	[GENERALES] [nvarchar](255) NULL,
	[ANNO] [nvarchar](255) NULL,
 ) ON [PRIMARY]

    INSERT INTO #Residuos_Generales
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Residuos_Generales.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


	DROP TABLE IF EXISTS #TempResiduos_Generales
		SELECT MES,ANNO,TIPO,VALOR 
	INTO #TempResiduos_Generales
	FROM   
	   (SELECT [MES],[ANNO],[PLASTICO],[PAPEL],[CARTON],[VIDRIO],[GENERALES]
	   FROM #Residuos_Generales 
	   WHERE MES not in('Total','Residuos','Dato%')) p  
	UNPIVOT  
	   (VALOR FOR TIPO IN 
		  ([PLASTICO],[PAPEL],[CARTON],[VIDRIO],[GENERALES])  
	)AS unpvt;  
	  


   DROP TABLE IF EXISTS #HC18
   SELECT 
	[N]=18,
	[Id_Indicador]='HC-18',
	[Indicador]='Generación de residuos sólidos',
	[Valor]=CONVERT(FLOAT,ISNULL(VALOR,0))/10000,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=CASE 
			WHEN Mes = 'Enero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-01'+ '-01' AS DATE)))
			WHEN Mes = 'Febrero' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-02'+ '-01' AS DATE)))
			WHEN Mes = 'Marzo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-03'+ '-01' AS DATE)))
			WHEN Mes = 'Abril' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-04'+ '-01' AS DATE)))
			WHEN Mes = 'Mayo' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-05'+ '-01' AS DATE)))
			WHEN Mes = 'Junio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-06'+ '-01' AS DATE)))
			WHEN Mes = 'Julio' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-07'+ '-01' AS DATE)))
			WHEN Mes = 'Agosto' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-08'+ '-01' AS DATE)))
			WHEN Mes = 'Setiembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-09'+ '-01' AS DATE)))
			WHEN Mes = 'Octubre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-10'+ '-01' AS DATE)))
			WHEN Mes = 'Noviembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-11'+ '-01' AS DATE)))
			WHEN Mes = 'Diciembre' THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, CAST(CONVERT(VARCHAR(4),ANNO)+'-12'+ '-01' AS DATE)))
    END,
	[Agencia]='Principal',
	[Medida]='Kg',
	[Tipo]=TIPO
	INTO #HC18
	FROM #TempResiduos_Generales 
	
	DROP TABLE #Residuos_Generales
	DROP TABLE #TempResiduos_Generales


					
----Residuos generales 
 DROP TABLE IF EXISTS #Aprovechables_Entregados
    SELECT *
    INTO #Aprovechables_Entregados
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Aprovechables_Entregados.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

   DROP TABLE IF EXISTS #HC19
   SELECT 
	[N]=19,
	[Id_Indicador]='HC-19',
	[Indicador]='Reciclaje de residuos sólidos',
	[Valor]=CONVERT(FLOAT,ISNULL(CANTIDAD,0))/10000,
	[Porcentaje]=0,
	[ValorOriginal]=ISNULL(CANTIDAD,0),
	[Fecha]=CONVERT(DATE,ANNO),
	[Agencia]='Principal',
	[Medida]='Kg',
	[Tipo]=UPPER(REPLACE(REPLACE(REPLACE(CONCEPTO,'Ó','O'),'É','E'),'Á','A')),
	[Autorizado]=AUTORIZADO,
	[Donado]=DONADO
	INTO #HC19
	FROM #Aprovechables_Entregados 
	
	DROP TABLE #Aprovechables_Entregados

----Cantidad Dispuesto
   DROP TABLE IF EXISTS #HC20
   SELECT 
	[N]=20,
	[Id_Indicador]='HC-20',
	[Indicador]='Cantidad Anual Dispuesto RRSS',
	[Valor]=CONVERT(DECIMAL(10,5),(ISNULL(a.Valor,0)-ISNULL(b.Valor,0))),
	[Porcentaje]=0,
	[ValorOriginal]=CONVERT(DECIMAL(10,5),(ISNULL(a.Valor,0)-ISNULL(b.Valor,0))),
	[Fecha]=DATEFROMPARTS(YEAR(A.FECHA), 12, 31),
	[Agencia]='Principal',
	[Medida]='Ton',
	[Tipo]=a.Tipo
	INTO #HC20
	FROM #HC18 a LEFT JOIN #HC19 b on YEAR(a.Fecha)=YEAR(b.Fecha) AND a.Tipo=b.Tipo 

	

----Percápita Energía eléctrica y agua potable

	DROP TABLE IF EXISTS #COLAB
	SELECT FECHA,SUM(VALOR)COLABORADORES 
	INTO #COLAB
	FROM #HC6
	GROUP BY FECHA

	DROP TABLE IF EXISTS #EE
	SELECT FECHA,SUM(VALOR)EE 
	INTO #EE
	FROM #HC10
	GROUP BY FECHA

	DROP TABLE IF EXISTS #AGUA
	SELECT FECHA,SUM(VALOR)AGUA
	INTO #AGUA
	FROM #HC11
	GROUP BY FECHA

	DROP TABLE IF EXISTS #HC21
	SELECT 
	[N]=21,
	[Id_Indicador]='HC-21',
	[Indicador]='Per cápita Consumo de Energía Eléctrica',
	[Valor]=EE/COLABORADORES,
	[Porcentaje]=0,
	[ValorOriginal]=EE/COLABORADORES,
	[Fecha]=#EE.Fecha,
	[Agencia]='Principal'
	INTO #HC21
	FROM #EE 
	LEFT JOIN #COLAB
	ON #EE.Fecha=#COLAB.Fecha


	DROP TABLE IF EXISTS #HC22
	SELECT 
	[N]=21,
	[Id_Indicador]='HC-22',
	[Indicador]='Per cápita Consumo de Agua Potable',
	[Valor]=AGUA/COLABORADORES,
	[Porcentaje]=0,
	[ValorOriginal]=AGUA/COLABORADORES,
	[Fecha]=#AGUA.Fecha,
	[Agencia]='Principal'
	INTO #HC22
	FROM #AGUA 
	LEFT JOIN #COLAB
	ON #AGUA.Fecha=#COLAB.Fecha

					
----Equidad de Género
 DROP TABLE IF EXISTS #EGenero
 CREATE TABLE #EGenero(
	[N] [float] NULL,
	[INDICADOR] [nvarchar](255) NULL,
	[UNIDAD] [nvarchar](255) NULL,
	[2021] float NULL,
	[2022] float NULL,
	[2023] float NULL,
	[2024] float NULL,
	[2025] float NULL,
	) ON [PRIMARY]
	

	INSERT INTO #EGenero
    SELECT *
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Equidad_Genero.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

	DROP TABLE IF EXISTS #TempEGenero
		SELECT  [INDICADOR],[ANNIO],[UNIDAD],[VALOR]
	INTO #TempEGenero
	FROM   
	   (SELECT [INDICADOR],[UNIDAD],
		[2021],[2022],[2023],[2024],[2025]
	   FROM #EGenero  ) p  
	UNPIVOT  
	   (VALOR FOR ANNIO IN   
		  ([2021],[2022],[2023],[2024],[2025])  
	)AS unpvt;  
	  

   DROP TABLE IF EXISTS #EG
   SELECT 
	[N]=23,
	[Id_Indicador]='EG-1',
	[Indicador]='Mujeres en puestos gerenciales',
	[Valor]=A.VALOR,
	[Porcentaje]=A.VALOR,
	[ValorOriginal]=B.VALOR,
	[Fecha]=DATEFROMPARTS(A.ANNIO, 12, 31),
	[Agencia]='Principal'
	INTO #EG
	FROM (SELECT * FROM  #TempEGenero where unidad='%' and indicador='Mujeres en puestos gerenciales**')  A
	LEFT JOIN  (SELECT * FROM  #TempEGenero where unidad='Número' and indicador='Mujeres en puestos gerenciales**')  B
	ON A.INDICADOR=B.INDICADOR AND A.ANNIO=B.ANNIO

	UNION
    SELECT 
	[N]=24,
	[Id_Indicador]='EG-2',
	[Indicador]='Proporción de mujeres en el personal',
	[Valor]=A.VALOR,
	[Porcentaje]=A.VALOR,
	[ValorOriginal]=B.VALOR,
	[Fecha]=DATEFROMPARTS(A.ANNIO, 12, 31),
	[Agencia]='Principal'
	FROM (SELECT * FROM  #TempEGenero where unidad='%' and indicador='Proporción de mujeres en el personal**')  A
	LEFT JOIN  (SELECT * FROM  #TempEGenero where unidad='Número' and indicador='Proporción de mujeres en el personal**')  B
	ON A.INDICADOR=B.INDICADOR AND A.ANNIO=B.ANNIO

	UNION
    SELECT 
	[N]=25,
	[Id_Indicador]='EG-3',
	[Indicador]='Personal capacitado en temas de género e inclusión (por género)',
	--[Valor]=REPLACE(REPLACE([dbo].[Funcion_separar_por_columnas](VALOR, 1, '/'),'M',''),' ',''),
	[Valor]=VALOR,
	[Porcentaje]=0,
	[ValorOriginal]=VALOR,
	[Fecha]=DATEFROMPARTS(ANNIO, 12, 31),
	[Agencia]='Principal'
	FROM  #TempEGenero where unidad='Número' and  Indicador='Personal capacitado en temas de género e inclusión (por género)'

	UNION
	SELECT 
	[N]=26,
	[Id_Indicador]='EG-4',
	[Indicador]='Capacitaciones ofrecidas al personal en temas de género e inclusión',
	[Valor]=VALOR,
	[Porcentaje]=0,
	[ValorOriginal]=VALOR,
	[Fecha]=DATEFROMPARTS(ANNIO, 12, 31),
	[Agencia]='Principal'
	FROM  #TempEGenero  where unidad='Número' and Indicador='Capacitaciones ofrecidas al personal en temas de género e inclusión'

	DROP TABLE #EGenero
	DROP TABLE #TempEGenero


----Programa SARAS
 DROP TABLE IF EXISTS #SARAS
    SELECT *
    INTO #SARAS
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Saras.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');

   DROP TABLE IF EXISTS #SA
   SELECT 
	[N]=27,
	[Id_Indicador]='SA-1',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	 INTO #SA
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-1')
	
	UNION
	SELECT 
	[N]=28,
	[Id_Indicador]='SA-2',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-2')

	UNION
	SELECT 
	[N]=29,
	[Id_Indicador]='SA-3',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-3')

	UNION
	SELECT 
	[N]=30,
	[Id_Indicador]='SA-4',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-4')

	UNION
	SELECT 
	[N]=31,
	[Id_Indicador]='SA-5',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-5')

	UNION
	SELECT 
	[N]=32,
	[Id_Indicador]='SA-6',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-6')

	UNION
	SELECT 
	[N]=33,
	[Id_Indicador]='SA-7',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-7')

	UNION
	SELECT 
	[N]=34,
	[Id_Indicador]='SA-8',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-8')

	UNION
	SELECT 
	[N]=35,
	[Id_Indicador]='SA-9',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-9')

	UNION
	SELECT 
	[N]=36,
	[Id_Indicador]='SA-10',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(VALOR,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-10')

	UNION
	SELECT 
	[N]=37,
	[Id_Indicador]='SA-11',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-11')

	UNION
	SELECT 
	[N]=37,
	[Id_Indicador]='SA-12',
	[Indicador]=DESCRIPCION,
	[Valor]=ISNULL(PORCENTAJE,0),
	[Porcentaje]=ISNULL(PORCENTAJE,0),
	[ValorOriginal]=ISNULL(VALOR,0),
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal'
	FROM #SARAS WHERE DESCRIPCION IN
	(SELECT DISTINCT Indicador FROM ST_INDICADORES_SOSTENIBILIDAD WHERE IdIndicador='SA-12')



----Programa Kimochi
 DROP TABLE IF EXISTS #Kimochi
    SELECT *
    INTO #Kimochi
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Sostenibilidad\Kimochi.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Sheet1$]');


   DROP TABLE IF EXISTS #PVK1
   SELECT 
	[N]=23,
	[Id_Indicador]='PVK-1',
	[Indicador]='Cantidad de horas de voluntariado',
	[Valor]=[HORAS TOTALES],
	[Porcentaje]=0,
	[ValorOriginal]=[HORAS TOTALES],
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Medida]='Horas',
	[Actividad]=ACTIVIDAD
	INTO #PVK1
	FROM #Kimochi 

   DROP TABLE IF EXISTS #PVK3
   SELECT 
	[N]=24,
	[Id_Indicador]='PVK-3',
	[Indicador]=' Cantidad de participantes ',
	[Valor]=PARTICIPANTES,
	[Porcentaje]=0,
	[ValorOriginal]=PARTICIPANTES,
	[Fecha]=DATEFROMPARTS(ANNO, 12, 31),
	[Agencia]='Principal',
	[Medida]='N° Participantes',
	[Actividad]=ACTIVIDAD
	INTO #PVK3
	FROM #Kimochi 
		
	DROP TABLE #Kimochi


----CONSOLIDAR INDICADORES 
DROP TABLE IF EXISTS #INDICADORES_SOSTENIBILIDAD
CREATE TABLE #INDICADORES_SOSTENIBILIDAD(
	[N] [int] NULL,
	[IdIndicador] [varchar](6) NULL,
	[Indicador] [varchar](150) NULL,
	[Valor] [float] NULL,
	[Porcentaje] [float] NULL,
	[ValorOriginal] [float] NULL,
	[Medida] [varchar](20) NULL,
	[Fecha] [date] NULL,
	[Agencia] [varchar](50) NULL,
	[Modalidad] [varchar](20) NULL,
	[Descripcion] [varchar](100) NULL,
	[CodigoEquipo] [varchar](100) NULL,
	[Piso] [varchar](20) NULL,
	[Ubicacion] int NULL,
	[Serie] [varchar](50) NULL,
	[Marca] [varchar](50) NULL,
	[Tipo] [varchar](50) NULL,
	[Gramaje] [varchar](50) NULL,
	[Tamaño][varchar](50) NULL,
	[Unidad] int NULL,
	[Detalle] [varchar](150) NULL,
	[Area] [varchar](50) NULL,
	[Usuario] [varchar](150) NULL,
	[Salida] [date] NULL,
	[Retorno] [date] NULL,
	[Origen] [varchar](100) NULL,
	[Ruta] [varchar](200) NULL,
	[Destino1] [varchar](100) NULL,
	[Destino2] [varchar](100) NULL,
	[Proveedor] [varchar](100) NULL,
	[Medio] [varchar](100) NULL,
	[Dias] int NULL,
	[IdaVuelta] int NULL,
	[Autorizado] varchar(2),
	[Donado] varchar(2),
	[Actividad] [varchar](100) NULL,
	[Sexo] [varchar](100) NULL,
	[FechaCarga] [datetime] NULL
) ON [PRIMARY]


----Hoja Datos Finales

	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,GETDATE()
	FROM #HC1234;

----Indicador HC-5 -"Personal capacitado en huella de carbono"

	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,FechaCarga)
	VALUES
    (5,'HC-5','Personal capacitado en huella de carbono',11,0,11,'2022-12-31','Principal',GETDATE())


----Hoja Colaboradores
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Modalidad,Medida,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Modalidad,Medida,GETDATE()
	FROM #HC6;
	
----Hoja Equipos Fijos
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Descripcion,CodigoEquipo,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Descripcion,CodigoEquipo,GETDATE()
	FROM #HC7;

----Hoja Uso de Extintores
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,Tipo,Piso,Ubicacion,Serie,Marca,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,Tipo,Piso,Ubicacion,Serie,Marca,GETDATE()
	FROM #HC8;

----Indicador HC-9 -"Recarga de gas refrigerante en sistema de A/C - Mantenimiento"

	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,Fecha,Agencia,FechaCarga)
	VALUES
    (9,'HC-9','PRecarga de gas refrigerante en sistema de A/C - Mantenimiento',0,0,'2021-12-31','Principal',GETDATE())
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,Fecha,Agencia,FechaCarga)
	VALUES
	(9,'HC-9','PRecarga de gas refrigerante en sistema de A/C - Mantenimiento',0,0,'2022-12-31','Principal',GETDATE())
		INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,Fecha,Agencia,FechaCarga)
	VALUES
	(9,'HC-9','PRecarga de gas refrigerante en sistema de A/C - Mantenimiento',0,0,'2023-12-31','Principal',GETDATE())

----Hoja Consumo de EE
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Tipo,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Tipo,GETDATE()
	FROM #HC10;

----Hoja Consumo de Agua Potable
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,GETDATE()
	FROM #HC11;

----Hoja Consumo papel
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Descripcion,Marca,Tipo,Gramaje,Tamaño,Unidad,Detalle,Area,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Descripcion,Marca,Tipo,Gramaje,Tamaño,Unidad,Detalle,Area,GETDATE()
	FROM #HC12;


----Hoja Viajes áereos
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Usuario,Salida,Retorno,Origen,Ruta,Destino1,Destino2,Detalle,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Usuario,Salida,Retorno,Origen,Ruta,Destino1,Destino2,Detalle,GETDATE()
	FROM #HC13;


----Hoja Viajes terrestres
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Usuario,Salida,Retorno,Origen,Destino1,Detalle,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Usuario,Salida,Retorno,Origen,Destino1,Detalle,GETDATE()
	FROM #HC14;


----Hoja Taxi - caja chica
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Origen,Destino1,Detalle,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Origen,Destino1,Detalle,GETDATE()
	FROM #HC15;	

----Hoja Taxi 
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Proveedor,Medio,Detalle,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Proveedor,Medio,Detalle,GETDATE()
	FROM #HC16;	

----Hoja Taxi 
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											 Dias,IdaVuelta,Medio,Modalidad,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Dias,IdaVuelta,Medio,Modalidad,GETDATE()
	FROM #HC17;	


----Hoja Residuos Generados 
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											Medida,Tipo,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,Tipo,GETDATE()
	FROM #HC18 order by fecha asc;	

----Hoja Residuos Generados 
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											Medida,Tipo,Autorizado,Donado,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,Tipo,Autorizado,Donado,GETDATE()
	FROM #HC19;	

----Indicador HC20 
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											Medida,Tipo,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Medida,Tipo,GETDATE()
	FROM #HC20 order by fecha asc;	


----Indicador HC21
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,GETDATE()
	FROM #HC21;	


----Indicador HC22
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,
											FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,GETDATE()
	FROM #HC22;	



----Programa Voluntariado Kimochi
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Actividad,
											FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Actividad,GETDATE()
	FROM #PVK1;	

----Indicador PVK-2 -"Inversión en actividades"

	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,FechaCarga)
	VALUES
    (2,'PVK-2','Inversión en actividades',16516.86 ,0,16516.86,'2022-12-31','Principal',GETDATE())

----#PVK3
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,Actividad,
											FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,'Principal',Actividad,GETDATE()
	FROM #PVK3;	

	  
----Equidad Genero
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Agencia,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,'Principal',GETDATE() FROM #EG

/*
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,Sexo,
											FechaCarga)
	SELECT RIGHT(IdIndicador,1),IdIndicador,IdIndicador,Valor,0,Valor,Fecha,Sexo,GETDATE() 
	FROM ST_INDICADORES_SOSTENIBILIDAD_DATA
	WHERE IdIndicador like 'EG%'
	*/

----Saras
	INSERT INTO #INDICADORES_SOSTENIBILIDAD (N,IdIndicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,FechaCarga)
	SELECT N,Id_Indicador,Indicador,Valor,Porcentaje,ValorOriginal,Fecha,GETDATE() FROM #SA
/*
	SELECT RIGHT(IdIndicador,1),IdIndicador,IdIndicador,Valor,Porcentaje,Valor,Fecha,GETDATE() 
	FROM ST_INDICADORES_SOSTENIBILIDAD_DATA
	WHERE IdIndicador like 'SA%' 
	*/


	DROP TABLE IF EXISTS ST_INDICADORES_SOSTENIBILIDAD_DATA
	SELECT *
	INTO ST_INDICADORES_SOSTENIBILIDAD_DATA
	FROM #INDICADORES_SOSTENIBILIDAD


	SELECT * 
	--INTO  ST_INDICADORES_SOSTENIBILIDAD_DATA_BK
	FROM ST_INDICADORES_SOSTENIBILIDAD_DATA WHERE IDINDICADOR='EG-3'

	--update a 
	--set Indicador='Proporción de mujeres en el personal'
	----select * 
	--from ST_INDICADORES_SOSTENIBILIDAD a where idindicador='EG-2'

	--Emisiones de GEI per cápita’


	