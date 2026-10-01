"""
    read_energy(file) -> Dict{String,NamedTuple}

Read the `*-energy.csv` file written by SeisSol (`EnergyOutput = 1`). Returns, for every
quantity (e.g. `"seismic_moment"`, `"elastic_energy"`), a named tuple `(time, value)` of vectors.
"""
function read_energy(file::AbstractString)
    out = Dict{String,NamedTuple{(:time, :value),Tuple{Vector{Float64},Vector{Float64}}}}()
    for (i, line) in enumerate(eachline(file))
        i == 1 && continue
        isempty(strip(line)) && continue
        t, name, value = split(line, ',')
        entry = get!(out, String(name)) do
            (time = Float64[], value = Float64[])
        end
        push!(entry.time, parse(Float64, t))
        push!(entry.value, parse(Float64, value))
    end
    return out
end

"""
    moment_magnitude(M0)

Moment magnitude of a seismic moment `M0` in N⋅m, as printed by SeisSol: `2/3 log10(M0) - 6.07`.
"""
moment_magnitude(M0::Real) = 2 / 3 * log10(M0) - 6.07
