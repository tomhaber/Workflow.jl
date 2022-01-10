using Graphs

Node = Int64
Graph = DiGraph{Node}

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

struct FlowGraph{T,R}
    graph::Graph
    name::Symbol
    self::Function
    begin_node::Node
    end_node::Node
    nodes::Vector{NodeType}
end

function FlowGraph(name::Symbol, self::Function, argtypes::Tuple, rettype::Type)
    T = Tuple{argtypes...}
    R = rettype
    input_types = Tuple{typeof(self), argtypes...}

    graph = Graph()
    begin_node = push_node!(graph)
    end_node = push_node!(graph)
    FlowGraph{T,R}(graph, name, self, begin_node, end_node, [BeginNode(input_types), EndNode(rettype)])
end

push_node!(g::FlowGraph; pv...) = push_node!(g.graph; pv...)
connect!(g::FlowGraph, src::Node, dst::Node; pv...) = add_edge_meta!(g.graph, src, dst; pv...)
connect_to_input!(g::FlowGraph, dst::Node, arg::Int; pv...) = connect!(g, g.begin_node, dst; arg=arg, pv...)
connect_to_output!(g::FlowGraph, src::Node; pv...) = connect!(g, src, g.end_node; pv...)

is_begin_node(fg::FlowGraph, n::Node) = n == fg.begin_node
end_node(fg::FlowGraph) = fg.end_node

function all_inputs(fg::FlowGraph, n::Node)
    ((src,get_prop(fg.graph, Edge(src, n), :idx)) for src in inneighbors(fg.graph, n))
end

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

function node_meta(fg::FlowGraph, n::Node, which::Symbol)
    # if ! has_prop(fg.graph, n, which)
    #     @warn "node $n has no $which property: $(props(fg.graph, n))"
    # end

    get_prop(fg.graph, n, which)
end

function node_expression(fg::FlowGraph, n::Node)
    input_types = get_prop(fg.graph, n, :input_types)
    body = get_prop(fg.graph, n, :expr)
    args = get_prop(fg.graph, n, :args)
    body, args, input_types
end

has_expression(fg::FlowGraph, n::Node) = has_prop(fg.graph, n, :expr)

import Base: iterate, length
iterate(fg::FlowGraph) = iterate(1:nv(fg.graph))
iterate(fg::FlowGraph, state::Node) = iterate(1:nv(fg.graph), state)
length(fg::FlowGraph) = nv(fg.graph)

topological_sort(fg::FlowGraph) = topological_sort_by_dfs(fg.graph)
