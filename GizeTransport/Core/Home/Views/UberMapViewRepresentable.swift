import SwiftUI
import MapKit
import Firebase

private enum MapConstants {
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    static let routeLineWidth: CGFloat = 5
    static let carImageName = "car"
}

struct UberMapViewRepresentable: UIViewRepresentable {
    @Binding var mapState: MapViewState
    @EnvironmentObject var homeViewModel: HomeViewModel
    @ObservedObject var locationManager = LocationManager.shared

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .includingAll
            mapView.preferredConfiguration = configuration
        } else {
            mapView.pointOfInterestFilter = .includingAll
        }
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.sync(mapView: mapView, state: mapState)
    }
}

final class MapCoordinator: NSObject, MKMapViewDelegate {
    private let parent: UberMapViewRepresentable
    private weak var mapView: MKMapView?
    private var routeOverlays = [MKPolyline]()
    private var didCenterOnUser = false
    private var isUserChangingRegion = false
    private var lastRenderedTripKey: String?
    private var lastRouteKey: String?
    private var lastFittedRouteKey: String?
    private var routeRequestID = UUID()

    init(parent: UberMapViewRepresentable) {
        self.parent = parent
        super.init()
    }

    func sync(mapView: MKMapView, state: MapViewState) {
        self.mapView = mapView
        centerOnUserIfNeeded(mapView)

        guard let trip = parent.homeViewModel.trip else {
            clearMapElements()
            return
        }

        switch state {
        case .tripAccepted:
            let pickup = trip.pickupLocationCoordiantes
            let dropoff = trip.dropoffLocationCoordinates
            renderTripIfNeeded(trip: trip, state: state, pickup: pickup, dropoff: dropoff)
            configurePolylineIfNeeded(from: parent.locationManager.userLocation?.coordinate, to: pickup, trip: trip, state: state)
        case .tripArrived:
            let pickup = trip.pickupLocationCoordiantes
            let dropoff = trip.dropoffLocationCoordinates
            renderTripIfNeeded(trip: trip, state: state, pickup: pickup, dropoff: dropoff)
            configurePolylineIfNeeded(from: parent.locationManager.userLocation?.coordinate, to: pickup, trip: trip, state: state)
        case .tripStarted:
            let pickup = trip.pickupLocationCoordiantes
            let dropoff = trip.dropoffLocationCoordinates
            renderTripIfNeeded(trip: trip, state: state, pickup: pickup, dropoff: dropoff)
            configurePolylineIfNeeded(from: parent.locationManager.userLocation?.coordinate, to: dropoff, trip: trip, state: state)
        case .tripCompleted, .noTrip, .tripRejected, .noInput:
            clearMapElements()
        default:
            break
        }
    }

    private func centerOnUserIfNeeded(_ mapView: MKMapView) {
        guard !didCenterOnUser, let coordinate = parent.locationManager.userLocation?.coordinate else { return }
        guard coordinate.isValidForMap else { return }
        didCenterOnUser = true
        mapView.setRegion(MKCoordinateRegion(center: coordinate, span: MapConstants.defaultSpan), animated: false)
    }

    private func renderTripIfNeeded(trip: Trip, state: MapViewState, pickup: CLLocationCoordinate2D, dropoff: CLLocationCoordinate2D) {
        let tripKey = mapContentKey(trip: trip, state: state, pickup: pickup, dropoff: dropoff)
        guard tripKey != lastRenderedTripKey else { return }
        lastRenderedTripKey = tripKey
        showTripPins(pickup: pickup, dropoff: dropoff)
    }

    private func showTripPins(pickup: CLLocationCoordinate2D, dropoff: CLLocationCoordinate2D) {
        guard let mapView = mapView else { return }
        guard pickup.isValidForMap, dropoff.isValidForMap else { return }
        let existingTripPins = mapView.annotations.filter { $0 is TripMapAnnotation }
        mapView.removeAnnotations(existingTripPins)
        mapView.addAnnotation(TripMapAnnotation(title: "Pickup", coordinate: pickup, kind: .pickup))
        mapView.addAnnotation(TripMapAnnotation(title: "Drop-off", coordinate: dropoff, kind: .dropoff))
        fitMap(to: [pickup, dropoff])
    }

