#import "K.h"
#import "NSDictionary+PCS.h"

@implementation K

static NSRegularExpression *_PPPRegex=nil;
static NSRegularExpression *_DARegex=nil;
static NSRegularExpression *_SHRegex=nil;
static NSRegularExpression *_UIRegex=nil;
static NSRegularExpression *_TZRegex=nil;

static NSArray             *_levels;

static NSArray             *_key;
static NSArray             *_tag;
static NSArray             *_vr;

static NSArray             *_modalities;

static NSString            *_defaultTimezone=nil;

static NSDictionary        *_scheme=nil;
static NSDictionary        *_schemeindexes=nil;
static NSMutableDictionary *_code=nil;
static NSMutableDictionary *_codeindexes=nil;
static NSMutableDictionary *_procedure=nil;
static NSMutableDictionary *_procedureindexes=nil;

static NSArray             *_iso3166=nil;//contries
static NSDictionary        *_personidtype=nil;//icaa documents

# pragma mark - init

+ (void)initialize {
    _code=[NSMutableDictionary dictionary];
    _codeindexes=[NSMutableDictionary dictionary];
    _procedure=[NSMutableDictionary dictionary];
    _procedureindexes=[NSMutableDictionary dictionary];
    _TZRegex = [NSRegularExpression regularExpressionWithPattern:@"^[+-][0-2][0-9][0-5][0-9]$" options:0 error:NULL];
    _UIRegex = [NSRegularExpression regularExpressionWithPattern:@"^[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*$" options:0 error:NULL];
    _SHRegex = [NSRegularExpression regularExpressionWithPattern:@"^(?:\\s*)([^\\r\\n\\f\\t]*[^\\r\\n\\f\\t\\s])(?:\\s*)$" options:0 error:NULL];
    _DARegex = [NSRegularExpression regularExpressionWithPattern:@"^(19|20)\\d\\d(01|02|03|04|05|06|07|08|09|10|11|12)(01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$" options:0 error:NULL];
    _PPPRegex = [NSRegularExpression regularExpressionWithPattern:@"(ab)" options:0 error:NULL];

    _modalities=@[@"CR",@"CT",@"MR",@"PT",@"XA",@"US",@"MG",@"RF",@"DX",@"EPS"];
    
    _levels=@[@"/patients",@"/studies",@"/series",@"/instances"];

    _key=@[
           @"IssuerOfPatientID",//0
           @"IssuerOfPatientIDQualifiersSequence.LocalNamespaceEntityID",//1
           @"IssuerOfPatientIDQualifiersSequence.UniversalEntityID",//2
           @"IssuerOfPatientIDQualifiersSequence.UniversalEntityIDType",//3
           @"PatientID",//4
           @"PatientName",//5
           @"PatientBirthDate",//6
           @"PatientSex",//7
           @"",//8
           @"",//9
           @"",//10
           @"",//11
           @"",//12
           @"",//13
           @"",//14
           @"",//15
           @"",//16
           @"ProcedureCodeSequence.CodeValue",//17
           @"ProcedureCodeSequence.CodingSchemeDesignator",//18
           @"ProcedureCodeSequence.CodeMeaning",//19
           @"StudyInstanceUID",//20
           @"StudyDescription",//21
           @"StudyDate",//22
           @"StudyTime",//23
           @"StudyID",//24
           @"",//25
           @"",//26
           @"",//27
           @"",//28
           @"AccessionNumber",//29
           @"IssuerOfAccessionNumberSequence.LocalNamespaceEntityID",//30
           @"IssuerOfAccessionNumberSequence.UniversalEntityID",//31
           @"IssuerOfAccessionNumberSequence.UniversalEntityIDType",//32
           @"ReferringPhysicianName",//33
           @"NameofPhysiciansrStudy",//34
           @"ModalitiesInStudy",//35
           @"NumberOfStudyRelatedSeries",//36
           @"NumberOfStudyRelatedInstances",//37
           @"",//38
           @"",//39
           @"SeriesInstanceUID",//40
           @"Modality",//41
           @"SeriesDescription",//42
           @"SeriesNumber",//43
           @"BodyPartExamined",//44
           @"",//45
           @"",//46
           @"StationName",//47
           @"InstitutionalDepartmentName",//48
           @"InstitutionName",//49
           @"Performing​Physician​Name",//50
           @"",//51
           @"InstitutionCodeSequence.CodeValue",//52
           @"InstitutionCodeSequence.schemeDesignator",//53
           @"",//54
           @"PerformedProcedureStepStartDate",//55
           @"PerformedProcedureStepStartTime",//56
           @"RequestAttributeSequence.ScheduledProcedureStepID",//57
           @"RequestAttributeSequence.RequestedProcedureID",//58
           @"NumberOfSeriesRelatedInstances",//59
           @"SOPInstanceUID",//60
           @"SOPClassUID",//61
           @"InstanceNumber",//62
           @"HL7InstanceIdentifier",//63
           @""//64
           ];
    _tag=@[
           @"00100021",//0
           @"00100024.00400031",//1
           @"00100024.00400032",//2
           @"00100024.00400033",//3
           @"00100020",//4
           @"00100010",//5
           @"00100030",//6
           @"00100040",//7
           @"",//8
           @"",//9
           @"",//10
           @"",//11
           @"",//12
           @"",//13
           @"",//14
           @"",//15
           @"",//16
           @"00081032.00080100",//17
           @"00081032.00080102",//18
           @"00081032.00080104",//19
           @"0020000D",//20
           @"00081030",//21
           @"00080020",//22
           @"00080030",//23
           @"00200010",//24
           @"",//25
           @"",//26
           @"",//27
           @"",//28
           @"00080050",//29
           @"00080051.00400031",//30
           @"00080051.00400032",//31
           @"00080051.00400033",//32
           @"00080090",//33
           @"00081060",//34
           @"00080061",//35
           @"00201206",//36
           @"00201208",//37
           @"",//38
           @"",//39
           @"0020000E",//40
           @"00080060",//41
           @"0008103E",//42
           @"00200011",//43
           @"00180015",//44
           @"",//45
           @"",//46
           @"00081010",//47
           @"00081040",//48
           @"00080080",//49
           @"00081050",//50
           @"",//51
           @"00080082.00080100",//52
           @"00080082.00080102",//53
           @"",//54
           @"00400244",//55
           @"00400245",//56
           @"00400275.00400009",//57
           @"00400275.00401001",//58
           @"00201209",//59
           @"00080018",//60
           @"00080016",//61
           @"00200013",//62
           @"0040E001",//63
           @""//64
           ];
    _vr=@[
          @"LO",//0
          @"UT",//1
          @"UT",//2
          @"CS",//3
          @"LO",//4
          @"PN",//5
          @"DA",//6
          @"CS",//7
          @"",//8
          @"",//9
          @"",//10
          @"",//11
          @"",//12
          @"",//13
          @"",//14
          @"",//15
          @"",//16
          @"SH",//17
          @"SH",//18
          @"LO",//19
          @"UI",//20
          @"LO",//21
          @"DA",//22
          @"TM",//23
          @"SH",//24
          @"",//25
          @"",//26
          @"",//27
          @"",//28
          @"SH",//29
          @"UT",//30
          @"UT",//31
          @"CS",//32
          @"PN",//33
          @"PN",//34
          @"CS",//35
          @"IS",//36
          @"IS",//37
          @"",//38
          @"",//39
          @"UI",//40
          @"CS",//41
          @"LO",//42
          @"IS",//43
          @"CS",//44
          @"",//45
          @"",//46
          @"SH",//47
          @"LO",//48
          @"LO",//49
          @"PN",//50
          @"",//51
          @"SH",//52
          @"SH",//53
          @"",//54
          @"DA",//55
          @"TM",//56
          @"SH",//57
          @"SH",//58
          @"IS",//59
          @"UI",//60
          @"UI",//61
          @"IS",//62
          @"ST",//63
          @""//64
          ];
}

