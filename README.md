# PortsDB
PortsDB is a program for importing of the FreeBSD ports tree into an SQLite database.

## Purpose
SQLite is a relational database. In many cases it is easier to query data in a relational database than when the data is in text files.

## How to use PortsDB
Just run the command './import.sh' on a FreeBSD system. It will run for several minutes and will create the database 'ports.sqlite'.

## What to do with the database produced by PortsDB?
A variety of applications can easily run SQL queries against the PortsDB database to
* list ports or packages
* list port dependencies in both directions
* find the list of ports maintained by a particular maintainer
* search ports by the content of their comment
* any other similar applications

## What software does PortsDB depend on?
There are only three dependencies:
* Bourne shell (/bin/sh) which is already present on all systems
* BSD make which is already present on all systems
* SQLite database application which can be installed from the 'sqlite3' package
