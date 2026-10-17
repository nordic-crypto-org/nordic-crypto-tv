import SwiftUI
import CoreImage.CIFilterBuiltins

/// The Nordic Crypto Shield badge from nft.nordiccrypto.no: live minted count
/// and a fresh Wally Wallet (tdpp) link as a QR code. Nothing is stored.
@MainActor
@Observable
final class BadgeStore {
    static let page = URL(string: "https://nft.nordiccrypto.no/")!

    enum Phase: Equatable { case loading, ready, soldOut, notLaunched, sent(Int?), offline }

    var minted: Int?
    var supply = 1000
    var link: URL?
    var phase: Phase = .loading

    private var cookie: String?
    private var issued = Date.distantPast
    private var sentAt = Date.distantPast
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private struct Status: Decodable { let minted: Int; let supply: Int }
    private struct Offer: Decodable { let cookie: String?; let link: String? }
    private struct Poll: Decodable { let done: Done?; struct Done: Decodable { let n: Int? } }

    func run() async {
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func tick() async {
        let previous = minted
        if let status = await get("status", as: Status.self).value {
            minted = status.minted
            supply = status.supply
        } else if link == nil {
            phase = .offline
        }
        if case .sent = phase, Date.now.timeIntervalSince(sentAt) < 20 { return }
        let changed = previous != nil && previous != minted
        if changed, let cookie, let poll = await get("api/poll?cookie=\(cookie)", as: Poll.self).value, let done = poll.done {
            phase = .sent(done.n)
            sentAt = .now
            self.cookie = nil
            link = nil
            return
        }
        // Offers expire after an hour; the Worker reuses a session only while it is current.
        if Date.now.timeIntervalSince(issued) > 30 * 60 { cookie = nil }
        if link == nil || changed || cookie == nil { await renew() }
    }

    private func renew() async {
        let (offer, code) = await get("api/session" + (cookie.map { "?cookie=\($0)" } ?? ""), as: Offer.self)
        switch code {
        case 200:
            guard let offer, let link = offer.link.flatMap(URL.init(string:)) else { phase = .offline; return }
            if offer.cookie != cookie { issued = .now }
            cookie = offer.cookie
            self.link = link
            phase = .ready
        case 410: link = nil; phase = .soldOut
        case 503: link = nil; phase = .notLaunched
        case 409: break
        default: if link == nil { phase = .offline }
        }
    }

    private func get<T: Decodable>(_ path: String, as type: T.Type) async -> (value: T?, code: Int) {
        guard let url = URL(string: path, relativeTo: Self.page)?.absoluteURL,
              let (data, response) = try? await session.data(from: url) else { return (nil, 0) }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (try? JSONDecoder().decode(T.self, from: data), code)
    }
}

struct BadgeView: View {
    /// When set, the screen can be closed (Apple TV overlay, not a tab).
    var onClose: (() -> Void)? = nil

    @State private var store = BadgeStore()
    @FocusState private var closeFocused: Bool

    private static let gold = Color(hex: 0xD9A034)
    private static let teal = Color(hex: 0x1E3A45)

    var body: some View {
        content
            .background(NLBackground())
            .navigationTitle("Badge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task { await store.run() }
            #if os(tvOS)
            .onAppear { closeFocused = true }
            .onExitCommand { onClose?() }
            #endif
    }

    #if os(tvOS)
    private var content: some View {
        HStack(alignment: .center, spacing: 100) {
            VStack(alignment: .leading, spacing: 28) {
                shield(200)
                details
                Text("Terms and privacy: \(BadgeStore.page.host() ?? "")")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
                if let onClose {
                    Button(action: onClose) {
                        Text("Done")
                            .font(NLFont.row)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .focused($closeFocused)
                    .accessibilityIdentifier("badge-done")
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            VStack(spacing: 24) {
                qr(620)
                Text(scanHint)
                    .font(NLFont.row)
                    .foregroundStyle(NL.textPrimary)
                Text("Get Wally Wallet from the App Store or Google Play.")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textSecondary)
            }
            .frame(width: 700)
        }
        .padding(NLMetrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    #else
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NLMetrics.gutter) {
                shield(140)
                details
                if showsQR {
                    VStack(spacing: 12) {
                        qr(320)
                        Text(scanHint)
                            .font(NLFont.body)
                            .foregroundStyle(NL.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                if let link = store.link {
                    Link(destination: link) {
                        Text("Mint in Wally Wallet")
                            .font(.headline)
                            .foregroundStyle(Self.teal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Self.gold, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("badge-mint")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get Wally Wallet from the App Store or Google Play.")
                    HStack(spacing: 16) {
                        Link(destination: URL(string: "https://apps.apple.com/us/app/wally-nexa-wallet/id6469619075")!) { Text(verbatim: "App Store") }
                        Link(destination: URL(string: "https://play.google.com/store/apps/details?id=info.bitcoinunlimited.www.wally")!) { Text(verbatim: "Google Play") }
                        Link("Open the web page", destination: BadgeStore.page)
                    }
                    HStack(spacing: 16) {
                        Link("Terms", destination: BadgeStore.page.appending(path: "terms"))
                        Link("Privacy", destination: BadgeStore.page.appending(path: "privacy"))
                    }
                }
                .font(NLFont.caption)
                .foregroundStyle(NL.textSecondary)
                .tint(NL.accent)
            }
            .padding(NLMetrics.margin)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// No QR on iPhone: the phone itself opens Wally.
    private var showsQR: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
    }
    #endif

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "Nordic Crypto Shield")
                .font(NLFont.display)
                .foregroundStyle(NL.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("badge-screen")
            Text("Edition of 1,000, while supply lasts.")
                .font(NLFont.row)
                .foregroundStyle(NL.textPrimary)
            if let minted = store.minted {
                Text("\(minted) / \(store.supply) minted")
                    .font(NLFont.title)
                    .foregroundStyle(Self.gold)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("badge-count")
            }
            Text("Free from Nordic Crypto, you pay a small Nexa network fee yourself.")
                .font(NLFont.body)
                .foregroundStyle(NL.textSecondary)
            Text("Collectible badge, no economic rights.")
                .font(NLFont.caption)
                .foregroundStyle(NL.textTertiary)
            status
        }
    }

    @ViewBuilder private var status: some View {
        switch store.phase {
        case .soldOut: note("All 1,000 badges have been minted.")
        case .notLaunched: note("Minting opens soon.")
        case .sent(let n?): note("Badge #\(n) sent.")
        case .sent(nil): note("Badge sent.")
        case .loading, .ready, .offline: EmptyView()
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(NLFont.row)
            .foregroundStyle(NL.accent)
    }

    private func shield(_ size: CGFloat) -> some View {
        Image("Shield")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
            .accessibilityHidden(true)
    }

    /// The live Wally link when there is one, otherwise the web page.
    private var qrText: String { store.link?.absoluteString ?? BadgeStore.page.absoluteString }

    private var scanHint: LocalizedStringKey {
        store.link == nil ? "Scan with your phone" : "Scan with Wally Wallet on your phone, then confirm."
    }

    private func qr(_ size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white)
            if store.phase == .loading {
                ProgressView().tint(Self.teal)
            } else if let image = QRCode.image(qrText) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.05)
                    .accessibilityLabel(Text(scanHint))
                    .accessibilityIdentifier("badge-qr")
            }
        }
        .frame(width: size, height: size)
    }
}

enum QRCode {
    static func image(_ text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
