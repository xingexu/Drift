import Foundation

// MARK: - App Classifier

/// Classifies applications and web domains into productivity categories.
///
/// Uses a two-tier lookup strategy:
/// 1. **Bundle identifier** (preferred) -- reliable across localizations and renames.
/// 2. **Display name** (fallback) -- covers apps whose bundle ID is unknown.
///
/// Unknown apps default to ``AppCategory/neutral`` so users are never
/// penalised for software the classifier has not seen before.
struct AppClassifier {

    private static let overrideDefaultsKey = "drift_classification_overrides"

    private static func savedOverride(for key: String) -> AppCategory? {
        guard let data = UserDefaults.standard.data(forKey: overrideDefaultsKey),
              let overrides = try? JSONDecoder().decode([String: AppCategory].self, from: data) else {
            return nil
        }
        return overrides[key.lowercased()]
    }

    // MARK: - Bundle-ID Classification

    /// Maps known bundle identifiers to their productivity category.
    ///
    /// Entries are grouped by purpose to simplify maintenance. Every bundle ID
    /// is lowercased at lookup time so casing in this table does not matter.
    private static let bundleCategories: [String: AppCategory] = {
        var map = [String: AppCategory]()

        // -- IDEs & Editors -----------------------------------------------
        let productiveBundles: [String] = [
            // Apple
            "com.apple.dt.Xcode",
            "com.apple.ScriptEditor2",
            // Microsoft
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            // JetBrains
            "com.jetbrains.intellij",
            "com.jetbrains.intellij.ce",
            "com.jetbrains.WebStorm",
            "com.jetbrains.pycharm",
            "com.jetbrains.pycharm.ce",
            "com.jetbrains.CLion",
            "com.jetbrains.goland",
            "com.jetbrains.rider",
            "com.jetbrains.AppCode",
            "com.jetbrains.rubymine",
            "com.jetbrains.PhpStorm",
            "com.jetbrains.datagrip",
            "com.jetbrains.fleet",
            // Other editors
            "com.sublimetext.4",
            "com.sublimetext.3",
            "com.panic.Nova",
            "com.barebones.bbedit",
            "com.macromates.TextMate",
            "com.todesktop.230313mzl4w4u92",   // Cursor
            "dev.zed.Zed",

            // -- Terminals ------------------------------------------------
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "io.alacritty",
            "co.zeit.hyper",
            "com.mitchellh.ghostty",

            // -- Design ---------------------------------------------------
            "com.figma.Desktop",
            "com.bohemiancoding.sketch3",
            "com.serif.affinity-designer-2",
            "com.serif.affinity-photo-2",
            "com.adobe.Photoshop",
            "com.adobe.illustrator",
            "com.adobe.InDesign",
            "com.adobe.Lightroom",
            "com.adobe.AdobeXD",

            // -- Productivity & Notes -------------------------------------
            "notion.id",
            "md.obsidian",
            "net.shinyfrog.bear",
            "com.logseq.logseq",
            "com.lukilabs.lukiapp",             // Craft
            "com.apple.iWork.Pages",
            "com.apple.iWork.Numbers",
            "com.apple.iWork.Keynote",
            "com.microsoft.Word",
            "com.microsoft.Excel",
            "com.microsoft.Powerpoint",
            "com.apple.Notes",
            "com.apple.reminders",
            "com.apple.iCal",
            "com.apple.Preview",
            "com.apple.finder",

            // -- Communication (work) -------------------------------------
            "com.tinyspeck.slackmacgap",        // Slack
            "com.microsoft.teams2",
            "us.zoom.xos",

            // -- API & Database -------------------------------------------
            "com.postmanlabs.mac",
            "com.kong.insomnia",
            "com.docker.docker",
            "com.tinyapp.TablePlus",
            "com.sequel-pro.sequel-pro",
            "at.eggerapps.Postico2",
            "com.dbeaver.product.enterprise",

            // -- Git clients ----------------------------------------------
            "com.github.GitHubClient",
            "com.fournova.Tower3",
            "com.fournova.Tower4",
            "com.todesktop.2307ppabr13kgs4",    // Fork
            "com.atlassian.SourcetreeX",

            // -- Project management ---------------------------------------
            "com.linear",
        ]

        // -- Entertainment & Social Media ---------------------------------
        let distractionBundles: [String] = [
            "com.hnc.Discord",
            "com.hammerandchisel.discord",
            "org.whispersystems.signal-desktop",
            "ru.keepcoder.Telegram",
            "net.whatsapp.WhatsApp",
            "com.spotify.client",
            "com.apple.Music",
            "org.videolan.vlc",
            "com.colliderli.iina",
            "com.apple.QuickTimePlayerX",
            "com.apple.FaceTime",
            "com.apple.MobileSMS",              // Messages
            "com.valvesoftware.steam",
            "com.epicgames.EpicGamesLauncher",
            "com.apple.TV",
            "com.apple.podcasts",
            "com.riotgames.LeagueofLegends.GameClient",
        ]

        for id in productiveBundles { map[id.lowercased()] = .productive }
        for id in distractionBundles { map[id.lowercased()] = .distraction }
        return map
    }()

