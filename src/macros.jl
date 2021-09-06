val_type_expr(T::Symbol) = Expr(:curly, :Value, T)

function transform_header(ex::Expr)
    xf(x::Symbol) = Expr(:(::), x, val_type_expr(:Any))
    xf(x::ExDColon) = Expr(:(::), x.args[1], val_type_expr(x.args[2]))
    xf(x::ExKw) = error("kw arguments not supported")

    @assert ex.head == :call
    Expr(:call, ex.args[1], map(xf ∘ toExH, ex.args[2:end])...)
end

function transform_expr(ex::Expr)
    ex
end

macro workflow(ex)
    @assert ex.head == :function
    header = ex.args[1]
    body = ex.args[2]

    Expr(:block,
        esc(Expr(:function, transform_header(header), transform_expr(body))),
        esc(ex))
end

