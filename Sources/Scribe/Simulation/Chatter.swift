import Foundation

// 작가가 하는 말. 초상화를 눌렀을 때(`Chatter`), 손님 작가와 말다툼할 때(`Quarrels`), 서점의 문단 소식(`Gossip`).

/// 초상화를 눌렀을 때 하는 말. 상황(돌발 상황·사건·비평·기분·시각·진행)에 맞는 말과 작가다운 말을 섞는다.
@MainActor
enum Chatter {
    static let generic = [
        "지금 쓰는 중입니다", "네?", "펜을 놓지 않았습니다", "한 줄만 더 쓰고요", "잉크가 아직 남았습니다",
        "오늘 분량은 채울 겁니다", "무슨 일이십니까", "종이가 모자라진 않습니다", "읽어 보시겠습니까. 아직은 아닙니다",
        "커피가 식었습니다", "창문 좀 열어 주시겠습니까", "이 문장이 잘 안 풀립니다", "조금만 조용히", "손이 안 보이시나요. 바쁩니다",
        "「{T}」의 이 대목은 꽤 마음에 듭니다", "{T}(은|는) 생각보다 손이 많이 가는 작품입니다",
        "방금 쓴 문장은 지우지 않을 생각입니다", "압지를 대고 잉크가 마르기를 기다리는 중입니다",
        "펜촉 끝이 종이에 스치는 소리가 좋지 않습니까", "지금 이 호흡을 놓치면 안 됩니다",
    ]
    static let byAuthor: [String: [String]] = [
        "Shakespeare": [
            "배우들이 대사를 또 틀렸습니다", "극장은 늘 돈이 모자랍니다", "운율이 안 맞으면 밤에 잠이 안 옵니다",
            "5막이 제일 어렵습니다", "여왕께서 보신답니다. 고쳐야겠군요", "펜은 칼보다 느립니다",
            "「{T}」의 독백은 무대 한가운데서 읊어야 제맛입니다", "약강 오보격의 박자가 한 음절 모자라는군요",
            "글로브 극장의 선 채로 보는 관객들도 이 장면에서는 숨을 죽일 겁니다", "비극과 희극은 종이 한 장 차이입니다",
            "광대의 입을 빌려야 진짜 진실을 말할 수 있지요", "소네트 열네 줄 안에 우주를 담는 게 더 쉽겠습니다",
            "왕관의 무게는 잉크로 달아 봐야 아는 법입니다", "무대 뒤에서 들리는 발소리가 대사보다 급하군요"
        ],
        "Dickens": [
            "마감이 내일입니다. 늘 그렇듯", "런던은 안개가 걷히질 않습니다", "이번 장에서 또 누가 죽어야 합니다",
            "독자가 편지로 결말을 바꾸라 합니다", "신문사는 글자 수로 돈을 줍니다", "거리의 아이들이 이야기를 줍니다",
            "「{T}」의 다음 연재분을 기다리는 독자들이 인쇄소 앞에 줄을 섰답니다", "법원 서기 시절에 본 얼굴들이 아직도 원고지 위로 걸어 나옵니다",
            "붉은 제라늄 화분을 책상 앞에 두어야 문장이 잘 풀립니다", "등장인물 이름을 짓는 데만 반나절을 썼습니다",
            "런던의 밤거리를 스무 마일쯤 걸어야 이 장의 결말이 보일 것 같습니다", "가난한 사람들의 식탁일수록 따뜻하게 묘사해야 합니다",
            "연재소설은 마지막 줄에서 독자의 숨을 멈추게 해야지요", "구두약 공장의 냄새는 평생 잉크로도 지워지지 않습니다"
        ],
        "Poe": [
            "까마귀가 또 왔습니다", "밤이 더 조용합니다", "심장 소리가 들리지 않습니까",
            "운율은 어둠에서 옵니다", "이 집은 어딘가 기울어 있습니다", "술은 아닙니다. 잉크입니다",
            "「{T}」의 첫 문장부터 단 하나의 인상으로 독자를 몰아넣어야 합니다", "단편은 한 번에 읽혀야 합니다. 끊기면 마법이 깨집니다",
            "아름다움의 가장 높은 경지는 늘 슬픔과 맞닿아 있지요", "암호문 하나를 풀듯 문장의 구조를 맞추고 있습니다",
            "촛불이 흔들릴 때마다 벽지의 무늬가 살아 움직이는 듯합니다", "이성적인 추리와 광기는 같은 방의 양쪽 창문입니다",
            "마루 밑에서 시계 초침보다 빠른 소리가 들리지 않습니까", "검은 고양이가 원고지 가장자리를 밟고 지나갔습니다"
        ],
        "Carroll": [
            "토끼가 시계를 보고 갔습니다", "수수께끼 하나 내 볼까요", "차 모임은 여섯 시입니다. 늘",
            "말은 뜻보다 소리가 먼저입니다", "거울 저쪽은 글씨가 뒤집혀 있습니다", "논리도 놀이입니다",
            "「{T}」에는 삼단논법으로 풀 수 없는 문장을 하나 숨겨 두었습니다", "제자리에서 있으려면 온 힘을 다해 달려야 합니다",
            "보라색 잉크가 다 떨어져서 검은 잉크로 쓰는 중입니다", "까마귀와 책상이 왜 닮았는지 아직도 묻는 사람이 있습니다",
            "단어 두 개를 하나로 합치면 뜻도 두 배가 됩니다", "옥스퍼드의 종소리가 울리기 전에 이 장을 끝내야 합니다",
            "체스판 위의 나이트처럼 한 칸 옆으로 건너뛰는 문장입니다", "어른들은 설명해 주지 않으면 농담을 이해하지 못합니다"
        ],
        "Stevenson": [
            "바람이 바뀌었습니다", "지도부터 그려야 이야기가 됩니다", "기침이 좀 납니다. 괜찮습니다",
            "바다가 종이 위로 들어옵니다", "보물은 늘 마지막 장에", "짐을 쌀까 하다 말았습니다",
            "「{T}」의 배경이 될 해안선을 붉은 잉크로 먼저 그려 두었습니다", "인간의 마음속에는 늘 두 사람이 한 몸을 두고 다툽니다",
            "남태평양의 따뜻한 무역풍이 창문 틈으로 불어오면 좋겠군요", "에든버러의 가스등 불빛과 바다의 폭풍우가 동시에 떠오릅니다",
            "모험담에는 쓸데없는 수식어보다 팽팽한 밧줄 소리가 필요합니다", "당나귀 한 마리와 침낭만 있으면 어디든 여행기가 됩니다",
            "담요를 무릎에 덮고서도 머릿속은 갑판 위를 달리고 있습니다", "나침반 바늘이 가리키는 쪽으로 다음 장을 몰고 갑니다"
        ],
        "Wilde": [
            "침묵도 재치가 있다면 좋겠군요", "카네이션이 시들기 전에 끝내겠습니다", "인용될 말을 쓰는 중입니다",
            "진지한 건 제 취향이 아닙니다", "살롱에 늦었습니다. 글이 먼저지만", "두 번 읽을 가치가 있는 문장만 남깁니다",
            "「{T}」에서 가장 도덕적인 인물이 가장 지루하게 말하도록 고치는 중입니다", "오전 내내 쉼표 하나를 넣었다가 오후 내내 다시 뺐습니다",
            "자연은 언제나 예술을 모방하려 애쓰지요", "유혹을 이기는 유일한 방법은 유혹에 굴복하는 것입니다",
            "사람들은 자기 얼굴로 말할 때보다 가면을 썼을 때 진실을 말합니다", "비평가들이 논란을 벌인다면 그 책은 이미 성공한 셈입니다",
            "차 한 잔의 온도보다 문장의 리듬이 더 중요합니다", "평범한 진실보다 아름다운 역설이 오래 남습니다"
        ],
        "Austen": [
            "차를 한 잔 더 우렸습니다", "이웃이 또 혼담을 가져왔습니다", "응접실 문을 닫고 씁니다",
            "비 오는 날이 글에는 낫습니다", "편지를 쓰듯 씁니다", "결혼은 소설 끝에서만",
            "「{T}」의 두 사람은 아직 서로의 진심을 모른 척하고 있습니다", "시골 마을의 서너 가족만 있으면 소설 한 편을 쓰기에 충분합니다",
            "두 치 남짓한 상아 조각에 세밀화를 그리듯 문장을 다듬고 있습니다", "복도에서 발소리가 들리면 압지 밑에 원고를 감추곤 합니다",
            "무도회장의 대화 한 줄에 가문의 체면과 속내가 다 들어 있지요", "너무 완벽한 여주인공은 저부터가 정이 가지 않습니다",
            "찻잔을 내려놓는 타이밍 하나로도 거절의 뜻을 전할 수 있습니다", "언니 카산드라에게 방금 쓴 대목을 먼저 읽어 주었습니다"
        ],
        "Goethe": [
            "잎 하나에도 법칙이 있습니다", "색은 빛과 어둠 사이에서 납니다", "광물 상자를 정리하다 왔습니다",
            "이탈리아가 그립습니다", "2부는 평생 걸릴지도 모릅니다", "시도 학문입니다",
            "「{T}」의 이 장은 젊은 날의 열정과 노년의 절제를 함께 담아야 합니다", "서두르지 않되 쉬지도 않고, 별처럼 제 궤도를 돌며 씁니다",
            "인간은 노력하는 한 방황하기 마련입니다", "아침 햇살이 서재 창문을 비출 때가 가장 정신이 맑습니다",
            "바이마르의 정원 산책에서 얻은 생각을 운율로 옮기는 중입니다", "프리즘을 통과한 빛의 경계처럼 미묘한 감정을 포착해야 합니다",
            "고전이란 건강하고 낭만이란 병적인 것이라고 적어 두었습니다", "식물의 잎이 꽃잎으로 변하듯 첫 구상이 장대한 극시로 자라납니다"
        ],
    ]
    static let poked = [
        "그만 찌르세요", "원고에 손자국이 납니다", "펜이 흔들립니다", "세 번째입니다",
        "눈치챘습니다. 그만", "간지럽습니다", "저도 할 일이 있습니다", "이러면 한 줄도 못 씁니다",
        "자꾸 건드리시면 잉크가 튐니다", "집중력이 깨지잖습니까", "독촉하셔도 손은 더 빨라지지 않습니다", "원고지가 구겨집니다"
    ]
    static let byEvent: [String: [String]] = [
        "nap": ["……", "(코 고는 소리)", "음냐…", "……오 분만……", "(원고지를 베개 삼아 곤히 자고 있습니다)", "……그 문장은 내일 고치겠소……"],
        "ink": ["잉크가 없습니다. 보시다시피", "마른 펜으로는 못 씁니다", "잉크병이 비었다니까요", "바닥에 남은 한 방울까지 다 긁어 썼습니다", "연필이라도 주시든지요"],
        "away": ["(빈 의자가 삐걱입니다)", "(아무도 없습니다)", "(창문이 열려 있습니다)", "(책상 위에 내려놓은 펜만 덩그러니 놓여 있습니다)"],
        "walk": ["(코트가 없습니다)", "(발자국만 남았습니다)", "(모자걸이가 비어 있습니다)", "(산책용 지팡이를 챙겨 나갔습니다)"],
        "block": ["안 떠오릅니다", "한 글자도 안 나옵니다", "말 걸지 마세요. 아니, 걸어 주세요", "머리가 하얗습니다", "바닥에 구겨 던진 종이만 늘어 갑니다", "첫 줄에서 한 시간째 멈춰 있습니다"],
        "letter": ["편지를 다 읽고요", "답장을 써야 합니다", "이 편지는 좀 깁니다", "봉투에 밀랍 인장만 찍으면 끝납니다", "독촉장에는 정중하게 답해야 합니다"],
        "dark": ["초가 꺼졌습니다", "어둡습니다", "불 좀", "손이 안 보입니다", "성냥이 어디 갔는지 모르겠습니다", "어둠 속에서는 행간이 보이지 않습니다"],
        "exhausted": ["……조금만 누워 있겠습니다", "손가락 하나 까딱할 힘이 없습니다", "(긴 의자에서 깊은 숨만 내쉬고 있습니다)", "체력이 돌아오면 다시 앉겠습니다"],
        "author.Shakespeare": ["(글로브 극장 리허설에 불려 갔습니다)", "(대본 뭉치를 옆구리에 끼고 극장으로 나갔습니다)", "(무대 감독과 3막 동선을 맞추러 갔습니다)"],
        "author.Dickens": ["(런던의 밤안개 속을 걸으러 나갔습니다)", "(지팡이를 짚고 템스강 변으로 나갔습니다)", "(가로등 켜진 골목길을 순찰하듯 걷고 있습니다)"],
        "author.Poe": ["저 까마귀가 '네버모어'라고 하지 않았습니까", "흉상 위의 검은 눈동자에서 시선을 뗄 수 없습니다", "쉿, 날갯짓 소리가 들립니다"],
        "author.Carroll": ["(리델 가의 아이들에게 동화를 들려주러 갔습니다)", "(강가 뱃놀이에서 수수께끼를 내고 있습니다)", "(차 모임 자리에서 이야기를 이어 가는 중입니다)"],
        "author.Stevenson": ["수평선 너머로 돛단배가 지나갑니다", "파도 소리가 들리는 듯합니다. 잠시만요", "지도 위의 섬 이름을 고르는 중입니다"],
        "author.Wilde": ["(살롱 만찬장에서 경구를 뽐내고 있습니다)", "(옷깃에 카네이션을 꽂고 사교계로 나갔습니다)", "(샴페인 잔을 들고 청중을 웃기는 중입니다)"],
        "author.Austen": ["(응접실에서 이웃 부인들에게 차를 대접하고 있습니다)", "(원고를 압지 밑에 숨기고 손님을 맞으러 나갔습니다)", "(무도회 소식을 들으며 조용히 미소 짓고 있습니다)"],
        "author.Goethe": ["(정원에서 새싹과 잎의 변형을 관찰 중입니다)", "(온실에서 식물 표본을 스케치하고 있습니다)", "(광물 표본 상자를 들고 정원으로 나갔습니다)"],
    ]
    static let waiting = [
        "쓸 걸 주셔야 쓰지요", "기다리는 중입니다", "토큰이 안 옵니다", "펜을 들고 있습니다. 보이시죠",
        "종이만 하얗게 펼쳐 두고 기다리고 있습니다", "펜촉에 묻은 잉크가 마르기 전에 일감을 주시지요", "손가락으로 책상 모서리만 두드리고 있습니다"
    ]
    static let alone = [
        "계셨군요", "혼자 잘 쓰고 있었습니다", "돌아오셨군요. 몇 장 늘었습니다",
        "자리를 비우신 동안 「{T}」의 까다로운 대목을 넘겼습니다", "조용해서 오히려 진도가 제법 나갔습니다"
    ]
    static let slacking = [
        "아, 네. 쓰고 있었습니다", "기지개만 켠 겁니다", "창밖에 뭐가 있어서요", "종이비행기는 제 것이 아닙니다",
        "구상을 하느라 눈을 감고 있었을 뿐입니다", "여백의 낙서는 펜촉이 잘 나오나 시험해 본 겁니다"
    ]
    static let dawn = [
        "새벽입니다. 주무시지요", "아직 안 주무셨습니까", "새벽 글은 아침에 읽으면 부끄럽습니다",
        "창밖이 푸르스름하게 밝아 옵니다", "새벽 공기가 차갑습니다. 커피가 한 잔 생각나는군요"
    ]
    static let night = [
        "밤이 깊었습니다", "촛불이 하나 남았습니다", "밤에 쓴 글은 아침에 고칩니다",
        "모두 잠든 시간이라 펜 소리만 또렷이 들립니다", "밤이 깊을수록 문장은 더 솔직해집니다"
    ]
    static let nearlyDone = [
        "마지막 장입니다. 조용히", "거의 다 왔습니다", "끝이 보입니다", "탈고가 코앞입니다. 숨 쉬지 마세요",
        "「{T}」의 대단원이 몇 줄 남지 않았습니다", "마지막 마침표를 찍을 자리가 눈앞에 보입니다"
    ]
    static let justStarted = [
        "첫 장은 늘 어렵습니다", "이제 막 시작했습니다", "첫 문장을 세 번 고쳤습니다",
        "「{T}」의 첫 장을 열었습니다. 갈 길이 멉니다", "백지 위에 첫 줄을 그을 때가 가장 설레고 두렵습니다"
    ]
    static let noItems = [
        "가방이 비었군요. 커피라도", "아이템이 없으면 제가 고생합니다", "커피 한 잔이면 더 쓸 텐데요",
        "찬장도 서랍도 텅 비었습니다. 비상용 잉크라도 구해 두시지요"
    ]
    static let fullBag = [
        "가방이 무겁습니다", "커피를 그렇게 쌓아 두면 식습니다", "아이템을 좀 쓰시지요",
        "선반에 물건이 가득하니 마음은 든든하군요"
    ]
    static let pendingDilemma = [
        "답을 기다리고 있습니다. 편지가 왔잖습니까", "결정은 당신 몫입니다", "제 뜻은 묻지 마세요. 아니, 물어 주세요",
        "책상 위 사안을 결정해 주셔야 마음 편히 원고에 집중합니다"
    ]
    static let praised = [
        "신문 보셨습니까", "비평가도 가끔 옳습니다", "오늘은 기분이 좋습니다",
        "호평이 실린 신문을 은근슬쩍 책상 맨 위에 올려 두었습니다", "독자들이 알아봐 주니 펜 끝이 한결 가볍습니다"
    ]
    static let panned = [
        "신문 얘기는 꺼내지 마세요", "그 비평가는 책을 안 읽습니다", "오늘은 말을 걸지 마세요",
        "혹평 따위에 흔들릴 줄 아십니까. 다음 작품으로 보여 주겠습니다", "비평가는 원래 남의 글에 흠집 내는 게 직업입니다"
    ]
    static let guest = [
        "손님이 와 있습니다. 조용히", "둘이 쓰니 두 배로 시끄럽습니다", "손님 커피까지 제가 타야 합니까",
        "옆자리에서 펜 굴리는 소리가 신경 쓰여 더 빨리 쓰는 중입니다"
    ]
    static let tired = [
        "어깨가 돌처럼 굳었습니다. 조금 지치는군요", "눈꺼풀이 무거워 글자가 두 개로 겹쳐 보입니다",
        "체력이 바닥나기 전에 차나 커피 한 잔이 간절합니다"
    ]
    static let caffeinated = [
        "커피를 너무 마셨더니 손끝이 미세하게 떨립니다", "심장이 빠르게 뛰고 문장도 덩달아 빨라집니다",
        "오늘은 잠이 다 달아났습니다. 밤새도록 쓸 기세입니다"
    ]
    static let byWeather: [Weather: [String]] = [
        .rain: ["창밖 빗소리가 펜촉 소리와 박자를 맞춥니다", "비 오는 날엔 잉크가 조금 더디게 마릅니다", "처마 끝에 떨어지는 빗방울 소리가 서재를 채웁니다"],
        .snow: ["창밖으로 눈이 소복이 쌓이고 있습니다. 세상이 조용하군요", "눈빛이 반사되어 낮에도 서재 안이 환합니다", "벽난로에 장작을 하나 더 넣어야겠습니다"],
        .storm: ["비바람에 창틀이 덜컹거립니다. 원고가 날아가지 않게 문진을 올려 두었습니다", "천둥소리가 울릴 때마다 촛불이 크게 흔들립니다"],
        .fog: ["창밖이 자욱한 안개에 잠겨 맞은편 지붕도 보이지 않습니다", "안개 낀 날에는 기억 속의 장면들이 오히려 선명해집니다"],
        .heat: ["더위 때문에 이마에 맺힌 땀을 닦으며 쓰고 있습니다", "부채질을 해 가며 잉크를 말리는 중입니다"],
        .cloudy: ["구름이 낮게 깔려 낮인데도 등잔을 가까이 두었습니다", "흐린 날의 차분한 그늘이 원고지 위에 내려앉습니다"],
        .clear: ["창문 너머로 볕이 잘 들어 잉크가 빠르게 마릅니다", "맑은 날씨가 아깝지만 오늘은 이 장을 마쳐야 합니다"],
    ]

