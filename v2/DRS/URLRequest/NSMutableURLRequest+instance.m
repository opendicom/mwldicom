//
//  NSMutableURLRequest+instance.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableURLRequest+instance.h"

@implementation NSMutableURLRequest (instance)


+(id)GETqidoinstancemetadataxml:(NSString*)URLString
                       studyUID:(NSString*)studyUID
                      seriesUID:(NSString*)seriesUID
                        SOPIUID:(NSString*)SOPIUID
                        timeout:(NSTimeInterval)timeout
{
    if (!URLString || ![URLString length]) return nil;
    if (!studyUID  || ![studyUID length]) return nil;
    if (!seriesUID || ![seriesUID length]) return nil;
    if (!SOPIUID   || ![SOPIUID length]) return nil;
    NSString *qidoinstancemetadata=[NSString stringWithFormat:@"%@/%@/series/%@/instances/%@/metadata",URLString,studyUID,seriesUID,SOPIUID];
    id request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:qidoinstancemetadata]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData
                                     timeoutInterval:timeout];
    // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
    //NSURLRequestReturnCacheDataElseLoad
    //NSURLRequestReloadIgnoringCacheData
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/dicom+xml" forHTTPHeaderField:@"Content-Type"];
    return request;
}

+(id)GETqidostudy:(NSString*)URLString
                        timeout:(NSTimeInterval)timeout
{
    if (!URLString || ![URLString length]) return nil;
    id request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData
                                     timeoutInterval:timeout];
    // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
    //NSURLRequestReturnCacheDataElseLoad
    //NSURLRequestReloadIgnoringCacheData
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    return request;
}

@end
