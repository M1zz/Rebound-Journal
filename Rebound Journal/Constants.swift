//
//  Constants.swift
//  Rebound Journal
//
//  Created by hyunho lee on 4/18/24.
//

import Foundation

enum EmotionLevel {
    case level0 // emotionTextsLevel0
    case level1 // emotionTextsLevel1
    case level2 // emotionTextsLevel2
    case level3 // emotionTextsLevel3
}

/// 저장·비교에 쓰이는 고정 값. 화면에 그릴 때만 `DisplayText` 로 번역한다.
/// 언어를 바꿔도 이미 저장된 기록이 깨지지 않도록 원문(한국어)을 그대로 유지한다.
enum DataSentinel {
    static let noGoal = "목표 없음"
    static let success = "성공"
    static let failure = "실패"
    static let uptrend = "상승세"
    static let downtrend = "하락세"
    static let steady = "안정"
    static let notEnoughData = "데이터 부족"
}

/// `DataSentinel` 값을 현재 언어로 번역해서 돌려준다.
enum DisplayText {
    static func goalName(_ raw: String) -> String {
        raw == DataSentinel.noGoal ? String(localized: "목표 없음") : raw
    }

    static func outcome(_ raw: String) -> String {
        switch raw {
        case DataSentinel.success: return String(localized: "성공")
        case DataSentinel.failure: return String(localized: "실패")
        default: return raw
        }
    }

    static func trend(_ raw: String) -> String {
        switch raw {
        case DataSentinel.uptrend: return String(localized: "상승세")
        case DataSentinel.downtrend: return String(localized: "하락세")
        case DataSentinel.steady: return String(localized: "안정")
        case DataSentinel.notEnoughData: return String(localized: "데이터 부족")
        default: return raw
        }
    }
}

struct Constants {
    struct ContentText {
        let shootTypeTitle = String(localized: "어떤 슛을 남겨볼까요?")
        let shootTypeDescription = String(localized: "골인은 성공을, 리바운드는 아쉬운 실패를 뜻해요")

        let EmotionInPutGoalIn = String(localized: "골인!\n지금 어떤 감정인가요?")
        let EmotionInPutRebound = String(localized: "리바운드!\n지금 어떤 감정인가요?")

        let reviewShooting = String(localized: "오늘 쏘았던 슛은 어땠나요?")
        let reviewShootingField = String(localized: "짧아도 좋아요. 경험에 대해 적어봐요.")
        let whatNextPlan = String(localized: "앞으로의 계획은 어떤 것인가요?")
        let whatNextPlanField = String(localized: "작은 것부터 생각해보아도 좋아요.")

        /// 긍정적
        let emotionTextsLevel0 = [
            String(localized: "기분이 좋은"), String(localized: "신나는"), String(localized: "자랑스러운"),
            String(localized: "의욕적인"), String(localized: "뿌듯한"), String(localized: "상쾌한"),
            String(localized: "설레는"), String(localized: "감사한"), String(localized: "행복한"),
            String(localized: "자신감이 생긴"), String(localized: "편안한"), String(localized: "만족한"),
            String(localized: "열정적인"), String(localized: "기대되는"), String(localized: "용기있는")
        ]

        /// 보통
        let emotionTextsLevel1 = [
            String(localized: "평범한"), String(localized: "일상적인"), String(localized: "중립적인"),
            String(localized: "무난한"), String(localized: "일반적인"), String(localized: "보통의"),
            String(localized: "냉정한"), String(localized: "무감각한"), String(localized: "무관심한"),
            String(localized: "무표정한")
        ]

        /// 부정적
        let emotionTextsLevel2 = [
            String(localized: "실망스러운"), String(localized: "지루한"), String(localized: "어수선한"),
            String(localized: "괴로운"), String(localized: "불만족스러운"), String(localized: "피곤한"),
            String(localized: "짜증나는"), String(localized: "슬픈"), String(localized: "불안한")
        ]

        /// 매우 부정적
        let emotionTextsLevel3 = [
            String(localized: "절망적인"), String(localized: "끔찍한"), String(localized: "비참한"),
            String(localized: "혐오스러운"), String(localized: "무서운"), String(localized: "파괴적인"),
            String(localized: "쓸쓸한"), String(localized: "분노스러운"), String(localized: "좌절스러운"),
            String(localized: "무력한")
        ]

