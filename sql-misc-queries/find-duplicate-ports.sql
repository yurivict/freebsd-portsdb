--
-- finds duplicate ports with names that are same with case insensitive comparison
--

--
-- SLOW query because it can't use the Port.PKGORIGIN index
--

SELECT
	*
FROM
	Port P
WHERE
	EXISTS(
		SELECT
			*
		FROM
			Port PI
		WHERE -- names are same when compared w/out case
			PI.PKGORIGIN <> P.PKGORIGIN
			AND
			LOWER(PI.PKGORIGIN) = LOWER(P.PKGORIGIN)
	)