    // MARK: - Display-Name Classification

    /// Fallback lookup table keyed by the app's localized display name.
    ///
    /// Matching is case-insensitive. Prefer adding a bundle ID above when
    /// possible; this table exists for apps whose ID varies across versions.
    private static let productiveAppNames: Set<String> = [
        "Xcode", "Visual Studio Code", "Code", "Cursor", "Zed",
        "Terminal", "iTerm2", "Warp", "Alacritty", "Hyper", "Ghostty",
        "IntelliJ IDEA", "IntelliJ IDEA CE", "WebStorm", "PyCharm",
        "PyCharm CE", "CLion", "GoLand", "Rider", "AppCode",
        "RubyMine", "PhpStorm", "DataGrip", "Fleet",
        "Sublime Text", "Nova", "BBEdit", "TextMate",
        "Figma", "Sketch", "Affinity Designer", "Affinity Designer 2",
        "Affinity Photo", "Affinity Photo 2",
        "Adobe Photoshop", "Adobe Illustrator", "Adobe InDesign",
        "Adobe Lightroom", "Adobe XD",
        "Notion", "Obsidian", "Bear", "Logseq", "Craft",
        "Slack", "Microsoft Teams", "Zoom",
        "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint",
        "Pages", "Numbers", "Keynote",
        "Postman", "Insomnia",
        "Docker Desktop", "Docker", "TablePlus", "Postico", "Postico 2",
        "Sequel Pro", "DBeaver",
        "Preview", "Finder", "Notes", "Reminders", "Calendar",
        "GitHub Desktop", "Tower", "Fork", "Sourcetree",
        "Linear", "Jira", "Asana", "Trello",
        "Script Editor",
    ]

    private static let distractionAppNames: Set<String> = [
        "Discord", "Telegram", "WhatsApp", "Signal",
        "Spotify", "Apple Music", "Music",
        "VLC", "IINA", "QuickTime Player",
        "Messages", "FaceTime",
        "Steam", "Epic Games Launcher",
        "TikTok", "Instagram",
        "TV", "Podcasts",
        "League of Legends",
    ]

    /// Pre-computed lowercase lookup sets built once at launch.
    private static let productiveNamesLower: Set<String> = Set(productiveAppNames.map { $0.lowercased() })
    private static let distractionNamesLower: Set<String> = Set(distractionAppNames.map { $0.lowercased() })

    // MARK: - App Classification

    /// Classifies an application by bundle identifier and display name.
    ///
    /// The bundle identifier takes priority when available because it is
    /// stable across OS locales. Falls back to a case-insensitive name
    /// match, then defaults to ``AppCategory/neutral``.
    ///
    /// - Parameters:
    ///   - appName: The localized display name of the application.
    ///   - bundleId: The application's `CFBundleIdentifier`, if known.
    /// - Returns: The inferred ``AppCategory``.
    static func classify(appName: String, bundleId: String? = nil) -> AppCategory {
        if let id = bundleId?.lowercased(), let category = savedOverride(for: "bundle:\(id)") {
            return category
        }
        if let category = savedOverride(for: "app:\(appName.lowercased())") {
            return category
        }

        // 1. Try bundle identifier (most reliable).
        if let id = bundleId?.lowercased(), let category = bundleCategories[id] {
            return category
        }

        // 2. Fallback to display name (case-insensitive).
        let nameLower = appName.lowercased()
        if productiveNamesLower.contains(nameLower) { return .productive }
        if distractionNamesLower.contains(nameLower) { return .distraction }

        return .neutral
    }

    /// Convenience overload that matches the original single-argument call site.
    static func classify(appName: String) -> AppCategory {
        classify(appName: appName, bundleId: nil)
    }

    // MARK: - Domain Classification

