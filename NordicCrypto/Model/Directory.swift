import Foundation

// The Nordic Crypto who's who (/api/v1/orgchart.json) and academia
// (/api/v1/academia.json): people, companies, public bodies, courses,
// research groups and student groups.

struct OrgChartFeed: Decodable {
    var entities: [OrgEntity]
}

struct OrgEntity: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: String?          // "person" or "organisation"
    var sector: String?        // "private" or "public"
    var country: String?
    var description: String?
    var descriptionI18n: [String: String]
    var role: String?
    var org: String?           // id of the organisation a person belongs to
    var group: String?
    var logo: CreditedImage?
    var image: CreditedImage?

    var isPerson: Bool { type == "person" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        sector = try? c.decodeIfPresent(String.self, forKey: .sector)
        country = try? c.decodeIfPresent(String.self, forKey: .country)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        descriptionI18n = (try? c.decodeIfPresent([String: String].self, forKey: .descriptionI18n)) ?? [:]
        role = try? c.decodeIfPresent(String.self, forKey: .role)
        org = try? c.decodeIfPresent(String.self, forKey: .org)
        group = try? c.decodeIfPresent(String.self, forKey: .group)
        logo = try? c.decodeIfPresent(CreditedImage.self, forKey: .logo)
        image = try? c.decodeIfPresent(CreditedImage.self, forKey: .image)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sector, country, description, role, org, group, logo, image
        case descriptionI18n = "description_i18n"
    }

    /// The description in `lang`; the English text only when `lang` is English.
    func description(for lang: String) -> String? {
        let text = descriptionI18n[lang] ?? (lang == "en" ? description : nil)
        return text?.isEmpty == true ? nil : text
    }
}

/// A photo or logo with the licence details its credit line needs.
struct CreditedImage: Decodable, Hashable {
    var kind: String?
    var fileURL: URL?
    var author: String?
    var license: String?
    var credit: String?

    enum CodingKeys: String, CodingKey {
        case kind, author, license, credit
        case fileURL = "file_url"
    }

    /// tvOS cannot draw SVG, so those logos fall back to a monogram.
    var displayableURL: URL? {
        guard let fileURL, fileURL.pathExtension.lowercased() != "svg" else { return nil }
        return fileURL
    }

    /// "Johannes Dalen Giske · CC BY-SA 4.0 · Wikimedia Commons"
    var creditLine: String? {
        let parts = [author, license, credit].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct AcademiaFeed: Decodable {
    var courses: [AcademiaItem]
    var groups: [AcademiaItem]
    var research: [AcademiaItem]
    var publications: [AcademiaItem]

    enum CodingKeys: String, CodingKey { case courses, groups, research, publications }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courses = (try? c.decodeIfPresent([AcademiaItem].self, forKey: .courses)) ?? []
        groups = (try? c.decodeIfPresent([AcademiaItem].self, forKey: .groups)) ?? []
        research = (try? c.decodeIfPresent([AcademiaItem].self, forKey: .research)) ?? []
        publications = (try? c.decodeIfPresent([AcademiaItem].self, forKey: .publications)) ?? []
    }

    var all: [AcademiaItem] { courses + groups + research + publications }
}

struct AcademiaItem: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var section: String?       // courses, groups, research, publications
    var institution: String?
    var code: String?
    var level: String?
    var country: String?
    var about: String?
    var aboutI18n: [String: String]
    var url: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, title, section, institution, code, level, country, about, url
        case aboutI18n = "about_i18n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try (c.decodeIfPresent(String.self, forKey: .name) ?? c.decode(String.self, forKey: .title))
        section = try? c.decodeIfPresent(String.self, forKey: .section)
        institution = try? c.decodeIfPresent(String.self, forKey: .institution)
        code = try? c.decodeIfPresent(String.self, forKey: .code)
        level = try? c.decodeIfPresent(String.self, forKey: .level)
        country = try? c.decodeIfPresent(String.self, forKey: .country)
        about = try? c.decodeIfPresent(String.self, forKey: .about)
        aboutI18n = (try? c.decodeIfPresent([String: String].self, forKey: .aboutI18n)) ?? [:]
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
    }

    func about(for lang: String) -> String? {
        aboutI18n.localized(lang, base: about)
    }
}

/// One card in the Apple TV spotlight: someone or something from industry,
/// the public sector or academia.
enum SpotlightItem: Identifiable, Hashable {
    case entity(OrgEntity)
    case academia(AcademiaItem)

    var id: String {
        switch self {
        case .entity(let e): "e-" + e.id
        case .academia(let a): "a-" + a.id
        }
    }
}

extension String {
    /// Up to the end of the first sentence ("e.g. the" and "Art. 63" do not end one).
    var firstSentence: String {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = s.range(of: #"[.!?؟।](?=\s+[\p{Lu}\p{Lo}]|$)|[。！？]"#, options: .regularExpression) else { return s }
        return String(s[..<r.upperBound])
    }
}
