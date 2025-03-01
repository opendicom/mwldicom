//
//  NSMutableURLRequest+enclosed.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (enclosed)

+(id)POSTenclosedToPacs:(NSDictionary*)pacs
                     CS:(NSString*)CS
                     DA:(NSString*)DA
                     TM:(NSString*)TM
                     TZ:(NSString*)TZ
                     AN:(NSString*)AN
                ANLocal:(NSString*)ANLocal
            ANUniversal:(NSString*)ANUniversal
        ANUniversalType:(NSString*)ANUniversalType
               modality:(NSString*)modality
       studyDescription:(NSString*)studyDescription
         procedureCodes:(NSArray*)procedureCodes
              referring:(NSString*)referring
                reading:(NSString*)reading
                   name:(NSString*)name
                    pid:(NSString*)pid
                 issuer:(NSString*)issuer
              birthdate:(NSString*)birthdate
                    sex:(NSString*)sex
            instanceUID:(NSString*)instanceUID
              seriesUID:(NSString*)seriesUID
               studyUID:(NSString*)studyUID
                studyID:(NSString*)studyID
           seriesNumber:(NSString*)seriesNumber
      seriesDescription:(NSString*)seriesDescription
         enclosureHL7II:(NSString*)enclosureHL7II
         enclosureTitle:(NSString*)enclosureTitle
enclosureTransferSyntax:(NSString*)enclosureTransferSyntax
          enclosureData:(NSData*)enclosureData
            contentType:(NSString*)contentType
;

@end