    /// Known productive web domains.
    private static let productiveDomains: Set<String> = [
        // Documentation & Code
        "docs.google.com", "sheets.google.com", "slides.google.com",
        "github.com", "gitlab.com", "bitbucket.org",
        "stackoverflow.com", "stackexchange.com",
        "developer.apple.com", "developer.mozilla.org",
        "docs.swift.org", "docs.rs", "pkg.go.dev",
        "crates.io", "pypi.org", "npmjs.com", "rubygems.org",
        // Productivity SaaS
        "notion.so", "linear.app", "figma.com",
        "asana.com", "trello.com", "monday.com", "clickup.com",
        "jira.atlassian.com", "confluence.atlassian.com",
        "miro.com", "excalidraw.com",
        // Cloud & DevOps
        "vercel.com", "netlify.com", "heroku.com",
        "console.aws.amazon.com", "cloud.google.com", "portal.azure.com",
        "supabase.com", "firebase.google.com",
        "sentry.io", "datadog.com", "grafana.com",
        "fly.io", "render.com", "railway.app",
        // Learning
        "medium.com", "dev.to", "hashnode.dev",
        "coursera.org", "udemy.com", "edx.org",
        "khanacademy.org", "brilliant.org",
        "pluralsight.com", "frontendmasters.com",
        "egghead.io", "codecademy.com",
        "leetcode.com", "hackerrank.com",
        // Communication (work)
        "slack.com", "teams.microsoft.com",
        "mail.google.com", "outlook.office.com",
        "calendar.google.com",
        "zoom.us",
    ]

    /// Known distraction web domains.
    private static let distractionDomains: Set<String> = [
        // Video
        "netflix.com", "twitch.tv", "hulu.com",
        "disneyplus.com", "primevideo.com", "crunchyroll.com",
        // Social
        "threads.net", "bsky.app", "mastodon.social",
        // Entertainment
        "9gag.com", "buzzfeed.com", "imgur.com", "giphy.com",
        // Messaging
        "discord.com", "web.whatsapp.com", "web.telegram.org",
        // Shopping
        "amazon.com", "ebay.com", "aliexpress.com", "etsy.com",
        // Gaming
        "store.steampowered.com", "twitch.tv",
    ]

    /// Domains where the page title/query matters more than the domain.
    private static let contextDependentDomains: Set<String> = [
        "youtube.com", "youtu.be",
        "linkedin.com",
        "reddit.com",
        "twitter.com", "x.com",
        "instagram.com", "facebook.com", "tiktok.com",
    ]

    private static let productiveSignals: [(phrase: String, weight: Int)] = [
        ("tutorial", 3), ("lecture", 3), ("lesson", 3), ("course", 3),
        ("study", 2), ("learn", 2), ("explained", 2), ("walkthrough", 2),
        ("documentary", 2), ("research", 3), ("paper", 2), ("case study", 2),
        ("university", 2), ("mit ", 2), ("stanford", 2), ("harvard", 2),
        ("khan academy", 4), ("crash course", 3), ("freecodecamp", 4),
        ("programming", 3), ("coding", 3), ("software engineering", 3),
        ("swift", 2), ("python", 2), ("javascript", 2), ("typescript", 2),
        ("react", 2), ("xcode", 2), ("api", 2), ("debug", 2),
        ("math", 2), ("calculus", 2), ("physics", 2), ("chemistry", 2),
        ("biology", 2), ("history", 1), ("economics", 2), ("design", 2),
        ("engineering", 3), ("conference", 2), ("keynote", 1),
        ("interview prep", 3), ("portfolio", 2), ("resume", 3),
        ("job", 2), ("jobs", 2), ("career", 2), ("hiring", 2),
        ("recruiter", 2), ("certification", 3),
    ]

    private static let distractionSignals: [(phrase: String, weight: Int)] = [
        ("shorts", 5), ("meme", 3), ("memes", 3), ("prank", 3),
        ("reaction", 2), ("drama", 3), ("gossip", 4), ("celebrity", 3),
        ("vlog", 3), ("haul", 3), ("challenge", 2), ("compilation", 2),
        ("fails", 3), ("music video", 4), ("official video", 2),
        ("trailer", 3), ("highlights", 2), ("gameplay", 3), ("stream", 2),
        ("fortnite", 4), ("minecraft", 3), ("valorant", 4),
        ("league of legends", 4), ("tiktok", 4), ("funny", 3),
        ("comedy", 3), ("shopping", 2), ("sale", 2), ("viral", 3),
        ("feed", 2), ("notifications", 2),
    ]

