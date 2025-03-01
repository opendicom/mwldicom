//
//  DRS+encapsulated.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180118.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+encapsulated.h"

@implementation DRS (encapsulated)

-(void)addEncapsulatedHandler
{
    NSRegularExpression *encapsulatedRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/pacs\\/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*\\/(ot|doc|cda|sr|OT|DOC|CDA|SR)$" options:NSRegularExpressionCaseInsensitive error:NULL];
    [self addHandler:@"GET" regex:encapsulatedRegex processBlock:
     ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             //LOG_DEBUG(@"client: %@",request.remoteAddressString);
             
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
             
             NSDictionary *entityDict=devices[pComponents[2]];
             if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} not found]",urlComponents.path];
             
             //modality
             NSString *modality;
             if (
                 [pComponents[3] isEqualToString:@"doc"]) modality=@"DOC";
             else if ([pComponents[3] isEqualToString:@"cda"]) modality=@"DOC";
             else if ([pComponents[3] isEqualToString:@"CDA"]) modality=@"DOC";
             else if ([pComponents[3] isEqualToString:@"ot"]) modality=@"OT";
             else if ([pComponents[3] isEqualToString:@"sr"]) modality=@"SR";
             
             
             //requires AccessionNumber or StudyInstanceUID
             NSString *AccessionNumber=nil;
             NSString *StudyInstanceUID=nil;
             NSString *SeriesInstanceUID=nil;
             NSString *SOPInstanceUID=nil;
             
             for (NSURLQueryItem *qi in urlComponents.queryItems)
             {
                 NSString *key=qidotag[@"qi.name"];
                 if (!key) key=@"qi.name";
                 
                 if ([key isEqualToString:@"preferredstudyidentificator"])
                 {
                     AccessionNumber=[NSString stringWithString:qi.value];
                     if ([entityDict[@"preferredstudyidentificator"]isEqualToString:@"preferredstudyidentificator"]) break;
                 }
                 else if ([key isEqualToString:@"StudyInstanceUID"])
                 {
                     StudyInstanceUID=[NSString stringWithString:qi.value];
                     if ([entityDict[@"preferredstudyidentificator"]isEqualToString:@"StudyInstanceUID"]) break;
                 }
             }
             
             //getting StudyInstanceUID, SeriesInstanceUID, SOPInstanceUID of encapsulated
             
             //sql or qido
             if ([entityDict[@"sqlobjectmodel"] length])
             {
                 //create wado request
                 //select relative to sql mapping
                 NSMutableString *select=[NSMutableString stringWithString:@" SELECT "];
                 for (NSString* key in wadouris[@"select"])
                 {
                     [select appendFormat:@"%@,",(sqlobjectmodel[@"attribute"])[key]];
                 }
                 [select deleteCharactersInRange:NSMakeRange([select length]-1,1)];
                 
                 if (AccessionNumber)
                 {
                     sqlScriptString=[NSString stringWithFormat:@"%@%@%@ WHERE %@='%@'\" %@",
                                      entityDict[@"sqlprolog"],
                                      select,
                                      (sqlobjectmodel[@"from"])[@"instancesofstudy"],
                                      (sqlobjectmodel[@"attribute"])[@"AccessionNumber"],
                                      AccessionNumber,
                                      wadouris[@"format"]
                                      ];
                 }
                 else if (StudyInstanceUID)
                 {
                     sqlScriptString=[NSString stringWithFormat:@"%@%@%@ WHERE %@='%@'\" %@",
                                      entityDict[@"sqlprolog"],
                                      select,
                                      (sqlobjectmodel[@"from"])[@"instancesofstudy"],
                                      (sqlobjectmodel[@"attribute"])[@"StudyInstanceUID"],
                                      StudyInstanceUID,
                                      wadouris[@"format"]
                                      ];
                 }
                 else if (SeriesInstanceUID)
                 {
                     sqlScriptString=[NSString stringWithFormat:@"%@%@%@ WHERE %@='%@'\" %@",
                                      entityDict[@"sqlprolog"],
                                      select,
                                      (sqlobjectmodel[@"from"])[@"instancesofstudy"],
                                      (sqlobjectmodel[@"attribute"])[@"SeriesInstanceUID"],
                                      SeriesInstanceUID,
                                      wadouris[@"format"]
                                      ];
                 }
                 else return [RSErrorResponse responseWithClientError:404 message:
                              @"shouldn´t be here..."];
                 
                 
                 //NSData *instanceData=[NSData dataWithContentsOfURL:[NSURL URLWithString:wadoRsString]];
                 
             }
             else if ([entityDict[@"qidolocaluri"] length])
             {
                 NSString *qidoString=nil;
                 if (StudyInstanceUID) [NSString stringWithFormat:@"%@/instances?StudyInstanceUID=%@&Modality=%@",
                                        entityDict[@"qidolocaluri"],
                                        StudyInstanceUID,
                                        modality];
                 else if (AccessionNumber) [NSString stringWithFormat:@"%@/instances?AccessionNumber=%@&Modality=%@",
                                            entityDict[@"qidolocaluri"],
                                            AccessionNumber,
                                            modality];
                 NSMutableData *mutableData=[NSMutableData dataWithContentsOfURL:
                                             [NSURL URLWithString:qidoString]];
                 
                 
                 //applicable, latest doc
                 //6.7.1.2.3.2 JSON Results
                 //If there are no matching results,the JSON message is empty.
                 if (!mutableData || ![mutableData length]) [RSErrorResponse responseWithClientError:404 message:@"no displayable match"];
                 
                 if ([entityDict[@"sqlstringencoding"]intValue]==5) //latin1
                 {
                     NSString *latin1String=[[NSString alloc]initWithData:mutableData encoding:NSISOLatin1StringEncoding];
                     [mutableData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
                 }
                 NSArray *instanceArray=[NSJSONSerialization JSONObjectWithData:mutableData options:0 error:nil];
                 NSUInteger instanceArrayCount=[instanceArray count];
                 if (instanceArrayCount==0) [RSErrorResponse responseWithClientError:404 message:@"no match"];
                 
                 //Find latest matching
                 NSDictionary *instance;
                 NSInteger i=0;
                 NSInteger index=0;
                 NSInteger date=0;
                 NSInteger time=0;
                 if (instanceArrayCount==1) instance=instanceArray[0];
                 else
                 {
                     for (i=0;  i<instanceArrayCount; i++)
                     {
                         NSInteger PPSSD=[(((instanceArray[i])[@"00400244"])[@"Value"])[0] longValue];
                         NSInteger PPSST=[(((instanceArray[i])[@"00400245"])[@"Value"])[0] longValue];
                         if ((PPSSD > date) || ((PPSSD==date)&&(PPSST>time)))
                         {
                             date=PPSSD;
                             time=PPSST;
                             index=i;
                         }
                     }
                     instance=instanceArray[index];
                 }
             }
             else return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} sql or qido needed]",urlComponents.path];
             
             
             //wadouri or wadors
             if ([entityDict[@"wadolocaluri"] length])
             {
                 //create wado request
                 
                 
                 NSData *instanceData=[NSData dataWithContentsOfURL:[NSURL URLWithString:wadoRsString]];
                 
             }
             else if ([entityDict[@"wadorslocaluri"] length])
             {
                 //wadors returns bytestream with 00420010
                 NSString *wadoRsString=(((instanceArray[index])[@"00081190"])[@"Value"])[0];
                 LOG_INFO(@"applicable wadors %@",wadoRsString);
                 
                 
                 //get instance
                 NSData *applicableData=[NSData dataWithContentsOfURL:[NSURL URLWithString:wadoRsString]];
                 if (!applicableData || ![applicableData length]) return [RSErrorResponse responseWithClientError:404 message:@"applicable %@ notFound",request.URL.path];
                 
                 NSUInteger applicableDataLength=[applicableData length];
                 
                 NSUInteger valueLocation;
                 //between "Content-Type: " and "\r\n"
                 NSRange ctRange  = [applicableData rangeOfData:contentType options:0 range:NSMakeRange(0, applicableDataLength)];
                 valueLocation=ctRange.location+ctRange.length;
                 NSRange rnRange  = [applicableData rangeOfData:rn options:0 range:NSMakeRange(valueLocation, applicableDataLength-valueLocation)];
                 NSData *contentTypeData=[applicableData subdataWithRange:NSMakeRange(valueLocation,rnRange.location-valueLocation)];
                 NSString *ctString=[[NSString alloc]initWithData:contentTypeData encoding:NSUTF8StringEncoding];
                 LOG_INFO(@"%@",ctString);
                 
                 
                 //between "\r\n\r\n" and "\r\n--"
                 NSRange rnrnRange=[applicableData rangeOfData:rnrn options:0 range:NSMakeRange(0, applicableDataLength)];
                 valueLocation=rnrnRange.location+rnrnRange.length;
                 NSRange rnhhRange=[applicableData rangeOfData:rnhh options:0 range:NSMakeRange(valueLocation, applicableDataLength-valueLocation)];
                 
                 //encapsulatedData
                 NSData *encapsulatedData=[applicableData subdataWithRange:NSMakeRange(valueLocation,rnhhRange.location-valueLocation - 1 - ([[applicableData subdataWithRange:NSMakeRange(rnhhRange.location-2,2)] isEqualToData:rn] * 2))];
                 
                 if ([modality isEqualToString:@"CDA"])
                 {
                     LOG_INFO(@"CDA");
                     NSRange CDAOpeningTagRange=[encapsulatedData rangeOfData:CDAOpeningTag options:0 range:NSMakeRange(0, encapsulatedData.length)];
                     if (CDAOpeningTagRange.location != NSNotFound)
                     {
                         NSRange CDAClosingTagRange=[encapsulatedData rangeOfData:CDAClosingTag options:0 range:NSMakeRange(0, encapsulatedData.length)];
                         NSData *cdaData=[encapsulatedData subdataWithRange:NSMakeRange(CDAOpeningTagRange.location, CDAClosingTagRange.location+CDAClosingTagRange.length-CDAOpeningTagRange.location)];
                         return [RSDataResponse
                                 responseWithData:cdaData
                                 contentType:ctString];
                     }
                 }
                 
                 return [RSDataResponse
                         responseWithData:encapsulatedData
                         contentType:ctString];
             }
             return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} wadouri needed]",urlComponents.path];
         }(request));}];
    
}
@end
