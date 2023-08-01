DROP TABLE IF EXISTS xxx;

#Inventaris
CREATE TABLE xxx
SELECT a.nOrdersId_fk,  a.sSN, a.nIdProduct_fk, b.nIdTypeOrders_fk
FROM tx_ms_orders_d a INNER JOIN tx_ms_orders_h b
ON b.nOrdersId = a.nOrdersId_fk
WHERE
a.sStatusDelete IS NULL AND
b.sStatusDelete IS NULL
AND a.nUnitId_fk = 1
AND b.nUnitId_fk = 1
AND b.nIdTypeOrders_fk = 1;

#Add Field
ALTER TABLE tx_ms_orders_d ADD nOrdersIdReff_fk INT;

#Change SP sp_tx_ms_orders_d
DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_tx_ms_orders_d`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_tx_ms_orders_d`(
  p_sMode CHAR(1),
  p_nOrdersId_fk INT,
  p_nIdProduct_fk VARCHAR (11),
  p_sKondisiBarang CHAR(1),
  p_sDeskripsi VARCHAR (100),
  p_sSN VARCHAR (50),
  p_nQtyDoc INT,
  p_nNoUrut INT,
  p_sUUID VARCHAR (32),
  p_nUnitId_fk INT,
  p_sUserInput VARCHAR (50),
  p_nIdTypeOrders_fk INT,
  p_nIdVendorSource_fk INT,
  p_nIdVendorDestination_fk INT,
  p_sSRProductName VARCHAR (100),
  p_sSRSN VARCHAR (50),
  p_sSRDeskripsi VARCHAR (200),
  p_sSRNoTicket VARCHAR (10),
  p_nSRQty INT
)
BEGIN
	DECLARE p_nOrdersIdReff_fk  INT;
	SELECT a.nOrdersId_fk INTO p_nOrdersIdReff_fk
															FROM tx_ms_orders_d a INNER JOIN tx_ms_orders_h b 
															ON b.nOrdersId = a.nOrdersId_fk WHERE a.sStatusDelete IS NULL 
															AND a.nUnitId_fk = p_nUnitId_fk 
															AND a.sSN = p_sSN AND b.nIdTypeOrders_fk = 1 AND a.nIdProduct_fk = p_nIdProduct_fk
															AND b.sStatusDelete IS NULL LIMIT 1;
  IF p_sMode = 'I' 
  THEN 
  BEGIN
    INSERT INTO tx_ms_orders_d (
      nOrdersId_fk,
      nIdProduct_fk,
      sKondisiBarang,
      sDeskripsi,
      sSN,
      nQtyDoc,
      nQtyMod,
      nNoUrut,
      sUUID,
      nUnitId_fk,
      sSRProductName,
      sSRSN,
      sSRDeskripsi,
      sSRNoTicket,
      sCreateBy,
      dCreateOn,
      nSRQty,
      nOrdersIdReff_fk
    ) 
    VALUES
      (
        p_nOrdersId_fk,
        p_nIdProduct_fk,
        p_sKondisiBarang,
        p_sDeskripsi,
        p_sSN,
        p_nQtyDoc,
        p_nQtyDoc,
        p_nNoUrut,
        MD5(UUID()),
        p_nUnitId_fk,
        p_sSRProductName,
        UPPER(p_sSRSN),
        p_sSRDeskripsi,
        p_sSRNoTicket,
        p_sUserInput,
        CURRENT_TIMESTAMP,
        p_nSRQty,
        p_nOrdersIdReff_fk
      ) ;
    #Inventaris dan Distribusi masukin stock 
    IF p_nIdTypeOrders_fk = 1 OR p_nIdTypeOrders_fk = 4
    THEN 
    BEGIN
      INSERT INTO tx_ms_orders_stock (
        nIdProduct_fk,
        nIdVendor_fk,
        nQtyOH,
        nOrdersId_fk,
        sCreateBy,
        dCreateOn,
        nUnitId_fk,
        sSN,
        sUUID
      ) 
      VALUES
        (
          p_nIdProduct_fk,
          p_nIdVendorDestination_fk,
          p_nQtyDoc,
          p_nOrdersId_fk,
          p_sUserInput,
          CURRENT_TIMESTAMP,
          p_nUnitId_fk,
          UPPER(p_sSN),
          MD5(UUID())
        ) ;
    END ;
    END IF; 
    #distribusi, kurangi stok sumber
    IF p_nIdTypeOrders_fk = 4 
    THEN 
    BEGIN
      #Kalau inventaris nya distribusi, kurangi qty di order yang order type nya inventaris berdasatkan order id dan order type nya inventaris
      UPDATE 
        tx_ms_orders_stock,
        tx_ms_orders_d,
        tx_ms_orders_h
      SET
        tx_ms_orders_stock.nQtyOH = tx_ms_orders_stock.nQtyOH - tx_ms_orders_d.nQtyMod 
      WHERE tx_ms_orders_d.nIdProduct_fk = tx_ms_orders_stock.nIdProduct_fk 
				AND tx_ms_orders_h.`nOrdersId` = tx_ms_orders_d.`nOrdersId_fk`
        AND UPPER(tx_ms_orders_d.sSN) = UPPER(tx_ms_orders_stock.sSN) 
        AND tx_ms_orders_stock.nIdVendor_fk = p_nIdVendorSource_fk 
        AND tx_ms_orders_stock.nOrdersId_fk = (SELECT p.`nOrdersIdReff_fk` FROM tx_ms_orders_d p WHERE p.`nOrdersId_fk` = p_nOrdersId_fk 
        AND p.`sStatusDelete` IS NULL AND p.`nUnitId_fk` = p_nUnitId_fk AND p.`nIdProduct_fk` = tx_ms_orders_stock.`nIdProduct_fk` AND p.sSN = tx_ms_orders_stock.`sSN`)
        AND tx_ms_orders_stock.sStatusDelete IS NULL 
        AND tx_ms_orders_d.sStatusDelete IS NULL 
        AND tx_ms_orders_h.sStatusDelete IS NULL 
        AND tx_ms_orders_stock.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_d.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_h.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_stock.nQtyOH > 0;
    END ;
    END IF ;
  END ;
  ELSEIF p_sMode = 'D' 
  THEN 
  BEGIN
    UPDATE 
      tx_ms_orders_d 
    SET
      sStatusDelete = 'V',
      sDeleteBy = p_sUserInput,
      dDeleteOn = CURRENT_TIMESTAMP 
    WHERE nOrdersId_fk = p_nOrdersId_fk 
      AND sStatusDelete IS NULL 
      AND nUnitId_fk = p_nUnitId_fk ;
  END ;
  END IF ;
