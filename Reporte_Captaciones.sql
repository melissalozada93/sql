USE [DWCOOPAC]
GO

-----------------------------------------------------------------------------------------------
--*********************1.Importe de dep�sitos a plazo por fecha soles************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT FECHAAPERTURA[FECHA],
SUM(DF)[DINERO FRESCO S/.],
SUM(DNF)[DINERO NO FRESCO S/.]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_SOLES='SI' 
GROUP BY FECHAAPERTURA
ORDER BY FECHAAPERTURA DESC

-----------------------------------------------------------------------------------------------
--********************1.Importe de dep�sitos a plazo por fecha d�lares***********************--
-----------------------------------------------------------------------------------------------


DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT FECHAAPERTURA[FECHA],
SUM(DF)[DINERO FRESCO $],
SUM(DNF)[DINERO NO FRESCO $]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_DOLARES='SI' 
GROUP BY FECHAAPERTURA
ORDER BY FECHAAPERTURA DESC


-----------------------------------------------------------------------------------------------
--*************************2.Dep�sitos a plazo por subproducto soles*************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT [FILTRO_CANAL],
[SUBPRODUCTO],
SUM(DF)[DINERO FRESCO S/.],
SUM(DNF)[DINERO NO FRESCO S/.]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_SOLES='SI' 
GROUP BY FILTRO_CANAL,SUBPRODUCTO
ORDER BY FILTRO_CANAL ASC


-----------------------------------------------------------------------------------------------
--**********************2.Dep�sitos a plazo por subproducto d�lares*************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT [FILTRO_CANAL],
[SUBPRODUCTO],
SUM(DF)[DINERO FRESCO $],
SUM(DNF)[DINERO NO FRESCO $]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_DOLARES='SI' 
GROUP BY FILTRO_CANAL,SUBPRODUCTO
ORDER BY FILTRO_CANAL ASC



-----------------------------------------------------------------------------------------------
--***************************3.Dep�sitos a plazo por agencias soles**************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT agencia_apert [AGENCIA],
SUM(DF)[DINERO FRESCO S/.],
SUM(DNF)[DINERO NO FRESCO S/.]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_SOLES='SI' 
GROUP BY agencia_apert
ORDER BY agencia_apert ASC



-----------------------------------------------------------------------------------------------
--***********************3.Dep�sitos a plazo por agencias d�lares****************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT agencia_apert [AGENCIA],
SUM(DF)[DINERO FRESCO $],
SUM(DNF)[DINERO NO FRESCO $]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_DOLARES='SI' 
GROUP BY agencia_apert
ORDER BY agencia_apert ASC


-----------------------------------------------------------------------------------------------
--***********************4.Tasa anual promedio por subproducto soles*************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT [FILTRO_CANAL],
[SUBPRODUCTO],
[RENOV.]=AVG(CASE WHEN FILTRO_FRS_RNV='RENOV.' THEN tasaintanualactual ELSE 0 END),
[DINERO FRESCO]=AVG(CASE WHEN FILTRO_FRS_RNV='DINERO FRESCO' THEN tasaintanualactual ELSE 0 END)
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_SOLES='SI' 
GROUP BY FILTRO_CANAL,SUBPRODUCTO
ORDER BY FILTRO_CANAL DESC


-----------------------------------------------------------------------------------------------
--*********************4.Tasa anual promedio por subproducto dolares*************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT [FILTRO_CANAL],
[SUBPRODUCTO],
[RENOV.]=AVG(CASE WHEN FILTRO_FRS_RNV='RENOV.' THEN tasaintanualactual ELSE 0 END),
[DINERO FRESCO]=AVG(CASE WHEN FILTRO_FRS_RNV='DINERO FRESCO' THEN tasaintanualactual ELSE 0 END)
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_DOLARES='SI' 
GROUP BY FILTRO_CANAL,SUBPRODUCTO
ORDER BY FILTRO_CANAL DESC


-----------------------------------------------------------------------------------------------
--***********************5.Dep�sitos a plazo por n�mero de d�as soles************************--
-----------------------------------------------------------------------------------------------

DECLARE @CAMPANA VARCHAR(20);
SET @CAMPANA = (
					SELECT CAMPA�A FROM   [dbo].[ST_CAMPANAS]
					WHERE INICIO<=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA) AND FIN>=(SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA));


SELECT [NUMERODIAS],
SUM(DF)[DINERO FRESCO S/.],
SUM(DNF)[DINERO NO FRESCO S/.]
FROM WT_DINERO_FRESCO_DPF WHERE CAMPA�A=@CAMPANA AND PROD_SOLES='SI' 
GROUP BY NUMERODIAS
ORDER BY NUMERODIAS ASC