+(void)setDefaultTimezone:(NSString*)defaultTimezone
{
    _defaultTimezone=defaultTimezone;
}

+(void)loadIso3166ByCountry:(NSArray*)country
{
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
    for (NSArray *countryArray in country)
    {
        [iso3166PAIS addObject:countryArray[0]];
        [iso3166COUNTRY addObject:countryArray[1]];
        [iso3166AB addObject:countryArray[2]];
        [iso3166ABC addObject:countryArray[3]];
        [iso3166XXX addObject:countryArray[4]];
    }
    _iso3166=@[iso3166PAIS,iso3166COUNTRY,iso3166AB,iso3166ABC,iso3166XXX];
}

+(void)loadPersonIDTypes:(NSDictionary*)personidtype
{
    _personidtype=personidtype;
}

+(void)loadScheme:(NSDictionary*)scheme
{
    _schemeindexes=[NSDictionary da4dd:scheme];
    _scheme=scheme;
}

+(void)loadCode:(NSDictionary*)code forKey:(NSString*)key
{
    [_codeindexes setObject:[NSDictionary da4dd:code] forKey:key];
    [_code setObject:code forKey:key];
}

+(void)loadProcedure:(NSDictionary*)procedure forKey:(NSString*)key
{
    [_procedureindexes setObject:[NSDictionary da4dd:procedure] forKey:key];
    [_procedure setObject:procedure forKey:key];
}


#pragma mark - getters

+(NSRegularExpression*)PPPRegex       { return _DARegex;}
+(NSRegularExpression*)DARegex       { return _DARegex;}
+(NSRegularExpression*)SHRegex       { return _SHRegex;}
+(NSRegularExpression*)UIRegex       { return _UIRegex;}
+(NSRegularExpression*)TZRegex       { return _TZRegex;}

+(NSArray*)levels                    { return _levels;}
+(NSString*)defaultTimezone          { return _defaultTimezone;}

+(NSArray*)key                       { return _key;}
+(NSArray*)tag                       { return _tag;}
+(NSArray*)vr                        { return _vr;}

+(NSArray*)modalities                        { return _modalities;}

+(NSDictionary*)scheme               { return _scheme;}
+(NSDictionary*)schemeindexes        { return _schemeindexes;}
+(NSDictionary*)code                 { return _code;}
+(NSDictionary*)codeindexes          { return _codeindexes;}
+(NSDictionary*)procedure            { return _procedure;}
+(NSDictionary*)procedureindexes     { return _procedureindexes;}
+(NSArray*)iso3166                   { return _iso3166;}
+(NSDictionary*)personidtype         { return _personidtype;}


+(NSUInteger)indexOfAttribute:(NSString*)refString
{
    if ([_key indexOfObject:refString]!=NSNotFound) return [_key indexOfObject:refString];
    return [_tag indexOfObject:refString];
}

@end
