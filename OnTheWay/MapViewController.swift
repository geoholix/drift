// Copyright 2016 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

open class MapViewController: UIViewController, AGSGeoViewTouchDelegate {
    
    @IBOutlet var subView:UIView!
    @IBOutlet var viewSwitcher:UISegmentedControl!
    @IBOutlet var driftButton:UIButton!
    
    public let mapView = AGSMapView(frame: CGRect.zero)
    
    private var directionsVC:DirectionsViewController!
    private var generatedRoute:AGSRoute?
    
    let routeGraphicsOverlay = AGSGraphicsOverlay()
    
    var routeResult : AGSRouteResult? {
        didSet{
            showRouteOnMapView()
        }
    }
    
    @IBAction func driftButtonAction(_ sender: AnyObject) {
        guard let polyline = generatedRoute?.routeGeometry else{
            return
        }
        mapView.setViewpointGeometry(polyline, padding: 40, completion: nil)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Directions"
        
        mapView.frame = subView.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        subView.addSubview(mapView)
        
        directionsVC = UIStoryboard(name: "Directions", bundle: nil).instantiateViewController(withIdentifier: "DirectionsViewController") as! DirectionsViewController
        directionsVC.view.frame = subView.bounds
        directionsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        subView.addSubview(directionsVC.view)
        
        subView.bringSubview(toFront: mapView)
        
        mapView.touchDelegate = self
        
        mapView.map = AGSMap.redlandsMap()
        mapView.graphicsOverlays.add(routeGraphicsOverlay)
        
        // set mapViewController on AppContext
        AppContext.shared.mapViewController = self
        
        let showYelpQueryBbi = UIBarButtonItem(title: "Drift!", style: .plain, target: self, action: #selector(showYelpAction))
        navigationItem.rightBarButtonItem = showYelpQueryBbi
        
        viewSwitcher.removeFromSuperview()
        navigationItem.titleView = viewSwitcher
        viewSwitcher.tintColor = UIColor.white
    }
    
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        
        let ll = mapPoint.latLong
        print("lat long: \(ll)")
    }
    
    func showRouteOnMapView(){
        
        // clear any previous route graphics
        routeGraphicsOverlay.graphics.removeAllObjects()
        
        self.generatedRoute = routeResult?.routes.first
        
        // make sure we have a route geom
        guard let polyline = generatedRoute?.routeGeometry else{
            return
        }
        
        guard let stops = routeResult?.routes.first?.stops else {
            return
        }
        
        // create symbology/graphic, add to overlay
        let sym = routeSymbol()
        let graphic = AGSGraphic(geometry: polyline, symbol: sym, attributes: nil)
        
        for stop in stops {
            var sym : AGSSymbol?
            if stop == stops.first {
                sym = originStopMarger()
            }
            else if stop == stops.last {
                sym = DestinationStopMarger()
            }
            else {
                sym = driftStopMarker()
            }
            let g = AGSGraphic(geometry: stop.geometry, symbol: sym, attributes: nil)
            g.zIndex = 1
            routeGraphicsOverlay.graphics.add(g)
        }

        routeGraphicsOverlay.graphics.add(graphic)
        
        // zoom to route
        //mapView.setViewpointGeometry(polyline, padding: 40, completion: nil)
        
        //
        // create a simulated location datasource
        
        // densify line to a certain MPH
        // TODO: Ryan
        let milesPerHour : Double = 65
        let milesPerSecond : Double = milesPerHour / (60.0 * 60.0)
        
        guard let linearUnit = polyline.spatialReference?.unit as? AGSLinearUnit else {
            return
        }
        
        let unitsPerSecond = AGSLinearUnit.miles().convert(milesPerSecond, to: linearUnit)

        guard let generalized = AGSGeometryEngine.generalizeGeometry(polyline, maxDeviation: unitsPerSecond, removeDegenerateParts: true) as? AGSPolyline else{
            return
        }
        
        guard let densified = AGSGeometryEngine.densifyGeometry(generalized, maxSegmentLength: unitsPerSecond) as? AGSPolyline else{
            return
        }
        
        let ds = AGSSimulatedLocationDataSource()
        ds.setLocationsWith(densified)
        
        mapView.locationDisplay.dataSource = ds
        mapView.locationDisplay.start(completion: nil)
        mapView.locationDisplay.autoPanMode = .recenter
    }
    
    func showYelpAction(){
        // TODO: Ryan - remove
        
        guard let route = routeResult?.routes.first else{
            return
        }
        
        if let polyline = routeResult?.routes.first?.routeGeometry {
            let dist = polyline.distanceToEndOfLine(nearestStartingPoint: mapView.locationDisplay.mapLocation!)
            print("Distance to end of route: \(dist)")
            print("Minutes to end of route: \(minutesToEndOfRoute(route: (routeResult?.routes.first!)!, location: mapView.locationDisplay.mapLocation!))")
            let p = pointOnRoute(route: (routeResult?.routes.first!)!, forTimeOffset: 15.0, from: mapView.locationDisplay.mapLocation!)
            let sym = AGSSimpleMarkerSymbol(style: .diamond, color: UIColor.orange, size: 20.0)
            let g = AGSGraphic(geometry: p, symbol: sym, attributes: nil)
            routeGraphicsOverlay.graphics.add(g)
        }
        
        guard let vc = UIStoryboard(name: "Ryan", bundle: nil).instantiateViewController(withIdentifier: "YelpQueryViewController") as? YelpQueryViewController else{
            return
        }
        
        vc.route = route
        vc.locationDisplay = mapView.locationDisplay
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func executeTestRoute(completion: @escaping (AGSRouteResult?, Error?)->Void){
        
        // Test Route
        //let point1 = AGSPoint(x: -117.1873071, y: 34.0503211, spatialReference: AGSSpatialReference.wgs84())
        
        // right about to get on freeway
        let point1 = AGSPoint(x: -117.23176575926132, y: 34.066904648027112, spatialReference: AGSSpatialReference.wgs84())
        
        //let point2 = AGSPoint(x: -117.1816, y: 34.05694, spatialReference: AGSSpatialReference.wgs84())
        
        // disneyland
        //let point2 = AGSPoint(x: -117.918976, y: 33.812511, spatialReference: AGSSpatialReference.wgs84())
        
        //let stop1 = AGSStop(point: point1)
        //stop1.name = "Origin"
        //let stop2 = AGSStop(point: point2)
        //stop2.name = "Destination"
        //let stops = [stop1, stop2]
        
        calculateRoute(point: point1, location: "Disneyland") { result, error in
            if let err = error {
                print("Route ERROR: \(err)")
                completion(nil, error)
            }
            else {
                print("\(result)")
                completion(result, nil)
            }
        }
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func indexChanged(_ sender: UISegmentedControl) {
        switch viewSwitcher.selectedSegmentIndex
        {
        case 0:
            subView.bringSubview(toFront: mapView)
        case 1:
            // doesn't seem very efficient to do this here - but only way I could get it to work
            self.directionsVC.directionManeuvers = generatedRoute?.directionManeuvers
            self.directionsVC.tableView.reloadData()
            subView.bringSubview(toFront: directionsVC.view)
        default:
            break; 
        }
    }
}