    private static let productiveSubredditSignals: [String] = [
        "learnprogramming", "programming", "swift", "iosprogramming",
        "webdev", "javascript", "typescript", "machinelearning",
        "science", "askscience", "askacademia", "productivity",
        "cscareerquestions", "design", "userexperience",
    ]

    /// Classifies a URL or bare domain into a productivity category.
    ///
    /// Performs an exact domain match first, then checks whether the input
    /// domain is a subdomain of any known entry (e.g. `m.youtube.com` matches
    /// `youtube.com`). Returns ``AppCategory/neutral`` for unrecognised domains.
    ///
    /// - Parameter urlString: A full URL or bare domain string.
    /// - Returns: The inferred ``AppCategory``.
    static func classifyDomain(_ urlString: String) -> AppCategory {
        guard let host = extractHost(from: urlString) else { return .neutral }

        let domain = normalizeHost(host)

        if let category = savedOverride(for: "domain:\(domain)") {
            return category
        }

        // Exact match.
        if productiveDomains.contains(domain) { return .productive }
        if distractionDomains.contains(domain) { return .distraction }

        // Subdomain match (e.g. "m.reddit.com" -> "reddit.com").
        for d in productiveDomains where domain.hasSuffix("." + d) {
            return .productive
        }
        for d in distractionDomains where domain.hasSuffix("." + d) {
            return .distraction
        }

        return .neutral
    }

    /// Classifies web activity using both the domain and page context.
    ///
    /// Context-dependent sites such as YouTube are not blanket-labelled as
    /// distractions. Their page title, URL path, and query decide whether the
    /// activity looks educational/productive, distracting, or neutral.
    static func classifyWebContext(urlString: String?, title: String, fallback: AppCategory = .neutral) -> AppCategory {
        let context = WebContext(urlString: urlString, title: title)

        if let domain = context.domain,
           let category = savedOverride(for: "domain:\(normalizeHost(domain))") {
            return category
        }

        let productiveScore = signalScore(in: context.searchableText, signals: productiveSignals)
        let distractionScore = signalScore(in: context.searchableText, signals: distractionSignals)

        if let domain = context.domain, isContextDependentDomain(domain) {
            if domain == "youtube.com" || domain.hasSuffix(".youtube.com") || domain == "youtu.be" {
                return classifyYouTube(context, productiveScore: productiveScore, distractionScore: distractionScore)
            }
            if domain == "linkedin.com" || domain.hasSuffix(".linkedin.com") {
                return classifyLinkedIn(context, productiveScore: productiveScore, distractionScore: distractionScore)
            }
            if domain == "reddit.com" || domain.hasSuffix(".reddit.com") {
                return classifyReddit(context, productiveScore: productiveScore, distractionScore: distractionScore)
            }
            return classifyAmbiguousSocial(context, productiveScore: productiveScore, distractionScore: distractionScore)
        }

        if productiveScore >= 3 && productiveScore > distractionScore { return .productive }
        if distractionScore >= 3 && distractionScore > productiveScore { return .distraction }

        if let urlString {
            let domainCategory = classifyDomain(urlString)
            if domainCategory != .neutral { return domainCategory }
        }

        return fallback
    }

    // MARK: - Helpers

    private struct WebContext {
        let domain: String?
        let path: String
        let query: String
        let title: String
        let searchableText: String

        init(urlString: String?, title: String) {
            self.title = AppClassifier.normalizedText(title)

            guard let urlString, let url = AppClassifier.parseURL(urlString) else {
                self.domain = nil
                self.path = ""
                self.query = ""
                self.searchableText = AppClassifier.normalizedText(title)
                return
            }

            self.domain = url.host.map(AppClassifier.normalizeHost)
            self.path = AppClassifier.normalizedText(url.path)
            self.query = AppClassifier.normalizedText(url.query ?? "")
            self.searchableText = [title, url.path, url.query ?? "", urlString]
                .map(AppClassifier.normalizedText)
                .joined(separator: " ")
        }

        func pathStarts(with prefix: String) -> Bool {
            path == prefix || path.hasPrefix(prefix + "/")
        }

        func pathContains(_ fragment: String) -> Bool {
            path.contains(fragment)
        }
    }

