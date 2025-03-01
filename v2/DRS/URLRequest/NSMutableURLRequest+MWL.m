//
//  NSMutableURLRequest+MWL.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableURLRequest+MWL.h"
#import "NSDictionary+DICM.h"
#import "NSMutableDictionary+DICM.h"
#import "NSMutableData+DICM.h"
#import "NSUUID+DICM.h"

@implementation NSMutableURLRequest (MWL)

const UInt32        tag00020000mwl     = 0x02;
const UInt32        vrULmonovaluedmwl  = 0x044C55;

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
        
        [request setHTTPMethod:@"POST"];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
        
        //crear json for workitem http://dicom.nema.org/medical/Dicom/2015a/output/chtml/part03/sect_C.4.10.html
        //doesn´t indicate optional, nor mandatory metadata...
        
        //minimal format, one step with accessionNumber=procid=stepid=studyiuid
        NSMutableString *json=[NSMutableString string];
        [json appendFormat:@"{\"00080005\": {\"vr\":\"CS\",\"Value\":[\"%@\"]},",CS];
        [json appendString:@"\"00400100\": {\"vr\":\"SQ\",\"Value\":[{"];
        if ([aet length]) [json appendFormat:@"\"00400001\":{\"vr\":\"AE\",\"Value\":[\"%@\"]},",aet];
        [json appendFormat:@"\"00400002\":{\"vr\":\"DA\",\"Value\":[\"%@\"]},",DA];
        [json appendFormat:@"\"00400003\":{\"vr\":\"TM\",\"Value\":[\"%@\"]},",TM];
        [json appendFormat:@"\"00080060\":{\"vr\":\"CS\",\"Value\":[\"%@\"]},",modality];
        [json appendFormat:@"\"00400009\":{\"vr\":\"SH\",\"Value\":[\"%@\"]},",accessionNumber];//<STEPID> (=Accession Number)
        [json appendFormat:@"\"00400020\":{\"vr\":\"CS\",\"Value\":[\"%@\"]}}]},",status];
        [json appendFormat:@"\"00401001\":{\"vr\":\"SH\",\"Value\":[\"%@\"]},",accessionNumber];//<PROCID> (=Accession Number)
        if (referring)[json appendFormat:@"\"00080090\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"%@\"}]},",referring];
        [json appendFormat:@"\"00321060\":{\"vr\":\"LO\",\"Value\":[\"%@\"]},",studyDescription];
        [json appendFormat:@"\"0020000D\":{\"vr\":\"UI\",\"Value\":[\"%@\"]},",accessionNumber];//<STUDYUID>
        [json appendFormat:@"\"00401003\":{\"vr\":\"SH\",\"Value\":[\"%@\"]},",priority];
        [json appendFormat:@"\"00080050\":{\"vr\":\"SH\",\"Value\":[\"%@\"]},",accessionNumber];
        [json appendFormat:@"\"00100010\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"%@\"}]},",name];
        [json appendFormat:@"\"00100020\":{\"vr\":\"LO\",\"Value\":[\"%@\"]},",pid];
        [json appendFormat:@"\"00100021\":{\"vr\":\"LO\",\"Value\":[\"%@\"]},",issuer];
        [json appendFormat:@"\"00100030\":{\"vr\":\"DA\",\"Value\":[\"%@\"]},",birthdate];
        [json appendFormat:@"\"00100040\":{\"vr\":\"CS\",\"Value\":[\"%@\"]}}",sex];

        [request setHTTPBody:[json dataUsingEncoding:NSUTF8StringEncoding]];
        
        return request;
    }
    return nil;
}

#pragma mark use +enclosed with accessionNumber issuer improved
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
{
    //aet empty
    //enclosure HL7II
    //enclosureTitle
    //procScheme change to independient
    
    if (!URLString || ![URLString length]) return nil;
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
         DICMC070201StudyWithUID:studyUID
                              DA:DA
                              TM:TM
                              ID:@""
                              AN:accessionNumber
                         ANLocal:nil
                     ANUniversal:nil
                 ANUniversalType:nil
                     description:studyDescription
                  procedureCodes:procedureCodes
                       referring:referring
                         reading:reading]];

        
        //DICMC240100    Encapsulated Series
        [dicm addEntriesFromDictionary:[NSDictionary
         DICMC240100ForModality1:@"OT"
                      seriesUID1:seriesUID
                   seriesNumber2:@"-32"
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
        [stowData appendBytes:&tag00020000mwl    length:4];
        [stowData appendBytes:&vrULmonovaluedmwl length:4];
        [stowData appendBytes:&count00020000  length:4];
        [stowData appendData:metainfoData];
        
        [stowData appendData:[NSMutableData DICMDataWithDICMDictionary:dicm bulkdataBaseURI:nil]];        

        [stowData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundaryString] dataUsingEncoding:NSASCIIStringEncoding]];
        
//request
        id request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:timeout];
        // https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc;
        //NSURLRequestReturnCacheDataElseLoad
        //NSURLRequestReloadIgnoringCacheData
        [request setHTTPMethod:@"POST"];
        [request setValue:[NSString stringWithFormat:@"multipart/related;type=application/dicom;boundary=%@",boundaryString] forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:stowData];
        return request;
    }
    return nil;
}

@end
