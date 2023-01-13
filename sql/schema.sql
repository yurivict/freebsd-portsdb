CREATE TABLE Port(
	PKGORIGIN          TEXT NOT NULL,
	PORTNAME           TEXT NOT NULL,
	PORTVERSION        TEXT NOT NULL,
	DISTVERSION        TEXT NOT NULL,
	DISTVERSIONPREFIX  TEXT NULL,
	DISTVERSIONSUFFIX  TEXT NULL,
	PORTREVISION       INTEGER NULL,
	PORTEPOCH          INTEGER NULL,
	CATEGORIES         TEXT NOT NULL,
	MAINTAINER         TEXT NOT NULL,
	WWW                TEXT NULL,
	CPE_STR            TEXT NULL,
	COMPLETE_OPTIONS_LIST TEXT NULL,
	OPTIONS_DEFAULT    TEXT NULL,
	FLAVORS            TEXT NULL,
	PRIMARY KEY (PKGORIGIN)
);
CREATE TABLE PortFlavor(
	PKGORIGIN          TEXT NOT NULL,
	FLAVOR             TEXT NOT NULL,
	COMMENT            TEXT NOT NULL,
	PKGBASE            TEXT NOT NULL,
	PKGNAME            TEXT NOT NULL,
	PKGNAMESUFFIX      TEXT NULL,
	USES               TEXT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR),
	FOREIGN KEY (PKGORIGIN) REFERENCES Port (PKGORIGIN)
);
CREATE TABLE Depends(
	PARENT_PKGORIGIN     TEXT NOT NULL,
	PARENT_FLAVOR        TEXT NOT NULL,
	PARENT_PHASE         TEXT NULL, -- there can't be multiple phases for the same combination of other fields, so it isn't included in PK
	CHILD_PKGORIGIN      TEXT NOT NULL,
	CHILD_FLAVOR         TEXT NOT NULL,
	KIND                 CHAR NOT NULL,
	PRIMARY KEY (PARENT_PKGORIGIN, PARENT_FLAVOR, CHILD_PKGORIGIN, CHILD_FLAVOR, KIND),
	FOREIGN KEY (PARENT_PKGORIGIN, PARENT_FLAVOR) REFERENCES PortFlavor(PKGORIGIN, FLAVOR),
	FOREIGN KEY (CHILD_PKGORIGIN, CHILD_FLAVOR) REFERENCES PortFlavor(PKGORIGIN, FLAVOR)
);
CREATE TABLE GitHub(
	PKGORIGIN            TEXT NOT NULL,
	FLAVOR               TEXT NOT NULL,
	USE_GITHUB           TEXT NOT NULL,
	GH_ACCOUNT           TEXT NOT NULL,
	GH_PROJECT           TEXT NOT NULL,
	GH_TAGNAME           TEXT NOT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR),
	FOREIGN KEY (PKGORIGIN, FLAVOR) REFERENCES PortFlavor (PKGORIGIN, FLAVOR)
);
CREATE TABLE GitLab(
	PKGORIGIN            TEXT NOT NULL,
	FLAVOR               TEXT NOT NULL,
	USE_GITLAB           TEXT NOT NULL,
	GL_SITE              TEXT NOT NULL,
	GL_ACCOUNT           TEXT NOT NULL,
	GL_PROJECT           TEXT NOT NULL,
	GL_COMMIT            TEXT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR),
	FOREIGN KEY (PKGORIGIN, FLAVOR) REFERENCES PortFlavor (PKGORIGIN, FLAVOR)
);
CREATE TABLE Deprecated(
	PKGORIGIN            TEXT NOT NULL,
	FLAVOR               TEXT NOT NULL,
	DEPRECATED           TEXT NOT NULL,
	EXPIRATION_DATE      TEXT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR)
);
CREATE TABLE Broken(
	PKGORIGIN            TEXT NOT NULL,
	FLAVOR               TEXT NOT NULL,
	BROKEN               TEXT NOT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR)
);
CREATE TABLE MakefileDependencies(
	PKGORIGIN            TEXT NOT NULL,
	FLAVOR               TEXT NOT NULL,
	MAKEFILE             TEXT NOT NULL,
	PRIMARY KEY (PKGORIGIN, FLAVOR, MAKEFILE),
	FOREIGN KEY (PKGORIGIN, FLAVOR) REFERENCES PortFlavor (PKGORIGIN, FLAVOR)
);
CREATE TABLE RevisionLog(
	UPDATE_TIMESTAMP     TEXT NOT NULL,
	GIT_HASH             TEXT NOT NULL,
	COMMENT              TEXT NOT NULL,
	PRIMARY KEY (UPDATE_TIMESTAMP)
);

CREATE INDEX Port_ByPortname ON Port(PORTNAME);
CREATE INDEX Port_ByMaintaner ON Port(MAINTAINER);
CREATE INDEX Depends_ByChild ON Depends(CHILD_PKGORIGIN, CHILD_FLAVOR);
CREATE INDEX GitHub_ByAccountProject ON GitHub(GH_ACCOUNT, GH_PROJECT);
CREATE INDEX GitLab_ByAccountProject ON GitLab(GL_ACCOUNT, GL_PROJECT);
CREATE INDEX Deprecated_ByExpirationDate ON Deprecated(EXPIRATION_DATE);
CREATE INDEX MakefileDependencies_ByMakefile ON MakefileDependencies(MAKEFILE);
