import Base: print

abstract type NodeType end
print(io::IO, x::NodeType) = print(io, "$(name(x))::$(type(x))")

struct BeginNode <: NodeType
    input_types::Type{<:Tuple}
end
name(::BeginNode) = "begin"
type(x::BeginNode) = x.input_types

struct EndNode <: NodeType
    type::DataType
end
name(::EndNode) = "end"
type(x::EndNode) = x.type

struct ConstantNode{T} <: NodeType
    val::T
end
#ConstantNode(x::T) where T = ConstantNode{T}(x)

name(x::ConstantNode) = "Const($(x.val))"
type(::ConstantNode{T}) where T = T

struct CallNode <: NodeType
    ex::Expr
    input_types::Type{<:Tuple}
    args::Vector{Symbol}
    type::DataType

    function CallNode(ex::Expr, input_types::Type{<:Tuple}, args::Vector{Symbol}, type::DataType)
        @assert ex.head === :call
        @assert length(input_types) == length(args)
        new(ex, input_types, args, type)
    end
end

name(x::CallNode) = first(x.ex.args)
type(x::CallNode) = x.type
print(io::IO, x::CallNode) = print(io, "$(first(x.ex.args))::$(x.type)")
