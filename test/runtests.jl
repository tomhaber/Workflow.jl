using Workflow, Test

# @workflow function f(x)
#     y = g(x)
#     z = h(x, y)
#     return z
# end

g(x) = x^2
h = +

function _f(graph::FlowGraph, x::Workflow.Value)
    y = begin
        S = Workflow.infertypes(g, (Workflow.type(x),))
        n = Workflow.push_node!(graph; type=S, func=g)
        Workflow.connect!(graph, x.node, n; name=:x)
        Workflow.Value{S}(n)
    end

    z = begin
        S = Workflow.infertypes(h, (Workflow.type(x),Workflow.type(y)))
        n = Workflow.push_node!(graph; type=S, func=h)
        Workflow.connect!(graph, x.node, n; name=:x)
        Workflow.connect!(graph, y.node, n; name=:y)
        Workflow.Value{S}(n)
    end
end

function f(X::Type)
    graph = FlowGraph(:f, Tuple{X})
    x = Workflow.Value{X}(graph.begin_node)
    y = _f(graph, x)
    graph
end
