//
//  AppDelegate.swift
//  OnTheWay
//
//  Created by Ryan Olson on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import UIKit
import YelpAPI
import ArcGIS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func setupTheme(){
        let nb = UINavigationBar.appearance()
        nb.tintColor = UIColor.white
        nb.barTintColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
        nb.isTranslucent = false
        nb.titleTextAttributes = [NSForegroundColorAttributeName : UIColor(red:0.27, green:0.32, blue:0.38, alpha:1.00), NSFontAttributeName : UIFont(name: "Avenir Book", size: 24)!]

        
        let sc = UISegmentedControl.appearance()
        sc.tintColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
        
        let bt = UIButton.appearance()
        bt.tintColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
        
        let slider = UISlider.appearance()
        slider.tintColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
        
        let sw = UISwitch.appearance()
        sw.tintColor = UIColor.lightGray.withAlphaComponent(0.7)
        sw.onTintColor = UIColor(red:0.97, green:0.51, blue:0.20, alpha:1.00)
    }
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        do {
            // TODO: add your own ArcGIS license here
            let result = try AGSArcGISRuntimeEnvironment.setLicenseKey("")
            print("License Result : \(result.licenseStatus)")
        }
        catch let error as NSError {
            print("error: \(error)")
        }
        
        setupTheme()
        
        // Override point for customization after application launch.
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        let startVC = UIStoryboard(name: "Michael", bundle: nil).instantiateViewController(withIdentifier: "StartRouteViewController")
        let nc = UINavigationController(rootViewController: startVC)
        
        self.window?.rootViewController = nc
        self.window?.makeKeyAndVisible()
        
        // authorize yelp client
        
        // TODO: add your own Yelp V3 credentials here
        YLPClient.authorize(withAppId: "", secret: ""){ client, error in
            if let error = error{
                print("authorization failed: \(error)")
            }
            else{
                print("yelp authorization succeeded...")
                AppContext.shared.yelpClient = client
            }
        }
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