    /// 상황에 맞는 말 하나. `pokes` 는 몇 초 안에 연달아 누른 횟수. `rolls` 는 0..<1 두 개.
    static func line(author: String, progress: WritingProgress, mood: Mood, now: Date, pokes: Int, rolls: (Double, Double)) -> String {
        let title = progress.book?.displayTitle ?? "원고"
        func format(_ s: String) -> String {
            Format.resolve(s.replacingOccurrences(of: "{T}", with: title))
        }
        func pick(_ pool: [String], _ roll: Double) -> String {
            format(pool[min(pool.count - 1, Int(roll * Double(pool.count)))])
        }
        if pokes >= 3 { return pick(poked, rolls.0) }
        var situational: [String] = []
        if let event = progress.event {
            situational += byEvent[event.id] ?? byEvent["away"]!
            // 돌발 상황 중에는 그 말만 한다.
            return pick(situational, rolls.0)
        }
        if progress.dilemma != nil { situational += pendingDilemma }
        if let review = progress.reviews.first, now.timeIntervalSince(review.date) < 86_400, review.affected == true {
            situational += review.stars >= 4 ? praised : review.stars <= 2 ? panned : []
        }
        switch mood {
        case .waiting: situational += waiting
        case .alone: situational += alone
        case .slacking: situational += slacking
        default: break
        }
        if progress.guestAuthor != nil { situational += guest }
        if progress.tired { situational += tired }
        if progress.caffeinated { situational += caffeinated }
        if let wLines = byWeather[progress.weather] { situational += wLines }
        switch DayPart.current(now) {
        case .dawn: situational += dawn
        case .night: situational += night
        default: break
        }
        if progress.fraction >= 0.9 { situational += nearlyDone } else if progress.fraction < 0.03 { situational += justStarted }
        let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
        if items == 0 { situational += noItems } else if items >= 20 { situational += fullBag }
        let flavor = (byAuthor[author] ?? []) + generic
        // 상황에 맞는 말이 있으면 열에 일곱은 그것을, 나머지는 작가다운 말을.
        if !situational.isEmpty, rolls.1 < 0.7 { return pick(situational, rolls.0) }
        return pick(flavor, rolls.0)
    }
}

