//
//  NSMutableURLRequest+enclosed.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableURLRequest+enclosed.h"
#import "NSDictionary+DICM.h"
#import "NSMutableDictionary+DICM.h"
#import "NSMutableData+DICM.h"
#import "NSUUID+DICM.h"

@implementation NSMutableURLRequest (enclosed)

const UInt32        tag00020000     = 0x02;
const UInt32        vrULmonovalued  = 0x044C55;

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
{
    //enclosure HL7II
    //enclosureTitle
    //procScheme change to independient
    
    if (!pid || ![pid length]) return nil;
    if (!issuer || ![issuer length]) return nil;
    if ([contentType isEqualToString:@"application/dicom"])
    {
        //minimal format, one step with accessionNumber=procid=stepid=studyiuid
        NSMutableDictionary *metainfo=[NSMutableDictionary dictionary];
        [metainfo addEntriesFromDictionary:[NSDictionary
                                            DICM0002ForMediaStorageSOPClassUID:@"1.2.840.10008.5.1.4.1.1.104.2"
                                            mediaStorageSOPInstanceUID:instanceUID
                                            implementationClassUID:@""
                                            implementationVersionName:@""
                                            sourceApplicationEntityTitle:@""
                                            privateInformationCreatorUID:@""
                                            privateInformation:nil]];
        NSMutableData *metainfoData=[NSMutableData DICMDataGroup2WithDICMDictionary:metainfo];

        NSMutableDictionary *dicm=[NSMutableDictionary dictionary];

        //DICMC120100    SOP Common
         [dicm addEntriesFromDictionary:[NSDictionary
          DICMC120100ForSOPClassUID1:@"1.2.840.10008.5.1.4.1.1.104.2"
                     SOPInstanceUID1:instanceUID
                            charset1:CS
                                 DA1:DA
                                 TM1:TM
                                  TZ:TZ]];
        
        //DICMC070101    Patient
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC070101PatientWithName:name
                         pid:pid
                      issuer:issuer
                   birthdate:birthdate
                         sex:sex]];

        //DICMC070201    General Study
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC070201StudyWithUID:AN
                              DA:DA
                              TM:TM
                              ID:studyID
                              AN:AN
                         ANLocal:ANLocal
                     ANUniversal:ANUniversal
                 ANUniversalType:ANUniversalType
                     description:studyDescription
                  procedureCodes:procedureCodes
                       referring:referring
                         reading:reading]];

        //DICMC240100    Encapsulated Series
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC240100ForModality1:modality
                      seriesUID1:seriesUID
                   seriesNumber2:seriesNumber
                       seriesDA3:DA
                       seriesTM3:TM
              seriesDescription3:seriesDescription]];
        
        //DICMC070501    General Equipment
        [dicm addEntriesFromDictionary:[NSDictionary DICMC070501ForInstitution:ANLocal]];
        
        //DICMC080601    SC Equipment
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC080601ForConversionType1:@"WSD"]];

        //DICMC240200    Encapsulated Document
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC240200EncapsulatedCDAWithDA:DA
                                       TM:TM
                                    title:enclosureTitle
                                    HL7II:enclosureHL7II
                                     data:enclosureData]];


        //MutableDictionary -> NSMutableData
        
        NSString *boundaryString=[[NSUUID UUID]UUIDString];

        NSMutableData *stowData=[NSMutableData data];
        
        [stowData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\nContent-Type:application/dicom\r\n\r\n",boundaryString] dataUsingEncoding:NSASCIIStringEncoding]];
        
        [stowData increaseLengthBy:128];
        [stowData appendDICMSignature];
        
        UInt32 count00020000 = (UInt32)[metainfoData length];
        [stowData appendBytes:&tag00020000    length:4];
        [stowData appendBytes:&vrULmonovalued length:4];
        [stowData appendBytes:&count00020000  length:4];
        [stowData appendData:metainfoData];
        
        [stowData appendData:[NSMutableData DICMDataWithDICMDictionary:dicm bulkdataBaseURI:nil]];        

        [stowData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundaryString] dataUsingEncoding:NSASCIIStringEncoding]];
        
//request
        
        NSURLRequestCachePolicy cachepolicy;
        if ([pacs[@"cachepolicy"]length]) cachepolicy=[pacs[@"cachepolicy"] integerValue];
        else cachepolicy=1;//NSURLRequestReloadIgnoringCacheData
        
        NSTimeInterval timeoutinterval;
        if ([pacs[@"timeoutinterval"]length]) timeoutinterval=[pacs[@"timeoutinterval"] doubleValue];
        else timeoutinterval=10;

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[pacs[@"dcm4cheelocaluri"] stringByAppendingPathComponent:@"rs/studies"]]
                                             cachePolicy:cachepolicy
                                         timeoutInterval:timeoutinterval];
        // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
        //NSURLRequestReturnCacheDataElseLoad
        //NSURLRequestReloadIgnoringCacheData
        [request setHTTPMethod:@"POST"];
        [request setValue:[NSString stringWithFormat:@"multipart/related;type=application/dicom;boundary=%@",boundaryString] forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:stowData];
        
        if (![[NSFileManager defaultManager]fileExistsAtPath:@"/Users/Shared/stowbody"]) [[NSFileManager defaultManager]createDirectoryAtPath:@"/Users/Shared/stowbody" withIntermediateDirectories:NO attributes:nil error:nil];
        [request.HTTPBody writeToFile:[NSString stringWithFormat:@"/Users/Shared/stowbody/%@",boundaryString] atomically:NO];
        
        return request;
    }
    return nil;
}

@end
