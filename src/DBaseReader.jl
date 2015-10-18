module DBaseReader

# File format references used:
# [1] http://www.dbf2002.com/dbf-file-format.html
# [2] http://www.clicketyclick.dk/databases/xbase/format/dbf.html#DBF_NOTE_1_TARGET

using DataFrames

export readdbf, readdbfheader, DBFHeader

function hextoint(ary::AbstractArray)
  res = 0
  for (p, bt) in enumerate(ary)
    res += 256^(p-1) * Int(ary[p])
  end
  return res
end


function isterm(f)
  t = readbytes(f, 1)
  t == [0x0d] && return true  # eat the terminator!
  skip(f, -1)
  return false
end


function hextostring(ary)
  # We know the chars must be ASCII only.
  # We also know strings are null-terminated in these files, so we
  # can find the termination to eliminate unnecessary conversions.
  # The findfirst code is faster than strip(..., Char(0x00))
  iend = (findfirst(ary, 0x00)-1)
  if iend > 0
    return strip(ASCIIString(ary[1:iend]))
  else
    return strip(ASCIIString(ary))
  end
end

type DBFFieldInfo
  name::Symbol
  kind::Char
  displacement::Int64
  bytesize::Int64
  decimalplaces::Int64
  rest::Array{UInt8}
end


# References [1] and [2] disagree about the lengths and meanings of bytes
# after offset 17. We just stick it all into the "rest" field although
# none of those bytes matter for dbfs associated with shapefiles.
function readfieldinfo(f)
  return DBFFieldInfo(                      # Byte offset
    Symbol(hextostring(readbytes(f, 11))),  # 0-10
    Char(readbytes(f, 1)[1]),               # 11
    hextoint(readbytes(f, 4)),              # 12-15
    hextoint(readbytes(f, 1)),              # 16
    hextoint(readbytes(f, 1)),              # 17
    readbytes(f, 14))                       # 18-31
end


function parserecord!(col, datum, typ, decimalplaces)
  if typ == 'C'
    push!(col, hextostring(datum))

  elseif typ == 'N'
    if decimalplaces == 0
      push!(col, parse(Int64, hextostring(datum)))
    else
      push!(col, parse(Float64, hextostring(datum)))
    end
  end

  return nothing
end


function parserecords!(cols, chunk, info, recordlength)
  coloffset = 0

  # Iterate over columns
  for inf in info
    col = cols[inf.name]
    istart = coloffset + 2
    rows = length(chunk) / recordlength

    iend = 0
    # Iterate over rows
    for x in 1:rows
      iend = istart + inf.bytesize - 1
      parserecord!(col, chunk[istart:iend], inf.kind, inf.decimalplaces)
      istart += recordlength
    end
    coloffset += inf.bytesize
  end

  return nothing
end


function stubcolumns(info)
  cols = Dict()
  for inf in info
    if inf.kind == 'C'
      cols[inf.name] = DataArray(Array(UTF8String, 0),
                                Array(Bool, 0))
    elseif inf.kind == 'N' && inf.decimalplaces == 0
      cols[inf.name] = DataArray(Array(Int64, 0),
                                Array(Bool, 0))
    elseif inf.kind == 'N' && inf.decimalplaces != 0
      cols[inf.name] = DataArray(Array(Float64, 0),
                                Array(Bool, 0))
    end
  end
  return cols
end


type DBFHeader
  dbasetype::UInt8
  yearmodified::Int64
  monthmodified::Int64
  daymodified::Int64
  numrecords::Int64
  firstrecordoffset::Int64
  recordlength::Int64
  reservedspace::Array{UInt8}
  tableflags::UInt8
  codepagemark::UInt8
  reservedzeroes::Array{UInt8}
end
DBFHeader() = DBFHeader(0x00,0,0,0,0,0,0,UInt8[],0x00,0x00,UInt8[])


function readdbfheader(path::AbstractString)
  f = open(path)

  h = DBFHeader()
                                                      # Byte offset
  h.dbasetype = readbytes(f, 1)[1]                    # 0
  h.yearmodified = 1900 + hextoint(readbytes(f, 1))   # 1
  h.monthmodified = hextoint(readbytes(f, 1))         # 2
  h.daymodified = hextoint(readbytes(f, 1))           # 3
  h.numrecords = hextoint(readbytes(f, 4))            # 4-7
  h.firstrecordoffset = hextoint(readbytes(f, 2))     # 8-9
  h.recordlength = hextoint(readbytes(f, 2))          # 10-11
  h.reservedspace = readbytes(f, 16)                  # 12-27
  h.tableflags = readbytes(f, 1)[1]                   # 28
  h.codepagemark = readbytes(f, 1)[1]                 # 29
  h.reservedzeroes = readbytes(f, 2)                  # 30-31

  close(f)

  return h
end


function readdbf(path::AbstractString, maxbytes::Int64=1000000)
  header = readdbfheader(path)

  f = open(path)

  # Skip over header
  skip(f, 32)

  info = []
  while !isterm(f)
    push!(info, readfieldinfo(f))
  end

  cols = stubcolumns(info)

  chunking = div(maxbytes, header.recordlength)
  chunks, extra = divrem(header.numrecords, chunking)

  for x in 1:chunks
    parserecords!(cols, readbytes(f, chunking * header.recordlength), info,
                  header.recordlength)
  end
  extra != 0 && parserecords!(cols, readbytes(f, extra * header.recordlength),
                              info, header.recordlength)

  df = DataFrame()

  # Ensure cols are added to DataFrame in same order they appear in .dbf:
  for inf in info
    df[inf.name] = cols[inf.name]
  end

  close(f)

  return df
end

end # module
