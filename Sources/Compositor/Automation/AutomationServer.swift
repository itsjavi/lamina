import AppKit
import LaminaAutomation

/// Answers `lamina`'s Apple Events (see `AutomationEvent`): the request is the event's direct parameter, the reply
/// the reply event's. The event is suspended while the command runs, so the app keeps responding meanwhile.
///
/// Who can send: macOS asks the person once per calling app before its first event gets through (Privacy & Security
/// › Automation, where it can be revoked). On top of that, events from another Mac (Remote Apple Events) or from a
/// process of another user are refused here.
final class AutomationServer: NSObject {
    let dispatcher: AutomationDispatcher

    init(workspace: ProjectWorkspace) {
        dispatcher = AutomationDispatcher(workspace: workspace)
    }

    func install() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handle(_:withReply:)),
                                                     forEventClass: AutomationEvent.eventClass, andEventID: AutomationEvent.eventID)
    }

    @objc private func handle(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        if let refusal = Self.refusal(of: event) {
            reply.setParam(NSAppleEventDescriptor(string: AutomationMessage.reply(.failure(refusal)).encodedString()), forKeyword: keyDirectObject)
            return
        }
        let request = Data((event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue ?? "").utf8)
        let manager = NSAppleEventManager.shared()
        guard let suspension = manager.suspendCurrentAppleEvent() else { return }
        Task {
            let response = await dispatcher.handle(request)
            manager.replyAppleEvent(forSuspensionID: suspension)
                .setParam(NSAppleEventDescriptor(string: String(decoding: response, as: UTF8.self)), forKeyword: keyDirectObject)
            manager.resume(withSuspensionID: suspension)
        }
    }

    /// Events from another Mac or another user's process are refused.
    static func refusal(of event: NSAppleEventDescriptor) -> AutomationError? {
        if event.attributeDescriptor(forKeyword: AEKeyword(keyEventSourceAttr))?.int32Value == Int32(kAERemoteProcess) {
            return AutomationError(.transport, "\(AppIdentity.displayName) doesn't take commands from other Macs.")
        }
        if let sender = event.attributeDescriptor(forKeyword: AEKeyword(keySenderEUIDAttr))?.int32Value, uid_t(bitPattern: sender) != geteuid() {
            return AutomationError(.transport, "\(AppIdentity.displayName) only takes commands from its own user's processes.")
        }
        return nil
    }
}
