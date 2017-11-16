using DBaseReader
using Base.Test

data = joinpath(dirname(@__FILE__), "data")

# Basic tests
filename = "$data/cb_2014_us_region_20m.dbf"
d = readdbf(filename)
@test length(d) == 7
@test length(d[:NAME]) == 4
@test typeof(d[:NAME][1]) == String && d[:NAME][1] == "Northeast"
@test typeof(d[:ALAND][1]) == Int64 && d[:ALAND][1] == 419356559348
@test Set(collect(keys(d))) == Set([:REGIONCE,:AFFGEOID,:GEOID,:NAME,:LSAD,:ALAND,:AWATER])


# QGIS 2.10-generated dbf containing both a Date-type field
# and a Real Numeric field
filename = "$data/test.dbf"
d = readdbf(filename)
@test d[:ADate][2] == Date(1927, 10, 15)
@test typeof(d[:AReal][2]) == Float64 && d[:AReal][2] == 6.62607


# Test FoxPro 'F' type
filename = "$data/taz_small.dbf"
d = readdbf(filename)
@test d[:TAZ2K][1] == 501030005


# TODO: test for
# * Logical fields (Have never seen one associated with a shapefile though)
