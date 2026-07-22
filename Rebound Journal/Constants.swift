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

struct Constants {
    struct ContentText {
        let shootTypeTitle = "어떤 슛을 남겨볼까요?"
        let shootTypeDescription = "골인은 성공을, 리바운드는 아쉬운 실패를 뜻해요"
        
        let EmotionInPutGoalIn = "골인!\n지금 어떤 감정인가요?"
        let EmotionInPutRebound = "리바운드!\n지금 어떤 감정인가요?"
        
        let reviewShooting = "오늘 쏘았던 슛은 어땠나요?"
        let reviewShootingField = "짧아도 좋아요. 경험에 대해 적어봐요."
        let whatNextPlan = "앞으로의 계획은 어떤 것인가요?"
        let whatNextPlanField = "작은 것부터 생각해보아도 좋아요."

        /// 긍정적
        let emotionTextsLevel0 = ["기분이 좋은", "신나는", "자랑스러운", "의욕적인", "뿌듯한",
                                  "상쾌한", "설레는", "감사한", "행복한", "자신감이 생긴",
                                  "편안한", "만족한", "열정적인", "기대되는", "용기있는"]

        /// 보통
        let emotionTextsLevel1 = ["평범한", "일상적인", "중립적인", "무난한", "일반적인",
                                  "보통의", "냉정한", "무감각한", "무관심한", "무표정한"]

        /// 부정적
        let emotionTextsLevel2 = ["실망스러운", "지루한", "어수선한", "괴로운", "불만족스러운",
                                  "피곤한", "짜증나는", "슬픈", "불안한"]

        /// 매우 부정적
        let emotionTextsLevel3 = ["절망적인", "끔찍한", "비참한", "혐오스러운", "무서운",
                                  "파괴적인", "쓸쓸한", "분노스러운", "좌절스러운", "무력한"]
        
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
        let previousButton = "이전"
        let nextButton = "다음으로"
        let saveButton = "저장하기"
        let goalIn = "골인"
        let rebound = "리바운드"
        let sliderGuide = "슬라이더를 움직여\n감정을 표현해보세요"
    }
    
    struct Strings {
        
        static let mainTitle = "리바운드 저널"
        
        static let oops = "이런!"
        static let reboundShootIn = "리바운드 슛!"
        
        static let past = "과거"
        static let future = "미래"
        static let shootInIsDisabled = "슛은 쏠 수 없어요"
        static let howIsYourDaySoFar = "오늘 하루 어때요?"
        static let shootIn = "슛-쏘기"
        static let reShootIn = "다시-쏘기"
        
        static let noEntriesYet = "아직 슈팅 기록이 없어요"
        static let noEntriesYetDiscription = "한 번도 쓧을 쏘지 않았는데\n슛-쏘기 버튼을 눌러서 슛 쏴보는건 어때요?"
        
        static let todayShoot = "오늘 쏘았던 슛은 어땠나요?"// "What shot did you shoot today?"
        
        static let feelToday = "어떤 슛을 남겨볼까요?" //"Hello, how do you feel today?"
        static let howToRebound = "만족해요? 이 다음은 어떻게 할꺼에요?"// "How can you rebound?"
        static let attachPhotos = "같이 붙일 사진이 있나요?"// "Do you want to attach any photos?"
        static let reboundTodayShoot = "다시 쏘았던 슛은 어땠나요?"// "What shot did you shoot today?"
        static let reboundFeelToday = "그래서 그 슛을 다시 쏘고난 지금 기분은 어때요?" //"Hello, how do you feel today?"
        static let reboundHowToRebound = "리바운드는 만족해요? 이 다음은 어떻게 할꺼에요?"// "How can you rebound?"
        static let reboundAttachPhotos = "같이 붙일 사진이 있나요?"// "Do you want to attach any photos?"
        static let whatWillNext = "그래서 이 다음은 어떻게 되는거에요?"//"Describe how was your day so far..."
        static let describeShoot = "오늘 쏘았던 슛은 얼마나 멀리 날아갔는지 최대한 자세하게 설명해주세요."//"Describe how was your day so far..."
        
        static let doneEditing = "작성완료" //"Done Editing"
        static let nextStep = "다음으로" //"Next Step"
        static let submitEntry = "슛 쏘기" // "Submit Entry"
        
        static let whatIshoot = "내가 쐈던 슛은 이랬어요" // "What I shoot"
        static let myReboundPlan = "내 다음 계획은 이래요"// "My rebound plan"
        static let myMood = "지금 내 기분은"
        
        static let exitFlow = "슈팅을 그만하시겠어요?"// "Exit Flow"
        static let exitDescription = "지금 나가시면 기록했던 내용들이\n모두 사라집니다."//"Are you sure you want to leave this flow? You will lose your current progress"

				static let exitText = "나가기"
				static let continueText = "계속 작성하기"

        
        // SettingsView
        static let setting = "설정"// "setting"
        static let appPasscode = "앱 비밀번호" // "App Passcode"
        
        static let setPasscode = "비밀번호 설정" // "Set Passcode"
        static let disablePasscode = "비밀번호 삭제" // "Disable Passcode"
        
        static let dailyReminders = "매일 알림"// "Daily Reminders"
        static let enableReminders = "알림 켜기"// "Enable Reminders"
        
        static let spreadTheWord = "소식을 퍼뜨리세요" // "Spread the Word"
        static let rateApp = "평점주기" // "Rate App"
        static let shareApp = "앱 공유하기" // "Share App"
        
        static let supportAndPrivacy = "지원 및 개인정보 보호" // "Support & Privacy"
        static let eMailUs = "개발자에게 메일 보내기" // "E-Mail us"
        static let instagramDM = "인스타그램 DM (@lee25_ios)" // "Instagram DM"
        static let privacyPolicy = "개인정보 보호정책"// "Privacy Policy"
        static let termsOfUse = "이용약관"// "Terms of Use"
        
        static let history = "이전 기록보기"// "History"
    }
    
    struct ImageStrings {
        static let xMark = "xmark"
    }
}
