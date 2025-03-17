function getRigidStepSelector()
    return SimpleTimeStepSelector(
        firstRampupStepRelative = 1,
        firstRampupStep         = Inf,
        maxRelativeAdjustment   = Inf,
        minRelativeAdjustment   = 1,
        maxTimestep             = Inf,
        minTimestep             = 0
    )
end
