//
//  YelpViewController.swift
//  OnTheWay
//
//  Created by Ryan Olson on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import UIKit
import YelpAPI
import ArcGIS

class LocationCandidate : Hashable{
    
    let yelpBusiness : YLPBusiness
    let routeLine: AGSPolyline
    
    let mapLocation : AGSPoint
    let distanceFromRoute: Double
    let distanceFromStartingLocation: Double
    
    let score : Double
    
    init?(yelpBusiness: YLPBusiness, routeLine: AGSPolyline, startingLocation: AGSPoint){
        self.yelpBusiness = yelpBusiness
        self.routeLine = routeLine
        
        guard let coord = yelpBusiness.location.coordinate else{
            return nil
        }
        
        guard let sr = routeLine.spatialReference else {
            return nil
        }
        
        let wgs84Point = AGSPointMakeWGS84(coord.latitude, coord.longitude)
        guard let point = AGSGeometryEngine.projectGeometry(wgs84Point, to: sr) as? AGSPoint else{
            return nil
        }
        
        mapLocation = point
        
        guard let proxResult = AGSGeometryEngine.nearestCoordinate(in: routeLine, to: mapLocation) else{
            return nil
        }
        
        distanceFromRoute = proxResult.distance
        
        distanceFromStartingLocation = AGSGeometryEngine.distanceBetweenGeometry1(mapLocation, geometry2: startingLocation)
        
        //
        // calculate score
        // lower score is better
        
        let miles = AGSLinearUnit.miles()
        let ratingFactor = (5 - yelpBusiness.rating)
        let distanceFromRouteFactor = miles.convert(fromMeters: distanceFromRoute) * 5
        let distanceFromStartingLocationFactor = miles.convert(fromMeters: distanceFromStartingLocation) * 1
        
        score = ratingFactor + distanceFromRouteFactor + distanceFromStartingLocationFactor
        
    }
    
    var hashValue: Int {
        return yelpBusiness.identifier.hash
    }
    
}

func ==(lhs: LocationCandidate, rhs: LocationCandidate) -> Bool {
    return lhs.yelpBusiness.identifier == rhs.yelpBusiness.identifier
}

class ResultContext{
    
    var route : AGSRoute
    var currentLocation : AGSPoint
    var locationDisplay : AGSLocationDisplay
    
    var searchRadius : Double = 0
    var minRating : Double = 0
    var maxDollarSigns : Int = 0
    var unionedResultPolygon: AGSPolygon?
    
    var candidates : [LocationCandidate] = [LocationCandidate]()
    var queryLocations = [AGSPoint]()
    
    var unfilteredCandidatesSet = Set<LocationCandidate>()
    
    init(route: AGSRoute, currentLocation: AGSPoint, locationDisplay: AGSLocationDisplay){
        self.route = route
        self.currentLocation = currentLocation
        self.locationDisplay = locationDisplay
    }
    
    func filterCandidates(){
        
        guard let union = self.unionedResultPolygon else{
            return
        }
        
        var candidates = Array(unfilteredCandidatesSet)
        
        // first remove candidates that don't have rating high enough
        candidates = candidates.filter{
            $0.yelpBusiness.rating >= self.minRating
        }
        
        // filter out if distance greater, because yelp returns results outside distance
        //candidates = candidates{
        //    $0.distanceFromRoute <= resultContext.searchRadius
        //}
        
        // filter out if not in union of buffered query locations because
        // yelp returns results outside of the area we ask for
        candidates = candidates.filter{
            AGSGeometryEngine.geometry(union, contains: $0.mapLocation)
        }
        
        // sort by distance from route
        candidates = candidates.sorted{
            //$0.distanceFromRoute <= $1.distanceFromRoute
            $0.score <= $1.score
        }
        
        self.candidates = candidates
    }
}

class YelpQueryViewController : UIViewController{
    
    
    @IBOutlet weak var lookingForTextField: UITextField!
    @IBOutlet weak var dealsSwitch: UISwitch!
    @IBOutlet weak var hotAndNewSwitch: UISwitch!
    @IBOutlet weak var minRatingSegmentedControl: UISegmentedControl!
    @IBOutlet weak var maxCostSegmentedControl: UISegmentedControl!
    @IBOutlet weak var distanceSlider: UISlider!
    @IBOutlet weak var milesLabel: UILabel!
    @IBOutlet weak var findLocationsButton: UIButton!
    @IBOutlet weak var whenStopSlider: UISlider!
    @IBOutlet weak var whenStopLabel: UILabel!
    
    var minsLeftOnRoute : Double?
    
    func calcMinutesToEndOfRoute(){
        guard let route = self.route, let currentLocation = self.locationDisplay?.mapLocation else{
            return
        }
        guard minsLeftOnRoute == nil else{
            return
        }
        
        minsLeftOnRoute = minutesToEndOfRoute(route: route, location: currentLocation)
        whenStopSlider?.maximumValue = Float(minsLeftOnRoute!)
    }
    
    var route : AGSRoute?{
        didSet{
            calcMinutesToEndOfRoute()
        }
    }
    private(set) var currentLocation : AGSPoint?
    
    var locationDisplay : AGSLocationDisplay?{
        didSet{
            calcMinutesToEndOfRoute()
        }
    }
    
