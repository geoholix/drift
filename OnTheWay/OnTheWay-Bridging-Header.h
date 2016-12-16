//
//  OnTheWay-Bridging-Header.h
//  OnTheWay
//
//  Created by Philip Gruenler on 12/15/16.
//  Copyright © 2016 Esri. All rights reserved.
//

#ifndef OnTheWay_Bridging_Header_h
#define OnTheWay_Bridging_Header_h

#import <ArcGIS/ArcGIS.h>

@class AGSRouteTrackerListener;
@class AGSRouteTask;
@class AGSRouteParameters;
@class AGSRouteResult;
@class AGSLocation;
@class AGSFeatureTable;
@class AGSTextGuidanceNotification;
@class AGSGeometry;

typedef NS_ENUM(NSInteger, AGSDestinationStatus) {
    AGSDestinationStatusNotReached = 0,
    AGSDestinationStatusNearDestination = 1,
    AGSDestinationStatusAtDestination = 2
};

typedef NS_ENUM(NSInteger, AGSTrackingStatus) {
    AGSTrackingStatusAtStart = 0,
    AGSTrackingStatusOnRoute = 1,
    AGSTrackingStatusOffRoute = 2
};

typedef NS_ENUM(NSInteger, AGSGuidanceNotificationType) {
    AGSGuidanceNotificationTypeApproachingManeuverLong = 0,
    AGSGuidanceNotificationTypeApproachingManeuverMiddle = 1,
    AGSGuidanceNotificationTypeApproachingManeuverShort = 2,
    AGSGuidanceNotificationTypeAtManeuver = 3,
    AGSGuidanceNotificationTypeApproachingDestination = 4
};

@interface AGSTrackingResult : AGSObject
    NS_ASSUME_NONNULL_BEGIN
    
#pragma mark -
#pragma mark initializers
    
-(instancetype)init __attribute__((unavailable("init is not available.")));
    
#pragma mark -
#pragma mark properties
    
    @property (nonatomic, assign, readonly) NSInteger currentManeuver;
    @property (nonatomic, assign, readonly) NSInteger currentRoutePart;
    @property (nonatomic, assign, readonly) AGSDestinationStatus destinationStatus;
    @property (nonatomic, assign, readonly) double distanceToDestination;
    @property (nonatomic, assign, readonly) double distanceToNextManeuver;
    @property (nonatomic, assign, readonly, getter=isRouteCalculating) BOOL routeCalculating;
    @property (nonatomic, assign, readonly) double minutesToDestination;
    @property (nonatomic, assign, readonly) double minutesToNextManeuver;
    @property (nullable, nonatomic, strong, readonly) AGSLocation *myLocation;
    @property (nullable, nonatomic, strong, readonly) AGSGeometry *passedGeometry;
    @property (nullable, nonatomic, strong, readonly) AGSGeometry *remainingGeometry;
    @property (nullable, nonatomic, strong, readonly) AGSRouteResult *routeResult;
    @property (nullable, nonatomic, strong, readonly) AGSTextGuidanceNotification *textGuidanceNotification;
    @property (nonatomic, assign, readonly) AGSTrackingStatus trackingStatus;
    
    NS_ASSUME_NONNULL_END
    @end

@interface AGSRouteTracker : AGSObject
    NS_ASSUME_NONNULL_BEGIN
    
#pragma mark -
#pragma mark initializers
    
-(instancetype)init;
+(instancetype)routeTracker;
    
#pragma mark -
#pragma mark properties
    
    @property (nonatomic, strong, readonly) AGSTextGuidanceNotification *textGuidanceNotification;
    @property (nonatomic, assign, readonly, getter=isLoggingEnabled) BOOL loggingEnabled;
    @property (nonatomic, assign, readonly, getter=isReroutingEnabled) BOOL reroutingEnabled;
    @property (nonatomic, strong, readonly) AGSRouteTrackerListener *listener;
    
#pragma mark -
#pragma mark methods
    
-(void)cancelRerouting;
-(void)disableLogging;
-(void)disableRerouting;
-(void)enableLoggingWithFolder:(NSString*)folder;
-(void)enableReroutingWithRouteTask:(AGSRouteTask*)routeTask routeParameters:(AGSRouteParameters*)routeParameters curbApproach:(AGSCurbApproach)curbApproach;
-(AGSTrackingResult*)setRouteResult:(AGSRouteResult*)routeResult routeIndex:(NSInteger)routeIndex directionUnitSystem:(AGSUnitSystem)directionUnitSystem;
-(AGSTrackingResult*)switchToNextDestination;
-(AGSTrackingResult*)trackLocation:(AGSLocation*)location;
    
    NS_ASSUME_NONNULL_END
    @end


#endif /* OnTheWay_Bridging_Header_h */
