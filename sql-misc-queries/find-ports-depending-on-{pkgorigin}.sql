SELECT
	CHILD_PKGORIGIN,
	KIND
FROM
	Depends
WHERE
	PARENT_PKGORIGIN = '%s'
