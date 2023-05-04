USE master;  
GO  
CREATE SERVER AUDIT SrvAudit1  
TO FILE (FILEPATH = 'C:\DataFiles\audit\');  
GO  
ALTER SERVER AUDIT SrvAudit1  
WITH (STATE = ON);  
GO  
USE Test1;
GO  
CREATE DATABASE AUDIT SPECIFICATION DbSpec1 
FOR SERVER AUDIT SrvAudit1
ADD (SCHEMA_OBJECT_CHANGE_GROUP),
ADD (SELECT, INSERT, UPDATE, DELETE 
  ON Schema::Sales BY public)  
WITH (STATE = ON);  
GO


SELECT audit_id,
  name audit_name,
  create_date,
  type_desc,
  is_state_enabled is_enabled
FROM sys.server_audits
WHERE name = 'SrvAudit1';



SELECT database_specification_id dbspec_id,
  name spec_name,
  create_date,
  is_state_enabled is_enabled
FROM sys.database_audit_specifications;



