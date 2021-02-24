#import <Foundation/Foundation.h>
#import "NSURLComponents+PCS.h"
#import "ODLog.h"
//look at the implementation of the function ODLog below

#import "RS.h"
#import "RSDataResponse.h"
#import "RSErrorResponse.h"
#import "RSFileResponse.h"
#import "RSStreamedResponse.h"

#import "LFCGzipUtility.h"

#import "DICMTypes.h"
#import "NSString+PCS.h"
#import "NSData+PCS.h"
#import "NSData+ZIP.h"
#import "NSURLSessionDataTask+PCS.h"
#import "NSMutableURLRequest+PCS.h"
#import "NSMutableString+DSCD.h"
#import "NSUUID+DICM.h"


//static immutable write
static uint32 zipLocalFileHeader=0x04034B50;
static uint16 zipVersion=0x0A;
static uint32 zipNameLength=0x28;
static uint32 zipFileHeader=0x02014B50;
static uint32 zipEndOfCentralDirectory=0x06054B50;
static NSTimeInterval timeout=300;

static NSRegularExpression *UIRegex=nil;
static NSRegularExpression *SHRegex=nil;
static NSRegularExpression *DARegex=nil;
static NSArray *qidoLastPathComponent=nil;
static NSData *pdfContentType;

//static immutable find within NSData
static NSData *rn;
static NSData *rnrn;
static NSData *rnhh;
static NSData *contentType;
static NSData *CDAOpeningTag;
static NSData *CDAClosingTag;
static NSData *ctad;
static NSData *emptyJsonArray;

//datatables caché [session]
static NSMutableDictionary *Date;
static NSMutableDictionary *Req;
static NSMutableDictionary *Total;
static NSMutableDictionary *Filtered;
static NSMutableDictionary *sPatientID;
static NSMutableDictionary *sPatientName;
static NSMutableDictionary *sDate_start;
static NSMutableDictionary *sDate_end;
static NSMutableDictionary *sModality;
static NSMutableDictionary *sStudyDescription;

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
    //[task waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
    //[aTask interrupt];
    
    [task waitUntilExit];
    int terminationStatus = [task terminationStatus];
    if (terminationStatus!=0) LOG_INFO(@"ERROR task terminationStatus: %d",terminationStatus);
    return terminationStatus;
}

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

ODLogLevelEnum ODLogLevel = ODLogLevel_Info;
static const char* levelNames[] = {"DEBUG", "VERBOSE", "INFO", "WARNING", "ERROR", "EXCEPTION"};
void ODLog(ODLogLevelEnum level, NSString* format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    fprintf(stderr, "[%s] %s\n", levelNames[level], [message UTF8String]);
}

BOOL buildWhereString(BOOL E,BOOL S,BOOL I,NSArray *queryItems, NSDictionary *sqlDict, NSMutableString *whereString)
{

    return true;
}



int main(int argc, const char* argv[]) {
    @autoreleasepool {
        
        
        /*
         syntax:
         [0] mwldicom
         [1] deploypath
         [2] mwldicomport
         [3] loglevel [ DEBUG | VERBOSE | INFO | WARNING | ERROR | EXCEPTION]
         */
        NSArray *args=[[NSProcessInfo processInfo] arguments];
        if ([args count]!=4)
        {
            LOG_WARNING(@"syntax: httpdicom deploypath httpdicomport loglevel");
            return 1;
        }
        
        
        //[3] loglevel
        NSUInteger llindex=[@[@"DEBUG",@"VERBOSE",@"INFO",@"WARNING",@"ERROR",@"EXCEPTION"] indexOfObject:args[3]];
        if (llindex==NSNotFound)
        {
            LOG_ERROR(@"ODLogLevel (arg 1) should be one of [ DEBUG | VERBOSE | INFO | WARNING | ERROR | EXCEPTION ]");
            return 1;
        }
        ODLogLevel=(int)llindex;
        
        
        //[2] mwldicomport
        long long port=[args[2]longLongValue];
        if (port <1 || port>65535)
        {
            LOG_ERROR(@"port should be between 0 and 65535");
            return 1;
        }
        
        //util formatters
        UIRegex = [NSRegularExpression regularExpressionWithPattern:@"^[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*$" options:0 error:NULL];
        SHRegex = [NSRegularExpression regularExpressionWithPattern:@"^(?:\\s*)([^\\r\\n\\f\\t]*[^\\r\\n\\f\\t\\s])(?:\\s*)$" options:0 error:NULL];
        DARegex = [NSRegularExpression regularExpressionWithPattern:@"^(19|20)\\d\\d(01|02|03|04|05|06|07|08|09|10|11|12)(01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$" options:0 error:NULL];
        [NSURLComponents initializeStaticRegex];
        qidoLastPathComponent=@[@"/patients",@"/studies",@"/series",@"/instances"];
        [NSData initPCS];
        
        //static immutable
        rn=[@"/r/n" dataUsingEncoding:NSASCIIStringEncoding];//0x0A0D;
        rnrn=[@"/r/n/r/n" dataUsingEncoding:NSASCIIStringEncoding];//0x0A0D0A0D;
        rnhh=[@"/r/n--" dataUsingEncoding:NSASCIIStringEncoding];//0x2D2D0A0D;
        contentType=[@"Content-Type: " dataUsingEncoding:NSASCIIStringEncoding];
        CDAOpeningTag=[@"<ClinicalDocument" dataUsingEncoding:NSASCIIStringEncoding];
        CDAClosingTag=[@"</ClinicalDocument>" dataUsingEncoding:NSASCIIStringEncoding];
        ctad=[@"Content-Type: application/dicom\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        emptyJsonArray=[@"[]" dataUsingEncoding:NSASCIIStringEncoding];

        //datatables caché [session]
        Req=[NSMutableDictionary dictionary];
        Total=[NSMutableDictionary dictionary];
        Filtered=[NSMutableDictionary dictionary];
        Date=[NSMutableDictionary dictionary];
        sPatientID=[NSMutableDictionary dictionary];
        sPatientName=[NSMutableDictionary dictionary];
        sDate_start=[NSMutableDictionary dictionary];
        sDate_end=[NSMutableDictionary dictionary];
        sModality=[NSMutableDictionary dictionary];
        sStudyDescription=[NSMutableDictionary dictionary];
        

        //[1] deploypath
        NSString *deployPath=[args[1]stringByExpandingTildeInPath];
        BOOL isDirectory=FALSE;
        if (![[NSFileManager defaultManager]fileExistsAtPath:deployPath isDirectory:&isDirectory] || !isDirectory)
        {
            LOG_ERROR(@"deploy folder does not exist");
            return 1;
        }

        //1.1 codesystem
        NSDictionary *codesystem=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/codesystem.plist"]];
        if (!codesystem) codesystem=@{};
        
        //1.2 code
        NSMutableDictionary *codeDict=[NSMutableDictionary dictionary];
        NSArray *codes=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:[deployPath stringByAppendingPathComponent:@"voc/code/"] error:nil];
        if (!codes) LOG_WARNING(@"no folder voc/code into deploy");
        else if ([codes count]==0) LOG_WARNING(@"no code file registered");
        else
        {
            for (NSString *code in codes)
            {
                [codeDict setObject:[NSDictionary dictionaryWithContentsOfFile:[[deployPath stringByAppendingPathComponent:@"voc/code"] stringByAppendingPathComponent:code]]
                             forKey:[code stringByDeletingPathExtension]
                 ];
            }
        }


        //1.3 devices (pacs is another name synonym of devices)

        //initialization of custodian and sql dictionaries based on properties of entitiesDicts
        NSMutableDictionary *custodianoids=[NSMutableDictionary dictionary];
        NSMutableDictionary *custodiantitles=[NSMutableDictionary dictionary];
        
        NSMutableSet *sqlset=[NSMutableSet set];
        NSDictionary *entitiesDicts=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"devices/devices.plist"]];
        if (!entitiesDicts)
        {
            LOG_ERROR(@"could not get contents of devices/devices.plist");
            return 1;
        }
        
