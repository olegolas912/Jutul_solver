using Jutul, JutulDarcy, Dates, JLD2

# Константы и пути
const day = 86400.0           # 1 день в секундах
dataset_path = joinpath("D:/GitHub/JutulDarcy.jl/egg/", "results", "abrupt")

nStepsToSkip = 5
nMaxDiffs    = 3
nRealizations = 0            # В JutulDarcy нет параметра realization – используется базовый случай

for iRealization in 0:nRealizations
    for jDiffs in 0:nMaxDiffs
        # --- Загрузка модели из .DATA файла ---
        # В MRST используют функцию setupEGG('realization', iRealization)
        # В JutulDarcy параметр realization отсутствует, поэтому просто загружаем базовый case
        data_file = joinpath("D:/GitHub/JutulDarcy.jl/egg/", "Egg_Model_ECL.DATA")
        case = setup_case_from_data_file(data_file)
        # При необходимости можно изменить дополнительные параметры (например, rock.cr)
        case.model.rock.cr = 1e-5

        # В MRST создаётся модель через selectModelFromDeck, а schedule через convertDeckScheduleToMRST.
        # В JutulDarcy вся информация уже содержится в case, а управление временными шагами задаётся через вектор timesteps.
        # Здесь мы задаём один контрольный шаг равный 30 дней:
        timesteps = [30 * day]

        # Если требуется модифицировать расписание (аналог makeScheduleInconsistent),
        # можно определить функцию make_schedule_inconsistent(schedule, 15, 2, 1)
        # и применить её к структуре schedule, если такая существует.
        # В данном примере schedule не хранится в case, поэтому эту часть опускаем.

        # --- Симуляция ---
        # Создаем нелинейный решатель, аналог NLSGuessApprox, передавая nDiffs и nStepsToSkip.
        solver = NLSGuessApprox(nDiffs = jDiffs, nStepsToSkip = nStepsToSkip)
        # Задаем линейный солвер – функция select_linear_solver_ad должна быть реализована в вашей библиотеке.
        solver.LinearSolver = select_linear_solver_ad(case.model; useCPR = true, tolerance = 1e-5)
        
        # Запускаем симуляцию.
        # В JutulDarcy симуляция выполняется функцией simulate_reservoir, куда передаются case,
        # вектор временных шагов и опционально nonlinear solver через именованный аргумент nonlinearsolver.
        result = simulate_reservoir(case; timesteps = timesteps, nonlinearsolver = solver)
        
        # --- Отчет ---
        # В MATLAB суммируют report.Iterations; в JutulDarcy общее число итераций можно получить из:
        iter_sum = result.extra[:simulator].storage.recorder.recorder.iterations
        println("Реализация = $(iRealization), jDiffs = $(jDiffs), суммарное число итераций = ", iter_sum)
        
        # Сохранение отчета и состояний в файлы (с использованием JLD2)
        report_path = joinpath(dataset_path, "abrupt_report_$(iRealization)_$(jDiffs).jld2")
        states_path = joinpath(dataset_path, "abrupt_states_$(iRealization)_$(jDiffs).jld2")
        @save report_path result.extra[:report]
        @save states_path result.states
    end
end
