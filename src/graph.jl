using LightGraphs, MetaGraphs
using ParserCombinator, GraphIO

Node = Int64
Graph = MetaDiGraph{Node, Float64}

function push_node!(g::Graph; pv...)
    add_vertex!(g)
    n = nv(g)
    for (p,v) in pv
        set_prop!(g, n, p, v)
    end
    n
end

function add_edge_meta!(g::Graph, src::Node, dst::Node; pv...)
    add_edge!(g, src, dst)
    e = ne(g)
    for (p,v) in pv
        set_prop!(g, e, p, v)
    end
    e
end

struct FlowGraph{Type}
    graph::Graph
    name::Symbol
    begin_node::Int64
    end_node::Int64
end

function FlowGraph(name::Symbol, ::Type{T}) where {T <: Tuple}
    graph = Graph()
    begin_node = push_node!(graph; type=:begin)
    end_node = push_node!(graph; type=:end)
    FlowGraph{T}(graph, name, begin_node, end_node)
end

#function connect_endnode(graph::FlowGraph, node::Value)
#
#end

(g::FlowGraph{T})(x...) where T = g(T(x...))
(g::FlowGraph{T})(x::T) where T = error("NYI")

push_node!(g::FlowGraph; pv...) = push_node!(g.graph; pv...)
connect!(g::FlowGraph, src::Node, dst::Node; pv...) = add_edge_meta!(g.graph, src, dst; pv...)

function save(g::FlowGraph, fn::AbstractString)
    savegraph(fn, g.graph, "flow", GraphIO.DOTFormat())
    nothing
end
