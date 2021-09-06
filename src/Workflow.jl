module Workflow

include("utils.jl")
include("ast.jl")
include("macros.jl")
include("graph.jl")

struct Value{T}
    node::Node
end

type(::Value{T}) where T = T

export FlowGraph, @workflow
end
