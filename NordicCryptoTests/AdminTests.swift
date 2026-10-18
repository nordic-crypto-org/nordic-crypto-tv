#if os(iOS)
import XCTest
@testable import Nordic_Crypto

final class AdminTests: XCTestCase {
    func testEmailRuleMatchesTheWorker() {
        XCTAssertEqual(AdminEmail.normalized(" JQrgen@NordicCrypto.no "), "jqrgen@nordiccrypto.no")
        for e in ["x@evil-nordiccrypto.no", "x@nordiccrypto.no.evil.com", "x@a.nordiccrypto.no", "x@nordiccrypto.no.",
                  "a@b@nordiccrypto.no", "@nordiccrypto.no", "x y@nordiccrypto.no", "<x@nordiccrypto.no>", ".x@nordiccrypto.no",
                  "x..y@nordiccrypto.no", "nordiccrypto.no", ""] {
            XCTAssertNil(AdminEmail.normalized(e), e)
        }
    }

    func testCode() {
        XCTAssertEqual(AdminCode.normalized("1234 5678"), "12345678")
        XCTAssertEqual(AdminCode.normalized("1234-5678"), "12345678")
        XCTAssertNil(AdminCode.normalized("1234567"))
        XCTAssertNil(AdminCode.normalized("1234567a"))
        XCTAssertNil(AdminCode.normalized("١٢٣٤٥٦٧٨"))
    }

