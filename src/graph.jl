using LightGraphs, MetaGraphs

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

function add_node_meta!(g::Graph, n::Node; pv...)
    for (p,v) in pv
        set_prop!(g, n, p, v)
    end
    n
end

function add_edge_meta!(g::Graph, src::Node, dst::Node; pv...)
    add_edge!(g, src, dst)
    e = ne(g)
    for (p,v) in pv
        set_prop!(g, src, dst, p, v)
    end
    e
end

struct Value{T}
    node::Node
end

type(::Value{T}) where T = T

struct FlowGraph{T,R}
    graph::Graph
    name::Symbol
    self::Function
    begin_node::Node
    end_node::Node
end

function FlowGraph(name::Symbol, self::Function, argtypes::Tuple, rettype::Type)
    T = Tuple{argtypes...}
    R = rettype

    graph = Graph()
    begin_node = push_node!(graph; name=:begin, type=T)
    end_node = push_node!(graph; name=:end, type=rettype)
    FlowGraph{T,R}(graph, name, self, begin_node, end_node)
end

push_node!(g::FlowGraph; pv...) = push_node!(g.graph; pv...)
connect!(g::FlowGraph, src::Node, dst::Node; pv...) = add_edge_meta!(g.graph, src, dst; pv...)
connect_to_input!(g::FlowGraph, dst::Node, arg::Int; pv...) = connect!(g, g.begin_node, dst; arg=arg, pv...)
connect_to_output!(g::FlowGraph, src::Node; pv...) = connect!(g, src, g.end_node; pv...)

(g::FlowGraph{T})(x...) where T = g(T(x...))
(g::FlowGraph{T})(x::T) where T = error("NYI")

function save(fn::AbstractString, g::FlowGraph)
    open(fn, "w") do io
        save(io, g)
    end
end

function save(io::IO, fg::FlowGraph)
    g = fg.graph

    println(io, "digraph flow {")
    for i in vertices(g)
        name = get_prop(g, i, :name)
        ex = has_prop(g, i, :expr) ? get_prop(g, i, :expr) : ""
        type = get_prop(g, i, :type)
        label = escape_string("$(name)::$(type)\n$(ex)")
        println(io,"\t$i [label=\"$i: $(label)\"]")

    end

    for e in edges(g)
        if has_prop(g, e, :name)
            name = get_prop(g, e, :name)
            println(io, "\t$(e.src) -> $(e.dst) [label=\"$name\"]")
        else
            println(io, "\t$(e.src) -> $(e.dst)")
        end
    end
    println(io,"}")
end

function prune_unreachable!(fg::FlowGraph)
    parents = dfs_parents(fg.graph, fg.end_node, dir=:in)
    for (v,p) in enumerate(parents)
        if p == 0
            rem_vertex!(fg.graph, v)
        end
    end
    fg
end
