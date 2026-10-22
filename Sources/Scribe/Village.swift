import AppKit
import SwiftUI

// 마을. 팝오버에서 방향키를 누르면 나오는 작은 맵. 게임보이 시절 포켓몬 같은 16px 타일(굵은 테두리, 네 단계 색)로
// 작업실·창고·서점 세 건물이 나란히 서 있고, 사용자를 뜻하는 모자 쓴 사람이 걸어 다니다 문 앞에서 위로 가면 그 화면이 열린다.
// 맵은 11×9 타일을 한 장으로 구워 쓰고 사람만 따로 얹는다. 가만히 있을 때는 아무것도 다시 그리지 않는다.

// MARK: - 건물

enum VillageBuilding: String, CaseIterable, Sendable {
    case workshop, storage, bookstore, salon

    var title: String {
        switch self {
        case .workshop: "작업실"
        case .storage: "창고"
        case .bookstore: "서점"
        case .salon: "살롱"
        }
    }

    /// 건물 윗줄. 위 셋은 1행, 살롱은 아래 7행.
    var top: Int { self == .salon ? 7 : 1 }
    /// 문이 있는 줄과 그 앞 줄.
    var doorRow: Int { top + 2 }
    var frontRow: Int { doorRow + 1 }

    /// 건물 왼쪽 타일. 너비 4타일, 지붕 1~2행, 벽 3행.
    var left: Int {
        switch self {
        case .workshop: 0
        case .storage: 5
        case .bookstore: 10
        case .salon: 5
        }
    }

    /// 문이 있는 타일(3행). 오두막과 서점은 왼쪽에서 셋째, 헛간은 둘째(큰 문의 왼쪽).
    var doorCol: Int { self == .storage ? left + 1 : left + 2 }

    /// 집 그림.
    var sprite: [String] {
        switch self {
        case .workshop: VillageTiles.houseWorkshop
        case .storage: VillageTiles.houseStorage
        case .bookstore: VillageTiles.houseBookstore
        case .salon: VillageTiles.houseSalon
        }
    }
}

// MARK: - 타일

/// 16×16 타일. 게임보이 컬러 시절 마을 그림의 관습을 따른다. 바닥은 옅은 민트색에 회색 점, 나무는 네 단계 초록의 빽빽한 덤불,
/// 지붕은 세로 줄무늬 두 줄에 처마 선, 벽은 옅은 바탕에 벽돌 점, 창문은 노란 유리에 검은 틀. `.` 은 밑이 보인다.
enum VillageTiles {
    static let size = 16

