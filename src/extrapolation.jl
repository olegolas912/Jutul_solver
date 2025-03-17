using LinearAlgebra

"""
    extrapolation(train_dataset, nDiff, saveCoeffs)

Проводит экстраполяцию по истории состояний.
- train_dataset: массив структур с полями `pressure` и `s`
- nDiff: число дифференцирований
- saveCoeffs: логическое значение — сохранять ли коэффициенты регрессии

Возвращает кортеж:
(state_press, sO, sW, coeffs_pressure, coeffs_wat_sat)
"""
function extrapolation(train_dataset, nDiff::Int, saveCoeffs::Bool)
    # Собираем данные в матрицы (каждый столбец — значение из одного состояния)
    data_pressure = hcat(getfield.(train_dataset, :pressure)...)
    data_wat_sat  = hcat(getfield.(train_dataset, :s)...)
    
    coeffs_pressure = nothing
    coeffs_wat_sat  = nothing

    if nDiff == 0
        state_press = data_pressure
        sW = data_wat_sat
        sO = 1 .- sW
    elseif nDiff == 1
        # Берём второй столбец в качестве базового
        pressure0 = data_pressure[:, 2]
        sW0 = data_wat_sat[:, 2]
        state_press = pressure0 .+ forwardDifference(data_pressure)
        sW = sW0 .+ forwardDifference(data_wat_sat)
        sO = 1 .- sW
    elseif nDiff == 2
        pressure0 = data_pressure[:, 3]
        sW0 = data_wat_sat[:, 3]
        data_pressure = forwardDifference(data_pressure)
        data_wat_sat  = forwardDifference(data_wat_sat)
        coeff_press = simpleLinreg(data_pressure[:, 1], data_pressure[:, 2])
        coeff_wat_sat = simpleLinreg(data_wat_sat[:, 1], data_wat_sat[:, 2])
        if saveCoeffs
            coeffs_pressure = coeff_press
            coeffs_wat_sat  = coeff_wat_sat
        end
        state_press = pressure0 .+ coeff_press .* data_pressure[:, 2]
        sW = sW0 .+ coeff_wat_sat .* data_wat_sat[:, 2]
        sO = 1 .- sW
    else
        pressure0 = data_pressure[:, end]
        sW0 = data_wat_sat[:, end]
        data_pressure = forwardDifference(data_pressure)
        data_wat_sat  = forwardDifference(data_wat_sat)
        # Решаем без перехвата свободного члена
        coeffs_pressure = data_pressure[:, 1:end-1] \ data_pressure[:, end]
        coeffs_wat_sat  = data_wat_sat[:, 1:end-1] \ data_wat_sat[:, end]
        if !saveCoeffs
            coeffs_pressure = nothing
            coeffs_wat_sat  = nothing
        end
        # Для предсказания используем столбцы 2:end как регрессоры
        state_press = pressure0 .+ data_pressure[:, 2:end] * coeffs_pressure
        sW = sW0 .+ data_wat_sat[:, 2:end] * coeffs_wat_sat
        sO = 1 .- sW
    end

    return state_press, sO, sW, coeffs_pressure, coeffs_wat_sat
end

"""
    forwardDifference(states)

Возвращает матрицу разностей вдоль столбцов: states[:,2:end] - states[:,1:end-1]
"""
function forwardDifference(states)
    return states[:, 2:end] .- states[:, 1:end-1]
end

"""
    simpleLinreg(X, Y)

Вычисляет коэффициент линейной регрессии (без перехвата) по формулам:
    coeff = sum(X .* Y) / sum(X .^ 2)
"""
function simpleLinreg(X, Y)
    return sum(X .* Y) / sum(X .^ 2)
end
