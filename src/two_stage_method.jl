export TwoStageCost, two_stage_method, node_two_stage_function
using Flux
struct TwoStageCost{F,F2,D} <: Function
  cost_function::F
  cost_function2::F2
  estimated_solution::D
  estimated_derivative::D
end

(f::TwoStageCost)(p) = f.cost_function(p)
(f::TwoStageCost)(p, g) = f.cost_function2(p, g)

function decide_kernel(kernel)
    if kernel == :Epanechnikov
        return Epanechnikov_kernel
    elseif kernel == :Uniform
        return Uniform_kernel
    elseif kernel == :Triangular
        return Triangular_kernel
    elseif kernel == :Quartic
      return Quartic_Kernel
    elseif kernel == :Triweight
      return Triweight_Kernel
    elseif kernel == :Tricube
      return Tricube_Kernel
    elseif kernel == :Gaussian
      return Gaussian_Kernel
    elseif kernel == :Cosine
      return Cosine_Kernel
    elseif kernel == :Logistic
      return Logistic_Kernel
    elseif kernel == :Sigmoid
      return Sigmoid_Kernel
    else
      return Silverman_Kernel
    end
end


function construct_t1(t, tpoints)
    T1 = []
    for i in 1:length(tpoints)
        push!(T1,[1 tpoints[i]-t])
    end
    foldl(vcat,T1)
end
function construct_t2(t, tpoints)
    T2 = []
    for i in 1:length(tpoints)
        push!(T2,[1 tpoints[i]-t (tpoints[i]-t)^2])
    end
    foldl(vcat,T2)
end
function construct_w(t, tpoints, h, kernel_function)
    n = length(tpoints)
    W = zeros(n)
    for i in 1:n
        W[i] = kernel_function((tpoints[i]-t)/h)/h
    end
    Matrix(Diagonal(W))
end
function construct_estimated_solution_and_derivative!(estimated_solution, estimated_derivative, e1, e2, data, kernel_function, tpoints, h, n)
  for i in 1:n
      T1 = construct_t1(tpoints[i], tpoints)
      T2 = construct_t2(tpoints[i], tpoints)
      W = construct_w(tpoints[i], tpoints, h, kernel_function)
      estimated_solution[:,i] = e1'*inv(T1'*W*T1)*T1'*W*data'
      estimated_derivative[:,i] = e2'*inv(T2'*W*T2)T2'*W*data'
  end
end

function two_stage_method(prob::DiffEqBase.DEProblem, tpoints, data; kernel= :Epanechnikov,
                          loss_func = L2Loss, mpg_autodiff = false,
                          verbose = false, verbose_steps = 100,
                          autodiff_prototype = mpg_autodiff ? zeros(length(prob.p)) : nothing,
                          autodiff_chunk = mpg_autodiff ? ForwardDiff.Chunk(autodiff_prototype) : nothing)
    f = prob.f
    n = length(tpoints)
    h = (n^(-1/5))*(n^(-3/35))*((log(n))^(-1/16))
    estimated_solution = zeros(size(data)[1], n)
    estimated_derivative = zeros(size(data)[1], n)
    kernel_function = decide_kernel(kernel)
    e1 = [1;0]
    e2 = [0;1;0]
    construct_estimated_solution_and_derivative!(estimated_solution, estimated_derivative, e1, e2, data, kernel_function, tpoints, h, n)
    # Step - 2
    cost_function = function (p)
        println("\n")
        println("p is ", p)
        println("\n")
        du = similar(prob.u0, eltype(prob.u0))
        sol = Vector{typeof(du)}(undef,n)
        f = prob.f
        println("\n")
        println("f is ", prob.f)
        println("\n")

        for i in 1:n
          est_sol = @view estimated_solution[:,i]
          #print("fargs ", du, est_sol, p, tpoints[i])
          du = f(du, est_sol, p, i)
          sol[i] = copy(du)
        end
        #print("sum args", estimated_derivative, sol)
        sqrt(sum(abs2, vec(estimated_derivative)[i] - vec(VectorOfArray(sol))[i] for i in 1:length(vec(estimated_derivative))))
    end

    if mpg_autodiff
      gcfg = ForwardDiff.GradientConfig(cost_function, autodiff_prototype, autodiff_chunk)
      g! = (x, out) -> ForwardDiff.gradient!(out, cost_function, x, gcfg)
    else
      g! = (x, out) -> Calculus.finite_difference!(cost_function,x,out,:central)
    end
    if verbose
      count = 0 # keep track of # function evaluations
    end
    cost_function2 = function (p,grad)
      if length(grad)>0
        g!(p,grad)
      end
      loss_val = cost_function(p)
      if verbose
        count::Int += 1
        if mod(count,verbose_steps) == 0
          println("Iteration: $count")
          println("Current Cost: $loss_val")
          println("Parameters: $p")
        end
      end
      loss_val
    end

    return TwoStageCost(cost_function, cost_function2, estimated_solution, estimated_derivative)
end


function node_two_stage_function(model, x, tspan, saveat, ode_data,
                       args...; kwargs...)
    function dudt_(du,u0,p,t)
        #println("du: ",(du))
        #println("u: ",(u0))
        #println("type u: ",typeof(u0))
        #println("model u: ",model)
        #println("typeof model u: ",typeof(model))
        du=model[:,t]
        du
    end
    prob_fly = ODEProblem(dudt_,param(x),tspan)
    two_stage_method(prob_fly, saveat, ode_data)
end

#function destructure(m)
#  xs = []
#  mapleaves(m) do x
#    x isa TrackedArray && push!(xs, x)
#    return x
#  end
#  return vcat(vec.(xs)...)
#end
#function restructure(m, xs)
#  i = 0
#  mapleaves(m) do x
#    x isa TrackedArray || return x
#    x = reshape(xs[i.+(1:length(x))], size(x))
#    i += length(x)
#    return x
#  end
#end