#pragma mark TODO classify entitiesDicts
        // sql, dicomweb, dicom, custodian
        
        for (NSDictionary *d in [entitiesDicts allValues])
        {
            NSString *newcustodiantitle=d[@"custodiantitle"];
            if (
                   !newcustodiantitle
                || ![newcustodiantitle length]
                || ![SHRegex numberOfMatchesInString:newcustodiantitle options:0 range:NSMakeRange(0,[newcustodiantitle length])]
                )
            {
                LOG_ERROR(@"bad custodiantitle");
                return 1;
            }

            NSString *newcustodianoid=d[@"custodianoid"];
            if (
                   !newcustodianoid
                || ![newcustodianoid length]
                || ![UIRegex numberOfMatchesInString:newcustodianoid options:0 range:NSMakeRange(0,[newcustodianoid length])]
                )
            {
                LOG_ERROR(@"bad custodianoid");
                return 1;
            }
            
            if ( custodianoids[newcustodianoid] || custodiantitles[newcustodiantitle])
            {
                //verify if there is no incoherence
                if (
                       ![newcustodiantitle isEqualToString:custodianoids[newcustodianoid]]
                    || ![newcustodianoid isEqualToString:custodiantitles[newcustodiantitle]]
                    )
                {
                    LOG_ERROR(@"devices incoherence in custodian oid and title ");
                    return 1;
                }

            }
            else
            {
                //add custodian
                [custodianoids setObject:newcustodiantitle forKey:newcustodianoid];
                [custodiantitles setObject:newcustodianoid forKey:newcustodiantitle];
            }

            //sql
            if (d[@"sqlobjectmodel"]) [sqlset addObject:d[@"sqlobjectmodel"]];
        }
        //response data for root queries custodians/titles and custodians/oids
        NSData *custodianOIDsData = [NSJSONSerialization dataWithJSONObject:[custodianoids allKeys] options:0 error:nil];
        NSData *custodianTitlesData = [NSJSONSerialization dataWithJSONObject:[custodiantitles allKeys] options:0 error:nil];

        
        //devices OID classified by custodian
        NSMutableDictionary *custodianOIDsaeis=[NSMutableDictionary dictionary];
        for (NSString *custodianOID in [custodianoids allKeys])
        {
            NSMutableArray *custodianOIDaeis=[NSMutableArray array];
            for (NSString *k in [entitiesDicts allKeys])
            {
                NSDictionary *d=[entitiesDicts objectForKey:k];
                if ([[d objectForKey:@"custodianoid"]isEqualToString:custodianOID])[custodianOIDaeis addObject:k];
            }
            [custodianOIDsaeis setValue:custodianOIDaeis forKey:custodianOID];
        }
        LOG_VERBOSE(@"known devices OID classified by corresponding custodian OID:\r\n%@",[custodianOIDsaeis description]);

        //devices titles grouped on custodian
        NSMutableDictionary *custodianTitlesaets=[NSMutableDictionary dictionary];
        NSMutableDictionary *custodianTitlesaetsStrings=[NSMutableDictionary dictionary];
        for (NSString *custodianTitle in [custodiantitles allKeys])
        {
            NSMutableArray *custodianTitleaets=[NSMutableArray array];
            NSMutableString *s=[NSMutableString stringWithString:@"("];

            for (NSString *k in [entitiesDicts allKeys])
            {
                NSDictionary *d=[entitiesDicts objectForKey:k];
                if ([[d objectForKey:@"custodiantitle"]isEqualToString:custodianTitle])
                {
                    [custodianTitleaets addObject:[d objectForKey:@"dicomaet"]];
                    if ([s isEqualToString:@"("])
                        [s appendFormat:@"'%@'",[d objectForKey:@"dicomaet"]];
                    else [s appendFormat:@",'%@'",[d objectForKey:@"dicomaet"]];
                }
            }
            [custodianTitlesaets setObject:custodianTitleaets forKey:custodianTitle];
            [s appendString:@")"];
            [custodianTitlesaetsStrings setObject:s forKey:custodianTitle];
        }
        LOG_VERBOSE(@"known devices aet classified by corresponding custodian title:\r\n%@",[custodianTitlesaets description]);

        NSMutableDictionary *pacsTitlesDictionary=[NSMutableDictionary dictionary];
        NSMutableArray *localOIDs=[NSMutableArray array];
        NSDictionary *custodianDictionary=nil;
        for (NSString *key in [entitiesDicts allKeys])
        {
            [pacsTitlesDictionary setObject:key forKey:[(entitiesDicts[key])[@"custodiantitle"] stringByAppendingPathExtension:(entitiesDicts[key])[@"dicomaet"]]];
            
            if ([(entitiesDicts[key])[@"local"] boolValue])
            {
                [localOIDs addObject:key];
                if ([(entitiesDicts[key])[@"custodianoid"] isEqualToString:key]) custodianDictionary=entitiesDicts[key];
            }
        }
        
        
        
        //1.4 sql queries and sql qido filters
        NSDictionary *datatables=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"objectmodel/datatables.plist"]];
        NSDictionary *qido=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"objectmodel/qido.plist"]];
        NSDictionary *qidokey=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"objectmodel/qidokey.plist"]];
        NSDictionary *wadouris=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"objectmodel/wadouris.plist"]];
        NSDictionary *weasis=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"objectmodel/weasis.plist"]];
        if (
               !datatables
            || !qido
            || !qidokey
            || !wadouris
            || !weasis
            )
        {
            LOG_ERROR(@"lacks of one or more objectmodel plist");
            return 1;
        }

        //create qido attribute index by tags
        NSMutableDictionary *qidotag=[NSMutableDictionary dictionary];
        for (NSString *key in qidokey)
        {
            [qidotag setObject:key forKey:((qidokey[key])[@"tag"])];
        }
        
        LOG_VERBOSE(@"sqls:\r\n%@",[sqlset description]);
        NSMutableDictionary *sql=[NSMutableDictionary dictionary];
        
        for (NSString *sqlname in sqlset)
        {
            NSString *sqlpath=[[deployPath
                               stringByAppendingPathComponent:@"objectmodel"] stringByAppendingPathComponent:sqlname];
            NSDictionary *attribute=[NSDictionary dictionaryWithContentsOfFile:[sqlpath stringByAppendingPathComponent:@"attribute.plist"]];
            NSDictionary *from=[NSDictionary dictionaryWithContentsOfFile:[sqlpath stringByAppendingPathComponent:@"from.plist"]];
            NSDictionary *where=[NSMutableDictionary dictionaryWithContentsOfFile:[sqlpath stringByAppendingPathComponent:@"where.plist"]];
            if (
                   !attribute
                && !from
                && !where
                )
            {
                LOG_ERROR(@"%@ sql configuration incomplete",sqlname);
                return 1;
            }
            
            [sql setObject:@{@"attribute":attribute, @"from":from, @"where":where} forKey:sqlname];
        }

        
        //1.5 country
        NSArray *iso3166ByCountry=[NSArray arrayWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/country.plist"]];
        if (!iso3166ByCountry)
        {
            LOG_ERROR(@"no folder voc/country.plist into deploy");
            return 1;
        }
        
#define PAIS 0
#define COUNTRY 1
#define AB 2
#define ABC 3
#define XXX 4
        NSMutableArray *iso3166PAIS=[NSMutableArray array];
        NSMutableArray *iso3166COUNTRY=[NSMutableArray array];
        NSMutableArray *iso3166AB=[NSMutableArray array];
        NSMutableArray *iso3166ABC=[NSMutableArray array];
        NSMutableArray *iso3166XXX=[NSMutableArray array];
        for (NSArray *countryArray in iso3166ByCountry)
        {
            [iso3166PAIS addObject:countryArray[0]];
            [iso3166COUNTRY addObject:countryArray[1]];
            [iso3166AB addObject:countryArray[2]];
            [iso3166ABC addObject:countryArray[3]];
            [iso3166XXX addObject:countryArray[4]];
        }
        NSArray *iso3166=@[iso3166PAIS,iso3166COUNTRY,iso3166AB,iso3166ABC,iso3166XXX];
        //1.6 idtype
        NSDictionary *personIDType=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/personIDType.plist"]];
        if (!personIDType)
        {
            LOG_ERROR(@"no folder voc/personIDType.plist into deploy");
            return 1;
        }

#pragma mark -
        RS* httpdicomServer = [[RS alloc] init];
        
//-----------------------------------------------
        
#pragma mark wado application/dicom
//default handler
        
//does support transitive (to other PCS) operation
//does support distributive (to inner devices) operation
//does not support response consolidation (wado uri always return one object only)
        
        
// /wado
//?requestType=WADO
//&contentType=application/dicom
//&studyUID={studyUID}
//&seriesUID={seriesUID}
//&objectUID={objectUID}
        
//&pacs={pacsOID} (added, optional)
        
//alternative processing:
//(a) proxy custodian
//(b) local entity wado
//(c) local entity sql, filesystem
//(d) not available
        
        NSRegularExpression *wadouriRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/" options:NSRegularExpressionCaseInsensitive error:NULL];
        [httpdicomServer addHandler:@"GET" regex:wadouriRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
{
    NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

    //valid params syntax?
    NSString *wadoDicomQueryItemsError=[urlComponents wadoDicomQueryItemsError];
    if (wadoDicomQueryItemsError)
    {
#pragma mark any

        LOG_DEBUG(@"[any] Path: %@",urlComponents.path);
        LOG_DEBUG(@"[any] Query: %@",urlComponents.query);
        LOG_DEBUG(@"[any] Content-Type:\"%@\"",request.contentType);
        LOG_DEBUG(@"[any] Body: %@",[request.data description]);

        return [RSErrorResponse responseWithClientError:404 message:@"[any]<br/> unkwnown path y/o query:<br/>%@?%@",urlComponents.path,urlComponents.query];
    }

    //param pacs
    NSString *pacs=[urlComponents firstQueryItemNamed:@"pacs"];
    
    // (a) ningún pacs especificado
#pragma mark TODO reemplazar la lógica con qidos para encontrar el pacs, tanto local como remotamente. Se podría ordenar los qido por proximidad.... sql,qido,custodian
    
    if (!pacs)
    {
        LOG_VERBOSE(@"[wado] no param named \"pacs\" in: %@",urlComponents.query);
        //Find wado in any of the local device (recursive)
        for (NSString *oid in localOIDs)
        {
            NSData *wadoResp=[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%lld/%@?%@&pacs=%@", port, urlComponents.path, urlComponents.query, oid]]];
            if (wadoResp && [wadoResp length] > 512) return [RSDataResponse responseWithData:wadoResp contentType:@"application/dicom"];
        }
        return [RSErrorResponse responseWithClientError:404 message:@"[wado] not found locally: %@",urlComponents.query];
    }
    
    //find entityDict
    NSDictionary *entityDict=entitiesDicts[pacs];
    if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"[wado] pacs %@ not known]",pacs];
    
    //(b) sql+filesystem?
    NSString *filesystembaseuri=entityDict[@"filesystembaseuri"];
    NSString *sqlobjectmodel=entityDict[@"sqlobjectmodel"];
    
    if ([filesystembaseuri length] && [sqlobjectmodel length])
    {
#pragma mark TODO wado sql+filesystem
        return [RSErrorResponse responseWithClientError:404 message:@"%@ [wado] not available]",urlComponents.path];
    }

    //(c) wadolocaluri?
    if ([entityDict[@"wadolocaluri"] length])
    {
        NSString *uriString=[NSString stringWithFormat:@"%@?%@",
                             entityDict[@"wadolocaluri"],
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

#pragma mark TODO (d) DICOM c-get
    
#pragma mark TODO (e) DICOM c-move
    
    //(f) global?
    if ([entityDict[@"custodianglobaluri"] length])
    {
        NSString *uriString=[NSString stringWithFormat:@"%@?%@",
                             entityDict[@"custodianglobaluri"],
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
  return [RSErrorResponse responseWithClientError:404 message:@"[wado] pacs %@ not available",pacs];
  
}(request));}];
        
//-----------------------------------------------
        
#pragma mark mwlItem

        [httpdicomServer addHandler:@"POST" path:@"/mwlitem" processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
             {
                 //PARAMETROS OBLIGATORIOS
                 //pacs=2.16.858.2.212659800019.72769.217215590012
                 //aet=FCR-CSL-SCU
                 //Modality="CR" (fijo, indicando que se trata de radiografía)
                 //AccessionNumber= (<17 caracteres - identificador único de este estudio de este paciente en la historia clínica de BCBSU)
                 //StudyDescription= (formato: [código]^CPT)
                 //PatientName= (apellido1>apellido2^nombre1 nombre2   todo en mayusculas)
                 //PatientID= (cédula sin puntos, con guión antes del dígito verificador,  o nro pasaporte)
                 //PatientIDIssuer= (formato: 2.16.858.1.[ID país].[ID tipo de documento] ,  ver lista de los ID abajo)
                 //PatientBirthDate= (formato: aaaammdd)
                 //PatientSex= (M=masculino, F=feminino, O=no especificado)
                 //Priority=
                 // pdf= (dato médico u otras comunicaciones en el formato de documento indicado por el nombre del parámetro, codificado base64)
                 // msg= texto

                 //PARAMETROS OPCIONALES
                 
                 //Informing=
                 //Referring= (quien pidió el examen. Formato:   BCBSU^^Apellido (y eventualmente nombre)^especialidad)

                 
                 //data
                 NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
                 LOG_DEBUG(@"[mwlitem] Path: %@",urlComponents.path);
                 LOG_DEBUG(@"[mwlitem] Query: %@",urlComponents.query);
                 LOG_DEBUG(@"[mwlitem] Content-Type:\"%@\"",request.contentType);

                 //Allow
                 // Content-Type:"multipart/form-data" (form html5)
                 // Content-Type:"application/x-www-form-urlencoded" (easier to create in rest)
                 //create namesvalues {"names":[],"values":[]}
 
                 NSArray *names=nil;
                 NSArray *values=nil;
                 NSArray *types=nil;

                 if ([request.contentType hasPrefix:@"multipart/form-data"])
                 {
                     LOG_DEBUG(@"[mwlitem] Body: %@",[request.data description]);
                     [request.data writeToFile:@"/private/tmp/data" options:0 error:nil];
                     NSDictionary *components=[request.data parseNamesValuesTypesInBodySeparatedBy:[[request.contentType valueForName:@"boundary"]dataUsingEncoding:NSASCIIStringEncoding]];
                     LOG_VERBOSE(@"[mwlitem] request body parts: %@",[components description]);
                     names=components[@"names"];
                     values=components[@"values"];
                     types=components[@"types"];

                 }
                 else if ([request.contentType hasPrefix:@"application/x-www-form-urlencoded"])
                 {
                     NSLog(@"%@",[request description]);
                     names=[[request arguments]allKeys];
                     values=[[request arguments]allValues];
                 }
                 else
                     return [RSErrorResponse responseWithClientError:404 message:@"[[mwlitem] Content-Type:\"%@\" (should be either \"multipart/form-data\" or \"application/x-www-form-urlencoded\"",request.contentType];
                 
                 //verificar metadata
//pacs
                 NSUInteger pacsIndex=[names indexOfObject:@"pacs"];
                 if (pacsIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs required"];
                 NSString *pacs=values[pacsIndex];
                 if (![UIRegex numberOfMatchesInString:pacs options:0 range:NSMakeRange(0,[pacs length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' should be an OID",pacs];
                 NSDictionary *entityDict=entitiesDicts[pacs];
                 if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' not known",pacs];
                 NSString *mwlitemlocaluri=nil;
                 NSString *ormlocaluri=nil;
                 if (
                        entityDict[@"mwlitemlocaluri"]
                     && [entityDict[@"mwlitemlocaluri"] length])
                     mwlitemlocaluri=entityDict[@"mwlitemlocaluri"];
                 else if (
                             entityDict[@"ormlocaluri"]
                          && [entityDict[@"ormlocaluri"] length])
                          ormlocaluri=entityDict[@"ormlocaluri"];
                 else return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' doesn´t offer mwlitem or orm service",pacs];
                 
                 NSString *patientslocaluri=nil;
                 NSString *pidlocaluri=nil;
                 if (
                     entityDict[@"patientslocaluri"]
                     && [entityDict[@"patientslocaluri"] length])
                     patientslocaluri=entityDict[@"patientslocaluri"];
                 else if (
                          entityDict[@"pidlocaluri"]
                          && [entityDict[@"pidlocaluri"] length])
                     pidlocaluri=entityDict[@"pidlocaluri"];
                 else return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' doesn´t offer patients or pid service",pacs];

                 
                 NSString *stowjsonlocaluri=nil;
                 NSString *stowxmllocaluri=nil;
                 NSString *stowdicomlocaluri=nil;
                 NSString *cstore=nil;
                 if (
                     entityDict[@"stowjsonlocaluri"]
                     && [entityDict[@"stowjsonlocaluri"] length])
                     stowjsonlocaluri=entityDict[@"stowjsonlocaluri"];
                 else if (
                     entityDict[@"stowxmllocaluri"]
                     && [entityDict[@"stowxmllocaluri"] length])
                     stowxmllocaluri=entityDict[@"stowxmllocaluri"];
                 else if (
                          entityDict[@"stowdicomlocaluri"]
                          && [entityDict[@"stowdicomlocaluri"] length])
                     stowdicomlocaluri=entityDict[@"stowdicomlocaluri"];
                 else if (
                          entityDict[@"cstore"]
                          && [entityDict[@"cstore"]boolValue])
                     cstore=entityDict[@"cstore"];
                 else return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' doesn´t offer stow or store service",pacs];

//aet
                 NSUInteger aetIndex=[names indexOfObject:@"aet"];
                 NSString *aet=nil;
                 if (aetIndex!=NSNotFound) aet=values[aetIndex];

//Modality
                 NSUInteger ModalityIndex=[names indexOfObject:@"Modality"];
                 if (ModalityIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] Modality required"];
                 NSString *Modality=values[ModalityIndex];
                 if ([@[@"CR",@"CT",@"MR",@"PT",@"XA",@"US",@"MG"] indexOfObject:Modality]==NSNotFound)  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] Modality '%@', should be one of CR,CT,MR,PT,XA,US,MG",Modality];
                 
//AccessionNumber
                 NSUInteger AccessionNumberIndex=[names indexOfObject:@"AccessionNumber"];
                 if (AccessionNumberIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber required"];
                 NSString *AccessionNumber=values[AccessionNumberIndex];

                 if (![SHRegex numberOfMatchesInString:AccessionNumber options:0 range:NSMakeRange(0,[values[AccessionNumberIndex] length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
                 
                 //Already exists in the PACS?
                 if (mwlitemlocaluri)
                 {
                     NSData *AccessionNumberUnique=[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?AccessionNumber=%@",mwlitemlocaluri,AccessionNumber]]];
                     if (   AccessionNumberUnique
                         &&[AccessionNumberUnique length])
                     {
                         NSError *error=nil;
                         NSArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:AccessionNumberUnique options:0 error:&error];
                         if (
                                !error
                              && [arrayOfDicts count]
                             ) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber '%@' already exists in pacs '%@'",AccessionNumber,pacs];
                     }
                         
                         
                 }

//StudyDescription
                 NSUInteger StudyDescriptionIndex=[names indexOfObject:@"StudyDescription"];
                 if (StudyDescriptionIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] StudyDescription required"];
                 NSString *StudyDescription=values[StudyDescriptionIndex];
#define PROCCODE 0
#define PROCSCHEME 1
#define PROCMEANING 2
                 NSArray *StudyDescriptionArray=[StudyDescription componentsSeparatedByString:@"^"];
                 if ([StudyDescriptionArray count]!=3) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] StudyDescription format should be code^systemShortcut^[optional description]"];
                 
                 NSDictionary *StudyDescriptionSystem=[codeDict objectForKey:StudyDescriptionArray[1]];
                 if (!StudyDescriptionSystem) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] code system '%@' not known", StudyDescriptionArray[1]];
                 NSDictionary *StudyDescriptionCode=[StudyDescriptionSystem objectForKey:StudyDescriptionArray[0]];
                 if (!StudyDescriptionCode) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] code '%@' of code system '%@' not known",StudyDescriptionArray[0], StudyDescriptionArray[1]];
                 
                 
//PatientName
                 NSMutableString *PatientName=[NSMutableString string];

                 NSUInteger apellido1Index=[names indexOfObject:@"apellido1"];
                 if (apellido1Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'apellido1' required"];
                 NSString *apellido1String=[values[apellido1Index] uppercaseString];
                 [PatientName appendString:apellido1String];
                 
                 NSUInteger apellido2Index=[names indexOfObject:@"apellido2"];
                 NSString *apellido2String=[values[apellido2Index] uppercaseString];
                 if (apellido2Index!=NSNotFound) [PatientName appendFormat:@">%@",apellido2String];
                 
                 NSUInteger nombresIndex=[names indexOfObject:@"nombres"];
                 NSString *nombresString=[values[nombresIndex] uppercaseString];

                 if (nombresIndex!=NSNotFound) [PatientName appendFormat:@"^%@",nombresString];

//PatientID
                 NSUInteger IDCountryIndex=[names indexOfObject:@"PatientIDCountry"];
                 if (IDCountryIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientIDCountry' required"];
                 
                 NSString *IDCountryValue=[values[IDCountryIndex] uppercaseString];
                 
                 NSUInteger iso3166Index=NSNotFound;
                 iso3166Index=[iso3166[PAIS] indexOfObject:IDCountryValue];
                 if (iso3166Index==NSNotFound)
                 {
                     iso3166Index=[iso3166[COUNTRY] indexOfObject:IDCountryValue];
                     if (iso3166Index==NSNotFound)
                     {
                         iso3166Index=[iso3166[AB] indexOfObject:IDCountryValue];
                         if (iso3166Index==NSNotFound)
                         {
                             iso3166Index=[iso3166[ABC] indexOfObject:IDCountryValue];
                             if (iso3166Index==NSNotFound)
                             {
                                 iso3166Index=[iso3166[XXX] indexOfObject:IDCountryValue];
                                 if (iso3166Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientID Country '%@' not valid",IDCountryValue];
                             }
                         }
                     }
                 }


                 NSUInteger PatientIDTypeIndex=[names indexOfObject:@"PatientIDType"];
                 if (PatientIDTypeIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientIDType' required"];
                 if ([[personIDType allKeys] indexOfObject:values[PatientIDTypeIndex]]==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientIDType '%@' unknown",values[PatientIDTypeIndex]];

                 NSString *IssuerOfPatientID=[NSString stringWithFormat:@"2.16.858.1.%@.%@",(iso3166[XXX])[iso3166Index],values[PatientIDTypeIndex]];
                 
                 NSUInteger PatientIDIndex=[names indexOfObject:@"PatientID"];
                 if (PatientIDIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientID' required"];
                 NSString *PatientID=values[PatientIDIndex];
                 if (![SHRegex numberOfMatchesInString:values[PatientIDIndex] options:0 range:NSMakeRange(0,[PatientID length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientID should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
                 

//PatientBirthDate
                 NSUInteger PatientBirthDateIndex=[names indexOfObject:@"PatientBirthDate"];
                 if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientBirthDate' required"];
                 NSString *PatientBirthdate=values[PatientBirthDateIndex];
                 if (![DARegex numberOfMatchesInString:PatientBirthdate options:0 range:NSMakeRange(0,[values[PatientBirthDateIndex] length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientBirthDate format should be aaaammdd"];

//PatientSex
                 NSUInteger PatientSexIndex=[names indexOfObject:@"PatientSex"];
                 if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientSex' required"];
                 NSString *PatientSexValue=[values[PatientSexIndex]uppercaseString];
                 NSUInteger PatientSexSaluduyIndex=0;
                 if ([PatientSexValue isEqualToString:@"M"])PatientSexSaluduyIndex=1;
                 else if ([PatientSexValue isEqualToString:@"F"])PatientSexSaluduyIndex=2;
                 else if ([PatientSexValue isEqualToString:@"O"])PatientSexSaluduyIndex=9;
                 else  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientSex should be 'M','F' or 'O'"];

#pragma mark TODO Already exists in the PACS? Is coherent with patients found?

//pid already exists in the PACS?
                 NSArray *pidInPacs=nil;
                 if (patientslocaluri)
                 {
                     //GET
                     NSString *pidInPacsURLString=[NSString stringWithFormat:@"%@?PatientID=%@&IssuerOfPatientID=%@",patientslocaluri,PatientID,IssuerOfPatientID];
                     NSData *pidInPacsResponseData=[NSData dataWithContentsOfURL:[NSURL URLWithString:pidInPacsURLString]];
                     if (   pidInPacsResponseData
                         &&[pidInPacsResponseData length])
                     {
                         NSError *error=nil;
                         pidInPacs=[NSJSONSerialization JSONObjectWithData:pidInPacsResponseData options:0 error:&error];
                         if (error) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] bad answer of service patient of pacs '%@'",pacs];
                     }
                 }
                 if (!pidInPacs || [pidInPacs count]==0)
                 {
                     //create patient
                     NSString *URLString=[NSString stringWithFormat:@"%@/%@%%5E%%5E%%5E%@",
                                          patientslocaluri,
                                          PatientID,IssuerOfPatientID
                                          ];
                     NSMutableURLRequest *PUTpatientRequest=
                     [NSMutableURLRequest
                        PUTpatient:URLString
                        name:PatientName
                        pid:PatientID
                        issuer:IssuerOfPatientID
                        birthdate:(NSString *)PatientBirthdate
                        sex:PatientSexValue
                        contentType:@"application/json"
                        timeout:timeout
                      ];
                     LOG_VERBOSE(@"%@",[PUTpatientRequest URL]);
                     LOG_VERBOSE(@"%@ %@",[PUTpatientRequest HTTPMethod],[[PUTpatientRequest allHTTPHeaderFields]description]);
                     LOG_VERBOSE(@"%@",[[NSString alloc] initWithData:[PUTpatientRequest HTTPBody] encoding:NSUTF8StringEncoding]);
                     
                     NSHTTPURLResponse *PUTpatientResponse=nil;
                     //URL properties: expectedContentLength, MIMEType, textEncodingName
                     //HTTP properties: statusCode, allHeaderFields
                     NSError *error=nil;
                     //NSData *patientResponseData=[NSURLConnection sendSynchronousRequest:PUTpatientRequest returningResponse:&PUTpatientResponse error:&error];
                     NSData *patientResponseData=[NSURLSessionDataTask sendSynchronousRequest:PUTpatientRequest returningResponse:&PUTpatientResponse error:&error];
                     NSString *patientResponseString=[[NSString alloc]initWithData:patientResponseData encoding:NSUTF8StringEncoding];
                     LOG_INFO(@"[mwlitem] PUT new patient at %@",URLString);
                     if ( error || PUTpatientResponse.statusCode>299)
                     {
                         LOG_ERROR(@"[mwlitem] can not PUT patient %@. Error: %@ body:%@",PatientName,[error description], patientResponseString);
                         return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not PUT patient %@. Error: %@ body:%@",PatientName,[error description], patientResponseString];
                     }
                     LOG_VERBOSE(@"[mwlitem] %@",[PUTpatientResponse description]);
                 }

//now
                 NSDate *now=[NSDate date];
                 
//Priority
                 NSString *Priority=nil;
                 if ([[values[[names indexOfObject:@"Priority"]] uppercaseString] isEqualToString:@"URGENT"])Priority=@"URGENT";
                 else Priority=@"MEDIUM";

                 
                 
//create mwlitem
                 NSMutableURLRequest *POSTmwlitemRequest=
                 [NSMutableURLRequest
                  POSTmwlitem:mwlitemlocaluri
                  CS:@"ISO_IR 192"
                  aet:aet
                  DA:[DICMTypes DAStringFromDate:now]
                  TM:[DICMTypes TMStringFromDate:now]
                  TZ:@"-0300"
                  modality:Modality
                  accessionNumber:AccessionNumber
                  status:@"ARRIVED"
                  procCode:StudyDescriptionArray[PROCCODE]
                  procScheme:StudyDescriptionArray[PROCSCHEME]
                  procMeaning:StudyDescriptionArray[PROCMEANING]
                  priority:Priority
                  name:PatientName
                  pid:PatientID
                  issuer:IssuerOfPatientID
                  birthdate:(NSString *)PatientBirthdate
                  sex:PatientSexValue
                  contentType:@"application/json"
                  timeout:timeout
                  ];
                 LOG_VERBOSE(@"%@",[POSTmwlitemRequest URL]);
                 LOG_VERBOSE(@"%@ %@",[POSTmwlitemRequest HTTPMethod],[[POSTmwlitemRequest allHTTPHeaderFields]description]);
                 LOG_VERBOSE(@"%@",[[NSString alloc] initWithData:[POSTmwlitemRequest HTTPBody] encoding:NSUTF8StringEncoding]);

                 NSHTTPURLResponse *POSTmwlitemResponse=nil;
                 //URL properties: expectedContentLength, MIMEType, textEncodingName
                 //HTTP properties: statusCode, allHeaderFields
                 NSError *error=nil;
                 
                 NSData *mwlitemResponseData=[NSURLSessionDataTask sendSynchronousRequest:POSTmwlitemRequest returningResponse:&POSTmwlitemResponse error:&error];
                 NSString *mwlitemResponseString=[[NSString alloc]initWithData:mwlitemResponseData encoding:NSUTF8StringEncoding];
                 LOG_INFO(@"[mwlitem] POST new mwlitem at %@",mwlitemlocaluri);

                 if (error || POSTmwlitemResponse.statusCode>299)
                 {
                     LOG_ERROR(@"[mwlitem] can not POST mwlitem for patient: %@. Error: %@ body:%@",PatientName,[error description], mwlitemResponseString);
                     return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not POST mwlitem for patient: %@. Error: %@ body:%@",PatientName,[error description], mwlitemResponseString];
                 }
                 LOG_VERBOSE(@"[mwlitem] %@",[POSTmwlitemResponse description]);

                 NSMutableString* html = [NSMutableString stringWithString:@"<html><body>"];
                 [html appendFormat:@"<p>mwlitem sent to %@</p>",mwlitemlocaluri];
                 
                 if (stowdicomlocaluri)
                 {

                     //dscd object
                     NSMutableString *dscd=[NSMutableString string];
                     [dscd appendDSCDprefix];
                     
                     [dscd appendSCDprefix];
                     [dscd appendCDAprefix];
                     
                     unsigned long long organizationId;
                     NSUInteger organizationIdIndex=[names indexOfObject:@"organizationId"];
                     if (organizationIdIndex==NSNotFound) organizationId=214462250019;//BCBSU
                     else organizationId=(unsigned long long)[values[organizationIdIndex]longLongValue];
                     
                     unsigned long long manufacturerId;
                     NSUInteger manufacturerIdIndex=[names indexOfObject:@"manufacturerId"];
                     if (manufacturerIdIndex==NSNotFound) manufacturerId=217215590012;//Opendicom
                     else manufacturerId=(unsigned long long)[values[manufacturerIdIndex]longLongValue];

                     [dscd appendCdaOntoWithTitle:StudyDescriptionArray[PROCMEANING]
                                   OrganizationId:organizationId
                                        timestamp:now
                                      incremental:1
                                   manufacturerId:manufacturerId];
                     
                     [dscd appendCdaRecordTargetWithPid:PatientID
                                                 issuer:IssuerOfPatientID
                                              apellido1:apellido1String
                                              apellido2:apellido2String
                                                nombres:nombresString
                                                    sex:PatientSexValue
                                              birthdate:PatientBirthdate];
#pragma mark TODO custodian...
                     [dscd appendCdaCustodianOid:@"2.16.858.0.2.16.86.9.0.0.2.214462250019"
                                            name:@"BCBSU"];
                     
                     [dscd appendCdaRequestFrom:@"BCBSU"
                                         issuer:@"2.16.858.0.2.16.86.9.0.0.2.214462250019"
                                accessionNumber:AccessionNumber
                                       studyUID:AccessionNumber
                                           code:(NSString*)StudyDescriptionArray[PROCCODE]
                                         system:(NSString*)StudyDescriptionArray[PROCSCHEME]
                                        display:(NSString*)StudyDescriptionArray[PROCMEANING]
                                       datetime:(NSString*)[[DICMTypes DAStringFromDate:now]
                                             stringByAppendingString:[DICMTypes TMStringFromDate:now]]];
                     
                     [dscd appendComponentofWithSnomedCode:@"371527006"
                                             snomedDisplay:@"informe radiológico (elemento de registro)"
                                                     lowDA:[DICMTypes DAStringFromDate:now]
                                                    highDA:[DICMTypes DAStringFromDate:now]
                                               serviceCode:@"310125001"
                                               serviceName:@"BCBSU CR PUNTA DEL ESTE"];
                     
                     NSString *enclosure=values[[names indexOfObject:@"enclosure"]];
                     
                     if ([enclosure isEqualToString:@"pdf"])
                     {
                         NSString *enclosurePdf=values[[names indexOfObject:@"enclosurePdf"]];
                         if  (enclosurePdf && [enclosurePdf length]) [dscd appendUrlComponentWithPdf:enclosurePdf];
                         else [dscd appendEmptyComponent];
                     }
                     else if ([enclosure isEqualToString:@"textarea"])
                     {
                         NSString *enclosureTextarea=values[[names indexOfObject:@"enclosureTextarea"]];
                        if  (enclosureTextarea && [enclosureTextarea length])
                            [dscd appendTextComponent:enclosureTextarea];
                        else
                            [dscd appendEmptyComponent];
                     }
                     else [dscd appendEmptyComponent];

                     [dscd appendCDAsuffix];
                     [dscd appendSCDsuffix];
                     [dscd appendDSCDsuffix];

                     //create dscd headers
                     
                     
                     //dicom object
                     NSMutableURLRequest *POSTenclosedRequest=
                     [NSMutableURLRequest
                      POSTenclosed:stowdicomlocaluri
                      CS:@"ISO_IR 192"
                      aet:aet
                      DA:[DICMTypes DAStringFromDate:now]
                      TM:[DICMTypes TMStringFromDate:now]
                      TZ:@"-0300" 
                      modality:@"OT"
                      accessionNumber:AccessionNumber
                      status:@"ARRIVED"
                      procCode:StudyDescriptionArray[PROCCODE]
                      procScheme:StudyDescriptionArray[PROCSCHEME]
                      procMeaning:StudyDescriptionArray[PROCMEANING]
                      priority:Priority
                      name:PatientName
                      pid:PatientID
                      issuer:IssuerOfPatientID
                      birthdate:(NSString *)PatientBirthdate
                      sex:PatientSexValue
                      instanceUID:[[NSUUID UUID]ITUTX667UIDString]
                      seriesUID:[[NSUUID UUID]ITUTX667UIDString]
                      studyUID:AccessionNumber
                      seriesNumber:@"-32"
                      seriesDescription:@"Solicitud de informe imagenológico"
                      enclosureHL7II:@""
                      enclosureTitle:@"Solicitud de informe imagenológico"
                      enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
                      enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
                      contentType:@"application/dicom"
                      timeout:timeout
                      ];
                     
                     
                     //qido post stow
                     [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?AccessionNumber=%@",mwlitemlocaluri,AccessionNumber]]];

                     LOG_VERBOSE(@"%@",[POSTenclosedRequest URL]);
                     LOG_VERBOSE(@"%@ %@",[POSTenclosedRequest HTTPMethod],[[POSTenclosedRequest allHTTPHeaderFields]description]);
                     LOG_VERBOSE(@"%@",[[NSString alloc] initWithData:[POSTenclosedRequest HTTPBody] encoding:NSUTF8StringEncoding]);
                     
                     NSHTTPURLResponse *POSTenclosedResponse=nil;
                     //URL properties: expectedContentLength, MIMEType, textEncodingName
                     //HTTP properties: statusCode, allHeaderFields
                     NSError *error=nil;

                     NSData *POSTenclosedResponseData=[NSURLConnection sendSynchronousRequest:POSTenclosedRequest returningResponse:&POSTenclosedResponse error:&error];
                     
                     NSString *POSTenclosedResponseString=[[NSString alloc]initWithData:POSTenclosedResponseData encoding:NSUTF8StringEncoding];
                     LOG_INFO(@"[mwlitem] POSTenclosedCDA at %@",stowdicomlocaluri);
                     
                     if (error || POSTenclosedResponse.statusCode>299)
                     {

                     
                      //Failure
                      //=======
                      //400 - Bad Request (bad syntax)
                      //401 - Unauthorized
                      //403 - Forbidden (insufficient priviledges)
                      //409 - Conflict (formed correctly - system unable to store due to a conclict in the request
                      //(e.g., unsupported SOP Class or StudyInstance UID mismatch)
                      //additional information can be found in teh xml response body
                      //415 - unsopported media type (e.g. not supporting JSON)
                      //500 (instance already exists in db - delete file)
                      //503 - Busy (out of resource)
                      
                      //Warning
                      //=======
                      //202 - Accepted (stored some - not all)
                      //additional information can be found in teh xml response body
                      
                      //Success
                      //=======
                      //200 - OK (successfully stored all the instances)


                         LOG_ERROR(@"[mwlitem] can not POST CDA for patient: %@. Error: %@ body:%@",PatientName,[error description], POSTenclosedResponseString);
                         return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not POST CDA for patient: %@. Error: %@ body:%@",PatientName,[error description], POSTenclosedResponseString];
                     }
                     
                     
                     
                     LOG_VERBOSE(@"[mwlitem] %@",[POSTenclosedResponse description]);
                     [html appendFormat:@"<p>solicitud dicom cda sent to %@</p>",stowdicomlocaluri];

                      /*
                     [html appendString:@"<dl>"];
                     for (int i=0; i < [names count]; i++)
                     {
                         [html appendFormat:@"<dt>%@</dt>",names[i]];
                         if (  !types
                             ||![types[i] length]
                             || [types[i] hasPrefix:@"text"]
                             || [types[i] hasPrefix:@"application/json"]
                             || [types[i] hasPrefix:@"application/dicom+json"]
                             || [types[i] hasPrefix:@"application/xml"]
                             || [types[i] hasPrefix:@"application/xml+json"]
                             )[html appendFormat:@"<dd>%@</dd>",values[i]];
                         else
                         {
                             [html appendString:@"<dd>"];
                             [html appendFormat:@"<embed src=\"data:%@;base64,%@\" width=\"500\" height=\"375\" type=\"%@\">",types[i],values[i],types[i] ];
                             [html appendString:@"</dd>"];
                         }
                       
                     }
                     [html appendString:@"</dl>"];*/
                 }
                 [html appendString:@"</body></html>"];
                 
                 return [RSDataResponse responseWithHTML:html];

                 

             }(request));}];

        
        
#pragma mark echo
        [httpdicomServer addHandler:@"GET" path:@"/echo" processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock)
         {completionBlock(^RSResponse* (RSRequest* request){
            return [RSDataResponse responseWithText:[NSString stringWithFormat:@"[echo] your IP:port is %@", request.remoteAddressString]];
        }(request));}];

        
//-----------------------------------------------
        

#pragma mark custodians
        NSRegularExpression *custodiansRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/custodians/.*$" options:0 error:NULL];
        [httpdicomServer addHandler:@"GET" regex:custodiansRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock)
         {completionBlock(^RSResponse* (RSRequest* request){

            //using NSURLComponents instead of RSRequest
            NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

            NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
            NSUInteger pCount=[pComponents count];
             
            if (pCount<3) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];
             
             if ([pComponents[2]isEqualToString:@"titles"])
             {
                 //custodians/titles
                 if (pCount==3) return [RSDataResponse responseWithData:custodianTitlesData contentType:@"application/json"];
                 
                 NSUInteger p3Length = [pComponents[3] length];
                 if (  (p3Length>16)
                     ||![SHRegex numberOfMatchesInString:pComponents[3] options:0 range:NSMakeRange(0,p3Length)])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} datatype should be DICOM SH]",urlComponents.path];
                 
                 if (!custodiantitles[pComponents[3]])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} not found]",urlComponents.path];
                 
                 //custodians/titles/{TITLE}
                 if (pCount==4) return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:custodiantitles[pComponents[3]]] options:0 error:nil] contentType:@"application/json"];
                 
                 if (![pComponents[4]isEqualToString:@"aets"])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} unique resource is 'aets']",urlComponents.path];
                 
                 //custodians/titles/{title}/aets
                 if (pCount==5)
                     return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[custodianTitlesaets objectForKey:pComponents[3]] options:0 error:nil] contentType:@"application/json"];

                 NSUInteger p5Length = [pComponents[5]length];
                 if (  (p5Length>16)
                     ||![SHRegex numberOfMatchesInString:pComponents[5] options:0 range:NSMakeRange(0,p5Length)])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aet}datatype should be DICOM SH]",urlComponents.path];
                 
                 NSUInteger aetIndex=[[custodianTitlesaets objectForKey:pComponents[3]] indexOfObject:pComponents[5]];
                 if (aetIndex==NSNotFound)
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aet} not found]",urlComponents.path];

                 if (pCount>6) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];

                 //custodians/titles/{title}/aets/{aet}
                     return [RSDataResponse responseWithData:
                             [NSJSONSerialization dataWithJSONObject:
                              [NSArray arrayWithObject:(custodianOIDsaeis[custodiantitles[pComponents[3]]])[aetIndex]]
                              options:0
                              error:nil
                             ]
                             contentType:@"application/json"
                            ];
             }
             
             
             if ([pComponents[2]isEqualToString:@"oids"])
             {
                 //custodians/oids
                 if (pCount==3) return [RSDataResponse responseWithData:custodianOIDsData contentType:@"application/json"];
                 
                 NSUInteger p3Length = [pComponents[3] length];
                 if (  (p3Length>64)
                     ||![UIRegex numberOfMatchesInString:pComponents[3] options:0 range:NSMakeRange(0,p3Length)]
                     )
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} datatype should be DICOM UI]",urlComponents.path];
                 
                 if (!custodianoids[pComponents[3]])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} not found]",urlComponents.path];
                 
                 //custodian/oids/{OID}
                 if (pCount==4) return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:custodianoids[pComponents[3]]] options:0 error:nil] contentType:@"application/json"];
                 
                 if (![pComponents[4]isEqualToString:@"aeis"])
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} unique resource is 'aeis']",urlComponents.path];
                 
                 //custodian/oids/{OID}/aeis
                 if (pCount==5)
                     return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[custodianOIDsaeis objectForKey:pComponents[3]] options:0 error:nil] contentType:@"application/json"];
                 
                 NSUInteger p5Length = [pComponents[5]length];
                 if (  (p5Length>64)
                     ||![UIRegex numberOfMatchesInString:pComponents[5] options:0 range:NSMakeRange(0,p5Length)]
                     )
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aei}datatype should be DICOM UI]",urlComponents.path];
                 
                 NSUInteger aeiIndex=[[custodianOIDsaeis objectForKey:pComponents[3]] indexOfObject:pComponents[5]];
                 if (aeiIndex==NSNotFound)
                     return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aei} not found]",urlComponents.path];
                 
                 if (pCount>6) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];
                 
                 //custodian/oids/{OID}/aeis/{aei}
                 return [RSDataResponse responseWithData:
                         [NSJSONSerialization dataWithJSONObject:
                          [NSArray arrayWithObject:(entitiesDicts[pComponents[5]])[@"dicomaet"]]
                                                         options:0
                                                           error:nil
                          ]
                                                       contentType:@"application/json"
                         ];
             }
             return [RSErrorResponse responseWithClientError:404 message:@"%@ [no handler]",urlComponents.path];

        }(request));}];

        