END$$

DELIMITER ;

#Drop Field
ALTER TABLE tx_ms_orders_h DROP COLUMN nOrdersIdReff_fk;

#Distribusi
UPDATE  
tx_ms_orders_d, tx_ms_orders_h
SET tx_ms_orders_d.nOrdersIdReff_fk = (SELECT a.nOrdersId_fk
FROM xxx a
WHERE a.sSN = tx_ms_orders_d.sSN
AND a.nIdProduct_fk = tx_ms_orders_d.nIdProduct_fk
LIMIT 1)

WHERE
tx_ms_orders_d.nOrdersId_fk = tx_ms_orders_h.nOrdersId AND
tx_ms_orders_d.nUnitId_fk = 1 AND
tx_ms_orders_d.sStatusDelete IS NULL AND
tx_ms_orders_h.nUnitId_fk = 1 AND
tx_ms_orders_d.sStatusDelete IS NULL AND
tx_ms_orders_h.nIdTypeOrders_fk = 4;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_tx_ms_orders_h`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_tx_ms_orders_h`(
  p_sMode CHAR(1),
  p_nOrdersId INT,
  p_dOrdersDate DATE,
  p_nIdVendorSource_fk INT,
  p_nIdVendorDestination_fk INT,
  p_nIdTypeOrders_fk INT,
  p_sDeskripsi VARCHAR (100),
  p_sUUID VARCHAR (32),
  p_nUnitId_fk INT,
  p_sUserInput VARCHAR (50),
  p_sNoPO VARCHAR (50),
  p_sNoPR VARCHAR (50),
  p_nIdEkspedisi_fk INT,
  p_sSRNIK VARCHAR (10),
  p_sSRNama VARCHAR (50),
  p_nSRIdVendor_fk INT,
  p_sSRNoHP VARCHAR (20),
  p_sSREmail VARCHAR (80),
  p_nTotalQtyOrder INT
)
BEGIN
  IF p_sMode = 'I' 
  THEN 
  BEGIN
    INSERT INTO tx_ms_orders_h (
      nOrdersId,
      dOrdersDate,
      nIdVendorSource_fk,
      nIdVendorDestination_fk,
      nIdTypeOrders_fk,
      sDeskripsi,
      sUUID,
      nUnitId_fk,
      sNoPO,
      sNoPR,
      nIdEkspedisi_fk,
      sSRNIK,
      sSRNama,
      nSRIdVendor_fk,
      sSRNoHP,
      sSREmail,
      sCreateBy,
      dCreateOn,
      nTotalQtyOrder
    ) 
    VALUES
      (
        p_nOrdersId,
        p_dOrdersDate,
        p_nIdVendorSource_fk,
        p_nIdVendorDestination_fk,
        p_nIdTypeOrders_fk,
        p_sDeskripsi,
        MD5(UUID()),
        p_nUnitId_fk,
        p_sNoPO,
        p_sNoPR,
        p_nIdEkspedisi_fk,
        p_sSRNIK,
        p_sSRNama,
        p_nSRIdVendor_fk,
        p_sSRNoHP,
        p_sSREmail,
        p_sUserInput,
        CURRENT_TIMESTAMP,
        p_nTotalQtyOrder
      ) ;
  END ;
  ELSEIF p_sMode = 'U' 
  THEN 
  BEGIN
    UPDATE 
      tx_ms_orders_h 
    SET
      dOrdersDate = p_dOrdersDate,
      nIdVendorSource_fk = p_nIdVendorSource_fk,
      nIdVendorDestination_fk = p_nIdVendorDestination_fk,
      nIdTypeOrders_fk = p_nIdTypeOrders_fk,
      sNoPO = p_sNoPO,
      nIdEkspedisi_fk = p_nIdEkspedisi_fk,
      sNoPR = p_sNoPR,
      nTotalQtyOrder = p_nTotalQtyOrder,
      sDeskripsi = p_sDeskripsi,
      sSRNIK = p_sSRNIK,
      sSRNama = p_sSRNIK,
      nSRIdVendor_fk = p_nSRIdVendor_fk,
      sSRNoHP = p_sSRNoHP,
      sSREmail = p_sSREmail,
      sUUID = MD5(UUID()),
      nUnitId_fk = p_nUnitId_fk,
      sLastEditBy = p_sUserInput,
      dLastEditOn = CURRENT_TIMESTAMP 
    WHERE nOrdersId = p_nOrdersId 
      AND sStatusDelete IS NULL ;
  END ;
  ELSEIF p_sMode = 'D' 
  THEN 
  BEGIN
    UPDATE 
      tx_ms_orders_h 
    SET
      sStatusDelete = 'V',
      sDeleteBy = p_sUserInput,
      dDeleteOn = CURRENT_TIMESTAMP 
    WHERE nOrdersId = p_nOrdersId 
      AND sStatusDelete IS NULL 
      AND nUnitId_fk = p_nUnitId_fk ;
  END ;
  ELSEIF p_sMode = 'E' # Update
  THEN 
  BEGIN
		#Kalau inventaris nya distribusi, tambah qty di order yang order type nya inventaris berdasatkan order id dan order type nya inventaris
      UPDATE 
        tx_ms_orders_stock,
        tx_ms_orders_d,
        tx_ms_orders_h
      SET
        tx_ms_orders_stock.nQtyOH = tx_ms_orders_stock.nQtyOH + tx_ms_orders_d.nQtyDoc 
      WHERE tx_ms_orders_d.nIdProduct_fk = tx_ms_orders_stock.nIdProduct_fk 
				AND tx_ms_orders_h.`nOrdersId` = tx_ms_orders_d.`nOrdersId_fk`
				AND tx_ms_orders_d.`nOrdersId_fk` = tx_ms_orders_stock.`nOrdersId_fk`
        AND UPPER(tx_ms_orders_d.sSN) = UPPER(tx_ms_orders_stock.sSN) 
        AND tx_ms_orders_stock.nIdVendor_fk =  p_nIdVendorDestination_fk 
        AND tx_ms_orders_d.nOrdersId_fk = (SELECT p.`nOrdersIdReff_fk` FROM tx_ms_orders_d p WHERE p.`nOrdersId_fk` = p_nOrdersId AND p.`sStatusDelete` IS NULL AND p.`nUnitId_fk` = p_nUnitId_fk AND p.`nIdProduct_fk` = tx_ms_orders_d.`nIdProduct_fk` AND p.sSN = tx_ms_orders_d.`sSN`)
        AND tx_ms_orders_stock.sStatusDelete IS NULL 
        AND tx_ms_orders_d.sStatusDelete IS NULL 
        AND tx_ms_orders_h.sStatusDelete IS NULL 
        AND tx_ms_orders_stock.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_d.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_h.nUnitId_fk = p_nUnitId_fk ;
  END ;
  ELSEIF p_sMode = 'F' # Delete
  THEN 
  BEGIN
		#Kalau inventaris nya distribusi, tambah qty di order yang order type nya inventaris berdasatkan order id dan order type nya inventaris
      UPDATE 
        tx_ms_orders_stock,
        tx_ms_orders_d,
        tx_ms_orders_h
      SET
        tx_ms_orders_stock.nQtyOH = tx_ms_orders_stock.nQtyOH + tx_ms_orders_d.nQtyDoc 
      WHERE tx_ms_orders_d.nIdProduct_fk = tx_ms_orders_stock.nIdProduct_fk 
				AND tx_ms_orders_h.`nOrdersId` = tx_ms_orders_d.`nOrdersId_fk`
				AND tx_ms_orders_d.`nOrdersId_fk` = tx_ms_orders_stock.`nOrdersId_fk`
        AND UPPER(tx_ms_orders_d.sSN) = UPPER(tx_ms_orders_stock.sSN) 
        AND tx_ms_orders_stock.nIdVendor_fk =  p_nIdVendorSource_fk 
        AND tx_ms_orders_d.nOrdersId_fk = (SELECT p.`nOrdersIdReff_fk` FROM tx_ms_orders_d p WHERE p.`nOrdersId_fk` = p_nOrdersId AND p.`sStatusDelete` IS NULL AND p.`nUnitId_fk` = p_nUnitId_fk AND p.`nIdProduct_fk` = tx_ms_orders_d.`nIdProduct_fk` AND p.sSN = tx_ms_orders_d.`sSN`)
        AND tx_ms_orders_stock.sStatusDelete IS NULL 
        AND tx_ms_orders_d.sStatusDelete IS NULL 
        AND tx_ms_orders_h.sStatusDelete IS NULL 
        AND tx_ms_orders_stock.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_d.nUnitId_fk = p_nUnitId_fk 
        AND tx_ms_orders_h.nUnitId_fk = p_nUnitId_fk ;
  END ;
  END IF ;
END$$

DELIMITER ;