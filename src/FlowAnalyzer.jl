import Core:
    CodeInfo,
    CodeInstance,
    MethodInstance,
    Const,
    Argument,
    SSAValue,
    PiNode,
    PhiNode,
    UpsilonNode,
    PhiCNode,
    ReturnNode,
    GotoNode,
    GotoIfNot,
    SimpleVector

const CC = Core.Compiler

import .CC:
    CFG,
    BasicBlock,
    compute_basic_blocks

# import .CC:
#     AbstractInterpreter,
#     NativeInterpreter,
#     IRCode,
#     OptimizationParams,
#     OptimizationState,
#     get_world_counter,
#     convert_to_ircode,
#     run_passes

# struct FlowState
# end

# mutable struct FlowAnalyzer{State} <: AbstractInterpreter
#     native::NativeInterpreter
#     ir::IRCode
#     state::State
#     linfo::MethodInstance
#     FlowAnalyzer(native::NativeInterpreter) = new{FlowState}(native)
# end

# CC.InferenceParams(interp::FlowAnalyzer)    = CC.InferenceParams(interp.native)
# CC.OptimizationParams(interp::FlowAnalyzer) = CC.OptimizationParams(interp.native)
# CC.get_world_counter(interp::FlowAnalyzer)  = get_world_counter(interp.native)

# CC.lock_mi_inference(::FlowAnalyzer,   ::MethodInstance) = nothing
# CC.unlock_mi_inference(::FlowAnalyzer, ::MethodInstance) = nothing

# CC.add_remark!(interp::FlowAnalyzer, sv, s) = CC.add_remark!(interp.native, sv, s)

# CC.may_optimize(interp::FlowAnalyzer)      = CC.may_optimize(interp.native)
# CC.may_compress(interp::FlowAnalyzer)      = CC.may_compress(interp.native)
# CC.may_discard_trees(interp::FlowAnalyzer) = CC.may_discard_trees(interp.native)
# CC.verbose_stmt_info(interp::FlowAnalyzer) = CC.verbose_stmt_info(interp.native)

# CC.get_inference_cache(interp::FlowAnalyzer) = CC.get_inference_cache(interp.native)

# CC.code_cache(interp::FlowAnalyzer) = CC.code_cache(interp.native)

# function CC.optimize(interp::FlowAnalyzer, opt::OptimizationState, params::OptimizationParams, @nospecialize(result))
#     nargs = Int(opt.nargs) - 1
#     ir = run_passes(opt.src, nargs, opt)
#     return CC.finish(interp, opt, params, ir, result)
# end

# function CC.finish(interp::FlowAnalyzer, opt::OptimizationState, params::OptimizationParams, ir::IRCode, @nospecialize(result))
#     println("finis")
#     interp.ir = ir
#     #interp.state = state
#     interp.linfo = opt.linfo
#     return CC.finish(interp.native, opt, params, ir, result)
# end

# function analyze_flow(@nospecialize(f), @nospecialize(types=Tuple{}); world = get_world_counter(), interp = NativeInterpreter(world))
#     interp = FlowAnalyzer(interp)
#     results = code_typed(f, types; optimize=true, world, interp)
#     #isone(length(results)) || throw(ArgumentError("`analyze_flows` only supports single analysis result"))
#     #return FlowResult(interp.ir, interp.state, interp.linfo)
#     interp, results
# end

macro analyze_flow(ex0...)
    return InteractiveUtils.gen_call_with_extracted_types_and_kwargs(__module__, :analyze_flow, ex0)
end

function analyze_flow(@nospecialize(f), @nospecialize(types=Tuple{}))
    results = code_typed(f, types; optimize=true)
    !isempty(results) || throw(ArgumentError("`analyze_flow` failed to analyze function"))
    isone(length(results)) || throw(ArgumentError("`analyze_flow` only supports single analysis result"))
    first(results)
end

