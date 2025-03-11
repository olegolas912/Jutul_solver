using Jutul, JutulDarcy, GLMakie
# include("C:/Users/Oleg/.julia/packages/Jutul/4EUEx/src/simulator/simulator1.jl")
# using Jutul.Simulator1

# include("Simulator2.jl")
# using .Simulator2

basedir = "D:/GitHub/JutulDarcy.jl/egg/"
data_file_path = "Egg_Model_ECL.DATA"
case = setup_case_from_data_file(joinpath(basedir, data_file_path))

result = simulate_reservoir(case, timesteps = :none, output_substates = true, cutting_criterion = nothing)

# result_wth_substates = simulate_reservoir(case, output_substates = true)

# Extract the simulator from the simulation result
sim = result.extra[:simulator]
fieldnames(typeof(result.extra))

# Extract the ProgressRecorder from storage
pr = sim.storage.recorder  # This is a ProgressRecorder object

# Extract the main SolveRecorder (for main steps)
main_rec = pr.recorder
fieldnames(typeof(main_rec))

main_rec.iteration

# If substep data is needed, use the subrecorder:
sub_rec = pr.subrecorder
fieldnames(typeof(sub_rec))

# Print values from the main SolveRecorder
println("Number of steps: ", main_rec.step)
println("Number of iterations: ", main_rec.iterations)
println("Failed iterations: ", main_rec.failed)
println("Current dt value: ", main_rec.dt)

extra = result.extra

result

fieldnames(typeof(result))
fieldnames(typeof(result.result))

well_names = result.wells

lrat_all_wells = Dict{Symbol, Vector{Float64}}()

for well in well_names
    lrat_all_wells[well] = reservoir_sim_result.wells[well][:lrat]
end



substates = result.get_substates()

result

@show keys(result.wells.wells)  # 
@show (result.wells.wells[:PROD4][:lrat])  # 



#--------------------------------------------------------------------------------------------------------------------------------------

using Jutul, JutulDarcy, JLD2

# ============================
# State approximation functions
# ============================

function forwardDifference(states::AbstractMatrix)
    # Computes the forward difference approximation along columns
    return states[:, 2:end] .- states[:, 1:end-1]
end

function simpleLinreg(X, Y)
    # Linear regression coefficient using least squares
    return sum(X .* Y) / sum(X .^ 2)
end

"""
    extrapolation(train_dataset, nDiff; saveCoeffs=false)

Takes an array of states (each state is a dictionary with fields :pressure and :s)
and computes the predicted state. Returns a tuple with:
  • state_press – predicted pressure,
  • sO – predicted oil saturation,
  • sW – predicted water saturation,
  • coeffs_pressure and coeffs_wat_sat (if saveCoeffs=true).
"""
function extrapolation(train_dataset, nDiff::Int; saveCoeffs=false)
    pressures = hcat([state[:pressure] for state in train_dataset]...)
    s_wats   = hcat([state[:s] for state in train_dataset]...)
    coeffs_pressure = nothing
    coeffs_wat_sat  = nothing

    if nDiff == 0
        state_press = pressures
        sW = s_wats
        sO = 1 .- sW
    elseif nDiff == 1
        pressure0 = pressures[:, 2]
        sW0       = s_wats[:, 2]
        state_press = pressure0 .+ forwardDifference(pressures)[:, 1]
        sW = sW0 .+ forwardDifference(s_wats)[:, 1]
        sO = 1 .- sW
    elseif nDiff == 2
        pressure0 = pressures[:, 3]
        sW0       = s_wats[:, 3]
        P_diff = forwardDifference(pressures)
        S_diff = forwardDifference(s_wats)
        coeff_press = simpleLinreg(P_diff[:, 1], P_diff[:, 2])
        coeff_wat_sat = simpleLinreg(S_diff[:, 1], S_diff[:, 2])
        if saveCoeffs
            coeffs_pressure = coeff_press
            coeffs_wat_sat  = coeff_wat_sat
        end
        state_press = pressure0 .+ coeff_press .* P_diff[:, 2]
        sW = sW0 .+ coeff_wat_sat .* S_diff[:, 2]
        sO = 1 .- sW
    else
        pressure0 = pressures[:, end]
        sW0       = s_wats[:, end]
        P_diff = forwardDifference(pressures)
        S_diff = forwardDifference(s_wats)
        coeff_press = simpleLinreg(P_diff[:, end-1], P_diff[:, end])
        coeff_wat_sat = simpleLinreg(S_diff[:, end-1], S_diff[:, end])
        if saveCoeffs
            coeffs_pressure = coeff_press
            coeffs_wat_sat  = coeff_wat_sat
        end
        state_press = pressure0 .+ coeff_press .* P_diff[:, end]
        sW = sW0 .+ coeff_wat_sat .* S_diff[:, end]
        sO = 1 .- sW
    end
    return (state_press=state_press, sO=sO, sW=sW,
            coeffs_pressure=coeffs_pressure, coeffs_wat_sat=coeffs_wat_sat)
