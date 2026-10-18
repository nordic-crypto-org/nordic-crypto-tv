#if os(iOS)
import SwiftUI

/// Staff-only, English only like the web admin (nordiccrypto.no/admin/). Read-only.
struct AdminView: View {
    @State private var store = AdminStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch store.phase {
            case .signedOut: AdminSignIn(store: store)
            case .codeSent(let email): AdminCodeEntry(store: store, email: email)
            case .signedIn(let email): AdminData(store: store, email: email)
            }
        }
        .navigationTitle(Text(verbatim: "Admin"))
        .navigationBarTitleDisplayMode(.inline)
        // Keep subscriber addresses out of the app switcher snapshot.
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Rectangle().fill(.background)
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
                }
                .ignoresSafeArea()
            }
        }
        .accessibilityIdentifier("admin-screen")
    }
}

private struct AdminMessage: View {
    let text: String?

    var body: some View {
        if let text {
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("admin-message")
        }
    }
}

private struct AdminSignIn: View {
    let store: AdminStore
    @State private var email = ""

    var body: some View {
        Form {
            Section {
                TextField(text: $email, prompt: Text(verbatim: "name@\(AdminConfig.domain)")) { Text(verbatim: "Email") }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityIdentifier("admin-email")
                Button(action: send) { Text(verbatim: "Send sign-in code") }
                    .disabled(store.busy || email.isEmpty)
            } header: {
                Text(verbatim: "Staff sign-in")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "For Nordic Crypto staff. Sign in with your @\(AdminConfig.domain) address; you get a one-time code by email.")
                    AdminMessage(text: store.message)
                }
            }
        }
    }

    private func send() {
        Task { await store.requestCode(email: email) }
    }
}

private struct AdminCodeEntry: View {
    let store: AdminStore
    let email: String
    @State private var code = ""

    var body: some View {
        Form {
            Section {
                TextField(text: $code, prompt: Text(verbatim: "1234 5678")) { Text(verbatim: "Code") }
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .font(.title3.monospacedDigit())
                    .accessibilityIdentifier("admin-code")
                Button { Task { await store.verify(code: code) } } label: { Text(verbatim: "Sign in") }
                    .disabled(store.busy || AdminCode.normalized(code) == nil)
                Button { store.startOver() } label: { Text(verbatim: "Use another address") }
            } header: {
                Text(verbatim: "Code sent to \(email)")
            } footer: {
                AdminMessage(text: store.message)
            }
        }
    }
}

private struct AdminData: View {
    let store: AdminStore
    let email: String
    @State private var query = ""
    @State private var status: String?
    @State private var sort: AdminSort = .newest

    var body: some View {
        List {
            Section {
                LabeledContent { Text(verbatim: email) } label: { Text(verbatim: "Signed in as") }
                Button(role: .destructive) { Task { await store.signOut() } } label: { Text(verbatim: "Sign out") }
                AdminMessage(text: store.message)
            }
            if let subs = store.subscribers {
                subscribers(subs)
                press
            } else if store.message == nil {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .searchable(text: $query, prompt: Text(verbatim: "Search email, language, issue"))
        .refreshable { await store.load() }
        .task { if store.subscribers == nil { await store.load() } }
    }

    @ViewBuilder
    private func subscribers(_ subs: AdminSubscribers) -> some View {
        let t = subs.totals
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                total("All", t.all)
                total("Confirmed", t.confirmed)
                total("Pending", t.pending)
                total("Unsubscribed", t.unsubscribed)
                total("Deliveries", t.deliveries)
                total("Last issue", subs.lastIssue.map { "#\($0)" } ?? "–")
            }
            .padding(.vertical, 4)
            Picker(selection: $status) {
                Text(verbatim: "All statuses").tag(String?.none)
                ForEach(["confirmed", "pending", "unsubscribed"], id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
            } label: { Text(verbatim: "Status") }
            Picker(selection: $sort) {
                ForEach(AdminSort.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Sort") }
        } header: {
            Text(verbatim: "Newsletter subscribers")
        }
        let list = AdminFilter.subscribers(subs.rows, query: query, status: status, sort: sort)
        Section {
            ForEach(list) { AdminSubscriberRow(row: $0) }
        } header: {
            Text(verbatim: "\(list.count) / \(subs.rows.count)")
        }
    }

    private func total(_ label: String, _ value: Int) -> some View { total(label, String(value)) }

    private func total(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.title2.bold().monospacedDigit()).foregroundStyle(NL.accent)
            Text(verbatim: label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var press: some View {
        Section {
            if store.pressReleases.isEmpty {
                Text(verbatim: "No press releases yet.").foregroundStyle(.secondary)
            }
            ForEach(store.pressReleases.sorted { ($0.published ?? "", $0.id) > ($1.published ?? "", $1.id) }) { r in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: r.title ?? r.id).font(.subheadline.weight(.semibold))
                    Text(verbatim: "\(r.published ?? "") · \(r.languages?.count ?? 0) languages · \(r.emailsSent ?? 0) emails sent · \(r.status ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(verbatim: "Press releases")
        }
        Section {
            if let sends = store.pressSends {
                if sends.isEmpty { Text(verbatim: "No press emails sent yet.").foregroundStyle(.secondary) }
                ForEach(sends) { s in
                    DisclosureGroup {
                        ForEach(s.recipients, id: \.self) { x in
                            Text(verbatim: [x.email, x.status, x.error ?? ""].filter { !$0.isEmpty }.joined(separator: " – ")).font(.caption)
                        }
                    } label: {
                        Text(verbatim: "\(s.releaseId) · \(AdminFilter.minute(s.at)) (Oslo) · \(s.fromAddr) · sent \(s.sent), failed \(s.failed)\(s.dryRun ? " · DRY RUN" : "")")
                            .font(.caption)
                    }
                }
            } else {
                Text(verbatim: "Could not load the sends.").foregroundStyle(.secondary)
            }
        } header: {
            Text(verbatim: "Sends")
        } footer: {
            Text(verbatim: "Recipients come from the admin service and are shown only to you. Times are Oslo time.")
        }
    }
}

private struct AdminSubscriberRow: View {
    let row: AdminSubscriber

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: row.email).font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(verbatim: row.status)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(row.status == "confirmed" ? NL.accent.opacity(0.25) : Color.secondary.opacity(0.15), in: Capsule())
            }
            Text(verbatim: "\(row.lang ?? "–") · signed up \(AdminFilter.minute(row.createdAt))\(row.confirmedAt == nil ? "" : " · confirmed \(AdminFilter.minute(row.confirmedAt))") UTC")
                .font(.caption).foregroundStyle(.secondary)
            if !row.issues.isEmpty {
                Text(verbatim: "Issues " + row.issues.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
