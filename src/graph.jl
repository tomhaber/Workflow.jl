using LightGraphs, MetaGraphs

Graph = MetaDiGraph

function push_node!(g::Graph; pv...)
    add_vertex!(g)
    n = nv(g)
    for (p,v) in pv
        set_prop!(g, n, p, v)
    end
    n
end