end

# ============================
# Experimental procedures
# ============================

"""
    run_experiment_abrupt(basedir, dataset_path)

Loads a case from a DATA file using setup_case_from_data_file,
creates a simulator with automatic time step selection,
gets the configuration via simulator_config, and runs the simulation
with the parameter timesteps = :none. Results are saved using JLD2.
"""
function run_experiment_abrupt(basedir::String, dataset_path::String)
    println("Running abrupt experiment...")
    data_file = joinpath(basedir, "Egg_Model_ECL.DATA")
    case = setup_case_from_data_file(data_file)
    # Create a simulator based on the case; timesteps=:none means automatic step selection
    result = simulate_reservoir(case, timesteps = :none, output_substates = true, cutting_criterion = nothing)
    println("Total iterations: ", sum(result.report.iterations))
    @save joinpath(dataset_path, "abrupt_report.jld2") result.report
    @save joinpath(dataset_path, "abrupt_states.jld2") result.states
end

"""
    run_experiment_coeffs(basedir, dataset_path)

Runs a simulation to calculate regression coefficients.
A simulator is created, the configuration is obtained via simulator_config,
and then the coefficients are extracted from result.extra (if they are saved).
"""
function run_experiment_coeffs(basedir::String, dataset_path::String)
    println("Running coefficients experiment...")
    data_file = joinpath(basedir, "Egg_Model_ECL.DATA")
    case = setup_case_from_data_file(data_file)
    result = simulate_reservoir(case, timesteps = :none, output_substates = true, cutting_criterion = nothing)
    coeffs = result.extra[:regrCoeffs]  # If the simulator saves coefficients
    @save joinpath(dataset_path, "coeffs.jld2") coeffs
end

"""
    run_experiment_main(basedir, dataset_path)

Main experiment. A case is loaded from a DATA file, a simulator is created,
the configuration is obtained via simulator_config, and the simulation is run with timesteps = :none.
The simulation results are saved using JLD2.
"""
function run_experiment_main(basedir::String, dataset_path::String)
    println("Running main experiment...")
    data_file = joinpath(basedir, "Egg_Model_ECL.DATA")
    case = setup_case_from_data_file(data_file)
    result = simulate_reservoir(case, timesteps = :none, output_substates = true, cutting_criterion = nothing)
    println("Total iterations: ", sum(result.report.iterations))
    @save joinpath(dataset_path, "main_report.jld2") result.report
    @save joinpath(dataset_path, "main_states.jld2") result.states
end

# ============================
# Main experiment execution
# ============================

basedir = "D:/GitHub/JutulDarcy.jl/egg/"
run_experiment_abrupt(basedir, "./results/abrupt/")
run_experiment_coeffs(basedir, "./results/coeffs/")
run_experiment_main(basedir, "./results/main/")

fieldnames(typeof(result))
fieldnames(typeof(result.result))


#--------------------------------------------------------------------------------------------------------------------------------------
