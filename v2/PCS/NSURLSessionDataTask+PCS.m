//
//  NSURLSessionDataTask+PCS.m
//  httpdicom
//
//  Created by jacquesfauquex on 2017129.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSURLSessionDataTask+PCS.h"
#import "ODLog.h"

@implementation NSURLSessionDataTask (PCS)

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse *__autoreleasing *)responsePointer error:(NSError *__autoreleasing *)errorPointer
{
    dispatch_semaphore_t semaphore;
    __block NSData *result = nil;
    
    semaphore = dispatch_semaphore_create(0);
    
    void (^completionHandler)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error);
    completionHandler = ^(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error)
    {
        if ( errorPointer != NULL )
        {
            *errorPointer = error;
        }
        
        if ( responsePointer != NULL )
        {
            *responsePointer = response;
        }
        
        if ( error == nil )
        {
            result = data;
        }
        
        dispatch_semaphore_signal(semaphore);
    };
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return result;
}


+(NSArray*)existsInPacs:(NSDictionary*)pacs
                    pid:(NSString*)pid
                 issuer:(NSString*)issuer
       returnAttributes:(BOOL)returnAttributes
{
    if (!pid || ![pid length])
    {
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] no pid");
        return false;
    }
    
    
    NSURLRequestCachePolicy cachepolicy;
    if ([pacs[@"cachepolicy"]length]) cachepolicy=[pacs[@"cachepolicy"] integerValue];
    else cachepolicy=1;//NSURLRequestReloadIgnoringCacheData

    NSTimeInterval timeoutinterval;
    if ([pacs[@"timeoutinterval"]length]) timeoutinterval=[pacs[@"timeoutinterval"] doubleValue];
    else timeoutinterval=10;

    
    id request=nil;
    if (issuer) request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/patients?PatientID=%@&IssuerOfPatientID=%@&includefield=00100021&includefield=00080090",pacs[@"dcm4cheelocaluri"],pid,issuer]]
                                                  cachePolicy:cachepolicy
                                              timeoutInterval:timeoutinterval];
    else  request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/patients?PatientID=%@&includefield=00100021",pacs[@"dcm4cheelocaluri"],pid]]
                                            cachePolicy:cachepolicy
                                        timeoutInterval:timeoutinterval];

    
    NSHTTPURLResponse *response=nil;
    NSError *error=nil;
    if ((returnAttributes==false) && [pacs[@"headavailable"]boolValue])
    {
        [request setHTTPMethod:@"HEAD"];
        [self sendSynchronousRequest:request returningResponse:&response error:&error];
        //expected
        if (response.statusCode==200) return @[];//contents
        if (response.statusCode==204) return nil;//no content
        //unexpected
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] HEADpid %ld",response.statusCode);
        if (error) LOG_ERROR(@"[NSURLSessionDataTask+PCS] HEADpid error:\r\n%@",[error description]);
        return nil;
    }
    else
    {
        [request setHTTPMethod:@"GET"];
        NSData *responseData=[self sendSynchronousRequest:request returningResponse:&response error:&error];
        //expected
        if (response.statusCode==200)
        {
            if (![responseData length])
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETpid empty response");
                return nil;
            }
            NSArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if (error)
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETpid badly formed json answer: %@", [error description]);
                return nil;
            }
            if ([arrayOfDicts count]>1) LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETAccessionNumber more than one patient identified by pid:%@ issuer:%@", pid, issuer);
            return arrayOfDicts;
        }
        //unexpected
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETpid %ld",response.statusCode);
        if (error) LOG_ERROR(@"[NSURLSessionDataTask+PCS] GETpid error:\r\n%@",[error description]);
    }
    return nil;
}



