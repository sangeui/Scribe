import Foundation
import SwiftUI

// 날씨. 날마다 하나가 정해진다(날짜로 난수를 고정하고 계절마다 비중이 다르다). 글자·재해·돌발 상황·판매에 작은 보정이 붙고,
// 상시 창에 빗줄기나 눈이 옅게 내린다. 손님 작가는 눈 오는 날 오지 않는다.

enum Weather: String, CaseIterable, Sendable {
    case clear, cloudy, rain, storm, snow, fog, heat

    var title: String {
        let raw: String = switch self {
        case .clear: "맑음"
        case .cloudy: "흐림"
        case .rain: "비"
        case .storm: "폭풍"
        case .snow: "눈"
        case .fog: "안개"
        case .heat: "더위"
        }
        return L10n.tr(raw)
    }

    /// 팝오버와 상시 창 툴팁에 쓰는 한 줄.
    var line: String {
        let raw: String = switch self {
        case .clear: "맑습니다. 창문을 열어 두었습니다"
        case .cloudy: "흐립니다. 등잔을 일찍 켭니다"
        case .rain: "비가 옵니다. 글이 조금 잘 됩니다"
        case .storm: "폭풍입니다. 원고를 잘 묶어 두세요"
        case .snow: "눈이 옵니다. 손님은 오지 않습니다"
        case .fog: "안개가 짙습니다. 서점에 손님이 적습니다"
        case .heat: "덥습니다. 작가가 자주 졸립니다"
        }
        return L10n.tr(raw)
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
        let raw: String? = switch self {
        case .clear: "판매 +5%"
        case .cloudy: nil
        case .rain: "글자 +5% · 돌발 상황 -10%"
        case .storm: "재해 ×2.5 · 판매 -15%"
        case .snow: "손님 없음 · 돌발 상황 -10%"
        case .fog: "판매 -15%"
        case .heat: "돌발 상황 +20%"
        }
        return raw.map(L10n.tr)
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

// MARK: - 해와 달 천문 계산 및 상시 창 하늘 궤적

/// 시스템 시간대(`zone.tab`)의 위도·경도와 천문 수식(Jean Meeus / SunCalc)으로 해와 달의 실시간 고도·방위각·위상을 구한다.
/// 네트워크 요청이나 위치 권한 팝업 없이 오프라인으로 동작한다.
enum Celestial {
    struct Coordinate: Sendable, Equatable {
        let latitude: Double
        let longitude: Double
    }

    struct Body: Sendable, Equatable {
        /// 지평선 기준 고도각(-90° ... +90°).
        let altitude: Double
        /// 진북 기준 시계 방향 방위각(0° 북, 90° 동, 180° 남, 270° 서).
        let azimuth: Double
        /// 출(0.0) → 남중(0.5) → 몰(1.0) 사이 수평 궤적 진행도.
        let progress: Double
        /// 적위(라디안)와 반일주호(라디안). 그날의 고도 궤적 곡선을 그릴 때 쓴다.
        let declinationRad: Double
        let halfArcRad: Double
    }

    struct Moon: Sendable, Equatable {
        let body: Body
        /// 0.0(합삭) → 0.25(상현) → 0.5(보름) → 0.75(하현) → 1.0(합삭).
        let phase: Double
        /// 밝게 빛나는 면적 비율(0.0 ... 1.0).
        var illumination: Double { 0.5 * (1 - cos(phase * 2 * .pi)) }

        var phaseTitle: String {
            let raw: String = switch phase {
            case ..<0.04, 0.96...: "합삭"
            case 0.04..<0.21: "초승달"
            case 0.21..<0.29: "상현달"
            case 0.29..<0.46: "차오르는 달"
            case 0.46..<0.54: "보름달"
            case 0.54..<0.71: "기울어가는 달"
            case 0.71..<0.79: "하현달"
            default: "그믐달"
            }
            return L10n.tr(raw)
        }
    }

    struct Snapshot: Sendable, Equatable {
        let coordinate: Coordinate
        let sun: Body
        let moon: Moon

        /// 해가 지평선(시민박명 포함) 위에 있는지.
        var isSunVisible: Bool { sun.altitude >= -5.0 && (-0.08...1.08).contains(sun.progress) }
        /// 달이 지평선 위에 있고 합삭이 아닌지.
        var isMoonVisible: Bool { moon.body.altitude >= -2.0 && (-0.06...1.06).contains(moon.body.progress) && moon.illumination >= 0.02 }

        /// 진행도 `u`(0 출 ... 0.5 남중 ... 1 몰)에서 천체의 고도각(도)을 구한다.
        func altitude(of body: Body, atProgress u: Double) -> Double {
            let phi = coordinate.latitude * (.pi / 180)
            let h = (2 * u - 1) * body.halfArcRad
            let sinAlt = sin(phi) * sin(body.declinationRad) + cos(phi) * cos(body.declinationRad) * cos(h)
            return asin(min(1, max(-1, sinAlt))) * (180 / .pi)
        }

        /// 상시 창 툴팁에 넣을 해·달 위치 요약 한 줄.
        var summaryLine: String {
            var parts: [String] = []
            if sun.altitude >= -0.833 {
                parts.append(L10n.tr("해 \(Celestial.compass(sun.azimuth)) \(Int(sun.altitude.rounded()))°"))
            }
            if moon.body.altitude >= 0, moon.illumination >= 0.02 {
                parts.append(L10n.tr("\(moon.phaseTitle) \(Celestial.compass(moon.body.azimuth)) \(Int(moon.body.altitude.rounded()))°"))
            } else if parts.isEmpty {
                let edge = L10n.tr(moon.body.progress < 0.5 ? "월출 전" : "월몰 후")
                parts.append(L10n.tr("밤하늘 · \(moon.phaseTitle)(\(edge))"))
            }
            return parts.joined(separator: " · ")
        }
    }

    /// 주어진 날짜의 현지 일출·일몰 시각(시 단위, 0...24)을 구한다.
    static func sunTimes(on date: Date, calendar: Calendar = .current) -> (sunrise: Double, sunset: Double) {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let noon = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: 12)) ?? date
        let snap = snapshot(at: noon, timeZone: calendar.timeZone)
        let hHours = (snap.sun.progress - 0.5) * 2 * (snap.sun.halfArcRad / .pi * 12.0)
        let solarNoon = 12.0 - hHours
        let halfDayHours = snap.sun.halfArcRad / .pi * 12.0
        return (sunrise: max(2.0, min(10.0, solarNoon - halfDayHours)),
                sunset: max(14.0, min(22.5, solarNoon + halfDayHours)))
    }

