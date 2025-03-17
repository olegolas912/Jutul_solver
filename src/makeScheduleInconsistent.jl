function make_schedule_inconsistent(schedule, day, inj_coef, prod_coef)
    # Создаем глубокие копии исходного расписания для двух частей
    schedule1 = deepcopy(schedule)
    schedule1.step.control = schedule1.step.control[1:day, 1]
    schedule1.step.val     = schedule1.step.val[1:day, 1]
    
    schedule2 = deepcopy(schedule)
    schedule2.step.control = schedule2.step.control[day+1:end, 1]
    schedule2.step.val     = schedule2.step.val[day+1:end, 1]
    
    # Модифицируем управляющие значения для первых 8 скважин (инжекторы)
    for i in 1:8
        schedule2.control.W[i].val *= inj_coef
    end
    # Для скважин с 9 по 12 (производители)
    for i in 9:12
        schedule2.control.W[i].val *= prod_coef
    end
    
    # Объединяем расписания, отключая приведение к согласованному расписанию
    schedule_new = combineSchedules(schedule1, schedule2; makeConsistent = false)
    return schedule_new
end
