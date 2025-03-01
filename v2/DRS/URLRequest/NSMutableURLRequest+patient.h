//
//  NSMutableURLRequest+patient.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (patient)


+(id)PUTpatient:(NSString*)URLString
           name:(NSString*)name
            pid:(NSString*)pid
         issuer:(NSString*)issuer
      birthdate:(NSString*)birthdate
            sex:(NSString*)sex
    contentType:(NSString*)contentType
        timeout:(NSTimeInterval)timeout
;

@end
