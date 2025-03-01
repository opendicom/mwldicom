//
//  NSMutableURLRequest+html5dicom.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (html5dicom)

+(id)POSThtml5dicomuserRequest:(NSString*)URLString
                   institution:(NSString*)institution
                      username:(NSString*)username
                      password:(NSString*)password
                     firstname:(NSString*)firstname
                      lastname:(NSString*)lastname
                      isactive:(BOOL)isactive
                       timeout:(NSTimeInterval)timeout
;

@end
