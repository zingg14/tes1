ALTER TABLE tm_user_logins ADD sESignature TEXT;
ALTER TABLE tm_user_logins ADD sMobilePhone VARCHAR(20);
ALTER TABLE tx_ms_orders_d ADD nSRIdVendorService_fk	INT;
ALTER TABLE tx_ms_orders_d ADD nSRIdEkspedisiVendorService_fk	INT;
ALTER TABLE tx_ms_orders_d ADD dSRTglKirimKeVendor	DATE;
ALTER TABLE tx_ms_orders_d ADD nSRUserIdKirimKeVendor_fk	INT;

ALTER TABLE tx_ms_orders_d ADD nSRUserIdReceiveOrderFromVendor_fk	INT;
ALTER TABLE tx_ms_orders_d ADD dSRReceiveDateOrderFromVendor	DATETIME;
ALTER TABLE tx_ms_orders_d ADD nSRStatusPushInventarisDistribusi	INT;

ALTER TABLE tm_user_open_reports ADD sOpenReportsConfigValueJSON	TEXT;



DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_tm_user_logins`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_tm_user_logins`( p_sMode CHAR(1),	p_nUserId INT,
	p_sUserName VARCHAR(100),
	p_sRealName VARCHAR(200),
	p_sEmail VARCHAR(100),
	p_sPassword VARCHAR(100),
	p_sAvatar VARCHAR(100),
	p_sAboutMe VARCHAR(100),
	p_sMobilePhone VARCHAR(20),
	p_sUUID VARCHAR(36),
	p_sUserInput VARCHAR(50)
)
BEGIN
IF p_sMode = 'I' THEN 
BEGIN
DECLARE oUserId INT;
	SET oUserId = (SELECT CASE WHEN COUNT(1) = 0 THEN 1 ELSE MAX(nUserId) + 1 END FROM tm_user_logins);
 INSERT INTO tm_user_logins ( 			nUserId,
			sUserName,
			sRealName,
			sEmail,
			sPassword,
			sUUID,
sCreateBy, dCreateOn, sMobilePhone ) VALUES ( 			oUserId,
			p_sUserName,
			UPPER(p_sRealName),
			p_sEmail,
			MD5(p_sPassword),
			MD5(UUID()),
p_sUserInput, CURRENT_TIMESTAMP, p_sMobilePhone); 
END;
ELSEIF p_sMode = 'U' THEN 
BEGIN
 UPDATE tm_user_logins SET sUserName = p_sUserName,
sRealName = UPPER(p_sRealName),
sEmail = p_sEmail,
sUUID = MD5(UUID()),
sPassword = MD5(p_sPassword),
sMobilePhone = p_sMobilePhone,
sLastEditBy = p_sUserInput, dLastEditOn = CURRENT_TIMESTAMP 
WHERE nUserId = p_nUserId  ;
END;
ELSEIF p_sMode = 'P' THEN 
BEGIN
 UPDATE tm_user_logins SET sUserName = p_sUserName,
sRealName = UPPER(p_sRealName),
sEmail = p_sEmail,
sMobilePhone = p_sMobilePhone,
sUUID = MD5(UUID()),
sLastEditBy = p_sUserInput, dLastEditOn = CURRENT_TIMESTAMP 
WHERE nUserId = p_nUserId  ;
END;
ELSEIF p_sMode = 'D' THEN 
BEGIN
  UPDATE tm_user_logins SET sStatusDelete = 'V', sDeleteBy = p_sUserInput, dDeleteOn = CURRENT_TIMESTAMP  
WHERE nUserId = p_nUserId  ;
END;
END IF;
END$$

DELIMITER ;

DELIMITER $$

