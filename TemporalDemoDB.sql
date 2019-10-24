What triggers the purge
Why is CUSTNAME an invalid column name



--Sam Nasr, MVP, MCSA, MCTS, MCT
-- NIS Technologies
-- Temporal Tables Demo, requires SQL Server 2016+ (any edition)
-- *************************************************************************
-- NOTE: All time fields must reflect time frame when script was executed
-- *************************************************************************

IF DB_ID(N'TemporalDemoDB') IS NOT NULL 
  DROP DATABASE TemporalDemoDB;
GO

CREATE DATABASE TemporalDemoDB;

USE TemporalDemoDB;
GO

CREATE TABLE TerritoryManagers
(
     [Id] int identity(1,1) NOT NULL PRIMARY KEY CLUSTERED  
   , [FirstName] varchar(50) NOT NULL
   , [LastName] varchar(50) NOT NULL
   , [TerritoryName] varchar(100) NOT NULL
)

CREATE TABLE Customers   
(    
     [Id] int identity(1,1) NOT NULL PRIMARY KEY CLUSTERED  
   , [FirstName] varchar(50) NOT NULL
   , [LastName] varchar(50) NOT NULL
   , [Address] varchar(100) NOT NULL
   , [Email] varchar(50) NULL
   , [TerritoryManagerId] int NOT NULL
   , [SysStartTime] datetime2 GENERATED ALWAYS AS ROW START NOT NULL
   , [SysEndTime] datetime2 GENERATED ALWAYS AS ROW END NOT NULL
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)
)    
WITH (SYSTEM_VERSIONING = ON 
        (
		  HISTORY_TABLE = dbo.CustomersHistoricalTable
          --HISTORY_RETENTION_PERIOD = 6 MONTHS
		)
); 


ALTER TABLE [dbo].Customers WITH CHECK 
ADD CONSTRAINT [FK_dbo.Customers_dbo.TerritoryManagers_TerritoryManagerId] FOREIGN KEY([TerritoryManagerId])
REFERENCES [dbo].[TerritoryManagers] ([Id])
GO


/**************************************/
/* Populating tables with sample data */
/**************************************/

INSERT INTO [dbo].[TerritoryManagers] ([FirstName], [LastName], [TerritoryName])
                               VALUES ('Jim', 'Smith', 'Midwest')
							         ,('Mary', 'Jones', 'Southeast')
									 ,('John', 'Lewis', 'Northwest')
GO


INSERT INTO [dbo].[Customers] ([FirstName], [LastName], [Address], [Email], [TerritoryManagerId])
                       VALUES ('Lisa', 'Shepherd', '1212 Middle Street, Cleveland, OH  44118', 'lisa@gmail.com', 1)
					         ,('Tina', 'Wilson', '5582 South Street, Naples, FL  34101', 'tinaw@outlook.com', 2)
							 ,('Sam', 'Johnson', '2418 North Woods Ave, Seattle, WA  98116', 'SamuelJohnson@yahoo.com', 3)
GO


select * from [dbo].[TerritoryManagers]
select * from [dbo].[Customers]

select * from [dbo].[Customers]
select * from [dbo].[CustomersHistoricalTable]

--sys.tables.temporal_type
--0 = NON_TEMPORAL_TABLE  (non-versioned)
--1 = HISTORY_TABLE
--2 = SYSTEM_VERSIONED_TEMPORAL_TABLE
select name, temporal_type, temporal_type_desc from sys.tables where name = 'Customers'
select name, temporal_type, temporal_type_desc from sys.tables where name = 'CustomersHistoricalTable'


/********************/
/* Demo 1: Query   */
/********************/
--Delay/Change #1
WAITFOR DELAY '00:00:03';
UPDATE [dbo].[Customers]
SET [Email] = 'tina2018@yahoo.com'
WHERE Id = 2

--Delay/Change #2
WAITFOR DELAY '00:00:03';
UPDATE [dbo].[Customers]
SET [Email] = 'tinaR@hotmail.com'
WHERE Id = 2

--Delay/Change #3
WAITFOR DELAY '00:00:03';
UPDATE [dbo].[Customers]
SET [Email] = 'tina1@mailx.com'
WHERE Id = 2

SELECT * FROM [dbo].[Customers]
SELECT * FROM [dbo].[CustomersHistoricalTable]

/********************/
/* Demo 2: Clauses */
/********************/
Use TemporalDemoDB
Go

--Demo 2A:AS OF <date_time>; 
--Use SysStartTime of the time it started to exist (what was the table at this time?)

--3 Recs started at/prior to this specified time (time OF rec insert, in UTC)
SELECT * FROM [dbo].[Customers]
FOR SYSTEM_TIME AS OF '2019-10-05 20:29:40.4892802'  --Current table SysStartTime
ORDER BY Id
Go

