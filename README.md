# DBaseReader

Reads a .dbf file into a `DataFrame`.

Written in pure Julia; only package dependency is DataFrames. File import
speed is roughly on par with the DataFrames package's `readtable` function
applied to an equivalent csv, as long as there are no Date fields in the file.

Example Use
-----------

    using DBaseReader

    df = readdbf("path/to/file.dbf")

Known Issues
------------

* Numeric ('N'), Character ('C'), Date ('D'), and Logical ('L') field types
  are the only ones supported. Logical type is untested.
* Might not correctly import dbfs written with QGIS. There can apparently
  be some quirks of data termination in those files, but I don't have any
  specimens.
* Does not respect the delete flag that may be present on a record.
  Right now, if it appears in the file, it shows up in your DataFrame.
* Does not attempt to detect ESRI's signal value(s) for "no data": < -10^38
  (Unclear from https://www.esri.com/library/whitepapers/pdfs/shapefile.pdf
  whether this signal value applies to all pieces of a shapefile, or only
  the .shp itself.)


To Do
-----

* Test 'L' (logical) field type against appropriate shapefile.
* Sort out the (alleged) QGIS quirks
* ?Respect delete flag?
* ?Add a companion DBaseWriter module?
