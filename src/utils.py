"""Code for parsing and plotting result files saved from Julia (e.g. via JLD2)"""
import h5py
import numpy as np


def states(data_path):
    with h5py.File(data_path, 'r') as f:
        # Предполагается, что данные сохранены в группе "statesStepSol"
        states_struct = f["statesStepSol"]
        # Если "pressure" и "s" сохранены как массивы или наборы, их можно извлечь так:
        pressure = np.array(states_struct["pressure"])
        sat = np.array(states_struct["s"])
    return pressure, sat


def reports(data_path):
    with h5py.File(data_path, 'r') as f:
        # Предполагается, что отчет сохранён в группе "reportData"
        report_struct = f["reportData"]
        # [()] извлекает скалярное значение
        iterations = report_struct["Iterations"][()]
        sim_time = report_struct["SimulationTime"][()]
    return iterations, sim_time
