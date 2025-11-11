import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (() -> Void)?
    private let hotKeySignature: FourCharCode = makeFourCharCode("FiTx")

    func register(
        keyCode: UInt32 = UInt32(kVK_ANSI_U),
        modifiers: UInt32 = UInt32(cmdKey) | UInt32(optionKey),
        handler: @escaping () -> Void
    ) {
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
            print("Hot key registration failed with status \(registrationStatus)")
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
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
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
