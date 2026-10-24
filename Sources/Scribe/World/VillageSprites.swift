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