//-----------------------------------------------

        
#pragma mark QIDO
        // /(studies|series|instances)
        // &pacs={oid}
        
        NSRegularExpression *qidoRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/(studies|series|instances)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        [httpdicomServer addHandler:@"GET" regex:qidoRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             //use it to tag DEBUG logs
             LOG_DEBUG(@"[qido] client: %@",request.remoteAddressString);

             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             
             if ([urlComponents.queryItems count] < 1)
                 return [RSErrorResponse responseWithClientError:404
                                                         message:@"[qido] requires at least one filter in: %@",[request.URL absoluteString]];
             
             //valid params syntax?
             //NSString *qidoQueryItemsError=[urlComponents qidoQueryItemsError:(*)];
             //if (qidoQueryItemsError) return [RSErrorResponse responseWithClientError:404 message:@"[qido] query item %@ error in: %@",qidoQueryItemsError,urlComponents.query];

             //param pacs
             NSString *pacs=[urlComponents firstQueryItemNamed:@"pacs"];
             
             // (a) any local pacs
             if (!pacs)
             {
                 LOG_VERBOSE(@"[qido] no param named \"pacs\" in: %@",urlComponents.query);
                 //Find qido in any of the local device (recursive)
                 for (NSString *oid in localOIDs)
                 {
#pragma mark TODO wado any local
                 }

             }

             //find entityDict
             NSDictionary *entityDict=entitiesDicts[pacs];
             if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"[qido] pacs %@ not known]",pacs];


             
             //(b) sql available
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (sqlobjectmodel)
             {
                 //create where
                 NSUInteger level=[qidoLastPathComponent indexOfObject:urlComponents.path];
                 NSMutableString *whereString = [NSMutableString string];
                 switch (level) {
                     case 1:
                         [whereString appendFormat:@" %@ ",(sqlobjectmodel[@"where"])[@"study"]];
                         break;
                     case 2:
                         [whereString appendFormat:@" %@ ",(sqlobjectmodel[@"where"])[@"series"]];
                         break;
                     case 3:
                         [whereString appendFormat:@" %@ ",(sqlobjectmodel[@"where"])[@"instance"]];
                         break;
                     default:
                         return [RSErrorResponse responseWithClientError:404 message:@"level %@ not accepted. Should be study, series or instance",urlComponents.path];
                         break;
                 }
                 
                 for (NSURLQueryItem *qi in urlComponents.queryItems)
                 {
                     NSString *key=qidotag[@"qi.name"];
                     if (!key) key=@"qi.name";

                     NSDictionary *keyProperties=nil;
                     if (key) keyProperties=qidokey[key];
                     if (!keyProperties) return [RSErrorResponse responseWithClientError:404 message:@"%@ [not a valid qido filter for this PACS]",qi.name];
                     
                     //level check
                     if ( level < [keyProperties[@"level"] unsignedIntegerValue]) return [RSErrorResponse responseWithClientError:404 message:@"%@ [not available at level %@]",key,urlComponents.path];
                     
                     //string compare
                     if ([@[@"LO",@"PN",@"CS",@"UI"] indexOfObject:keyProperties[@"vr"]]!=NSNotFound)
                     {
                         [whereString appendString:
                          [NSString mysqlEscapedFormat:@" AND %@ like '%@'"
                                           fieldString:(sqlobjectmodel[@"attribute"])[key]
                                           valueString:qi.value
                           ]
                          ];
                         continue;
                     }
                     
                     
                     //date compare
                     if ([@[@"DA"] indexOfObject:keyProperties[@"vr"]]!=NSNotFound)
                     {
                         NSArray *startEnd=[qi.value componentsSeparatedByString:@"-"];
                         switch ([startEnd count]) {
                             case 1:;
                                 [whereString appendString:
                                  [
                                   (sqlobjectmodel[@"attribute"])[key]
                                        sqlFilterWithStart:startEnd[0]
                                        end:startEnd[0]
                                   ]
                                  ];
                             break;
                             case 2:;
                                 [whereString appendString:
                                  [
                                   (sqlobjectmodel[@"attribute"])[key]
                                        sqlFilterWithStart:startEnd[0]
                                        end:startEnd[1]
                                   ]
                                  ];
                             break;
                         }
                         continue;
                     }
                     
                 }//end loop
                 
                 //join parts of sql select
                 NSString *sqlScriptString=nil;
                 NSMutableString *select=[NSMutableString stringWithString:@" SELECT "];
                 switch (level) {
                     case 1:;
                         for (NSString* key in qido[@"studyselect"])
                         {
                             [select appendFormat:@"%@,",(sqlobjectmodel[@"attribute"])[key]];
                         }
                         [select deleteCharactersInRange:NSMakeRange([select length]-1,1)];
                         sqlScriptString=[NSString stringWithFormat:@"%@%@%@%@%@",
                                          entityDict[@"sqlprolog"],
                                          select,
                                          (sqlobjectmodel[@"from"])[@"studypatient"],
                                          whereString,
                                          qido[@"studyformat"]
                                          ];
                         break;
                     case 2:;
                         for (NSString* key in qido[@"seriesselect"])
                         {
                             [select appendFormat:@"%@,",(sqlobjectmodel[@"attribute"])[key]];
                         }
                         [select deleteCharactersInRange:NSMakeRange([select length]-1,1)];

                         sqlScriptString=[NSString stringWithFormat:@"%@%@%@%@%@",
                                          entityDict[@"sqlprolog"],
                                          select,
                                          (sqlobjectmodel[@"from"])[@"seriesstudypatient"],
                                          whereString,
                                          qido[@"seriesformat"]
                                          ];
                         break;
                     case 3:;
                         for (NSString* key in qido[@"instanceselect"])
                         {
                             [select appendFormat:@"%@,",(sqlobjectmodel[@"attribute"])[key]];
                         }
                         [select deleteCharactersInRange:NSMakeRange([select length]-1,1)];
                         sqlScriptString=[NSString stringWithFormat:@"%@%@%@%@%@",
                                          entityDict[@"sqlprolog"],
                                          select,
                                          (sqlobjectmodel[@"from"])[@"instansceseriesstudypatient"],
                                          whereString,
                                          qido[@"instanceformat"]
                                          ];
                         break;
                 }
                 LOG_DEBUG(@"%@",sqlScriptString);

                 
                 //execute sql select
                 NSMutableData *mutableData=[NSMutableData data];
                 if (!task(@"/bin/bash",@[@"-s"],[sqlScriptString dataUsingEncoding:NSUTF8StringEncoding],mutableData))
                     [RSErrorResponse responseWithClientError:404 message:@"%@",@"can not execute the sql"];//NotFound
                 
                 //response can be almost empty
                 //in this case we remove lost ']'
                 if ([mutableData length]<10) return [RSDataResponse responseWithData:emptyJsonArray contentType:@"application/json"];

                 //db response may be in latin1
                 NSStringEncoding charset=(NSStringEncoding)[entityDict[@"sqlstringencoding"] longLongValue ];
                 if (charset!=4 && charset!=5) return [RSErrorResponse responseWithClientError:404 message:@"unknown sql charset : %lu",(unsigned long)charset];
                 
                 if (charset==5) //latin1
                 {
                     NSString *latin1String=[[NSString alloc]initWithData:mutableData encoding:NSISOLatin1StringEncoding];
                     [mutableData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
                 }
                 
                 NSError *error=nil;
                 NSMutableArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:mutableData options:0 error:&error];
                 if (error) return [RSErrorResponse responseWithClientError:404 message:@"bad qido sql result : %@",[error description]];
                 
                 //formato JSON qido
                 NSMutableArray *qidoResponseArray=[NSMutableArray array];
                 for (NSDictionary *dict in arrayOfDicts)
                 {
                     NSMutableDictionary *object=[NSMutableDictionary dictionary];
                     for (NSString *key in dict)
                     {
                         NSDictionary *attrDesc=qidokey[key];
                         NSMutableDictionary *attrInst=[NSMutableDictionary dictionary];
                         if ([attrDesc[@"vr"] isEqualToString:@"PN"])
                             [attrInst setObject:@[@{@"Alphabetic":dict[key]}] forKey:@"Value"];
                         else if ([attrDesc[@"vr"] isEqualToString:@"DA"]) [attrInst setObject:@[[dict[key] dcmDaFromDate]] forKey:@"Value"];
                         else [attrInst setObject:@[dict[key]] forKey:@"Value"];
                         //TODO add other cases, like TM, DT, etc...
                         
                         [attrInst setObject:attrDesc[@"vr"] forKey:@"vr"];
                         [object setObject:attrInst forKey:attrDesc[@"tag"]];
                     }
                     [qidoResponseArray addObject:object];
                 }
                 return [RSDataResponse responseWithData:
                         [NSJSONSerialization dataWithJSONObject:qidoResponseArray options:0 error:nil] contentType:@"application/json"];
             }
             
             //(c) qidolocaluri?
             if ([entityDict[@"qidolocaluri"] length])
             {
                 NSString *qidolocaluriLevel=[entityDict[@"qidolocaluri"] stringByAppendingString:urlComponents.path];
             }

             
             
             /*
             NSString *qidoLocalString=entityDict[@"qidolocaluri"];
             if ([qidoLocalString length]>0)
             {
                 return qidoUrlProxy(
              
                    [NSString stringWithFormat:@"%@/%@",qidoBaseString,pComponents.lastObject],
                    =qidolocaluri + urlComponents.path
                    ==qidoString
                    ===pacsUri
              
              
                    urlComponents.query,
                    =urlComponents.query
                    ==queryString
              
              
                    [custodianbaseuri stringByAppendingString:urlComponents.path]
                    =custodianglobaluri + urlComponents.path
                    ==httpdicomString
                    ===httpDicomUri
                    );
                 //pComponents.lastObject = ( studies | series | instances )
                 //application/dicom+json not accepted
             }
*/
             
             //(d) global?
             if ([entityDict[@"custodianglobaluri"] length])
             {
#pragma mark TODO qido global proxying
                 
             }
             
             
             //(e) not available
             return [RSErrorResponse responseWithClientError:404 message:@"[qido] pacs %@ not available",pacs];

         }(request));}];
        
        
