//
//  RouteHelpers.swift
//  OnTheWay
//
//  Created by Philip Gruenler on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import Foundation
import ArcGIS

func timeDifferenceBetween(oldRoute : AGSRoute, and newRoute : AGSRoute) -> TimeInterval {
    return newRoute.travelTime - oldRoute.travelTime
}

func routeSymbol() -> AGSCompositeSymbol {
    let cs = AGSCompositeSymbol()
    
    let sls1 = AGSSimpleLineSymbol()
    sls1.color = UIColor.blue
    sls1.style = .solid
    sls1.width = 6
    cs.symbols.append(sls1)
    
    let sls2 = AGSSimpleLineSymbol()
    sls2.color = UIColor(red: 0/255.0, green:170/255.0, blue:255/255.0, alpha:1.0)
    sls2.style = .solid
    sls2.width = 4
    cs.symbols.append(sls2)
    
    return cs
}

private func stopMarker(named imageName: String) -> AGSSymbol {
    let image = UIImage(named: imageName)
    if let image = image {
        let marker1 = AGSPictureMarkerSymbol(image: image)
        marker1.height = 25
        marker1.width = 25
        marker1.offsetY = 12
        let marker2 = AGSSimpleMarkerSymbol(style: .circle, color: UIColor(red: 0/255.0, green:170/255.0, blue:255/255.0, alpha:1.0), size: 10.0)
        marker2.outline = AGSSimpleLineSymbol(style: .solid, color: UIColor.blue, width: 1.0)
        let marker = AGSCompositeSymbol(symbols: [marker2, marker1])
        return marker
    }
    else {
        return AGSSimpleMarkerSymbol(style: .diamond, color: UIColor.orange, size: 20.0)
    }
}

func driftStopMarker() -> AGSSymbol {
    return stopMarker(named: "OrangePin")
}

func originStopMarger() -> AGSSymbol {
    return stopMarker(named: "GreenMarker")
}

func DestinationStopMarger() -> AGSSymbol {
    return stopMarker(named: "RedMarker2")
}

func minutesToEndOfRoute(route: AGSRoute, location: AGSPoint) -> Double {
    guard let polyline = route.routeGeometry else {
        return 0.0
    }
    let distMeters = polyline.distanceToEndOfLine(nearestStartingPoint: location)
    let distMiles = distMeters / 1609.34
    return (distMiles / 65.0) * 60
}

func pointOnRoute(route: AGSRoute, forTimeOffset minutes: Double, from point: AGSPoint) -> AGSPoint? {
    guard let polyline = route.routeGeometry else {
        return nil
    }
    let distMiles = (minutes / 60.0) * 65.0
    let distMeters = distMiles * 1609.34
    return polyline.pointOnLine(nearestStartingPoint: point, distance: distMeters)!
}

func calculateRoute(point : AGSPoint, location : String, completion : ((_ result : AGSRouteResult?, _ error : Error?) -> Void)?) {

    let appContext = AppContext.shared
    
    //initialize geocode parameters
    let geocodeParameters = AGSGeocodeParameters()
    geocodeParameters.resultAttributeNames.append(contentsOf: ["*"])
    geocodeParameters.minScore = 75

    //perform geocode with input text
    appContext.locatorTask.geocode(withSearchText: location, parameters: geocodeParameters, completion: { (results:[AGSGeocodeResult]?, error:Error?) -> Void in
        if let error = error {
            if let completion = completion {
                completion(nil, error)
            }
        }
        else if let results = results, results.count > 0, let locationPoint = results[0].displayLocation {
            calculateRoute(point1: point, point2: locationPoint, completion: completion)
        }
        else {
            //provide feedback in case of failure
            if let completion = completion {
                completion(nil, nil)// TODO make some sort of error
            }
        }
        
    })
    
}

func calculateRoute(point1 : AGSPoint, point2 : AGSPoint, completion: ((_ result : AGSRouteResult?, _ error : Error?) -> Void)?) {
    let stop1 = AGSStop(point: point1)
    stop1.name = "Origin"
    let stop2 = AGSStop(point: point2)
    stop2.name = "Destination"
    let stops = [stop1, stop2]
    calculateRoute(stops: stops, completion: completion)
}

func calculateRoute(beginPoint: AGSPoint, onTheWayPoint: AGSPoint, endPoint: AGSPoint, completion: ((_ result : AGSRouteResult?, _ error : Error?) -> Void)?) {
    let beginStop = AGSStop(point: beginPoint)
    beginStop.name = "Origin"
    let onTheWayStop = AGSStop(point: onTheWayPoint)
    onTheWayStop.name = "Drift! Stop"
    let endStop = AGSStop(point: endPoint)
    endStop.name = "Destination"
    let stops = [beginStop, onTheWayStop, endStop]
    calculateRoute(stops: stops, completion: completion)
}

func caculateRouteAddingPoint(onTheWayPoint: AGSPoint, to existingRoute: AGSRoute, completion: ((_ result : AGSRouteResult?, _ error : Error?) -> Void)?) {
    let onTheWayStop = AGSStop(point: onTheWayPoint)
    onTheWayStop.name = "Drift! Stop"
    if existingRoute.stops.count > 1 {
        let beginStop = existingRoute.stops[0]
        let endStop = existingRoute.stops[1]
        let stops = [beginStop, onTheWayStop, endStop]
        calculateRoute(stops: stops, completion: completion)
    }
    else {
        if let completion = completion {
            completion(nil, nil) //TODO make an error
        }
    }
}

func calculateRoute(stops : [AGSStop], completion: ((_ result : AGSRouteResult?, _ error : Error?) -> Void)?) {
    let appContext = AppContext.shared
    appContext.routeTask.defaultRouteParameters(completion: { (parameters: AGSRouteParameters?, error: Error?) -> Void in
        if let error = error {
            print(error)
            if let completion = completion {
                completion(nil, error)
            }
        }
        else if let params = parameters {
            //set parameters to return directions
            params.returnDirections = true
            params.returnStops = true
            params.outputSpatialReference = AGSSpatialReference.webMercator()
            
            //set the stops
            params.setStops(stops)
            
            appContext.routeTask.solveRoute(with: params) { (routeResult: AGSRouteResult?, error: Error?) -> Void in
                if let error = error {
                    print(error)
                    if let completion = completion {
                        completion(nil, error)
                    }
                }
                else {
                    if let completion = completion {
                        completion(routeResult, error)
                    }
                }
            }
        }
        else {
            if let completion = completion {
                completion(nil, nil) // should probably make an error here
            }
        }
    })
    
}

//func minutesToDestination(location: AGSLocation, routeResult: AGSRouteResult) -> Double {
//    let rt = AGSRouteTracker()
//    var result = rt.setRouteResult(routeResult, routeIndex: 0, directionUnitSystem: .imperial)
//    result = rt.trackLocation(location)
//    return result.minutesToDestination
//}

