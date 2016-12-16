//
//  AppContext.swift
//  OnTheWay
//
//  Created by Ryan Olson on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import UIKit
import ArcGIS
import YelpAPI

private let _sharedInstance = AppContext()

class AppContext {
    
    class var shared: AppContext {
        return _sharedInstance
    }
    
    var mapViewController : MapViewController?
    
    lazy var routeTask : AGSRouteTask = {
        let rt = AGSRouteTask(url: URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
        
        // TODO: add your own ArcGIS.com credentials here
        rt.credential = AGSCredential(user: "", password: "")
        return rt
    }()
    
    lazy var locatorTask : AGSLocatorTask = {
        return AGSLocatorTask(url: URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)
    }()
    
    var yelpClient : YLPClient?
    
}


