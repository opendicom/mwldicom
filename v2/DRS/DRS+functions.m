//
//  DRS+functions.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180112.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

#import "DRS+functions.h"
#import "NSData+PCS.h"
#import "NSString+PCS.h"

@implementation DRS (functions)

int parseRequestParams(RSRequest* request, NSMutableString *jsonString, NSMutableArray *names, NSMutableArray *values, NSMutableArray *types, NSString **errorString)
{
    if ([request.contentType hasPrefix:@"application/json"])
    {
        NSData *requestData=request.data;
        if (!requestData)
        {
            *errorString=@"[mwlitem] POST Content-Type:\"application/json\" requires a request body...";
            return false;
        }
        NSError *requestJsonError=nil;
        NSDictionary *requestJson=[NSJSONSerialization JSONObjectWithData:requestData options:0 error:&requestJsonError];
        if (requestJsonError)
        {
            NSString *DUMPPATH=[@"/Users/Shared/stowbody/error_json_" stringByAppendingString:[[NSUUID UUID] UUIDString]];
            [requestData writeToFile:DUMPPATH atomically:true];
            LOG_ERROR(@"[REQ] json\r\n%@\r\n%@",DUMPPATH,[requestJsonError description]);
            *errorString=[NSString stringWithFormat:@"[mwlitem] json error: %@",[requestJsonError description]];
            return false;
        }
        [jsonString appendString:[[NSString alloc]initWithData:requestData encoding:NSUTF8StringEncoding]];
        [names addObjectsFromArray:[requestJson allKeys]];
        [values addObjectsFromArray:[requestJson allValues]];
        return true;
    }
    else if ([request.contentType hasPrefix:@"multipart/form-data"])
    {
        //form html5
        
        //LOG_DEBUG(@"[mwlitem] Body: %@",[request.data description]);
        //[request.data writeToFile:@"/private/tmp/data" options:0 error:nil];
        NSDictionary *components=[request.data parseNamesValuesTypesInBodySeparatedBy:[[request.contentType valueForName:@"boundary"]dataUsingEncoding:NSASCIIStringEncoding]];
        //LOG_VERBOSE(@"[mwlitem] request body parts: %@",[components description]);
        names=components[@"names"];
        values=components[@"values"];
        types=components[@"types"];
        return true;
    }
    else if ([request.contentType hasPrefix:@"application/x-www-form-urlencoded"])
    {
        //rest
        [names addObjectsFromArray:[[request arguments]allKeys]];
        [values addObjectsFromArray:[[request arguments]allValues]];
        return true;
    }
    *errorString=[NSString stringWithFormat:@"[[mwlitem] Content-Type:\"%@\" (should be either \"multipart/form-data\" or \"application/x-www-form-urlencoded\"",request.contentType];
    return false;
}

//request type
int requestParams(RSRequest* request, NSMutableArray *names, NSMutableArray *values, NSMutableArray *types, NSString **errorString)
{
    if ([request.contentType hasPrefix:@"application/json"])
    {
        NSData *requestData=request.data;
        if (!requestData)
        {
            *errorString=@"[mwlitem] POST Content-Type:\"application/json\" requires a request body...";
            return false;
        }
        NSError *requestJsonError=nil;
        NSDictionary *requestJson=[NSJSONSerialization JSONObjectWithData:requestData options:0 error:&requestJsonError];
        if (requestJsonError)
        {
            *errorString=[NSString stringWithFormat:@"[mwlitem] json error: %@",[requestJsonError description]];
            return false;
        }

        [names addObjectsFromArray:[requestJson allKeys]];
        [values addObjectsFromArray:[requestJson allValues]];
        return true;
    }
    else if ([request.contentType hasPrefix:@"multipart/form-data"])
    {
        //form html5
        
        //LOG_DEBUG(@"[mwlitem] Body: %@",[request.data description]);
        //[request.data writeToFile:@"/private/tmp/data" options:0 error:nil];
        NSDictionary *components=[request.data parseNamesValuesTypesInBodySeparatedBy:[[request.contentType valueForName:@"boundary"]dataUsingEncoding:NSASCIIStringEncoding]];
        //LOG_VERBOSE(@"[mwlitem] request body parts: %@",[components description]);
        names=components[@"names"];
        values=components[@"values"];
        types=components[@"types"];
        return true;
    }
    else if ([request.contentType hasPrefix:@"application/x-www-form-urlencoded"])
    {
        //rest
        [names addObjectsFromArray:[[request arguments]allKeys]];
        [values addObjectsFromArray:[[request arguments]allValues]];
        return true;
    }
    *errorString=[NSString stringWithFormat:@"[[mwlitem] Content-Type:\"%@\" (should be either \"multipart/form-data\" or \"application/x-www-form-urlencoded\"",request.contentType];
    return false;
}

#pragma mark -
#pragma mark task

int bash(NSData *writeData, NSMutableData *readData)
{
    return task(@"/bin/bash",@[@"-s"], writeData, readData);
}

