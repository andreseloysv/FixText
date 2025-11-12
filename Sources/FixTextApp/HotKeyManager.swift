import AppKit
import Carbon.HIToolbox

final class HotKeyManager: @unchecked Sendable {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handlerRefcon: UnsafeMutableRawPointer?
    private var callback: (() -> Void)?
    private let hotKeySignature: FourCharCode = makeFourCharCode("FiTx")

    private func logState(function: String = #function) {
        // LogManager.shared.log("---")
        // LogManager.shared.log("HotKeyManager state in \(function):")
        // LogManager.shared.log("  - hotKeyRef: \(hotKeyRef.debugDescription)")
        // LogManager.shared.log("  - handlerRef: \(handlerRef.debugDescription)")
        // LogManager.shared.log("  - handlerRefcon: \(handlerRefcon.debugDescription)")
        // LogManager.shared.log("  - callback: \(callback.debugDescription)")
        // LogManager.shared.log("---")
    }

    func register(
        keyCode: UInt32 = UInt32(kVK_ANSI_U),
        modifiers: UInt32 = UInt32(cmdKey) | UInt32(optionKey),
        handler: @escaping () -> Void
    ) {
        logState()
        unregister()

        callback = handler
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            // LogManager.shared.log("Hot key registration failed with status \(registrationStatus)")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }

                let manager = Unmanaged<HotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                if hotKeyID.signature == manager.hotKeySignature {
                    Task { @MainActor in
                        manager.callback?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            &handlerRef
        )
    }

    func unregister() {
        logState()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        if let handlerRefcon {
            Unmanaged<HotKeyManager>.fromOpaque(handlerRefcon).release()
            self.handlerRefcon = nil
        }

        callback = nil
    }

}

private func makeFourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + FourCharCode(scalar.value)
    }
    return result
}
