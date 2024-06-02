USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dwt_actualizar_dinerofresco]    Script Date: 22/05/2024 16:53:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_FCD_ingresar_datos_bases_externas]
as

DECLARE @FECHA DATE = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE estado = 1)
DECLARE @FECHAREPORTE DATE =(SELECT DATEFROMPARTS(YEAR(DATEADD(YEAR, -2, @FECHA)), 1, 1))
DECLARE @TC DECIMAL(15,3) = '3.697'

MERGE INTO ST_FCI_BASESEXTERNAS AS A
USING Temp_Bases_Externas AS B
ON A.id = B.id AND 
   A.Moneda = B.Moneda AND 
   A.Fecha = B.Fecha

WHEN MATCHED THEN
    UPDATE SET
        A.Indicador1 = B.Indicador1,
        A.Indicador2 = B.Indicador2,
        A.Descripción = B.Descripción,
        A.Monto = B.Monto,
        A.FechaActualizacion = GETDATE()

WHEN NOT MATCHED BY TARGET THEN
    INSERT (id, Indicador1, Indicador2, Descripción, Moneda, Monto, Fecha, FechaCarga, FechaActualizacion)
    VALUES (B.id, B.Indicador1, B.Indicador2, B.Descripción, B.Moneda, B.Monto, B.Fecha, GETDATE(), GETDATE())

WHEN NOT MATCHED BY SOURCE THEN
    DELETE;



DROP TABLE IF EXISTS #TEMP_BASES_EXTERNAS
SELECT 
	be.ID,
	NOMBRE=be.Indicador2,
	be.MONEDA,
	be.MONTO,
	MONTO_S=IIF(be.MONEDA='DOLARES',be.MONTO*ISNULL(tc.PROMEDIO,@TC),be.MONTO),
	FORMAT(Fecha, 'yyyy-MM')PERIODO 
INTO #TEMP_BASES_EXTERNAS
FROM ST_FCI_BASESEXTERNAS be
LEFT JOIN DW_TIPOCAMBIOAJUSTE tc
ON FORMAT(be.Fecha, 'yyyy-MM')=FORMAT(tc.FECHACAMBIO, 'yyyy-MM')
WHERE be.Monto>0


DROP TABLE IF EXISTS #BASES_EXTERNAS
SELECT ID, NOMBRE,PERIODO,SUM(MONTO)MONTO,SUM(MONTO_S)MONTO_S 
INTO #BASES_EXTERNAS
FROM #TEMP_BASES_EXTERNAS
GROUP BY  ID, NOMBRE,PERIODO



DELETE FROM WT_FLUJO_CAJA_DIRECTA WHERE ID IN (SELECT DISTINCT ID FROM ST_FCI_BASESEXTERNAS )
INSERT INTO WT_FLUJO_CAJA_DIRECTA
SELECT *, @FECHA FROM #BASES_EXTERNAS
