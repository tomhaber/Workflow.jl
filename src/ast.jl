##########  Parameterized type to ease AST exploration  ############
struct ExH{H}
  head::Symbol
  args::Vector
end
toExH(s::Symbol) = s
toExH(ex::Expr) = ExH{ex.head}(ex.head, ex.args)
toExpr(ex::ExH) = Expr(ex.head, ex.args...)

ExEqual = ExH{:(=)}
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
getSymbols(ex::Any)    = Set{Symbol}()
getSymbols(ex::Symbol) = Set{Symbol}([ex])
getSymbols(ex::Array)  = mapreduce(getSymbols, union, ex)
getSymbols(ex::Expr)   = getSymbols(toExH(ex))
getSymbols(ex::ExH)    = mapreduce(getSymbols, union, ex.args)
getSymbols(ex::ExQuote)= Set{Symbol}()
getSymbols(ex::ExCall) = mapreduce(getSymbols, union, ex.args[2:end])  # skip function name
getSymbols(ex::ExMacro) = mapreduce(getSymbols, union, ex.args[2:end])  # skip macro name
getSymbols(ex::ExRef)  = setdiff(mapreduce(getSymbols, union, ex.args), Set([:(:), symbol("end")]) )# ':'' and 'end' do not count
getSymbols(ex::ExDot)  = Set{Symbol}([ex.args[1]])  # return variable, not fields