/// 손님 작가와의 말다툼. 둘이 한 마디씩 주고받는다. 둘의 조합에 맞는 말이 있으면 그것을, 없으면 이름을 넣는 말을.
@MainActor
enum Quarrels {
    struct Exchange: Sendable {
        let a: String
        let b: String
        let aLine: String
        let bLine: String
    }

    /// 특정한 둘 사이의 말. 순서는 상관없다(바뀌면 줄도 바꾼다).
    static let pairs: [Exchange] = [
        Exchange(a: "Shakespeare", b: "Wilde", aLine: "그 경구는 내 대사에서 가져간 것 아니오", bLine: "빌린 게 아니라 고쳐 쓴 겁니다. 훨씬 낫게"),
        Exchange(a: "Shakespeare", b: "Wilde", aLine: "희극은 웃기면 되는 게 아니오", bLine: "그래서 당신 희극은 안 웃긴 겁니까"),
        Exchange(a: "Poe", b: "Carroll", aLine: "까마귀는 '다시는'이라고 했소", bLine: "제 까마귀는 책상과 닮은 점을 묻던데요"),
        Exchange(a: "Poe", b: "Carroll", aLine: "운율이 너무 가볍소", bLine: "무거운 운율은 가라앉습니다"),
        Exchange(a: "Dickens", b: "Austen", aLine: "응접실에서 무슨 소설이 나오겠소", bLine: "거리에서 쓴 소설은 늘 길더군요"),
        Exchange(a: "Dickens", b: "Austen", aLine: "연재는 독자를 기다리게 하는 기술이오", bLine: "기다리게 하는 건 신랑감으로 충분합니다"),
        Exchange(a: "Goethe", b: "Shakespeare", aLine: "당신 작품은 번역하면서 많이 고쳤소", bLine: "독일어로도 운율이 남았기를"),
        Exchange(a: "Goethe", b: "Poe", aLine: "어둠도 빛이 있어야 보이는 법이오", bLine: "빛은 어둠을 모릅니다"),
        Exchange(a: "Stevenson", b: "Poe", aLine: "보물은 땅에 묻는 거요", bLine: "저는 심장을 마루 밑에 묻습니다"),
        Exchange(a: "Stevenson", b: "Dickens", aLine: "배 타 본 적은 있소", bLine: "템스강이면 충분하오"),
        Exchange(a: "Wilde", b: "Austen", aLine: "결혼은 상상력의 패배입니다", bLine: "결혼 안 한 사람이 늘 그렇게 말하더군요"),
        Exchange(a: "Wilde", b: "Dickens", aLine: "가난을 그렇게 길게 쓸 일입니까", bLine: "가난은 원래 길게 가오"),
        Exchange(a: "Carroll", b: "Austen", aLine: "차 모임에 초대해도 될까요", bLine: "여섯 시에 멈춘 시계라면 사양합니다"),
        Exchange(a: "Goethe", b: "Wilde", aLine: "젊은이, 색채론은 읽었소", bLine: "빛은 안 읽어도 압니다. 전 늘 빛 쪽에 섭니다"),
        Exchange(a: "Stevenson", b: "Carroll", aLine: "지도 없이 이야기를 쓴다고", bLine: "지도는 땅 크기로 그리면 됩니다. 땅 위에 펼치고"),
        Exchange(a: "Goethe", b: "Dickens", aLine: "장편에도 형식이 있어야 하오", bLine: "마감이 형식이오"),
        Exchange(a: "Shakespeare", b: "Dickens", aLine: "등장인물이 너무 많아 무대가 무너지겠소", bLine: "런던 거리는 당신 극장보다 넓소"),
        Exchange(a: "Shakespeare", b: "Poe", aLine: "유령은 1막에 나와야 극이 사는 법이오", bLine: "진짜 공포는 유령 없이도 마루 밑에서 울리는 법이오"),
        Exchange(a: "Shakespeare", b: "Carroll", aLine: "광대의 말장난을 동화로 옮겨 놓았더군", bLine: "왕과 여왕을 체스판 위에 세웠을 뿐입니다"),
        Exchange(a: "Shakespeare", b: "Stevenson", aLine: "보물섬에도 프로스페로 같은 마법사가 있소?", bLine: "마법 대신 럼주와 외다리 선원이 있소"),
        Exchange(a: "Shakespeare", b: "Austen", aLine: "당신 소설엔 칼싸움 한 번이 없더군", bLine: "응접실의 정중한 인사 한마디가 칼보다 날카롭습니다"),
        Exchange(a: "Dickens", b: "Poe", aLine: "내 까마귀 그립이 당신 까마귀보다 먼저였소", bLine: "내 까마귀는 수다를 떨지 않고 단 한 단어만 말하오"),
        Exchange(a: "Dickens", b: "Carroll", aLine: "아이들이 읽기에 논리가 너무 복잡하지 않소", bLine: "어른들이 읽기에 세상이 너무 복잡한 겁니다"),
        Exchange(a: "Poe", b: "Wilde", aLine: "초상화가 늙어 간다니 제법 내 취향이오", bLine: "당신 같았으면 초상화를 벽 속에 묻어 버렸겠지요"),
        Exchange(a: "Poe", b: "Austen", aLine: "그 저택에는 무너져 내리는 균열이 하나도 없소?", bLine: "지붕이 새면 로맨스보다 수리비가 먼저 걱정됩니다"),
        Exchange(a: "Carroll", b: "Wilde", aLine: "거울 속 세상은 모든 게 반대랍니다", bLine: "현실보다 거울 속이 훨씬 우아하겠군요"),
        Exchange(a: "Carroll", b: "Goethe", aLine: "나비의 변신보다 애벌레의 물담배가 더 중요합니다", bLine: "자연을 역설로 뒤집는 재주가 대단하군"),
        Exchange(a: "Stevenson", b: "Wilde", aLine: "지킬 박사도 당신처럼 이중생활을 즐겼소", bLine: "저는 약물 대신 재치로 변신합니다"),
        Exchange(a: "Stevenson", b: "Austen", aLine: "영국 시골길은 너무 안전해서 모험이 안 되오", bLine: "마차가 진흙탕에 빠지는 것만으로도 큰 사건입니다"),
        Exchange(a: "Stevenson", b: "Goethe", aLine: "이탈리아 기행문은 잘 읽었소. 나도 당나귀를 타고 걸었지", bLine: "젊은이, 바람 냄새가 문장마다 배어 있더군"),
        Exchange(a: "Austen", b: "Goethe", aLine: "베르테르는 감정이 너무 격해서 찻잔을 다 엎지르겠어요", bLine: "청춘의 열병이란 원래 예법을 모르는 법이오"),
    ]

