//
//  RRMapViewController.m
//  RRiOSApp
//
//  Created by Harlan Kellaway on 10/14/14.
//  Copyright (c) 2014 ___REFUGERESTROOMS___. All rights reserved.
//

#import "RRMapViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "MBProgressHUD.h"
#import "Restroom.h"
#import "RestroomManager.h"
#import "RRMapLocation.h"
#import "Reachability.h"

#define RGB(r, g, b) [UIColor colorWithRed:(float)r / 255.0 green:(float)g / 255.0 blue:(float)b / 255.0 alpha:1.0]
#define RGBA(r, g, b, a) [UIColor colorWithRed:(float)r / 255.0 green:(float)g / 255.0 blue:(float)b / 255.0 alpha:a]

static NSString *mapTitle = @"Refuge Restrooms";
static NSString *syncText = @"Syncing";
static NSString *noLocationText = @"Could not find your location";
static NSString *noInternetText = @"Internet connection unavailable";
static NSString *completionGraphic = @"37x-Checkmark@2x";

const float METERS_PER_MILE = 1609.344;

@interface RRMapViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation RRMapViewController
{
    Reachability *internetReachability;
    CLLocationManager *locationManager;
    MBProgressHUD *hud;
    BOOL internetIsAccessible;
    BOOL initialZoomComplete;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.topItem.title = mapTitle;
    
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDAnimationFade;
    hud.color = RGB(65.0, 60.0, 107.0);
    hud.labelText = syncText;
    
    internetIsAccessible = YES;
    initialZoomComplete = NO;
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    
    // set RestroomManager delegate
    RestroomManager *restroomManager = (RestroomManager *)[RestroomManager sharedInstance];
    restroomManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    
    // prompt for location allowing
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
    {
        [locationManager requestWhenInUseAuthorization];
    }
    else
    {
#pragma message "Should provide else case here that can run on iOS 7"
        // TODO: Test on iOS 7 device
    }
    
    [locationManager startUpdatingLocation];
    
    // check for Internet reachability
    internetReachability = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Internet is reachable
    internetReachability.reachableBlock = ^(Reachability*reach)
    {
        dispatch_async
        (
            // update UI on main thread
            dispatch_get_main_queue(), ^
            {
                [[RestroomManager sharedInstance] fetchNewRestrooms];
            }
         );
    };

    // Internet is not reachable
    internetReachability.unreachableBlock = ^(Reachability*reach)
    {
        // Update the UI on the main thread
        dispatch_async
        (
            dispatch_get_main_queue(), ^
            {
                internetIsAccessible = NO;
                
                hud.mode = MBProgressHUDModeText;
                hud.labelText = noInternetText;
            }
         );
    };
    
    [internetReachability startNotifier];
}

- (void)plotRestrooms:(NSArray *)restrooms
{
    // remove existing annotations
    for (id<MKAnnotation> annotation in self.mapView.annotations)
    {
        [self.mapView removeAnnotation:annotation];
    }
    
    // add all annotations
    for (Restroom *restroom in restrooms)
    {
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = [restroom.latitude doubleValue];
        coordinate.longitude = [restroom.longitude doubleValue];
    
        RRMapLocation *mapLocation = [[RRMapLocation alloc] initWithName:restroom.name address:restroom.street coordinate:coordinate];
    
        [self.mapView addAnnotation:[mapLocation annotation]];
    }
}

#pragma mark - CLLocationManagerDelegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [locationManager stopUpdatingLocation];
    
    if(!initialZoomComplete)
    {
        // zoom to initial location
        CLLocation *location = [locationManager location];
        CLLocationCoordinate2D coordinate = [location coordinate];
    
        float longitude = coordinate.longitude;
        float latitude = coordinate.latitude;
    
        NSLog(@"dLongitude : %f",longitude);
        NSLog(@"dLatitude : %f", latitude);
    
        CLLocationCoordinate2D zoomLocation;
        zoomLocation.latitude = latitude;
        zoomLocation.longitude= longitude;
        MKCoordinateRegion viewRegion = [self getRegionWithZoomLocation:zoomLocation];
    
        [self.mapView setRegion:viewRegion animated:YES];
    
        [locationManager startUpdatingLocation];
        
        initialZoomComplete = YES;
    }
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [locationManager stopUpdatingLocation];
    
    if(internetIsAccessible) { hud.labelText = noLocationText; }
    [hud hide:YES afterDelay:5];
    
    hud.labelText = syncText;
    [hud hide:NO];
}

#pragma mark - RestroomManagerDelegate methods

- (void)didReceiveRestrooms:(NSArray *)restrooms
{
    // plot Restrooms on map
    dispatch_async
    (
        // update UI on main thread
        dispatch_get_main_queue(), ^(void)
        {
            [self plotRestrooms:restrooms];
            
            hud.mode = MBProgressHUDModeCustomView;
            hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:completionGraphic]];
            hud.labelText = @"Complete";
            [hud hide:YES afterDelay:2];
        }
     );
}

- (void)fetchingRestroomsFailedWithError:(NSError *)error
{;
    // display error
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Sync error";
    hud.detailsLabelText = [NSString stringWithFormat:@"Code: %i", [error code]];
}

#pragma mark - Helper methods

- (MKCoordinateRegion)getRegionWithZoomLocation:(CLLocationCoordinate2D)zoomLocation
{
    return MKCoordinateRegionMakeWithDistance(zoomLocation, (0.5 * METERS_PER_MILE), (0.5 * METERS_PER_MILE));
}

@end
