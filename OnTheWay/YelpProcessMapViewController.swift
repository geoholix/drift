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

open class YelpProcessMapViewController: UIViewController {
    
    public let mapView = AGSMapView(frame: CGRect.zero)
    let overlay = AGSGraphicsOverlay()
    let overlayWhere = AGSGraphicsOverlay()
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Where"
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        
        mapView.map = AGSMap.redlandsMap()
        mapView.graphicsOverlays.add(overlay)
        mapView.graphicsOverlays.add(overlayWhere)
        
        overlay.isVisible = false
        overlayWhere.isVisible = true
        
        let bbi = UIBarButtonItem(title: "Sauce", style: .plain, target: self, action: #selector(sauceAction))
        navigationItem.rightBarButtonItem = bbi
    }
    
    func sauceAction(){
        overlay.isVisible = true
    }
    
    var resultContext : ResultContext?{
        didSet{
            showResultContextOnMapView()
        }
    }
    
    func showResultContextOnMapView(){
        overlay.graphics.removeAllObjects()
        
        guard let resultContext = self.resultContext,
              let polyline = resultContext.route.routeGeometry else{
            return
        }
        
        // make sure view is loaded so map is set, so initial viewpoint works
        let _ = view
        
        let sym = AGSSimpleLineSymbol(style: .solid, color: UIColor.red, width: 3)
        let graphic = AGSGraphic(geometry: polyline, symbol: sym, attributes: nil)
        
        // add route
        overlay.graphics.add(graphic)
        mapView.graphicsOverlays.add(overlay)
        
        // add current location graphic
        let sms = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.white.withAlphaComponent(0.2), size: 16)
        let blueSls = AGSSimpleLineSymbol(style: .solid, color: UIColor.blue, width: 1)
        sms.outline = blueSls
        let clGraphic = AGSGraphic(geometry: resultContext.currentLocation, symbol: sms, attributes: nil)
        overlay.graphics.add(clGraphic)
        
        // add query location graphics
        let greenSls = AGSSimpleLineSymbol(style: .solid, color: UIColor.blue, width: 1)
        for p in resultContext.queryLocations{
            let geom = AGSGeometryEngine.bufferGeometry(p, byDistance: resultContext.searchRadius)
            let g = AGSGraphic(geometry: geom, symbol: greenSls, attributes: nil)
            overlay.graphics.add(g)
        }
        
        // add all original unfiltered candidates
        showCandidatesOnMapView(candidates: Array(resultContext.unfilteredCandidatesSet), color: UIColor.yellow, outlineColor: UIColor.white)
        
        // add final results
        showFinalResultsOnMapView(candidates: resultContext.candidates)
        
        if let geom = resultContext.unionedResultPolygon{
            mapView.setViewpointGeometry(geom, padding: 40, completion: nil)
        }
    }
    
    func showCandidatesOnMapView(candidates: [LocationCandidate], color: UIColor, outlineColor: UIColor){
        
        let sms = AGSSimpleMarkerSymbol(style: .circle, color: color, size: 8)
        let sls = AGSSimpleLineSymbol(style: .solid, color: outlineColor, width: 1)
        sms.outline = sls
        
        for candidate in candidates{
            let g = AGSGraphic(geometry: candidate.mapLocation, symbol: sms, attributes: nil)
            overlay.graphics.add(g)
        }
    }
    
    func showFinalResultsOnMapView(candidates: [LocationCandidate]){
        
        for candidate in candidates{
            let g = AGSGraphic(geometry: candidate.mapLocation, symbol: driftStopMarker(), attributes: nil)
            overlayWhere.graphics.add(g)
        }
    }
    
}

