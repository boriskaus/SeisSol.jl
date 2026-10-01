# SeisSol parameter files are Fortran namelists: `Key = value ! comment`.
# These helpers edit single `Key = value` lines and leave everything else untouched.

format_value(v::AbstractString) = "'" * v * "'"
format_value(v::Bool) = v ? "1" : "0"
format_value(v::AbstractFloat) = string(v)
format_value(v::Integer) = string(v)
format_value(v::Union{Tuple,AbstractVector}) = join(format_value.(v), " ")

key_regex(key) = Regex("^([ \\t]*)" * key * "([ \\t]*=[ \\t]*)([^!\\n]*?)([ \\t]*(?:!.*)?)\$", "im")

"""
    get_parameter(parfile, key) -> String

Return the (unparsed) value of `key` in the SeisSol parameter file `parfile`, without quotes.
"""
function get_parameter(parfile::AbstractString, key::AbstractString)
    m = match(key_regex(key), read(parfile, String))
    m === nothing && throw(KeyError(key))
    return strip(strip(m.captures[3]), '\'')
end

"""
    set_parameters!(parfile; key=value, ...)
    set_parameters!(parfile, Dict("Key" => value, ...))

Change existing entries of a SeisSol parameter file in place (keys are case-insensitive).
Strings are quoted, numbers and vectors are written plainly. Trailing `!` comments are kept.
Throws a `KeyError` if a key is not present.

```julia
set_parameters!("parameters.par"; EndTime = 2.0, MeshFile = "mesh.puml.h5")
```
"""
function set_parameters!(parfile::AbstractString, pairs::AbstractDict)
    txt = read(parfile, String)
    for (key, value) in pairs
        r = key_regex(string(key))
        occursin(r, txt) || throw(KeyError(string(key)))
        new = format_value(value)
        m = match(r, txt)
        txt = txt[1:prevind(txt, m.offset)] * m.captures[1] * string(key) * m.captures[2] * new *
              m.captures[4] * txt[m.offset+ncodeunits(m.match):end]
    end
    write(parfile, txt)
    return parfile
end
set_parameters!(parfile::AbstractString; kwargs...) =
    set_parameters!(parfile, Dict(string(k) => v for (k, v) in kwargs))

"""
    delete_parameter!(parfile, key)

Remove the line `key = ...` from the parameter file (SeisSol then uses its default).
"""
function delete_parameter!(parfile::AbstractString, key::AbstractString)
    txt = read(parfile, String)
    r = Regex("^[ \\t]*" * key * "[ \\t]*=[^\\n]*\\n?", "im")
    occursin(r, txt) || throw(KeyError(key))
    write(parfile, replace(txt, r => ""; count = 1))
    return parfile
end
