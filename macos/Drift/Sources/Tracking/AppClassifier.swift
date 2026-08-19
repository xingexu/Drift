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
        "reddit.com",
        "twitter.com", "x.com",
        "instagram.com", "facebook.com", "tiktok.com",
    ]

    private static let educationalSignals: [String] = [
        "tutorial", "lecture", "lesson", "course", "study", "learn",
        "explained", "walkthrough", "documentary", "research", "paper",
        "university", "mit ", "stanford", "harvard", "khan academy",
        "crash course", "programming", "coding", "swift", "python",
        "javascript", "typescript", "math", "calculus", "physics",
        "chemistry", "biology", "history", "economics", "design",
        "engineering", "conference", "keynote", "interview",
    ]

    private static let distractionSignals: [String] = [
        "shorts", "meme", "memes", "prank", "reaction", "drama", "gossip",
        "celebrity", "vlog", "haul", "challenge", "compilation", "fails",
        "music video", "official video", "trailer", "highlights", "gameplay",
        "stream", "fortnite", "minecraft", "valorant", "league of legends",
        "tiktok", "funny", "comedy", "shopping",
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

        let domain = host
            .lowercased()
            .replacingOccurrences(of: "www.", with: "")

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
        let context = [
            title,
            urlString ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
        .replacingOccurrences(of: "%20", with: " ")
        .replacingOccurrences(of: "+", with: " ")

        let hasEducationalSignal = educationalSignals.contains { context.contains($0) }
        let hasDistractionSignal = distractionSignals.contains { context.contains($0) }

        if let urlString,
           let host = extractHost(from: urlString)?.lowercased().replacingOccurrences(of: "www.", with: ""),
           isContextDependentDomain(host) {
            if hasEducationalSignal && !hasDistractionSignal { return .productive }
            if hasDistractionSignal && !hasEducationalSignal { return .distraction }
            return .neutral
        }

        if hasEducationalSignal && !hasDistractionSignal { return .productive }
        if hasDistractionSignal && !hasEducationalSignal { return .distraction }

        if let urlString {
            let domainCategory = classifyDomain(urlString)
            if domainCategory != .neutral { return domainCategory }
        }

        return fallback
    }

    // MARK: - Helpers

    /// Extracts the host component from a URL string or bare domain.
    private static func extractHost(from urlString: String) -> String? {
        // Try standard URL parsing first.
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        // Treat bare domain-like strings (contains a dot, no spaces).
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return trimmed
        }
        return nil
    }

    private static func isContextDependentDomain(_ domain: String) -> Bool {
        if contextDependentDomains.contains(domain) { return true }
        return contextDependentDomains.contains { domain.hasSuffix("." + $0) }
    }
}