+(id)existsInPacs:(NSDictionary*)pacs
  accessionNumber:(NSString*)an
      issuerLocal:(NSString*)issuerLocal
  issuerUniversal:(NSString*)issuerUniversal
       issuerType:(NSString*)issuerType
 returnAttributes:(BOOL)returnAttributes
{
    if (!an || ![an length])
    {
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] no accession number");
        return nil;
    }
    
    
    NSURLRequestCachePolicy cachepolicy;
    if ([pacs[@"cachepolicy"]length]) cachepolicy=[pacs[@"cachepolicy"] integerValue];
    else cachepolicy=1;//NSURLRequestReloadIgnoringCacheData
    
    NSTimeInterval timeoutinterval;
    if ([pacs[@"timeoutinterval"]length]) timeoutinterval=[pacs[@"timeoutinterval"] doubleValue];
    else timeoutinterval=10;
    
    
    id request=nil;
    /* In IRP, there is only one issuer
     
    if (issuerLocal) request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/studies?AccessionNumber=%@&00080051.00400031=%@&includefield=00100021",pacs[@"dcm4cheelocaluri"],an,issuerLocal]]
                                                  cachePolicy:cachepolicy
                                              timeoutInterval:timeoutinterval];
    else if (issuerUniversal && issuerType) request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/studies?AccessionNumber=%@&00080051.00400032=%@&00080051.00400033=%@&includefield=00100021&includefield=00081060",pacs[@"dcm4cheelocaluri"],an,issuerUniversal,issuerType]]
                                                       cachePolicy:cachepolicy
                                                   timeoutInterval:timeoutinterval];
    else
     */
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/studies?AccessionNumber=%@&includefield=00100021",pacs[@"dcm4cheelocaluri"],an]]
                                            cachePolicy:cachepolicy
                                        timeoutInterval:timeoutinterval];
    
    
    NSHTTPURLResponse *response=nil;
    NSError *error=nil;
    if ((returnAttributes==false) && [pacs[@"headavailable"] boolValue])
    {
        [request setHTTPMethod:@"HEAD"];
        [self sendSynchronousRequest:request returningResponse:&response error:&error];
        if (response.statusCode==200) return @{};//exists
        else return nil;//doesn't exist
    }
    else
    {
        [request setHTTPMethod:@"GET"];
        NSData *responseData=[self sendSynchronousRequest:request returningResponse:&response error:&error];
        if (response.statusCode==200)
        {
            if (![responseData length])
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETAccessionNumber empty response");
                return nil;
            }
            NSArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if (error)
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETAccessionNumber badly formed json answer: %@", [error description]);
                return nil;
            }
            if ([arrayOfDicts count]==0) return nil;
            if ([arrayOfDicts count]!=1)
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETAccessionNumber more than one study identified by an:%@ issuerLocal:%@ issuerUniversal:%@ issuerType:%@", an, issuerLocal, issuerUniversal, issuerType);
                return nil;
            }
            return arrayOfDicts[0];
        }
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] GETAccessionNumber %ld",response.statusCode);
        if (error) LOG_ERROR(@"[NSURLSessionDataTask+PCS] GETAccessionNumber error:\r\n%@",[error description]);
    }
    return nil;
}

+(NSArray*)existsInPacs:(NSDictionary*)pacs
               studyUID:(NSString*)studyUID
              seriesUID:(NSString*)seriesUID
                 sopUID:(NSString*)sopUID
       returnAttributes:(BOOL)returnAttributes
{
    NSURLRequestCachePolicy cachepolicy;
    if ([pacs[@"cachepolicy"]length]) cachepolicy=[pacs[@"cachepolicy"] integerValue];
    else cachepolicy=1;//NSURLRequestReloadIgnoringCacheData
    
    NSTimeInterval timeoutinterval;
    if ([pacs[@"timeoutinterval"]length]) timeoutinterval=[pacs[@"timeoutinterval"] doubleValue];
    else timeoutinterval=10;
    
    NSMutableString *URLString=[NSMutableString stringWithFormat:@"%@/rs/",pacs[@"dcm4cheelocaluri"]];
    if (sopUID)
    {
        [URLString appendString:@"instances?SOPInstanceUID="];
        [URLString appendString:sopUID];

        if (seriesUID)
        {
            [URLString appendString:@"&SeriesInstanceUID="];
            [URLString appendString:seriesUID];
        }
 
        if (studyUID)
        {
            [URLString appendString:@"&StudyInstanceUID="];
            [URLString appendString:studyUID];
        }
    }
    else if (seriesUID)
    {
        [URLString appendString:@"series?SeriesInstanceUID="];
        [URLString appendString:seriesUID];
        
        if (studyUID)
        {
            [URLString appendString:@"&StudyInstanceUID="];
            [URLString appendString:studyUID];
        }
    }
    else if (studyUID)
    {
        [URLString appendString:@"studies?StudyInstanceUID="];
        [URLString appendString:studyUID];
    }
    else //no level
    {
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] no studyUID");
        return nil;
    }
    [URLString appendString:@"&includefield=00100021"];
    LOG_VERBOSE(@"[PCS] %@", URLString);

    id request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]
                                       cachePolicy:cachepolicy
                                   timeoutInterval:timeoutinterval];

    NSHTTPURLResponse *response=nil;
    NSError *error=nil;
    if ((returnAttributes==false) && [pacs[@"headavailable"] boolValue])
    {
        [request setHTTPMethod:@"HEAD"];
        [self sendSynchronousRequest:request returningResponse:&response error:&error];
        if (response.statusCode==200) return @[];//exists
        else return nil;//doesn't exist
    }
    else
    {
        [request setHTTPMethod:@"GET"];
        NSData *responseData=[self sendSynchronousRequest:request returningResponse:&response error:&error];
        if (response.statusCode==200)
        {
            if (![responseData length])
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GET qido empty response");
                return nil;
            }
            NSArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if (error)
            {
                LOG_WARNING(@"[NSURLSessionDataTask+PCS] GET qido badly formed json answer: %@", [error description]);
                return nil;
            }
            if ([arrayOfDicts count]==0) return nil;
            return arrayOfDicts;
        }
        LOG_WARNING(@"[NSURLSessionDataTask+PCS] GET wado %ld",response.statusCode);
        if (error) LOG_ERROR(@"[NSURLSessionDataTask+PCS] GET wado error:\r\n%@",[error description]);
    }
    return nil;
}

@end
