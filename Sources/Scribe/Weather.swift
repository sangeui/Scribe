import Foundation
import SwiftUI

// 날씨. 날마다 하나가 정해진다(날짜로 난수를 고정하고 계절마다 비중이 다르다). 글자·재해·돌발 상황·판매에 작은 보정이 붙고,
// 상시 창에 빗줄기나 눈이 옅게 내린다. 손님 작가는 눈 오는 날 오지 않는다.

enum Weather: String, CaseIterable, Sendable {
    case clear, cloudy, rain, storm, snow, fog, heat

    var title: String {
        switch self {
        case .clear: "맑음"
        case .cloudy: "흐림"
        case .rain: "비"
        case .storm: "폭풍"
        case .snow: "눈"
        case .fog: "안개"
        case .heat: "더위"
        }
    }

    /// 팝오버와 상시 창 툴팁에 쓰는 한 줄.
    var line: String {
        switch self {
        case .clear: "맑습니다. 창문을 열어 두었습니다"
        case .cloudy: "흐립니다. 등잔을 일찍 켭니다"
        case .rain: "비가 옵니다. 글이 조금 잘 됩니다"
        case .storm: "폭풍입니다. 원고를 잘 묶어 두세요"
        case .snow: "눈이 옵니다. 손님은 오지 않습니다"
        case .fog: "안개가 짙습니다. 서점에 손님이 적습니다"
        case .heat: "덥습니다. 작가가 자주 졸립니다"
        }
    }

    /// 효과. 글자 배수, 자연재해 확률 배수, 돌발 상황 확률 배수, 판매 배수.
    var characters: Double { self == .rain ? 1.05 : 1 }
    var disaster: Double { self == .storm ? 2.5 : 1 }
    var event: Double {
        switch self {
        case .heat: 1.2
        case .storm: 1.1
        case .rain, .snow: 0.9
        default: 1
        }
    }
    var sales: Double {
        switch self {
        case .clear: 1.05
        case .fog, .storm: 0.85
        default: 1
        }
    }
    var blocksGuest: Bool { self == .snow }

    /// 효과를 짧게. 없으면 nil.
    var effectText: String? {
        switch self {
        case .clear: "판매 +5%"
        case .cloudy: nil
        case .rain: "글자 +5% · 돌발 상황 -10%"
        case .storm: "재해 ×2.5 · 판매 -15%"
        case .snow: "손님 없음 · 돌발 상황 -10%"
        case .fog: "판매 -15%"
        case .heat: "돌발 상황 +20%"
        }
    }

    /// SF Symbol 이름.
    var symbol: String {
        switch self {
        case .clear: "sun.max"
        case .cloudy: "cloud"
        case .rain: "cloud.rain"
        case .storm: "cloud.bolt.rain"
        case .snow: "snowflake"
        case .fog: "cloud.fog"
        case .heat: "thermometer.sun"
        }
    }

    /// 상시 창 바탕에 더하는 색.
    var tint: Color? {
        switch self {
        case .cloudy: Color(red: 0.45, green: 0.47, blue: 0.52).opacity(0.22)
        case .rain: Color(red: 0.3, green: 0.4, blue: 0.6).opacity(0.26)
        case .storm: Color(red: 0.1, green: 0.12, blue: 0.2).opacity(0.42)
        case .snow: Color(red: 0.85, green: 0.9, blue: 1).opacity(0.3)
        case .fog: Color(red: 0.8, green: 0.8, blue: 0.82).opacity(0.36)
        case .heat: Color(red: 1, green: 0.68, blue: 0.3).opacity(0.2)
        case .clear: nil
        }
    }

    /// 계절(월)에 따른 비중.
    static func weights(month: Int) -> [(Weather, Int)] {
        switch month {
        case 3...5: [(.clear, 35), (.cloudy, 25), (.rain, 20), (.fog, 15), (.storm, 5)]
        case 6...8: [(.clear, 30), (.heat, 25), (.cloudy, 15), (.rain, 15), (.storm, 15)]
        case 9...11: [(.clear, 35), (.cloudy, 25), (.fog, 20), (.rain, 15), (.storm, 5)]
        default: [(.clear, 30), (.cloudy, 25), (.snow, 30), (.fog, 10), (.storm, 5)]
        }
    }

