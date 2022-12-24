# PortsDB
PortsDB is a program that imports the FreeBSD ports tree into an SQLite database.

## Purpose
SQLite is a relational database. In many cases it is easier to query data in a relational database than when the data is in text files.

## How to use PortsDB
Just run the command './import.sh' on a FreeBSD system. It will run for several minutes and will create the database 'ports.sqlite'.
Then you can update your ports tree and run './update.sh', which will update the database with all new commits.

## What to do with the database produced by PortsDB?
A variety of applications can easily run SQL queries against the PortsDB database to
* list ports or packages
* list port dependencies in both directions
* find the list of ports maintained by a particular maintainer
* search ports by the content of their comment
* any other similar applications

## What software does PortsDB depend on?
There are only few dependencies:
* Bourne shell (/bin/sh) which is already present on all systems
* BSD make which is already present on all systems
* SQLite database application which can be installed from the 'sqlite3' package
* git program
* gsed program

## Design principles
* *Ease of use:* users only need to run import.sh to import the ports tree into a database. They can also choose to run update.sh to quickly update the database with new commits, instead of re-running import.sh, which takes longer
* *Performance:* import.sh only takes ~15 minutes, depending on the system.
* *No artificial keys:* we didn't introduce any external integer keys into tables. Tables are indexed with PKGORIGIN in the form of *{carteg}/{name}* and flavor. This makes tables easy to understand and easy to query.

## How to see what's in PortsDB?
There is an excellent SQLite DB viewer [SQLiteStudio](https://www.sqlitestudio.pl/) that can be installed with ```pkg install SQLiteStudio```.
