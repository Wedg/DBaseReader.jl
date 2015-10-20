using DBaseReader
using Base.Test

data = joinpath(dirname(@__FILE__), "data")

filename = "$data/cb_2014_us_region_20m.dbf"

df = readdbf(filename)
@test size(df, 1) == 4
@test typeof(df[1,1]) == UTF8String && df[1,1] == "1"
@test typeof(df[1,6]) == Int64 && df[1,6] == 419356559348
@test names(df) == [:REGIONCE,:AFFGEOID,:GEOID,:NAME,:LSAD,:ALAND,:AWATER]

# QGIS 2.10 - generated dbf containing both a Date-type field
# and a Real Numeric field
filename = "$data/test.dbf"
df = readdbf(filename)
@test df[2, :ADate] == Date(1927, 10, 15)
@test typeof(df[2, :AReal]) == Float64 && df[2, :AReal] == 6.62607


# TODO: test for
# * Logical fields (Have never seen one associated with a shapefile though)