    /// 바닥. 8칸마다 되풀이되는 회색 점.
    static let ground: [String] = {
        let unit = [
            "........",
            ".f.....f",
            "....f...",
            "........",
            "f.......",
            ".......f",
            "........",
            ".f......",
        ]
        return (0..<16).map { y in String(repeating: unit[y % 8], count: 2).map { $0 == "." ? "e" : $0 }.map(String.init).joined() }
    }()
    /// 꽃밭. 바닥에 분홍·빨강·주황 꽃.
    static let flowers = [
        "eeeeeeeeeeeeeeee",
        "efeeeeefepeeeeef",
        "eeeefeeeppfeeeee",
        "eeeeeeeeepeeeeee",
        "feeeeeeefeeeeeee",
        "eeeeeeefeeeeeeef",
        "eeerreeeeeeeeeee",
        "efrrrreeefeeeeee",
        "eeerreeeeeeeeeee",
        "efeeeeefefeeeoee",
        "eeeefeeeeeeeooof",
        "eeeeeeeeeeeeeoee",
        "feeeeeeefeeeeeee",
        "eeeepeeeeeeeeeef",
        "eeeppeeeeeeeeeee",
        "efeepeeeefeeeeee",
    ]
    /// 나무. 둥근 덤불. 울타리처럼 이어 붙인다.
    static let tree = [
        "xxbbbbbbbbbbbbxx",
        "xbbbaabbbbbaabbx",
        "bbaabbaabbaabbab",
        "babbaababbbbabba",
        "baabbbbaaabbabab",
        "abbaabbabbbaabba",
        "aabbabbaabbabaad",
        "abaabbbabbabaadd",
        "daabaabbabaaddad",
        "dadaabababaddadd",
        "ddaddaaaaddaddda",
        "dddadddaddaddddd",
        "xdddddxxxxdddddx",
        "xxddxxjjjjxxddxx",
        "xxxxxxjjjjxxxxxx",
        "xxxxxxxxxxxxxxxx",
    ]
    /// 팻말(품절).
    static let signpost = [
        "eeeeeeeeeeeeeeee",
        "efeeeeefefeeeeef",
        "eeeefeeeeeeefeee",
        "eeeeeeeeeeeeeeee",
        "feexxxxxxxxxxeee",
        "eeexffffffffxeef",
        "eeexfxxxxxxfxeee",
        "efexfxrrrrxfxeee",
        "eeexfxxxxxxfxeee",
        "efexffffffffxeef",
        "eeeexxxxxxxxxeee",
        "eeeeeeexvxeeeeee",
        "feeeeeexvxeeeeee",
        "eeeeeeexvxeeeeef",
        "eeeeeeexxxeeeeee",
        "efeeeeeeefeeeeee",
    ]
    /// 창문 벽. 노란 유리에 검은 틀, 벽돌 점.
    static let wallWindow = [
        "eeeeeeeeeeeeeeee",
        "eeneeeeeeeeeneee",
        "eexxxxxxxxxxxxee",
        "eexkkkkkxkkkkkxe",
        "eexkkkkkxkkkkkxe",
        "eexkkkkkxkkkkkxe",
        "eexxxxxxxxxxxxxe",
        "eexkkkkkxkkkkkxe",
        "eexkkkkkxkkkkkxe",
        "eexxxxxxxxxxxxee",
        "eeeeeeeeeeeeeeee",
        "eneeeeeneeeeeene",
        "eeeeeeeeeeeeeeee",
        "eeeeneeeeeeneeee",
        "eeeeeeeeeeeeeeee",
        "eneeeeeneeeeeene",
    ]
    /// 창문 없는 벽.
    static let wallPlain = [
        "eeeeeeeeeeeeeeee",
        "eeneeeeeeeeeneee",
        "eeeeeeeeeeeeeeee",
        "eeeeeeneeeeeeeee",
        "eeeeeeeeeeeeeeee",
        "eneeeeeeeeeneeee",
        "eeeeeeeeeeeeeeee",
        "eeeeeeeeneeeeeee",
        "eeeeeeeeeeeeeeee",
        "eeeneeeeeeeeenee",
        "eeeeeeeeeeeeeeee",
        "eneeeeeneeeeeene",
        "eeeeeeeeeeeeeeee",
        "eeeeneeeeeeneeee",
        "eeeeeeeeeeeeeeee",
        "eneeeeeneeeeeene",
    ]
    /// 문 벽. 갈색 문에 검은 틀, 손잡이.
    static let wallDoor = [
        "eeeeeeeeeeeeeeee",
        "eeneeeeeeeeeneee",
        "eeeexxxxxxxxeeee",
        "eeexjjjjjjjjxeee",
        "eexjjiiiiiijjxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiikijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjiiiiiiiijxee",
        "eexjjjjjjjjjjxee",
        "eexxxxxxxxxxxxee",
    ]
    /// 헛간의 큰 문(두 타일). 널빤지와 가로 띠.
    static let barnDoorLeft = [
        "eeeeeeeeeeeeeeee",
        "eeneeeeeeeeeneee",
        "eexxxxxxxxxxxxxx",
        "eexjjjjjjjjjjjjj",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjjjjjjjjjjjjj",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjiijiijiijiij",
        "eexjjjjjjjjjjjjj",
        "eexxxxxxxxxxxxxx",
        "eeeeeeeeeeeeeeee",
    ]
    static let barnDoorRight = barnDoorLeft.map { String($0.reversed()) }
    /// 서점 진열창(두 타일). 큰 유리 안에 책등.
    static let shopWindowLeft = [
        "eeeeeeeeeeeeeeee",
        "eeneeeeeeeeeneee",
        "eexxxxxxxxxxxxxx",
        "eexkkkkkkkkkkkkk",
        "eexkkkkkkkkkkkkk",
        "eexkkrrkuukookkk",
        "eexkkrrkuukookkk",
        "eexkkrrkuukookkk",
        "eexkkkkkkkkkkkkk",
        "eexkxxxxxxxxxxxx",
        "eexkkkkkkkkkkkkk",
        "eexkkuukrrkkkkkk",
        "eexkkuukrrkkkkkk",
        "eexkkkkkkkkkkkkk",
        "eexxxxxxxxxxxxxx",
        "eeeeeeeeeeeeeeee",
    ]
    static let shopWindowRight = shopWindowLeft.map { String($0.reversed()) }
    /// 상자(창고 앞).
    static let crate = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "....xxxxxxxxx...",
        "....xiiiiiiix...",
        "....xijjjjjix...",
        "....xijiiijix...",
        "....xijiiijix...",
        "....xijjjjjix...",
        "....xiiiiiiix...",
        "....xxxxxxxxx...",
        "................",
        "................",
    ]
    /// 장작 한 개의 마구리. 작업실 앞에 쌓는다.
    static let log = [
        ".xxx.",
        "xIiIx",
        "xiIix",
        ".xxx.",
    ]
    /// 장작을 쌓는 자리(작업실 오른쪽 벽 타일 안에서 dx, dy). 아래 셋, 가운데 둘, 위 하나 순서로 채운다.
    static let logSpots: [(Int, Int)] = [(1, 12), (5, 12), (9, 12), (3, 9), (7, 9), (5, 6)]
    /// 광고 벽보.
    static let poster = [
        "................",
        "................",
        "................",
        "................",
        "....xxxxxxx.....",
        "....xkkkkkx.....",
        "....xkrrrkx.....",
        "....xkkkkkx.....",
        "....xkrkrkx.....",
        "....xkkkkkx.....",
        "....xxxxxxx.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ]
    /// 열린 문(들어갈 때 문 자리에 덮는다). 폭 12, 높이 16.
    static let doorOpen = [
        "xxxxxxxxxxxx",
        "xjjjjjjjjjjx",
        "xjxxxxxxxxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxvvvvvvxjx",
        "xjxxxxxxxxjx",
        "xxxxxxxxxxxx",
    ]
    /// 굴뚝 연기 두 프레임(8×12).
    static let smokeA = [
        "........",
        "...ee...",
        "..eeee..",
        "..eeee..",
        "...ee...",
        "........",
        "....ee..",
        "...eeee.",
        "....ee..",
        "........",
        ".....e..",
        "....ee..",
    ]
    static let smokeB = [
        "..ee....",
        ".eeee...",
        ".eeee...",
        "..ee....",
        "........",
        "...ee...",
        "..eeee..",
        "...ee...",
        "........",
        "....e...",
        "...ee...",
        "....e...",
    ]
    /// 우산(12×7). 비 오는 날 머리 위에.
    static let umbrella = [
        ".....xx.....",
        "...xxUUxx...",
        ".xxUUUUUUxx.",
        "xUUUUUUUUUUx",
        "xxxxxxxxxxxx",
        ".....x......",
        ".....x......",
    ]
    /// 새 두 프레임(8×5).
    static let birdA = [
        "x......x",
        ".x....x.",
        "..xxxx..",
        "........",
        "........",
    ]
    static let birdB = [
        "........",
        "........",
        "..xxxx..",
        ".x....x.",
        "x......x",
    ]
    /// 풀밭에 떨어진 물건(반짝임 두 프레임, 8×8).
    static let sparkleA = [
        "...k....",
        "...k....",
        ".kkkkk..",
        "...k....",
        "...k....",
        "......k.",
        ".....kkk",
        "......k.",
    ]
    static let sparkleB = [
        "........",
        "...k....",
        "..kkk...",
        "...k....",
        "........",
        ".k......",
        "kkk.....",
        ".k......",
    ]
    /// 꽃만 남긴 꽃밭(흔들림용). 바탕은 비친다.
    static let flowerHeads: [String] = flowers.map { row in String(row.map { "pro".contains($0) ? $0 : "." }) }

    /// 서점 지붕 간판(책).
    static let roofSign = [
        "................",
        "................",
        "................",
        "....xxxxxxxx....",
        "....xkkkkkkx....",
        "....xkxkkxkx....",
        "....xkxkkxkx....",
        "....xkxkkxkx....",
        "....xkkkkkkx....",
        "....xxxxxxxx....",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ]

    // MARK: 집 넷(64×48). 용마루에서 넓어지는 지붕, 기와 줄, 처마 그늘, 벽.
    static let houseSalon = [
        "................................................................",
        "................................................................",
        "......xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx......",
        ".....xNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNx.....",
        "....xNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNx....",
        "....xNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNx....",
        "...xmmmmmmmmmmmmmmmmmmmmxxxxxxxxxxxxxxxxmmmmmmmmmmmmmmmmmmmmx...",
        "..xmmmmmmmmmmmmmmmmmmmmmxeeeeeeeeeeeeeexmmmmmmmmmmmmmmmmmmmmmx..",
        "..xMMMMMMMMMMMMMMMMMMMMMxeeeeeeeeeeeeeexMMMMMMMMMMMMMMMMMMMMMx..",
        ".xmmmmmmmmmmmmmmmmmmmmmmxeerrrrexxxxxeexmmmmmmmmmmmmmmmmmmmmmmx.",
        "xmmmmmmmMMmmmmmmMMmmmmmmxeerrrreexeeeeexMMmmmmmmMMmmmmmmMMmmmmmx",
        "xmmmmmmmmmmmmmmmmmmmmmmmxeerrrreexeeeeexmmmmmmmmmmmmmmmmmmmmmmmx",
        "xMMMMMMMMMMMMMMMMMMMMMMMxeerrrreexeeeeexMMMMMMMMMMMMMMMMMMMMMMMx",
        "xmmmmmmmmmmmmmmmmmmmmmmmxeeeeeeeeeeeeeexmmmmmmmmmmmmmmmmmmmmmmmx",
        "xmMMmmmmmmMMmmmmmmMMmmmmxxxxxxxxxxxxxxxxmmMMmmmmmmMMmmmmmmMMmmmx",
        "xmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmx",
        "xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx",
        "xmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmx",
        "xmmmmmMMmmmmmmMMmmmmmmMMmmmmmmMMmmmmmmMMmmmmmmMMmmmmmmMMmmmmmmmx",
        "xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx",
        "xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx",
        "xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx",
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeexxxxxxxxxxxxxxxxxxxxxxeeeexxxxxxxxxxxxeeeeeeeeeeeeeeeeex..",
        "..xeeexeeeeexeeeeexeeeeexeexeeeexjjjjjjjjjjxeeeeeeeeeeeeeeeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeeeexxxxxxxxxxxxeeeeeeeeeeeeeeeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxexeexjjjjjjjjjjxeexexxxxxxxxxxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxekeexjiiiiiiiijxeekexkkkkxkkkxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxekeexjiiiiiiiijxeekexkkkkxkkkxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxexeexjiiiiiiiijxeexexkkkkxkkkxeeex..",
        "..xeeexxxxxxxxxxxxxxxxxxxxxxeveexjiiiiiiiijxeevexkkkkxkkkxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeveexjiiiiiiiijxeevexkkkkxkkkxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeeeexjiiiiiiiijxeeeexkkkkxkkkxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeeeexjiiiiiikijxeeeexxxxxxxxxxeeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeeeexjiiiiiiiijxeeexxxxxxxxxxxxeex..",
        "..xeeexkkkkkxkkkkkxkkkkkxkkxeeeexjiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeexxxxxxxxxxxxxxxxxxxxxxeeeexjiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeexxxxxxxxxxxxxxxxxxxxxxxxeeexjiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeennnnnnnnnnnnnnnnnnnnnneeeexjiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeexxxxxxxxxxxxeeeeeeeeeeeeeeeeex..",
        "..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..",
        "..fffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvffffffff..",
        "..ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff..",
    ]

    static let houseWorkshop = [
        "......xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx......",
        ".....xGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGxeeeeeexGGGGGGx.....",
        "....xGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGxeeeeeexGGGGGGGx....",
        "....xGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGxvvvvvvxGGGGGGGx....",
        "...xggggggggggggggggggggggggggggggggggggggggxeeeeeexggggggggx...",
        "..xgggggggggggggggggggggggggggggggggggggggggxeeeeeexgggggggggx..",
        "..xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhxeeeeeexhhhhhhhhhx..",
        ".xggggggggggggggggggggggggggggggggggggggggggxeeeeeexggggggggggx.",
        "xggggggghhgggggghhgggggghhgggggghhgggggghhggxeeeeeexgggghhgggggx",
        "xgggggggggggggggggggggggggggggggggggggggggggxxxxxxxxgggggggggggx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggx",
        "xghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggx",
        "xggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggx",
        "xggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggggx",
        "xggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggx",
        "xghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggggghhgggx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhx",
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeeeexxxxxxxxxxxxeeeeeeeeeeeeeeeexxxxxxxxxxxxeeeeeeeeeeeeex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeeeeeeeeeeexjjjjjjjjjjxeeeeeeeeeeeeex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeneeeeeeenexjiiiiiiiijxeeneeeeeeeneex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeeeeeeexeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeexxxxxxxxxxxxeeeeeeeeeeeekeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeeeeeeexeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeeeeeeeveeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeexkkkkkxkkkkxeeeeeeeeeeeeveeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeenexxxxxxxxxxxxeeneeeeeeeneveeexjiiiiiikijxeeeeeeneeeeeex..",
        "..xeeeexxpxxxoxxxpxxxeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeexxxxxxxxxxxxxxeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeexjjjjjjjjjjjjxeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeexjjjjjjjjjjjjxeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeexxxxxxxxxxxxxxeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeexxxxxxxxxxxxeeeeeeeeeeeeex..",
        "..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..",
        "..fffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvffffffff..",
        "..ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff..",
    ]
    static let houseStorage = [
        "................................................................",
        "................................................................",
        "................................................................",
        "................................................................",
        "....xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx....",
        "....xIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIx....",
        "...xIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIx...",
        "..xIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIx..",
        "..xiiiiiiiiiiiiiiiiiiiiiiiiixxxxxxxxiiiiiiiiiiiiiiiiiiiiiiiiix..",
        "..xiiiiiiiiiiiiiiiiiiiiiiiiixkkkxkkxiiiiiiiiiiiiiiiiiiiiiiiiix..",
        ".xOOOOOOOOOOOOOOOOOOOOOOOOOOxkkkxkkxOOOOOOOOOOOOOOOOOOOOOOOOOOx.",
        "xiiiiiiiiiiiiiiiiiiiiiiiiiiixxxxxxxxiiiiiiiiiiiiiiiiiiiiiiiiiiix",
        "xiiiiiiOOiiiiiiOOiiiiiiOOiiixkkkxkkxiiiOOiiiiiiOOiiiiiiOOiiiiiix",
        "xiiiiiiiiiiiiiiiiiiiiiiiiiiixkkkxkkxiiiiiiiiiiiiiiiiiiiiiiiiiiix",
        "xOOOOOOOOOOOOOOOOOOOOOOOOOOOxxxxxxxxOOOOOOOOOOOOOOOOOOOOOOOOOOOx",
        "xiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiix",
        "xiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiix",
        "xiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiix",
        "xOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOx",
        "xiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiix",
        "xiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiOOiiiiiiix",
        "xOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOx",
        "xOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOx",
        "xOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOx",
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnx..",
        "..xeeeeeeeeeeeeeeeeexxxxxxxxxxxxxxxxxxxxxxxxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjjjjjjjjjjxxjjjjjjjjjjxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjijiiiiijixxiijiiiiijjxeeeexeeeeeeeeeeeex..",
        "..xeeeeeeeneeeeeeenexjiiiiiiiiixxiiiiiiiiijxeeeekeneeeeeeeneex..",
        "..xeeeeeeeeeeeeeeeeexjiijiiijiixxiiijiiijijxeeeexeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiijijiiixxiiiijijiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiijiiiixxiiiiijikijxeeeeeeeeeeeeeeeeex..",
        "..xeeeneeeeeeeneeeeexjiiiiiiiiixxiiiiiiiiijxeeneeeeeeeneeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiijijiiixxiiiijijiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiijiiijiixxiiijiiijijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexjiiiiiiiiixxiiiiiiiiijxeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeexxxxxxxxxxxxxxxxxxxxxxxxeeeeeeeeeeeeeeeeex..",
        "..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..",
        "..fffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvffffffff..",
        "..ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff..",
    ]
    static let houseBookstore = [
        "......xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx......",
        ".....xVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVx.....",
        "....xVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVx....",
        "....xVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVx....",
        "...xuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuux...",
        "..xuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuux..",
        "..xUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUx..",
        ".xuuuuuuuuuuuuuuuuxxxxxxxxxxxxxxxxxxxxxxxxxxxxuuuuuuuuuuuuuuuux.",
        "xuuuuuuuUUuuuuuuUUxnnnnnnnnnnnnnnnnnnnnnnnnnnxuuUUuuuuuuUUuuuuux",
        "xuuuuuuuuuuuuuuuuuxeeeeeeeeeeeeeeeeeeeeeeeeeexuuuuuuuuuuuuuuuuux",
        "xUUUUUUUUUUUUUUUUUxeexxxexxxexxxexxxexxxexxxexUUUUUUUUUUUUUUUUUx",
        "xuuuuuuuuuuuuuuuuuxeerrrekkkeoooeuuueRRRegggexuuuuuuuuuuuuuuuuux",
        "xuUUuuuuuuUUuuuuuuxeerrrekkkeoooeuuueRRRegggexuuuuUUuuuuuuUUuuux",
        "xuuuuuuuuuuuuuuuuuxeerrrekkkeoooeuuueRRRegggexuuuuuuuuuuuuuuuuux",
        "xUUUUUUUUUUUUUUUUUxeerrrekkkeoooeuuueRRRegggexUUUUUUUUUUUUUUUUUx",
        "xuuuuuuuuuuuuuuuuuxeerrrekkkeoooeuuueRRRegggexuuuuuuuuuuuuuuuuux",
        "xuuuuuUUuuuuuuUUuuxeeeeeeeeeeeeeeeeeeeeeeeeeexUUuuuuuuUUuuuuuuux",
        "xuuuuuuuuuuuuuuuuuxxxxxxxxxxxxxxxxxxxxxxxxxxxxuuuuuuuuuuuuuuuuux",
        "xUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUx",
        "xUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUx",
        "xUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUx",
        "xUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUx",
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "..uueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuuee..",
        "..uueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuuee..",
        "..uueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuueeeeuuuuee..",
        "..uxxeexxuuxxeexxuuxxeexxuuxxeexxuuxxeexxuuxxeexxuuxxeexxuuxxe..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeex..",
        "..xeeexxxxxxxxxxxxxxxxxxxxxxxxxxeeeexxxxxxxxxxxxeeeeeeneeeeeex..",
        "..xeeexkkkkkkkkkkkkkkkkkkkkkkkkxeeeexjjjjjjjjjjxeeeeeeeeeeeeex..",
        "..xeeexkkrrkkuukkookkRRkkggkkuuxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeexkkrrkkuukkookkRRkkggkkuuxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeexkkrrkkuukkookkRRkkggkkuuxeeeexjeeeeeeeejxeeeeeeeeeeeeex..",
        "..xeeexkkrrkkuukkookkRRkkggkkuuxeeeexjerrrrrrejxeeeeeeeeeeeeex..",
        "..xeeexkkrrkkuukkookkRRkkggkkuuxeenexjexxxxxxejxeeneeeeeeeneex..",
        "..xeeexjjjjjjjjjjjjjjjjjjjjjjjjxeeeexjeeeeeeeejxeeeeeeeeeeeeex..",
        "..xeeexkkkuukkRRkkookkrrkkggkkkxeeeexjiiiiiikijxeeeeeeeeeeeeex..",
        "..xeeexkkkuukkRRkkookkrrkkggkkkxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeexkkkuukkRRkkookkrrkkggkkkxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeexkkkuukkRRkkookkrrkkggkkkxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeexkkkuukkRRkkookkrrkkggkkkxeeeexjiiiiiiiijxeeeeeeneeeeeex..",
        "..xeeexjjjjjjjjjjjjjjjjjjjjjjjjxeeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeexxxxxxxxxxxxxxxxxxxxxxxxxxxxeeexjiiiiiiiijxeeeeeeeeeeeeex..",
        "..xeeennnnnnnnnnnnnnnnnnnnnnnnnneeeexxxxxxxxxxxxeeeeeeeeeeeeex..",
        "..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..",
        "..fffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvfffffvffffffff..",
        "..ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff..",
    ]


    /// 그 시절 마을 팔레트를 조금 가라앉힌 색. 너무 밝지 않게 채도와 밝기를 낮췄다.
    static let palette: [Character: Color] = [
        "e": Color(red: 0.80, green: 0.87, blue: 0.80),
        "f": Color(red: 0.64, green: 0.69, blue: 0.64),
        "x": Color(red: 0.2, green: 0.2, blue: 0.23),
        "a": Color(red: 0.42, green: 0.72, blue: 0.24),
        "b": Color(red: 0.6, green: 0.84, blue: 0.38),
        "d": Color(red: 0.2, green: 0.45, blue: 0.12),
        "g": Color(red: 0.55, green: 0.78, blue: 0.42),
        "h": Color(red: 0.33, green: 0.58, blue: 0.22),
        "i": Color(red: 0.72, green: 0.56, blue: 0.3),
        "n": Color(red: 0.72, green: 0.74, blue: 0.66),
        "j": Color(red: 0.55, green: 0.4, blue: 0.16),
        "k": Color(red: 0.92, green: 0.85, blue: 0.4),
        "v": Color(red: 0.42, green: 0.42, blue: 0.44),
        "r": Color(red: 0.8, green: 0.33, blue: 0.26),
        "R": Color(red: 0.55, green: 0.18, blue: 0.14),
        "p": Color(red: 0.9, green: 0.62, blue: 0.74),
        "o": Color(red: 0.86, green: 0.52, blue: 0.18),
        "O": Color(red: 0.5, green: 0.36, blue: 0.12),
        "u": Color(red: 0.4, green: 0.44, blue: 0.76),
        "U": Color(red: 0.22, green: 0.24, blue: 0.56),
        "G": Color(red: 0.7, green: 0.88, blue: 0.58),
        "I": Color(red: 0.84, green: 0.72, blue: 0.5),
        "V": Color(red: 0.58, green: 0.62, blue: 0.9),
        "m": Color(red: 0.55, green: 0.36, blue: 0.52),
        "M": Color(red: 0.36, green: 0.2, blue: 0.36),
        "N": Color(red: 0.7, green: 0.52, blue: 0.68),
    ]
}

