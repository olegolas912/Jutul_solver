abstract type NonLinearSolver end

# Тип селектора временных шагов (пример; должен быть определён в вашем коде)
struct SimpleTimeStepSelector
    firstRampupStepRelative::Real
    firstRampupStep::Real
    maxRelativeAdjustment::Real
    minRelativeAdjustment::Real
    maxTimestep::Real
    minTimestep::Real
end

# Функция создания "жёсткого" селектора временных шагов
function getRigidStepSelector()
    return SimpleTimeStepSelector(1, Inf, Inf, 1, Inf, 0)
end

# Наш расширенный нелинейный решатель с ML-аппроксимацией начального приближения
mutable struct NLSGuessApprox <: NonLinearSolver
    # Основные параметры
    statesCount::Int
    nStepsToSkip::Int
    nDiffs::Int
    iterationsCount::Int
    rigidTimeStepSelector::Bool
    stateCollection::Vector{Any}         # История состояний (каждый элемент – Dict с ключами :pressure и :s)
    saveRegrCoeffs::Bool
    regrCoeffs::Vector{Any}              # Массив словарей, например, Dict(:coeffs_pressure => ..., :coeffs_wat_sat => ...)
    timeStepSelector                     # Например, SimpleTimeStepSelector
    # Дополнительные поля, используемые в solveTimestep:
    verbose::Int
    continueOnFailure::Bool
    maxTimestepCuts::Int
    # Для идентификации (например, метод getId)
    id::String
end

# Конструктор с дефолтными значениями
function NLSGuessApprox(; kwargs...)
    # Значения по умолчанию
    solver = NLSGuessApprox(1, 0, 4, 0, true, Any[], false, Any[], nothing, 1, true, 10, "NLSGuessApprox")
    # Можно переопределить поля через kwargs, если нужно (например, через Base.merge!)
    if solver.rigidTimeStepSelector
        solver.timeStepSelector = getRigidStepSelector()
    end
    return solver
end

# Метод для получения идентификатора (аналог solver.getId() в MATLAB)
function getId(solver::NLSGuessApprox)
    return solver.id
end

# Обновление истории состояний
function update_state_collection!(solver::NLSGuessApprox, state, converged::Bool)
    if !converged
        return
    end
    # Предполагаем, что state.pressure – вектор, state.s – матрица, берем первую колонку
    new_state = Dict(:pressure => state.pressure, :s => state.s[:, 1])
    if length(solver.stateCollection) < solver.nDiffs + 1
        push!(solver.stateCollection, new_state)
    else
        # Сдвигаем историю: удаляем первый элемент и добавляем новый
        solver.stateCollection = vcat(solver.stateCollection[2:end], [new_state])
    end
    solver.statesCount += 1
end

# Начальное приближение на основе истории состояний
function initial_guess_approx(solver::NLSGuessApprox, state0)
    if solver.statesCount == 1
        solver.stateCollection = [Dict(:pressure => state0.pressure, :s => state0.s[:, 1])]
    end
    if solver.statesCount < solver.nStepsToSkip
        return state0
    end
    train_dataset = solver.stateCollection
    # Функция extrapolation должна быть определена (см. предыдущий ответ)
    state_press, sO, sW, coeffs_pressure, coeffs_wat_sat = extrapolation(train_dataset, solver.nDiffs, solver.saveRegrCoeffs)
    guess = deepcopy(state0)
    guess.pressure = state_press
    # Объединяем sW и sO по горизонтали, получая матрицу из двух колонок
    guess.s = hcat(sW, sO)
    push!(solver.regrCoeffs, Dict(:coeffs_pressure => coeffs_pressure, :coeffs_wat_sat => coeffs_wat_sat))
    return guess
end

