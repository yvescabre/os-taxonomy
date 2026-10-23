/// Fixed (argument-free) child-facing lines the app speaks; these ship as prerecorded clips.
public enum SpokenLines {
    public static let prerecorded: [L10n.Key] = [
        .bridgeInstructions, .sequenceInstructions,
        .nudgeMissingNumber, .nudgeBalance, .nudgeCommutative, .nudgeSequence, .nudgeBuild,
        .clueCommutative, .clueSequence, .clueBuild,
        .feedbackCorrect, .feedbackAlmost, .feedbackUsedVisibleNumbers, .feedbackWroteTheWhole,
        .feedbackRunningTotal, .feedbackWrongOperation, .feedbackOffByOne, .feedbackPlaceValueSlip,
        .feedbackWrongStep, .feedbackWrongDirection, .feedbackGenericWrong,
    ]
}
