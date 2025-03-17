using JLD2

"""
    save_report(path, allReport, savedReportFields)

Сохраняет отчёт, оставляя только те поля, которые перечислены в `savedReportFields`.
Если `savedReportFields` пуст, берутся поля по умолчанию.
Возвращает true после успешного сохранения.
"""
function save_report(path::String, allReport::Dict{Symbol,Any}; savedReportFields::Vector{Symbol} = Symbol[])
    # Поля по умолчанию
    defaultFields = [:Iterations, :ControlstepReports, :SimulationTime,
                     :PressureInf, :SaturationWatInf, :SaturationOilInf]
    chosenFields = isempty(savedReportFields) ? defaultFields : savedReportFields

    # Все потенциальные поля, которые могут присутствовать в отчёте
    reportFields = [
        :ControlstepReports, :ReservoirTime, :Converged, :Iterations,
        :SimulationTime, :Failure, :PressureInf, :SaturationWatInf, :SaturationOilInf
    ]

    # Удаляем из reportFields всё, что нужно сохранить
    for field in chosenFields
        filter!(x -> x != field, reportFields)
    end

    # Теперь из allReport удалим поля, которые остались в reportFields,
    # оставив только нужные поля
    reportData = Dict{Symbol,Any}()  # итоговый словарь
    for (k, v) in allReport
        if !(k in reportFields)
            reportData[k] = v
        end
    end

    # Сохраняем reportData в файл (здесь используется JLD2)
    @save path reportData

    return true
end