int task(NSString *launchPath, NSArray *launchArgs, NSData *writeData, NSMutableData *readData)
{
    NSTask *task=[[NSTask alloc]init];
    [task setLaunchPath:launchPath];
    [task setArguments:launchArgs];
    //LOG_INFO(@"%@",[task arguments]);
    NSPipe *writePipe = [NSPipe pipe];
    NSFileHandle *writeHandle = [writePipe fileHandleForWriting];
    [task setStandardInput:writePipe];
    
    NSPipe* readPipe = [NSPipe pipe];
    NSFileHandle *readingFileHandle=[readPipe fileHandleForReading];
    [task setStandardOutput:readPipe];
    [task setStandardError:readPipe];
    
    [task launch];
    [writeHandle writeData:writeData];
    [writeHandle closeFile];
    
    NSData *dataPiped = nil;
    while((dataPiped = [readingFileHandle availableData]) && [dataPiped length])
    {
        [readData appendData:dataPiped];
    }
    //while( [task isRunning]) [NSThread sleepForTimeInterval: 0.1];
    //[task waitUntilExit];        // <- This is VERY DANGEROUS : the main runloop is continuing...
    //[aTask interrupt];
    
    [task waitUntilExit];
    int terminationStatus = [task terminationStatus];
    if (terminationStatus!=0) NSLog(@"ERROR task terminationStatus: %d",terminationStatus);
    return terminationStatus;
}

#pragma mark -
#pragma mark charset

NSMutableArray *jsonMutableArray(NSString *scriptString, NSStringEncoding encoding)
{
    if      (encoding==4) LOG_DEBUG(@"utf8\r\n%@",scriptString);
    else if (encoding==5) LOG_DEBUG(@"latin1\r\n%@",scriptString);
    else                  LOG_DEBUG(@"encoding:%lu\r\n%@",(unsigned long)encoding,scriptString);
    
    NSMutableData *mutableData=[NSMutableData data];
    if (!task(@"/bin/bash",@[@"-s"],[scriptString dataUsingEncoding:NSUTF8StringEncoding],mutableData))
        [RSErrorResponse responseWithClientError:404 message:@"%@",@"can not execute the script"];//NotFound
    NSString *string=[[NSString alloc]initWithData:mutableData encoding:encoding];//5=latinISO1 4=UTF8
    NSData *utf8Data=[string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *e;
    NSMutableArray *mutableArray=[NSJSONSerialization JSONObjectWithData:utf8Data options:NSJSONReadingMutableContainers error:&e];
    if (e)
    {
        LOG_DEBUG(@"%@",[e description]);
        return nil;
    }
    return mutableArray;
}

#pragma mark -
#pragma mark proxy

id qidoUrlProxy(NSString *qidoString,NSString *queryString, NSString *httpdicomString)
{
    __block dispatch_semaphore_t __urlProxySemaphore = dispatch_semaphore_create(0);
    __block NSMutableData *__data;
    __block NSURLResponse *__response;
    __block NSError *__error;
    __block NSDate *__date;
    __block unsigned long __chunks=0;
    
    NSString *urlString;
    if (queryString) urlString=[NSString stringWithFormat:@"%@?%@",qidoString,queryString];
    else urlString=qidoString;
    
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];//application/dicom+json not accepted !!!!!
    
    NSURLSessionDataTask * const dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                             {
                                                 __data=[NSMutableData dataWithData:data];
                                                 __response=response;
                                                 __error=error;
                                                 dispatch_semaphore_signal(__urlProxySemaphore);
                                             }];
    __date=[NSDate date];
    [dataTask resume];
    dispatch_semaphore_wait(__urlProxySemaphore, DISPATCH_TIME_FOREVER);
    //completionHandler of dataTask executed only once and before returning
    return [RSStreamedResponse responseWithContentType:@"application/json" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
            {
                if (__error) completionBlock(nil,__error);
                if (__chunks)
                {
                    completionBlock([NSData data], nil);
                    LOG_DEBUG(@"urlProxy: %lu chunk in %fs for:\r\n%@",__chunks,[[NSDate date] timeIntervalSinceDate:__date],[__response description]);
                }
                else
                {
                    NSData *pacsUri=[qidoString dataUsingEncoding:NSUTF8StringEncoding];
                    NSData *httpdicomUri=[httpdicomString dataUsingEncoding:NSUTF8StringEncoding];
                    NSUInteger httpdicomLength=[httpdicomUri length];
                    NSRange dataLeft=NSMakeRange(0,[__data length]);
                    NSRange occurrence=[__data rangeOfData:pacsUri options:0 range:dataLeft];
                    while (occurrence.length)
                    {
                        [__data replaceBytesInRange:occurrence
                                          withBytes:[httpdicomUri bytes]
                                             length:httpdicomLength];
                        dataLeft.location=occurrence.location+httpdicomLength;
                        dataLeft.length=[__data length]-dataLeft.location;
                        occurrence=[__data rangeOfData:pacsUri options:0 range:dataLeft];
                    }
                    completionBlock(__data, nil);
                    __chunks++;
                }
            }];
}


id urlChunkedProxy(NSString *urlString,NSString *contentType)
{
    __block dispatch_semaphore_t __urlProxySemaphore = dispatch_semaphore_create(0);
    __block NSData *__data;
    __block NSURLResponse *__response;
    __block NSError *__error;
    __block NSDate *__date;
    __block unsigned long __chunks=0;
    
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:contentType forHTTPHeaderField:@"Accept"];//application/dicom+json not accepted !!!!!
    [request setValue:@"chunked" forHTTPHeaderField:@"Transfer-Encoding"];
    
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
    
    
    return [RSStreamedResponse responseWithContentType:contentType asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
            {
                if (__error) completionBlock(nil,__error);
                if (__chunks)
                {
                    completionBlock([NSData data], nil);
                    LOG_DEBUG(@"urlProxy: %lu chunk in %fs for:\r\n%@",__chunks,[[NSDate date] timeIntervalSinceDate:__date],[__response description]);
                }
                else completionBlock(__data, nil);
                __chunks++;
            }];
}



@end
