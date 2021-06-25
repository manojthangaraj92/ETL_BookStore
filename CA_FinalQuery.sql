--Create Database CAPublisher_DW and two dimesional table Books_Title and Author_TitleAU and fact table is Payment_facts

CREATE DATABASE CAPublisher_DW
GO
USE CAPublisher_DW;

CREATE TABLE Books_Title
(
TitleKey INT NOT NULL IDENTITY,
title_id  CHAR(20),
title VARCHAR(80),
type CHAR(12),
Date DATETIME,
PRIMARY KEY(TitleKey)
);
GO


CREATE TABLE Author_TitleAU
(AuthorKey INT NOT NULL IDENTITY,
au_id CHAR(20),
au_name VARCHAR(65),
title_id CHAR(20),
au_ord TINYINT, --Not needed?
contract BIT,
StartDate DATETIME,
EndDate DATETIME,
PRIMARY KEY(AuthorKey)
);
GO

CREATE TABLE Payment_facts
(
AuthorKey  INT,
TitleKey  INT,
ytd_sales INT,
royalty INT,
royaltyper INT,
RoyPay_YtdSales FLOAT,
AdvancePerAuthor MONEY,
TotalPay FLOAT,
PRIMARY KEY(AuthorKey,TitleKey),
FOREIGN KEY (AuthorKey) REFERENCES Author_TitleAU (AuthorKey),
FOREIGN KEY (TitleKey) REFERENCES Books_Title(TitleKey)
);
GO

--Lets create staging tables to bring data from the sourcec before it is uploaded in dimensional table

CREATE TABLE stg_Author_TitleAU
(
au_id CHAR(20),
au_name VARCHAR(65),
title_id CHAR(20),
au_ord TINYINT,
contract BIT
);
GO

CREATE TABLE stg_Books_Title
(
title_id  CHAR(20),
title VARCHAR(80),
type CHAR(12),
Date DATETIME
);
GO

CREATE TABLE stg_Payment_facts
(
AuthorKey  INT,
TitleKey  INT,
ytd_sales INT,
royalty INT,
royaltyper INT,
RoyPay_YtdSales FLOAT,
AdvancePerAuthor MONEY,
TotalPay FLOAT
);
GO

-- Creating ETL Run Table to Lof the ETL Run Records

CREATE TABLE ETLRun
(
ETLRunKey INT NOT NULL IDENTITY PRIMARY KEY,
TableName varchar(200) NOT NULL,
ETLStatus varchar(25) NULL,
StartTime datetime NULL,
EndTime   datetime NULL,
RecordCount INT NULL
);
GO

-- Stored Procedure to create ETL Logging Record

CREATE PROCEDURE CreateETLLoggingRecord
	@TableName varchar(200),
	@ETLID INT OUTPUT
AS
BEGIN
	--Insert a new record into the ETLRun table and return the ETLID that was generated
    INSERT INTO ETLRun
           (TableName
           ,ETLStatus
           ,StartTime
           ,EndTime
           ,RecordCount)
     VALUES
           (@TableName
           ,'Running'
           ,getdate()
           ,NULL
           ,NULL)

	SET @ETLID = SCOPE_IDENTITY(); -- RETURNS LAST IDENTITY VALUE INSERTED INTO AN IDENTITY COLUMN

END
GO

-- Stored Procedure to update ETL Logging Record

CREATE PROCEDURE UpdateETLLoggingRecord
	@ETLID INT,
	@RecordCount INT
AS
BEGIN
	--Insert a new record into the ETLRun table and return the ETLID that was generated
	update ETLRun 
	set	EndTime = getdate(),
		ETLStatus = 'Success',
		RecordCount = @RecordCount
	where ETLRunKey = @ETLID;

END
GO

-- Stored Procedure to merge data into Author_TitleAU dimension table from staging table