--0 Recs started at/prior to this specified time (time BEFORE rec insert, in UTC)
SELECT * FROM [dbo].[Customers]
FOR SYSTEM_TIME AS OF '2019-10-05 14:54:16.0615959'  --Current table SysStartTime - 1 sec
ORDER BY Id
Go

--Demo 2B: FROM <start_date_time> TO <end_date_time>; (use ANY time range)
--Returns all row versions that were started within the specified time range, excluding boundary
SELECT * FROM [dbo].[Customers]
SELECT * FROM [dbo].[CustomersHistoricalTable]

SELECT * FROM [dbo].[Customers]
FOR SYSTEM_TIME FROM '2019-10-05 14:54:17.0615959' TO '2020-03-30 20:22:47.7176231'
ORDER BY Id
Go


--Demo 2C: BETWEEN <start_date_time> AND <end_date_time>; (use MIN-MAX (before-after) time values)
--Returns all row versions that were STARTED within the specified time range, INCLUDING boundary
SELECT * FROM [dbo].[Customers]  --Current table SysStartTime   --MAX time
FOR SYSTEM_TIME BETWEEN  '2019-10-05 14:54:17.0615959' AND '2029-03-30 03:19:51.2102354'
ORDER BY Id
Go

--Demo 2D: CONTAINED IN (<start_date_time>,<end_date_time>); (use exact START-END time of tina2018@yahoo.com)
--Returns only those that started AND ended within specified period boundaries.
SELECT * FROM [dbo].[Customers]
FOR SYSTEM_TIME CONTAINED IN ('2019-06-08 17:17:50.4635455', '2019-06-08 17:18:10.7313111')
ORDER BY Id
Go

--Demo 2E: ALL (returns the union of rows that belong to the current and the history table)
SELECT * FROM [dbo].[Customers]
FOR SYSTEM_TIME ALL
where id = 2
Go

-- Demo 2F: Direct Query
select * from CustomersHistoricalTable where SysEndTime >= '2019-10-05 20:29:40.4892802'

/***********************************************************/
/* Demo 3: Transactions (uses Begin Time in UTC)           */
/***********************************************************/
Use TemporalDemoDB
Go

BEGIN TRAN
PRINT 'Transaction Starting @ ' + CONVERT(varchar, SysDateTime())

	UPDATE [dbo].[Customers]
	SET [Email] = 'tinawil@live1.com'
	WHERE Id = 2

	PRINT 'Delay #1...';
	WAITFOR DELAY '00:00:01';

	UPDATE [dbo].[Customers]
	SET [Email] = 'tinawil@live2.com'
	WHERE Id = 2

    PRINT 'Delay #2...';
	WAITFOR DELAY '00:00:01';

	UPDATE [dbo].[Customers]
	SET [Email] = 'tinawil@live3.com'
	WHERE Id = 2
	
PRINT 'Transaction Committing @ ' + CONVERT(varchar, SysDateTime())

--ROLLBACK TRAN --Nothing is saved in either table
COMMIT TRAN

select * from Customers
select * from CustomersHistoricalTable

-- Updating Historical Recs
	UPDATE [dbo].[CustomersHistoricalTable]  --must have SYSTEM_VERSIONING = OFF
	SET [Email] = 'tinawil@liveXYZ.com'
	WHERE Id = 2

--Deleting Recs
delete from customers where id =2
delete from CustomersHistoricalTable where email='tinaw@outlook.com'


/*********************/
/* Demo 4: ALTER     */
/*********************/
ALTER TABLE dbo.[Customers] Add Alt_Email1 varchar(20) null;  --Updates both tables

ALTER TABLE dbo.[Customers] Add Alt_Email2 varchar(20) not null;  --Fails due to NOT NULL


BEGIN TRAN;
-- Turn system versioning off when making custom changes (i.e. NOT NULL fields)
ALTER TABLE dbo.[Customers] SET ( SYSTEM_VERSIONING = OFF )

-- Apply changes to both tables
ALTER TABLE dbo.[Customers] Add CustNotes varchar(50) null;
ALTER TABLE dbo.[CustomersHistoricalTable] Add CustNotes varchar(50) null;

update [Customers]
set CustNotes = 'Current Customer Rec'


update [CustomersHistoricalTable]
set CustNotes = 'Old Rec'

-- Turn system versioning back on
--Adding PERIOD will perform a data consistency check on current table to 
--make sure that the existing values for period columns are valid
ALTER TABLE dbo.[Customers]
SET ( SYSTEM_VERSIONING = ON
        ( HISTORY_TABLE = dbo.CustomersHistoricalTable,
        DATA_CONSISTENCY_CHECK = ON ) );

COMMIT TRAN;