    /// 누구와도 쓸 수 있는 말. {A} 가 말하고 {B} 가 받는다.
    static let generic: [(String, String)] = [
        ("그 의자는 내 것이오", "앉은 사람이 임자입니다"),
        ("펜 소리가 너무 큽니다", "당신 한숨 소리보다는 작소"),
        ("창문을 열면 안 되오", "닫으면 잉크가 안 마릅니다"),
        ("커피를 다 마셨군요", "홍차는 남았소"),
        ("{B}, 그 문장은 내 것 같은데", "비슷한 생각은 누구나 합니다"),
        ("이 책상은 둘이 쓰기엔 좁소", "그럼 당신이 서서 쓰시오"),
        ("그 대목은 결말이 너무 쉽소", "쉬운 결말을 쓰기가 제일 어렵소"),
        ("초를 하나 더 켜도 되겠소", "책상이 타면 당신 탓이오"),
        ("{B}의 독자는 참을성이 많더군", "{A}의 독자는 숫자가 적더군"),
        ("오늘 몇 장 썼소", "묻는 사람보다는 많이"),
        ("비평가가 당신 책을 칭찬했다지요", "그 사람은 내 책도 칭찬했소. 작년에"),
        ("내 원고를 보지 마시오", "볼 게 있어야 보지"),
        ("손님은 손님답게 조용히", "주인이 먼저 조용하면"),
        ("종이를 그렇게 쓰면 모자라오", "글이 길면 종이가 드는 법"),
        ("잉크병을 내 쪽으로 좀 밀어 주시오", "팔이 짧은 건 내 탓이 아니오"),
        ("중얼거리면서 쓰지 마시오", "대사는 소리 내어 읽어 봐야 맛을 아오"),
        ("{B}, 글씨가 그게 뭐요. 인쇄소에서 울겠소", "명작은 원래 악필에서 나오는 법이오"),
        ("압지를 어디다 두었소", "방금 당신이 코 푸는 데 썼잖소"),
        ("서재에 담배 연기가 가득하오", "안개 낀 장면을 쓰는 중이오"),
        ("첫 문장을 벌써 한 시간째 고치는군", "{A}처럼 아무 문장이나 첫 줄로 쓸 수는 없지"),
    ]

