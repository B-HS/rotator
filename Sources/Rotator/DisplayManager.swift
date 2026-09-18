import AppKit
import CoreGraphics
import RotationBridge
import RotatorCore

struct DisplayInfo: Equatable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let rotation: RotationAngle
}

enum DisplayRotationError: LocalizedError {
    case enumerationFailed(CGError)
    case requestFailed(String)
    case changeNotObserved

    var errorDescription: String? {
        switch self {
        case .enumerationFailed(let error):
            return "연결된 디스플레이를 확인하지 못했습니다. (오류 \(error.rawValue))"
        case .requestFailed(let message):
            return message
        case .changeNotObserved:
            return "macOS에서 회전 변경을 확인하지 못했습니다. 이 디스플레이가 해당 회전을 지원하는지 확인해 주세요."
        }
    }
}

final class DisplayManager {
    func onlineDisplays() throws -> [DisplayInfo] {
        var count: UInt32 = 0
        var result = CGGetOnlineDisplayList(0, nil, &count)
        guard result == .success else { throw DisplayRotationError.enumerationFailed(result) }

        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        result = CGGetOnlineDisplayList(count, &ids, &count)
        guard result == .success else { throw DisplayRotationError.enumerationFailed(result) }

        let namesByID: [CGDirectDisplayID: String] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else {
                    return nil
                }
                return (CGDirectDisplayID(number.uint32Value), screen.localizedName)
            }
        )

        return ids.prefix(Int(count)).enumerated().map { index, id in
            let builtIn = CGDisplayIsBuiltin(id) != 0
            let fallbackName = builtIn ? "MacBook 내장 디스플레이" : "외장 디스플레이 \(index + 1)"
            return DisplayInfo(
                id: id,
                name: namesByID[id] ?? fallbackName,
                isBuiltIn: builtIn,
                rotation: RotationAngle.nearest(to: CGDisplayRotation(id))
            )
        }
        .sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func currentRotation(of displayID: CGDirectDisplayID) -> RotationAngle {
        RotationAngle.nearest(to: CGDisplayRotation(displayID))
    }

    func setRotation(_ angle: RotationAngle, for displayID: CGDirectDisplayID) throws {
        let result = RBSetDisplayRotation(displayID, Int32(angle.rawValue))
        guard result == 0 else {
            let detail = String(cString: RBLastErrorMessage())
            throw DisplayRotationError.requestFailed(
                detail.isEmpty ? "macOS가 회전 요청을 거부했습니다. (오류 \(result))" : detail
            )
        }
    }
}
