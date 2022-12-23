SELECT
	PKGORIGIN
FROM
	Port P
WHERE
	MAINTAINER = '%s'
	AND
	EXISTS(
		SELECT
			*
		FROM
			PortFlavor PF
		WHERE
			PF.PKGORIGIN = P.PKGORIGIN
			AND
			USES like '%%%s%%'
	)