# Метод решения одного временного шага с субшагами
function solve_timestep(solver::NLSGuessApprox, state0, dT, model; kwargs...)
    # Запуск таймера
    t_start_time = time()
    # Начальное приближение
    opt = Dict(:initialGuess => initial_guess_approx(solver, state0))
    
    # Получаем стандартные drivingForces из модели
    drivingForces = model.getValidDrivingForces()
    drivingForces[:controlId] = NaN

    # Объединяем опции; здесь merge_options – предполагаемая функция
    forcesArg = Dict()  # для простоты
    for (k,v) in forcesArg
        drivingForces[k] = v
    end

    # Подготовка report-step (метод модели)
    model, state = model.prepareReportstep(opt[:initialGuess], state0, dT, drivingForces)
    opt[:initialGuess] = state
    @assert dT >= 0 "Negative timestep detected."

    # Инициализация переменных цикла
    converged = false
    done = false
    early_done = false
    itCount = 0          # общее число итераций
    cuttingCount = 0     # число субшагов из-за уменьшения шага
    stepCount = 0
    acceptCount = 0
    t_local = 0.0
    if !haskey(state0, :time)
        state0[:time] = 0.0
    end
    t_start = state0[:time]
    isFinalMinistep = false
    state0_inner = state0
    state_prev = nothing
    dt_prev = NaN

    wantMinistates = true
    reports = Any[]
    ministates = Any[]

    # Информируем селектор временных шагов о начале контрольного шага
    stepsel = solver.timeStepSelector
    stepsel.newControlStep(drivingForces)

    dtMin = dT / (2^solver.maxTimestepCuts)
    timestepFailure = false
    dt = dT

    while !done
        if timestepFailure
            dt_selector = stepsel.cutTimestep(dt_prev, dt, model, solver, state_prev, state0_inner, drivingForces)
        else
            dt_selector = stepsel.pickTimestep(dt_prev, dt, model, solver, state_prev, state0_inner, drivingForces)
        end
        dt_model = model.getMaximumTimestep(state, state0_inner, dT - t_local, drivingForces)
        dt_choice = min(dt_selector, dt_model)
        if t_local + dt_choice >= dT
            isFinalMinistep = true
            dt = dT - t_local
        else
            dt = dt_choice
        end
        if solver.verbose > 0 && dt < dT
            println("$(getId(solver)) Solving ministep: $(dt) sec ($(dt/dT*100)% of control step, $(t_local/dT*100)% complete)")
        end
        # Обновляем время
        state[:time] = t_start + t_local + dt
        # Решаем минишаг; функция solve_ministep должна возвращать (state, failure, tmp)
        state, failure, tmp = solve_ministep(solver, model, state, state0_inner, dt, drivingForces)
        # Сохраняем отчет по шагу
        tmp["LocalTime"] = state[:time]
        push!(reports, tmp)
        if !isFinalMinistep || (dt/dt_choice > 0.9)
            stepsel.storeTimestep(tmp)
        end
        itCount += tmp["Iterations"]
        stepCount += 1
        if converged = tmp["Converged"]
            t_local += dt
            dt_prev = dt
            state_prev = state0_inner
            state0_inner = state
            acceptCount += 1
            push!(ministates, state)
            timestepFailure = false
        else
            stopNow = (dt <= dtMin) || (failure && solver.continueOnFailure)
            if !(stopNow && solver.continueOnFailure)
                if acceptCount == 0
                    state = opt[:initialGuess]
                else
                    state = state0_inner
                end
            end
            msg = string(getId(solver), " Did not find a solution: ")
            msg_fail = ""
            if failure
                msg_fail = tmp["NonlinearReport"][end]["FailureMsg"]
                msg *= "Model step resulted in failure state. Reason: " * msg_fail
            else
                msg *= "Maximum number of substeps stopped timestep reduction"
            end
            if stopNow
                if solver.errorOnFailure
                    error(msg)
                else
                    if solver.verbose >= 0
                        @warn msg
                    end
                    converged = false
                    if !(solver.continueOnFailure && failure)
                        break
                    else
                        timestepFailure = true
                    end
                end
            else
                if solver.verbose >= 0
                    if failure
                        println("$(getId(solver)) Solver failure after $(tmp["Iterations"] - 1) iterations for timestep $(dt). Failure reason: $(msg_fail). Cutting timestep.")
                    else
                        println("$(getId(solver)) Solver did not converge in $(tmp["Iterations"] - 1) iterations for timestep $(dt). Cutting timestep.")
                    end
         
