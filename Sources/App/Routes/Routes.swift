import Vapor
import Kanna
import Foundation

extension Droplet {
    func setupRoutes() throws {
        get("hello") { req in
            var json = JSON()
            try json.set("hello", "world")
            return json
        }

        get("plaintext") { req in
            return "Hello, world!"
        }

        // response to requests to /info domain
        // with a description of the request
        get("info") { req in
            return req.description
        }

        get("description") { req in return req.description }

        get("nytimes") { req in
            guard let sections = self.parseNYTimes() else { throw Abort(.badRequest, metadata: nil, reason: "Could not find headlines", identifier: nil, possibleCauses: nil, suggestedFixes: nil, documentationLinks: nil, stackOverflowQuestions: nil, gitHubIssues: nil) }
            var json = JSON()
            try json.set("value", sections.map { $0.json })
            return json
        }
        
        try resource("posts", PostController.self)
    }

    func parseNYTimes() -> [Section]? {
        var sections = [Section]()
        let url = URL(string: "http://www.nytimes.com/pages/todayspaper/index.html")!
        if let doc = try? Kanna.HTML(url: url, encoding: .utf8) {
            var headlinesForSection = [Headline]()
            var headlinesForOtherSections = [Headline]()
            for storybody in doc.css("article.story > div.story-body") {
                let pageString = "Page A1"
                if  let headline = storybody.at_css("h2.headline > a"),
                    let headlineText = headline.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                    let urlString = headline["href"] {
                    let hl = Headline(headline: headlineText, link: urlString, page: pageString)
                    headlinesForSection.append(hl)
                }
            }
            for storybody in doc.css("li.supplement-group > div.story-body") {
                var pageString = "Page A1"
                if let page = storybody.at_css("footer.story-footer") {
                    pageString = page.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
                if  let headline = storybody.at_css("h2.headline > a"),
                    let headlineText = headline.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                    let urlString = headline["href"] {
                    let hl = Headline(headline: headlineText, link: urlString, page: pageString)
                    if pageString == "Page A1" {
                        console.print(pageString)
                        headlinesForSection.append(hl)
                    }
                    else {
                        console.print(pageString)
                        headlinesForOtherSections.append(hl)
                    }
                }
            }
            sections.append(Section(title: "The Front Page", headlines: headlinesForSection))
            for storybody in doc.css("li.stream-body") {
                var pageString = ""
                if let page = storybody.at_css("footer.story-footer") {
                    pageString = page.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
                if  let headline = storybody.at_css("h2.headline > a"),
                    let headlineText = headline.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                    let urlString = headline["href"] {
                    let hl = Headline(headline: headlineText, link: urlString, page: pageString)
                        headlinesForOtherSections.append(hl)
                }
            }
            sections.append(Section(title: "Other Sections", headlines: headlinesForOtherSections))
            return sections
        }
        else {
            return nil
        }
    }
}

struct Section {
    let title: String
    let headlines: [Headline]

    var json: [String: Any] {
        return [
            "title": title,
            "headlines": headlines.map { $0.json }
        ]
    }
}

struct Headline {
    let headline: String
    let link: String
    let page: String

    var json: [String: Any] {
        return [
            "headline": headline,
            "link": link,
            "page": page
        ]
    }
}

extension Headline: Equatable {
    static func ==(lhs: Headline, rhs: Headline) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension Headline: Hashable {
    var hashValue: Int {
        return link.hashValue
    }
}