// MARK: - 맵

enum VillageMap {
    static let tile = VillageTiles.size
    static let cols = 14
    static let rows = 12
    /// 1.5배. 레티나에서 그림 한 점이 기기 픽셀 셋이라 또렷하다.
    static let scale: CGFloat = 1.5
    static var width: Int { cols * tile }
    static var height: Int { rows * tile }

    /// 가장자리 나무(4~6행 양끝).
    static let trees: [(Int, Int)] = [(0, 5), (0, 6), (13, 5), (13, 6), (0, 8), (13, 8), (0, 10), (13, 10)]

    /// 장작더미 열. 작업실 문 오른쪽 벽 앞(3행).
    static let woodpileCol = VillageBuilding.workshop.left + 3

    /// 5시간 한도에서 남은 몫을 장작 수로. 조금이라도 남으면 하나는 있다.
    static func logs(_ fuel: LimitRow) -> Int {
        let left = min(100, max(0, 100 - fuel.percent))
        return Int((left / 100 * Double(VillageTiles.logSpots.count)).rounded(.up))
    }

    /// 서점 옆 팻말 타일.
    static let signpost = (col: VillageBuilding.bookstore.left + 3, row: 4)

    /// 살롱이 차지하는 칸(7~9행, 5~8열).
    static func insideSalon(col: Int, row: Int) -> Bool {
        (VillageBuilding.salon.top...(VillageBuilding.salon.top + 2)).contains(row) && (VillageBuilding.salon.left...(VillageBuilding.salon.left + 3)).contains(col)
    }

    /// 바닥 4~6행과 7~10행(살롱 자리 빼고). 문 줄은 문 타일만. 나무와 팻말 자리는 못 지나간다.
    static func walkable(col: Int, row: Int) -> Bool {
        guard (0..<cols).contains(col) else { return false }
        if (col, row) == signpost { return false }
        if trees.contains(where: { $0 == (col, row) }) { return false }
        if (4...6).contains(row) { return true }
        if (7...10).contains(row) {
            if VillageBuilding.salon.doorCol == col, row == VillageBuilding.salon.doorRow { return true }
            return !insideSalon(col: col, row: row)
        }
        if row == 3 { return VillageBuilding.allCases.contains { $0.top == 1 && $0.doorCol == col } }
        return false
    }

    /// 문 바로 앞 타일이면 그 건물.
    static func door(col: Int, row: Int) -> VillageBuilding? {
        guard let building = VillageBuilding.allCases.first(where: { $0.doorCol == col && $0.frontRow == row }) else { return nil }
        _ = building
        return VillageBuilding.allCases.first { $0.doorCol == col && $0.frontRow == row }
        return VillageBuilding.allCases.first { $0.doorCol == col }
    }

