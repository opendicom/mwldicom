//
//  DRS+iheiid.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180118.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+iheiid.h"

@implementation DRS (iheiid)

-(void)addIheiidHandler
{
NSRegularExpression *iheiidRegex = [NSRegularExpression regularExpressionWithPattern:@"/IHEInvokeImageDisplay" options:0 error:NULL];
[httpdicomServer addHandler:@"GET" regex:iheiidRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
{
  LOG_DEBUG(@"client: %@",request.remoteAddressString);
  NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
  NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
  
  NSDictionary *q=request.query;
  
  //(1) b= html5dicomURL
  NSURL *requestURL=request.URL;
  NSString *bSlash=requestURL.baseURL.absoluteString;
  NSString *b=[bSlash substringToIndex:[bSlash length]-1];
  NSString *p=requestURL.path;
  LOG_INFO(@"%@%@?%@",b,p,requestURL.query);
  
  
  //(2) accept requestType STUDY / SERIES only
  NSString *requestType=q[@"requestType"];
  if (
      !requestType
      ||!
      (  [requestType isEqualToString:@"STUDY"]
       ||[requestType isEqualToString:@"SERIES"]
       )
      ) return [RSDataResponse responseWithText:[NSString stringWithFormat:@"missing requestType param in %@%@?%@",b,p,requestURL.query]];
  
  //session
  if (!q[@"session"]) return [RSDataResponse responseWithText:[NSString stringWithFormat:@"missing session param in %@%@?%@",b,p,requestURL.query]];
  
  
  //custodianURI
  
  if (!q[@"custodianOID"]) return [RSDataResponse responseWithText:[NSString stringWithFormat:@"missing custodianOID param in %@%@?%@",b,p,requestURL.query]];
  
  NSString *custodianURI;
  //if ((devices[q[@"custodianOID"]])[@"local"])
  custodianURI=[NSString stringWithFormat:@"http://localhost:%lld",port];
  //else custodianURI=(devices[q[@"custodianOID"]])[@"custodianglobaluri"];
  //if (!@"custodianURI") return [RSDataResponse responseWithText:[NSString stringWithFormat:@"invalid custodianOID param in %@%@?%@",b,p,requestURL.query]];
  
  
  //proxyURI
  NSString *proxyURI=q[@"proxyURI"];
  if (!proxyURI) proxyURI=b;
  
  //redirect to specific manifest
  NSMutableString *manifest=[NSMutableString string];
  
  NSString *viewerType=q[@"viewerType"];
  if (  !viewerType
      || [viewerType isEqualToString:@"IHE_BIR"]
      || [viewerType isEqualToString:@"weasis"]
      )
  {
      [manifest appendString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r"];
      NSString *additionalParameters=(devices[q[@"custodianOID"]])[@"wadoadditionalparameters"];
      if (!additionalParameters)additionalParameters=@"";
      [manifest appendFormat:@"<wado_query xmlns=\"http://www.weasis.org/xsd\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" wadoURL=\"%@\" requireOnlySOPInstanceUID=\"false\" additionnalParameters=\"%@&amp;session=%@&amp;custodianOID=%@\" overrideDicomTagsList=\"\">",
       proxyURI,
       additionalParameters,
       q[@"session"],
       q[@"custodianOID"]
       ];
      
      NSString *manifestWeasisURI;
      if ([requestType isEqualToString:@"STUDY"])
      {
          if (q[@"accessionNumber"]) manifestWeasisURI=[NSString stringWithFormat:@"%@/manifest/weasis/studies?AccessionNumber=%@&custodianOID=%@",custodianURI,q[@"accessionNumber"],q[@"custodianOID"]];
          else if (q[@"studyUID"]) manifestWeasisURI=[NSString stringWithFormat:@"%@/manifest/weasis/studies?StudyInstanceUID=%@&custodianOID=%@",custodianURI,q[@"studyUID"],q[@"custodianOID"]];
          else return [RSDataResponse responseWithText:[NSString stringWithFormat:@"requestType=STUDY requires param accessionNumber or studyUID in %@%@?%@",b,p,requestURL.query]];
      }
      else
      {
          //SERIES
          if (q[@"studyUID"] && q[@"seriesUID"]) manifestWeasisURI=[NSString stringWithFormat:@"%@/manifest/weasis/studies/%@/series/%@?custodianOID=%@",custodianURI,q[@"studyUID"],q[@"seriesUID"],q[@"custodianOID"]];
          else return [RSDataResponse responseWithText:[NSString stringWithFormat:@"requestType=SERIES requires params studyUID and seriesUID in %@%@?%@",b,p,requestURL.query]];
      }
      LOG_INFO(@"%@",manifestWeasisURI);
      [manifest appendFormat:@"%@\r</wado_query>\r",[NSString stringWithContentsOfURL:[NSURL URLWithString:manifestWeasisURI] encoding:NSUTF8StringEncoding error:nil]];
      LOG_INFO(@"%@",manifest);
      
      if ([manifest length]<350) [RSDataResponse responseWithText:[NSString stringWithFormat:@"zero objects for %@%@?%@",b,p,requestURL.query]];
      
      
      if (![custodianURI isEqualToString:@"http://localhost"])
      {
          //get series not available in dev0
          
          NSXMLDocument *xmlDocument=[[NSXMLDocument alloc]initWithXMLString:manifest options:0 error:nil];
          NSArray *seriesWadorsArray = [xmlDocument nodesForXPath:@"wado_query/Patient/Study/Series" error:nil];
          for (NSXMLNode *node in seriesWadorsArray)
          {
              NSString *seriesWadors=[node stringValue];// /studies/{studies}/series/{series}
              
              //cantidad de instancias en la serie en dev0?
              
          }
      }
      RSDataResponse *response=[RSDataResponse responseWithData:[[[LFCGzipUtility gzipData:[manifest dataUsingEncoding:NSUTF8StringEncoding]] base64EncodedStringWithOptions:0]dataUsingEncoding:NSUTF8StringEncoding] contentType:@"application/x-gzip"];
      [response setValue:@"Base64" forAdditionalHeader:@"Content-Transfer-Encoding"];//https://tools.ietf.org/html/rfc2045
      
      return response;
  }
  else if ([viewerType isEqualToString:@"cornerstone"])
  {
      //cornerstone
      NSMutableDictionary *cornerstone=[NSMutableDictionary dictionary];
      
      //TODO CHANGE HARD CODING
      //qido uri [@"local"]
      //127.0.0.1:11111/pacs/2.16.858.0.1.4.0.72769.217215590012.2/rs
      NSString *qidoSeriesString;
      if ([requestType isEqualToString:@"STUDY"])
      {
          if (q[@"accessionNumber"]) qidoSeriesString=[NSString stringWithFormat:@"%@/pacs/2.16.858.0.1.4.0.72769.217215590012.2/rs/series?AccessionNumber=%@",custodianURI,q[@"accessionNumber"]];
          else if (q[@"studyUID"]) qidoSeriesString=[NSString stringWithFormat:@"%@/pacs/2.16.858.0.1.4.0.72769.217215590012.2/rs/series?StudyInstanceUID=%@",custodianURI,q[@"studyUID"]];
          else return [RSDataResponse responseWithText:[NSString stringWithFormat:@"requestType=STUDY requires param accessionNumber or studyUID in %@%@?%@",b,p,requestURL.query]];
      }
      else
      {
          //SERIES
          if (q[@"studyUID"] && q[@"seriesUID"]) qidoSeriesString=[NSString stringWithFormat:@"%@/pacs/2.16.858.0.1.4.0.72769.217215590012.2/rs/series?StudyInstanceUID=%@&SeriesInstanceUID=%@",custodianURI,q[@"studyUID"],q[@"seriesUID"]];
          else return [RSDataResponse responseWithText:[NSString stringWithFormat:@"requestType=SERIES requires params studyUID and seriesUID in %@%@?%@",b,p,requestURL.query]];
      }
      LOG_DEBUG(@"%@",qidoSeriesString);
      
      
      NSMutableData *seriesData=[NSMutableData data];
      [seriesData setData:[NSData dataWithContentsOfURL:[NSURL URLWithString:qidoSeriesString]]];
      //TODO CHARSET
      //                  if (charset==5) //latin1
      //                {
      //                      NSString *latin1String=[[NSString alloc]initWithData:seriesData encoding:NSISOLatin1StringEncoding];
      //                      [seriesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
      //                  }
      
      NSError *error=nil;
      NSMutableArray *seriesArray=[NSJSONSerialization JSONObjectWithData:seriesData options:NSJSONReadingMutableContainers error:&error];
      if (error) return [RSErrorResponse responseWithClientError:404 message:@"bad qido sql result : %@",[error description]];
      
      [cornerstone setObject:((((seriesArray[0])[@"00100010"])[@"Value"])[0])[@"Alphabetic"] forKey:@"patientName"];
      [cornerstone setObject:(((seriesArray[0])[@"00100020"])[@"Value"])[0] forKey:@"patientId"];
      NSString *s=(((seriesArray[0])[@"00080020"])[@"Value"])[0];
      NSString *StudyDate=[NSString stringWithFormat:@"%@-%@-%@",
                           [s substringWithRange:NSMakeRange(0,4)],
                           [s substringWithRange:NSMakeRange(4,2)],
                           [s substringWithRange:NSMakeRange(6,2)]];
      [cornerstone setObject:StudyDate forKey:@"studyDate"];
      [cornerstone setObject:(((seriesArray[0])[@"00080061"])[@"Value"])[0] forKey:@"modality"];
      NSString *studyDescription=(((seriesArray[0])[@"00081030"])[@"Value"])[0];
      if (!studyDescription) studyDescription=@"";
      [cornerstone setObject:studyDescription forKey:@"studyDescription"];//
      [cornerstone setObject:@999 forKey:@"numImages"];
      NSString *studyId=(((seriesArray[0])[@"00200010"])[@"Value"])[0];
      if (!studyId)studyId=@"";
      [cornerstone setObject:studyId forKey:@"studyId"];
      NSMutableArray *seriesList=[NSMutableArray array];
      [cornerstone setObject:seriesList forKey:@"seriesList"];
      for (NSDictionary *seriesQido in seriesArray)
      {
          if (
              !([((seriesQido[@"00080060"])[@"Value"])[0] isEqualToString:@"OT"])
              &&!([((seriesQido[@"00080060"])[@"Value"])[0] isEqualToString:@"DOC"]))
          {
              //cornerstone no muestra los documentos encapsulados
              NSMutableDictionary *seriesCornerstone=[NSMutableDictionary dictionary];
              [seriesList addObject:seriesCornerstone];
              NSString *seriesDescription=((seriesQido[@"0008103E"])[@"Value"])[0];
              if (!seriesDescription)seriesDescription=@"";
              [seriesCornerstone setObject:seriesDescription forKey:@"seriesDescription"];
              [seriesCornerstone setObject:((seriesQido[@"00200011"])[@"Value"])[0] forKey:@"seriesNumber"];
              NSMutableArray *instanceList=[NSMutableArray array];
              [seriesCornerstone setObject:instanceList forKey:@"instanceList"];
              //get instances for the series
              //TODO remove hardcode
              NSString *qidoInstancesString=
              [NSString stringWithFormat:@"%@/pacs/2.16.858.0.1.4.0.72769.217215590012.2/rs/instances?StudyInstanceUID=%@&SeriesInstanceUID=%@",
               custodianURI,
               q[@"studyUID"],
               ((seriesQido[@"0020000E"])[@"Value"])[0]
               ];
              LOG_INFO(@"%@",qidoInstancesString);
              NSData *qidoInstanceResp=[NSData dataWithContentsOfURL:[NSURL URLWithString:qidoInstancesString]];
              NSMutableArray *instancesArray=[NSJSONSerialization JSONObjectWithData:qidoInstanceResp options:NSJSONReadingMutableContainers error:nil];
              
              //classify instancesArray by instanceNumber
              
              [instancesArray sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                  if ([((obj1[@"00200013"])[@"Value"])[0]intValue]<[((obj2[@"00200013"])[@"Value"])[0]intValue])
                      return NSOrderedAscending;
                  return NSOrderedDescending;
              }];
              
              
              
              for (NSDictionary *instance in instancesArray)
              {
                  NSString *wadouriInstance=[NSString stringWithFormat:@"%@?requestType=WADO&studyUID=%@&seriesUID=%@&objectUID=%@&session=%@&custodianOID=%@",proxyURI,
                                             q[@"studyUID"],
                                             ((seriesQido[@"0020000E"])[@"Value"])[0],
                                             ((instance[@"00080018"])[@"Value"])[0],
                                             q[@"session"],
                                             q[@"custodianOID"]
                                             ];
                  [instanceList addObject:@{
                                            @"imageId":wadouriInstance
                                            }];
              }
          }
      }
      NSData *cornerstoneJson=[NSJSONSerialization dataWithJSONObject:cornerstone options:0 error:nil];
      LOG_DEBUG(@"cornerstone manifest :\r\n%@",[[NSString alloc] initWithData:cornerstoneJson encoding:NSUTF8StringEncoding]);
      return [RSDataResponse responseWithData:cornerstoneJson contentType:@"application/json"];
  }
  else if ([viewerType isEqualToString:@"MHD-I"])
  {
      //MHD-I
      if ([requestType isEqualToString:@"STUDY"])
      {
          NSString *accessionNumber=q[@"accessionNumber"];
          NSString *studyUID=q[@"studyUID"];
          if (accessionNumber)
          {
              
          }
          else if (studyUID)
          {
              
          }
          else return [RSDataResponse responseWithText:[NSString stringWithFormat:@"requestType=STUDY requires param accessionNumber or studyUID in %@%@?%@",b,p,requestURL.query]];
          
      }
      else
      {
          //SERIES
      }
  }
  return [RSDataResponse responseWithText:[NSString stringWithFormat:@"unknown viewerType in %@%@?%@",b,p,requestURL.query]];
}
(request));}];
}
@end
