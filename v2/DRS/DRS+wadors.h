//
//  DRS+wadors.h
//  httpdicom
//
//  Created by jacquesfauquex on 20180117.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

//wadors multipart/related;type=application/dicom
 
// /studies/{StudyInstanceUID}
//http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.1
 
// /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}
//http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.2
 
// /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances/{SOPInstanceUID}
//http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.3
 
//Accept: multipart/related;type="application/dicom"

//additional parameter: pacs={oid}


#import "DRS.h"

@interface DRS (wadors)

-(void)addWadorsHandler;

@end


#pragma mark wadors multipart/related;type=application/dicom
/*
 //wadors should be evaluated before qido regex
 
 // /studies/{StudyInstanceUID}
 //http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.1
 
 // /pacs/{OID}/rs/studies/{StudyInstanceUID}/series/{SeriesInstanceUID}
 //http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.2
 
 // /pacs/{OID}/rs/studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances/{SOPInstanceUID}
 //http://dicom.nema.org/medical/dicom/current/output/html/part18.html#sect_6.5.3
 
 //Accept: multipart/related;type="application/dicom"
 NSRegularExpression *wadorsRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/studies\\/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*.*" options:NSRegularExpressionCaseInsensitive error:NULL];
 [httpdicomServer addHandler:@"GET" regex:wadorsRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
 {
 LOG_DEBUG(@"[wadors]: %@",request.remoteAddressString);
 
 NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
 
 #pragma mark TODO validator
 //valid params syntax?
 //NSString *wadorsQueryItemsError=[urlComponents wadorsQueryItemsError];
 //if (wadorsQueryItemsError) return [RSErrorResponse responseWithClientError:404 message:@"[wadors dicom] query item %@ error in: %@",wadorsQueryItemsError,urlComponents.query];
 
 //param pacs
 NSString *pacs=[urlComponents firstQueryItemNamed:@"pacs"];
 
 // (a) any local pacs
 if (!pacs)
 {
 LOG_VERBOSE(@"[wadors] no param named \"pacs\" in: %@",urlComponents.query);
 //Find wado in any of the local device (recursive)
 for (NSString *oid in localOIDs)
 {
 #pragma mark TODO pasar de wado a wadors
 NSData *wadoResp=[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%lld/%@?%@&pacs=%@", port, urlComponents.path, urlComponents.query, oid]]];
 if (wadoResp && [wadoResp length] > 512) return [RSDataResponse responseWithData:wadoResp contentType:@"application/dicom"];
 }
 return [RSErrorResponse responseWithClientError:404 message:@"[wadors] not found locally: %@",urlComponents.query];
 }
 
 //find entityDict
 NSDictionary *entityDict=pacs[pacs];
 if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} not found]",urlComponents.path];
 
 //(b) sql+filsystem
 NSString *filesystembaseuri=entityDict[@"filesystembaseuri"];
 NSString *sqlobjectmodel=entityDict[@"sqlobjectmodel"];
 
 if ([filesystembaseuri length] && [sqlobjectmodel length])
 {
 #pragma mark TODO wado sql+filesystem
 return [RSErrorResponse responseWithClientError:404 message:@"%@ [wadors] not available]",urlComponents.path];
 }
 
 //(c)wadorslocaluri
 NSString *wadorsBaseString=entityDict[@"wadorslocaluri"];
 if ([entityDict[@"wadorslocaluri"] length]>0)
 {
 NSString *uriString=[NSString stringWithFormat:@"%@%@?%@",
 entityDict[@"wadorslocaluri"],
 urlComponents.path,
 [urlComponents queryWithoutItemNamed:@"pacs"]
 ];
 LOG_VERBOSE(@"[wadors] proxying localmente to:\r\n%@",uriString);
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:uriString]];
 [request setValue:@"multipart/related;type=application/dicom" forHTTPHeaderField:@"Accept"];
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
 
 
 return [RSStreamedResponse responseWithContentType:@"multipart/related;type=application/dicom" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
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
 
 
 //(d) global?
 if ([entityDict[@"custodianglobaluri"] length])
 {
 NSString *uriString=[NSString stringWithFormat:@"%@%@?%@",
 entityDict[@"custodianglobaluri"],
 urlComponents.path,
 [urlComponents query]
 ];
 LOG_VERBOSE(@"[wadors] proxying to another custodian:\r\n%@",uriString);
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:uriString]];
 [request setValue:@"multipart/related;type=application/dicom" forHTTPHeaderField:@"Accept"];
 
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
 
 
 return [RSStreamedResponse responseWithContentType:@"multipart/related;type=application/dicom" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
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
 
 //(e) not available
 return [RSErrorResponse responseWithClientError:404 message:@"[wadors] pacs %@ not available",pacs];
 
 }(request));}];
 */
