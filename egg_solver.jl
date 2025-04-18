using Jutul, JutulDarcy, GLMakie


include("D:/GitHub/Jutul_solver/simulator_1.jl")


basedir = "D:/GitHub/JutulDarcy.jl/egg/"
data_file_path = "Egg_Model_ECL.DATA"
case = setup_case_from_data_file(joinpath(basedir, data_file_path))

result = simulate_reservoir(case, timesteps = :none, output_substates = true, cutting_criterion = nothing)
