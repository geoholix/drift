//
//  Extensions.swift
//  ArcGISToolkit
//
//  Created by Ryan Olson on 12/5/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import Foundation

import ArcGIS

extension UITableViewCell{
    
    func setPortalItem(_ portalItem: AGSPortalItem, for indexPath: IndexPath){
        
        // tag the cell so we know what index path it's being used for
        self.tag = indexPath.hashValue
        
        // set title
        self.textLabel?.text = portalItem.title
        
        //
        // Set the image of a UITableViewCell to the portal item's thumbnail
        // Set the thumbnail on cell.imageView?.image
        //   - The thumbnail property of the AGSPortalItem implements AGSLoadable, which means
        //     that you have to call loadWithCompletion on it to get it's value
        //   - use the cell's tag to make sure that once you get the thumbnail, that cell is
        //     still being used for the indexPath.row that you care about
        //     (cells can get recycled by the time the thumbnail comes in)
        //   - once you set the image on cell.imageView?.image, you will need to call cell.setNeedsLayout() for it to appear
        
        // set thumbnail on cell
        self.imageView?.image = portalItem.thumbnail?.image
        // if imageview is still nil then need to load the thumbnail
        if self.imageView?.image == nil {
            
            // set default image until thumb is loaded
            self.imageView?.image = UIImage(named: "placeholder")
            // have to call setNeedsLayout for image to draw
            self.setNeedsLayout()
            
            portalItem.thumbnail?.load() { [weak portalItem, weak self] (error) in
                
                guard let strongSelf = self, let portalItem = portalItem else{
                    return
                }
                
                // make sure this is the cell we still care about and that it
                // wasn't already recycled by the time we get the thumbnail
                if strongSelf.tag != indexPath.hashValue{
                    return
                }
                
                // now if no error then set the thumbnail image
                // reload the cell
                if error == nil {
                    strongSelf.imageView?.image = portalItem.thumbnail?.image
                    // have to call setNeedsLayout for image to draw
                    strongSelf.setNeedsLayout()
                }
            }
        }
    }
    
}


extension UIApplication {
    func topViewController(_ controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(presented)
        }
        return controller
    }
}

func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

extension AGSMap{
    class func redlandsMap() -> AGSMap{
        let m = AGSMap(basemapType: AGSBasemapType.navigationVector, latitude: 34.056934, longitude: -117.169088, levelOfDetail: 12)
        return m
    }
}

extension AGSViewpoint{
    class func redlandsViewpoint() -> AGSViewpoint{
        let v = AGSViewpoint(center: AGSPointMakeWGS84(34.056934, -117.169088), scale: 200_000)
        return v
    }
}

extension AGSPoint{
    class func redlandsPoint() -> AGSPoint{
        let redlands = AGSPoint(x: -117, y: 34, z: 10, spatialReference: AGSSpatialReference.wgs84())
        return redlands
    }
}

extension AGSPoint{
    struct LatLong{
        var lat : Double
        var long : Double
    }
    
    var latLong: LatLong {
        guard let p = AGSGeometryEngine.projectGeometry(self, to: AGSSpatialReference.wgs84()) as? AGSPoint else{
            return LatLong(lat: 0.0, long: 0.0)
        }
        return LatLong(lat: p.y, long: p.x)
    }
}

extension AGSPoint{
    
    func isOnSegment(point1: AGSPoint, point2: AGSPoint) -> Bool{
        let dxc : Double = self.x - point1.x;
        let dyc : Double = self.y - point1.y;
        
        let dxl : Double = point2.x - point1.x;
        let dyl : Double = point2.y - point1.y;
        
        let cross : Double = (dxc * dyl) - (dyc * dxl);
        
        //return cross == 0.0
        
        let tol : Double = 0.00001
        let onSegment : Bool = (cross < tol) && (cross > (-tol))
        
        return onSegment
    }
    
}

extension AGSPolyline{
    
    func findStartingSegment(pointOnSegment: AGSPoint) -> AGSPoint?{
        
        var lastPoint : AGSPoint?
        
        for part in self.parts.array(){
            for p in part.points.array(){
                
                if p.isEqual(to: pointOnSegment){
                    return p
                }
                
                if let lastPoint = lastPoint, pointOnSegment.isOnSegment(point1: lastPoint, point2: p){
                    return p
                }
                
                lastPoint = p
            }
        }
        
        return nil
    }
    
