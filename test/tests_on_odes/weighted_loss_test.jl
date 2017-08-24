using Distributions, RecursiveArrayTools, NLopt
srand(123)

original_solution = [(sol(t[i])) for i in 1:length(t)]
original_solution_matrix_form = vecvec_to_mat(original_solution)
weight = zeros(size(original_solution_matrix_form)[1],size(original_solution_matrix_form)[2])
error = zeros(size(original_solution_matrix_form)[1],size(original_solution_matrix_form)[2])

for i in 1:size(original_solution_matrix_form)[1]
 for j in 1:size(original_solution_matrix_form)[2]
  tmp = rand()
  weight[i,j] = tmp*tmp
  d = Normal(0,tmp)
  error[i,j] = rand(d)
 end
end

weighted_data = original_solution_matrix_form + error

weighted_cost_function = build_loss_objective(prob1,Tsit5(),CostVData(t,maximum_likelihood_data',weight=weight'),maxiters=10000)
opt = Opt(:LN_COBYLA, 1)
min_objective!(opt, weighted_cost_function)
(minf,minx,ret) = NLopt.optimize(opt,[1.3])
@test minx[1] ≈ 1.5 atol=1e-2