//-----------------------------------------------

        
#pragma mark wadors multipart/related;type=application/dicom
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
             NSDictionary *entityDict=entitiesDicts[pacs];
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

        
        
//-----------------------------------------------

#pragma mark dcm.zip
        // dcm.zip?StudyInstanceUID={UID}
        // pacs={oid}
        // option AccessionNumber, StudyInstanceUID, SeriesInstanceUID
        
        // servicio de segundo nivel que llama a filesystembaseuri, wadouri o wadors para su realización
        
        
        NSRegularExpression *dcmzipRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/pacs\\/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*\\/dcm\\.zip\\?\(StudyInstanceUID|SeriesInstanceUID|AccessionNumber)=[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*$" options:NSRegularExpressionCaseInsensitive error:NULL];
        [httpdicomServer addHandler:@"GET" regex:dcmzipRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
        {
            //LOG_DEBUG(@"client: %@",request.remoteAddressString);
            
            //using NSURLComponents instead of RSRequest
            NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
            NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];

            NSDictionary *entityDict=entitiesDicts[pComponents[2]];
            if (!entityDict) return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} not found]",urlComponents.path];

            //using sql
            NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
            if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs sql} not accessible]",urlComponents.path];
            
            NSString *sqlScriptString;
            NSString *AccessionNumber=request.query[@"AccessionNumber"];
            NSString *StudyInstanceUID=request.query[@"StudyInstanceUID"];
            NSString *SeriesInstanceUID=request.query[@"SeriesInstanceUID"];

            //implementaciones:
            //(a) filesystembaseuri (no implementado)
            //(b) wadors (no implementado)
            //(c) wadouri

            if ([entityDict[@"filesystembaseuri"] length])
            {
                LOG_VERBOSE(@"(filesystembaseuri) dcm.zip?%@",[urlComponents query]);
                 return [RSErrorResponse responseWithClientError:404 message:@"not available"];
            }
            else if ([entityDict[@"wadorslocaluri"] length])
            {
                LOG_VERBOSE(@"(wadors) dcm.zip?%@",[urlComponents query]);
                return [RSErrorResponse responseWithClientError:404 message:@"not available"];
                /*
                 
                 //series wadors
                 NSArray *seriesArray=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/series?%@",entityDict[@"qidolocaluri"],request.URL.query]]] options:0 error:nil];
                 
                 
                 __block NSMutableArray *wados=[NSMutableArray array];
                 for (NSDictionary *dictionary in seriesArray)
                 {
                 //download series
                 //00081190 UR RetrieveURL
                 [wados addObject:((dictionary[@"00081190"])[@"Value"])[0]];
                 #pragma mark TODO correct proxy wadors...
                 }
                 LOG_DEBUG(@"%@",[wados description]);
                 
                 
                 __block NSMutableData *wadors=[NSMutableData data];
                 __block NSMutableData *boundary=[NSMutableData data];
                 __block NSMutableData *directory=[NSMutableData data];
                 __block NSRange wadorsRange=NSMakeRange(0,0);
                 __block uint32 entryPointer=0;
                 __block uint16 entriesCount=0;
                 __block NSRange ctadRange=NSMakeRange(0,0);
                 __block NSRange boundaryRange=NSMakeRange(0,0);
                 
                 //  The RSAsyncStreamBlock works like the RSStreamBlock
                 //  except the streamed data can be returned at a later time allowing for
                 //  truly asynchronous generation of the data.
                 //
                 //  The block must call "completionBlock" passing the new chunk of data when ready,
                 //  an empty NSData when done, or nil on error and pass a NSError.
                 //
                 //  The block cannot call "completionBlock" more than once per invocation.
                
                RSStreamedResponse* response = [RSStreamedResponse responseWithContentType:@"application/octet-stream" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
                                                {
                                                    if (wadorsRange.length<1000)
                                                    {
                                                        LOG_INFO(@"need data. Remaining wadors:%lu",(unsigned long)wados.count);
                                                        if (wados.count>0)
                                                        {
                                                            //request, response and error
                                                            NSMutableURLRequest *wadorsRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:wados[0]] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:timeout];
                                                            //https://developer.apple.com/reference/foundation/nsurlrequestcachepolicy?language=objc
                                                            //NSURLRequestReloadIgnoringCacheData
                                                            [wadorsRequest setHTTPMethod:@"GET"];
                                                            [wadorsRequest setValue:@"multipart/related;type=application/dicom" forHTTPHeaderField:@"Accept"];
                                                            NSHTTPURLResponse *response=nil;
                                                            //URL properties: expectedContentLength, MIMEType, textEncodingName
                                                            //HTTP properties: statusCode, allHeaderFields
                                                            
                                                            NSError *error=nil;
                                                            [wadors setData:[NSURLConnection sendSynchronousRequest:wadorsRequest returningResponse:&response error:&error]];
                                                            if (response.statusCode==200)
                                                            {
                                                                wadorsRange.location=0;
                                                                wadorsRange.length=[wadors length];
                                                                NSString *ctString=response.allHeaderFields[@"Content-Type"];
                                                                NSString *boundaryString=[@"\r\n--" stringByAppendingString:[ctString substringFromIndex:ctString.length-36]];
                                                                [boundary setData:[boundaryString dataUsingEncoding:NSUTF8StringEncoding]];
                                                                LOG_INFO(@"%@\r\n(%lu,%lu) boundary:%@",wados[0],(unsigned long)wadorsRange.location,(unsigned long)wadorsRange.length,boundaryString);
                                                            }
                                                            [wados removeObjectAtIndex:0];
                                                        }
                                                    }
                                                    ctadRange=[wadors rangeOfData:ctad options:0 range:wadorsRange];
                                                    boundaryRange=[wadors rangeOfData:boundary options:0 range:wadorsRange];
                                                    if ((ctadRange.length>0) && (boundaryRange.length>0)) //chunk with new entry
                                                    {
                                                        //dcm
                                                        unsigned long dcmLocation=ctadRange.location+ctadRange.length;
                                                        unsigned long dcmLength=boundaryRange.location-dcmLocation;
                                                        wadorsRange.location=boundaryRange.location+boundaryRange.length;
                                                        wadorsRange.length=wadors.length-wadorsRange.location;
                                                        
                                                        NSString *dcmUUID=[[[NSUUID UUID]UUIDString]stringByAppendingPathExtension:@"dcm"];
                                                        NSData *dcmName=[dcmUUID dataUsingEncoding:NSUTF8StringEncoding];
                                                        //LOG_INFO(@"dcm (%lu bytes):%@",dcmLength,dcmUUID);
                                                        
                                                        __block NSMutableData *entry=[NSMutableData data];
                                                        [entry appendBytes:&zipLocalFileHeader length:4];//0x04034B50
                                                        [entry appendBytes:&zipVersion length:2];//0x000A
                                                        [entry increaseLengthBy:8];//uint32 flagCompression,zipTimeDate
                                                        
                                                        NSData *dcmData=[wadors subdataWithRange:NSMakeRange(dcmLocation,dcmLength)];
                                                        uint32 zipCrc32=[dcmData crc32];
                                                        
                                                        [entry appendBytes:&zipCrc32 length:4];
                                                        [entry appendBytes:&dcmLength length:4];//zipCompressedSize
                                                        [entry appendBytes:&dcmLength length:4];//zipUncompressedSize
                                                        [entry appendBytes:&zipNameLength length:4];//0x28
                                                        [entry appendData:dcmName];
                                                        //extra param
                                                        [entry appendData:dcmData];
                                                        
                                                        completionBlock(entry, nil);
                                                        
                                                        //directory
                                                        [directory appendBytes:&zipFileHeader length:4];//0x02014B50
                                                        [directory appendBytes:&zipVersion length:2];//0x000A
                                                        [directory appendBytes:&zipVersion length:2];//0x000A
                                                        [directory increaseLengthBy:8];//uint32 flagCompression,zipTimeDate
                                                        [directory appendBytes:&zipCrc32 length:4];
                                                        [directory appendBytes:&dcmLength length:4];//zipCompressedSize
                                                        [directory appendBytes:&dcmLength length:4];//zipUncompressedSize
                                                        [directory appendBytes:&zipNameLength length:4];//0x28
                                                        //uint16 zipFileCommLength=0x0;
                                                        //uint16 zipDiskStart=0x0;
                                                        //uint16 zipInternalAttr=0x0;
                                                        //uint32 zipExternalAttr=0x0;

                                                        [directory increaseLengthBy:10];
                                                        
                                                        [directory appendBytes:&entryPointer length:4];//offsetOfLocalHeader
                                                        entryPointer+=dcmLength+70;
                                                        entriesCount++;
                                                        [directory appendData:dcmName];
                                                        //extra param
                                                    }
                                                    else if (directory.length) //chunk with directory
                                                    {
                                                        //ZIP "end of central directory record"
                                                        
                                                        //uint32 zipEndOfCentralDirectory=0x06054B50;
                                                        [directory appendBytes:&zipEndOfCentralDirectory length:4];
                                                        [directory increaseLengthBy:4];//zipDiskNumber
                                                        [directory appendBytes:&entriesCount length:2];//disk zipEntries
                                                        [directory appendBytes:&entriesCount length:2];//total zipEntries
                                                        uint32 directorySize=86 * entriesCount;
                                                        [directory appendBytes:&directorySize length:4];
                                                        [directory appendBytes:&entryPointer length:4];
                                                        [directory increaseLengthBy:2];//zipCommentLength
                                                        completionBlock(directory, nil);
                                                        [directory setData:[NSData data]];
                                                    }
                                                    else completionBlock([NSData data], nil);//last chunck
                                                    
                                                }];
                
                return response;

                 
                 */

            }
            else if ([entityDict[@"wadolocaluri"] length])
            {
                LOG_VERBOSE(@"(wadouri) dcm.zip?%@",[urlComponents query]);
                
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
                
                LOG_DEBUG(@"%@",sqlScriptString);
                
                
                //pipeline
                NSMutableData *wadoUrisData=[NSMutableData data];
                int studiesResult=task(@"/bin/bash",
                                       @[@"-s"],
                                       [sqlScriptString dataUsingEncoding:NSUTF8StringEncoding],
                                       wadoUrisData
                                       );
                __block NSMutableArray *wados=[NSJSONSerialization JSONObjectWithData:wadoUrisData options:NSJSONReadingMutableContainers error:nil];
                __block NSMutableData *directory=[NSMutableData data];
                __block uint32 entryPointer=0;
                __block uint16 entriesCount=0;
                
                // The RSAsyncStreamBlock works like the RSStreamBlock
                // The block must call "completionBlock" passing the new chunk of data when ready, an empty NSData when done, or nil on error and pass a NSError.
                // The block cannot call "completionBlock" more than once per invocation.
                RSStreamedResponse* response = [RSStreamedResponse responseWithContentType:@"application/octet-stream" asyncStreamBlock:^(RSBodyReaderCompletionBlock completionBlock)
                                                {
                                                    if (wados.count>0)
                                                    {
                                                        //request, response and error
                                                        NSString *wadoString=[NSString stringWithFormat:@"%@%@%@",
                                                                              entityDict[@"wadolocaluri"],
                                                                              wados[0],
                                                                              entityDict[@"wadoadditionalparameters"]];
                                                        __block NSData *wadoData=[NSData dataWithContentsOfURL:[NSURL URLWithString:wadoString]];
                                                        if (!wadoData)
                                                        {
                                                            NSLog(@"could not retrive: %@",wadoString);
                                                            completionBlock([NSData data], nil);
                                                        }
                                                        else
                                                        {
                                                            [wados removeObjectAtIndex:0];
                                                            unsigned long wadoLength=(unsigned long)[wadoData length];
                                                            NSString *dcmUUID=[[[NSUUID UUID]UUIDString]stringByAppendingPathExtension:@"dcm"];
                                                            NSData *dcmName=[dcmUUID dataUsingEncoding:NSUTF8StringEncoding];
                                                            //LOG_INFO(@"dcm (%lu bytes):%@",dcmLength,dcmUUID);
                                                            
                                                            __block NSMutableData *entry=[NSMutableData data];
                                                            [entry appendBytes:&zipLocalFileHeader length:4];//0x04034B50
                                                            [entry appendBytes:&zipVersion length:2];//0x000A
                                                            [entry increaseLengthBy:8];//uint32 flagCompression,zipTimeDate
                                                            uint32 zipCrc32=[wadoData crc32];
                                                            [entry appendBytes:&zipCrc32 length:4];
                                                            [entry appendBytes:&wadoLength length:4];//zipCompressedSize
                                                            [entry appendBytes:&wadoLength length:4];//zipUncompressedSize
                                                            [entry appendBytes:&zipNameLength length:4];//0x28
                                                            [entry appendData:dcmName];
                                                            //extra param
                                                            [entry appendData:wadoData];
                                                            
                                                            completionBlock(entry, nil);
                                                            
                                                            //directory
                                                            [directory appendBytes:&zipFileHeader length:4];//0x02014B50
                                                            [directory appendBytes:&zipVersion length:2];//0x000A
                                                            [directory appendBytes:&zipVersion length:2];//0x000A
                                                            [directory increaseLengthBy:8];//uint32 flagCompression,zipTimeDate
                                                            [directory appendBytes:&zipCrc32 length:4];
                                                            [directory appendBytes:&wadoLength length:4];//zipCompressedSize
                                                            [directory appendBytes:&wadoLength length:4];//zipUncompressedSize
                                                            [directory appendBytes:&zipNameLength length:4];//0x28
                                                            /*
                                                             uint16 zipFileCommLength=0x0;
                                                             uint16 zipDiskStart=0x0;
                                                             uint16 zipInternalAttr=0x0;
                                                             uint32 zipExternalAttr=0x0;
                                                             */
                                                            [directory increaseLengthBy:10];
                                                            
                                                            [directory appendBytes:&entryPointer length:4];//offsetOfLocalHeader
                                                            entryPointer+=wadoLength+70;
                                                            entriesCount++;
                                                            [directory appendData:dcmName];
                                                            //extra param
                                                        }
                                                    }
                                                    else if (directory.length) //chunk with directory
                                                    {
                                                        //ZIP "end of central directory record"
                                                        
                                                        //uint32 zipEndOfCentralDirectory=0x06054B50;
                                                        [directory appendBytes:&zipEndOfCentralDirectory length:4];
                                                        [directory increaseLengthBy:4];//zipDiskNumber
                                                        [directory appendBytes:&entriesCount length:2];//disk zipEntries
                                                        [directory appendBytes:&entriesCount length:2];//total zipEntries
                                                        uint32 directorySize=86 * entriesCount;
                                                        [directory appendBytes:&directorySize length:4];
                                                        [directory appendBytes:&entryPointer length:4];
                                                        [directory increaseLengthBy:2];//zipCommentLength
                                                        completionBlock(directory, nil);
                                                        [directory setData:[NSData data]];
                                                    }
                                                    else completionBlock([NSData data], nil);//last chunck
                                                    
                                                }];
                
                return response;

            }
            else return [RSErrorResponse responseWithClientError:404 message:@"%@ [{pacs} no filesystembaseuri, no wadors, no wadouri]",urlComponents.path];

        }(request));}];

        
        
