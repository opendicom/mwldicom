//
//  NSURLSessionDataTask+PCS.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLSessionDataTask (PCS)

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;

+(NSArray*)existsInPacs:(NSDictionary*)pacs
                    pid:(NSString*)pid
                 issuer:(NSString*)issuer
       returnAttributes:(BOOL)returnAttributes
;

+(NSDictionary*)existsInPacs:(NSDictionary*)pacs
             accessionNumber:(NSString*)an
                issuerLocal:(NSString*)issuerLocal
            issuerUniversal:(NSString*)issuerUniversal
                 issuerType:(NSString*)issuerType
            returnAttributes:(BOOL)returnAttributes;


+(NSArray*)existsInPacs:(NSDictionary*)pacs
               studyUID:(NSString*)studyUID
              seriesUID:(NSString*)seriesUID
                 sopUID:(NSString*)sopUID
       returnAttributes:(BOOL)returnAttributes;

@end
