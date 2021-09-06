##########  Parameterized type to ease AST exploration  ############
struct ExH{H}
  head::Symbol
  args::Vector
end
toExH(s::Symbol) = s
toExH(ex::Expr) = ExH{ex.head}(ex.head, ex.args)
toExpr(ex::ExH) = Expr(ex.head, ex.args...)

ExAssign = ExH{:(=)}
ExDColon = ExH{:(::)}
ExKw = ExH{:kw}
ExCurly = ExH{:curly}
ExCall = ExH{:call}
ExBlock = ExH{:block}
ExLine = ExH{:line}
ExRef = ExH{:ref}
ExIf = ExH{:if}
ExDot = ExH{:.}
ExMacro = ExH{:macrocall}
ExQuote = ExH{:quote}

isSymbol(ex)   = isa(ex, Symbol)
isDot(ex)      = isa(ex, Expr) && ex.head == :.   && isa(ex.args[1], Symbol)
isRef(ex)      = isa(ex, Expr) && ex.head == :ref && isa(ex.args[1], Symbol)

## variable symbol sampling functions
get_symbols(ex::Any)    = Set{Symbol}()
get_symbols(ex::Symbol) = Set{Symbol}([ex])
get_symbols(ex::Array)  = mapreduce(get_symbols, union, ex)
get_symbols(ex::Expr)   = get_symbols(toExH(ex))
get_symbols(ex::ExH)    = mapreduce(get_symbols, union, ex.args)
get_symbols(ex::ExQuote)= Set{Symbol}()
get_symbols(ex::ExCall) = mapreduce(get_symbols, union, ex.args[2:end])  # skip function name
get_symbols(ex::ExMacro) = mapreduce(get_symbols, union, ex.args[2:end])  # skip macro name
get_symbols(ex::ExRef)  = setdiff(mapreduce(get_symbols, union, ex.args), Set([:(:), symbol("end")]) )# ':'' and 'end' do not count
get_symbols(ex::ExDot)  = Set{Symbol}([ex.args[1]])  # return variable, not fields