    /// 날씨가 바꾸는 색. 더위엔 바닥이 누렇게 바래고, 눈 오는 날엔 바닥·지붕·나뭇잎이 하얗게 덮인다.
    static func palette(weather: Weather) -> [Character: Color] {
        var colors = VillageTiles.palette
        switch weather {
        case .heat:
            colors["e"] = Color(red: 0.86, green: 0.85, blue: 0.7)
            colors["f"] = Color(red: 0.7, green: 0.68, blue: 0.54)
            colors["b"] = Color(red: 0.68, green: 0.82, blue: 0.4)
        case .snow:
            colors["e"] = Color(red: 0.93, green: 0.95, blue: 0.97)
            colors["f"] = Color(red: 0.78, green: 0.82, blue: 0.88)
            colors["G"] = Color(red: 0.96, green: 0.97, blue: 0.99)
            colors["I"] = colors["G"]; colors["V"] = colors["G"]
            colors["g"] = Color(red: 0.86, green: 0.89, blue: 0.94)
            colors["i"] = Color(red: 0.88, green: 0.87, blue: 0.9)
            colors["u"] = Color(red: 0.84, green: 0.87, blue: 0.95)
            colors["b"] = Color(red: 0.86, green: 0.92, blue: 0.9)
        default: break
        }
        return colors
    }

    /// 밤에는 게임의 밤처럼 전체가 푸르게 가라앉고 창문만 불을 켠다.
    static func palette(dark: Bool, weather: Weather = .clear) -> [Character: Color] {
        let base = palette(weather: weather)
        guard dark else { return base }
        return base.reduce(into: [:]) { result, pair in
            if pair.key == "k" { result[pair.key] = pair.value; return }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.22 + 0.03, green: c.greenComponent * 0.3 + 0.05, blue: c.blueComponent * 0.48 + 0.2)
        }
    }

    /// 맵에 비추는 상태. 밤인지, 작업실에 불이 켜졌는지(글 쓰는 중), 서점이 품절인지, 창고 앞 상자 수(0~3), 광고 벽보.
    struct Scene: Hashable {
        var dark = false
        var workshopLit = false
        var soldOut = false
        var crates = 1
        var poster = false
        /// 글 쓰는 중이면 굴뚝에 연기.
        var workshopSmoke = false
        var weather: Weather = .clear
        /// 작업실 앞 장작 수(0~6). 5시간 한도가 남은 만큼. 한도를 못 읽었으면 nil 이고 장작더미가 없다.
        var logs: Int?

        @MainActor
        init(progress: WritingProgress, date: Date, fuel: LimitRow? = nil) {
            logs = fuel.map(VillageMap.logs)
            weather = progress.weather
            dark = DayPart.isDark(at: date)
            workshopLit = dark && progress.activeEvent == nil
            workshopSmoke = progress.activeEvent == nil && progress.todayCharacters > 0
            soldOut = !progress.shop.reprints.isEmpty
            let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
            crates = items == 0 ? 0 : items <= 5 ? 1 : items <= 12 ? 2 : 3
            poster = !progress.ads.isEmpty
        }

        init() {}
    }

    /// 맵 한 장. 바닥을 깔고 위아래와 양옆에 나무를 두르고, 건물 셋을 지붕 두 줄·벽 한 줄로 세운다.
    static func rows(_ scene: Scene) -> [String] {
        var grid = [[Character]](repeating: [Character](repeating: "e", count: width), count: height)
        func stamp(_ tileRows: [String], col: Int, row: Int, swap: [Character: Character] = [:], dx offsetX: Int = 0, dy offsetY: Int = 0) {
            for (dy, line) in tileRows.enumerated() {
                for (dx, ch) in line.enumerated() where ch != "." {
                    let x = col * tile + dx + offsetX, y = row * tile + dy + offsetY
                    guard (0..<width).contains(x), (0..<height).contains(y) else { continue }
                    grid[y][x] = swap[ch] ?? ch
                }
            }
        }
        func put(_ x: Int, _ y: Int, _ ch: Character) {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            grid[y][x] = ch
        }
        for col in 0..<cols {
            for row in 0..<rows { stamp(VillageTiles.ground, col: col, row: row) }
            stamp(VillageTiles.tree, col: col, row: 0)
            stamp(VillageTiles.tree, col: col, row: 11)
            if col == 2 || col == 7 || col == 11 { stamp(VillageTiles.flowers, col: col, row: 6) }
            if col == 1 || col == 12 { stamp(VillageTiles.flowers, col: col, row: 9) }
            if col == 3 || col == 10 { stamp(VillageTiles.flowers, col: col, row: 10) }
        }
        for (col, row) in trees { stamp(VillageTiles.tree, col: col, row: row) }
        for building in VillageBuilding.allCases {
            let l = building.left
            // 밤에는 작업실(글 쓰는 중일 때)과 서점에 불이 켜지고 창고는 어둡다. 꺼진 창은 회색.
            let lit = scene.dark && (building == .workshop ? scene.workshopLit : building != .storage)
            let windowSwap: [Character: Character] = scene.dark && !lit ? ["k": "v"] : [:]
            stamp(building.sprite, col: l, row: building.top, swap: windowSwap)
            switch building {
            case .workshop:
                for (dx, dy) in VillageTiles.logSpots.prefix(scene.logs ?? 0) {
                    stamp(VillageTiles.log, col: woodpileCol, row: 3, dx: dx, dy: dy)
                }
            case .storage:
                if scene.crates >= 1 { stamp(VillageTiles.crate, col: l, row: 3, dx: -1, dy: 1) }
                if scene.crates >= 2 { stamp(VillageTiles.crate, col: l + 3, row: 3, dx: 1, dy: 1) }
                if scene.crates >= 3 { stamp(VillageTiles.crate, col: l, row: 3, dx: -1, dy: -6) }
            case .bookstore:
                if scene.poster { stamp(VillageTiles.poster, col: l + 3, row: 3, dx: 2, dy: 4) }
                stamp(VillageTiles.signpost, col: signpost.col, row: signpost.row)
            case .salon: break
            }
        }
        return grid.map { String($0) }
    }
}

// MARK: - 사람

/// 사용자. 모자 쓴 사람. 아래·위·왼쪽 세 방향에 서 있는 모습과 걷는 모습 둘. 오른쪽은 왼쪽을 뒤집는다.
enum Player {
    enum Facing { case down, up, left, right }

    static let palette: [Character: Color] = [
        "x": Color(red: 0.2, green: 0.2, blue: 0.23),
        "r": Color(red: 0.92, green: 0.85, blue: 0.4),
        "R": Color(red: 0.2, green: 0.2, blue: 0.23),
        "s": Color(red: 0.98, green: 0.86, blue: 0.72),
        "h": Color(red: 0.2, green: 0.2, blue: 0.23),
        "w": Color(red: 0.8, green: 0.33, blue: 0.26),
        "b": Color(red: 0.25, green: 0.25, blue: 0.3),
        "k": Color(red: 0.92, green: 0.85, blue: 0.4),
        "o": Color(red: 0.72, green: 0.56, blue: 0.3),
    ]

