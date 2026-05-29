import Foundation
import Testing

@testable import Wardrobe

struct HTMLStripperTests {

    @Test func stripsBasicTags() {
        #expect(HTMLStripper.strip("<p>Hello, <b>world</b>!</p>") == "Hello, world!")
    }

    @Test func removesScriptAndStyleBlocksIncludingContent() {
        let html = """
        Before
        <script type="text/javascript">var x = 1;</script>
        Middle
        <style>.a{color:red;}</style>
        After
        """
        let out = HTMLStripper.strip(html)
        #expect(!out.contains("var x"))
        #expect(!out.contains("color:red"))
        #expect(out.contains("Before"))
        #expect(out.contains("Middle"))
        #expect(out.contains("After"))
    }

    @Test func stripsHTMLComments() {
        let out = HTMLStripper.strip("<!-- hidden -->visible<!-- also hidden -->")
        #expect(out == "visible")
    }

    @Test func decodesNamedEntities() {
        let out = HTMLStripper.strip("Cats &amp; Dogs &copy; 2026 &mdash; sale &pound;9.99")
        #expect(out == "Cats & Dogs © 2026 — sale £9.99")
    }

    @Test func decodesNumericEntities() {
        // &#39; → ' ;  &#x2014; → — (em-dash)
        let out = HTMLStripper.strip("It&#39;s great &#x2014; really")
        #expect(out == "It's great — really")
    }

    @Test func convertsBlockTagsToNewlines() {
        let out = HTMLStripper.strip("<p>One</p><p>Two</p><div>Three</div>")
        #expect(out == "One\nTwo\nThree")
    }

    @Test func collapsesWhitespace() {
        let out = HTMLStripper.strip("<p>Hello    \t  world</p>")
        #expect(out == "Hello world")
    }

    @Test func leavesPlainTextUntouched() {
        #expect(HTMLStripper.strip("Just plain text.") == "Just plain text.")
    }

    @Test func handlesEmptyInput() {
        #expect(HTMLStripper.strip("") == "")
    }

    @Test func leavesMalformedEntityIntact() {
        // No semicolon within bounded range → don't decode.
        #expect(HTMLStripper.strip("AT&T won't decode") == "AT&T won't decode")
    }
}
