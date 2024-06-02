-- Insertar información del Funcionarios
DROP TABLE IF EXISTS ST_FUNCIONARIO;
CREATE TABLE ST_FUNCIONARIO (
    CodFuncionario VARCHAR(7),
    Gerencia VARCHAR(10),
    CodJefatura VARCHAR(7),
    Estado BIGINT,
	FechaAlta DATETIME,
	FechaBaja DATETIME,
	Usuario VARCHAR(20),
	UsuarioMod  VARCHAR(20)
);

	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0124189','RICARDO YI','0113954','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0068193','RICARDO YI','0113954','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0114904','RICARDO YI','0114904','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0126098','RICARDO YI','0114904','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario)
	VALUES ('0031171','RICARDO YI','0013866','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0043827','RICARDO YI','0013866','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0122631','RICARDO YI','0121859','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0041353','RICARDO YI','0121859','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0121859','RICARDO YI','0121859','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0127832','RICARDO YI','0121859','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0123362','RICARDO YI','0121859','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0113954','RICARDO YI','0113954','1',getdate() -3,'MELISSA LOZADA')
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0134374','RICARDO YI','0113954','1',getdate() -3,'MELISSA LOZADA')

	sELECT * FROM ST_FUNCIONARIO



