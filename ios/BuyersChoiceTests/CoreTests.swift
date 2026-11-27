import XCTest
import CoreLocation
@testable import BuyersChoice

final class SwerefTests: XCTestCase {
    // Facit från pyproj (EPSG:3007 till EPSG:4326).
    func testToWGS84() {
        let c = Sweref.toWGS84(e: 144338, n: 6398567)
        XCTAssertEqual(c.latitude, 57.706221122, accuracy: 1e-7)
        XCTAssertEqual(c.longitude, 11.905026075, accuracy: 1e-7)
        let p = Sweref.toWGS84(e: 153287, n: 6395901)
        XCTAssertEqual(p.latitude, 57.682307005, accuracy: 1e-7)
        XCTAssertEqual(p.longitude, 12.055099549, accuracy: 1e-7)
    }

    func testRoundTrip() {
        let c = CLLocationCoordinate2D(latitude: 57.709513620, longitude: 11.780057011)
        let p = Sweref.fromWGS84(c)
        XCTAssertEqual(p.e, 136889, accuracy: 0.01)
        XCTAssertEqual(p.n, 6398951, accuracy: 0.01)
    }
}

final class TextTests: XCTestCase {
    func testFold() {
        XCTAssertEqual(Txt.fold("Linnégatan 20"), "linnegatan 20")
        XCTAssertEqual(Txt.fold("  Fröjas  backe, 10 "), "frojas backe 10")
        XCTAssertEqual(Txt.fold("Åkerö-vägen"), "akero vagen")
    }

    func testDistance() {
        XCTAssertEqual(Txt.dist(350), "350 m")
        XCTAssertEqual(Txt.dist(1260), "1,3 km")
        XCTAssertEqual(Txt.num(101868), "101 868")
    }

    func testPrettyName() {
        XCTAssertEqual(Txt.prettyName("ASKIM,DETALJPLAN FÖR BOSTÄDER VID SISJÖVÄGEN"), "Askim,detaljplan för Bostäder vid Sisjövägen")
        XCTAssertEqual(Txt.prettyName("12 - Del av SKF:s område"), "Del av SKF:s område")
    }

    func testBands() {
        XCTAssertEqual(EnvTexts.band([55, 60]), "55–60 dBA")
        XCTAssertEqual(EnvTexts.band([0, 45]), "under 45 dBA")
        XCTAssertEqual(EnvTexts.band([65, 100]), "över 65 dBA")
    }
}

final class SearchTests: XCTestCase {
    private func data() -> ([Street], [Address]) {
        var addrs: [Address] = []
        var streets: [Street] = []
        for (si, (name, nrs)) in [("Linnégatan", ["1", "2", "20", "20A"]), ("Övre Linnégatan", ["3"]), ("Lindholmsallén", ["1", "2"])].enumerated() {
            let first = addrs.count
            for nr in nrs {
                addrs.append(Address(id: addrs.count, label: "\(name) \(nr)", street: si, kommun: 0, local: addrs.count, nr: Txt.fold(nr).replacingOccurrences(of: " ", with: ""), e: 0, n: 0, plans: []))
            }
            streets.append(Street(name: name, folded: Txt.fold(name), first: first, count: nrs.count, kommun: 0, postort: "Göteborg"))
        }
        return (streets, addrs)
    }

    func testStreetAndNumber() {
        let (s, a) = data()
        let hits = AddressSearch.search("linnegatan 20", streets: s, addresses: a)
        XCTAssertEqual(hits, [.address(2), .address(3)])
    }

    func testStreetsFirst() {
        let (s, a) = data()
        let hits = AddressSearch.search("lin", streets: s, addresses: a)
        XCTAssertEqual(hits.first, .street(0))
        XCTAssertTrue(hits.contains(.street(2)))
    }

    func testWordInside() {
        let (s, a) = data()
        let hits = AddressSearch.search("linnégatan 3", streets: s, addresses: a)
        XCTAssertEqual(hits, [.address(4)])
    }

    func testAdLink() {
        XCTAssertEqual(AdLink.parse("https://www.hemnet.se/bostad/x-1")?.site, "Hemnet")
        XCTAssertEqual(AdLink.parse("www.booli.se/annons/123")?.site, "Booli")
        XCTAssertNil(AdLink.parse("http://www.hemnet.se/bostad/x"))
        XCTAssertNil(AdLink.parse("https://example.com"))
    }
}

final class ParseTests: XCTestCase {
    func testEnvRow() throws {
        let json = #"[3,5,10,116,3,140,1670,530,null,null,null,[198,500,265,770],"KYRKBYN 144:1",475,1,2,[3,"1998","1952"]]"#
        let r = Parse.envRow(try Parse.json(Data(json.utf8)))
        XCTAssertEqual(r.leq, 3)
        XCTAssertEqual(r.no2, 10)
        XCTAssertEqual(r.pm10x10, 116)
        XCTAssertEqual(r.skyfall, 140)
        XCTAssertNil(r.flyg)
        XCTAssertEqual(r.framtid.count, 2)
        XCTAssertEqual(r.framtid[1].m, 770)
        XCTAssertEqual(r.fastighet, "KYRKBYN 144:1")
        XCTAssertEqual(r.area, 475)
        if case let .covered(c, latest, earliest)? = r.geo {
            XCTAssertEqual(c, 3); XCTAssertEqual(latest, "1998"); XCTAssertEqual(earliest, "1952")
        } else { XCTFail("geo saknas") }
    }

    func testMissingIndexIsNil() throws {
        let r = Parse.envRow(try Parse.json(Data(#"[-1,-1,null,null,-1]"#.utf8)))
        XCTAssertNil(r.leq)
        XCTAssertNil(r.radon)
    }
}
