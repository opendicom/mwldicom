//
//  DRS+wado.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180113.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+wado.h"
#import "NSURLComponents+PCS.h"

@implementation DRS (wado)

//wado application/dicom ony
-(void)addWadoHandler
{
    //route
    NSRegularExpression *wadouriRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/" options:NSRegularExpressionCaseInsensitive error:NULL];
    
    //request and completion
    [self addHandler:@"GET" regex:wadouriRegex processBlock:
     ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             
             //valid wado url params syntax? (uses first occurrence only)
             BOOL requestType=false;
             BOOL contentType=false;
             BOOL studyUID=false;
             BOOL seriesUID=false;
             BOOL objectUID=false;

             for (NSURLQueryItem* i in urlComponents.queryItems)
             {
                 if (!requestType && [i.name isEqualToString:@"requestType"] && [i.value isEqualToString:@"WADO"]) requestType=true;
                 else if (!contentType && [i.name isEqualToString:@"contentType"] && [i.value isEqualToString:@"application/dicom"]) contentType=true;
                 else if (!studyUID && [i.name isEqualToString:@"studyUID"] && [DRS.UIRegex numberOfMatchesInString:i.value options:0 range:NSMakeRange(0,[i.value length])]) studyUID=true;
                 else if (!seriesUID && [i.name isEqualToString:@"seriesUID"] && [DRS.UIRegex numberOfMatchesInString:i.value options:0 range:NSMakeRange(0,[i.value length])]) seriesUID=true;
                 else if (!objectUID && [i.name isEqualToString:@"objectUID"] && [DRS.UIRegex numberOfMatchesInString:i.value options:0 range:NSMakeRange(0,[i.value length])]) objectUID=true;
             }

             if (!(requestType && contentType && studyUID && seriesUID && objectUID))
             {
                 if (contentType==false) LOG_DEBUG(@"[wado+any] 'contentType' parameter not found");
                 if (studyUID==false)    LOG_DEBUG(@"[wado+any] 'studyUID parameter not found");
                 if (seriesUID==false)   LOG_DEBUG(@"[wado+any] 'seriesUID parameter not found");
                 if (objectUID==false)   LOG_DEBUG(@"[wado+any] 'objectUID parameter not found");

                 LOG_DEBUG(@"[wado+any] Path: %@",urlComponents.path);
                 LOG_DEBUG(@"[wado+any] Query: %@",urlComponents.query);
                 LOG_DEBUG(@"[wado+any] Content-Type:\"%@\"",request.contentType);
                 return [RSErrorResponse responseWithClientError:404 message:@"[wado+any]<br/> unkwnown path y/o query:<br/>%@?%@",urlComponents.path,urlComponents.query];

             }
             
             
             //additional routing parameter pacs
             NSString *pacsUID=[urlComponents firstQueryItemNamed:@"pacs"];

             if (!pacsUID)
             {
#pragma mark ningún pacs especificado
                 // TODO reemplazar la lógica con qidos para encontrar el pacs, tanto local como remotamente. Se podría ordenar los qido por proximidad.... sql,qido,custodian

                 LOG_VERBOSE(@"[wado] no param named \"pacs\" in: %@",urlComponents.query);
                 
                 //Find wado in any of the local device (recursive)
                 for (NSString *oid in DRS.localoids)
                 {
                     NSData *wadoResp=[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%lld/%@?%@&pacs=%@", DRS.drsport, urlComponents.path, urlComponents.query, oid]]];
                     if (wadoResp && [wadoResp length] > 512) return [RSDataResponse responseWithData:wadoResp contentType:@"application/dicom"];
                 }
                 return [RSErrorResponse responseWithClientError:404 message:@"[wado] not found locally: %@",urlComponents.query];
             }
             
#pragma mark existing pacs?
             NSDictionary *pacs=DRS.devices[pacsUID];
             if (!pacs) return [RSErrorResponse responseWithClientError:404 message:@"[wado] pacs %@ not known]",pacsUID];
             
             
             //(b) sql+filesystem?
             NSString *filesystembaseuri=pacs[@"filesystembaseuri"];
             NSString *sqlobjectmodel=pacs[@"sqlobjectmodel"];
             if ([filesystembaseuri length] && [sqlobjectmodel length])
             {
#pragma mark TODO wado simulated by sql+filesystem
                 return [RSErrorResponse responseWithClientError:404 message:@"%@ [wado] not available]",urlComponents.path];
             }
             
             
             //(c) wadolocaluri?
             if ([pacs[@"wadolocaluri"] length])
             {
                 NSString *uriString=[NSString stringWithFormat:@"%@?%@",
                                      pacs[@"wadolocaluri"],
                                      [urlComponents queryWithoutItemNamed:@"pacs"]
                                      ];
                 LOG_VERBOSE(@"[wado] proxying localmente to:\r\n%@",uriString);
                 
                 
                 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:uriString]];
                 [request setValue:@"application/dicom" forHTTPHeaderField:@"Accept"];
                 //application/dicom+json not accepted !!!!!
                 
                 __block dispatch_semaphore_t __urlProxySemaphore = dispatch_semaphore_create(0);
                 __block NSURLResponse *__response;
                 __block NSError *__error;
                 __block NSDate *__date;
                 __block unsigned long __chunks=0;
                 __block NSData *__data;//block including __data get passed to completion handler of async response
                 
                 NSURLSessionDataTask * const dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                                          {
                                                              __data=data;
                                                              __response=response;
                                                              __error=error;
                                                              dispatch_semaphore_signal(__urlProxySemaphore);
                                                          }];
                 __date=[NSDate date];
                 [dataTask resume];
                 dispatch_semaphore_wait(__urlProxySemaphore, DISPATCH_TIME_FOREVER);
                 //completionHandler of dataTask executed only once and before returning
                 
                 
                 return [RSStreamedResponse responseWithContentType:@"application/dicom" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
                         {
                             if (__error) completionBlock(nil,__error);
                             if (__chunks)
                             {
                                 completionBlock([NSData data], nil);
                                 LOG_DEBUG(@"urlProxy: %lu chunk in %fs for:\r\n%@",__chunks,[[NSDate date] timeIntervalSinceDate:__date],[__response description]);
                             }
                             else
                             {
                                 
                                 completionBlock(__data, nil);
                                 __chunks++;
                             }
                         }];
             }
             
