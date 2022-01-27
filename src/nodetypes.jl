import Base: print

abstract type NodeType end
print(io::IO, x::NodeType) = print(io, "$(nodename(x))::$(nodetype(x))")

struct BeginNode <: NodeType
    input_types::Type{<:Tuple}
end
nodename(::BeginNode) = "begin"
nodetype(x::BeginNode) = x.input_types

struct EndNode <: NodeType
    type::DataType
end
nodename(::EndNode) = "end"
nodetype(x::EndNode) = x.type

struct ConstantNode{T} <: NodeType
    val::T
end

nodename(x::ConstantNode) = "Const($(x.val))"
nodetype(::ConstantNode{T}) where T = T

struct GlobalRefNode <: NodeType
    ref::GlobalRef
    type::Any
end

nodename(x::GlobalRefNode) = "GlobalRef($(x.ref))"
nodetype(x::GlobalRefNode) = x.type

struct CallNode <: NodeType
    ex::Expr
    input_types::Type{<:Tuple}
    args::Vector{Symbol}
    type::Any

    function CallNode(ex::Expr, input_types::Type{<:Tuple}, args::Vector{Symbol}, type::Any)
        @assert ex.head === :call
        @assert fieldcount(input_types) == length(args)
        new(ex, input_types, args, type)
    end
end

nodename(x::CallNode) = string(first(x.ex.args))
nodetype(x::CallNode) = x.type
print(io::IO, x::CallNode) = print(io, "$(first(x.ex.args))::$(x.type)\n$(x.ex)")

struct EdgeProp
    idx::Int64
    name::Symbol
end
