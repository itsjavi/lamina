// Chooses a menu command of a running app through Accessibility (the item's press action: no mouse or key events), for
// the README and website screenshots (brand/README.md). The calling app needs Privacy & Security › Accessibility.
//   swift scripts/menu-command.swift <pid> Filter "Camera Raw Filter…"
//   swift scripts/menu-command.swift <pid> Layer "Layer Style" "Drop Shadow…"
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3, let pid = pid_t(args[0]) else {
    print("usage: menu-command <pid> <menu> [submenu…] <item>")
    exit(64)
}
guard AXIsProcessTrusted() else { print("allow the calling app under Privacy & Security › Accessibility"); exit(1) }

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}
func children(_ element: AXUIElement) -> [AXUIElement] { attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func title(_ element: AXUIElement) -> String { attribute(element, kAXTitleAttribute) as? String ?? "" }

guard let bar = attribute(AXUIElementCreateApplication(pid), kAXMenuBarAttribute) else { print("no menu bar for \(pid)"); exit(1) }
var current = bar as! AXUIElement
let path = Array(args.dropFirst())
for (index, name) in path.enumerated() {
    // A menu bar item or a submenu item holds an untitled menu, which holds the items.
    let candidates = index == 0 ? children(current) : children(current).flatMap { title($0).isEmpty ? children($0) : [$0] }
    guard let next = candidates.first(where: { title($0) == name }) else {
        print("no \"\(name)\" among \(candidates.map(title))")
        exit(1)
    }
    if index == path.count - 1 {
        let result = AXUIElementPerformAction(next, kAXPressAction as CFString)
        guard result == .success else { print("\(name): AX error \(result.rawValue)"); exit(1) }
        exit(0)
    }
    current = next
}
