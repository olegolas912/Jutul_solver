using Jutul, JutulDarcy, Dates, JLD2

# Путь для сохранения результатов
dataset_path = joinpath("D:/GitHub/JutulDarcy.jl/egg", "results", "coeffs")

nStepsToSkip  = 5
nMaxDiffs     = 4
nRealizations = 0   # В JutulDarcy отсутствует параметр realization, поэтому используется базовый случай

const day = 86400.0  # 1 день в секундах

for iRealization in 0:nRealizations
    for jDiffs in 4:nMaxDiffs
        println("iRealization = ", iRealization, ", jDiffs = ", jDiffs)
        
        # --- Загрузка модели из .DATA файла ---
        data_file = joinpath("D:/GitHub/JutulDarcy.jl/egg", "Egg_Model_ECL.DATA")
        case = setup_case_from_data_file(data_file)
        # Устанавливаем дополнительное свойство rock.cr
        case.model.rock.cr = 1e-5
        
        # Модель уже содержится в case.model
        model = case.model
        
        # В MRST schedule формируется через convertDeckScheduleToMRST,
        # а затем модифицируется – в JutulDarcy явного schedule нет.
        # Для симуляции задаём один временной шаг равный 30 дней:
        timesteps = [30 * day]
        
        # --- Симуляция ---
        # Создаем решатель, передавая nDiffs, nStepsToSkip и включив опцию сохранения коэффициентов.
        solver = NLSGuessApprox(nDiffs = jDiffs, nStepsToSkip = nStepsToSkip, saveRegrCoeffs = true)
        # Задаем линейный солвер с использованием CPR и заданной точностью
        solver.LinearSolver = select_linear_solver_ad(model; useCPR = true, tolerance = 1e-5)
        
        # Запускаем симуляцию – функция simulate_reservoir принимает case, временные шаги,
        # и именованный аргумент nonlinearsolver
        result = simulate_reservoir(case; timesteps = timesteps, nonlinearsolver = solver)
        
        # --- Отчет ---
        # Извлекаем регрессионные коэффициенты из решателя
        coeffs = solver.regrCoeffs
        report_path = joinpath(dataset_path, "coeffs_$(iRealization)_$(jDiffs).jld2")
        @save report_path coeffs
    end
end
