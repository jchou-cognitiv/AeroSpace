import CoreGraphics
import Foundation

// MARK: - Private SkyLight API declarations

private typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyWindowsWithOptionsAndTags")
private func CGSCopyWindowsWithOptionsAndTags(
    _ cid: CGSConnectionID,
    _ owner: Int,
    _ spaces: CFArray,
    _ options: Int,
    _ setTags: UnsafeMutablePointer<Int>,
    _ clearTags: UnsafeMutablePointer<Int>,
) -> CFArray

// MARK: - Space ID lookup (also private)

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: CGSConnectionID) -> Int

// MARK: - Tab detection

/// Returns the set of CGWindowIDs that are tabbed but NOT the active tab.
/// These should be excluded from tiling.
///
/// Technique: CGSCopyWindowsWithOptionsAndTags excludes tabbed windows.
/// CGWindowListCopyWindowInfo includes all windows.
/// The difference = inactive tabs.
@MainActor
func getTabbedWindowIds() -> Set<UInt32> {
    let cid = CGSMainConnectionID()
    let activeSpace = CGSGetActiveSpace(cid)

    // Get windows via CGS (excludes inactive tabs)
    var setTags: Int = 0
    var clearTags: Int = 0
    let cgsWindows = CGSCopyWindowsWithOptionsAndTags(
        cid, 0, [activeSpace] as CFArray, 2, &setTags, &clearTags,
    ) as? [CGWindowID] ?? []
    let cgsWindowSet = Set(cgsWindows)

    // Get ALL windows via public API (includes inactive tabs)
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cgInfoArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
        return []
    }

    var tabbedIds = Set<UInt32>()
    for info in cgInfoArray {
        guard let windowId = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
        // Window layer 0 = normal windows (skip menubar, dock, etc.)
        guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue, layer == 0 else { continue }

        if !cgsWindowSet.contains(windowId) {
            tabbedIds.insert(windowId)
        }
    }

    return tabbedIds
}
