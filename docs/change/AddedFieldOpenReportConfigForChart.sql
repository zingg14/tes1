ALTER TABLE tm_user_open_reports ADD sOpenReportsConfigValueJSON	text;
ALTER TABLE tm_user_open_reports ADD sSPModeQuery	char(1) default '0';

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
	p_sSPModeQuery char(1)
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