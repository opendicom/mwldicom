//
//  NSMutableURLRequest+MWL.h
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (MWL)

+(id)POSTmwlitem:(NSString*)URLString
              CS:(NSString*)CS
             aet:(NSString*)aet
              DA:(NSString*)DA
              TM:(NSString*)TM
              TZ:(NSString*)TZ
        modality:(NSString*)modality
 accessionNumber:(NSString*)accessionNumber
       referring:(NSString*)referring
          status:(NSString*)status
studyDescription:(NSString*)studyDescription
        priority:(NSString*)priority
            name:(NSString*)name
             pid:(NSString*)pid
          issuer:(NSString*)issuer
       birthdate:(NSString*)birthdate
             sex:(NSString*)sex
     contentType:(NSString*)contentType
         timeout:(NSTimeInterval)timeout
;

+(id)POSTenclosed:(NSString*)URLString
               CS:(NSString*)CS
               DA:(NSString*)DA
               TM:(NSString*)TM
               TZ:(NSString*)TZ
         modality:(NSString*)modality
  accessionNumber:(NSString*)accessionNumber
  accessionIssuer:(NSString*)accessionIssuer
          ANLocal:(NSString*)ANLocal
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
     seriesNumber:(NSString*)seriesNumber
seriesDescription:(NSString*)seriesDescription
   enclosureHL7II:(NSString*)enclosureHL7II
   enclosureTitle:(NSString*)enclosureTitle
enclosureTransferSyntax:(NSString*)enclosureTransferSyntax
    enclosureData:(NSData*)enclosureData
      contentType:(NSString*)contentType
          timeout:(NSTimeInterval)timeout
;

@end
