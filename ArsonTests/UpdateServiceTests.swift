import Foundation
import Testing
@testable import Arson

struct UpdateServiceTests {
    @Test func acceptsHTTPSFeedAndEdDSAPublicKey() {
        let publicKey = Data(repeating: 7, count: 32).base64EncodedString()

        #expect(
            UpdateService.isValidConfiguration(
                feedURL: "https://example.com/appcast.xml",
                publicKey: publicKey
            )
        )
    }

    @Test func rejectsInsecureOrIncompleteConfiguration() {
        let publicKey = Data(repeating: 7, count: 32).base64EncodedString()

        #expect(
            !UpdateService.isValidConfiguration(
                feedURL: "http://example.com/appcast.xml",
                publicKey: publicKey
            )
        )
        #expect(
            !UpdateService.isValidConfiguration(
                feedURL: "https://example.com/appcast.xml",
                publicKey: "not-a-key"
            )
        )
        #expect(
            !UpdateService.isValidConfiguration(
                feedURL: "https:",
                publicKey: publicKey
            )
        )
    }
}
