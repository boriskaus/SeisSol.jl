# Checks the XDMF output of SeisSol: the binary mesh connectivity (<Topology> of every .xdmf file)
# must have exactly the size that the XML declares (cells x nodes x Precision bytes). A mismatch
# makes ParaView fail to read the files (it happened on Windows, where `unsigned long` has 4 bytes).
# usage: julia ci/check_xdmf.jl <output folder>
dir = ARGS[1]
nchecked = 0
for xdmf in filter(f -> endswith(f, ".xdmf"), readdir(dir; join = true))
    txt = read(xdmf, String)
    for m in eachmatch(r"<Topology[^>]*>\s*<DataItem[^>]*?Precision=\"(\d+)\"[^>]*?Dimensions=\"([\d ]+)\"[^>]*>\s*([^<\s]+)\s*</DataItem>"s, txt)
        prec = parse(Int, m.captures[1])
        n = prod(parse.(Int, split(strip(m.captures[2]))))
        file = joinpath(dirname(xdmf), replace(m.captures[3], '\\' => '/'))
        isfile(file) || error("$(basename(xdmf)): referenced file $(m.captures[3]) does not exist")
        filesize(file) == n * prec ||
            error("$(basename(xdmf)): $(m.captures[3]) has $(filesize(file)) bytes, but the XML declares $n values x $prec bytes = $(n * prec)")
        global nchecked += 1
    end
end
nchecked > 0 || error("no <Topology> data found in $dir")
println("XDMF check passed: $nchecked connectivity files have the declared size")
