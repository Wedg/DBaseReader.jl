module DBaseReader

# File format references used:
# [1] http://www.dbf2002.com/dbf-file-format.html
# [2] http://www.clicketyclick.dk/databases/xbase/format/dbf.html#DBF_NOTE_1_TARGET

using DataFrames

export readdbf, readdbfheader, DBFHeader


function bytestostring(ary)
  # findfirst plus sub-indexing is faster than rstrip(..., ['\0']])
  iend = (findfirst(ary, 0x00)-1)
  if iend > 0
    return rstrip(ASCIIString(ary[1:iend]))
  else
    return rstrip(ASCIIString(ary))
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
# after offset 17. We just stick it all into the "rest" field.
function readfieldinfo(f)
  return DBFFieldInfo(                        # Byte offset
    Symbol(bytestostring(readbytes(f, 11))),  # 0-10
    Char(readbytes(f, 1)[1]),                 # 11
    read(f, Int32),                           # 12-15
    read(f, Int8),                            # 16
    read(f, Int8),                            # 17
    readbytes(f, 14))                         # 18-31
end


function store!(col, datum, typ, decimalplaces, name)
  try
    if typ == 'C'
      push!(col, bytestostring(datum))
    elseif typ == 'N'
      if decimalplaces == 0
        push!(col, parse(Int64, bytestostring(datum)))
      else
        push!(col, parse(Float64, bytestostring(datum)))
      end
    elseif typ == 'D' # Date in YYYYMMDD character format
      yyyy = parse(Int64, bytestostring(datum[1:4]))
      mm = parse(Int64, bytestostring(datum[5:6]))
      dd = parse(Int64, bytestostring(datum[7:8]))
      if yyyy == 0 || mm == 0 || dd == 0
        push!(col, NA)
      else
        push!(col, Date(yyyy, mm, dd))
      end
    elseif typ == 'L' # Character boolean
      if datum in "TtYy"
        push!(col, true)
      elseif datum in "FfNn"
        push!(col, false)
      else
        push!(col, NA)
      end
    else
      push!(col, NA)
    end
  catch # If a conversion failed, call it an NA and move on.
    warn("Failed to convert '$typ' value in column $name")
    push!(col, NA)
  end
  return nothing
end


function parserecords!(cols, chunk, info, recordlength)
  coloffset = 0
  # Iterate column-wise. Yields better performance than row-wise.
  for inf in info
    name = inf.name
    col = cols[name]
    istart = coloffset + 2
    records = length(chunk) / recordlength
    iend = 0
    for x in 1:records
      iend = istart + inf.bytesize - 1
      store!(col, chunk[istart:iend], inf.kind, inf.decimalplaces, name)
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
      cols[inf.name] = DataArray(UTF8String[], Bool[])
    elseif inf.kind == 'D'
      cols[inf.name] = DataArray(Date[], Bool[])
    elseif inf.kind == 'L'
      cols[inf.name] = DataArray(Bool[], Bool[])
    elseif inf.kind == 'N' && inf.decimalplaces == 0
      cols[inf.name] = DataArray(Int64[], Bool[])
    elseif inf.kind == 'N' && inf.decimalplaces != 0
      cols[inf.name] = DataArray(Float64[], Bool[])
    else
      warn("Unsupported column type $(inf.kind); will fill with NA's")
      cols[inf.name] = DataArray(Bool[], Bool[])
    end
  end
  return cols
end


"""
`DBFHeader`

All the information you ever expected to get out of a dBase header.
Fields are: `dbasetype`, `yearmodified`, `monthmodified`, `daymodified`,
`numrecords`, `firstrecordoffset`, `recordlength`, `reservedspace`,
`tableflags`, `codepagemark`, `reservedzeroes`.
"""
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


"""
`readdbfheader(path::AbstractString)`

Reads the header from a dBase file and returns a `DBFHeader` object.
`path` specifies the desired .dbf file, and must include the file extension.
"""
function readdbfheader(path::AbstractString)
  f = open(path)

  h = DBFHeader()
                                                      # Byte offset
  h.dbasetype = readbytes(f, 1)[1]                    # 0
  h.yearmodified = 1900 + read(f, Int8)               # 1
  h.monthmodified = read(f, Int8)                     # 2
  h.daymodified = read(f, Int8)                       # 3
  h.numrecords = read(f, Int32)                       # 4-7
  h.firstrecordoffset = read(f, Int16)                # 8-9
  h.recordlength = read(f, Int16)                     # 10-11
  h.reservedspace = readbytes(f, 16)                  # 12-27
  h.tableflags = readbytes(f, 1)[1]                   # 28
  h.codepagemark = readbytes(f, 1)[1]                 # 29
  h.reservedzeroes = readbytes(f, 2)                  # 30-31

  close(f)

  return h
end


"""
`readdbf(path::AbstractString, maxbytes::Int64=10000000)`

Reads a dBase file into a new `DataFrame`. `path` specifies the desired file,
and must include the file extension. `maxbytes` is optional, and specifies
the maximum number of bytes to read from the file at once.
"""
function readdbf(path::AbstractString, maxbytes::Int64=10000000)
  header = readdbfheader(path)

  f = open(path)

  # Skip over header
  skip(f, 32)

  info = []
  for x in 1:((header.firstrecordoffset - 33) // 32)
    push!(info, readfieldinfo(f))
  end
  readbytes(f, 1) # eat the terminator

  cols = stubcolumns(info)

  # Add data column-wise rather than row-wise because the looping
  # is around 30% faster doing it column-wise. However, this entails skipping
  # the read cursor around in the file rather than incrementing through the
  # file byte-by-byte. For sufficiently large files stored on a magnetic drive,
  # this could be problematic. To avoid this, read the file in contiguous
  # chunks, stepping column-wise through each chunk.
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
