var_type_expr(T::Symbol) = Expr(:curly, :Value, T)

function transform_header(ex::Expr)
    xf(x::Symbol) = Expr(:(::), x, var_type_expr(:Any))
    xf(x::ExDColon) = Expr(:(::), x.args[1], var_type_expr(x.args[2]))
    xf(x::ExKw) = error("kw arguments not supported")
    xf(ex::Expr) = xf(toExH(ex))

    args = map(xf, ex.args[2:end])
    syms = Set(map(ex -> first(ex.args), args))

    @assert ex.head == :call
    syms, Expr(:call, ex.args[1], args...)
end

struct XFState
    g::Symbol
    vars::Set{Symbol}
end

XFState(g::Symbol) = XFState(g, Set{Symbol}())

transform_expr(s::XFState) = Fix1(transform_expr, s)
transform_expr(s::XFState, ex::ExH) = error("expression $(ex.head) not implemented")

function transform_expr(s::XFState, ex::ExAssign)
    lhs, rhs = ex.args

    syms = get_symbols(rhs)
    intersect!(syms, s.vars)
    if !isempty(syms)
        push!(s.vars, lhs)
    end

    Expr(:(=), lhs, transform_expr(s, rhs))
end

function transform_expr(s::XFState, ex::ExCall)
    func = ex.args[1]
    args = ex.args[2:end]
    syms = get_symbols(args)
    intersect!(syms, s.vars)

    quote
        n = push_node!($(s.g); type=:call, func=$func)
        for s in $(syms)
            add_edge!($(s.g), s, n; name=:s)
        end
        n
    end
end

function transform_expr(s::XFState, ex::ExBlock)
    Expr(:block, map(transform_expr(s), ex.args))
end

transform_expr(s::XFState, x) = x
transform_expr(s::XFState, ex::LineNumberNode) = ex
transform_expr(s::XFState, ex::Expr) = transform_expr(s, toExH(ex))

macro workflow(ex)
    if isa(f, Expr) && (f.head === :function || is_short_function_def(f))
        syms, header = transform_header(ex.args[1])

        graph = gensym("graph")
        state = XFState(graph, syms)
        body = transform_expr(state, ex.args[2])

        body = Expr(:block,
            :($graph = FlowGraph()),
            body...,
            (:return $graph))

        Expr(:block,
            esc(Expr(:function, header, body)),
            esc(ex))
    else
        error("invalid syntax; @workflow must be used with a function definition")
    end
end