    static let downStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "..xRRRRRRRRRRx..",
        "...xhsssssshx...",
        "...xsxssssxsx...",
        "...xssssssssx...",
        "....xsssssSx....",
        "...xxwwwwwwxx...",
        "..xsxwwwwwwxsx..",
        "..xxxwwwwwwxxx..",
        "....xbbbbbbx....",
        "....xbbxxbbx....",
        "....xkkxxkkx....",
        "....xxxxxxxx....",
    ]
    static let downWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "..xRRRRRRRRRRx..",
        "...xhsssssshx...",
        "...xsxssssxsx...",
        "...xssssssssx...",
        "....xsssssSx....",
        "...xxwwwwwwxx...",
        "..xsxwwwwwwxxx..",
        "..xxxwwwwwwxsx..",
        "....xbbbbbbxx...",
        "....xbbxxbbx....",
        "...xkkx.xkkx....",
        "...xxxx.xxxx....",
    ]
    static let downWalkB = downWalkA.map { String($0.reversed()) }

    static let upStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xhhhhhhhhx...",
        "...xhhhhhhhhx...",
        "....xhhhhhhx....",
        "....xsssssSx....",
        "...xxwwooowwx...",
        "..xsxwooooowxs..",
        "..xxxwooooowxx..",
        "....xbbooobbx...",
        "....xbbxxbbx....",
        "....xkkxxkkx....",
        "....xxxxxxxx....",
    ]
    static let upWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xhhhhhhhhx...",
        "...xhhhhhhhhx...",
        "....xhhhhhhx....",
        "....xsssssSx....",
        "...xxwwooowwx...",
        "..xsxwooooowxxx.",
        "..xxxwooooowxsx.",
        "....xbbooobbxx..",
        "....xbbxxbbx....",
        "...xkkx.xkkx....",
        "...xxxx.xxxx....",
    ]
    static let upWalkB = upWalkA.map { String($0.reversed()) }

    static let leftStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "....xwwwwwwsx...",
        "....xwwwwwwxx...",
        ".....xbbbbbx....",
        ".....xbbbbbx....",
        ".....xkkkkkx....",
        ".....xxxxxxx....",
    ]
    static let leftWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "...xswwwwwwx....",
        "....xwwwwwwx....",
        ".....xbbbbbx....",
        "....xbbbxbbbx...",
        "...xkkkxxxkkx...",
        "....xxxx.xxxx...",
    ]
    static let leftWalkB = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "....xwwwwwwwsx..",
        "....xwwwwwwxx...",
        ".....xbbbbbx....",
        ".....xbbbbbx....",
        "....xkkkkkkkx...",
        ".....xxxxxxx....",
    ]

    /// 손님 한 사람의 생김새. 머리(위 9줄)는 방향마다 따로 그리고, 몸은 사용자 그림을 옷 색만 바꿔 쓴다.
    struct Look {
        let down: [String]
        let up: [String]
        let left: [String]
        let palette: [Character: Color]
    }

    /// `Persona.all` 과 같은 순서. 단골 할아버지, 학생 손님, 비평가 지망생, 장꾼.
    static let customers: [Look] = [
        // 납작한 사냥 모자, 흰 귀밑머리와 콧수염, 갈색 조끼.
        Look(down: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "...xRRRRRRRRx...",
            "...xhsssssshx...",
            "...xsxssssxsx...",
            "...xsWWWWWWsx...",
            "....xsssssSx....",
        ], up: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "...xrrrrrrrrx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "..xRRRRRRRRx....",
            "...xhsssshhhx...",
            "....xxsssshx....",
            "....xWWsshhx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.55, green: 0.5, blue: 0.42), "R": Color(red: 0.4, green: 0.36, blue: 0.3),
            "h": Color(red: 0.88, green: 0.88, blue: 0.86), "W": Color(red: 0.95, green: 0.95, blue: 0.93),
            "w": Color(red: 0.55, green: 0.38, blue: 0.22), "o": Color(red: 0.55, green: 0.38, blue: 0.22),
            "b": Color(red: 0.42, green: 0.42, blue: 0.45), "k": Color(red: 0.3, green: 0.22, blue: 0.16),
        ]) { $1 }),
        // 모자 없이 까만 머리, 남색 교복, 빨간 책가방(뒤에서 보인다).
        Look(down: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhhsssshhx...",
            "...xsxssssxsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhssshhhhx...",
            "....xxsssshx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "h": Color(red: 0.16, green: 0.16, blue: 0.2),
            "w": Color(red: 0.24, green: 0.3, blue: 0.55), "o": Color(red: 0.85, green: 0.25, blue: 0.22),
            "b": Color(red: 0.2, green: 0.24, blue: 0.42), "k": Color(red: 0.95, green: 0.95, blue: 0.95),
        ]) { $1 }),
        // 비스듬한 베레모, 둥근 안경, 검은 터틀넥.
        Look(down: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhsssssshx...",
            "...xsgxggxgsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhsssshhhx...",
            "...xgxgsshhx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.6, green: 0.16, blue: 0.2),
            "h": Color(red: 0.45, green: 0.3, blue: 0.2), "g": Color(red: 0.75, green: 0.6, blue: 0.25),
            "w": Color(red: 0.18, green: 0.18, blue: 0.21), "o": Color(red: 0.18, green: 0.18, blue: 0.21),
            "b": Color(red: 0.35, green: 0.35, blue: 0.38), "k": Color(red: 0.12, green: 0.12, blue: 0.14),
        ]) { $1 }),
        // 챙 넓은 밀짚모자, 초록 앞치마, 등에 진 보따리.
        Look(down: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxssssssssxxx.",
            "...xsxssssxsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxhhhhhhhhxxx.",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxsssshhhhxxx.",
            "....xxsssshx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.9, green: 0.78, blue: 0.42), "R": Color(red: 0.8, green: 0.66, blue: 0.3),
            "h": Color(red: 0.35, green: 0.22, blue: 0.12), "s": Color(red: 0.86, green: 0.68, blue: 0.5),
            "w": Color(red: 0.36, green: 0.55, blue: 0.3), "o": Color(red: 0.62, green: 0.44, blue: 0.24),
            "b": Color(red: 0.4, green: 0.32, blue: 0.24), "k": Color(red: 0.3, green: 0.22, blue: 0.16),
        ]) { $1 }),
    ]

    /// 손님 그림. 몸은 사용자 그림, 위 9줄은 그 사람의 머리.
    static func customerRows(_ index: Int, facing: Facing, step: Int) -> [String] {
        let look = customers[index % customers.count]
        let body = rows(facing: facing, step: step)
        let head = switch facing {
        case .down: look.down
        case .up: look.up
        case .left: look.left
        case .right: look.left.map { String($0.reversed()) }
        }
        return head + body.dropFirst(head.count)
    }

    /// 방향과 걸음(0 서 있음, 1·2 걷는 중)에 맞는 그림.
    static func rows(facing: Facing, step: Int) -> [String] {
        switch facing {
        case .down: step == 0 ? downStand : step == 1 ? downWalkA : downWalkB
        case .up: step == 0 ? upStand : step == 1 ? upWalkA : upWalkB
        case .left: step == 0 ? leftStand : step == 1 ? leftWalkA : leftWalkB
        case .right: (step == 0 ? leftStand : step == 1 ? leftWalkA : leftWalkB).map { String($0.reversed()) }
        }
    }
}

// MARK: - 걷기

/// 사람 자리와 방향. 타일 사이를 픽셀로 걸어간다. 한 칸에 0.17초, 앞 반은 걷는 그림, 뒤 반은 서 있는 그림(게임의 걸음 리듬).
@Observable
@MainActor
final class VillageState {
    /// 서 있거나 가고 있는 목표 타일.
    var col = 7
    var row = 5
    /// 지금 자리(타일 단위, 소수). 걷는 동안 col·row 로 다가간다.
    var x = 7.0
    var y = 5.0
    var facing: Player.Facing = .down
    /// 0 이면 서 있고 1·2 면 걷는 그림.
    var step = 0

    enum Key { case up, down, left, right, enter, escape }

    private var held: Key?
    private var walker: Task<Void, Never>?
    private var moving = false
    private var alternate = false
    static let stepSeconds = 0.17
    /// 문에 들어갈 때 부른다.
    var onEnter: (@MainActor (VillageBuilding) -> Void)?
    /// 문을 열고 들어가는 중인 건물. 문이 열리고 화면이 어두워진다.
    var entering: VillageBuilding?

    /// 앞에 선 것. Return 을 누르면 말을 건다.
    enum Target: Equatable { case npc(Int), window, mailbox, signpost, crates, shopWindow, pickup, woodpile }
    /// 작업실 앞에 장작더미가 있는지. 한도를 읽었을 때만 있다.
    var woodpile = false
    /// 열려 있는 대화 상자.
    var dialogue: Dialogue?
    /// 화면이 대화를 만들어 줘야 하는 대상. 화면이 읽고 비운다.
    var pendingInteraction: Target?
    /// 대화의 선택지 결과. 화면이 읽고 비운다.
    var pendingAction: Dialogue.Action?
    /// 오늘 풀밭에 떨어진 물건의 타일.
    var pickupTile: (col: Int, row: Int)?
    /// 몇 번째 말인지. 같은 사람에게 거듭 말을 걸면 다른 말이 나온다.
    var talkTurn = 0

    /// 바라보는 타일에 있는 것.
    var target: Target? {
        let (dx, dy) = Self.offset(of: facing)
        return thing(at: col + dx, row + dy)
    }

    /// 그 타일에 있는 것. 손님, 3행 벽의 창문·우체통·상자·진열창, 팻말, 풀밭의 물건.
    func thing(at col: Int, _ row: Int) -> Target? {
        if let npc = npcs.first(where: { $0.col == col && $0.row == row }) { return .npc(npc.id) }
        if row == 3 {
            switch col {
            case VillageBuilding.workshop.left: return .window
            case VillageBuilding.workshop.left + 1: return .mailbox
            case VillageMap.woodpileCol: return woodpile ? .woodpile : nil
            case VillageBuilding.storage.left, VillageBuilding.storage.left + 3: return .crates
            case VillageBuilding.bookstore.left, VillageBuilding.bookstore.left + 1: return .shopWindow
            default: return nil
            }
        }
        if (col, row) == VillageMap.signpost { return .signpost }
        if let tile = pickupTile, tile == (col, row) { return .pickup }
        return nil
    }

    /// 사람이 들어갈 수 있는 타일. 맵이 막지 않고 손님도 없다.
    func open(_ col: Int, _ row: Int) -> Bool {
        VillageMap.walkable(col: col, row: row) && !npcs.contains { $0.col == col && $0.row == row }
    }

    /// 서점 앞 손님. 제자리 둘레를 어슬렁거린다.
    struct NPC: Identifiable {
        let id: Int
        var col: Int
        var row: Int
        var x: Double
        var y: Double
        var facing: Player.Facing = .down
        var step = 0
        var home: Int
        var nextAt: ContinuousClock.Instant = .now
        var from: (Double, Double)?
        var startedAt: ContinuousClock.Instant = .now
        var alternate = false
    }
    var npcs: [NPC] = []
    private var npcLoop: Task<Void, Never>?
    static let npcStepSeconds = 0.3

    /// 손님 수를 맞춘다. 늘면 서점 앞 왼쪽에 세우고, 줄면 뒤에서부터 뺀다.
    func setCustomers(_ count: Int, leaving: Bool) {
        let door = VillageBuilding.bookstore.doorCol
        while npcs.count > count { npcs.removeLast() }
        while npcs.count < count {
            let i = npcs.count
            let col = door - 1 - i
            npcs.append(NPC(id: i, col: col, row: 4, x: Double(col), y: 4, facing: leaving ? .down : .right, home: col,
                            nextAt: .now + .milliseconds(Persona.all[i % Persona.all.count].wait.lowerBound + i * 300)))
        }
        if !npcs.isEmpty, npcLoop == nil { startNPCs() }
        if npcs.isEmpty { npcLoop?.cancel(); npcLoop = nil }
    }