    override func viewDidLoad() {
        
        self.title = "Looking For?"
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        
        let findBbi = UIBarButtonItem(title: "Find", style: .plain, target: self, action: #selector(findLocationsButtonAction(_:)))
        
        navigationItem.rightBarButtonItem = findBbi
        distanceSliderAction(distanceSlider)
        
        if let minsLeftOnRoute = minsLeftOnRoute{
            whenStopSlider?.maximumValue = Float(minsLeftOnRoute)
        }
    }
    
    @IBAction func distanceSliderAction(_ sender: Any) {
        milesLabel.text = "\(distanceSlider.value.rounded()) Miles"
    }
    
    @IBAction func whenStopSliderAction(_ sender: Any) {
        let value = whenStopSlider.value
        if value < 5 {
            whenStopLabel.text = "ASAP"
        }
        else{
            whenStopLabel.text = "\(Int(value))" + " Minutes"
        }
    }
    
    @IBAction func findLocationsButtonAction(_ sender: Any) {
        
        // set current location from locationDisplay
        self.currentLocation = locationDisplay?.mapLocation
        
        guard let route = self.route,
            let polyline = route.routeGeometry,
            let locationDisplay = self.locationDisplay,
            let currentLocation = self.currentLocation else{
            return
        }
        
        let resultContext = ResultContext(route: route, currentLocation: currentLocation, locationDisplay: locationDisplay)
        resultContext.minRating = Double(minRatingSegmentedControl.selectedSegmentIndex + 1)
        resultContext.maxDollarSigns = maxCostSegmentedControl.selectedSegmentIndex + 1
        
        
        //
        // get all the query locations for the next so many miles
        let distanceLimitMiles = 21.0
        let distanceLimit = AGSLinearUnit.miles().convert(toMeters: distanceLimitMiles)
        
        let searchRadius = AGSLinearUnit.miles().convert(toMeters: Double(distanceSlider.value))
        resultContext.searchRadius = searchRadius
        // starting distance search radius plus a mile
        var distance : Double = searchRadius + AGSLinearUnit.miles().convert(toMeters: 1)
        
        var startingPoint = currentLocation
        if whenStopSlider.value > 5{
            if let timeOffsetPoint = pointOnRoute(route: route, forTimeOffset: Double(whenStopSlider.value), from: startingPoint){
                startingPoint = timeOffsetPoint
            }
        }
        
        while distance < distanceLimit{
            
            guard let point = polyline.pointOnLine(nearestStartingPoint: startingPoint, distance: distance) else{
                break
            }
            resultContext.queryLocations.append(point)
            distance += searchRadius
        }
        
        
        //
        // get buffered result polygon
        
        var unionResult : AGSPolygon? = nil
        for p in resultContext.queryLocations{
            
            guard let buffered = AGSGeometryEngine.bufferGeometry(p, byDistance: searchRadius) else{
                continue
            }
            
            if unionResult == nil{
                unionResult = buffered
            }
            else{
                unionResult = AGSGeometryEngine.union(ofGeometry1: buffered, geometry2: unionResult!) as? AGSPolygon
            }
        }
        resultContext.unionedResultPolygon = unionResult
        
        
        //
        // now find all locations for each query location
        
        let queryYelpGroup = DispatchGroup()
        
        for location in resultContext.queryLocations{
            
            queryYelpGroup.enter()
            
            findLocations(location, radiusInMeters: searchRadius){ searchResult in
                
                guard let searchResult = searchResult else {
                    queryYelpGroup.leave()
                    return
                }
                
                let businesses = searchResult.businesses.filter{ $0.location.coordinate != nil }
                let candidates = businesses.flatMap{ LocationCandidate(yelpBusiness: $0, routeLine: polyline, startingLocation: currentLocation) }
                
                // add candidates to set
                resultContext.unfilteredCandidatesSet.formUnion(candidates)
                
                queryYelpGroup.leave()
            }
        }
        
        //
        // Once all querying is done we need to filter
        
        queryYelpGroup.notify(queue: DispatchQueue.main){ [weak self] in
            resultContext.filterCandidates()
            
            let vc = UIStoryboard(name: "Ryan", bundle: nil).instantiateViewController(withIdentifier: "LocationCandidatesViewController") as! LocationCandidatesViewController
            vc.resultContext = resultContext
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    
    func findLocations(_ point: AGSPoint, radiusInMeters: Double, completion: @escaping (YLPSearch?)->Void){
    
        guard let text = lookingForTextField.text, !text.isEmpty else{
            return
        }
        
        // get radius in meters
        
        let latLong = point.latLong
        let coord = YLPCoordinate(latitude: latLong.lat, longitude: latLong.long)
        let query = YLPQuery(coordinate: coord)
        query.radiusFilter = radiusInMeters.rounded()
        query.dealsFilter = dealsSwitch.isOn
        query.sort = .bestMatched
        query.term = lookingForTextField.text
        query.limit = 50
        query.openNow = true
        query.hotAndNew = hotAndNewSwitch.isOn
        query.maxDollarSigns = maxCostSegmentedControl.selectedSegmentIndex + 1
        query.categoryFilter = ["food", "restaurants"]
        
        AppContext.shared.yelpClient?.search(with: query){ search, error in
            
            //print(" ")
            //print(" ")
            
            if let error = error{
                print("could not query... \(error)")
                completion(nil)
            }
            else if let search = search{
                
                //print("-- Found \(search.businesses.count) locations")
                
                /*for biz in search.businesses where biz.location.coordinate != nil{
                    print("\(biz.name), (\(biz.location.coordinate!.latitude), \(biz.location.coordinate!.longitude)) - id: \(biz.identifier)")
                }*/
                completion(search)
            }
        }
    }
    
    
}





































