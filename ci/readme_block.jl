# Prints the code block that follows the marker `<!-- ci:NAME -->` in README.md, so that CI runs
# exactly what the README tells users to copy and paste.
# usage: julia ci/readme_block.jl NAME
name = ARGS[1]
lines = readlines(joinpath(@__DIR__, "..", "README.md"))
i = findfirst(==("<!-- ci:$name -->"), lines)
i === nothing && error("marker ci:$name not found in README.md")
startswith(lines[i+1], "```") || error("no code block after marker ci:$name")
j = findnext(l -> startswith(l, "```"), lines, i + 2)
println(join(lines[i+2:j-1], "\n"))