    private func configurePolylineIfNeeded(from origin: CLLocationCoordinate2D?, to coordinate: CLLocationCoordinate2D, trip: Trip, state: MapViewState) {
        guard let origin = origin, origin.isValidForMap, coordinate.isValidForMap else { return }
        let routeKey = "\(trip.id)-\(state)-\(origin.routeKey)-\(coordinate.routeKey)"
        guard routeKey != lastRouteKey else { return }
        lastRouteKey = routeKey

        let requestID = UUID()
        routeRequestID = requestID

        AppleMapsRouting.route(from: origin, to: coordinate) { [weak self] route in
            guard let self = self, self.routeRequestID == requestID, let mapView = self.mapView else { return }
            mapView.removeOverlays(self.routeOverlays)
            let polyline = route?.polyline ?? MKPolyline(coordinates: [origin, coordinate], count: 2)
            self.routeOverlays = [polyline]
            mapView.addOverlay(polyline)
            self.fitRouteIfNeeded(routeKey: routeKey, coordinates: polyline.coordinates)
        }
    }

    func clearMapElements() {
        guard let mapView = mapView else { return }
        let tripPins = mapView.annotations.filter { $0 is TripMapAnnotation }
        mapView.removeAnnotations(tripPins)
        mapView.removeOverlays(routeOverlays)
        routeOverlays.removeAll()
        lastRenderedTripKey = nil
        lastRouteKey = nil
        lastFittedRouteKey = nil
    }

    private func fitRouteIfNeeded(routeKey: String, coordinates: [CLLocationCoordinate2D]) {
        guard lastFittedRouteKey != routeKey else { return }
        lastFittedRouteKey = routeKey
        fitMap(to: coordinates)
    }

    private func fitMap(to coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView, !coordinates.isEmpty else { return }
        guard !isUserChangingRegion else { return }
        let validCoordinates = coordinates.filter(\.isValidForMap)
        guard !validCoordinates.isEmpty else { return }
        var rect = MKMapRect.null
        validCoordinates.forEach { coordinate in
            let point = MKMapPoint(coordinate)
            guard point.x.isFinite, point.y.isFinite else { return }
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        guard !rect.isNull, !rect.isEmpty, rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.width.isFinite, rect.size.height.isFinite else { return }
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 90, left: 60, bottom: 220, right: 60), animated: true)
    }

    private func mapContentKey(trip: Trip, state: MapViewState, pickup: CLLocationCoordinate2D, dropoff: CLLocationCoordinate2D) -> String {
        "\(trip.id)-\(state)-\(pickup.routeKey)-\(dropoff.routeKey)"
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        isUserChangingRegion = mapView.isRegionChangeFromUserInteraction
        if isUserChangingRegion {
            mapView.userTrackingMode = .none
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard isUserChangingRegion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isUserChangingRegion = false
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let tripPin = annotation as? TripMapAnnotation else { return nil }
        let marker = mapView.dequeueReusableAnnotationView(withIdentifier: "trip") as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: tripPin, reuseIdentifier: "trip")
        marker.annotation = tripPin
        marker.markerTintColor = tripPin.kind == .pickup ? .darkGreen : .systemRed
        marker.glyphImage = UIImage(systemName: tripPin.kind == .pickup ? "car.fill" : "person.fill")
        marker.canShowCallout = true
        return marker
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .darkGreen
            renderer.lineWidth = MapConstants.routeLineWidth
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

private final class TripMapAnnotation: NSObject, MKAnnotation {
    enum Kind { case pickup, dropoff }
    let title: String?
    dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind

    init(title: String, coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.title = title
        self.coordinate = coordinate
        self.kind = kind
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

private extension CLLocationCoordinate2D {
    var isValidForMap: Bool {
        CLLocationCoordinate2DIsValid(self)
        && latitude.isFinite
        && longitude.isFinite
        && (-85.0...85.0).contains(latitude)
        && (-180.0...180.0).contains(longitude)
    }

    var routeKey: String {
        "\(latitude.rounded(toPlaces: 5)),\(longitude.rounded(toPlaces: 5))"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private extension MKMapView {
    var isRegionChangeFromUserInteraction: Bool {
        guard let view = subviews.first else { return false }
        return view.gestureRecognizers?.contains { recognizer in
            recognizer.state == .began || recognizer.state == .changed
        } ?? false
    }
}
