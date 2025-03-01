//
//  NSMutableURLRequest+instance.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (instance)

+(id)GETqidoinstancemetadataxml:(NSString*)URLString
                       studyUID:(NSString*)studyUID
                      seriesUID:(NSString*)seriesUID
                        SOPIUID:(NSString*)SOPIUID
                        timeout:(NSTimeInterval)timeout
;

+(id)GETqidostudy:(NSString*)URLString
                        timeout:(NSTimeInterval)timeout
;

@end
