/*
================================================================================
  SnapDB Project - Database Backup Script
  Creates SnapDB.bak in the project's backup/ folder
  Run after all scripts (01-04) have executed successfully
================================================================================

  NOTE: Adjust @BackupPath to match your local SQL Server backup directory.
        SQL Server service account must have write permission to that path.
*/

USE master;
GO

DECLARE @BackupPath NVARCHAR(500);
DECLARE @BackupDir NVARCHAR(500) = N'C:\Users\Melika\Desktop\snap-db-project-2\backup';

-- Create backup directory if using xp_cmdshell (optional)
-- EXEC master.dbo.xp_create_subdir @BackupDir;

SET @BackupPath = @BackupDir + N'\SnapDB.bak';

BACKUP DATABASE SnapDB
TO DISK = @BackupPath
WITH
    FORMAT,
    INIT,
    NAME = N'SnapDB-Full Database Backup',
    SKIP,
    NOREWIND,
    NOUNLOAD,
    COMPRESSION,
    STATS = 10;
GO

PRINT 'Backup completed: backup/SnapDB.bak';
GO

/*
================================================================================
  RESTORE (for reference / TA verification):
================================================================================

USE master;
GO
ALTER DATABASE SnapDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE SnapDB;
GO

RESTORE DATABASE SnapDB
FROM DISK = N'C:\Users\Melika\Desktop\snap-db-project-2\backup\SnapDB.bak'
WITH REPLACE, STATS = 10;
GO
*/