CREATE PROCEDURE Merge_Author_TitleAU
@PackageStartTime datetime,
@RecordCount INT OUTPUT
AS
BEGIN
	
	/*
	au_id		= Type 1
	au_name		= Type 1
	title_id	= Type 1
	au_ord		= Type 1
	contract	= Type 3
	*/


		--Type 1 
		MERGE INTO Author_TitleAU tgt
		USING stg_Author_TitleAU src ON tgt.au_id = src.au_id
		WHEN MATCHED AND EXISTS 
		(	
			select src.au_name, src.title_id, src.au_ord
			except 
			select tgt.au_name, tgt.title_id, tgt.au_ord
		)
		THEN UPDATE
		SET
			tgt.au_name = src.au_name,
			tgt.title_id = src.title_id,
			tgt.au_ord = src.au_ord

		WHEN NOT MATCHED BY TARGET THEN INSERT
		(
		   au_id
		  ,au_name
		  ,title_id
		  ,au_ord
		  ,contract
		  ,StartDate
		  ,EndDate
		)
		VALUES
		(
			 src.au_id
			,src.au_name
			,src.title_id
			,src.au_ord
			,src.contract
			,@PackageStartTime
			,NULL
		);


	DECLARE @RecCount1 INT
	SET @RecCount1 = @@ROWCOUNT

		
	CREATE TABLE #Author_TitleAU -- Local temporary table
	(
	au_id CHAR(20),
	au_name VARCHAR(65),
	title_id CHAR(20),
	au_ord TINYINT,
	contract BIT,
	StartDate datetime,
	EndDate datetime
	);


	--Type 2 Changes
	INSERT INTO #Author_TitleAU
		   (au_id, au_name ,title_id ,au_ord ,contract, StartDate, EndDate)
	SELECT	au_id, au_name ,title_id ,au_ord ,contract, StartDate, EndDate	
    From (
		MERGE INTO Author_TitleAU tgt
		USING stg_Author_TitleAU src ON tgt.au_id = src.au_id
		WHEN MATCHED AND tgt.EndDate IS NULL AND EXISTS 
		(	
			select src.contract
			except 
			select tgt.contract
		)
		THEN UPDATE
		SET 
			tgt.EndDate = @PackageStartTime -- Update End Date of the expired record	

		-- getting values for active records
		Output $ACTION ActionOut, src.au_id, src.au_name, src.title_id, src.au_ord, src.contract, 
			@PackageStartTime as StartDate, NULL as EndDate) AS a
	WHERE  a.ActionOut = 'UPDATE';

/*
The Merge statement can track the data that has changed, and whether it was an insert, update, or delete operation. 
This information can be returned by using the Output clause. 
*/
	insert into Author_TitleAU
	(au_id, au_name ,title_id ,au_ord ,contract, StartDate, EndDate)
	select au_id, au_name ,title_id ,au_ord ,contract, StartDate, EndDate
	from #Author_TitleAU;    


		--Save the number of records touched by the MERGE statement and send the results back to SSIS

		DECLARE @RecCount2 INT
		SET @RecCount2 = @@ROWCOUNT
		SET @RecordCount = @RecCount1 + 2*@RecCount2;
		SELECT @RecordCount;
	
END
GO

-- Stored Procedure to merge data into Books_Title dimension table from staging table


CREATE procedure Merge_Books_Title
@RecordCount INT OUTPUT
AS
BEGIN
		--Merge from the staging table into the final dimension table
		MERGE INTO Books_Title tgt
		USING stg_Books_Title src ON tgt.title_id= src.title_id
		WHEN MATCHED AND EXISTS 
                (
			select src.title, src.type, src.Date
			except 
			select tgt.title, tgt.type, tgt.Date
		)
		THEN UPDATE
		SET 
			tgt.title = src.title,
			tgt.type = src.type,
			tgt.Date = src.Date
		WHEN NOT MATCHED BY TARGET THEN INSERT
		(
		   title_id
		  ,title
		  ,type
		  ,Date
		 		)
		VALUES
		( src.title_id
		  ,src.title
		  ,src.type
		  ,src.Date
		 
		);
		--Save the number of records touched by the MERGE statement and send the results back to SSIS
		SET @RecordCount = @@ROWCOUNT;
		SELECT @RecordCount;
	END

-- Stored Procedure to merge data into Payment_facts dimension table from staging table

CREATE PROCEDURE Merge_Payment_facts
@RecordCount INT OUTPUT
AS
BEGIN

		MERGE INTO Payment_facts tgt
		USING stg_Payment_facts src ON tgt.AuthorKey = src.AuthorKey AND tgt.TitleKey = src.TitleKey
		WHEN MATCHED AND EXISTS 
		(SELECT src.ytd_sales,src.royalty, src.royaltyper, src.RoyPay_YtdSales, src.AdvancePerAuthor, src.TotalPay
		 except
		 SELECT tgt.ytd_sales,tgt.royalty, tgt.royaltyper, tgt.RoyPay_YtdSales, tgt.AdvancePerAuthor, tgt.TotalPay)
		THEN UPDATE
		SET 
			tgt.ytd_sales = src.ytd_sales,
			tgt.royalty = src.royalty,
			tgt.royaltyper = src.royaltyper,
			tgt.RoyPay_YtdSales = src.RoyPay_YtdSales,
			tgt.AdvancePerAuthor = src.AdvancePerAuthor,
			tgt.TotalPay = src.TotalPay

		WHEN NOT MATCHED BY TARGET THEN INSERT
		(
			AuthorKey,
			TitleKey,
		    ytd_sales ,
			royalty ,
			royaltyper,
			RoyPay_YtdSales,
			AdvancePerAuthor ,
			TotalPay
		)
		VALUES
		(
			src.AuthorKey ,
			src.TitleKey ,
			src.ytd_sales,
			src.royalty,
			src.royaltyper,
			src.RoyPay_YtdSales,
			src.AdvancePerAuthor,
			src.TotalPay
		);

		--Save the number of records touched by the MERGE statement and send the results back to SSIS
		SET @RecordCount = @@ROWCOUNT;
		SELECT @RecordCount;
	
END
GO