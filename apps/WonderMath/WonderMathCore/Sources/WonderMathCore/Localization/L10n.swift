import Foundation

/// All child-facing copy is funneled through these keys. The taxonomy dataset
/// is English-only, so any raw dataset string is never shown to a German
/// learner — `TaxonomyLocalization` provides an explicit translation table
/// for names/domains and authored mechanic text lives here.
public enum L10n {

    public enum Key: String, Codable, CaseIterable, Sendable {
        // App chrome
        case appName
        case worldMapTitle
        case settingsTitle
        case parentZoneTitle
        case loadingTaxonomy
        case comingSoon
        case comingSoonDetail
        case closeButton
        case doneButton
        case customizeBuddy
        case minuteFormatOne
        case minutesFormat
        case parentAgeFormat
        case curriculumNotice
        case languageEnglish
        case languageGerman
        case difficultyGentler
        case difficultyBalanced
        case difficultyBolder
        case companionColorLabel
        case companionAccessoryLabel
        case xpFormat
        case roundsFormat

        // Worlds
        case world1Title, world1Subtitle
        case world2Title, world2Subtitle
        case world3Title, world3Subtitle
        case world4Title, world4Subtitle
        case world5Title, world5Subtitle
        case lockedWorldBadge
        case playTopic
        case masteredBadge
        case lockedBadge
        case topicPathTitle
        case mapCompanionGreeting
        case scaffoldEncouragement
        case bridgeProgressFormat
        case progressStars
        case progressStarsValueFormat

        // Profile / onboarding
        case chooseName
        case chooseAge
        case chooseCompanion
        case onboardingTitle
        case onboardingBubbleName
        case onboardingBubbleAge
        case onboardingBubbleBuddy
        case onboardingNext
        case onboardingBack
        case startAdventure
        case childNamePlaceholder

        // Companion
        case companionFox, companionOwl, companionTurtle, companionDragon
        case companionHelperPraise

        // Bridge scene
        case bridgeInstructions
        case sequenceInstructions
        case dropPlankHere
        case checkAnswer
        case tryAgain
        case nextPuzzle
        case showHint
        case hintNudgeTitle
        case hintClueTitle
        case hintWalkthroughTitle
        case whyDoesThisWork
        case bigIdeaTitle
        case wonderTitle
        case tryItTitle
        case noTeachingNotesYet
        case skipPuzzle

        // Rewards
        case wellDone
        case chestOpened
        case xpEarnedFormat
        case treasureFound
        case newBadgeEarned
        case keepGoing

        // Hints & feedback (mechanic-authored, localized)
        case nudgeMissingNumber
        case nudgeMissingNumberTimes
        case nudgeMissingNumberDividedBy
        case nudgeDividedByWhich
        case nudgeBalance
        case nudgeCommutative
        case nudgeSequence
        case nudgeBuild
        case clueInverseAddSub
        case clueInverseSubAsAdd
        case clueInverseMultDiv
        case clueInverseDivAsMult
        case clueBalance
        case clueCommutative
        case clueSequence
        case clueBuild
        case feedbackCorrect
        case feedbackAlmost
        case feedbackUsedVisibleNumbers
        case feedbackWroteTheWhole
        case feedbackRunningTotal
        case feedbackWrongOperation
        case feedbackOffByOne
        case feedbackPlaceValueSlip
        case feedbackWrongStep
        case feedbackWrongDirection
        case feedbackGenericWrong

        // Walkthrough step templates ({0}=number slots)
        case stepWeKnowFormat
        case stepInverseFormat
        case stepCheckFormat
        case stepSequenceFormat

        // Explanation big ideas (per form)
        case ideaMissingAddend
        case ideaMissingFactor
        case ideaEqualsBalance
        case ideaCommutative
        case ideaSequence
        case ideaInverseCheck
        case ideaBuild

        // Daily adventure
        case dailyAdventureTitle
        case stageWarmup
        case stageMaths
        case stageLogic
        case stageCreative
        case stageChallenge
        case adventureComplete
        case adventureProgressFormat

        // Parent zone
        case parentGatePrompt
        case parentGateHint
        case learningTimeTitle
        case skillsPracticedTitle
        case masteryTitle
        case improvementTitle
        case achievementsTitle
        case offlineActivitiesTitle
        case settingsSectionTitle
        case attributionTitle
        case attributionText
        case licenseNote
        case parentZoneDescription
        case masteryNotStarted, masteryLearning, masteryMastered, masteryReview
        case evidenceConversationOnly
        case suggestedFocusFormat
        case noDataYet
        case perSkillTableTopic
        case perSkillTableAccuracy
        case perSkillTableAttempts
        case perSkillTableState
        case audioLabel, languageLabel, difficultyLabel
        case voiceSectionTitle, voicePersonalToggle
        case voiceStatusUsingPersonal, voiceStatusAvailable, voiceStatusNoLanguageVoice
        case voiceStatusDenied, voiceStatusCreate, voicePreview
        case voiceCurrentFormat, voiceNameDefault
        case voiceQualityPremium, voiceQualityEnhanced, voiceQualityDefault
        case researchTipPrefix
        case teachingNoteForParents

        // Achievements (names)
        case achFirstBridge
        case achTenBridges
        case achMasteredSkill
        case achUsedWalkthroughThenSolved
        case achFoundMultipleWays
        case achFinishedAdventure

        // Errors
        case errorGeneric
    }
}
