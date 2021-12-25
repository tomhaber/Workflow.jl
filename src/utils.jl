"""
    Fix1(f, x)

A type representing a partially-applied version of the two-argument function
`f`, with the first argument fixed to the value "x". In other words,
`Fix1(f, x)` behaves similarly to `y->f(x, y)`.
"""
struct Fix1{F,T} <: Function
    f::F
    x::T

    Fix1(f::F, x::T) where {F,T} = new{F,T}(f, x)
    Fix1(f::Type{F}, x::T) where {F,T} = new{Type{F},T}(f, x)
end

(f::Fix1)(y) = f.f(f.x, y)

function is_short_function_def(ex)
    ex.head === :(=) || return false
    while length(ex.args) >= 1 && isa(ex.args[1], Expr)
        (ex.args[1].head === :call) && return true
        (ex.args[1].head === :where || ex.args[1].head === :(::)) || return false
        ex = ex.args[1]
    end
    return false
end

function infertypes(@nospecialize(f), @nospecialize(types=Tuple))
    RT = Base.return_types(f, types)
    return Union{RT...}
end
