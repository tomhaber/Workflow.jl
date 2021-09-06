using Workflow, Test

@workflow function f(x)
    y = g(x)
    z = h(x, y)
    return z
end