ALTER DEFINER=`root`@`localhost` EVENT `CountingUserLoginPerDay` ON SCHEDULE EVERY 5 MINUTE STARTS '2023-03-23 15:56:00' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
  SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'run_event started';
		#----------------------------------------- Analytical User Login Per Day
		DROP TABLE IF EXISTS tz_analytical_user_login_per_day_all_month_all_year;
		CREATE TABLE tz_analytical_user_login_per_day_all_month_all_year SELECT CAST(DATE_FORMAT(dLogDate, '%Y-%m-%d') AS DATE) AS dLogDate, 
		COUNT(nUserId_fk) AS `nCountUser`, CURRENT_TIMESTAMP AS dTimeStamp FROM tm_user_logs
		WHERE sLogType = 'LOGIN'
		GROUP BY CAST(DATE_FORMAT(dLogDate, '%Y-%m-%d') AS DATE);
		#----------------------------------------- Analytical User Login Current Month and Current Year
		DROP TABLE IF EXISTS tz_analytical_user_login_current_month_current_year;
		CREATE TABLE tz_analytical_user_login_current_month_current_year SELECT CAST(DATE_FORMAT(dLogDate, '%m') AS UNSIGNED) AS dMonthDate, CAST(DATE_FORMAT(dLogDate, '%Y') AS UNSIGNED) AS dYearDate,
		COUNT(nUserId_fk) AS `nCountUser`, CURRENT_TIMESTAMP AS dTimeStamp FROM tm_user_logs
		WHERE sLogType = 'LOGIN' AND MONTH(dLogDate) = MONTH(CURRENT_DATE) AND YEAR(dLogDate) = YEAR(CURRENT_DATE)
		GROUP BY CAST(DATE_FORMAT(dLogDate, '%m') AS UNSIGNED);
		#----------------------------------------- Analytical User Login Per Month and Current Year
		DROP TABLE IF EXISTS tz_analytical_user_login_per_month_current_year;
		CREATE TABLE tz_analytical_user_login_per_month_current_year SELECT LEFT(MONTHNAME(dLogDate), 3) AS dMonthDate, CAST(DATE_FORMAT(dLogDate, '%Y') AS UNSIGNED) AS dYearDate,
		COUNT(nUserId_fk) AS `nCountUser`, CURRENT_TIMESTAMP AS dTimeStamp FROM tm_user_logs
		WHERE sLogType = 'LOGIN' AND YEAR(dLogDate) = YEAR(CURRENT_DATE)
		GROUP BY CAST(DATE_FORMAT(dLogDate, '%m') AS UNSIGNED);
		#----------------------------------------- Analytical User Login Per Day Current Month and Current Year
		SET @sql = NULL;
		SELECT
		GROUP_CONCAT(`nCountUser`, ' as `', DATE_FORMAT(dLogDate, '%d'), '`') INTO @sql
		FROM tz_analytical_user_login_per_day_all_month_all_year 
		WHERE MONTH(dLogDate) = MONTH(CURRENT_DATE) AND 
		YEAR(dLogDate) = YEAR(CURRENT_DATE);
		DROP TABLE IF EXISTS tz_analytical_user_login_pv_per_day_current_month_current_year;
		SET @sql = CONCAT('create table tz_analytical_user_login_pv_per_day_current_month_current_year select ', @sql);
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
		#----------------------------------------- Analytical User Login All Month and Current Year
		SET @sql = NULL;
		SELECT
		GROUP_CONCAT(`nCountUser`, ' as `', CONCAT(/*REPEAT('0', 2 - LENGTH(dMonthDate))*/dMonthDate), '`') 
		INTO @sql
		FROM tz_analytical_user_login_per_month_current_year;
		DROP TABLE IF EXISTS tz_analytical_user_login_pv_all_month_current_year;
		SET @sql = CONCAT('create table tz_analytical_user_login_pv_all_month_current_year select ', @sql);
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
		#------------------------------------------- Analytical User yang paling sering login di bulan dan tahun berjalan
		SET @sql = NULL;
		DROP TABLE IF EXISTS tz_analytical_user_login_pv_most_enter_current_month_year;
		SELECT GROUP_CONCAT(`nFrekuensi`, ' as `', sRealName, '`') INTO @sql FROM (		
			SELECT COUNT(a.nUserId_fk) AS nFrekuensi, UPPER(b.sRealName) AS sRealName 
			FROM 
			tm_user_logs a INNER JOIN tm_user_logins b 
			ON b.nUserId = a.nUserId_fk
			WHERE MONTH(dLogDate) = MONTH(CURRENT_DATE) AND 
			YEAR(dLogDate) = YEAR(CURRENT_DATE)
			GROUP BY b.sRealName
			ORDER BY COUNT(a.nUserId_fk) DESC LIMIT 10
		) AS c;
		SET @sql = CONCAT('create table tz_analytical_user_login_pv_most_enter_current_month_year select ', @sql);
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt; 
  SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = 'run_event finished';
END$$

DELIMITER ;

DELIMITER $$

USE `inventarisdb`$$

DROP FUNCTION IF EXISTS `gf_global_function`$$

