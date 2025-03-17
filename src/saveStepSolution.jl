using JLD2

function saveStepSolution(path::AbstractString, allStatesStepSol::Dict{String,Any}, savedStepSolFields::Vector{String})
    # По умолчанию сохраняются поля "pressure" и "s"
    chosenFields = ["pressure", "s"]
    if !isempty(savedStepSolFields)
        chosenFields = savedStepSolFields
    end

    # Полный список полей, присутствующих в step solution
    stepSolFields = ["pressure", "flux", "s", "time", "wellSol", "sMax", "rs", "rv", "FlowProps", "PVTProps"]

    # Удаляем из stepSolFields те поля, которые присутствуют в chosenFields (без учёта регистра)
    stepSolFields = [field for field in stepSolFields if !any(ch -> lowercase(ch) == lowercase(field), chosenFields)]
    
    # Формируем новый словарь, исключая ключи, указанные в stepSolFields
    statesStepSol = Dict{String,Any}()
    for (k, v) in allStatesStepSol
        if !(lowercase(k) in map(lowercase, stepSolFields))
            statesStepSol[k] = v
        end
    end

    @save path statesStepSol
    return true
end
