import Foundation

enum Achievements {
    private static func flag(_ value: Bool) -> (Double, Double) { (value ? 1 : 0, 1) }

    private static let base: [Achievement] = [
        // 집필
        Achievement(id: "first_line", title: "첫 문장", detail: "첫 글자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.quill, measure: { (min($0.totalCharacters, 1), 1) }, countable: false,
                    patronTitle: "첫 원고의 마중물"),
        Achievement(id: "chars_10k", title: "원고 1만 자", detail: "모두 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 10_000) }, chain: "chars",
                    patronTitle: "성실한 지필묵 후원자"),
        Achievement(id: "chars_100k", title: "원고 10만 자", detail: "모두 10만 자를 쓰세요", tier: .silver, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 100_000) }, chain: "chars",
                    patronTitle: "꺼지지 않는 서재의 등불"),
        Achievement(id: "chars_1m", title: "원고 100만 자", detail: "모두 100만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 1_000_000) }, chain: "chars", perk: .characters(0.05),
                    patronTitle: "대문호들의 든든한 메세나"),
        Achievement(id: "chars_5m", title: "원고 500만 자", detail: "모두 500만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 5_000_000) }, chain: "chars", perk: .characters(0.10),
                    patronTitle: "불멸의 문학사 후원자"),
        Achievement(id: "day_10k", title: "부지런한 하루", detail: "오늘 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.bolt, measure: { ($0.todayCharacters, 10_000) }, chain: "day", daily: true),
        Achievement(id: "day_100k", title: "폭풍 집필", detail: "오늘 10만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.bolt, measure: { ($0.todayCharacters, 100_000) }, chain: "day", perk: .itemTokens(0.9), daily: true),
        Achievement(id: "streak_7", title: "일주일 개근", detail: "7일 내리 하루도 빠짐없이 쓰세요", tier: .silver, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 7) }, chain: "streak",
                    patronTitle: "매일 찾아오는 후원인"),
        Achievement(id: "streak_30", title: "한 달 개근", detail: "30일 내리 하루도 빠짐없이 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 30) }, chain: "streak", perk: .eventChance(0.8),
                    patronTitle: "한결같은 문학의 벗"),
        Achievement(id: "night_10k", title: "밤의 작가", detail: "밤 10시부터 새벽 5시 사이에 모두 1만 자를 쓰세요", tier: .silver,
                    category: .writing, icon: PixelIcon.candle, measure: { (Double($0.nightCharacters), 10_000) },
                    patronTitle: "심야 집필실의 등불지기"),
        Achievement(id: "weekend_10k", title: "주말 작가", detail: "주말에 모두 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.calendar, measure: { ($0.weekendCharacters, 10_000) },
                    patronTitle: "휴일 서재의 산책 동무"),
        Achievement(id: "streak_100", title: "백일", detail: "100일 내리 하루도 빠짐없이 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 100) }, chain: "streak", perk: .eventDuration(0.75),
                    patronTitle: "백일의 서약을 지킨 후견인"),
        // 탈고
        Achievement(id: "first_book", title: "첫 탈고", detail: "작품 하나를 끝까지 쓰세요", tier: .silver, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 1) }, countable: false, chain: "books",
                    patronTitle: "초판본의 첫 후원자"),
        Achievement(id: "books_5", title: "다섯 권", detail: "작품 다섯 편을 탈고하세요", tier: .silver, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 5) }, chain: "books",
                    patronTitle: "작은 문고의 설립자"),
        Achievement(id: "books_10", title: "열 권", detail: "작품 열 편을 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 10) }, chain: "books", perk: .refusal(0.05),
                    patronTitle: "황금 서재의 관장"),
        Achievement(id: "books_25", title: "스물다섯 권", detail: "작품 스물다섯 편을 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 25) }, chain: "books", perk: .refusal(0.05),
                    patronTitle: "왕립 문학 총서의 편찬자"),
        Achievement(id: "round_1", title: "서재 완주", detail: "서재의 모든 작품을 한 바퀴 다 쓰세요", tier: .gold, category: .books,
                    icon: PixelIcon.trophy, measure: { (Double($0.completedRounds), 1) }, countable: false, chain: "rounds", perk: .itemTokens(0.9),
                    patronTitle: "전집 시대를 연 대후원자"),
        Achievement(id: "round_2", title: "두 바퀴", detail: "서재를 두 바퀴 다 쓰세요", tier: .gold, category: .books,
                    icon: PixelIcon.trophy, measure: { (Double($0.completedRounds), 2) }, countable: false, chain: "rounds", perk: .characters(0.05),
                    patronTitle: "시대를 초월한 문학의 수호자"),
        Achievement(id: "all_authors", title: "팔방미인", detail: "작가 8명의 작품을 한 편씩은 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.star, measure: { (Double($0.authorsFinished.count), 8) }, perk: .eventDuration(0.9),
                    patronTitle: "여덟 문호의 살롱 주인장"),
        // 판매
        Achievement(id: "sales_1k", title: "첫 천 부", detail: "책 한 권이 1,000부 팔리게 하세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 1_000) }, chain: "sales",
                    patronTitle: "동네 서점의 첫 투자자"),
        Achievement(id: "sales_10k", title: "재판", detail: "책 한 권이 1만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 10_000) }, chain: "sales",
                    patronTitle: "인쇄기를 돌리는 후원자"),
        Achievement(id: "sales_100k", title: "베스트셀러", detail: "책 한 권이 10만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 100_000) }, chain: "sales", perk: .itemTokens(0.95),
                    patronTitle: "런던 출판가의 큰손"),
        Achievement(id: "sales_1m", title: "밀리언셀러", detail: "책 한 권이 100만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.trophy, measure: { (Double($0.bestBookSales), 1_000_000) }, chain: "sales", perk: .characters(0.05),
                    patronTitle: "세기를 뒤흔든 출판 메세나"),
        Achievement(id: "readers_100k", title: "십만 독자", detail: "모든 책을 합쳐 10만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.pages, measure: { (Double($0.totalSales), 100_000) }, chain: "readers",
                    patronTitle: "십만 독자를 잇는 가교"),
        Achievement(id: "readers_1m", title: "백만 독자", detail: "모든 책을 합쳐 100만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.pages, measure: { (Double($0.totalSales), 1_000_000) }, chain: "readers", perk: .eventChance(0.9),
                    patronTitle: "백만 독자를 이끈 대후원자"),
        Achievement(id: "author_sales_100k", title: "인기 작가", detail: "한 작가의 책이 모두 10만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.star, measure: { (Double($0.bestAuthorSales), 100_000) },
                    patronTitle: "스타 작가를 키워 낸 후원자"),
        Achievement(id: "all_reprint", title: "전작 재판", detail: "탈고한 책이 모두 재판(1만 부)을 찍게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.book, measure: { flag($0.allReprinted) }, countable: false,
                    patronTitle: "전작 재판을 이끈 후원인"),
        Achievement(id: "ignite_3", title: "불씨", detail: "영감 게이지를 채워 영감의 날을 세 번 켜세요", tier: .silver, category: .writing,
                    icon: PixelIcon.star, measure: { (Double($0.ignitions), 3) },
                    patronTitle: "영감에 불을 지피는 후원자"),
        Achievement(id: "deadline_1", title: "마감 사수", detail: "출판사 마감을 지키세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMet), 1) }, countable: false, chain: "deadline",
                    patronTitle: "마감 시계를 챙기는 후견인"),
        Achievement(id: "deadline_5", title: "믿을 만한 작가", detail: "출판사 마감을 다섯 번 지키세요", tier: .silver, category: .writing,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMet), 5) }, chain: "deadline", perk: .refusal(0.03),
                    patronTitle: "출판계가 신뢰하는 후견인"),
        Achievement(id: "five_stars", title: "별 다섯", detail: "비평에서 별 5개를 받으세요", tier: .silver, category: .bookstore,
                    icon: PixelIcon.star, measure: { (Double($0.fiveStars), 1) }, countable: false,
                    patronTitle: "평단이 경외하는 안목의 후원자"),
        Achievement(id: "reviews_10", title: "스크랩북", detail: "비평 열 편을 모으세요", tier: .bronze, category: .bookstore,
                    icon: PixelIcon.page, measure: { (Double($0.reviews), 10) },
                    patronTitle: "문예지 스크랩북의 수집가"),
        Achievement(id: "housewarming", title: "집들이", detail: "작업실 가구를 하나 들이세요", tier: .bronze, category: .events,
                    icon: PixelIcon.lamp, measure: { (Double($0.furniture), 1) }, countable: false, chain: "studio",
                    patronTitle: "따뜻한 집필실의 마련자"),
        Achievement(id: "studio_full", title: "안락한 작업실", detail: "작업실 가구 여섯을 모두 들이세요", tier: .silver, category: .events,
                    icon: PixelIcon.lamp, measure: { (Double($0.furniture), 6) }, chain: "studio", perk: .itemTokens(0.95),
                    patronTitle: "완벽한 서재의 건축가"),
        Achievement(id: "order_1", title: "독자의 부탁", detail: "독자가 주문한 책을 기한 안에 쓰기 시작하세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.letter, measure: { (Double($0.ordersFilled), 1) }, countable: false,
                    patronTitle: "독자의 편지를 전하는 후원자"),
        Achievement(id: "shop_20", title: "단골 서점", detail: "서점에서 일어난 일을 스무 번 겪으세요", tier: .silver, category: .sales,
                    icon: PixelIcon.bag, measure: { (Double($0.shopEvents), 20) },
                    patronTitle: "거리 서점의 든든한 뒷배"),
        Achievement(id: "ads_3", title: "광고주", detail: "서점에 광고를 세 번 거세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.horn, measure: { (Double($0.ads), 3) },
                    patronTitle: "소문난 문학 선전가"),
        Achievement(id: "publishers_3", title: "출판사 세 곳", detail: "대형·문예·독립 출판사에 한 번씩 원고를 보내세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.letter, measure: { (Double($0.publishersUsed), 3) },
                    patronTitle: "출판계의 발 넓은 중개자"),
        Achievement(id: "decided", title: "결단", detail: "선택지가 있는 사건에 답하세요", tier: .bronze, category: .bookstore,
                    icon: PixelIcon.letter, measure: { (Double($0.decisions), 1) }, countable: false, chain: "decided",
                    patronTitle: "고민을 함께 나누는 조언자"),
        Achievement(id: "decided_10", title: "편집장", detail: "선택지가 있는 사건에 열 번 답하세요", tier: .silver, category: .bookstore,
                    icon: PixelIcon.letter, measure: { (Double($0.decisions), 10) }, chain: "decided", perk: .refusal(0.03),
                    patronTitle: "원고의 길을 밝히는 편집 고문"),
        Achievement(id: "reader", title: "독자", detail: "원고 읽기 창에서 지금까지 쓴 원고를 읽으세요", tier: .bronze, category: .books,
                    icon: PixelIcon.pages, measure: { (Double($0.reads), 1) }, countable: false,
                    patronTitle: "행간을 아끼는 첫 독자"),
        Achievement(id: "focus", title: "편애", detail: "서재에서 한 작가의 작품을 몰아 쓰게 하세요", tier: .bronze, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.focuses), 1) }, countable: false,
                    patronTitle: "열렬한 전담 후원자"),
        // 돌발 상황
        Achievement(id: "first_event", title: "뜻밖의 손님", detail: "돌발 상황을 처음 겪으세요", tier: .bronze, category: .events,
                    icon: PixelIcon.door, measure: { (Double($0.eventsSeen), 1) }, countable: false,
                    patronTitle: "작가의 투정을 받아 주는 이"),
        Achievement(id: "item_used", title: "임기응변", detail: "아이템으로 돌발 상황을 끝내세요", tier: .bronze, category: .events,
                    icon: PixelIcon.bell, measure: { (Double($0.itemsUsed), 1) }, countable: false,
                    patronTitle: "적재적소의 보급관"),
        Achievement(id: "coffee_10", title: "커피 열 잔", detail: "커피나 홍차로 졸음을 열 번 쫓으세요", tier: .silver, category: .events,
                    icon: PixelIcon.cup, measure: { (Double($0.coffeeUsed), 10) },
                    patronTitle: "다정한 다과 보급관"),
        Achievement(id: "patience_5", title: "기다림", detail: "아이템 없이 돌발 상황 다섯 번을 끝까지 기다리세요", tier: .silver,
                    category: .events, icon: PixelIcon.hourglass, measure: { (Double($0.waitedOut), 5) },
                    patronTitle: "과묵하고 너그러운 후원자"),
        Achievement(id: "collector", title: "수집가", detail: "여섯 가지 역할의 아이템을 한꺼번에 가지세요", tier: .silver, category: .events,
                    icon: PixelIcon.candle, measure: { flag($0.holdsEveryItem) }, countable: false,
                    patronTitle: "만물상 창고지기 후원자"),
        Achievement(id: "exchange_5", title: "교환상", detail: "아이템을 다섯 번 바꾸세요", tier: .bronze, category: .events,
                    icon: PixelIcon.horn, measure: { (Double($0.exchanges), 5) },
                    patronTitle: "알뜰한 보급품 조달자"),
        Achievement(id: "persistence_3", title: "끈기", detail: "거절당한 뒤 다시 권해 세 번 통하세요", tier: .silver, category: .events,
                    icon: PixelIcon.hourglass, measure: { (Double($0.persistence), 3) },
                    patronTitle: "작가의 고집을 꺾는 설득가"),
        Achievement(id: "guests_3", title: "손님 많은 집", detail: "손님 작가를 세 번 맞으세요", tier: .silver, category: .events,
                    icon: PixelIcon.door, measure: { (Double($0.guests), 3) },
                    patronTitle: "문인들의 사랑방 주인"),
        Achievement(id: "advance_3", title: "선금의 맛", detail: "출판사 선금을 세 번 받으세요", tier: .bronze, category: .events,
                    icon: PixelIcon.coin, measure: { (Double($0.advances), 3) },
                    patronTitle: "통 큰 선금 집행자"),
        // 자연재해
        Achievement(id: "survivor", title: "재해 생존", detail: "자연재해를 겪고도 계속 쓰세요", tier: .bronze, category: .disasters,
                    icon: PixelIcon.flame, measure: { (Double($0.disasters), 1) }, countable: false, chain: "disasters",
                    patronTitle: "원고 뭉치를 건져 낸 은인"),
        Achievement(id: "disasters_5", title: "불굴", detail: "자연재해를 다섯 번 겪으세요", tier: .gold, category: .disasters,
                    icon: PixelIcon.flame, measure: { (Double($0.disasters), 5) }, chain: "disasters", perk: .disasterLoss(0.5),
                    patronTitle: "폭풍우를 막아 서는 방패"),
        Achievement(id: "lost_10k", title: "잿더미에서", detail: "자연재해로 모두 1만 자를 잃고도 쓰세요", tier: .silver, category: .disasters,
                    icon: PixelIcon.wind, measure: { (Double($0.lostCharacters), 10_000) },
                    patronTitle: "잿더미 속 원고의 복원자"),
        Achievement(id: "shield_1", title: "대비", detail: "금고나 사본으로 자연재해를 한 번 막으세요", tier: .silver, category: .disasters,
                    icon: PixelIcon.safe, measure: { (Double($0.shieldBlocks), 1) }, countable: false,
                    patronTitle: "철통같은 원고 금고지기"),
        // 토큰
        Achievement(id: "tokens_100m", title: "1억 토큰의 날", detail: "오늘 토큰 1억 개를 쓰세요", tier: .silver, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 100_000_000) }, chain: "tokens", daily: true),
        Achievement(id: "tokens_500m", title: "5억 토큰의 날", detail: "오늘 토큰 5억 개를 쓰세요", tier: .gold, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 500_000_000) }, chain: "tokens", perk: .refusalWait(0.5), daily: true),
        Achievement(id: "tokens_1b", title: "10억 토큰의 날", detail: "오늘 토큰 10억 개를 쓰세요", tier: .gold, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 1_000_000_000) }, chain: "tokens", perk: .itemTokens(0.9), daily: true),
        // 비밀. 이루기 전에는 가린다.
        Achievement(id: "owl", title: "올빼미", detail: "새벽 0~4시에 돌발 상황을 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.candle, measure: { (Double($0.nightEvents), 1) }, countable: false,
                    patronTitle: "새벽녘 촛불을 켜 두는 이"),
        Achievement(id: "busy_day", title: "다사다난", detail: "하루에 돌발 상황을 세 번 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.bell, measure: { (Double($0.mostEventsInDay), 3) }, countable: false,
                    patronTitle: "소란스러운 작업실의 중재자"),
        Achievement(id: "hoard", title: "비축", detail: "커피와 홍차를 다섯 잔 쌓아 두세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.cup, measure: { (Double($0.coffeeHeld), 5) }, countable: false,
                    patronTitle: "찻잎과 원두의 비축가"),
        Achievement(id: "lucky", title: "행운아", detail: "행운을 다섯 번 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.lucks), 5) }, countable: false,
                    patronTitle: "행운을 불러오는 복덩이 후원자"),
        Achievement(id: "caught", title: "들켰다", detail: "농땡이 부리는 작가를 열 번 들키게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.door, measure: { (Double($0.caught), 10) }, countable: false,
                    patronTitle: "발소리 없이 다가오는 감독관"),
        Achievement(id: "veteran", title: "산전수전", detail: "돌발 상황을 스무 번 겪으세요", tier: .gold, category: .secret,
                    icon: PixelIcon.door, measure: { (Double($0.eventsSeen), 20) }, countable: false, perk: .eventChance(0.9),
                    patronTitle: "괴짜 문호들의 노련한 후견인"),
        Achievement(id: "missed_3", title: "펑크", detail: "출판사 마감을 세 번 어기세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMissed), 3) }, countable: false,
                    patronTitle: "마감 독촉장을 대신 받는 이"),
        Achievement(id: "caffeine", title: "카페인", detail: "하루에 커피·홍차를 일곱 잔 권하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.cup, measure: { (Double($0.mostCupsInDay), 7) }, countable: false,
                    patronTitle: "잠 못 드는 밤의 카페인 공급자"),
        Achievement(id: "gambler", title: "도박사", detail: "손님 작가와의 내기에서 세 번 이기세요", tier: .silver, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.betsWon), 3) }, countable: false,
                    patronTitle: "승부사 기질의 후원자"),
        Achievement(id: "busted", title: "쪽박", detail: "손님 작가와의 내기에서 세 번 지세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.betsLost), 3) }, countable: false,
                    patronTitle: "수업료를 아끼지 않는 후원자"),
        Achievement(id: "panned", title: "혹평", detail: "쓰는 중인 작가가 별 2개 이하 비평을 받게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.page, measure: { (Double($0.panned), 1) }, countable: false,
                    patronTitle: "혹평에도 흔들리지 않는 버팀목"),
        Achievement(id: "quarrels_5", title: "앙숙", detail: "손님 작가와 다섯 번 말다툼하게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.horn, measure: { (Double($0.quarrels), 5) }, countable: false,
                    patronTitle: "문호들의 말다툼 구경꾼"),
        Achievement(id: "poked", title: "참견", detail: "상시 창의 초상화를 서른 번 누르세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.bell, measure: { (Double($0.taps), 30) }, countable: false,
                    patronTitle: "작가의 어깨를 두드리는 후원자"),
    ]

    private static let authorPatronTitles: [String: String] = [
        "Shakespeare": "스트랫퍼드 극단의 후원 귀족",
        "Dickens": "런던 연재소설의 큰손",
        "Poe": "볼티모어 심야 서재의 후견인",
        "Carroll": "옥스퍼드 정원의 다과 후원자",
        "Doyle": "베이커가 221B의 단골 의뢰인",
        "Stevenson": "보물섬 항해의 투자자",
        "Austen": "햄프셔 응접실의 후견인",
        "Goethe": "바이마르 궁정의 문학 벗",
        "Wilde": "런던 사교계의 탐미 후원자",
    ]

    /// 작가마다 전집 하나. 메달에는 그 작가의 초상화가 들어간다.
    @MainActor
    private static func authorBadges() -> [Achievement] {
        Library.authors.map { author in
            let koFull = Library.books.first { $0.authorShort == author }?.authorKo ?? author
            let name = koFull.split(separator: " ").last.map(String.init) ?? koFull
            return Achievement(id: "author_\(author)", title: "\(name) 전집", detail: "\(name)의 작품을 한 회차 안에 모두 탈고하세요",
                               tier: .gold, category: .books, icon: PixelIcon.star,
                               measure: { flag($0.completedAuthors.contains(author)) }, countable: false, portrait: author,
                               perk: .authorEventDuration(author, 0.85),
                               patronTitle: authorPatronTitles[author] ?? "\(name) 전집의 후견인")
        }
    }

    @MainActor
    static let all: [Achievement] = {
        var list = base
        let insertAt = list.firstIndex { $0.id == "round_1" }.map { $0 + 1 } ?? list.count
        list.insert(contentsOf: authorBadges(), at: insertAt)
        return list
    }()

    @MainActor
    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }

    /// 미해금 비밀 성과에 마우스를 올렸을 때 보여 주는 은유적 단서.
    static func secretClue(for id: String) -> String {
        L10n.tr({ switch id {
        case "owl": "모두가 잠든 깊은 새벽녘, 작업실에 뜻밖의 소란이 찾아올 때가 있습니다."
        case "busy_day": "유난히 바람 잘 날 없는 하루가 있습니다."
        case "hoard": "찬장에 따뜻한 차와 커피를 아껴 두고 내어주지 않으면..."
        case "lucky": "문호의 책상 위에 우연한 행운이 거듭 내려앉을 때."
        case "caught": "창을 갑자기 열어젖히면 딴청 피우던 작가와 눈이 마주치곤 합니다."
        case "veteran": "수많은 소동과 변덕을 겪고 나면 어떤 일에도 놀라지 않게 됩니다."
        case "missed_3": "출판사 편집자의 재촉 편지가 여러 번 빈손으로 돌아갈 때."
        case "caffeine": "하루 동안 찻잔이 쉴 새 없이 작업실을 오갈 때."
        case "gambler": "찾아온 손님 작가와의 내기에서 연거푸 웃는 날이 있습니다."
        case "busted": "찾아온 손님 작가와의 내기에서 연거푸 빈주머니가 될 때도 있습니다."
        case "panned": "평론가의 펜끝이 유난히 매섭고 박한 날이 있습니다."
        case "quarrels_5": "작업실을 찾은 두 문호의 언성이 거듭 높아질 때."
        case "poked": "바탕화면 상시 창의 작가를 자꾸만 건드려 보면..."
        default: "집필실을 지켜보다 보면 우연히 마주치게 됩니다."
        } }())
    }

    /// 매일 초기화되는 성과.
    @MainActor
    static var dailies: [Achievement] { all.filter(\.daily) }

    /// 해금된 후원자 칭호가 담긴 성과 목록(높은 등급 우선).
    @MainActor
    static func unlockedPatronAchievements(earned: (Achievement) -> Bool) -> [Achievement] {
        all.filter { !$0.daily && $0.patronTitle != nil && earned($0) }
            .sorted { a, b in
                if a.tier.rawValue != b.tier.rawValue { return a.tier.rawValue > b.tier.rawValue }
                return false
            }
    }

    /// 아직 못 받은 것 가운데 보여 줄 것(매일 성과는 뺀다). 단계 묶음은 다음 단계 하나만.
    @MainActor
    static func nextGoals(earned: (Achievement) -> Bool) -> [Achievement] {
        var seenChains: Set<String> = []
        return all.filter { a in
            guard !a.daily, !earned(a) else { return false }
            guard let chain = a.chain else { return true }
            return seenChains.insert(chain).inserted
        }
    }
}

/// 달성한 성과 하나.
struct BadgeRecord: Codable, Sendable, Equatable {
    let date: Date
    var notified: Bool
    /// 보상으로 받은 아이템(`ItemKind.rawValue`). 처음 조용히 채운 것은 없다.
    var reward: [String]?
    /// 매일 성과: 지금까지 이룬 날수와 연속 일수.
    var count: Int?
    var streak: Int?
}