    func testPKCEChallengeIsRFC7636() {
        XCTAssertEqual(AdminPKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let p = AdminPKCE()
        XCTAssertEqual(p.verifier.count, 43)
        XCTAssertEqual(p.challenge.count, 43)
        XCTAssertNotEqual(p.verifier, AdminPKCE().verifier)
    }

    func testFilterAndSort() throws {
        let json = """
        {"ok":true,"email":"j@nordiccrypto.no","last_issue":2,
         "totals":{"all":3,"pending":1,"confirmed":1,"unsubscribed":1,"deliveries":2},
         "rows":[
          {"id":1,"email":"a@x.no","site":"nordic-crypto","lang":"nb","status":"confirmed","created_at":"2026-10-01T00:00:00+00:00","confirmed_at":"2026-10-01T01:00:00+00:00","unsubscribed_at":null,"issues":[1,2],"last_issue":2},
          {"id":2,"email":"b@x.no","site":"nordic-crypto","lang":"en","status":"pending","created_at":"2026-10-02T00:00:00+00:00","confirmed_at":null,"unsubscribed_at":null,"issues":[],"last_issue":null},
          {"id":3,"email":"c@y.se","site":"nordic-crypto","lang":"sv","status":"unsubscribed","created_at":"2026-09-01T00:00:00+00:00","confirmed_at":null,"unsubscribed_at":null,"issues":[1],"last_issue":1}]}
        """
        let subs = try AdminAPI.decoder.decode(AdminSubscribers.self, from: Data(json.utf8))
        XCTAssertEqual(subs.totals, AdminTotals(all: 3, pending: 1, confirmed: 1, unsubscribed: 1, deliveries: 2))
        XCTAssertEqual(subs.lastIssue, 2)
        XCTAssertEqual(AdminFilter.subscribers(subs.rows, query: "", status: nil).map(\.id), [2, 1, 3])
        XCTAssertEqual(AdminFilter.subscribers(subs.rows, query: "", status: "pending").map(\.id), [2])
        XCTAssertEqual(AdminFilter.subscribers(subs.rows, query: "X.NO", status: nil, sort: .email).map(\.id), [1, 2])
        XCTAssertEqual(AdminFilter.subscribers(subs.rows, query: "sv", status: nil).map(\.id), [3])
        XCTAssertEqual(AdminFilter.subscribers(subs.rows, query: "", status: nil, sort: .lastIssue).map(\.id), [1, 3, 2])
        XCTAssertEqual(AdminFilter.minute(subs.rows[0].confirmedAt), "2026-10-01 01:00")
    }

    func testPressSendsDecode() throws {
        let json = """
        {"ok":true,"sends":[{"id":"press-x-1","release_id":"press-x","at":"2026-10-19T09:00:00+02:00","from_addr":"NC <j@nordiccrypto.no>",
         "dry_run":false,"sent":1,"failed":1,"recipients":[{"email":"desk@outlet.no","status":"sent","error":""},{"email":"t@o.se","status":"failed","error":"provider error 422"}]}]}
        """
        let s = try AdminAPI.decoder.decode(AdminPressSends.self, from: Data(json.utf8)).sends
        XCTAssertEqual(s.first?.releaseId, "press-x")
        XCTAssertEqual(s.first?.recipients.count, 2)
    }

    // MARK: - Requests (stubbed, no network)

    private func api() -> AdminAPI {
        let c = AdminAPI.configuration()
        c.protocolClasses = [StubProtocol.self]
        return AdminAPI(base: URL(string: "https://admin.test/api/admin/")!, pressHistoryURL: URL(string: "https://admin.test/history.json")!,
                        session: URLSession(configuration: c))
    }

    override func tearDown() {
        StubProtocol.handler = nil
        StubProtocol.requests = []
        super.tearDown()
    }

    func testVerifySendsCodeAndVerifierAndNoCookiesOrOrigin() async throws {
        StubProtocol.handler = { _ in (200, #"{"ok":true,"token":"tok_abcdefghijklmnopqrstuvwxyz","email":"j@nordiccrypto.no","expires":4102444800}"#) }
        let s = try await api().verify(code: "12345678", verifier: "v".padding(toLength: 43, withPad: "v", startingAt: 0))
        XCTAssertEqual(s.email, "j@nordiccrypto.no")
        XCTAssertTrue(s.isValid)
        let r = try XCTUnwrap(StubProtocol.requests.first)
        XCTAssertEqual(r.request.url?.absoluteString, "https://admin.test/api/admin/verify")
        XCTAssertEqual(r.request.httpMethod, "POST")
        XCTAssertNil(r.request.value(forHTTPHeaderField: "Origin"))
        XCTAssertNil(r.request.value(forHTTPHeaderField: "Cookie"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: r.body) as? [String: String])
        XCTAssertEqual(body["code"], "12345678")
        XCTAssertEqual(body["verifier"]?.count, 43)
    }

    func testUnauthorizedAndRateLimit() async {
        StubProtocol.handler = { _ in (401, #"{"ok":false,"error":"The code is invalid, used or expired. Ask for a new one."}"#) }
        do { _ = try await api().subscribers(token: "t"); XCTFail() } catch {
            XCTAssertEqual(error as? AdminAPI.Failure, .unauthorized("The code is invalid, used or expired. Ask for a new one."))
        }
        StubProtocol.handler = { _ in (429, #"{"ok":false,"error":"rate"}"#) }
        do { try await api().requestCode(email: "j@nordiccrypto.no", challenge: "c"); XCTFail() } catch {
            XCTAssertEqual(error as? AdminAPI.Failure, .rateLimited)
        }
    }

    func testPressHistoryNeverGetsTheToken() async throws {
        StubProtocol.handler = { _ in (200, #"{"releases":[{"id":"press-x","title":"X","languages":["en","nb"],"published":"2026-10-19","status":"published","emails_sent":0}]}"#) }
        let r = try await api().pressHistory()
        XCTAssertEqual(r.first?.languages?.count, 2)
        XCTAssertNil(StubProtocol.requests.first?.request.value(forHTTPHeaderField: "Authorization"))
    }

    @MainActor
    func testStoreSignInFlowKeepsDataInMemoryAndSignOutClearsIt() async {
        StubProtocol.handler = { req in
            switch req.url?.lastPathComponent {
            case "login": return (202, #"{"ok":true}"#)
            case "verify": return (200, #"{"ok":true,"token":"tok_abcdefghijklmnopqrstuvwxyz","email":"j@nordiccrypto.no","expires":4102444800}"#)
            case "subscribers": return (200, #"{"ok":true,"email":"j@nordiccrypto.no","rows":[],"totals":{"all":0,"pending":0,"confirmed":0,"unsubscribed":0,"deliveries":0},"last_issue":null}"#)
            case "press-sends": return (404, #"{"ok":false}"#)
            default: return (200, #"{"ok":true,"releases":[]}"#)
            }
        }
        let store = AdminStore(api: api(), keychain: nil)
        await store.requestCode(email: "someone@gmail.com")
        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertTrue(StubProtocol.requests.isEmpty, "a non-staff address is never sent")
        await store.requestCode(email: "J@nordiccrypto.no")
        XCTAssertEqual(store.phase, .codeSent("j@nordiccrypto.no"))
        await store.verify(code: "1234 5678")
        XCTAssertEqual(store.phase, .signedIn("j@nordiccrypto.no"))
        XCTAssertEqual(store.subscribers?.totals.all, 0)
        XCTAssertNil(store.pressSends, "press endpoint not deployed yet")
        await store.signOut()
        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertNil(store.subscribers)
        XCTAssertEqual(StubProtocol.requests.last?.request.url?.lastPathComponent, "logout")
    }
}

final class StubProtocol: URLProtocol {
    struct Seen { let request: URLRequest; let body: Data }
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var requests: [Seen] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                body.append(buf, count: n)
            }
            stream.close()
        }
        Self.requests.append(Seen(request: request, body: body))
        let (status, text) = Self.handler?(request) ?? (500, "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
#endif