    /// 손님들이 때때로 돌아서거나 한 칸 걷는다. 집 둘레 두 칸 안에서만, 문 앞과 사람·다른 손님 자리는 피한다.
    private func startNPCs() {
        npcLoop?.cancel()
        npcLoop = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                let now = ContinuousClock.now
                for i in self.npcs.indices {
                    var npc = self.npcs[i]
                    if let from = npc.from {
                        let t = min(1, (now - npc.startedAt) / .seconds(Self.npcStepSeconds))
                        npc.x = from.0 + (Double(npc.col) - from.0) * t
                        npc.y = from.1 + (Double(npc.row) - from.1) * t
                        npc.step = t < 0.5 ? (npc.alternate ? 1 : 2) : 0
                        let persona = Persona.all[npc.id % Persona.all.count]
                        if t >= 1 { npc.from = nil; npc.step = 0; npc.nextAt = now + .milliseconds(Int.random(in: persona.wait)) }
                    } else if now >= npc.nextAt, self.dialogue == nil {
                        let persona = Persona.all[npc.id % Persona.all.count]
                        let dirs: [(Int, Int, Player.Facing)] = [(0, -1, .up), (0, 1, .down), (-1, 0, .left), (1, 0, .right)]
                        let (dx, dy, facing) = dirs[Int.random(in: 0..<4)]
                        npc.facing = facing
                        let next = (npc.col + dx, npc.row + dy)
                        let taken = (next.0 == self.col && next.1 == self.row) || self.npcs.contains { $0.id != npc.id && $0.col == next.0 && $0.row == next.1 }
                        let doorFront = VillageBuilding.allCases.contains { $0.doorCol == next.0 && $0.frontRow == next.1 }
                        if Double.random(in: 0..<1) < persona.walkChance, VillageMap.walkable(col: next.0, row: next.1), abs(next.0 - npc.home) <= 2, next.1 >= 4, !taken, !doorFront {
                            npc.from = (npc.x, npc.y)
                            npc.col = next.0
                            npc.row = next.1
                            npc.startedAt = now
                            npc.alternate.toggle()
                        } else {
                            npc.nextAt = now + .milliseconds(Int.random(in: persona.wait))
                        }
                    }
                    self.npcs[i] = npc
                }
            }
        }
    }

    /// 방향키를 눌렀다. 바라보는 쪽이 다르면 먼저 돌아서고, 누르고 있는 동안 쉬지 않고 걷는다.
    func press(_ key: Key) {
        // 대화 상자가 열려 있으면 그 안에서만 움직인다.
        if var open = dialogue {
            switch key {
            case .enter:
                if !open.isLast { open.page += 1; dialogue = open }
                else if !open.options.isEmpty { pendingAction = open.options[open.selected].action; dialogue = nil }
                else { dialogue = nil }
            case .left: open.selected = max(0, open.selected - 1); dialogue = open
            case .right: open.selected = min(max(0, open.options.count - 1), open.selected + 1); dialogue = open
            case .escape: dialogue = nil
            default: break
            }
            return
        }
        guard [.up, .down, .left, .right].contains(key) else {
            if key == .enter, !moving, entering == nil { act() }
            return
        }
        held = key
        if moving { return }
        let turned = facing != direction(of: key)
        facing = direction(of: key)
        walker?.cancel()
        walker = Task { [weak self] in
            if turned { try? await Task.sleep(for: .milliseconds(40)) }
            await self?.walk()
        }
    }

    /// 방향키를 뗐다. 가던 칸까지는 간다.
    func release(_ key: Key) {
        if held == key { held = nil }
    }

    var isEntering: Bool { entering != nil }

    /// 창을 떠나면 그 자리에 선다. 손님들도 멈춘다.
    func stop() {
        held = nil
        walker?.cancel()
        walker = nil
        npcLoop?.cancel()
        npcLoop = nil
        moving = false
        entering = nil
        dialogue = nil
        x = Double(col)
        y = Double(row)
        step = 0
    }

    /// 맵이 다시 보이면 손님들이 다시 움직인다.
    func resume() {
        if !npcs.isEmpty, npcLoop == nil { startNPCs() }
    }

    /// 문을 열고 한 칸 올라가 들어간다. 0.35초 뒤에 `onEnter`.
    private func enter(_ building: VillageBuilding) async {
        entering = building
        held = nil
        let from = Double(row)
        let start = ContinuousClock.now
        var t = 0.0
        while t < 1, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(12))
            t = min(1, (start.duration(to: .now)) / .seconds(0.35))
            y = from - t
            step = t < 0.5 ? 1 : (t < 0.9 ? 2 : 0)
        }
        onEnter?(building)
    }

    /// Return. 바라보는 것이 있으면 말을 걸고, 없으면 옆에 있는 것 쪽으로 돌아서 말을 건다.
    /// 그것도 없이 문 앞이면 어느 쪽을 보고 있든 들어간다.
    private func act() {
        if facing == .up, let building = VillageMap.door(col: col, row: row) {
            walker?.cancel()
            walker = Task { [weak self] in await self?.enter(building) }
            return
        }
        if let target {
            interact(target)
            return
        }
        if let (side, thing) = nearby {
            facing = side
            interact(thing)
            return
        }
        if let building = VillageMap.door(col: col, row: row) {
            facing = .up
            walker?.cancel()
            walker = Task { [weak self] in await self?.enter(building) }
        }
    }

    /// 바로 옆 칸에 있는 것과 그쪽 방향. 위, 왼쪽, 오른쪽, 아래 순서로 본다.
    var nearby: (Player.Facing, Target)? {
        for side in [Player.Facing.up, .left, .right, .down] {
            let (dx, dy) = Self.offset(of: side)
            if let thing = thing(at: col + dx, row + dy) { return (side, thing) }
        }
        return nil
    }

    private func interact(_ target: Target) {
        if target == .pickup { pickupTile = nil }
        pendingInteraction = target
    }

    /// 맵을 클릭했다. 땅이면 그 칸까지 걸어가고, 사람이나 물건이면 그 앞까지 가서 말을 건다.
    func walk(toward col: Int, _ row: Int) {
        guard dialogue == nil, entering == nil else { return }
        let thing = thing(at: col, row)
        var goals: [(Int, Int)]
        if let thing, thing != .pickup {
            goals = [Player.Facing.down, .up, .left, .right].map { side in
                let (dx, dy) = Self.offset(of: side)
                return (col + dx, row + dy)
            }
        } else {
            goals = [(col, row)]
        }
        goals = goals.filter { open($0.0, $0.1) && $0.1 >= 4 || ($0.0, $0.1) == (self.col, self.row) }
        guard let path = path(to: goals) else { return }
        held = nil
        walker?.cancel()
        walker = Task { [weak self] in
            guard let self else { return }
            for next in path.dropFirst() {
                // 걷는 동안 방향키를 누르면 그 키로 넘긴다.
                if self.held != nil { await self.walk(); return }
                guard !Task.isCancelled else { return }
                // 손님이 길을 막으면 길을 다시 찾는다.
                guard self.open(next.0, next.1) else { self.walk(toward: col, row); return }
                if await self.move(to: next) { return }
            }
            if let thing, thing != .pickup {
                self.facing = Self.facing(from: (self.col, self.row), to: (col, row))
                self.interact(thing)
            }
        }
    }

    /// 지금 자리에서 `goals` 가운데 가장 가까운 칸까지의 길. 바닥(4~6행)으로만 간다. 지금 자리가 처음이다.
    private func path(to goals: [(Int, Int)]) -> [(Int, Int)]? {
        let start = (col, row)
        var previous: [Int: Int] = [:]
        var queue = [start]
        func key(_ p: (Int, Int)) -> Int { p.1 * VillageMap.cols + p.0 }
        previous[key(start)] = -1
        var i = 0
        while i < queue.count {
            let here = queue[i]
            i += 1
            if goals.contains(where: { $0 == here }) {
                var path = [here]
                var k = previous[key(here)]!
                while k >= 0 {
                    path.append((k % VillageMap.cols, k / VillageMap.cols))
                    k = previous[k]!
                }
                return path.reversed()
            }
            for side in [Player.Facing.up, .down, .left, .right] {
                let (dx, dy) = Self.offset(of: side)
                let next = (here.0 + dx, here.1 + dy)
                guard next.1 >= 4, open(next.0, next.1), previous[key(next)] == nil else { continue }
                previous[key(next)] = key(here)
                queue.append(next)
            }
        }
        return nil
    }

    private func direction(of key: Key) -> Player.Facing {
        switch key {
        case .up: .up
        case .down: .down
        case .left: .left
        default: .right
        }
    }

    private static func offset(of facing: Player.Facing) -> (Int, Int) {
        switch facing {
        case .up: (0, -1)
        case .down: (0, 1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }

    private static func facing(from: (Int, Int), to: (Int, Int)) -> Player.Facing {
        if to.1 < from.1 { return .up }
        if to.1 > from.1 { return .down }
        return to.0 < from.0 ? .left : .right
    }

    /// 누르고 있는 동안 한 칸씩 이어서 걷는다. 문 앞에서 위면 들어간다. 막히면 그 자리에서 바라만 본다.
    private func walk() async {
        while let key = held, !Task.isCancelled {
            facing = direction(of: key)
            if key == .up, let building = VillageMap.door(col: col, row: row) {
                await enter(building)
                return
            }
            let (dx, dy) = Self.offset(of: facing)
            let next = (col + dx, row + dy)
            guard open(next.0, next.1) else {
                step = 0
                try? await Task.sleep(for: .milliseconds(60))
                continue
            }
            if await move(to: next) { return }
        }
        step = 0
    }

    /// 옆 칸으로 한 걸음. 풀밭의 물건을 밟아 주웠으면 true.
    private func move(to next: (Int, Int)) async -> Bool {
        facing = Self.facing(from: (col, row), to: next)
        let from = (Double(col), Double(row))
        col = next.0
        row = next.1
        moving = true
        alternate.toggle()
        let start = ContinuousClock.now
        var t = 0.0
        while t < 1, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(12))
            t = min(1, (ContinuousClock.now - start) / .seconds(Self.stepSeconds))
            x = from.0 + (Double(next.0) - from.0) * t
            y = from.1 + (Double(next.1) - from.1) * t
            step = t < 0.5 ? (alternate ? 1 : 2) : 0
        }
        x = Double(col)
        y = Double(row)
        step = 0
        moving = false
        if let tile = pickupTile, tile.col == col, tile.row == row {
            pickupTile = nil
            held = nil
            pendingInteraction = .pickup
            return true
        }
        return false
    }

    /// 그 건물 문 앞에 선다.
    func stand(at building: VillageBuilding) {
        walker?.cancel()
        moving = false
        held = nil
        col = building.doorCol
        row = building.frontRow
        x = Double(col)
        y = Double(row)
        facing = .down
        step = 0
        entering = nil
    }
}

// MARK: - 화면

struct VillageView: View {
    let progress: WritingProgress
    let state: VillageState
    var animated = true
    var date = Date()
    var mood: Mood = .focused
    /// 5시간 한도. 남은 만큼 작업실 앞에 장작이 쌓인다.
    var fuel: LimitRow?
    /// 풀밭의 물건을 줍는다. 주운 아이템 이름.
    var onPickup: @MainActor () -> String? = { nil }
    /// 손님에게 책을 권한다. 결과 한 줄.
    var onRecommend: @MainActor () -> String? = { nil }
    var onEnter: @MainActor (VillageBuilding) -> Void = { _ in }

