--
-- Fix Depends.PARENT_FLAVOR when depending on non-empty default flavor
--

UPDATE
	Depends
SET
	PARENT_FLAVOR=(SELECT FLAVOR from PortFlavor WHERE PKGORIGIN=Depends.PARENT_PKGORIGIN ORDER BY RowId ASC LIMIT 1) -- default flavor
WHERE
	PARENT_FLAVOR=''
	AND
	EXISTS (SELECT * from PortFlavor PF WHERE PKGORIGIN=Depends.PARENT_PKGORIGIN AND PF.FLAVOR!='')
	;
