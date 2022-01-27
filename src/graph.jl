using Graphs

const Node = Int64
const Graph = DiGraph{Node}
const Edge = Graphs.SimpleEdge{Node}

struct FlowGraph{T,R}
    graph::Graph
    name::Symbol
    self::Function
    begin_node::Node
    end_node::Node
    nodes::Vector{NodeType}
    edges::Dict{Edge, EdgeProp}
end

function FlowGraph(name::Symbol, self::Function, argtypes::Tuple, rettype::Type)
    T = Tuple{argtypes...}
    R = rettype
    input_types = Tuple{typeof(self), argtypes...}

    graph = Graph()
    begin_node = add_vertex!(graph) && nv(graph)
    end_node = add_vertex!(graph) && nv(graph)
    FlowGraph{T,R}(graph, name, self,
        begin_node, end_node,
        [BeginNode(input_types), EndNode(rettype)],
        Dict{Edge,EdgeProp}())
end

function push_node!(g::FlowGraph, node::NodeType)
    add_vertex!(g.graph) || error("failed to add node")
    push!(g.nodes, node)
    @assert length(g.nodes) == nv(g.graph) "WTF $(length(g.nodes)) != $(nv(g.graph))"
    nv(g.graph)
end

function rem_node!(g::FlowGraph, v::Node)
    n = nv(g.graph)

    for u in inneighbors(g.graph, v)
        delete!(g.edges, Edge(u,v))
    end

    for u in outneighbors(g.graph, v)
        delete!(g.edges, Edge(v,u))
    end

    if v != n
        # v is the new n
        for u in inneighbors(g.graph, n)
            prop = g.edges[Edge(u,n)]
            delete!(g.edges, Edge(u,n))
            push!(g.edges, Edge(u,v) => prop)
        end

        for u in outneighbors(g.graph, n)
            prop = g.edges[Edge(n,u)]
            delete!(g.edges, Edge(n,u))
            push!(g.edges, Edge(v,u) => prop)
        end

        g.nodes[v] = g.nodes[n]
    end

    pop!(g.nodes)
    rem_vertex!(g.graph, v)
end

function connect!(g::FlowGraph, src::Node, dst::Node, idx::Int64, name::Symbol)
    add_edge!(g.graph, src, dst)
    push!(g.edges, Edge(src,dst) => EdgeProp(idx,name))
end

connect_to_input!(g::FlowGraph, dst::Node, idx::Int64, name::Symbol) = connect!(g, g.begin_node, dst, idx, name)
connect_to_output!(g::FlowGraph, src::Node) = connect!(g, src, g.end_node, 1, :result)

find_node(g::FlowGraph, n::Node) = g.nodes[n]

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
        node = fg.nodes[i]
        println("$i $(typeof(node)) $(nodename(node))")
        label = escape_string(string(node))
        println(io,"\t$i [label=\"$i: $(label)\"]")

    end

    for e in edges(g)
        prop = fg.edges[e]
        println(io, "\t$(e.src) -> $(e.dst) [label=\"$(prop.name)\"]")
    end
    println(io,"}")
end

function prune_unreachable!(fg::FlowGraph)
    parents = dfs_parents(fg.graph, fg.end_node, dir=:in)
    for (v,p) in enumerate(parents)
        if p == 0
            rem_node!(fg, v)
        end
    end
    fg
end

nodetype(fg::FlowGraph, n::Node) = nodetype(fg.nodes[n])

import Base: iterate, length
iterate(fg::FlowGraph) = iterate(1:nv(fg.graph))
iterate(fg::FlowGraph, state::Node) = iterate(1:nv(fg.graph), state)
length(fg::FlowGraph) = nv(fg.graph)

topological_sort(fg::FlowGraph) = topological_sort_by_dfs(fg.graph)

# function topological_sort(fg::FlowGraph)
#     g= fg.graph
#     color = zeros(UInt8, nv(g))
#     L = Vector{Node}()

#     S = []
#     for v in vertices(g)
#         color[v] != 0 && continue

#         push!(S, v)
#         while !isempty(S)
#             u = pop!(S)
#             if color[u] == 1
#                 push!(L, u)
#             else
#                 color[u] = 1
#                 push!(S, u)
#                 for n in outneighbors(g, u)
#                     if color[n] == 0
#                         push!(S, n)
#                     end
#                 end
#             end
#         end
#     end

#     L
# end

function dfs(g::AbstractGraph{T}, s::Integer, neighborfn::Function=outneighbors) where T
#    parents = zeros(T, nv(g))

    seen = falses(nv(g))
    S = Vector{T}([s])
#    parents[s] = s
    while !isempty(S)
        v = pop!(S)
        seen[v] && continue

        for n in neighborfn(g, v)
            if !seen[n]
                push!(S, n)
#                parents[n] = v
            end
        end
    end
#    parents
end