    /// 한 번의 말다툼. `rolls` 는 0..<1 두 개.
    static func exchange(host: String, guest: String, rolls: (Double, Double)) -> (host: String, guest: String) {
        let hostName = Library.books.first { $0.authorShort == host }?.displayAuthorShort ?? host
        let guestName = Library.books.first { $0.authorShort == guest }?.displayAuthorShort ?? guest
        let matched = pairs.filter { ($0.a == host && $0.b == guest) || ($0.a == guest && $0.b == host) }
        // 둘의 말이 있어도 가끔은 일반적인 말다툼을 한다.
        if !matched.isEmpty, rolls.1 < 0.6 {
            let e = matched[min(matched.count - 1, Int(rolls.0 * Double(matched.count)))]
            return e.a == host ? (e.aLine, e.bLine) : (e.bLine, e.aLine)
        }
        let g = generic[min(generic.count - 1, Int(rolls.0 * Double(generic.count)))]
        func fill(_ s: String) -> String {
            Format.resolve(s.replacingOccurrences(of: "{A}", with: hostName).replacingOccurrences(of: "{B}", with: guestName))
        }
        return (fill(g.0), fill(g.1))
    }
}

/// 작가 교대. 책이 다음 작가 차례로 넘어갈 때 떠나는 작가와 오는 작가가 한 마디씩 한다.
@MainActor
enum Handoffs {
    /// 특정한 둘 사이의 말. (떠나는 작가, 오는 작가, 떠나는 말, 오는 말)
    static let pairs: [(from: String, to: String, leaving: String, arriving: String)] = [
        ("Shakespeare", "Dickens", "무대는 치웠소. 거리는 당신 몫이오", "런던 안개가 벌써 들어오는군요"),
        ("Dickens", "Poe", "난로는 켜 두었소", "끄겠소. 어둠이 편하오"),
        ("Poe", "Carroll", "까마귀가 책상 위에 있소. 건드리지 마시오", "토끼가 무서워하겠는데요"),
        ("Carroll", "Stevenson", "차는 여섯 시에 식었습니다", "항해엔 럼이 낫소"),
        ("Stevenson", "Wilde", "지도는 서랍에 넣어 두었소", "지도보다 거울이 필요한데요"),
        ("Wilde", "Austen", "카네이션은 꽃병에 두고 갑니다", "응접실에는 어울리겠군요"),
        ("Austen", "Goethe", "차 한 잔 남겨 두었어요", "고맙소. 광물 상자는 어디 두면 되오"),
        ("Goethe", "Shakespeare", "잎의 변형에 대해 적어 두었소. 읽어 보시오", "운율이 없으면 안 읽소"),
        ("Dickens", "Shakespeare", "마감이 닷새 남았소. 참고하시오", "마감은 극장 주인이나 지키는 것이오"),
        ("Poe", "Dickens", "초는 반쯤 남았소", "충분하오. 나는 가스등이 있소"),
        ("Shakespeare", "Poe", "비극의 왕관을 넘기고 가오", "왕관보다 지하실 열쇠가 더 쓸모 있소"),
        ("Shakespeare", "Wilde", "소네트 여백에 경구를 적어 두었소", "제 희곡 대사로 잘 쓰겠습니다"),
        ("Shakespeare", "Austen", "소란스러운 무대를 비워드리오", "이제 조용히 찻잔 소리를 들을 수 있겠군요"),
        ("Dickens", "Stevenson", "런던 골목 지도는 책상 위에 두었소", "나는 보물섬 해도를 펼칠 참이오"),
        ("Dickens", "Wilde", "인쇄소 소년이 밖에서 기다리오", "전 우아하게 내일 아침에 주겠습니다"),
        ("Poe", "Stevenson", "자정의 종소리가 울리면 조심하시오", "밤바다의 파도 소리에 비하면 자장가일 뿐이오"),
        ("Carroll", "Wilde", "수수께끼의 정답은 서랍 속에 없습니다", "정답이 없는 수수께끼야말로 예술이지요"),
        ("Carroll", "Austen", "체스판의 여왕들이 인사를 남겼습니다", "예의 바른 손님이라면 언제든 환영입니다"),
        ("Stevenson", "Dickens", "바닷바람에 창문이 좀 덜컹거리오", "런던 밤거리에 비하면 아늑하기만 하오"),
        ("Wilde", "Shakespeare", "관객들을 충분히 웃겨 두었습니다", "이제 울릴 차례군"),
        ("Austen", "Dickens", "서탁 위를 깔끔히 정돈해 두었어요", "곧 원고지와 잉크 자국으로 가득 찰 거요"),
        ("Goethe", "Poe", "서재 창문을 활짝 열어 빛을 들여놓았소", "커튼부터 치고 시작해야겠군"),
        ("Goethe", "Wilde", "자연의 질서를 기록해 두었소", "저는 인공의 아름다움을 덧붙이겠습니다"),
    ]
    /// 누구와도 쓰는 말. {A} 떠나는 작가, {B} 오는 작가.
    static let generic: [(String, String)] = [
        ("책상은 치우고 가오", "잉크는 남겨 두셨군요. 고맙소"),
        ("의자가 좀 삐걱거리오", "제 의자는 더 심했소"),
        ("펜촉은 새것이오. 아껴 쓰시오", "펜촉은 제 걸 쓰겠소"),
        ("창문은 열어 두었소", "닫겠소. 종이가 날리오"),
        ("{B}, 늦었군요", "{A}, 아직 안 갔군요"),
        ("원고는 가져가오. 보지 마시오", "볼 게 있어야 보지"),
        ("독자들에게 안부 전해 주시오", "제 독자들이오. 이제"),
        ("등잔 기름이 얼마 없소", "밤엔 안 쓰오"),
        ("행운을 비오", "운은 필요 없소. 시간이면 되오"),
        ("커피는 찬장 두 번째 칸이오", "홍차는요"),
        ("다음은 당신 차례요. 잘 써 보시오", "지켜보시오"),
        ("편집자가 성미가 급하오. 조심하시오", "편집자는 다 그렇소"),
        ("압지는 새것으로 갈아 두었소", "덕분에 첫 줄이 번지지 않겠군요"),
        ("벽난로에 장작을 더 넣어 두었소", "따뜻한 서재에서 시작할 수 있겠소"),
        ("내 몫의 마침표는 찍었소. 이제 {B} 차례요", "첫 문장은 이미 오면서 생각해 두었소"),
        ("사전은 펼친 채로 두고 가오", "내가 찾던 단어가 거기 있으면 좋겠군"),
    ]

