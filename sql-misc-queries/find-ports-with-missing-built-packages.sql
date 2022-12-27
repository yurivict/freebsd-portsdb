ATTACH '/var/db/pkg/repo-FreeBSD.sqlite' AS REPO;

SELECT
	PKGORIGIN
FROM
	Port
WHERE
	NOT EXISTS(
		SELECT * FROM REPO.packages WHERE origin = Port.PKGORIGIN
	)
