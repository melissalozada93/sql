USE [DWCOOPAC44]
GO
/****** Object:  StoredProcedure [dbo].[usp_z_historicos1mes]    Script Date: 29/10/2023 16:30:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_migracion_64_44]
	@TableName VARCHAR(100),-- = 'DW_PRESTAMO'
	@ColumnDate VARCHAR(100), --= 'DW_FECHACARGA'
	@FechaCarga date
as
    set nocount on
    set xact_abort on
	begin transaction
	begin try

		--DECLARE @TableName VARCHAR(100)='DW_PRESTAMO' 
		--DECLARE @ColumnDate VARCHAR(100) = 'DW_FECHACARGA'
		--DECLARE @FechaCarga date='2023-09-30'

		DECLARE @Server VARCHAR(100)='[192.168.9.64]'
		DECLARE @Database VARCHAR(100)='DWCOOPAC'
		DECLARE @Schema VARCHAR(100)='dbo'
		DECLARE @TableNameServer VARCHAR(100) = CONCAT(@Server,'.',@Database,'.',@Schema,'.',@TableName)
		DECLARE @PrefTable varchar(2) = 'Z_'
		DECLARE @TableNameDW VARCHAR(100) =CONCAT(@Database,'.',@Schema,'.',@TableName)
		DECLARE @TableNameZ VARCHAR(100) =CONCAT(@Database,'.',@Schema,'.',@PrefTable,@TableName)
		DECLARE @TableNameServerZ VARCHAR(100) = CONCAT(@Server,'.',@Database,'.',@Schema,'.',@PrefTable,@TableName)

		DECLARE @SQLString NVARCHAR(4000)
		SET @SQLString  = N'

			if exists(select top 1 '+ @ColumnDate +' from '+@TableNameDW+' where '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +''') 
			BEGIN
				DELETE FROM '+@TableNameDW+' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''

				INSERT INTO '+@TableNameDW+'
				SELECT * FROM '+ @TableNameServer +' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''

				insert into LOG_TABLAS_64 (log_fecha, log_id, log_tabla, log_estado) 
				select getdate(), (select isnull(max(log_id),0) from LOG_TABLAS_64)+1, '''+@TableNameDW+''', 1

			END
			ELSE
			BEGIN

				INSERT INTO '+@TableNameDW+'
				SELECT * FROM '+ @TableNameServer +' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''

				insert into LOG_TABLAS_64 (log_fecha, log_id, log_tabla, log_estado) 
				select getdate(), (select isnull(max(log_id),0) from LOG_TABLAS_64)+1, '''+@TableNameDW+''', 2

			END'



		DECLARE @SQLStringZ NVARCHAR(4000)
		SET @SQLStringZ  = N'

			if exists(select top 1 '+ @ColumnDate +' from '+@TableNameZ+' where '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +''') 
			BEGIN
				DELETE FROM '+@TableNameZ+' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''

				INSERT INTO '+@TableNameZ+'
				SELECT * FROM '+ @TableNameServerZ +' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''
				
				insert into LOG_TABLAS_64 (log_fecha, log_id, log_tabla, log_estado) 
				select getdate(), (select isnull(max(log_id),0) from LOG_TABLAS_64)+1, '''+@TableNameZ+''', 3

			END
			ELSE
			BEGIN

				INSERT INTO '+@TableNameZ+'
				SELECT * FROM '+ @TableNameServerZ +' WHERE '+ @ColumnDate +' = '''+ CONVERT(NVARCHAR, @FechaCarga, 120)  +'''

				insert into LOG_TABLAS_64 (log_fecha, log_id, log_tabla, log_estado) 
				select getdate(), (select isnull(max(log_id),0) from LOG_TABLAS_64)+1, '''+@TableNameZ+''', 4
			END'





			IF @FechaCarga < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			BEGIN
			    -- Consulta a ejecutar si @FechaCarga está antes del mes actual
				EXEC SP_EXECUTESQL @SQLStringZ
			END
			ELSE
			BEGIN
				-- Consulta a ejecutar si @FechaCarga no está antes del mes actual
				EXEC SP_EXECUTESQL @SQLString
			END



		

/*
	1 - @SQLStringZ - la data ya existia y se reemplazo en las tablas históricas - proceso se completo correctamente
	2 - @SQLStringZ - no existe data en la tabla histórica- fin del proceso
	3 - @SQLString - la data ya existia y se reemplazo en las tablas DW - proceso se completo correctamente
	4 - @SQLString - no existe data en la tabla original DW - fin del proceso
	5 - error
*/


	end try

	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
		insert into LOG_TABLAS_64 (
			  log_fecha
			, log_id
			, log_tabla
			, log_estado
			, log_obs
		)
		select getdate()
			, (select isnull(max(log_id),0) from LOG_TABLAS_64)+1
			, IIF( @FechaCarga < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) ,@TableNameZ,@TableName)
			, 5
			, @error_message
		
		select 0 as Result
	end catch 
	if @@trancount > 0
		commit transaction		
return 0



--Select COUNT(*) from Z_DW_PRESTAMO where DW_FECHACARGA='2023-09-30'

--100,442
--100,165


