//
//  NSMutableURLRequest+html5dicom.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableURLRequest+html5dicom.h"

@implementation NSMutableURLRequest (html5dicom)


+(id)POSThtml5dicomuserRequest:(NSString*)URLString
                   institution:(NSString*)institution
                      username:(NSString*)username
                      password:(NSString*)password
                     firstname:(NSString*)firstname
                      lastname:(NSString*)lastname
                      isactive:(BOOL)isactive
                       timeout:(NSTimeInterval)timeout
{
    if (!URLString || ![URLString length]) return nil;
    
    id request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData
                                     timeoutInterval:timeout];
    // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
    //NSURLRequestReturnCacheDataElseLoad
    //NSURLRequestReloadIgnoringCacheData
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSMutableString *json=[NSMutableString stringWithString:@"{"];
    [json appendFormat:@"\"institution\":\"%@\",",institution];
    [json appendFormat:@"\"username\":\"%@\",",username];
    if (password)[json appendFormat:@"\"password\":\"%@\",",password];
    [json appendFormat:@"\"first_name\":\"%@\",",firstname];
    [json appendFormat:@"\"last_name\":\"%@\",",lastname];
    
    if (isactive) [json appendString:@"\"is_active\":true}"];
    else [json appendString:@"\"is_active\":false}"];

    [request setHTTPBody:[json dataUsingEncoding:NSUTF8StringEncoding]];

    return request;
}


@end
