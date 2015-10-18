# DBaseReader

Reads .dbf files into a DataFrame. 

Written in pure Julia; only package dependency is DataFrames. File import speed is roughly on par with the DataFrames package's readtable function applied to an equivalent csv.

Example Use
===========

    using DBaseReader
    
    df = readdbf("path/to/file.dbf")

Known Issues
============

* Only supports "Numeric" and "Character" field types. (I don't have dbfs with anything else. File an issue and include a dbf with other field types, and I'll add suport.)
* Might not correctly import dbfs written with QGIS. There are apparently some quirks of data termination in those files, but I don't have any handy to test against.
* Does not respect the delete flag that may be present on a record. Right now, if it appears in the file, it shows up in your DataFrame.
* Does not attempt to detect ESRI's signal value(s) for "no data": < -10^38
* Reader only; can't write to dbf. Perhaps the package name would have indicated that....