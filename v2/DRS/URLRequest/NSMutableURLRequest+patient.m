//
//  NSMutableURLRequest+patient.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableURLRequest+patient.h"

@implementation NSMutableURLRequest (patient)

+(id)PUTpatient:(NSString*)URLString
           name:(NSString*)name
            pid:(NSString*)pid
         issuer:(NSString*)issuer
      birthdate:(NSString*)birthdate
            sex:(NSString*)sex
    contentType:(NSString*)contentType
        timeout:(NSTimeInterval)timeout
{
    if (!URLString || ![URLString length]) return nil;
    if (!pid || ![pid length]) return nil;
    if (!issuer || ![issuer length]) return nil;
    if ([contentType isEqualToString:@"application/json"])
    {
        id request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:timeout
                      ];

        // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
        //NSURLRequestReturnCacheDataElseLoad
        //NSURLRequestReloadIgnoringCacheData

        [request setHTTPMethod:@"PUT"];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];

        NSMutableString *json=[NSMutableString string];
        [json appendString:@"{\"00080005\": {\"vr\":\"CS\",\"Value\":[\"ISO_IR 192\"]},"];//utf8
        [json appendFormat:@"\"00100010\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"%@\"}]},",name];
        [json appendFormat:@"\"00100020\":{\"vr\":\"SH\",\"Value\":[\"%@\"]},",pid];
        [json appendFormat:@"\"00100021\":{\"vr\":\"LO\",\"Value\":[\"%@\"]},",issuer];
        [json appendFormat:@"\"00100030\":{\"vr\":\"DA\",\"Value\":[\"%@\"]},",birthdate];
        [json appendFormat:@"\"00100040\":{\"vr\":\"CS\",\"Value\":[\"%@\"]}}",sex];
        [request setHTTPBody:[json dataUsingEncoding:NSUTF8StringEncoding]];

        return request;
    }
    return nil;
}

@end