        func getEmotions(for level: EmotionLevel) -> [String] {
            switch level {
            case .level0: return emotionTextsLevel0
            case .level1: return emotionTextsLevel1
            case .level2: return emotionTextsLevel2
            case .level3: return emotionTextsLevel3
            }
        }
    }

    struct SystemText {
        let previousButton = String(localized: "이전")
        let nextButton = String(localized: "다음으로")
        let saveButton = String(localized: "저장하기")
        let goalIn = String(localized: "골인")
        let rebound = String(localized: "리바운드")
        let sliderGuide = String(localized: "슬라이더를 움직여\n감정을 표현해보세요")
    }

    struct Strings {

        static let mainTitle = String(localized: "징검돌")

        static let oops = String(localized: "이런!")
        static let reboundShootIn = String(localized: "리바운드 슛!")

        static let past = String(localized: "과거")
        static let future = String(localized: "미래")
        static let shootInIsDisabled = String(localized: "슛은 쏠 수 없어요")
        static let howIsYourDaySoFar = String(localized: "오늘 하루 어때요?")
        static let shootIn = String(localized: "슛-쏘기")
        static let reShootIn = String(localized: "다시-쏘기")

        static let noEntriesYet = String(localized: "아직 슈팅 기록이 없어요")
        static let noEntriesYetDiscription = String(localized: "한 번도 쓧을 쏘지 않았는데\n슛-쏘기 버튼을 눌러서 슛 쏴보는건 어때요?")

        static let todayShoot = String(localized: "오늘 쏘았던 슛은 어땠나요?")

        static let feelToday = String(localized: "어떤 슛을 남겨볼까요?")
        static let howToRebound = String(localized: "만족해요? 이 다음은 어떻게 할꺼에요?")
        static let attachPhotos = String(localized: "같이 붙일 사진이 있나요?")
        static let reboundTodayShoot = String(localized: "다시 쏘았던 슛은 어땠나요?")
        static let reboundFeelToday = String(localized: "그래서 그 슛을 다시 쏘고난 지금 기분은 어때요?")
        static let reboundHowToRebound = String(localized: "리바운드는 만족해요? 이 다음은 어떻게 할꺼에요?")
        static let reboundAttachPhotos = String(localized: "같이 붙일 사진이 있나요?")
        static let whatWillNext = String(localized: "그래서 이 다음은 어떻게 되는거에요?")
        static let describeShoot = String(localized: "오늘 쏘았던 슛은 얼마나 멀리 날아갔는지 최대한 자세하게 설명해주세요.")

        static let doneEditing = String(localized: "작성완료")
        static let nextStep = String(localized: "다음으로")
        static let submitEntry = String(localized: "슛 쏘기")

        static let whatIshoot = String(localized: "내가 쐈던 슛은 이랬어요")
        static let myReboundPlan = String(localized: "내 다음 계획은 이래요")
        static let myMood = String(localized: "지금 내 기분은")

        static let exitFlow = String(localized: "슈팅을 그만하시겠어요?")
        static let exitDescription = String(localized: "지금 나가시면 기록했던 내용들이\n모두 사라집니다.")

        static let exitText = String(localized: "나가기")
        static let continueText = String(localized: "계속 작성하기")

        // SettingsView
        static let setting = String(localized: "설정")
        static let appPasscode = String(localized: "앱 비밀번호")

        static let setPasscode = String(localized: "비밀번호 설정")
        static let disablePasscode = String(localized: "비밀번호 삭제")

        static let dailyReminders = String(localized: "매일 알림")
        static let enableReminders = String(localized: "알림 켜기")

        static let spreadTheWord = String(localized: "소식을 퍼뜨리세요")
        static let rateApp = String(localized: "평점주기")
        static let shareApp = String(localized: "앱 공유하기")

        static let supportAndPrivacy = String(localized: "지원 및 개인정보 보호")
        static let eMailUs = String(localized: "개발자에게 메일 보내기")
        static let instagramDM = String(localized: "인스타그램 DM (@lee25_ios)")
        static let privacyPolicy = String(localized: "개인정보 보호정책")
        static let termsOfUse = String(localized: "이용약관")

        static let history = String(localized: "이전 기록보기")
    }

    struct ImageStrings {
        static let xMark = "xmark"
    }
}