    /// 확인용 실행이 날씨를 정해 둘 때.
    nonisolated(unsafe) static var forced: Weather?

    /// 그날의 날씨. 날짜로 난수를 고정해 하루 동안 같다.
    static func of(_ date: Date, calendar: Calendar = .current) -> Weather {
        if let forced { return forced }
        let day = calendar.startOfDay(for: date)
        var seed = UInt64(max(0, day.timeIntervalSince1970)) / 86_400 &+ 7
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        seed ^= seed >> 29
        let weights = weights(month: calendar.component(.month, from: day))
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int(seed % UInt64(total))
        for (weather, weight) in weights {
            if roll < weight { return weather }
            roll -= weight
        }
        return .clear
    }
}

/// 상시 창 위에 내리는 비나 눈. 입자 열두 개가 저마다 다른 빠르기로 내려온다. 10fps.
/// 상시 창의 날씨 바탕. 흐림은 위가 짙은 회색, 비는 푸른 회색, 폭풍은 어둡다가 가끔 번개, 눈은 희푸름, 안개는 흰 띠가 흐르고, 더위는 위에서 누런 빛.
struct WeatherBackdrop: View {
    let weather: Weather
    var animated = true

    var body: some View {
        if let tint = weather.tint {
            TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
                ZStack {
                    Rectangle().fill(tint)
                    switch weather {
                    case .cloudy:
                        LinearGradient(colors: [Color.black.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
                    case .rain:
                        LinearGradient(colors: [Color(red: 0.2, green: 0.26, blue: 0.4).opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                    case .storm:
                        LinearGradient(colors: [Color.black.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        Rectangle().fill(Color.white.opacity(animated && tick % 17 == 0 ? 0.6 : 0))
                            .animation(.easeOut(duration: 0.45), value: tick)
                    case .fog:
                        GeometryReader { geo in
                            let drift = animated ? CGFloat(tick % 40) / 40 : 0.3
                            Capsule().fill(Color.white.opacity(0.35))
                                .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.5)
                                .blur(radius: 8)
                                .offset(x: -geo.size.width * 0.3 + geo.size.width * 1.2 * drift, y: geo.size.height * 0.25)
                        }
                    case .heat:
                        LinearGradient(colors: [Color(red: 1, green: 0.8, blue: 0.4).opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                    case .snow:
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                    case .clear:
                        EmptyView()
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

struct WeatherOverlay: View {
    let weather: Weather
    var animated = true

    var body: some View {
        if weather == .rain || weather == .storm || weather == .snow {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 10)) { context in
                    particles(at: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                particles(at: 0)
            }
        }
    }

    private func particles(at t: TimeInterval) -> some View {
        let snow = weather == .snow
        let count = weather == .storm ? 18 : 12
        return Canvas { context, size in
            for i in 0..<count {
                let seed = Double(i) * 0.6180339887
                let x0 = (seed.truncatingRemainder(dividingBy: 1)) * size.width
                let speed = snow ? 12.0 + Double(i % 4) * 4 : (weather == .storm ? 70.0 : 45.0) + Double(i % 3) * 8
                let period = size.height / speed
                let phase = ((t + seed * 10).truncatingRemainder(dividingBy: period)) / period
                let y = phase * size.height
                let drift = snow ? sin(t * 1.5 + seed * 6) * 4 : 0
                let x = x0 + drift
                if snow {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(.white.opacity(0.55)))
                } else {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: y))
                    line.addLine(to: CGPoint(x: x - 1, y: y + (weather == .storm ? 9 : 6)))
                    context.stroke(line, with: .color(Color(red: 0.55, green: 0.7, blue: 0.95).opacity(0.45)), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