    private static func classifyYouTube(
        _ context: WebContext,
        productiveScore: Int,
        distractionScore: Int
    ) -> AppCategory {
        if context.domain == "music.youtube.com" {
            return productiveScore >= 4 && productiveScore > distractionScore ? .productive : .distraction
        }

        if context.pathStarts(with: "/shorts")
            || context.pathStarts(with: "/feed/trending")
            || context.pathStarts(with: "/gaming")
            || context.pathStarts(with: "/music") {
            return productiveScore >= 4 && productiveScore > distractionScore ? .productive : .distraction
        }

        if context.pathStarts(with: "/results") {
            if productiveScore >= 3 && productiveScore > distractionScore { return .productive }
            if distractionScore >= 3 && distractionScore > productiveScore { return .distraction }
            return .neutral
        }

        if context.pathStarts(with: "/watch") || context.domain == "youtu.be" {
            if productiveScore >= max(3, distractionScore + 1) { return .productive }
            if distractionScore >= max(3, productiveScore + 1) { return .distraction }
            return .neutral
        }

        if context.pathStarts(with: "/@")
            || context.pathStarts(with: "/channel")
            || context.pathStarts(with: "/c") {
            if productiveScore >= 3 && productiveScore >= distractionScore { return .productive }
            if distractionScore >= 3 && distractionScore > productiveScore { return .distraction }
        }

        return .neutral
    }

    private static func classifyLinkedIn(
        _ context: WebContext,
        productiveScore: Int,
        distractionScore: Int
    ) -> AppCategory {
        if context.pathStarts(with: "/learning")
            || context.pathStarts(with: "/jobs")
            || context.pathStarts(with: "/in")
            || context.pathStarts(with: "/company")
            || context.pathStarts(with: "/school")
            || context.pathStarts(with: "/sales") {
            return .productive
        }

        if context.pathStarts(with: "/feed")
            || context.pathStarts(with: "/notifications")
            || context.pathStarts(with: "/games") {
            return productiveScore >= 4 && productiveScore > distractionScore ? .productive : .distraction
        }

        if productiveScore >= 3 && productiveScore > distractionScore { return .productive }
        if distractionScore >= 3 && distractionScore > productiveScore { return .distraction }
        return .neutral
    }

    private static func classifyReddit(
        _ context: WebContext,
        productiveScore: Int,
        distractionScore: Int
    ) -> AppCategory {
        if context.pathStarts(with: "/r/all") || context.pathStarts(with: "/r/popular") {
            return .distraction
        }

        if productiveSubredditSignals.contains(where: { context.pathContains("/r/\($0)") }) {
            return distractionScore >= productiveScore + 2 ? .neutral : .productive
        }

        if productiveScore >= 3 && productiveScore > distractionScore { return .productive }
        if distractionScore >= 3 && distractionScore > productiveScore { return .distraction }
        return .neutral
    }

    private static func classifyAmbiguousSocial(
        _ context: WebContext,
        productiveScore: Int,
        distractionScore: Int
    ) -> AppCategory {
        if context.pathStarts(with: "/feed")
            || context.pathStarts(with: "/explore")
            || context.pathStarts(with: "/reels")
            || context.pathStarts(with: "/notifications")
            || context.pathStarts(with: "/home") {
            return productiveScore >= 4 && productiveScore > distractionScore ? .productive : .distraction
        }

        if productiveScore >= 4 && productiveScore > distractionScore { return .productive }
        if distractionScore >= 3 && distractionScore >= productiveScore { return .distraction }
        return .neutral
    }

    private static func signalScore(in text: String, signals: [(phrase: String, weight: Int)]) -> Int {
        signals.reduce(0) { total, signal in
            text.contains(signal.phrase) ? total + signal.weight : total
        }
    }

    /// Extracts the host component from a URL string or bare domain.
    private static func extractHost(from urlString: String) -> String? {
        if let url = parseURL(urlString), let host = url.host {
            return host
        }

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("."), !trimmed.contains(" ") else { return nil }

        let end = trimmed.firstIndex(where: { ["/", "?", "#"].contains($0) }) ?? trimmed.endIndex
        let host = String(trimmed[..<end])
        return host.isEmpty ? nil : host
    }

    private static func parseURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.host != nil {
            return url
        }

        if !trimmed.contains(" "), let url = URL(string: "https://" + trimmed), url.host != nil {
            return url
        }

        return nil
    }

    private static func normalizeHost(_ host: String) -> String {
        let lowercased = host.lowercased()
        return lowercased.hasPrefix("www.") ? String(lowercased.dropFirst(4)) : lowercased
    }

    private static func normalizedText(_ value: String) -> String {
        let decoded = value.removingPercentEncoding ?? value
        return decoded
            .lowercased()
            .replacingOccurrences(of: "+", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func isContextDependentDomain(_ domain: String) -> Bool {
        if contextDependentDomains.contains(domain) { return true }
        return contextDependentDomains.contains { domain.hasSuffix("." + $0) }
    }
}