CREATE DEFINER=`root`@`localhost` FUNCTION `gf_global_function`(
	p_Mode VARCHAR(100), 
	p_Param1 VARCHAR(8000), 
	p_Param2 VARCHAR(8000), 
	p_Param3 VARCHAR(8000),
	p_Param4 VARCHAR(8000), 
	p_Param5 VARCHAR(8000), 
	p_Param6 VARCHAR(8000)
) RETURNS TEXT CHARSET latin1
BEGIN
DECLARE p_return TEXT;
		IF p_Mode = 'GetLastStatusOrders' THEN
			SET p_Return = (SELECT CONCAT(p.sNamaStatus, ' @ ', p.dStatusDateTime) FROM tx_ms_orders_status p 
			WHERE p.sStatusDelete IS NULL AND p.nUnitId_fk = CAST(p_Param1 AS UNSIGNED)
			AND p.nOrdersId_fk = CAST(p_Param2 AS UNSIGNED)
			AND p.sSRNoTicket = p_Param3
			ORDER BY p.dCreateOn DESC LIMIT 1);
		ELSEIF p_Mode = 'GetLastStatusOrdersNotes' THEN
			SET p_Return = (SELECT p.sNotes FROM tx_ms_orders_status p 
			WHERE p.sStatusDelete IS NULL AND p.nUnitId_fk = CAST(p_Param1 AS UNSIGNED)
			AND p.nOrdersId_fk = CAST(p_Param2 AS UNSIGNED)
			AND p.sSRNoTicket = p_Param3
			ORDER BY p.dCreateOn DESC LIMIT 1);
		ELSEIF p_Mode = 'GetLastStatusOrdersComplete' THEN
			SET p_Return = (SELECT CONCAT(p.sNamaStatus, ' | ', p.sNotes, ' @ ', p.dStatusDateTime) FROM tx_ms_orders_status p 
			WHERE p.sStatusDelete IS NULL AND p.nUnitId_fk = CAST(p_Param1 AS UNSIGNED)
			AND p.nOrdersId_fk = CAST(p_Param2 AS UNSIGNED)
			AND p.sSRNoTicket = p_Param3
			ORDER BY p.dCreateOn DESC LIMIT 1);
		ELSEIF p_Mode = 'GetLastStatusOrdersTypeStatusId' THEN
			SET p_Return = (SELECT p.nIdStatus_fk FROM tx_ms_orders_status p 
			WHERE p.sStatusDelete IS NULL AND p.nUnitId_fk = CAST(p_Param1 AS UNSIGNED)
			AND p.nOrdersId_fk = CAST(p_Param2 AS UNSIGNED)
			AND p.sSRNoTicket = p_Param3
			ORDER BY p.dCreateOn DESC LIMIT 1);
		END IF;		
		RETURN p_Return;		
		END$$

DELIMITER ;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_tm_user_open_reports`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_tm_user_open_reports`( p_sMode CHAR(1),	p_nIdOpenReport INT,
	p_nIdOpenReportParent_fk INT,
	p_sOpenReportsName VARCHAR(100),
	p_sOpenReportsSQL TEXT(65535),
	p_nOpenReportsType INT,
	p_nShowToUser INT,
	p_sOpenReportsStaticParams TEXT,
	p_sOpenReportsDesc VARCHAR(200),
	p_sOpenReportsStaticParamsExcel TEXT,
	p_sUUID VARCHAR(32),
	p_sUserInput VARCHAR(50),
	p_sHideColumns VARCHAR(1000),
	p_nOpenReportOutput INT,
	p_sOpenReportsConfigValueJSON TEXT
)
BEGIN
IF p_sMode = 'I' THEN 
BEGIN
DECLARE oId INT;
SET oId = (SELECT CASE WHEN COUNT(1) = 0 THEN 1 ELSE MAX(nIdOpenReport) + 1 END FROM tm_user_open_reports);
 INSERT INTO tm_user_open_reports ( 			nIdOpenReport,
			nIdOpenReportParent_fk,
			sOpenReportsName,
			sOpenReportsSQL,
			nOpenReportsType,
			nShowToUser,
			sOpenReportsStaticParams,
			sOpenReportsDesc,
			sOpenReportsStaticParamsExcel,
			sUUID,			
			sHideColumns,
sCreateBy, dCreateOn, nOpenReportOutput, sOpenReportsConfigValueJSON) VALUES ( 			oId,
			p_nIdOpenReportParent_fk,
			p_sOpenReportsName,
			p_sOpenReportsSQL,
			p_nOpenReportsType,
			p_nShowToUser,
			p_sOpenReportsStaticParams,
			p_sOpenReportsDesc,
			p_sOpenReportsStaticParamsExcel,
			p_sUUID,
			p_sHideColumns,
p_sUserInput, CURRENT_TIMESTAMP, p_nOpenReportOutput, p_sOpenReportsConfigValueJSON); 
END;
ELSEIF p_sMode = 'U' THEN 
BEGIN
 UPDATE tm_user_open_reports SET nIdOpenReportParent_fk = p_nIdOpenReportParent_fk,
