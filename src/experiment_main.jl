using Jutul, JutulDarcy, Dates, JLD2

# Пути и константы
dataset_path = joinpath("D:/GitHub/JutulDarcy.jl/egg", "results", "main")
const day = 86400.0  # 1 день в секундах

nStepsToSkip  = 5
nMaxDiffs     = 4
nRealizations = 100  # Будет выполнено 101 симуляция (от 0 до 100)

for iRealization in 0:nRealizations
    for jDiffs in 0:nMaxDiffs
        println("Реализация = $(iRealization), jDiffs = $(jDiffs)")
        
        # Загрузка модели из .DATA файла
        data_file = joinpath("D:/GitHub/JutulDarcy.jl/egg", "Egg_Model_ECL.DATA")
        case = setup_case_from_data_file(data_file)
        # Задаем дополнительное свойство rock.cr
        case.model.rock.cr = 1e-5
        model = case.model

        # В MRST schedule формируется через convertDeckScheduleToMRST,
        # а затем модифицируется (все control-шага задаются равными 30 дней).
        # В JutulDarcy явного schedule нет, поэтому задаём один временной шаг:
        timesteps = [30 * day]

        # Создаем нелинейный решатель NLSGuessApprox с заданными параметрами
        solver = NLSGuessApprox(nDiffs = jDiffs, nStepsToSkip = nStepsToSkip)
        # Задаем линейный солвер с опциями useCPR и tolerance
        solver.LinearSolver = select_linear_solver_ad(model; useCPR = true, tolerance = 1e-5)
        
        # Запускаем симуляцию; передаем case, timesteps и нелинейный решатель
        result = simulate_reservoir(case; timesteps = timesteps, nonlinearsolver = solver)
        
        # Выводим суммарное число итераций (из внутреннего рекордера)
        iter_sum = result.extra[:simulator].storage.recorder.recorder.iterations
        println("Суммарное число итераций = ", iter_sum)
        
        # Сохраняем отчёт и состояния с использованием JLD2
        report_path = joinpath(dataset_path, "report_$(iRealization)_$(jDiffs).jld2")
        states_path = joinpath(dataset_path, "states_$(iRealization)_$(jDiffs).jld2")
        @save report_path result.extra[:report]
        @save states_path result.states
    end
end