    private static let rad = Double.pi / 180.0
    private static let deg = 180.0 / Double.pi

    /// `/usr/share/zoneinfo/zone.tab` 에서 읽은 시간대별 표준 위경도 캐시.
    private static let zoneCoordinates: [String: Coordinate] = {
        var map: [String: Coordinate] = [:]
        for path in ["/usr/share/zoneinfo/zone.tab", "/var/db/timezone/zoneinfo/zone.tab"] {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let cols = line.split(separator: "\t")
                guard cols.count >= 3, let coord = parseISO6709(String(cols[1])) else { continue }
                map[String(cols[2])] = coord
            }
            if !map.isEmpty { break }
        }
        return map
    }()

    /// ISO 6709 문자열(예: `+3733+12658`, `-3352+15113`)을 위도·경도(도)로 변환한다.
    static func parseISO6709(_ raw: String) -> Coordinate? {
        var signs: [String.Index] = []
        for idx in raw.indices where raw[idx] == "+" || raw[idx] == "-" { signs.append(idx) }
        guard signs.count == 2 else { return nil }
        func parsePart(_ s: Substring, degDigits: Int) -> Double? {
            let sign = s.first == "-" ? -1.0 : 1.0
            let digits = s.dropFirst()
            guard digits.count >= degDigits + 2 else { return nil }
            let d = Double(digits.prefix(degDigits)) ?? 0
            let m = Double(digits.dropFirst(degDigits).prefix(2)) ?? 0
            let sec = digits.count >= degDigits + 4 ? (Double(digits.dropFirst(degDigits + 2).prefix(2)) ?? 0) : 0
            return sign * (d + m / 60.0 + sec / 3600.0)
        }
        guard let lat = parsePart(raw[signs[0]..<signs[1]], degDigits: 2),
              let lon = parsePart(raw[signs[1]...], degDigits: 3) else { return nil }
        return Coordinate(latitude: lat, longitude: lon)
    }

    /// 현재 시간대에 대응하는 표준 좌표를 돌려준다.
    static func coordinate(for timeZone: TimeZone = .current) -> Coordinate {
        let id = timeZone.identifier
        if let found = zoneCoordinates[id] { return found }
        // 심볼릭 링크 별칭(예: Asia/Tokyo 등)이면 원본 경로에서 표준 시간대 이름을 찾는다.
        let zonePath = "/usr/share/zoneinfo/\(id)"
        if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: zonePath) {
            for (key, coord) in zoneCoordinates where dest.hasSuffix(key) { return coord }
        }
        let lon = Double(timeZone.secondsFromGMT()) / 3600.0 * 15.0
        return Coordinate(latitude: 37.55, longitude: lon)
    }

    /// 방위각(0° ... 360°)을 8방위 이름으로 바꾼다.
    static func compass(_ azimuth: Double) -> String {
        let dirs = L10n.isEnglish
            ? ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            : ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]
        let normalized = ((azimuth.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int(((normalized + 22.5) / 45.0).rounded(.down)) % 8
        return dirs[idx]
    }

    /// 주어진 시각과 시간대의 해·달 위치 및 위상을 계산한다.
    static func snapshot(at date: Date, timeZone: TimeZone = .current) -> Snapshot {
        let coord = coordinate(for: timeZone)
        return snapshot(at: date, coordinate: coord)
    }

    static func snapshot(at date: Date, coordinate: Coordinate) -> Snapshot {
        let d = date.timeIntervalSince1970 / 86_400.0 - 10_957.5
        let phi = coordinate.latitude * rad
        let lon = coordinate.longitude * rad
        let obliquity = 23.4397 * rad
        let sidereal = (280.16 + 360.9856235 * d) * rad + lon

        // 1. 태양 좌표
        let meanAnomalySun = (357.5291 + 0.98560028 * d) * rad
        let centerSun = (1.9148 * sin(meanAnomalySun) + 0.0200 * sin(2 * meanAnomalySun) + 0.0003 * sin(3 * meanAnomalySun)) * rad
        let eclipticLonSun = meanAnomalySun + centerSun + (102.9372 + 180.0) * rad
        let decSun = asin(sin(eclipticLonSun) * sin(obliquity))
        let raSun = atan2(sin(eclipticLonSun) * cos(obliquity), cos(eclipticLonSun))
        let hSun = normalizeSignedRadians(sidereal - raSun)
        let altSun = asin(sin(phi) * sin(decSun) + cos(phi) * cos(decSun) * cos(hSun)) * deg
        let azSun = (atan2(sin(hSun), cos(hSun) * sin(phi) - tan(decSun) * cos(phi)) + .pi) * deg
        let halfArcSun = halfDayArc(latRad: phi, decRad: decSun, horizonDeg: -0.833)
        let progSun = 0.5 + hSun / (2 * halfArcSun)
        let sunBody = Body(altitude: altSun, azimuth: azSun, progress: progSun, declinationRad: decSun, halfArcRad: halfArcSun)

        // 2. 달 좌표 및 위상
        let meanLonMoon = (218.316 + 13.176396 * d) * rad
        let meanAnomalyMoon = (134.963 + 13.064993 * d) * rad
        let meanDistMoon = (93.272 + 13.229350 * d) * rad
        let eclipticLonMoon = meanLonMoon + 6.289 * rad * sin(meanAnomalyMoon)
        let eclipticLatMoon = 5.128 * rad * sin(meanDistMoon)
        let decMoon = asin(sin(eclipticLatMoon) * cos(obliquity) + cos(eclipticLatMoon) * sin(obliquity) * sin(eclipticLonMoon))
        let raMoon = atan2(sin(eclipticLonMoon) * cos(obliquity) - tan(eclipticLatMoon) * sin(obliquity), cos(eclipticLonMoon))
        let hMoon = normalizeSignedRadians(sidereal - raMoon)
        let rawAltMoon = asin(sin(phi) * sin(decMoon) + cos(phi) * cos(decMoon) * cos(hMoon))
        // 지평 시차 보정
        let altMoon = (rawAltMoon - 0.0165 * cos(rawAltMoon)) * deg
        let azMoon = (atan2(sin(hMoon), cos(hMoon) * sin(phi) - tan(decMoon) * cos(phi)) + .pi) * deg
        let halfArcMoon = halfDayArc(latRad: phi, decRad: decMoon, horizonDeg: 0.125)
        let progMoon = 0.5 + hMoon / (2 * halfArcMoon)
        let moonBody = Body(altitude: altMoon, azimuth: azMoon, progress: progMoon, declinationRad: decMoon, halfArcRad: halfArcMoon)

        var cycle = (eclipticLonMoon - eclipticLonSun).truncatingRemainder(dividingBy: 2 * .pi)
        if cycle < 0 { cycle += 2 * .pi }
        let phase = cycle / (2 * .pi)

        return Snapshot(coordinate: coordinate, sun: sunBody, moon: Moon(body: moonBody, phase: phase))
    }

    private static func normalizeSignedRadians(_ angle: Double) -> Double {
        var x = (angle + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        if x < 0 { x += 2 * .pi }
        return x - .pi
    }

    private static func halfDayArc(latRad: Double, decRad: Double, horizonDeg: Double) -> Double {
        let h0 = horizonDeg * rad
        let denom = max(0.0001, cos(latRad) * cos(decRad))
        let cosH0 = (sin(h0) - sin(latRad) * sin(decRad)) / denom
        return acos(min(0.95, max(-0.95, cosH0)))
    }
}

/// 상시 창(알약) 오른쪽 위 구석에 현재 시각과 위치 기준의 해 또는 달(실제 위상)을 조용히 표시한다.
struct CelestialBackdrop: View {
    var date: Date? = nil
    var dayPart: DayPart? = nil
    let weather: Weather
    var dark: Bool = false

    private var effectiveDate: Date {
        if let date { return date }
        // 확인용 정적 렌더링처럼 시각이 주어지지 않았을 때는 낮(13:30) 또는 밤(22:00) 대표 시각을 쓴다.
        let base = Calendar.current.startOfDay(for: Date())
        let isNight = dayPart?.isDark ?? dark
        return base.addingTimeInterval((isNight ? 22.0 : 13.5) * 3600)
    }

    var body: some View {
        let snap = Celestial.snapshot(at: effectiveDate)
        let veil: Double = (weather == .clear || weather == .heat) ? 1.0 : (weather == .storm ? 0.45 : 0.72)
        Canvas { context, size in
            // 알약 오른쪽 위 구석 여백(x: 232...256, y: 8...13) 안에서 시간대별 진행도와 고도에 따라 배치한다.
            let xMin: CGFloat = min(size.width - 52, 232)
            let xMax: CGFloat = min(size.width - 28, 256)
            guard xMax > xMin else { return }
            let yLow: CGFloat = 12.5
            let yHigh: CGFloat = 8.0

            func cornerPoint(progress u: Double, altitude alt: Double) -> CGPoint {
                let clampedU = min(1, max(0, u))
                let x = xMin + CGFloat(clampedU) * (xMax - xMin)
                let normAlt = pow(min(90, max(0, alt)) / 90.0, 0.75)
                let y = yLow - CGFloat(normAlt) * (yLow - yHigh)
                return CGPoint(x: x, y: y)
            }

            if snap.isSunVisible {
                // 낮·일출·일몰: 구석에 해를 그린다.
                let s = snap.sun
                let sp = cornerPoint(progress: s.progress, altitude: max(0, s.altitude))
                let horizonFade = min(1.0, max(0.45, (s.altitude + 5.0) / 6.0))
                drawSun(in: &context, center: sp, altitude: s.altitude, alpha: horizonFade * veil)
            } else {
                // 밤: 구석에 달의 실제 위상과 잔잔한 별 두 점을 그린다.
                let m = snap.moon
                let progress = snap.isMoonVisible ? m.body.progress : 0.75
                let altitude = snap.isMoonVisible ? max(0, m.body.altitude) : 35.0
                let mp = cornerPoint(progress: progress, altitude: altitude)
                if weather != .fog && weather != .storm {
                    let starColor: Color = dark ? .white : Color(red: 0.25, green: 0.22, blue: 0.38)
                    let starOffsets: [(CGFloat, CGFloat, CGFloat)] = [(-11, 1.5, 1.3), (-5.5, -2.2, 1.1)]
                    for (dx, dy, d) in starOffsets {
                        let rect = CGRect(x: mp.x + dx - d / 2, y: mp.y + dy - d / 2, width: d, height: d)
                        context.fill(Path(ellipseIn: rect), with: .color(starColor.opacity(0.38 * veil)))
                    }
                }
                drawMoon(in: &context, center: mp, radius: 3.4, phase: m.phase,
                         southernHemisphere: snap.coordinate.latitude < 0, dark: dark, alpha: 0.92 * veil)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawSun(in context: inout GraphicsContext, center: CGPoint, altitude: Double, alpha: Double) {
        // 고도가 낮을수록(일출·일몰) 붉은 호박색, 높을수록 밝은 황금색
        let warm = min(1, max(0, (altitude - 2) / 18.0))
        let sunColor = Color(
            red: 1.0,
            green: 0.50 + 0.32 * warm,
            blue: 0.20 + 0.08 * warm
        )
        let glowOuter = CGRect(x: center.x - 6.8, y: center.y - 6.8, width: 13.6, height: 13.6)
        let glowInner = CGRect(x: center.x - 4.4, y: center.y - 4.4, width: 8.8, height: 8.8)
        context.fill(Path(ellipseIn: glowOuter), with: .color(sunColor.opacity(0.22 * alpha)))
        context.fill(Path(ellipseIn: glowInner), with: .color(sunColor.opacity(0.38 * alpha)))

        // 8방향 햇살
        for i in 0..<8 {
            let angle = Double(i) * (.pi / 4)
            let r1: CGFloat = 3.3
            let r2: CGFloat = 4.6
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * r1, y: center.y + CGFloat(sin(angle)) * r1))
            ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * r2, y: center.y + CGFloat(sin(angle)) * r2))
            context.stroke(ray, with: .color(sunColor.opacity(0.85 * alpha)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }

        let core = CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5.0, height: 5.0)
        context.fill(Path(ellipseIn: core), with: .color(sunColor.opacity(alpha)))
    }

    private func drawMoon(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, phase: Double, southernHemisphere: Bool, dark: Bool, alpha: Double) {
        let moonColor = dark ? Color(red: 0.99, green: 0.95, blue: 0.78) : Color(red: 0.96, green: 0.95, blue: 0.90)
        if dark {
            let glow = CGRect(x: center.x - radius * 2.1, y: center.y - radius * 2.1, width: radius * 4.2, height: radius * 4.2)
            context.fill(Path(ellipseIn: glow), with: .color(moonColor.opacity(0.22 * alpha)))
        }
        // 달의 어두운 반구 윤곽(지구조)
        let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: disc), with: .color((dark ? Color.white : Color.black).opacity(0.14 * alpha)))

        // 달의 위상(초승·상현·보름·하현·그믐)을 명암 경계선(terminator) 타원 방정식으로 정확히 채운다.
        let k = CGFloat(cos(phase * 2 * .pi))
        let waxing = southernHemisphere ? (phase > 0.5) : (phase <= 0.5)
        let samples = 24
        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []
        for i in 0...samples {
            let frac = CGFloat(i) / CGFloat(samples) * 2 - 1 // -1 ... +1
            let dy = frac * radius
            let halfW = sqrt(max(0, radius * radius - dy * dy))
            let xLeft = waxing ? (k * halfW) : -halfW
            let xRight = waxing ? halfW : (-k * halfW)
            leftEdge.append(CGPoint(x: center.x + xLeft, y: center.y + dy))
            rightEdge.append(CGPoint(x: center.x + xRight, y: center.y + dy))
        }
        var litPath = Path()
        if let first = rightEdge.first {
            litPath.move(to: first)
            for p in rightEdge.dropFirst() { litPath.addLine(to: p) }
            for p in leftEdge.reversed() { litPath.addLine(to: p) }
            litPath.closeSubpath()
        }
        context.fill(litPath, with: .color(moonColor.opacity(alpha)))
    }
}