    static func exchange(from: String, to: String, rolls: (Double, Double)) -> (leaving: String, arriving: String) {
        let fromName = Library.books.first { $0.authorShort == from }?.displayAuthorShort ?? from
        let toName = Library.books.first { $0.authorShort == to }?.displayAuthorShort ?? to
        let matched = pairs.filter { $0.from == from && $0.to == to }
        if !matched.isEmpty, rolls.1 < 0.7 {
            let m = matched[min(matched.count - 1, Int(rolls.0 * Double(matched.count)))]
            return (m.leaving, m.arriving)
        }
        let g = generic[min(generic.count - 1, Int(rolls.0 * Double(generic.count)))]
        func fill(_ s: String) -> String { Format.resolve(s.replacingOccurrences(of: "{A}", with: fromName).replacingOccurrences(of: "{B}", with: toName)) }
        return (fill(g.0), fill(g.1))
    }
}

/// 서점의 문단 소식. 한 주 동안 같은 소식이 보이도록 주 시작 시각으로 난수를 고정한다. 이름을 끼운 자리의 조사는 받침에 맞춘다.
@MainActor
enum Gossip {
    /// 두 작가 사이의 소문. {A}, {B}. 말끝을 섞어 같은 투가 이어지지 않게 한다.
    static let rumors = [
        "{A}(이|가) {B}의 신작을 몰래 샀다는 소문", "{A}(과|와) {B}(이|가) 같은 카페에서 등을 돌리고 앉았다고 합니다",
        "{B}(이|가) {A}의 서평을 쓰겠다고 했다가 말았다는 이야기", "{A}(이|가) {B}에게 빌려준 펜을 아직 못 받았답니다",
        "{A}(과|와) {B}(이|가) 같은 비평가를 저녁에 초대했고, 비평가는 둘 다 거절했습니다", "{B}(은|는) {A}의 제목을 자기가 먼저 떠올렸다고 합니다",
        "{A}(이|가) {B}의 낭독회에 갔다가 중간에 나왔다고들 합니다", "{A}(과|와) {B}(이|가) 쉼표 자리를 두고 편지로 다툽니다",
        "{B}(은|는) {A}의 책을 읽고 '길다'고만 했습니다", "{A}(이|가) {B}의 집 앞을 두 번 지나갔습니다. 들어가지는 않았습니다",
        "{A}(과|와) {B}(이|가) 같은 날 같은 출판사에 원고를 냈습니다", "{B}(이|가) {A}의 문장을 외워 다닙니다. 비꼬려고",
        "{A}(이|가) {B}(을|를) 저녁에 초대했는데 둘 다 글 얘기는 안 했답니다", "{B}의 새 모자를 {A}(이|가) 먼저 썼다는 말이 돕니다",
        "{A}(이|가) {B}의 초판본 여백에 반박 메모를 빼곡히 적어 두었답니다", "{B}(이|가) {A}의 단골 문방구에서 같은 잉크를 사 갔다는 목격담",
        "{A}(과|와) {B}(이|가) 서점 진열창 앞자리를 두고 은근히 신경전을 벌인답니다", "{B}(은|는) {A}의 새 작품 결말을 이미 눈치챘다고 장담합니다",
        "{A}(이|가) {B}에게 보낼 편지를 세 번이나 고쳐 쓰다 결국 안 부쳤답니다", "{B}(이|가) 살롱에서 {A}의 성대모사를 해 좌중을 웃겼다는 후문",
    ]
    static let quiet = [
        "문단은 이번 주 조용합니다", "서점 주인이 선반을 닦았습니다. 소식은 그게 다입니다", "비평가들이 휴가를 갔다고 합니다",
        "우체부가 편지를 잘못 배달했는데 아무도 눈치채지 못했습니다", "이번 주는 비 소식뿐입니다",
        "모두 마감에 쫓겨 살롱에도 발길이 뜸한 한 주입니다", "인쇄소 굴뚝에서 연기만 바쁘게 피어오릅니다"
    ]

