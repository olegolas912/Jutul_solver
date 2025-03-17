using Jutul, JutulDarcy, GLMakie, Dates

# -----------------------------------------------------------------------------
# 1. Инициализация модели Egg (двухфазная система нефть–вода)
# -----------------------------------------------------------------------------
basedir = "D:/GitHub/JutulDarcy.jl/egg/"
data_file_path = joinpath(basedir, "Egg_Model_ECL.DATA")
# В JutulDarcy реализация "realization" может задаваться опциями или оставляться по умолчанию
case = setup_case_from_data_file(data_file_path)  # базовый случай (realization = 0)

# Задаем опции симуляции: в MATLAB использовалась стратегия "none" и включался CPR
sim_options = Dict("TimestepStrategy" => "none", "useCPR" => true)

# Инициализируем задачу (аналог initEclipseProblemAD)
# В JutulDarcy симуляция запускается через simulate_reservoir.
# Здесь предполагается, что все необходимые параметры берутся из case.
# -----------------------------------------------------------------------------
# 2. Запуск симуляции
# -----------------------------------------------------------------------------
result = simulate_reservoir(case; sim_options..., output_substates = true)

# Предполагается, что result содержит:
# • result.states — массив состояний (каждое состояние представлено, например, как словарь)
# • result.extra — словарь с дополнительной информацией, например, schedule и wellSols.
wellSols = result.extra[:wellSols]  # (если реализовано)
states   = result.states
report   = result.extra[:report]    # общий отчет симуляции

# Для последующих построений извлекаем графическую информацию из case.model.
# Например, сетка и геологические свойства.
G    = case.model.grid        # структура сетки
rock = case.model.rock        # структура породы (например, поле perm)
# Для конвертации единиц примем, что 1 darcy = 9.869233e-13 m²
const darcy = 9.869233e-13
perm_mDarcy = rock.perm[:,1] ./ darcy ./ 1e3  # mDarcy

# -----------------------------------------------------------------------------
# 3. Построение геологии
# -----------------------------------------------------------------------------
fig1 = Figure(resolution = (800,600))
ax1 = Axis(fig1[1,1], title = "Geology: Permeability", xticks = nothing, yticks = nothing)
# Предположим, что у сетки G есть координаты центров ячеек (G.cell_centers — Nx2 матрица)
scatter!(ax1, G.cell_centers[:,1], G.cell_centers[:,2], markersize=8,
         color = perm_mDarcy, colormap = :jet)
Colorbar(fig1[1,2], ax1; label = "mDarcy", labelsize = 12)
display(fig1)

# -----------------------------------------------------------------------------
# 4. Построение графиков по результатам симуляции
# -----------------------------------------------------------------------------
# Для построения графиков времени берем расписание из result.extra (если оно сохранено)
schedule = result.extra[:schedule]  # предполагается, что schedule.step.val существует
# Формируем вектор времени (накопительное суммирование по шагам) и переводим в годы.
T_sec = cumsum(schedule.step.val)
const year_sec = 31536000.0
T_years = T_sec ./ year_sec

# Предположим, что сведения по скважинам хранятся в case.model.wells
W = case.model.wells
# Определяем индексы инжекторов (w.sign > 0) и производителей (w.sign < 0)
inj = [i for (i, w) in enumerate(W) if w.sign > 0]
prod = [i for (i, w) in enumerate(W) if w.sign < 0]

# Функция getWellOutput должна извлекать требуемую величину из wellSols по списку индексов.
bhp = getWellOutput(wellSols, "bhp", inj)

# Пример построения графика BHP инжекторов
fig2 = Figure()
ax2 = Axis(fig2[1,1], xlabel = "Time [years]", ylabel = "Injector BHP [bar]", title = "Injector BHP")
lines!(ax2, T_years, bhp, linewidth = 2)
# Для легенды можно, например, собрать имена скважин:
inj_names = [W[i].name for i in inj]
axislegend(ax2, inj_names)
display(fig2)

# Аналогично для производственных скважин (массовые потоки нефти и воды)
orat = getWellOutput(wellSols, "qOs", prod)
wrat = getWellOutput(wellSols, "qWs", prod)
fig3 = Figure()
ax3 = Axis(fig3[1,1], xlabel = "Time [years]", ylabel = "Producer Oil Rate [m³/day]",
           title = "Oil Rate")
lines!(ax3, T_years, -orat, linewidth = 2)
display(fig3)

fig4 = Figure()
ax4 = Axis(fig4[1,1], xlabel = "Time [years]", ylabel = "Producer Water Rate [m³/day]",
           title = "Water Rate")
lines!(ax4, T_years, -wrat, linewidth = 2)
display(fig4)

fig5 = Figure()
ax5 = Axis(fig5[1,1], xlabel = "Time [years]", ylabel = "Water Cut",
           title = "Water Cut")
water_cut = abs.(wrat) ./ abs.(wrat .+ orat)
lines!(ax5, T_years, water_cut, linewidth = 2)
display(fig5)

# -----------------------------------------------------------------------------
# 5. Построение динамических графиков давления и насыщенности водой
# -----------------------------------------------------------------------------
# Для каждого сохраненного состояния (states — массив словарей) строим карту давления и насыщенности
# Предполагается, что st.pressure — вектор давления, а st.s — матрица насыщенности (возьмем первый столбец для воды)
const barsa = 1e5
fig6 = Figure(resolution = (1200,600))
for (i, st) in enumerate(states)
    # Вычисляем накопленное время до текущего состояния
    t_sum = sum(schedule.step.val[1:i])
    # Форматируем время в строку (реализуйте formatTimeRange по необходимости)
    timestr = string(round(t_sum/ year_sec, digits=2), " years")
    
    # Создаем два подграфика: давление и насыщенность водой
    axp = Axis(fig6[1,1], title = "Pressure after $(timestr)", xticks = nothing, yticks = nothing)
    # Предполагается, что давление (в Pa) переводится в barsa
    cell_pressure = st.pressure ./ barsa
    heatmap!(axp, G.cell_centers[:,1], G.cell_centers[:,2], cell_pressure; colormap = :jet)
    # Отображаем скважины: инжекторы (черный) и производители (красный)
    for i_inj in inj
        scatter!(axp, W[i_inj].location[1], W[i_inj].location[2], color = :black, markersize = 10)
    end
    for i_prod in prod
        scatter!(axp, W[i_prod].location[1], W[i_prod].location[2], color = :red, markersize = 10)
    end
    
    axs = Axis(fig6[1,2], title = "Water Saturation after $(timestr)", xticks = nothing, yticks = nothing)
    water_sat = st.s[:,1]
    heatmap!(axs, G.cell_centers[:,1], G.cell_centers[:,2], water_sat; colormap = :jet)
    for i_inj in inj
        scatter!(axs, W[i_inj].location[1], W[i_inj].location[2], color = :black, markersize = 10)
    end
    for i_prod in prod
        scatter!(axs, W[i_prod].location[1], W[i_prod].location[2], color = :red, markersize = 10)
    end
    Colorbar(axp, label = "barsa", labelsize = 12)
    Colorbar(axs, label = "s", labelsize = 12)
    display(fig6)
    sleep(0.5)  # задержка для анимации
end