#pragma mark TODO (d) DICOM c-get
             
#pragma mark TODO (e) DICOM c-move
             
             //(f) global?
             if ([pacs[@"custodianglobaluri"] length])
             {
                 NSString *uriString=[NSString stringWithFormat:@"%@?%@",
                                      pacs[@"custodianglobaluri"],
                                      [urlComponents query]
                                      ];
                 LOG_VERBOSE(@"[wado] proxying to another custodian:\r\n%@",uriString);
                 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:uriString]];
                 [request setValue:@"application/dicom" forHTTPHeaderField:@"Accept"];
                 //application/dicom+json not accepted !!!!!
                 
                 __block dispatch_semaphore_t __urlProxySemaphore = dispatch_semaphore_create(0);
                 __block NSURLResponse *__response;
                 __block NSError *__error;
                 __block NSDate *__date;
                 __block unsigned long __chunks=0;
                 __block NSData *__data;
                 
                 NSURLSessionDataTask * const dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                                          {
                                                              __data=data;
                                                              __response=response;
                                                              __error=error;
                                                              dispatch_semaphore_signal(__urlProxySemaphore);
                                                          }];
                 __date=[NSDate date];
                 [dataTask resume];
                 dispatch_semaphore_wait(__urlProxySemaphore, DISPATCH_TIME_FOREVER);
                 //completionHandler of dataTask executed only once and before returning
                 
                 
                 return [RSStreamedResponse responseWithContentType:@"application/dicom" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
                         {
                             if (__error) completionBlock(nil,__error);
                             if (__chunks)
                             {
                                 completionBlock([NSData data], nil);
                                 LOG_DEBUG(@"urlProxy: %lu chunk in %fs for:\r\n%@",__chunks,[[NSDate date] timeIntervalSinceDate:__date],[__response description]);
                             }
                             else
                             {
                                 
                                 completionBlock(__data, nil);
                                 __chunks++;
                             }
                         }];
             }
             
             
             //(g) not available
             LOG_DEBUG(@"%@",[[urlComponents queryItems]description]);
             return [RSErrorResponse responseWithClientError:404 message:@"[wado] pacs %@ not available",pacsUID];
             
         }(request));}];

}
@end