    func pointOnLine(nearestStartingPoint: AGSPoint, distance: Double) -> AGSPoint?{
        
        if self.parts.count == 0{
            return nil
        }
        
        if self.parts.totalPointCount == 0{
            return nil
        }
        
        if self.parts.totalPointCount == 1{
            return self.parts.array().first?.points.array().first
        }
        
        // get starting point
        guard let proxResult = AGSGeometryEngine.nearestCoordinate(in: self, to: nearestStartingPoint) else{
            return nil
        }
        
        // distance <= 0, then returning starting point
        
        let startingPoint = proxResult.point
        if distance <= 0{
            return startingPoint
        }
        
        var pointA : AGSPoint? = nil
        var pointB : AGSPoint? = nil
        
        var currDist : Double = 0
        var lastDist : Double  = 0
        
        var lastPoint : AGSPoint? = nil
        
        var startChecking = false
        let lastPointInStartingSegment = findStartingSegment(pointOnSegment: startingPoint) ?? startingPoint
        
        //print("starting point: \(startingPoint)")
        //print("last segment point: \(lastPointInStartingSegment)")
        
        for part in self.parts.array(){
            for p in part.points.array(){
                
                //print(" - loop point : \(p)")
                
                if !startChecking && p.isEqual(to: lastPointInStartingSegment){
                    //print("  -   checking now...")
                    startChecking = true
                    lastPoint = startingPoint
                }
                
                if !startChecking{
                    continue
                }
                
                lastDist = currDist
                
                if let lastPoint = lastPoint{
                    currDist = currDist + AGSGeometryEngine.distanceBetweenGeometry1(lastPoint, geometry2: p)
                }
                
                if currDist == distance{
                    return p
                }
                else if currDist > distance{
                    pointA = lastPoint
                    pointB = p
                    break
                }
                lastPoint = p
            }
        }
        
        guard let point1 = pointA, let point2 = pointB else{
            // if here then the distance passed in is too long
            // return last point
            return self.parts.array().last?.points.array().last
        }
        
        
        // now interpolate between point A and B
        // basically offset pointA by distance interpDistance at angle
        // between pointA and pointB
        let interpDistance = distance - lastDist;
        
        // find angle
        let angle : Double = atan2(point2.y - point1.y, point2.x - point1.x);
        
        // now offset by the angle at the distance (h) to get dx, dy
        // sin(angle) * h = o, = dy
        // cos(angle) * h = a, = dx
        let dy : Double = sin(angle) * interpDistance;
        let dx : Double = cos(angle) * interpDistance;
        
        return AGSPoint(x: point1.x + dx, y: point1.y + dy, spatialReference: self.spatialReference)
    }
    
    func distanceToEndOfLine(nearestStartingPoint: AGSPoint) -> Double{
        
        if self.parts.count == 0{
            return 0.0
        }
        
        if self.parts.totalPointCount == 0{
            return 0.0
        }
        
        if self.parts.totalPointCount == 1{
            return 0.0 //Not sure if this is right, might need distance to the one point
//            return self.parts.array().first?.points.array().first
        }
        
        // get starting point
        guard let proxResult = AGSGeometryEngine.nearestCoordinate(in: self, to: nearestStartingPoint) else{
            return 0.0
        }
        
        let startingPoint = proxResult.point
        
        var currDist : Double = 0
        
        var lastPoint : AGSPoint? = nil
        
        var startChecking = false
        let lastPointInStartingSegment = findStartingSegment(pointOnSegment: startingPoint) ?? startingPoint
        
        //print("starting point: \(startingPoint)")
        //print("last segment point: \(lastPointInStartingSegment)")
        
        for part in self.parts.array(){
            for p in part.points.array(){
                
                //print(" - loop point : \(p)")
                
                if !startChecking && p.isEqual(to: lastPointInStartingSegment){
                    //print("  -   checking now...")
                    startChecking = true
                    lastPoint = startingPoint
                }
                
                if !startChecking{
                    continue
                }
                
                if let lastPoint = lastPoint{
                    currDist = currDist + AGSGeometryEngine.distanceBetweenGeometry1(lastPoint, geometry2: p)
                }
                
                lastPoint = p
            }
        }
        
        return currDist

// Where is the distance from the current point to the last point on the segment accounted for?  Do I need
// the code below to handle that?
        
//        guard let point1 = pointA, let point2 = pointB else{
//            // if here then the distance passed in is too long
//            // return last point
//            return self.parts.array().last?.points.array().last
//        }
//        
//        
//        // now interpolate between point A and B
//        // basically offset pointA by distance interpDistance at angle
//        // between pointA and pointB
//        let interpDistance = distance - lastDist;
//        
//        // find angle
//        let angle : Double = atan2(point2.y - point1.y, point2.x - point1.x);
//        
//        // now offset by the angle at the distance (h) to get dx, dy
//        // sin(angle) * h = o, = dy
//        // cos(angle) * h = a, = dx
//        let dy : Double = sin(angle) * interpDistance;
//        let dx : Double = cos(angle) * interpDistance;
//        
//        return AGSPoint(x: point1.x + dx, y: point1.y + dy, spatialReference: self.spatialReference)
    }
    
}












