# DBaseReader

Reads a .dbf file into a `DataFrame`.

Written in pure Julia; only package dependency is DataFrames. File import speed is roughly on par with the DataFrames package's `readtable` function applied to an equivalent csv.

Example Use
-----------

    using DBaseReader

    df = readdbf("path/to/file.dbf")

Known Issues
------------

* Numeric ('N') and Character ('C') field types are the only ones tested so far.
* Might not correctly import dbfs written with QGIS. There are apparently some quirks of data termination in those files, but I don't have any handy to test against.
* Does not respect the delete flag that may be present on a record. Right now, if it appears in the file, it shows up in your DataFrame.
* Does not attempt to detect ESRI's signal value(s) for "no data": < -10^38  (Unclear from https://www.esri.com/library/whitepapers/pdfs/shapefile.pdf whether this signal value applies to all pieces of a shapefile, or only the .shp itself.)


Future Work
-----------

* Add some real tests and get set up with travis.
* Test 'L' and 'D' field types (logical and date) against appropriate shapefiles.
* Sort out the (alleged) QGIS quirks
* ?Respect delete flag?
* ?Add a companion DBaseWriter module?
