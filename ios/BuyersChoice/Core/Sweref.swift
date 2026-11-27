import Foundation
import CoreLocation

/// Omräkning mellan SWEREF 99 12 00 (EPSG:3007), som all data är lagrad i, och WGS 84 för kartan.
/// Gauss–Krüger-formlerna enligt Lantmäteriet. Felet är under en millimeter inom kommunerna.
enum Sweref {
    private static let a = 6378137.0
    private static let f = 1 / 298.257222101
    private static let lon0 = 12.0 * .pi / 180
    private static let k0 = 1.0
    private static let fn = 0.0
    private static let fe = 150000.0

    private static let e2 = f * (2 - f)
    private static let n = f / (2 - f)
    private static let aRoof = a / (1 + n) * (1 + n * n / 4 + pow(n, 4) / 64)

    /// Nordlig (N) och östlig (E) koordinat till latitud och longitud.
    static func toWGS84(e: Double, n north: Double) -> CLLocationCoordinate2D {
        let d1 = n / 2 - 2 * n * n / 3 + 37 * pow(n, 3) / 96 - pow(n, 4) / 360
        let d2 = n * n / 48 + pow(n, 3) / 15 - 437 * pow(n, 4) / 1440
        let d3 = 17 * pow(n, 3) / 480 - 37 * pow(n, 4) / 840
        let d4 = 4397 * pow(n, 4) / 161280
        let aS = e2 + e2 * e2 + pow(e2, 3) + pow(e2, 4)
        let bS = -(7 * e2 * e2 + 17 * pow(e2, 3) + 30 * pow(e2, 4)) / 6
        let cS = (224 * pow(e2, 3) + 889 * pow(e2, 4)) / 120
        let dS = -(4279 * pow(e2, 4)) / 1260

        let xi = (north - fn) / (k0 * aRoof)
        let eta = (e - fe) / (k0 * aRoof)
        let xiP = xi - d1 * sin(2 * xi) * cosh(2 * eta) - d2 * sin(4 * xi) * cosh(4 * eta)
            - d3 * sin(6 * xi) * cosh(6 * eta) - d4 * sin(8 * xi) * cosh(8 * eta)
        let etaP = eta - d1 * cos(2 * xi) * sinh(2 * eta) - d2 * cos(4 * xi) * sinh(4 * eta)
            - d3 * cos(6 * xi) * sinh(6 * eta) - d4 * cos(8 * xi) * sinh(8 * eta)
        let phiS = asin(sin(xiP) / cosh(etaP))
        let dLambda = atan(sinh(etaP) / cos(xiP))
        let s = sin(phiS)
        let lat = phiS + s * cos(phiS) * (aS + bS * s * s + cS * pow(s, 4) + dS * pow(s, 6))
        return CLLocationCoordinate2D(latitude: lat * 180 / .pi, longitude: (lon0 + dLambda) * 180 / .pi)
    }

    /// Latitud och longitud till östlig (e) och nordlig (n) koordinat.
    static func fromWGS84(_ c: CLLocationCoordinate2D) -> (e: Double, n: Double) {
        let phi = c.latitude * .pi / 180
        let aa = e2
        let bb = (5 * e2 * e2 - pow(e2, 3)) / 6
        let cc = (104 * pow(e2, 3) - 45 * pow(e2, 4)) / 120
        let dd = (1237 * pow(e2, 4)) / 1260
        let b1 = n / 2 - 2 * n * n / 3 + 5 * pow(n, 3) / 16 + 41 * pow(n, 4) / 180
        let b2 = 13 * n * n / 48 - 3 * pow(n, 3) / 5 + 557 * pow(n, 4) / 1440
        let b3 = 61 * pow(n, 3) / 240 - 103 * pow(n, 4) / 140
        let b4 = 49561 * pow(n, 4) / 161280
        let s = sin(phi)
        let phiS = phi - s * cos(phi) * (aa + bb * s * s + cc * pow(s, 4) + dd * pow(s, 6))
        let dl = c.longitude * .pi / 180 - lon0
        let xiP = atan(tan(phiS) / cos(dl))
        let etaP = atanh(cos(phiS) * sin(dl))
        let north = k0 * aRoof * (xiP + b1 * sin(2 * xiP) * cosh(2 * etaP) + b2 * sin(4 * xiP) * cosh(4 * etaP)
            + b3 * sin(6 * xiP) * cosh(6 * etaP) + b4 * sin(8 * xiP) * cosh(8 * etaP)) + fn
        let east = k0 * aRoof * (etaP + b1 * cos(2 * xiP) * sinh(2 * etaP) + b2 * cos(4 * xiP) * sinh(4 * etaP)
            + b3 * cos(6 * xiP) * sinh(6 * etaP) + b4 * cos(8 * xiP) * sinh(8 * etaP)) + fe
        return (east, north)
    }
}