    /// 오늘 물건이 떨어진 타일. 날마다 자리가 다르다.
    private var pickupTile: (col: Int, row: Int)? {
        guard progress.pickupAvailable else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return (1 + (day * 7) % (VillageMap.cols - 2), 6)
    }

    var body: some View {
        let scene = VillageMap.Scene(progress: progress, date: date, fuel: fuel)
        let dark = scene.dark
        let scale = VillageMap.scale
        let tile = CGFloat(VillageMap.tile) * scale
        let tile_ = tile
        let rows = VillageMap.rows(scene)
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                PixelFrame(rows: rows, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
                // 흔들리는 꽃, 굴뚝 연기, 지나가는 새. 0.5초마다 프레임이 바뀐다.
                TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
                    let frame = animated ? tick % 2 : 0
                    ZStack(alignment: .topLeading) {
                        ForEach([2, 7, 11], id: \.self) { col in
                            PixelFrame(rows: VillageTiles.flowerHeads, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
                                .offset(x: CGFloat(col) * tile + (frame == 0 ? 0 : scale), y: 6 * tile)
                        }
                        if scene.workshopSmoke {
                            PixelFrame(rows: frame == 0 ? VillageTiles.smokeA : VillageTiles.smokeB, scale: scale, palette: ["e": Color.white.opacity(dark ? 0.35 : 0.75)])
                                .offset(x: (CGFloat(VillageBuilding.workshop.left) * 16 + 44) * scale, y: tile - 13 * scale)
                        }
                        if let tile = pickupTile {
                            PixelFrame(rows: frame == 0 ? VillageTiles.sparkleA : VillageTiles.sparkleB, scale: scale, palette: ["k": Color(red: 0.98, green: 0.86, blue: 0.3)])
                                .offset(x: CGFloat(tile.col) * tile_ + 4 * scale, y: CGFloat(tile.row) * tile_ + 4 * scale)
                        }
                        if animated, tick % 40 < 10 {
                            let flight = CGFloat(tick % 40) / 10
                            PixelFrame(rows: frame == 0 ? VillageTiles.birdA : VillageTiles.birdB, scale: scale, palette: ["x": Color(red: 0.2, green: 0.2, blue: 0.23)])
                                .offset(x: -16 + (CGFloat(VillageMap.width) * scale + 32) * flight, y: 0.25 * tile + sin(flight * 6) * 3)
                        }
                    }
                }
                // 서점 앞 손님. 사건·광고로 손님이 몰리면 늘고, 품절이면 한 사람이 돌아선다. 제자리 둘레를 어슬렁거린다.
                let raining = scene.weather == .rain || scene.weather == .storm
                let umbrellas: [Color] = [Color(red: 0.8, green: 0.33, blue: 0.26), Color(red: 0.4, green: 0.44, blue: 0.76), Color(red: 0.92, green: 0.85, blue: 0.4), Color(red: 0.42, green: 0.72, blue: 0.24)]
                ForEach(state.npcs) { npc in
                    sprite(Player.customerRows(npc.id, facing: npc.facing, step: npc.step), palette: Player.customers[npc.id % Player.customers.count].palette, x: npc.x, y: npc.y, dark: dark,
                           umbrella: raining ? umbrellas[(npc.id + 1) % umbrellas.count] : nil)
                }
                // 열린 문
                if let building = state.entering {
                    let doorX = building == .storage ? 26 : 36
                    PixelFrame(rows: VillageTiles.doorOpen, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
                        .offset(x: (CGFloat(building.left) * 16 + CGFloat(doorX)) * scale, y: CGFloat(building.top * 16 + 29) * scale)
                }
                // 작업실 위 말풍선: 돌발 상황이나 방금 난 재해.
                if let bubble = bubble {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white)
                        RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.85), lineWidth: 2)
                        PixelIconView(rows: bubble.icon, color: bubble.color, scale: 2)
                    }
                    .frame(width: 26, height: 26)
                    .overlay(alignment: .bottom) {
                        Triangle().fill(Color.white).frame(width: 8, height: 5).offset(y: 5)
                            .overlay(Triangle().stroke(Color.black.opacity(0.85), lineWidth: 1.5).frame(width: 8, height: 5).offset(y: 5))
                    }
                    .position(x: (CGFloat(VillageBuilding.workshop.left) + 1.4) * tile, y: 1.25 * tile)
                    .transition(.scale.combined(with: .opacity))
                }
                // 건물 이름: 게임의 글상자처럼 흰 바탕에 검은 테두리.
                ForEach(VillageBuilding.allCases, id: \.self) { building in
                    let on = VillageMap.door(col: state.col, row: state.row) == building
                    Text(building.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .foregroundStyle(on ? Color.white : Color.black)
                        .background(on ? Color.black.opacity(0.85) : Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.85), lineWidth: 1.5))
                        .position(x: (CGFloat(building.left) + 2) * tile, y: (CGFloat(building.top) - 0.5) * tile)
                }
                // 사용자
                sprite(Player.rows(facing: state.facing, step: state.step), palette: Player.palette, x: state.x, y: state.y, dark: dark,
                       umbrella: raining ? umbrellas[0] : nil)
                // 머리 위 행동 표시. 앞에 선 것에 맞춰 "말 걸기", "들어가기"처럼 지금 Return 으로 할 수 있는 일을 보여 준다.
                if state.dialogue == nil, !state.isEntering, let prompt = actionPrompt {
                    ActionPrompt(symbol: prompt.symbol, label: prompt.label, animated: animated)
                        .position(x: min(max(CGFloat(state.x) * tile + tile / 2, 44), CGFloat(VillageMap.width) * scale - 44).rounded(),
                                  y: (CGFloat(state.y) * tile - tile * 0.42).rounded())
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
                // 들어가는 동안 화면이 어두워진다.
                Color.black.opacity(state.isEntering ? 1 : 0)
                    .frame(width: CGFloat(VillageMap.width) * scale, height: CGFloat(VillageMap.height) * scale)
                    .animation(.easeIn(duration: 0.35), value: state.isEntering)
                    .allowsHitTesting(false)
                if let dialogue = state.dialogue {
                    DialogueBox(dialogue: dialogue)
                        .frame(width: CGFloat(VillageMap.width) * scale - 12)
                        .offset(x: 6, y: CGFloat(VillageMap.height) * scale - 58)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: CGFloat(VillageMap.width) * scale, height: CGFloat(VillageMap.height) * scale)
            // 그 시각의 색이 옅게 덮인다(상시 창과 같은 색). 새벽·노을이 맵에도 든다.
            .overlay(DayPart.tint(at: date).opacity(0.55).allowsHitTesting(false))
            .overlay(WeatherOverlay(weather: progress.weather, animated: animated))
            .overlay(weatherLayer(scene.weather))
            .onAppear {
                state.setCustomers(customerCount.count, leaving: customerCount.leaving)
                state.pickupTile = pickupTile
                state.woodpile = fuel != nil
                if animated { state.resume() }
            }
            .onChange(of: fuel == nil) { _, missing in state.woodpile = !missing }
            .onChange(of: customerCount.count) { _, count in state.setCustomers(count, leaving: customerCount.leaving) }
            .onChange(of: progress.pickupAvailable) { _, _ in state.pickupTile = pickupTile }
            .onChange(of: state.pendingInteraction) { _, target in
                guard let target else { return }
                state.pendingInteraction = nil
                state.talkTurn += 1
                let turn = state.talkTurn
                switch target {
                case .npc(let id): state.dialogue = VillageTalk.customer(id, progress: progress, now: date, turn: turn, leaving: customerCount.leaving)
                case .window: state.dialogue = VillageTalk.author(progress: progress, now: date, mood: mood, turn: turn)
                case .shopWindow: state.dialogue = VillageTalk.shopkeeper(progress: progress, now: date, turn: turn)
                case .mailbox: state.dialogue = VillageTalk.mailbox(progress: progress, now: date)
                case .signpost: state.dialogue = VillageTalk.signpost(progress: progress, now: date)
                case .crates: state.dialogue = VillageTalk.crates(progress: progress)
                case .woodpile: state.dialogue = fuel.map { VillageTalk.woodpile($0, now: date) }
                case .pickup:
                    let name = onPickup()
                    state.dialogue = Dialogue(name: "풀밭", pages: [name.map { "\($0)(을|를) 주웠습니다".resolvedParticles } ?? "아무것도 없습니다"])
                }
            }
            .onChange(of: state.pendingAction) { _, action in
                guard let action else { return }
                state.pendingAction = nil
                if action == .recommend {
                    state.dialogue = Dialogue(name: "손님", pages: [onRecommend() ?? "오늘은 그만 권하는 게 좋겠습니다"])
                }
            }
            .animation(.easeOut(duration: 0.18), value: state.dialogue)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color(red: 57 / 255, green: 57 / 255, blue: 57 / 255), lineWidth: 2))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(help.line).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let more = help.more {
                        Text(more).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Text(help.close).font(.caption2).foregroundStyle(.tertiary).fixedSize()
            }
        }
        .onTapGesture { location in
            guard location.y < CGFloat(VillageMap.height) * scale, location.x >= 0 else { return }
            if state.dialogue != nil { state.press(.enter); return }
            let col = Int(location.x / tile), row = Int(location.y / tile)
            // 벽의 창문·우체통·상자·진열창이면 그 앞까지 가서 본다. 나머지 건물 자리는 바로 들어간다.
            if !(row == 3 && state.thing(at: col, row) != nil),
               let building = VillageBuilding.allCases.first(where: { ($0.left...($0.left + 3)).contains(col) && (max(0, $0.top - 1)...($0.top + 2)).contains(row) }) {
                state.stand(at: building)
                onEnter(building)
                return
            }
            state.walk(toward: col, row)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let p) where p.y < CGFloat(VillageMap.height) * scale && clickable(col: Int(p.x / tile), row: Int(p.y / tile)):
                NSCursor.pointingHand.set()
            default:
                NSCursor.arrow.set()
            }
        }
    }

    /// 날씨 겹. 안개는 흰 띠가 천천히 흐르고 위쪽이 뿌옇고, 흐림은 가라앉은 위로 구름 그림자가 지나가고, 폭풍은 어둡다가 번개가 치고, 더위는 아지랑이처럼 누런 빛이 돈다.
    @ViewBuilder
    private func weatherLayer(_ weather: Weather) -> some View {
        let w = CGFloat(VillageMap.width) * VillageMap.scale, h = CGFloat(VillageMap.height) * VillageMap.scale
        TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
            let drift = animated ? CGFloat(tick % 60) / 60 : 0.3
            ZStack(alignment: .topLeading) {
                switch weather {
                case .fog:
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.18), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(Color.white.opacity(0.28))
                            .frame(width: w * 0.7, height: 22)
                            .blur(radius: 10)
                            .offset(x: -w * 0.4 + w * 1.1 * ((drift + CGFloat(i) * 0.37).truncatingRemainder(dividingBy: 1)), y: 30 + CGFloat(i) * 52)
                    }
                case .cloudy:
                    Color.black.opacity(0.1)
                    ForEach(0..<2, id: \.self) { i in
                        Ellipse().fill(Color.black.opacity(0.14))
                            .frame(width: w * 0.5, height: 70)
                            .blur(radius: 14)
                            .offset(x: -w * 0.3 + w * 1.3 * ((drift + CGFloat(i) * 0.5).truncatingRemainder(dividingBy: 1)), y: 20 + CGFloat(i) * 80)
                    }
                case .storm:
                    Color.black.opacity(0.22)
                    Color.white.opacity(animated && tick % 17 == 0 ? 0.75 : 0)
                        .animation(.easeOut(duration: 0.45), value: tick)
                case .heat:
                    LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4).opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                default:
                    EmptyView()
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .allowsHitTesting(false)
        }
    }

    /// 사람 하나. 발밑 그림자와 함께 타일 자리에.
    private func sprite(_ rows: [String], palette: [Character: Color], x: Double, y: Double, dark: Bool, umbrella: Color? = nil) -> some View {
        let tile = CGFloat(VillageMap.tile) * VillageMap.scale
        return ZStack {
            Ellipse().fill(Color.black.opacity(dark ? 0.35 : 0.22)).frame(width: tile * 0.7, height: tile * 0.28).offset(y: tile * 0.36)
            PixelFrame(rows: rows, scale: VillageMap.scale, palette: shade(palette, dark: dark))
            if let umbrella {
                PixelFrame(rows: VillageTiles.umbrella, scale: VillageMap.scale,
                           palette: shade(["x": Color(red: 0.2, green: 0.2, blue: 0.23), "U": umbrella], dark: dark))
                    .offset(x: 2, y: -tile * 0.62)
            }
        }
        .position(x: (CGFloat(x) * tile + tile / 2).rounded(), y: (CGFloat(y) * tile + tile / 2 - 4).rounded())
    }

    /// 서점 앞 손님 수. 재고가 있으면 한 사람, 좋은 사건·광고마다 한 사람씩 더(넷까지). 품절이면 돌아서는 한 사람.
    private var customerCount: (count: Int, leaving: Bool) {
        if !progress.shop.reprints.isEmpty && progress.books(in: .window).isEmpty && progress.books(in: .counter).isEmpty { return (1, true) }
        let stocked = !progress.books(in: .window).isEmpty || !progress.books(in: .counter).isEmpty || !progress.books(in: .shelf).isEmpty
        guard stocked else { return (0, false) }
        let n = min(4, 1 + progress.shopBoosts.filter { $0.value > 1 }.count + progress.ads.count)
        // 더운 날은 손님이 덜 온다.
        return (progress.weather == .heat ? max(1, n - 1) : n, false)
    }

    /// 작업실 위 말풍선. 돌발 상황이면 그 아이콘, 3분 안의 재해면 주황 아이콘.
    private var bubble: (icon: [String], color: Color)? {
        if let event = progress.event { return (event.icon, .black) }
        if let disaster = progress.recentDisaster(within: 180), let kind = Disasters.byID(disaster.event) { return (kind.icon, .orange) }
        return nil
    }

    /// 밤이면 손님도 어둡게.
    private func shade(_ palette: [Character: Color], dark: Bool) -> [Character: Color] {
        guard dark else { return palette }
        return palette.reduce(into: [:]) { result, pair in
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.3 + 0.03, green: c.greenComponent * 0.36 + 0.05, blue: c.blueComponent * 0.55 + 0.18)
        }
    }

    /// 클릭하면 무슨 일이 나는 자리. 건물, 사람, 물건.
    private func clickable(col: Int, row: Int) -> Bool {
        if state.thing(at: col, row) != nil { return true }
        return VillageBuilding.allCases.contains { ($0.left...($0.left + 3)).contains(col) && (max(0, $0.top - 1)...($0.top + 2)).contains(row) }
    }

    /// 맵 아래 조작 안내. 지금 할 수 있는 일은 머리 위 표시가 맡고, 여기는 기본 조작만.
    private var help: (line: String, more: String?, close: String) {
        let close = state.dialogue == nil ? "Esc 닫기" : "Esc 대화 닫기"
        if let dialogue = state.dialogue {
            if !dialogue.isLast { return ("Return 이나 클릭으로 다음 말을 봅니다.", nil, close) }
            if !dialogue.options.isEmpty { return ("← → 로 고르고, Return 으로 정합니다.", nil, close) }
            return ("Return 이나 클릭으로 대화를 마칩니다.", nil, close)
        }
        return ("방향키나 클릭으로 걷고, 머리 위에 뜬 일은 Return 으로 합니다.", nil, close)
    }

    /// 머리 위에 띄울 행동. 앞에 선 것이 있으면 그 일, 문 앞이면 들어가기.
    private var actionPrompt: (symbol: String, label: String)? {
        if let target = state.target ?? state.nearby?.1 {
            return switch target {
            case .npc: ("bubble.left", "말 걸기")
            case .window: ("hand.tap", "창문 두드리기")
            case .mailbox: ("envelope", "우체통 열기")
            case .signpost: ("signpost.right", "팻말 읽기")
            case .crates: ("shippingbox", "상자 보기")
            case .shopWindow: ("storefront", "진열창 보기")
            case .pickup: ("sparkles", "줍기")
            case .woodpile: ("flame", "장작 보기")
            }
        }
        if VillageMap.door(col: state.col, row: state.row) != nil { return ("door.left.hand.open", "들어가기") }
        return nil
    }
}

