USE [TemporalesDW]
GO

INSERT INTO ST_INDICADORES_PASSWORD
Select 'Prueba'[Usuario], '12345678'[Contraseņa] 


CREATE TABLE ST_INDICADORES_PASSWORD (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Usuario NVARCHAR(50),
    Contraseņa  NVARCHAR(50)
);


CREATE TABLE ST_FECHA_VALIDADA (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Usuario NVARCHAR(50),
    Fecha DATE,
    FechaRegistro DATETIME
);


SELECT * FROM ST_FECHA_VALIDADA

INSERT ST_FECHA_VALIDADA VALUES('Prueba',convert(Date,'2023-12-12 00:00:00'),GETDATE())

EXEC [dbo].[usp_dash_calendario]