    /// 이번 주 소식 몇 줄. 판매·비평·사건·돌발 상황·손님 기록에서 뽑고, 소문 한둘을 섞는다.
    static func lines(progress: WritingProgress, now: Date = Date()) -> [String] {
        let weekStart = WritingStore.weekStart(of: now)
        var dice = Dice([Double(UInt64(weekStart.timeIntervalSince1970) % 9973) / 9973])
        func name(_ author: String) -> String { Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author }

        var lines: [String] = []
        if let top = progress.finished.map(\.bookIndex).max(by: { progress.sales(of: Library.books[$0]) < progress.sales(of: Library.books[$1]) }),
           progress.sales(of: Library.books[top]) > 0 {
            let book = Library.books[top]
            let author = name(book.authorShort)
            lines.append(dice.pick(["이번 주 매대 맨 앞은 \(book.displayTitle). \(author)(이|가) 지나가다 두 번 봤다고 합니다",
                                    "\(book.displayTitle)(이|가) 매대에서 제일 빨리 빠집니다. \(Format.integer(progress.sales(of: book)))부째",
                                    "서점 주인이 \(book.displayTitle)(을|를) 창가로 옮겼습니다. \(author)(은|는) 모른 척합니다"]))
        }
        if let review = progress.reviews.first, let book = Library.books.first(where: { $0.file == review.book }) {
            let author = name(book.authorShort)
            let title = book.displayTitle
            lines.append(review.stars >= 4
                ? dice.pick(["\(review.critic)의 \(title) 서평이 화제입니다. \(author)(은|는) '안 읽었다'고 합니다",
                             "\(title)에 별 \(review.stars)개. \(author)(이|가) 신문을 오려 두었다고 합니다"])
                : review.stars <= 2
                ? dice.pick(["\(review.critic)(이|가) \(title)에 별 \(review.stars)개를 줬습니다. \(author)(은|는) 그 이름을 적어 두었습니다",
                             "\(title) 서평 때문에 \(author)(이|가) 신문을 끊었다는 소문"])
                : dice.pick(["\(review.critic)(은|는) \(title)(이|가) '읽을 만하다'고 했습니다. \(author)(은|는) 그 말이 더 싫답니다",
                             "\(title)에 별 3개. 기뻐한 사람도 화낸 사람도 없습니다"]))
        }
        if let decision = progress.decisions.first, let dilemma = Dilemmas.byID(decision.dilemma) {
            lines.append(decision.auto == true
                ? "\(dilemma.title) 건은 작가가 묻지도 않고 '\(decision.option)'(으로|로) 정했습니다"
                : dice.pick(["\(dilemma.title) 건은 '\(decision.option)'(으로|로) 결론이 났습니다", "문단에서는 \(dilemma.title) 이야기가 아직 돕니다. 결론은 '\(decision.option)'"]))
        }
        let events = progress.recentEvents.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") && $0.startedAt >= weekStart }.count
        if events >= 3, let book = progress.book {
            let author = name(book.authorShort)
            lines.append(dice.pick(["이번 주 돌발 상황 \(events)번. '\(author)(이|가) 요즘 산만하다'는 말이 돕니다",
                                    "\(author)의 집에 이번 주만 \(events)번 일이 있었습니다. 이웃이 세고 있습니다"]))
        }
        if let file = progress.featuredBook, let book = Library.books.first(where: { $0.file == file }) {
            lines.append(dice.pick(["서점 진열창에 \(book.displayTitle)(이|가) 걸렸습니다. 지나던 사람들이 걸음을 멈춥니다",
                                    "진열창의 \(book.displayTitle)(을|를) 보려고 \(name(book.authorShort))(이|가) 서점 앞을 세 번 지나갔습니다"]))
        }
        if progress.facts.guests > 0 {
            lines.append(dice.pick(["손님 작가가 지금까지 \(progress.facts.guests)번 다녀갔습니다. 커피값이 만만치 않다고 합니다",
                                    "손님이 \(progress.facts.guests)번째 다녀간 뒤로 의자가 하나 더 생겼습니다"]))
        }
        if progress.facts.longestStreak >= 7, let book = progress.book {
            lines.append("\(name(book.authorShort))(은|는) \(progress.facts.longestStreak)일째 하루도 안 빠졌습니다. 비서가 더 지쳤다는 후문")
        }
        let authors = Library.authors
        if authors.count >= 2 {
            for _ in 0..<(lines.count < 3 ? 2 : 1) {
                let a = dice.pick(authors)
                let b = dice.pick(authors.filter { $0 != a })
                lines.append(dice.pick(rumors).replacingOccurrences(of: "{A}", with: name(a)).replacingOccurrences(of: "{B}", with: name(b)))
            }
        }
        if lines.isEmpty { lines.append(dice.pick(quiet)) }
        return lines.prefix(6).map(Format.resolve)
    }
}
