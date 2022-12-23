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
			Broken B
		WHERE
			B.PKGORIGIN = P.PKGORIGIN
	)
