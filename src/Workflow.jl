module Workflow

include("ast.jl")
include("macros.jl")
include("graph.jl")

struct FlowGraph
    graph::Graph
    name::Symbol
    begin_node::Int64
    end_node::Int64
end

function FlowGraph(name::Symbol)
    graph = Graph()
    begin_node = push_node!(graph; type=:begin)
    end_node = push_node!(graph; type=:end)
    FlowGraph(graph, name, begin_node, end_node)
end

end