function instance_to_function(mi::MethodInstance)
    sig = Base.unwrap_unionall(mi.specTypes).types
    if sig[1] <: Function # typeof(func)
        sig[1].instance
    else                        # constructor
        getfield(
            parentmodule(sig[1].parameters[1]),
            mi.def.name)
    end
end

function function_to_graph(@nospecialize(f), @nospecialize(types=Tuple{}))
    name = nameof(f)
    ci, rettype = analyze_flow(f, types)

    graph = FlowGraph(name, f, types, rettype)
    convert_to_graph!(graph, ci, types)
end

function _type(code::CodeInfo, idx::Int)
    types = code.ssavaluetypes
    types isa Vector{Any} || return nothing
    return isassigned(types, idx) ? types[idx] : nothing
end

function invoke_to_call(ex::Expr)
    Expr(:call, ex.args[2:end]...)
end

function construct_inputs!(graph::FlowGraph, ci::CodeInfo, types::Tuple)
    input_types = Tuple{Tuple{typeof(graph.self), types...}}

    getindex = GlobalRef(Base, :getindex)
    function construct_arg(i::Int)
        T = ci.slottypes[i]
        name = ci.slotnames[i]

        ex = Expr(:call, getindex, :X, i)
        n = push_node!(graph;
                    name=:getindex,
                    expr=ex,
                    args=[:X],
                    input_types=input_types,
                    type=T)
        connect_to_input!(graph, n, i, name=name, idx=1)
        n
    end

    map(construct_arg, 1:length(types)+1) # include self
end

function convert_to_graph!(graph::FlowGraph, ci::CodeInfo, types::Tuple)
    stmts = ci.code
    argnodes = construct_inputs!(graph, ci, types)
    ssanodes = Vector{Node}(undef, length(stmts))

    for idx in 1:length(stmts)
        T = _type(ci, idx)
        stmt = stmts[idx]

        if stmt isa Expr
            ex = stmt::Expr

            args = Symbol[]
            edges = Node[]
            input_types = Any[]
            for (i, arg) in enumerate(ex.args)
                if arg isa SSAValue
                    x = gensym("x");
                    push!(args, x)
                    push!(edges, ssanodes[arg.id])
                    @info "ssa $(arg.id) stmt $idx: $stmt"
                    push!(input_types, node_meta(graph, ssanodes[arg.id], :type))
                    ex.args[i] = x
                elseif arg isa Argument
                    x = gensym("X");
                    push!(args, x)
                    push!(edges, argnodes[arg.n])
                    push!(input_types, node_meta(graph, argnodes[arg.n], :type))
                    ex.args[i] = x
                end
            end

            if ex.head == :invoke
                ex = invoke_to_call(ex)
            end

            name = Symbol(ex.args[1])
            n = push_node!(graph;
                            name=name,
                            expr=ex,
                            args=args,
                            input_types=Tuple{input_types...},
                            type=T)
            ssanodes[idx] = n

            for (i, src, name) in zip(Iterators.countfrom(), edges, args)
                connect!(graph, src, n; name=name, idx=i)
            end
        elseif stmt isa ReturnNode
            if isdefined(stmt, :val)
                val = stmt.val
                val isa SSAValue || error("unknown return statement: $stmt")
                connect_to_output!(graph, ssanodes[val.id]; type = T, idx=1)
            end
        elseif stmt isa GlobalRef
            x = getfield(stmt.mod, stmt.name)
            n = push_node!(graph;
                name=stmt.name,
                expr=Expr(:call, :getfield, stmt.mod, QuoteNode(stmt.name)),
                args=Symbol[],
                input_types=Tuple{},
                type=typeof(x))
            ssanodes[idx] = n
        elseif stmt isa GotoIfNot || stmt isa GotoNode
        elseif stmt isa PiNode
            val = stmt.val
            val isa SSAValue || error("unknown return statement: $stmt")
            ssanodes[idx] = ssanodes[val.id]
        elseif stmt isa PhiNode
        else
            @warn ("Unknown statement type: $stmt")
        end
    end

    graph
end