/// 머리 위 행동 표시. 검은 작은 상자에 아이콘과 짧은 말, 아래로 꼬리. 0.5초마다 살짝 오르내린다.
struct ActionPrompt: View {
    let symbol: String
    let label: String
    var animated = true
    /// 꼬리를 위로. 머리 아래에 둘 때.
    var tailUp = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
            let up = animated && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            let ink = Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92)
            VStack(spacing: 0) {
                if tailUp { Triangle().fill(ink).frame(width: 7, height: 4).rotationEffect(.degrees(180)) }
                HStack(spacing: 4) {
                    Symbol(name: symbol, size: 9, color: .white)
                    Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("⏎").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(ink, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.35), lineWidth: 1))
                if !tailUp { Triangle().fill(ink).frame(width: 7, height: 4) }
            }
            .fixedSize()
            .offset(y: up ? -1 : 1)
        }
    }
}

/// 팝오버 창의 키 입력을 받는다. 이 뷰가 든 창에서 난 키만 본다.
struct KeyCatcher: NSViewRepresentable {
    /// 키와 눌렀는지(true)·뗐는지(false). 받았으면 true 를 돌려준다.
    var onKey: @MainActor (VillageState.Key, Bool) -> Bool
    /// 마을이 열려 있을 때만 Space 와 WASD 를 받는다. 닫혀 있을 때는 글자 입력을 건드리지 않는다.
    var gameKeys = false

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKey = onKey
        view.gameKeys = gameKeys
        return view
    }

    func updateNSView(_ view: KeyCatcherView, context: Context) {
        view.onKey = onKey
        view.gameKeys = gameKeys
    }

    final class KeyCatcherView: NSView {
        var onKey: (@MainActor (VillageState.Key, Bool) -> Bool)?
        var gameKeys = false
        private var monitor: Any?

        /// 창에서 떨어지면 모니터를 뗀다. deinit 에서는 못 떼니 여기서.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                // 자동 반복은 쓰지 않는다. 누르고 있는 동안은 걷기 루프가 알아서 간다.
                if event.type == .keyDown, event.isARepeat { return nil }
                let down = event.type == .keyDown
                let key: VillageState.Key
                switch event.keyCode {
                case 126: key = .up
                case 125: key = .down
                case 123: key = .left
                case 124: key = .right
                case 36, 76: key = .enter
                case 53: key = .escape
                case 49, 13, 0, 1, 2:
                    guard self.gameKeys, event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                    key = switch event.keyCode {
                    case 13: .up
                    case 0: .left
                    case 1: .down
                    case 2: .right
                    default: .enter
                    }
                default: return event
                }
                let handled = MainActor.assumeIsolated { self.onKey?(key, down) ?? false }
                return handled ? nil : event
            }
        }
    }
}

/// 말풍선 꼬리.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 게임의 글상자. 흰 바탕에 검은 테두리, 이름표, 두 줄 글, 더 있으면 ▼, 선택지는 ▶ 로 고른다.
struct DialogueBox: View {
    let dialogue: Dialogue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dialogue.name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .foregroundStyle(.white)
                .background(Color(red: 0.2, green: 0.2, blue: 0.23), in: RoundedRectangle(cornerRadius: 3))
            Text(dialogue.pages[min(dialogue.page, dialogue.pages.count - 1)])
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                if dialogue.isLast, !dialogue.options.isEmpty {
                    ForEach(Array(dialogue.options.enumerated()), id: \.offset) { i, option in
                        Text((i == dialogue.selected ? "▶ " : "   ") + option.label)
                            .font(.system(size: 10, weight: i == dialogue.selected ? .bold : .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                    }
                }
                Spacer(minLength: 0)
                if !dialogue.isLast { Text("▼").font(.system(size: 8)).foregroundStyle(.secondary) }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.2, green: 0.2, blue: 0.23), lineWidth: 2))
    }
}
