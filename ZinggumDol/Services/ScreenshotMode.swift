//
//  ScreenshotMode.swift
//  ZinggumDol
//
//  App Store 스크린샷을 찍는 자리. **DEBUG 빌드에서만** 있다.
//
//  시뮬레이터는 손으로 누를 수 없으니 실행 인자로 화면을 연다:
//
//      xcrun simctl launch <기기> com.leeo.ReboundJournal -shot lookBack -AppleLanguages "(en)"
//
//  `-shot` 이 붙으면 기존 데이터를 비우고 그 언어로 된 기록을 새로 심는다.
//  값: home · conversation · lookBack · records · addGoal · settings
//

#if DEBUG
import Foundation
import SwiftData

enum ScreenshotMode {

    /// `-shot <화면>` 실행 인자. 인자는 UserDefaults 로 들어온다.
    static var scene: String? { UserDefaults.standard.string(forKey: "shot") }

    static var isActive: Bool { scene != nil }

    private static var isKorean: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ko") ?? true
    }

    /// 한국어 · 영어 밖 언어의 샘플 기록. 스크린샷 화면 속 글도 그 언어여야 한다.
    /// 순서: 걷기, 일어나기, 읽기 목표 → 기록 7개(느낀 점) · 다음엔 2개 (아래 records 와 같은 자리)
    private static let samples: [String: [String]] = [
        "cs": ["Projít se 30 minut po večeři", "Vstávat v 7", "Před spaním 10 stran", "Přestalo pršet, tak jsem došel až k řece. V hlavě mám jasno.", "Vypnul jsem budík a zase usnul. Do dvou do rána jsem byl na mobilu.", "Ve 23:30 nechat mobil v obýváku", "Byli jsme se sestrou na procházce. Čas utekl mnohem rychleji než o samotě.", "Chtěl jsem přečíst 10 stran a dal jsem celou kapitolu.", "Z práce jsem se vrátil až v 9. Na procházku už nebyla síla.", "V dlouhé dny aspoň kolečko kolem bloku", "Spal jsem s roztaženými závěsy a probudil se sám.", "Čtení v posteli mě příjemně uspalo."],
        "da": ["Gå en tur på 30 minutter efter aftensmaden", "Stå op kl. 7", "Læse 10 sider før sengetid", "Regnen stoppede, så jeg gik helt ned til åen. Hovedet føles klart.", "Slukkede vækkeuret og faldt i søvn igen. Sad med telefonen til kl. 2.", "Læg telefonen i stuen kl. 23.30", "Gik en tur med min søster. Tiden fløj i forhold til at gå alene.", "Ville læse 10 sider og læste et helt kapitel.", "Kom hjem kl. 21 efter at have arbejdet over. Ingen energi til at gå.", "På lange dage bare én tur rundt om blokken", "Sov med gardinerne trukket fra og vågnede af mig selv.", "At læse i sengen gjorde mig dejligt søvnig."],
        "de": ["Nach dem Abendessen 30 Minuten spazieren", "Um 7 Uhr aufstehen", "Vor dem Schlafen 10 Seiten lesen", "Der Regen hat aufgehört, also bin ich bis zum Fluss gelaufen. Mein Kopf ist frei.", "Wecker ausgemacht und wieder eingeschlafen. War bis 2 Uhr nachts am Handy.", "Um 23:30 das Handy ins Wohnzimmer legen", "Mit meiner Schwester spazieren gewesen. Die Zeit verging wie im Flug.", "Wollte 10 Seiten lesen und habe ein ganzes Kapitel geschafft.", "Nach Überstunden erst um 21 Uhr zu Hause. Keine Energie mehr zum Laufen.", "An langen Tagen nur eine Runde um den Block", "Mit offenen Vorhängen geschlafen und von allein aufgewacht.", "Im Bett lesen hat mich angenehm müde gemacht."],
        "el": ["Περπάτημα 30 λεπτά μετά το βραδινό", "Ξύπνημα στις 7", "10 σελίδες πριν τον ύπνο", "Σταμάτησε η βροχή και περπάτησα ως το ποτάμι. Καθάρισε το μυαλό μου.", "Έκλεισα το ξυπνητήρι και ξανακοιμήθηκα. Ήμουν στο κινητό ως τις 2 τα ξημερώματα.", "Στις 23:30 το κινητό μένει στο σαλόνι", "Περπάτησα με την αδερφή μου. Η ώρα πέρασε πετώντας.", "Ήθελα να διαβάσω 10 σελίδες και τελείωσα ολόκληρο κεφάλαιο.", "Γύρισα σπίτι στις 9 μετά από υπερωρίες. Δεν είχα κουράγιο για περπάτημα.", "Τις δύσκολες μέρες, μόνο έναν γύρο στο τετράγωνο", "Κοιμήθηκα με ανοιχτές κουρτίνες και ξύπνησα χωρίς ξυπνητήρι.", "Το διάβασμα στο κρεβάτι μού έφερε γλυκιά νύστα."],
        "en-GB": ["Walk for 30 minutes after dinner", "Get up at 7", "Read 10 pages before bed", "The rain stopped, so I walked all the way to the river. My head feels clear.", "Turned the alarm off and dozed off again. I was on my phone until 2am.", "Leave my phone in the living room at 11.30pm", "Went for a walk with my sister. Time flew compared to walking alone.", "Meant to read 10 pages and finished a whole chapter.", "Got home at 9 after working late. No energy left for a walk.", "On late days, just one lap round the block", "Slept with the curtains open and woke up naturally.", "Reading in bed made me nicely sleepy."],
        "es": ["Caminar 30 minutos después de cenar", "Levantarme a las 7", "Leer 10 páginas antes de dormir", "Dejó de llover y caminé hasta el río. Tengo la cabeza despejada.", "Apagué la alarma y me volví a dormir. Estuve con el móvil hasta las 2.", "Dejar el móvil en el salón a las 23:30", "Caminé con mi hermana. El tiempo se pasó volando.", "Iba a leer 10 páginas y terminé un capítulo entero.", "Llegué a casa a las 9 tras trabajar hasta tarde. Sin energía para caminar.", "Los días largos, solo una vuelta a la manzana", "Dormí con las cortinas abiertas y me desperté sin alarma.", "Leer en la cama me dio un sueño agradable."],
        "fi": ["30 minuutin kävely illallisen jälkeen", "Herätys klo 7", "10 sivua ennen nukkumaanmenoa", "Sade loppui, joten kävelin joelle asti. Pää tuntuu selkeältä.", "Sammutin herätyksen ja nukahdin uudelleen. Selasin puhelinta kahteen asti yöllä.", "Puhelin olohuoneeseen klo 23.30", "Kävelin siskon kanssa. Aika kului paljon nopeammin kuin yksin.", "Piti lukea 10 sivua, mutta luin koko luvun.", "Pääsin kotiin vasta yhdeksältä ylitöiden jälkeen. Ei ollut enää virtaa kävellä.", "Pitkinä päivinä vain yksi kierros korttelin ympäri", "Nukuin verhot auki ja heräsin itsestäni.", "Sängyssä lukeminen nukutti mukavasti."],
        "fr": ["Marcher 30 minutes après le dîner", "Me lever à 7 h", "Lire 10 pages avant de dormir", "La pluie s'est arrêtée, alors j'ai marché jusqu'à la rivière. J'ai l'esprit clair.", "J'ai éteint le réveil et refait un somme. Sur mon téléphone jusqu'à 2 h du matin.", "Laisser mon téléphone au salon à 23 h 30", "Marché avec ma sœur. Le temps a filé bien plus vite qu'en solo.", "Je voulais lire 10 pages, j'ai fini tout un chapitre.", "Retour à 21 h après une longue journée. Plus la force de marcher.", "Les soirs tardifs, juste un tour du pâté de maisons", "Dormi rideaux ouverts, réveil naturel ce matin.", "Lire au lit m'a doucement donné sommeil."],
        "id": ["Jalan kaki 30 menit setelah makan malam", "Bangun jam 7", "Baca 10 halaman sebelum tidur", "Hujannya reda, jadi aku jalan sampai ke sungai. Pikiran jadi jernih.", "Matikan alarm lalu ketiduran lagi. Main HP sampai jam 2 pagi.", "Jam 23.30 taruh HP di ruang tamu", "Jalan bareng adikku. Waktu terasa cepat dibanding jalan sendirian.", "Niatnya baca 10 halaman, malah selesai satu bab.", "Lembur, sampai rumah jam 9 malam. Sudah nggak ada tenaga buat jalan.", "Kalau pulang malam, cukup satu putaran keliling kompleks", "Tidur dengan gorden terbuka dan bangun sendiri.", "Baca di kasur bikin ngantuk yang enak."],
        "it": ["Camminare 30 minuti dopo cena", "Svegliarmi alle 7", "Leggere 10 pagine prima di dormire", "Ha smesso di piovere e ho camminato fino al fiume. Ho la testa leggera.", "Ho spento la sveglia e ho ripreso sonno. Al telefono fino alle 2 di notte.", "Lasciare il telefono in salotto alle 23:30", "Ho camminato con mia sorella. Il tempo è volato rispetto a camminare da soli.", "Volevo leggere 10 pagine e ho finito un capitolo intero.", "A casa alle 21 dopo aver lavorato fino a tardi. Niente energie per camminare.", "Nei giorni lunghi, solo un giro dell'isolato", "Ho dormito con le tende aperte e ho aperto gli occhi senza sveglia.", "Leggere a letto mi ha fatto venire un bel sonno."],
        "ja": ["夕食後に30分歩く", "7時に起きる", "寝る前に本を10ページ", "雨がやんだので川まで歩いた。頭がすっきりした。", "アラームを止めて二度寝。夜中の2時までスマホを見ていた。", "23時半にスマホをリビングに置く", "妹と一緒に歩いた。ひとりよりあっという間だった。", "10ページのつもりが、1章まるごと読めた。", "残業で帰宅は9時。歩く元気が残っていなかった。", "遅い日は近所を1周だけ", "カーテンを開けて寝たら、自然に目が覚めた。", "ベッドで読んでいたら、心地よく眠くなった。"],
        "nb": ["Gå 30 minutter etter middag", "Stå opp klokka 7", "Lese 10 sider før leggetid", "Regnet ga seg, så jeg gikk helt ned til elva. Hodet føles klart.", "Slo av vekkerklokka og sovnet igjen. Satt med mobilen til klokka 2.", "Legg mobilen i stua kl. 23.30", "Gikk tur med søstera mi. Tiden fløy sammenlignet med å gå alene.", "Skulle lese 10 sider og leste et helt kapittel.", "Kom hjem klokka 21 etter overtid. Ingen energi igjen til å gå.", "På lange dager holder det med én runde rundt kvartalet", "Sov med gardinene trukket fra og våknet av meg selv.", "Å lese i senga gjorde meg deilig søvnig."],
        "nl": ["Na het eten 30 minuten wandelen", "Om 7 uur opstaan", "Voor het slapen 10 bladzijden lezen", "Het was droog, dus ik ben helemaal naar de rivier gelopen. Mijn hoofd is weer helder.", "Wekker uitgezet en weer in slaap gevallen. Tot 2 uur 's nachts op mijn telefoon gezeten.", "Om 23.30 uur mijn telefoon in de woonkamer leggen", "Met mijn zus gewandeld. De tijd vloog vergeleken met alleen lopen.", "Wilde 10 bladzijden lezen en heb een heel hoofdstuk uitgelezen.", "Pas om 21 uur thuis na overwerken. Geen energie meer om te wandelen.", "Op lange dagen gewoon één rondje om het blok", "Met open gordijnen geslapen en vanzelf wakker geworden.", "Lezen in bed maakte me lekker slaperig."],
        "pl": ["Spacer 30 minut po kolacji", "Wstawać o 7", "10 stron przed snem", "Przestało padać, więc doszedłem aż nad rzekę. W głowie się rozjaśniło.", "Wyłączyłem budzik i znowu zasnąłem. Siedziałem w telefonie do 2 w nocy.", "O 23:30 zostawić telefon w salonie", "Spacer z siostrą. Czas leciał dużo szybciej niż w pojedynkę.", "Miałem przeczytać 10 stron, a skończyłem cały rozdział.", "Po nadgodzinach w domu dopiero o 21. Nie było siły na spacer.", "W długie dni choć jedno kółko wokół bloku", "Spałem z odsłoniętymi zasłonami i obudziłem się sam.", "Czytanie w łóżku przyjemnie mnie uśpiło."],
        "pt-BR": ["Caminhar 30 minutos depois do jantar", "Acordar às 7", "Ler 10 páginas antes de dormir", "A chuva parou e fui caminhando até o rio. Estou com a cabeça leve.", "Desliguei o despertador e voltei a dormir. Fiquei no celular até as 2 da manhã.", "Deixar o celular na sala às 23h30", "Caminhei com minha irmã. O tempo passou voando.", "Ia ler 10 páginas e terminei um capítulo inteiro.", "Cheguei em casa às 21h depois de trabalhar até tarde. Sem energia pra caminhar.", "Nos dias puxados, só uma volta no quarteirão", "Dormi com a cortina aberta e acordei sem despertador.", "Ler na cama me deu um sono gostoso."],
        "ru": ["Гулять 30 минут после ужина", "Вставать в 7", "10 страниц перед сном", "Дождь кончился, и я дошёл до самой реки. В голове прояснилось.", "Выключил будильник и снова уснул. До двух ночи сидел в телефоне.", "В 23:30 оставить телефон в гостиной", "Гуляли с сестрой. Время пролетело быстрее, чем одному.", "Хотел прочитать 10 страниц, а осилил целую главу.", "Задержался на работе, дома только в 9. Сил на прогулку не осталось.", "В поздние дни хотя бы круг вокруг квартала", "Спал с открытыми шторами и проснулся сам.", "Читал в кровати, и приятно потянуло в сон."],
        "sv": ["Promenera 30 minuter efter middagen", "Gå upp klockan 7", "Läsa 10 sidor innan läggdags", "Regnet slutade, så jag gick ända ner till ån. Huvudet känns klart.", "Stängde av larmet och somnade om. Satt med mobilen till klockan 2.", "Lägg mobilen i vardagsrummet kl. 23.30", "Promenerade med min syster. Tiden flög jämfört med att gå själv.", "Tänkte läsa 10 sidor och läste ut ett helt kapitel.", "Kom hem vid 21 efter att ha jobbat sent. Ingen ork kvar att gå.", "Sena dagar räcker ett varv runt kvarteret", "Sov med gardinerna fråndragna och vaknade av mig själv.", "Att läsa i sängen gjorde mig skönt sömnig."],
        "th": ["เดิน 30 นาทีหลังมื้อเย็น", "ตื่นนอนตอน 7 โมง", "อ่านหนังสือ 10 หน้าก่อนนอน", "ฝนหยุดแล้ว เลยเดินไปจนถึงริมแม่น้ำ หัวโล่งขึ้นเยอะ", "ปิดนาฬิกาปลุกแล้วหลับต่อ เมื่อคืนเล่นมือถือถึงตีสอง", "23:30 วางมือถือไว้ที่ห้องนั่งเล่น", "เดินกับน้องสาว เวลาผ่านไปเร็วกว่าเดินคนเดียวเยอะ", "ตั้งใจจะอ่าน 10 หน้า แต่อ่านจบไปทั้งบท", "ทำงานดึก กลับถึงบ้านสามทุ่ม ไม่มีแรงเดินแล้ว", "วันที่กลับดึก เดินรอบซอยสักรอบก็พอ", "นอนเปิดผ้าม่านไว้ ตื่นเองได้โดยไม่ต้องตั้งปลุก", "อ่านหนังสือบนเตียงแล้วง่วงแบบสบายๆ"],
        "tr": ["Akşam yemeğinden sonra 30 dakika yürü", "7'de kalk", "Yatmadan önce 10 sayfa oku", "Yağmur dindi, ben de nehre kadar yürüdüm. Kafam berraklaştı.", "Alarmı kapatıp yeniden uyudum. Gece 2'ye kadar telefondaydım.", "23.30'da telefonu salona bırak", "Kız kardeşimle yürüdüm. Yalnız yürümeye göre zaman su gibi geçti.", "10 sayfa okuyacaktım, koca bir bölümü bitirdim.", "Mesaiden sonra eve ancak 9'da geldim. Yürüyecek halim kalmadı.", "Geç kalınan günlerde mahallede bir tur yeter", "Perdeler açık uyudum, kendiliğimden uyandım.", "Yatakta okumak tatlı bir uyku getirdi."],
        "vi": ["Đi bộ 30 phút sau bữa tối", "Dậy lúc 7 giờ", "Đọc 10 trang sách trước khi ngủ", "Mưa tạnh nên mình đi bộ ra tận bờ sông. Đầu óc nhẹ hẳn.", "Tắt báo thức rồi ngủ tiếp. Tối qua lướt điện thoại tới 2 giờ sáng.", "23:30 để điện thoại ở phòng khách", "Đi bộ cùng em gái. Thời gian trôi nhanh hơn hẳn đi một mình.", "Định đọc 10 trang mà đọc hết luôn một chương.", "Tăng ca, 9 giờ tối mới về tới nhà. Hết sức đi bộ rồi.", "Hôm nào về muộn thì chỉ đi một vòng quanh khu phố", "Ngủ mở rèm, sáng tự thức dậy.", "Đọc sách trên giường, buồn ngủ thật dễ chịu."],
        "zh-Hans": ["晚饭后散步30分钟", "7点起床", "睡前读10页书", "雨停了，就一路走到了河边。脑子清醒多了。", "关了闹钟又睡过去了。玩手机玩到凌晨2点。", "23:30把手机放在客厅", "和妹妹一起散步。比一个人走时间过得快多了。", "本来只想读10页，结果读完了一整章。", "加班到9点才到家。没力气再去走路了。", "加班的日子，就绕小区走一圈", "开着窗帘睡，自然醒了。", "躺在床上看书，舒服地犯困了。"],
        "zh-Hant": ["晚餐後散步30分鐘", "7點起床", "睡前讀10頁書", "雨停了，就一路走到河邊。腦袋清醒多了。", "關掉鬧鐘又睡回去了。滑手機滑到凌晨2點。", "23:30把手機放在客廳", "和妹妹一起散步。比一個人走時間過得快多了。", "本來只想讀10頁，結果讀完了一整章。", "加班到9點才到家。沒力氣再去走路了。", "加班的日子，就繞街區走一圈", "開著窗簾睡，自然醒了。", "躺在床上看書，舒服地想睡了。"],
    ]

    /// 실행 언어에 맞는 샘플. zh-Hans · pt-BR · en-GB 처럼 지역까지 맞는 것을 먼저 찾는다.
    private static var localSample: [String]? {
        guard let id = Locale.preferredLanguages.first else { return nil }
        if let exact = samples[id] { return exact }
        let parts = id.split(separator: "-")
        if parts.count >= 2, let two = samples["\(parts[0])-\(parts[1])"] { return two }
        return samples[String(parts[0])]
    }

    static func seed(_ container: ModelContainer) {
        guard isActive else { return }
        let context = ModelContext(container)
        try? context.delete(model: JournalData.self)
        try? context.delete(model: SubGoalData.self)

        let ko = isKorean
        let local = ko ? nil : localSample
        let walk = local?[0] ?? (ko ? "저녁에 30분 걷기" : "Walk 30 minutes after dinner")
        let wake = local?[1] ?? (ko ? "7시에 일어나기" : "Wake up at 7")
        let read = local?[2] ?? (ko ? "자기 전 책 10쪽" : "Read 10 pages before bed")
        for goal in [walk, wake, read] {
            context.insert(SubGoalData(id: UUID().uuidString, date: .now, goalText: goal))
        }

        // (며칠 전, 목표, 해냈나, 감정, 느낀 점, 다음엔)
        let records: [(Int, String, Bool, Int, String, String)] = if let t = local { [
            (0, walk, true, 4, t[3], ""),
            (1, wake, false, 2, t[4], t[5]),
            (2, walk, true, 4, t[6], ""),
            (3, read, true, 3, t[7], ""),
            (4, walk, false, 2, t[8], t[9]),
            (5, wake, true, 4, t[10], ""),
            (6, read, true, 3, t[11], ""),
        ] } else if ko { [
            (0, walk, true, 4, "비가 그쳐서 한강까지 걸었다. 걷고 나니 머리가 맑아졌다.", ""),
            (1, wake, false, 2, "알람을 끄고 다시 잠들었다. 새벽 2시까지 휴대폰을 봤다.", "11시 반에 휴대폰을 거실에 두고 오기"),
            (2, walk, true, 4, "동생이랑 같이 걸었다. 혼자일 때보다 금방 지나갔다.", ""),
            (3, read, true, 3, "10쪽만 읽으려다 한 장을 다 읽었다.", ""),
            (4, walk, false, 2, "야근하고 오니 9시. 걸을 힘이 없었다.", "늦는 날은 집 앞 한 바퀴만"),
            (5, wake, true, 4, "커튼을 열어 두고 잤더니 저절로 눈이 떠졌다.", ""),
            (6, read, true, 3, "누워서 읽으니 잠이 잘 왔다.", ""),
        ] } else { [
            (0, walk, true, 4, "The rain stopped, so I walked all the way to the river. My head feels clear.", ""),
            (1, wake, false, 2, "Turned off the alarm and fell back asleep. I was on my phone until 2 a.m.", "Leave my phone in the living room at 11:30"),
            (2, walk, true, 4, "Walked with my sister. Time flew compared to walking alone.", ""),
            (3, read, true, 3, "Meant to read 10 pages and finished a whole chapter.", ""),
            (4, walk, false, 2, "Got home at 9 after working late. No energy left to walk.", "On late days, just one lap around the block"),
            (5, wake, true, 4, "Slept with the curtains open and woke up on my own.", ""),
            (6, read, true, 3, "Reading in bed made me sleepy in a good way.", ""),
        ] }
        let calendar = Calendar.current
        for (daysAgo, goal, done, emotion, review, next) in records {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
            context.insert(JournalData(
                id: UUID().uuidString,
                date: date,
                isGoalIn: done,
                emotionValue: emotion,
                review: review,
                nextPlan: next,
                isRebounded: false,
                subGoal: goal,
                isResolved: done ? nil : false
            ))
        }
        try? context.save()
    }
}
#endif
