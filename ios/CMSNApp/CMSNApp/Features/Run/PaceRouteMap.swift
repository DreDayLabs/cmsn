import MapKit
import SwiftUI

/// Route stroked from fast (off-white) to slow (dark gray). The map itself
/// is the only photographic color. The line stays in the app palette.
struct PaceRouteMap: View {
    let points: [TrackPoint]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(Color(hex: segment.hex), lineWidth: 4)
            }
        }
        .mapStyle(.standard(emphasis: .muted))
        .onAppear { fit() }
        .accessibilityLabel("Route colored by pace. Lighter is faster, darker is slower.")
    }

    private var segments: [(coordinates: [CLLocationCoordinate2D], hex: UInt32)] {
        let smoothed = RunMath.smooth(points)
        guard smoothed.count >= 2 else { return [] }
        let steps: [(points: [TrackPoint], pace: Double)] = stride(from: 1, to: smoothed.count, by: 1).map { index in
            let previous = smoothed[index - 1]
            let current = smoothed[index]
            let distance = max(1, RunMath.meters(from: previous, to: current))
            let time = max(0.2, current.timestamp.timeIntervalSince(previous.timestamp))
            return ([previous, current], time / distance)
        }
        let paces = steps.map(\.pace).filter(\.isFinite)
        let fastest = paces.min() ?? 0
        let slowest = paces.max() ?? 0
        return steps.map { step in
            (
                step.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                RunMath.toneHex(paceSecondsPerMeter: step.pace, fastest: fastest, slowest: slowest)
            )
        }
    }

    private func fit() {
        guard points.count >= 2 else { return }
        let lats = points.map(\.latitude)
        let lons = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.004, (maxLat - minLat) * 1.45),
            longitudeDelta: max(0.004, (maxLon - minLon) * 1.45)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