sOpenReportsName = p_sOpenReportsName,
sOpenReportsSQL = p_sOpenReportsSQL,
nOpenReportsType = p_nOpenReportsType,
sHideColumns = p_sHideColumns,
sOpenReportsStaticParamsExcel = p_sOpenReportsStaticParamsExcel,
sOpenReportsStaticParams = p_sOpenReportsStaticParams,
sOpenReportsDesc = p_sOpenReportsDesc,
nShowToUser = p_nShowToUser,
nOpenReportOutput = p_nOpenReportOutput, 
sUUID = p_sUUID,
sLastEditBy = p_sUserInput, dLastEditOn = CURRENT_TIMESTAMP,
sOpenReportsConfigValueJSON = p_sOpenReportsConfigValueJSON 
WHERE nIdOpenReport = p_nIdOpenReport AND sStatusDelete IS NULL ;
END;
ELSEIF p_sMode = 'D' THEN 
BEGIN
  UPDATE tm_user_open_reports SET sStatusDelete = 'V', sDeleteBy = p_sUserInput, dDeleteOn = CURRENT_TIMESTAMP  
WHERE nIdOpenReport = p_nIdOpenReport AND sStatusDelete IS NULL ;
END;
END IF;
END$$

DELIMITER ;

ALTER TABLE tm_user_open_reports ADD sOpenReportsConfigValueJSON	TEXT;
ALTER TABLE tm_user_open_reports ADD sSPModeQuery	CHAR(1) DEFAULT '0';

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_tm_user_open_reports`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_tm_user_open_reports`( p_sMode CHAR(1),	p_nIdOpenReport INT,
	p_nIdOpenReportParent_fk INT,
	p_sOpenReportsName VARCHAR(100),
	p_sOpenReportsSQL TEXT(65535),
	p_nOpenReportsType INT,
	p_nShowToUser INT,
	p_sOpenReportsStaticParams TEXT,
	p_sOpenReportsDesc VARCHAR(200),
	p_sOpenReportsStaticParamsExcel TEXT,
	p_sUUID VARCHAR(32),
	p_sUserInput VARCHAR(50),
	p_sHideColumns VARCHAR(1000),
	p_nOpenReportOutput INT,
	p_sOpenReportsConfigValueJSON TEXT,
	p_sSPModeQuery CHAR(1)
)
BEGIN
IF p_sMode = 'I' THEN 
BEGIN
DECLARE oId INT;
SET oId = (SELECT CASE WHEN COUNT(1) = 0 THEN 1 ELSE MAX(nIdOpenReport) + 1 END FROM tm_user_open_reports);
 INSERT INTO tm_user_open_reports ( 			nIdOpenReport,
			nIdOpenReportParent_fk,
			sOpenReportsName,
			sOpenReportsSQL,
			nOpenReportsType,
			nShowToUser,
			sOpenReportsStaticParams,
			sOpenReportsDesc,
			sOpenReportsStaticParamsExcel,
			sUUID,			
			sHideColumns,
sCreateBy, dCreateOn, nOpenReportOutput, sOpenReportsConfigValueJSON, sSPModeQuery) VALUES ( 			oId,
			p_nIdOpenReportParent_fk,
			p_sOpenReportsName,
			p_sOpenReportsSQL,
			p_nOpenReportsType,
			p_nShowToUser,
			p_sOpenReportsStaticParams,
			p_sOpenReportsDesc,
			p_sOpenReportsStaticParamsExcel,
			p_sUUID,
			p_sHideColumns,
p_sUserInput, CURRENT_TIMESTAMP, p_nOpenReportOutput, p_sOpenReportsConfigValueJSON, p_sSPModeQuery); 
END;
ELSEIF p_sMode = 'U' THEN 
BEGIN
 UPDATE tm_user_open_reports SET nIdOpenReportParent_fk = p_nIdOpenReportParent_fk,
sOpenReportsName = p_sOpenReportsName,
sOpenReportsSQL = p_sOpenReportsSQL,
nOpenReportsType = p_nOpenReportsType,
sHideColumns = p_sHideColumns,
sOpenReportsStaticParamsExcel = p_sOpenReportsStaticParamsExcel,
sOpenReportsStaticParams = p_sOpenReportsStaticParams,
sOpenReportsDesc = p_sOpenReportsDesc,
nShowToUser = p_nShowToUser,
nOpenReportOutput = p_nOpenReportOutput, 
sUUID = p_sUUID,
sLastEditBy = p_sUserInput, dLastEditOn = CURRENT_TIMESTAMP,
sOpenReportsConfigValueJSON = p_sOpenReportsConfigValueJSON,
sSPModeQuery = p_sSPModeQuery 
WHERE nIdOpenReport = p_nIdOpenReport AND sStatusDelete IS NULL ;
END;
ELSEIF p_sMode = 'D' THEN 
BEGIN
  UPDATE tm_user_open_reports SET sStatusDelete = 'V', sDeleteBy = p_sUserInput, dDeleteOn = CURRENT_TIMESTAMP  
WHERE nIdOpenReport = p_nIdOpenReport AND sStatusDelete IS NULL ;
END;
END IF;
END$$

DELIMITER ;