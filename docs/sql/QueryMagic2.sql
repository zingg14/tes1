DROP TABLE IF EXISTS aaa;
DROP TABLE IF EXISTS bbb;
DROP TABLE IF EXISTS ccc;
DROP TABLE IF EXISTS ddd;

#select nOrdersId buat nOrdersIdReff_fk berdasarkan Id pRODUCT DAN SN type nya Distribusi 4
CREATE TABLE aaa SELECT b.nOrdersId, a.nIdProduct_fk, a.sSN
FROM tx_ms_orders_d a INNER JOIN tx_ms_orders_h b
ON b.nOrdersId = a.nOrdersId_fk
WHERE a.sStatusDelete IS NULL AND 
b.sStatusDelete IS NULL AND 
b.nIdTypeOrders_fk = 1;

#ambil sn yang double inventaris
CREATE TABLE bbb
SELECT 
    sSN, 
    COUNT(sSN)
FROM
    tx_ms_orders_d a INNER JOIN tx_ms_orders_h b 
    ON b.nOrdersId = a.nOrdersId_fk WHERE a.sStatusDelete IS NULL AND
    b.sStatusDelete IS NULL AND b.nIdTypeOrders_fk = 1
GROUP BY a.sSN
HAVING COUNT(sSN) > 2;

#bikin sSN baru  type inventaris
CREATE TABLE ccc 
SELECT a.*, UPPER(SUBSTRING(MD5(UUID()), 1, 10)) AS sSNNew FROM tx_ms_orders_d a 
INNER JOIN tx_ms_orders_h b ON b.nOrdersId = a.nOrdersId_fk 
WHERE a.sStatusDelete IS NULL AND b.sStatusDelete IS NULL
AND b.nIdTypeOrders_fk = 1 AND a.sSN IN (SELECT sSN FROM bbb);

#update sSN baru type inventaris
UPDATE tx_ms_orders_d,ccc SET tx_ms_orders_d.sSN = ccc.sSNNew
WHERE tx_ms_orders_d.sUUID = ccc.sUUID;

#update sSN distribusi
UPDATE tx_ms_orders_d, ccc
SET tx_ms_orders_d.sSN = ccc.sSNNew
WHERE 
tx_ms_orders_d.`sStatusDelete` IS NULL AND 
tx_ms_orders_d.`sSN` = ccc.`sSN` AND 
tx_ms_orders_d.`nIdProduct_fk` = ccc.`nIdProduct_fk` AND 
tx_ms_orders_d.`nNoUrut` = ccc.`nNoUrut`;

#ambil order reff id
CREATE TABLE ddd SELECT b.nOrdersId, a.nIdProduct_fk, a.sSN
FROM tx_ms_orders_d a INNER JOIN tx_ms_orders_h b
ON b.nOrdersId = a.nOrdersId_fk
WHERE a.sStatusDelete IS NULL AND 
b.sStatusDelete IS NULL AND 
b.nIdTypeOrders_fk = 1;

#update nOrdersIdReff_fk yang distribusi
UPDATE tx_ms_orders_d, tx_ms_orders_h
SET tx_ms_orders_d.`nOrdersIdReff_fk` = (SELECT DISTINCT ddd.nOrdersId FROM ddd WHERE 
ddd.nIdProduct_fk = tx_ms_orders_d.`nIdProduct_fk` AND ddd.sSN = tx_ms_orders_d.sSN)
WHERE tx_ms_orders_d.`nOrdersId_fk` = tx_ms_orders_h.`nOrdersId`
AND tx_ms_orders_h.`nIdTypeOrders_fk` = 4 AND 
tx_ms_orders_d.`sStatusDelete` IS NULL AND 
tx_ms_orders_h.`sStatusDelete` IS NULL;

#truncate table tx_ms_orders_stock
TRUNCATE TABLE tx_ms_orders_stock;

#masukan stok awal inventaris type 1 dan 4
INSERT INTO tx_ms_orders_stock (nIdProduct_fk, nIdVendor_fk, nQtyOH, nOrdersId_fk, sCreateBy, dCreateOn, sUUID, nUnitId_fk, sSN)
SELECT a.nIdProduct_fk, b.nIdVendorDestination_fk, a.nQtyDoc, b.nOrdersId, a.sCreateBy, a.dCreateOn, MD5(UUID()), a.nUnitId_fk, a.sSN 
FROM tx_ms_orders_d a INNER JOIN tx_ms_orders_h b 
ON b.nOrdersId = a.nOrdersId_fk 
WHERE a.sStatusDelete IS NULL AND 
b.sStatusDelete IS NULL AND
b.nIdTypeOrders_fk IN (1, 4);

#update nQtyOnHand di tx_ms_orders_stock yang inventaris jadi 0 klo sudah di distribusikan
UPDATE tx_ms_orders_stock, tx_ms_orders_h
SET tx_ms_orders_stock.`nQtyOH` = 0 
WHERE tx_ms_orders_h.`nOrdersId` = tx_ms_orders_stock.`nOrdersId_fk`
AND tx_ms_orders_stock.`sStatusDelete` IS NULL
AND tx_ms_orders_h.`sStatusDelete` IS NULL 
AND tx_ms_orders_h.`nIdTypeOrders_fk` = 1
AND tx_ms_orders_h.`nOrdersId` IN ( SELECT p.`nOrdersIdReff_fk` FROM tx_ms_orders_d p INNER JOIN tx_ms_orders_h q 
ON q.`nOrdersId` = p.`nOrdersId_fk` WHERE p.`sStatusDelete` IS NULL AND q.`sStatusDelete` IS NULL AND q.`nIdTypeOrders_fk` = 4);


