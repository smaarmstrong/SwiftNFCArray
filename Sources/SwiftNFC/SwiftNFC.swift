import SwiftUI
import CoreNFC

@available(iOS 15.0, *)
public class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {

    public var startAlert = String(localized: "Hold your iPhone near the tag.", bundle: .module)
    public var endAlert = ""
    public var msg = String(localized: "Scan to read or Edit here to write...", bundle: .module)
    public var raw = String(localized: "Raw Data available after scan.", bundle: .module)

    public var session: NFCNDEFReaderSession?
    
    public func read() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("Error")
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = self.startAlert
        session?.begin()
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            self.msg = messages.map {
                $0.records.map {
                    String(decoding: $0.payload, as: UTF8.self)
                }.joined(separator: "\n")
            }.joined(separator: " ")
            
            self.raw = messages.map {
                $0.records.map {
                    "\($0.typeNameFormat) \(String(decoding:$0.type, as: UTF8.self)) \(String(decoding:$0.identifier, as: UTF8.self)) \(String(decoding: $0.payload, as: UTF8.self))"
                }.joined(separator: "\n")
            }.joined(separator: " ")


            session.alertMessage = self.endAlert != "" ? self.endAlert : "Read \(messages.count) NDEF Messages, and \(messages[0].records.count) Records."
        }
    }
    
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Session did invalidate with error: \(error)")
        self.session = nil
    }
}

public class NFCWriter: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    
    public var startAlert = String(localized: "Hold your iPhone near the tag.", bundle: .module)
    public var endAlert = ""
    public var msg = ""
    public var type = "T"
    
    public var session: NFCNDEFReaderSession?
    
    public func write() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("Error")
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = self.startAlert
        session?.begin()
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "Detected more than 1 tag. Please try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if let error = error {
                session.alertMessage = "Unable to connect to tag: \(error.localizedDescription)"
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the status of tag: \(error!.localizedDescription)"
                    session.invalidate()
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                case .readOnly:
                    session.alertMessage = "Read only tag detected."
                    session.invalidate()
                case .readWrite:
                    let data: [Any] = [123, "Hello", 45.67] // Example data
                    writeData(to: tag, data: data, session: session)
                @unknown default:
                    session.alertMessage = "Unknown NDEF status."
                    session.invalidate()
                }
            })
        })
    }
    
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Session did invalidate with error: \(error)")
        self.session = nil
    }
}

func createPayload(from data: [Any]) -> [NFCNDEFPayload] {
    var payloads: [NFCNDEFPayload] = []
    
    for item in data {
        let payload: NFCNDEFPayload?
        
        switch item {
        case let intValue as Int:
            payload = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: Data("I".utf8),
                identifier: Data(),
                payload: Data("\(intValue)".utf8)
            )
        case let stringValue as String:
            payload = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: Data("S".utf8),
                identifier: Data(),
                payload: Data(stringValue.utf8)
            )
        case let floatValue as Float:
            payload = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: Data("F".utf8),
                identifier: Data(),
                payload: Data("\(floatValue)".utf8)
            )
        default:
            continue
        }
        
        if let payload = payload {
            payloads.append(payload)
        }
    }
    
    return payloads
}

func writeData(to tag: NFCNDEFTag, data: [Any], session: NFCNDEFReaderSession) {
    let payloads = createPayload(from: data)
    
    let message = NFCNDEFMessage(records: payloads)
    
    tag.writeNDEF(message, completionHandler: { (error: Error?) in
        if let error = error {
            session.alertMessage = "Write NDEF message failed: \(error.localizedDescription)"
        } else {
            session.alertMessage = "Write NDEF message successful."
        }
        session.invalidate()
    })
}
