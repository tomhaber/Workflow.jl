function compile_function(body::Expr)
    ex = Expr(:function, Expr(:tuple), body)
    eval(ex)
end

function compile_function(body::Expr, args::Vector{Symbol}, input_types::Type{<:Tuple})
    X = gensym("input")
    argget = map(enumerate(args)) do (i,x)
        Expr(:(=), x, Expr(:call, :getindex, X, i))
    end

    ex = Expr(:function, Expr(:tuple, Expr(:(::), X, input_types)),
            Expr(:block, argget..., body))
    eval(ex)
end

compile_node(::BeginNode) = identity
compile_node(::EndNode) = first
compile_node(n::ConstantNode) = compile_function(Expr(:call, identity, n.val))
compile_node(n::GlobalRefNode) = compile_function(Expr(:call, Base.getfield, n.ref.mod, QuoteNode(n.ref.name)))
compile_node(n::CallNode) = compile_function(n.ex, n.args, n.input_types)

compile_node(fg::FlowGraph, n::Node) = compile_node(find_node(fg, n))
compile_graph(fg::FlowGraph) = [compile_node(fg, n) for n in fg]

struct CompiledGraph{T,R}
    graph::FlowGraph{T,R}
    code::Vector{Function}
end

function CompiledGraph(fg::FlowGraph{T,R}) where {T,R}
    CompiledGraph{T,R}(fg, compile_graph(fg))
end

(g::CompiledGraph{T, R})(x...) where {T, R} = g(T(x))
function (g::CompiledGraph{T, R})(X::T) where {T, R}
    X = (g.graph.self, X...)

    intermediates = Vector{Any}(undef, length(g.graph))
    order = topological_sort(g.graph)

    for n in order
        f = g.code[n]
        if is_begin_node(g.graph, n)
            intermediates[n] = f(X)
        else
            Input = node_meta(g.graph, n, :input_types)
            inputs = Vector{Any}(undef, fieldcount(Input))
            for (v, i) in all_inputs(g.graph, n)
                inputs[i] = intermediates[v]
            end
            x = Input(inputs)
            intermediates[n] = f(x)
        end
    end

    #intermediates
    intermediates[end_node(g.graph)]
end

