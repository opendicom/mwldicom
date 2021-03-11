#import <Foundation/Foundation.h>
#import "NSURLComponents+PCS.h"
#import "ODLog.h"
//look at the implementation of the function ODLog below

#import "RS.h"
#import "RSDataResponse.h"
#import "RSErrorResponse.h"
#import "RSFileResponse.h"
#import "RSStreamedResponse.h"
#import "DICMTypes.h"
#import "NSString+PCS.h"
#import "NSData+PCS.h"
#import "NSURLSessionDataTask+PCS.h"
#import "NSMutableURLRequest+PCS.h"
#import "NSMutableString+DSCD.h"
#import "NSUUID+DICM.h"


//static immutable write
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
#pragma mark pacs
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

#pragma mark aet
                 NSUInteger aetIndex=[names indexOfObject:@"aet"];
                 NSString *aet=nil;
                 if (aetIndex!=NSNotFound) aet=values[aetIndex];

#pragma mark Modality
                 NSUInteger ModalityIndex=[names indexOfObject:@"Modality"];
                 if (ModalityIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] Modality required"];
                 NSString *Modality=values[ModalityIndex];
                 if ([@[@"CR",@"CT",@"MR",@"PT",@"XA",@"US",@"MG"] indexOfObject:Modality]==NSNotFound)  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] Modality '%@', should be one of CR,CT,MR,PT,XA,US,MG",Modality];
                 
#pragma mark AccessionNumber
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

#pragma mark StudyDescription
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
                 
                 
#pragma mark PatientName (apellido1, apellido2, nombres)
                 NSMutableString *PatientName=[NSMutableString string];

                 NSUInteger apellido1Index=[names indexOfObject:@"apellido1"];
                 if (apellido1Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'apellido1' required"];
                 NSString *apellido1String=[values[apellido1Index] uppercaseString];
                 [PatientName appendString:apellido1String];
                 
                 NSUInteger apellido2Index=[names indexOfObject:@"apellido2"];
                 NSString *apellido2String=[values[apellido2Index] uppercaseString];
                 if (apellido2Index!=NSNotFound) [PatientName appendFormat:@">%@",apellido2String];
                 
                 NSString *nombresString;
                 NSUInteger nombresIndex=[names indexOfObject:@"nombres"];
                 if (nombresIndex!=NSNotFound)
                 {
                     nombresString=[values[nombresIndex] uppercaseString];
                     [PatientName appendFormat:@"^%@",nombresString];
                 }
                 else nombresString=@"";
                 

#pragma mark PatientID
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
                 

#pragma mark PatientBirthDate
                 NSUInteger PatientBirthDateIndex=[names indexOfObject:@"PatientBirthDate"];
                 if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientBirthDate' required"];
                 NSString *PatientBirthdate=values[PatientBirthDateIndex];
                 if (![DARegex numberOfMatchesInString:PatientBirthdate options:0 range:NSMakeRange(0,[values[PatientBirthDateIndex] length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientBirthDate format should be aaaammdd"];

#pragma mark PatientSex
                 NSUInteger PatientSexIndex=[names indexOfObject:@"PatientSex"];
                 if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientSex' required"];
                 NSString *PatientSexValue=[values[PatientSexIndex]uppercaseString];
                 NSUInteger PatientSexSaluduyIndex=0;
                 if ([PatientSexValue isEqualToString:@"M"])PatientSexSaluduyIndex=1;
                 else if ([PatientSexValue isEqualToString:@"F"])PatientSexSaluduyIndex=2;
                 else if ([PatientSexValue isEqualToString:@"O"])PatientSexSaluduyIndex=9;
                 else  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientSex should be 'M','F' or 'O'"];

#pragma mark - TODO Already exists in the PACS? Is coherent with patients found?

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
#pragma mark PUT patient
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

#pragma mark now
                 NSDate *now=[NSDate date];
                 
#pragma mark Priority
                 NSString *Priority=nil;
                 if ([[values[[names indexOfObject:@"Priority"]] uppercaseString] isEqualToString:@"URGENT"])Priority=@"URGENT";
                 else Priority=@"MEDIUM";

                 
                 
#pragma mark - POST mwlitem
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
#pragma mark - dscd object
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
                     
                     if (!enclosure)
                     {
                         LOG_VERBOSE(@"no 'enclosure'");
                     }
                     else if ([enclosure isEqualToString:@"pdf"])
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

#pragma mark -
#pragma mark run
        NSError *error=nil;
        
        [httpdicomServer startWithPort:port maxPendingConnections:16 error:&error];
        while (true) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
        }        
    }//end autorelease pool
}
