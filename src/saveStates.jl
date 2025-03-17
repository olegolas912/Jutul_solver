using JLD2

function saveStates(path::AbstractString, allStatesStepSol::Dict{String,Any}, savedStepSolFields::Vector{String})
    # Поля, которые сохраняются по умолчанию:
    chosenFields = ["pressure", "s"]
    if !isempty(savedStepSolFields)
        chosenFields = savedStepSolFields
    end

    # Список всех полей, присутствующих в исходном решении
    stepSolFields = ["pressure", "flux", "s", "time", "wellSol", "sMax", "rs", "rv", "FlowProps", "PVTProps"]

    # Из списка удаляются те поля, которые присутствуют в chosenFields (без учета регистра)
    stepSolFields = [field for field in stepSolFields if !any(ch -> lowercase(ch) == lowercase(field), chosenFields)]
    
    # Формируем новый словарь, удаляя из allStatesStepSol ключи, указанные в stepSolFields
    statesStepSol = Dict{String,Any}()
    for (k, v) in allStatesStepSol
        if !(lowercase(k) in map(lowercase, stepSolFields))
            statesStepSol[k] = v
        end
    end

    @save path statesStepSol
    return true
end
