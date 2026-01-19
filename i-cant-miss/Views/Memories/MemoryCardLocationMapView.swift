//
//  MemoryCardLocationMapView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import MapKit

struct MemoryCardLocationMapView: View {
    let location: MemoryTriggerModel.TriggerLocation
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    private var mapRegion: MKCoordinateRegion {
        // Convert radius from meters to approximate degrees
        // 1 degree of latitude ≈ 111,000 meters
        // 1 degree of longitude ≈ 111,000 * cos(latitude) meters
        let radiusInDegrees = location.radius / 111000.0
        let padding = 1.5 // Show 1.5x the radius for better context
        let span = max(radiusInDegrees * padding, 0.01) // Minimum span to avoid too much zoom
        
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: span,
                longitudeDelta: span / cos(location.latitude * .pi / 180.0)
            )
        )
    }
    
    var body: some View {
        Map(position: .constant(.region(mapRegion)),
            interactionModes: []) {
            MapCircle(center: coordinate, radius: location.radius)
                .foregroundStyle(Color.accentColor.opacity(0.18))
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
        }
        .mapStyle(.standard)
        .mapControls { }
        .allowsHitTesting(false)
    }
}