/**********************************/
/* Demo 5: "Clean" UPDATE, DELETE */
/**********************************/
--Blanket insert on ANY update, no intelligence for updates
UPDATE [dbo].[Customers]
SET [Email] = [Email]
WHERE Id = 3

select * from customers
select * from customershistoricaltable


--Deleting Recs
delete from Customers 
where ID =1

select * from customers
select * from customershistoricaltable



/***************************/
/* Demo 6: Purging options */
/***************************/
--Purging Historical Table
ALTER TABLE dbo.[Customers] SET ( SYSTEM_VERSIONING = OFF )
delete customershistoricaltable where id = 2  --Will only execute if versioning=OFF
ALTER TABLE dbo.[Customers] SET ( SYSTEM_VERSIONING = ON )

select * from customers
select * from customershistoricaltable

/****************************/
/* Demo 7: UPDATE History   */
/****************************/
Update CustomersHistoricalTable  --GOTCHA: Works regardless of versioning, prevented by security access
Set FirstName = 'Thomas'
Where Id=3


/****************************/
/* Demo 8: TRUNCATE options */
/****************************/
Truncate table customers  --Will only execute if versioning=OFF

ALTER TABLE dbo.[Customers] SET ( SYSTEM_VERSIONING = OFF )
Truncate table customers  --Will only execute if versioning=OFF => no history kept of deletions
ALTER TABLE dbo.[Customers] SET ( SYSTEM_VERSIONING = ON )

select * from customers
select * from customershistoricaltable

/****************************/
/* Demo 9: ALTER TABLE      */
/****************************/
ALTER TABLE dbo.[department1] Add Alt_Email2 varchar(20) null;  --Works, ALTERS both tables


/***************************/
/* Demo 10: CREATE options */
/***************************/

/**********************************************************************************************************/
/* Option #1:Temporal table w/anonymous history table:                                                    */
/*  user specifies schema of current table, but system auto-generates history table.                      */
/**********************************************************************************************************/
CREATE TABLE Department1   
(    
     DeptID int NOT NULL PRIMARY KEY CLUSTERED  
   , DeptName varchar(50) NOT NULL  
   , ManagerID INT  NULL  
   , ParentDeptID int NULL  
   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)     
)    
WITH (SYSTEM_VERSIONING = ON);  



/**********************************************************************************************************/
/* Option #2: Temporal table w/default history table:                                                     */
/*  user specifies history table schema name and table name, but system auto-generates history table.     */
/**********************************************************************************************************/
CREATE TABLE Department2   
(    
     DeptID int NOT NULL PRIMARY KEY CLUSTERED  
   , DeptName varchar(50) NOT NULL  
   , ManagerID INT  NULL  
   , ParentDeptID int NULL  
   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)     
)   
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.Department2History));  


/**********************************************************************************************************/
/* Option #3: Temporal table with a user-defined history table:                                           */
/*  user specifies history table, then references it during temporal table creation.                      */
/*  NOTE: Used for making existing tables "TEMPORAL".                                                     */
/**********************************************************************************************************/
CREATE TABLE Department3History   
(    
     DeptID int NOT NULL  
   , DeptName varchar(50) NOT NULL  
   , ManagerID INT NULL  
   , ParentDeptID int NULL  
   , SysStartTime datetime2 NOT NULL  
   , SysEndTime datetime2 NOT NULL   
);   
GO   

CREATE CLUSTERED COLUMNSTORE INDEX IX_Department3History ON Department3History;   
CREATE NONCLUSTERED INDEX IX_Department3History_ID_PERIOD_COLUMNS ON Department3History (SysEndTime, SysStartTime, DeptID);   
GO   

CREATE TABLE Department3   
(    
    DeptID int NOT NULL PRIMARY KEY CLUSTERED  
   , DeptName varchar(50) NOT NULL  
   , ManagerID INT  NULL  
   , ParentDeptID int NULL  
   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL     
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)      
)    
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.Department3History));  --History table must not be already used
Go



/**************************/
/* Demo : Time Zone Mod   */
/**************************/
/*Add offset of the local time zone to current time*/  
DECLARE @asOf DATETIMEOFFSET = GETDATE() AT TIME ZONE 'Eastern Standard Time'
  
/*Convert AS OF filter to UTC*/  
SET @asOf = DATEADD (hh, +4, @asOf) AT TIME ZONE 'UTC';  
PRINT @asOf;

SELECT   
     [FirstName]
   , [LastName] 
   , [Address]
   , [Email] 
   , [SysStartTime] AT TIME ZONE 'Eastern Standard Time' AS SysStartTimeEST   
   , [SysEndTime] AT TIME ZONE 'Eastern Standard Time' AS SysEndTimeEST  
FROM dbo.[Customers]   
    FOR SYSTEM_TIME AS OF @asOf 