//-----------------------------------------------

        
#pragma mark ot doc cda sr
        // /ot?
        // /doc?
        // /cda?
        // /sr?
        
        //pacs={oid}
/*
        NSRegularExpression *encapsulatedRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/pacs\\/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*\\/(ot|doc|cda|sr|OT|DOC|CDA|SR)$" options:NSRegularExpressionCaseInsensitive error:NULL];
         [httpdicomServer addHandler:@"GET" regex:encapsulatedRegex processBlock:
          ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             //LOG_DEBUG(@"client: %@",request.remoteAddressString);
             
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];

             NSDictionary *entityDict=entitiesDicts[pComponents[2]];
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

        
        
//-----------------------------------------------

#pragma mark /manifest/weasis/studies?
        NSRegularExpression *mwstudiesRegex = [NSRegularExpression regularExpressionWithPattern:@"^/manifest/weasis/studies" options:NSRegularExpressionCaseInsensitive error:NULL];
        [httpdicomServer addHandler:@"GET" regex:mwstudiesRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock)
         {completionBlock(^RSResponse* (RSRequest* request)
         {
             LOG_DEBUG(@"client: %@",request.remoteAddressString);
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
             
             //request parts logging
             NSURL *requestURL=request.URL;
             NSString *bSlash=requestURL.baseURL.absoluteString;
             NSString *b=[bSlash substringToIndex:[bSlash length]-1];
             NSString *p=requestURL.path;
             //NSString *q=requestURL.query;
             NSDictionary *q=request.query;


             NSDictionary *entityDict=entitiesDicts[q[@"custodianOID"]];
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
             //db response may be in latin1
             NSStringEncoding charset=(NSStringEncoding)[entityDict[@"sqlstringencoding"] integerValue ];
             if (charset!=4 && charset!=5) return [RSErrorResponse responseWithClientError:404 message:@"unknown sql charset : %lu",(unsigned long)charset];

             NSString *sqlString;
             NSString *AccessionNumber=request.query[@"AccessionNumber"];
             if (AccessionNumber)sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyAccessionNumber"],entityDict[@"sqlprolog"],AccessionNumber];
             else
             {
                 NSString *StudyInstanceUID=request.query[@"StudyInstanceUID"];
                 if (StudyInstanceUID)sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyStudyInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID];
                 else return [RSErrorResponse responseWithClientError:404 message:
                              @"parameter AccessionNumber or StudyInstanceUID required in %@%@?%@",b,p,q];
             }
             //SQL for studies
             NSMutableData *studiesData=[NSMutableData data];
             int studiesResult=task(@"/bin/bash",
                                    @[@"-s"],
                                    [sqlString dataUsingEncoding:NSUTF8StringEncoding],
                                    studiesData
                                    );
             
             
             if (charset==5) //latin1
             {
                 NSString *latin1String=[[NSString alloc]initWithData:studiesData encoding:NSISOLatin1StringEncoding];
                 [studiesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
             }
             NSMutableArray *studyArray=[NSJSONSerialization JSONObjectWithData:studiesData options:0 error:nil];
//[0] p.family_name,p.given_name,p.middle_name,p.name_prefix,p.name_suffix,
//[1] patient_id.pat_id,
//[2] iopid.entity_uid,
//[3] patient.pat_birthdate,
//[4] patient.pat_sex,
             
//[5] study.study_iuid,
//[6] study.accession_no,
//[7] ioan.entity_uid,
//[8] study_query_attrs.retrieve_aets,
//[9] study.study_id,
//[10] study.study_desc,
//[11] study.study_date,
//[12] study.study_time
//[13] NumberOfStudyRelatedInstances
 
             //the accessionNumber may join more than one study of one or more patient !!!
             //look for patient roots first
             NSMutableArray *uniquePatients=[NSMutableArray array];
             for (NSArray *studyInstance in studyArray)
             {
                 [uniquePatients addObject:[studyInstance[1]stringByAppendingPathComponent:studyInstance[2]]];
             }
             
             NSMutableString *weasisManifest=[NSMutableString string];
             //each patient
                 for (NSString *patient in [NSSet setWithArray:uniquePatients])
                 {
                     NSUInteger studyIndex=[uniquePatients indexOfObject:patient];
                     NSArray *patientAttrs=studyArray[studyIndex];
                     [weasisManifest appendFormat:
                      @"<Patient PatientName=\"%@\" PatientID=\"%@\" IssuerOfPatientID=\"%@\" PatientBirthDate=\"%@\" PatientSex=\"%@\">\r",
                      patientAttrs[0],
                      patientAttrs[1],
                      patientAttrs[2],
                      patientAttrs[3],
                      patientAttrs[4]
                      ];
                     
                     for (NSArray *studyInstance in studyArray)
                     {
                         if (  [studyInstance[1]isEqualToString:patientAttrs[1]]
                            )
                         {
                             //                             &&[studyInstance[2]isEqualToString:patientAttrs[2]]
                             //TODO: add second if clause?
                             
                            //each study of this patient
                             [weasisManifest appendFormat:
                              @"<Study SpecificCharacterSet=\"UTF-8\" StudyInstanceUID=\"%@\" AccessionNumber=\"%@\" IssuerOfAccessionNumber=\"%@\" RetrieveAETitle=\"%@\" StudyID=\"%@\" StudyDescription=\"%@\" StudyDate=\"%@\" StudyTime=\"%@\" WadorsURI=\"/studies/%@\" NumberOfStudyRelatedInstances=\"%@\">\r",
                              studyInstance[5],
                              studyInstance[6],
                              studyInstance[7],
                              studyInstance[8],
                              studyInstance[9],
                              studyInstance[10],
                              studyInstance[11],
                              studyInstance[12],
                              studyInstance[5],
                              studyInstance[13]
                              ];
                             
                             //series

                             NSMutableData *seriesData=[NSMutableData data];
                             int seriesResult=task(@"/bin/bash",
                                                    @[@"-s"],
                                                    [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisSeriesStudyInstanceUID"],entityDict[@"sqlprolog"],studyInstance[5]]
                                                     dataUsingEncoding:NSUTF8StringEncoding],
                                                    seriesData
                                                    );
                             if (charset==5) //latin1
                             {
                                 NSString *latin1String=[[NSString alloc]initWithData:seriesData encoding:NSISOLatin1StringEncoding];
                                 [seriesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
                             }
                             NSMutableArray *seriesArray=[NSJSONSerialization JSONObjectWithData:seriesData options:0 error:nil];

                             for (NSArray *seriesInstance in seriesArray)
                             {
                                 [weasisManifest appendFormat:
                                  @"<Series SeriesInstanceUID=\"%@\" SeriesDescription=\"%@\" SeriesNumber=\"%@\" Modality=\"%@\"  WadorsURI=\"/studies/%@/series/%@\" NumberOfSeriesRelatedInstances=\"%@\">\r",
                                  seriesInstance[0],
                                  seriesInstance[1],
                                  seriesInstance[2],
                                  seriesInstance[3],
                                  studyInstance[5],
                                  seriesInstance[0],
                                  seriesInstance[4]
                                  ];
                                 //instances
                                 NSMutableData *instanceData=[NSMutableData data];
                                 int instanceResult=task(@"/bin/bash",
                                                       @[@"-s"],
                                                       [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisInstanceSeriesInstanceUID"],entityDict[@"sqlprolog"],seriesInstance[0]]
                                                        dataUsingEncoding:NSUTF8StringEncoding],
                                                       instanceData
                                                       );
                                 if (charset==5) //latin1
                                 {
                                     NSString *latin1String=[[NSString alloc]initWithData:instanceData encoding:NSISOLatin1StringEncoding];
                                     [instanceData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
                                 }
                                 
                                 NSMutableArray *instanceArray=[NSJSONSerialization JSONObjectWithData:instanceData options:0 error:nil];
                                 for (NSArray *instance in instanceArray)
                                 {
                                     [weasisManifest appendFormat:
                                      @"<Instance SOPInstanceUID=\"%@\" InstanceNumber=\"%@\" SOPClassUID=\"%@\"/>\r",
                                      instance[0],
                                      instance[1],
                                      instance[2]
                                      ];
                                 }
                                 [weasisManifest appendString:@"</Series>\r"];
                             }
                             [weasisManifest appendString:@"</Study>\r"];
                         }
                     }
                     [weasisManifest appendString:@"</Patient>\r"];
                 }
                 return [RSDataResponse responseWithData:[weasisManifest dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/xml"];
             
         }(request));}];
        
        
#pragma mark /manifest/weasis/studies/{StudyInstanceUID}/series/{SeriesInstanceUID}
 
        NSRegularExpression *mwseriesRegex = [NSRegularExpression regularExpressionWithPattern:@"^/manifest/weasis/studies/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*" options:NSRegularExpressionCaseInsensitive error:NULL];
 ///series/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*
        
        [httpdicomServer addHandler:@"GET" regex:mwseriesRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock)
         {completionBlock(^RSResponse* (RSRequest* request)
         {
             LOG_DEBUG(@"client: %@",request.remoteAddressString);
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];

             //request parts logging
             NSURL *requestURL=request.URL;
             NSString *bSlash=requestURL.baseURL.absoluteString;
             NSString *b=[bSlash substringToIndex:[bSlash length]-1];
             
             NSString *p=requestURL.path;
             NSString *StudyInstanceUID=pComponents[4];
             NSString *SeriesInstanceUID=pComponents[6];
             
             //NSString *q=requestURL.query;
             NSDictionary *q=request.query;
             NSDictionary *entityDict=entitiesDicts[q[@"custodianOID"]];
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
             //db response may be in latin1
             NSStringEncoding charset=(NSStringEncoding)[entityDict[@"sqlstringencoding"] integerValue ];
             if (charset!=4 && charset!=5) return [RSErrorResponse responseWithClientError:404 message:@"unknown sql charset : %lu",(unsigned long)charset];

             NSString *sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisSeriesStudyInstanceUIDSeriesInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID,SeriesInstanceUID];
 
             //LOG_INFO(@"%@",sqlString);
            
             //SQL for series
             NSMutableData *seriesData=[NSMutableData data];
             int seriesResult=task(@"/bin/bash",
                                    @[@"-s"],
                                    [sqlString dataUsingEncoding:NSUTF8StringEncoding],
                                    seriesData
                                    );
             if (charset==5) //latin1
             {
                 NSString *latin1String=[[NSString alloc]initWithData:seriesData encoding:NSISOLatin1StringEncoding];
                 [seriesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
             }
             NSMutableArray *seriesArray=[NSJSONSerialization JSONObjectWithData:seriesData options:0 error:nil];
             if (![seriesArray count]) return [RSErrorResponse responseWithClientError:404 message:@"0 record for %@%@?%@",b,p,q];
//[0] SeriesInstanceUID,
//[1] SeriesDescription,
//[2] SeriesNumber,
//[3] Modality,
 
             //get corresponding patient and study
             //SQL for studies

             NSMutableData *studiesData=[NSMutableData data];
             int studiesResult=task(@"/bin/bash",
                                    @[@"-s"],
                                    [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyStudyInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID] dataUsingEncoding:NSUTF8StringEncoding],
                                    studiesData
                                    );
             if (charset==5) //latin1
             {
                 NSString *latin1String=[[NSString alloc]initWithData:studiesData encoding:NSISOLatin1StringEncoding];
                 [studiesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
             }
             NSMutableArray *studyArray=[NSJSONSerialization JSONObjectWithData:studiesData options:0 error:nil];

//[0]  p.family_name,p.given_name,p.middle_name,p.name_prefix,p.name_suffix,
//[1] patient_id.pat_id,
//[2] iopid.entity_uid,
//[3] patient.pat_birthdate,
//[4] patient.pat_sex,
              
//[5] study.study_iuid,
//[6] study.accession_no,
//[7] ioan.entity_uid,
//[8] study_query_attrs.retrieve_aets,
//[9] study.study_id,
//[10] study.study_desc,
//[11] study.study_date,
//[12] study.study_time
 
             //the accessionNumber may join more than one study of one or more patient !!!
             //look for patient roots first
             NSMutableArray *uniquePatients=[NSMutableArray array];
             for (NSArray *studyInstance in studyArray)
             {
                 [uniquePatients addObject:[studyInstance[1]stringByAppendingPathComponent:studyInstance[2]]];
             }
             
             NSMutableString *weasisManifest=[NSMutableString string];
             //each patient
             for (NSString *patient in [NSSet setWithArray:uniquePatients])
             {
                 NSUInteger studyIndex=[uniquePatients indexOfObject:patient];
                 NSArray *patientAttrs=studyArray[studyIndex];
                 [weasisManifest appendFormat:
                  @"<Patient PatientName=\"%@\" PatientID=\"%@\" IssuerOfPatientID=\"%@\" PatientBirthDate=\"%@\" PatientSex=\"%@\">\r",
                  patientAttrs[0],
                  patientAttrs[1],
                  patientAttrs[2],
                  patientAttrs[3],
                  patientAttrs[4]
                  ];
                 
                 for (NSArray *studyInstance in studyArray)
                 {
                     if (  [studyInstance[1]isEqualToString:patientAttrs[1]]
                         &&[studyInstance[2]isEqualToString:patientAttrs[2]]
                         )
                     {
                         //each study of this patient
                         [weasisManifest appendFormat:
                          @"<Study SpecificCharacterSet=\"UTF-8\" StudyInstanceUID=\"%@\" AccessionNumber=\"%@\" IssuerOfAccessionNumber=\"%@\" RetrieveAETitle=\"%@\" StudyID=\"%@\" StudyDescription=\"%@\" StudyDate=\"%@\" StudyTime=\"%@\" WadorsURI=\"/studies/%@\" NumberOfStudyRelatedInstances=\"%@\">\r",
                          studyInstance[5],
                          studyInstance[6],
                          studyInstance[7],
                          studyInstance[8],
                          studyInstance[9],
                          studyInstance[10],
                          studyInstance[11],
                          studyInstance[12],
                          studyInstance[5],
                          studyInstance[13]
                          ];
                         for (NSArray *seriesInstance in seriesArray)
                         {
                             [weasisManifest appendFormat:
                              @"<Series SeriesInstanceUID=\"%@\" SeriesDescription=\"%@\" SeriesNumber=\"%@\" Modality=\"%@\"  WadorsURI=\"/studies/%@/series/%@\" NumberOfSeriesRelatedInstances=\"%@\">\r",
                              seriesInstance[0],
                              seriesInstance[1],
                              seriesInstance[2],
                              seriesInstance[3],
                              studyInstance[5],
                              seriesInstance[0],
                              seriesInstance[4]
                              ];
                             
                             //instances
                             NSMutableData *instanceData=[NSMutableData data];
                             int instanceResult=task(@"/bin/bash",
                                                     @[@"-s"],
                                                     [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisInstanceSeriesInstanceUID"],entityDict[@"sqlprolog"],seriesInstance[0]]
                                                      dataUsingEncoding:NSUTF8StringEncoding],
                                                     instanceData
                                                     );
                             if (charset==5) //latin1
                             {
                                 NSString *latin1String=[[NSString alloc]initWithData:instanceData encoding:NSISOLatin1StringEncoding];
                                 [instanceData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
                             }
                             NSMutableArray *instanceArray=[NSJSONSerialization JSONObjectWithData:instanceData options:0 error:nil];
                             for (NSArray *instance in instanceArray)
                             {
                                 [weasisManifest appendFormat:
                                  @"<Instance SOPInstanceUID=\"%@\" InstanceNumber=\"%@\" SOPClassUID=\"%@\"/>\r",
                                  instance[0],
                                  instance[1],
                                  instance[2]
                                  ];
                             }
                             [weasisManifest appendString:@"</Series>\r"];
                         }
                         [weasisManifest appendString:@"</Study>\r"];
                     }
                 }
                 [weasisManifest appendString:@"</Patient>\r"];
             }
             return [RSDataResponse responseWithData:[weasisManifest dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/xml"];
             
         }(request));}];
   

// ------------------------------------------------


#pragma mark datatables/studies

//query ajax with params:
//agregate 00080090 in other accesible PCS...
         
//q=current query
//r=Req=request sql
//s=subselection from caché

 NSRegularExpression *dtstudiesRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/studies" options:0 error:NULL];
        [httpdicomServer addHandler:@"GET" regex:dtstudiesRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             LOG_VERBOSE(@"%@",[request.URL description]);
             LOG_DEBUG(@"client: %@",request.remoteAddressString);
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
             

             NSDictionary *q=request.query;
             
             NSString *session=q[@"session"];
             if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
             
             NSDictionary *r=Req[session];
             int recordsTotal;
             
             NSString *qPatientID=q[@"columns[3][search][value]"];
             NSString *qPatientName=q[@"columns[4][search][value]"];
             //NSString *qStudyDate=q[@"columns[5][search][value]"];
             NSString *qDate_start=q[@"date_start"];
             NSString *qDate_end=q[@"date_end"];
             NSString *qModality;
             if ([q[@"columns[6][search][value]"]isEqualToString:@"ALL"]) qModality=@"%%";
             else qModality=q[@"columns[6][search][value]"];
             if (!qModality) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'columns[6][search][value]' (modality) parameter"] contentType:@"application/dicom+json"];
             
             NSString *qStudyDescription=q[@"columns[7][search][value]"];
             
             NSString *rPatientID=r[@"columns[3][search][value]"];
             NSString *rPatientName=r[@"columns[4][search][value]"];
             //NSString *rStudyDate=r[@"columns[5][search][value]"];
             NSString *rDate_start=r[@"date_start"];
             NSString *rDate_end=r[@"date_end"];
             NSString *rModality=r[@"columns[6][search][value]"];
             NSString *rStduyDescription=r[@"columns[7][search][value]"];
             
             
             //same or different context?
             if (
                 !r
                 || [q[@"new"]isEqualToString:@"true"]
                 || (q[@"username"]    && ![q[@"username"]isEqualToString:r[@"username"]])
                 || (q[@"useroid"]     && ![q[@"useroid"]isEqualToString:r[@"useroid"]])
                 || (session           && ![session isEqualToString:r[@"session"]])
                 || (q[@"custodiantitle"]         && ![q[@"custodiantitle"]isEqualToString:r[@"custodiantitle"]])
                 || (q[@"aet"] && ![q[@"aet"]isEqualToString:r[@"aet"]])
                 || (q[@"role"]        && ![q[@"role"]isEqualToString:r[@"role"]])
                 
                 || (q[@"search[value]"] && ![q[@"search[value]"]isEqualToString:r[@"search[value]"]])
                 
                 ||(    qPatientID
                    &&![qPatientID isEqualToString:rPatientID]
                    &&![rPatientID isEqualToString:@""]
                    )
                 ||(    qPatientName
                    &&![qPatientName isEqualToString:rPatientName]
                    &&![rPatientName isEqualToString:@""]
                    )
                 ||(    qDate_start
                    &&![qDate_start isEqualToString:rDate_start]
                    &&![rDate_start isEqualToString:@""]
                    )
                 ||(    qDate_end
                    &&![qDate_end isEqualToString:rDate_end]
                    &&![rDate_end isEqualToString:@""]
                    )
                 ||(  ![qModality isEqualToString:rModality]
                    &&![rModality isEqualToString:@"%%"]
                    )
                 ||(    qStudyDescription
                    &&![qStudyDescription isEqualToString:rStduyDescription]
                    &&![rStduyDescription isEqualToString:@""]
                    )
                 )
             {
                 //LOG_INFO(@"%@",[[request URL]description]);
#pragma mark --different context
#pragma mark reemplazar org por custodianTitle e institucion por aet
                 //find dest
                 NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
                 NSDictionary *entityDict=entitiesDicts[destOID];
                 
                 NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
                 if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
                 
                 //local ... simulation qido through database access
                 
                 //LOG_INFO(@"different context with db: %@",entityDict[@"sqlobjectmodel"]);
                 
                 if (r){
                     //replace previous request of the session.
                     [Req removeObjectForKey:session];
                     [Total removeObjectForKey:session];
                     [Filtered removeObjectForKey:session];
                     [Date removeObjectForKey:session];
                     if(sPatientID[@"session"])[sPatientID removeObjectForKey:session];
                     if(sPatientName[@"session"])[sPatientName removeObjectForKey:session];
                     //if(sStudyDate[@"session"])[sStudyDate removeObjectForKey:session];
                     if(sDate_start[@"session"])[sDate_start removeObjectForKey:session];
                     if(sDate_end[@"session"])[sDate_end removeObjectForKey:session];
                     if(sModality[@"session"])[sModality removeObjectForKey:session];
                     if(sStudyDescription[@"session"])[sStudyDescription removeObjectForKey:session];
                     
                 }
                 //copy of the sql request of the new context
                 [Req setObject:q forKey:session];
                 
//TODO: remove old sessions
                 [Date setObject:[NSDate date] forKey:session];

                 if(qPatientID)[sPatientID setObject:qPatientID forKey:session];
                 if(qPatientName)[sPatientName setObject:qPatientName forKey:session];
                 //if(qStudyDate)[sStudyDate setObject:qStudyDate forKey:session];
                 if(qDate_start)[sDate_start setObject:qDate_start forKey:session];
                 if(qDate_end)[sDate_end setObject:qDate_end forKey:session];
                 [sModality setObject:qModality forKey:session];
                 if(qStudyDescription)[sStudyDescription setObject:qStudyDescription forKey:session];
                 
//1 create where clause
                 
                 //WHERE study.rejection_state!=2    (or  1=1)
                 //following filters use formats like " AND a like 'b'"
                 NSMutableString *studiesWhere=[NSMutableString stringWithString:sqlobjectmodel[@"studiesWhere"]];

                 //PEP por aet or custodian
                 if ([q[@"aet"] isEqualToString:q[@"custodiantitle"]])
                 {
//[studiesWhere appendFormat:
//@" AND %@ in %@",
//sqlobjectmodel[@"accessControlId"],
//custodianTitlesaetsStrings[q[@"custodiantitle"]]
//];
                 }
                 else
                 {
//[studiesWhere appendFormat:
//@" AND %@ in ('%@','%@')",
//sqlobjectmodel[@"accessControlId"],
//q[@"aet"],
//q[@"custodiantitle"]
//];
                 }
                 
                 if (q[@"search[value]"] && ![q[@"search[value]"] isEqualToString:@""])
                 {
                     //AccessionNumber q[@"search[value]"]
                     [studiesWhere appendString:
                      [NSString mysqlEscapedFormat:@" AND %@ like '%@'"
                                       fieldString:sqlobjectmodel[@"AccessionNumber"]
                                       valueString:q[@"search[value]"]
                       ]
                      ];
                 }
                 else
                 {
                     if(qPatientID && [qPatientID length])
                     {
                         [studiesWhere appendString:
                          [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                           fieldString:sqlobjectmodel[@"PatientID"]
                                           valueString:qPatientID
                           ]
                          ];
                     }
                     
                     if(qPatientName && [qPatientName length])
                     {
                         //PatientName _00100010 Nombre
                         NSArray *patientNameComponents=[qPatientName componentsSeparatedByString:@"^"];
                         NSUInteger patientNameCount=[patientNameComponents count];
                         
                         [studiesWhere appendString:
                          [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                           fieldString:(sqlobjectmodel[@"PatientName"])[0]
                                           valueString:patientNameComponents[0]
                           ]
                          ];
                         
                         if (patientNameCount > 1)
                         {
                             [studiesWhere appendString:
                              [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                               fieldString:(sqlobjectmodel[@"PatientName"])[1]
                                               valueString:patientNameComponents[1]
                               ]
                              ];
                             
                             if (patientNameCount > 2)
                             {
                                 [studiesWhere appendString:
                                  [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                                   fieldString:(sqlobjectmodel[@"PatientName"])[2]
                                                   valueString:patientNameComponents[2]
                                   ]
                                  ];
                                 
                                 if (patientNameCount > 3)
                                 {
                                     [studiesWhere appendString:
                                      [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                                       fieldString:(sqlobjectmodel[@"PatientName"])[3]
                                                       valueString:patientNameComponents[3]
                                       ]
                                      ];
                                     
                                     if (patientNameCount > 4)
                                     {
                                         [studiesWhere appendString:
                                          [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                                           fieldString:(sqlobjectmodel[@"PatientName"])[4]
                                                           valueString:patientNameComponents[4]
                                           ]
                                          ];
                                     }
                                 }
                             }
                         }
                     }
                     
                     if(
                        (qDate_start && [qDate_start length])
                        ||(qDate_end && [qDate_end length])
                        )
                     {
                         NSString *s=nil;
                         if (qDate_start && [qDate_start length]) s=qDate_start;
                         else s=@"";
                         NSString *e=nil;
                         if (qDate_end && [qDate_end length]) e=qDate_end;
                         else e=@"";
                         [studiesWhere appendString:[sqlobjectmodel[@"StudyDate"] sqlFilterWithStart:s end:e]];
                     }
                     
                     //qModality contains ONE modality or joker %%
                     [studiesWhere appendFormat:@" AND %@ like '%%%@%%'", sqlobjectmodel[@"ModalitiesInStudy"], qModality];
                     
                     if(qStudyDescription && [qStudyDescription length])
                     {
                         //StudyDescription _00081030 Descripción
                         [studiesWhere appendString:
                          [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                           fieldString:sqlobjectmodel[@"StudyDescription"]
                                           valueString:qStudyDescription
                           ]
                          ];
                     }
                 }
                 LOG_INFO(@"%@",[studiesWhere substringFromIndex:65]);


//2 count
                 NSString *sqlCountQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                          entityDict[@"sqlprolog"],
                                          sqlobjectmodel[@"studiesCountProlog"],
                                          studiesWhere,
                                          sqlobjectmodel[@"studiesCountEpilog"]
                                          ];
                 LOG_DEBUG(@"%@",sqlCountQuery);
                 NSMutableData *countData=[NSMutableData data];
                 if (task(@"/bin/bash",@[@"-s"],[sqlCountQuery dataUsingEncoding:NSUTF8StringEncoding],countData))
                     [RSErrorResponse responseWithClientError:404 message:@"%@",@"can not access the db"];//NotFound
                 NSString *countString=[[NSString alloc]initWithData:countData encoding:NSUTF8StringEncoding];
                 // max (max records filtered para evitar que filtros insuficientes devuelvan casi todos los registros... lo que devolvería un resultado inútil.
                 recordsTotal=[countString intValue];
                 int maxCount=[q[@"max"]intValue];
                 LOG_INFO(@"total:%d, max:%d",recordsTotal,maxCount);
                 if (recordsTotal > maxCount) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:[NSString stringWithFormat:@"you need a narrower filter. The browser table accepts up to %d matches. %d matches were found",maxCount, recordsTotal]] contentType:@"application/dicom+json"];

                 if (!recordsTotal) return [RSDataResponse
                                            responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:@{
                                                      @"draw":q[@"draw"],
                                                      @"recordsTotal":@0,
                                                      @"recordsFiltered":@0,
                                                      @"data":@[]
                                                      }]
                                     contentType:@"application/dicom+json"
                                     ];
                 else
                 {
                     //order is performed later, from mutableDictionary
//3 select
                     NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                             entityDict[@"sqlprolog"],
                                             sqlobjectmodel[@"datatablesStudiesProlog"],
                                             studiesWhere,
                                             [NSString stringWithFormat: sqlobjectmodel[@"datatablesStudiesEpilog"],session,
                                                 session
                                              ]
                                             ];

                     NSMutableArray *studiesArray=jsonMutableArray(sqlDataQuery,(NSStringEncoding) [entityDict[@"sqlstringencoding"]integerValue]);

                     [Total setObject:studiesArray forKey:session];
                     [Filtered setObject:[studiesArray mutableCopy] forKey:session];
                 }
                 
             }//end diferent context
             else
             {
                 
#pragma mark --same context
                 
                 recordsTotal=[Total[session] count];
                 //LOG_INFO(@"same context recordsTotal: %d ",recordsTotal);
                 
                 //subfilter?
                 // in case there is subfilter, derive BFiltered from BTotal
                 //https://developer.apple.com/reference/foundation/nsmutablearray/1412085-filterusingpredicate?language=objc
                 
                 if (recordsTotal > 0)
                 {
                     BOOL toBeFiltered=false;
                     
                     NSRegularExpression *PatientIDRegex=nil;
                     if(qPatientID && ![qPatientID isEqualToString:sPatientID[session]])
                     {
                         toBeFiltered=true;
                         PatientIDRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qPatientID withFormat:@"datatables\\/patient\\?PatientID=%@.*"] options:0 error:NULL];
                     }
                     
                     NSRegularExpression *PatientNameRegex=nil;
                     if(qPatientName && ![qPatientName isEqualToString:sPatientName[session]])
                     {
                         toBeFiltered=true;
                         PatientNameRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qPatientName withFormat:@"%@.*"] options:NSRegularExpressionCaseInsensitive error:NULL];
                     }
                     
                     NSString *until;
                     if(   qDate_end
                        && (  !sDate_end[session]
                            || ([qDate_end compare:sDate_end[session]]==NSOrderedAscending)
                            )
                        )
                     {
                         toBeFiltered=true;
                         until=qDate_end;
                     }
                     
                     NSString *since;
                     if(   qDate_start
                        && (  !sDate_start[session]
                            || ([qDate_start compare:sDate_start[session]]==NSOrderedDescending)
                            )
                        )
                     {
                         toBeFiltered=true;
                         since=qDate_start;
                     }
                     
                     NSString *modalitySelected=nil;
                     //sModality contains the last selected modality within the same context
                     if(![qModality isEqualToString:sModality[session]])
                     {
                         toBeFiltered=true;
                         modalitySelected=qModality;
                     }
                     else modalitySelected=sModality[session];
                     
                     NSRegularExpression *StudyDescriptionRegex=nil;
                     if(qStudyDescription  && ![qStudyDescription isEqualToString:sStudyDescription[session]])
                     {
                         toBeFiltered=true;
                         StudyDescriptionRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qStudyDescription withFormat:@"%@.*"] options:NSRegularExpressionCaseInsensitive error:NULL];
                     }
                     
                     if(toBeFiltered)
                     {
                         //filter from BTotal copy
                         [Filtered removeObjectForKey:session];
                         [Filtered setObject:[Total[session] mutableCopy] forKey:session];
                         
                         //create compound predicate
                         NSPredicate *compoundPredicate = [NSPredicate predicateWithBlock:^BOOL(NSArray *row, NSDictionary *bindings) {
                             if (PatientIDRegex)
                             {
                                 //LOG_INFO(@"patientID filter");
                                 if (![PatientIDRegex numberOfMatchesInString:row[3] options:0 range:NSMakeRange(0,[row[3] length])]) return false;
                             }
                             if (PatientNameRegex)
                             {
                                 //LOG_INFO(@"patientName filter");
                                 if (![PatientNameRegex numberOfMatchesInString:row[4] options:0 range:NSMakeRange(0,[row[4] length])]) return false;
                             }
                             if (until)
                             {
                                 //LOG_INFO(@"until filter");
                                 if ([until compare:row[5]]==NSOrderedDescending) return false;
                             }
                             if (since)
                             {
                                 //LOG_INFO(@"since filter");
                                 if ([since compare:row[5]]==NSOrderedAscending) return false;
                             }
                             //row[6] contains modalitiesInStudies. Ej: CT\OT
                             if (![row[6] containsString:modalitySelected]) return false;

                             if (StudyDescriptionRegex)
                             {
                                 //LOG_INFO(@"description filter");
                                 if (![StudyDescriptionRegex numberOfMatchesInString:row[7] options:0 range:NSMakeRange(0,[row[7] length])]) return false;
                             }
                             return true;
                         }];
                         
                         [Filtered[session] filterUsingPredicate:compoundPredicate];
                     }
                 }
             }
#pragma mark --order
             if (q[@"order[0][column]"] && q[@"order[0][dir]"])
             {
                 LOG_INFO(@"ordering with %@, %@",q[@"order[0][column]"],q[@"order[0][dir]"]);
                 
                 int column=[q[@"order[0][column]"]intValue];
                 if ([q[@"order[0][dir]"]isEqualToString:@"desc"])
                 {
                     [Filtered[session] sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                         return [obj2[column] caseInsensitiveCompare:obj1[column]];
                     }];
                 }
                 else
                 {
                     [Filtered[session] sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                         return [obj1[column] caseInsensitiveCompare:obj2[column]];
                     }];
                 }
             }
             
#pragma mark --response
             
             NSMutableDictionary *resp = [NSMutableDictionary dictionary];
             NSUInteger recordsFiltered=[Filtered[session]count];
             [resp setObject:q[@"draw"] forKey:@"draw"];
             [resp setObject:[NSNumber numberWithInt:recordsTotal] forKey:@"recordsTotal"];
             [resp setObject:[NSNumber numberWithUnsignedInteger:recordsFiltered] forKey:@"recordsFiltered"];
             
             if (!recordsFiltered)  return [RSDataResponse
                                            responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:@{@"draw":q[@"draw"],@"recordsTotal":@0,@"recordsFiltered":@0,@"data":@[]}]
                                            contentType:@"application/dicom+json"
                                            ];
             else
             {
                 //start y length
                 long ps=[q[@"start"]intValue];
                 long pl=[q[@"length"]intValue];
                 //LOG_INFO(@"paging desired (start=[%ld],filas=[%ld],last=[%lu])",ps,pl,recordsFiltered-1);
                 if (ps < 0) ps=0;
                 if (ps > recordsFiltered-1) ps=0;
                 if (ps+pl+1 > recordsFiltered) pl=recordsFiltered-ps;
                 //LOG_INFO(@"paging applied (start=[%ld],filas=[%ld],last=[%lu])",ps,pl,recordsFiltered-1);
                 NSArray *page=[Filtered[session] subarrayWithRange:NSMakeRange(ps,pl)];
                 if (!page)page=@[];
                 [resp setObject:page forKey:@"data"];
             }
             
             return [RSDataResponse
                     responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                     contentType:@"application/dicom+json"
                     ];
         }
                                                                                                                                          (request));}];
        
        
        
//-----------------------------------------------

        
#pragma mark datatables/patient

//ventana emergente con todos los estudios del paciente
//"datatables/patient
//PatientID=33333333&IssuerOfPatientID.UniversalEntityID=NULL&session=1"

 NSRegularExpression *dtpatientRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/patient" options:0 error:NULL];
        [httpdicomServer addHandler:@"GET" regex:dtpatientRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             LOG_DEBUG(@"client: %@",request.remoteAddressString);
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
             

             NSDictionary *q=request.query;
             
             NSString *session=q[@"session"];
             if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
             
             if (!q[@"PatientID"]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"studies of patient query without required 'patientID' parameter"] contentType:@"application/dicom+json"];
             
             //WHERE study.rejection_state!=2    (or  1=1)
             //following filters use formats like " AND a like 'b'"
             
             //find dest
             NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
             NSDictionary *entityDict=entitiesDicts[destOID];
             
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
             
             NSMutableString *studiesWhere=[NSMutableString stringWithString:sqlobjectmodel[@"studiesWhere"]];
             [studiesWhere appendString:
              [NSString mysqlEscapedFormat:@" AND %@ like '%@'"
                               fieldString:sqlobjectmodel[@"PatientID"]
                               valueString:q[@"PatientID"]
               ]
              ];
             //PEP por custodian aets

//[studiesWhere appendFormat:
//@" AND %@ in ('%@')",
//sqlobjectmodel[@"accessControlId"],
//[custodianTitlesaets[q[@"custodiantitle"]] componentsJoinedByString:@"','"]
//];

             LOG_INFO(@"WHERE %@",[studiesWhere substringFromIndex:38]);
             

             NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                     entityDict[@"sqlprolog"],
                                     sqlobjectmodel[@"datatablesStudiesProlog"],
                                     studiesWhere,
                                     [NSString stringWithFormat: sqlobjectmodel[@"datatablesStudiesEpilog"],session,
                                      session
                                      ]
                                     ];
             
             NSMutableArray *studiesArray=jsonMutableArray(sqlDataQuery, (NSStringEncoding) [entityDict[@"sqlstringencoding"]integerValue]);
             
             //sorted study date (5) desc
             [studiesArray sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                 return [obj2[5] caseInsensitiveCompare:obj1[5]];
             }];
             
             
             NSMutableDictionary *resp = [NSMutableDictionary dictionary];
             if (q[@"draw"])[resp setObject:q[@"draw"] forKey:@"draw"];
             NSNumber *count=[NSNumber numberWithUnsignedInteger:[studiesArray count]];
             [resp setObject:count forKey:@"recordsTotal"];
             [resp setObject:count forKey:@"recordsFiltered"];
             [resp setObject:studiesArray forKey:@"data"];
             return [RSDataResponse
                     responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                     contentType:@"application/dicom+json"
                     ];
         }
                                                                                                                                          (request));}];
        
        
        
//-----------------------------------------------

        
#pragma mark datatables/series
        //"datatables/series?AccessionNumber=22&IssuerOfAccessionNumber.UniversalEntityID=NULL&StudyIUID=2.16.858.2.10000675.72769.20160411084701.1.100&session=1"
        NSRegularExpression *dtseriesRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/series" options:0 error:NULL];
        [httpdicomServer addHandler:@"GET" regex:dtseriesRegex processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
         {
             LOG_DEBUG(@"client: %@",request.remoteAddressString);
             NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
             NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
             

             NSDictionary *q=request.query;
             NSString *session=q[@"session"];
             if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
             
             
             //find dest
             NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
             NSDictionary *entityDict=entitiesDicts[destOID];
             
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
             NSString *where;
             NSString *AccessionNumber=q[@"AccessionNumber"];
             NSString *StudyInstanceUID=q[@"StudyInstanceUID"];
             if (
                    [entityDict[@"preferredStudyIdentificator"] isEqualToString:@"AccessionNumber"]
                 && AccessionNumber
                 && ![AccessionNumber isEqualToString:@"NULL"])
             {
                 NSString *IssuerOfAccessionNumber=q[@"IssuerOfAccessionNumber.UniversalEntityID"];
                 if (IssuerOfAccessionNumber && ![IssuerOfAccessionNumber isEqualToString:@"NULL"]) where=[NSString stringWithFormat:@"%@ AND %@='%@' AND %@='%@'", sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"AccessionNumber"],AccessionNumber,sqlobjectmodel[@"IssuerOfAccessionNumber"],IssuerOfAccessionNumber];
                 else where=[NSString stringWithFormat:@"%@ AND %@='%@'",sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"AccessionNumber"],AccessionNumber];
                 
             }
             else if (StudyInstanceUID && ![StudyInstanceUID isEqualToString:@"NULL"])
                 where=[NSString stringWithFormat:@"%@ AND %@='%@'",sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"StudyInstanceUID"],StudyInstanceUID];
             else return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'AccessionNumber' or 'StudyInstanceUID' parameter"] contentType:@"application/dicom+json"];
             
             
             LOG_INFO(@"WHERE %@",[where substringFromIndex:38]);

             NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                     entityDict[@"sqlprolog"],
                                     sqlobjectmodel[@"datatablesSeriesProlog"],
                                     where,
                                     [NSString stringWithFormat:
                                      sqlobjectmodel[@"datatablesSeriesEpilog"],
                                      session,
                                      session
                                      ]
                                     ];
             
             NSMutableArray *seriesArray=jsonMutableArray(sqlDataQuery,(NSStringEncoding) [entityDict[@"sqlstringencoding"] integerValue]);
             //LOG_INFO(@"series array:%@",[seriesArray description]);
             
             NSMutableDictionary *resp = [NSMutableDictionary dictionary];
             if (q[@"draw"])[resp setObject:q[@"draw"] forKey:@"draw"];
             NSNumber *count=[NSNumber numberWithUnsignedInteger:[seriesArray count]];
             [resp setObject:count forKey:@"recordsTotal"];
             [resp setObject:count forKey:@"recordsFiltered"];
             [resp setObject:seriesArray forKey:@"data"];
             return [RSDataResponse
                     responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                     contentType:@"application/dicom+json"
                     ];
         }
                                                                                                                                          (request));}];

        
        
//-----------------------------------------------

        
#pragma mark IHEInvokeImageDisplay
        //IHEInvokeImageDisplay
        //?requestType=STUDY
        //&accessionNumber=1
        //&viewerType=IHE_BIR
        //&diagnosticQuality=true
        //&keyImagesOnly=false
        //&custodianOID=xxx
        //&proxyURI=yyy
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
             //if ((entitiesDicts[q[@"custodianOID"]])[@"local"])
             custodianURI=[NSString stringWithFormat:@"http://localhost:%lld",port];
             //else custodianURI=(entitiesDicts[q[@"custodianOID"]])[@"custodianglobaluri"];
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
                 NSString *additionalParameters=(entitiesDicts[q[@"custodianOID"]])[@"wadoadditionalparameters"];
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
*/
#pragma mark -
#pragma mark run
        NSError *error=nil;
        
        [httpdicomServer startWithPort:port maxPendingConnections:16 error:&error];
        while (true) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
        }        
    }//end autorelease pool
}
