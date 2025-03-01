//
//  DRS.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180112.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

#import "DRS.h"

#import "DRS+wado.h"
#import "DRS+pacs.h"
#import "DRS+mwl.h"
#import "DRS+pdf.h"

#import "DICMTypes.h"

@implementation DRS

static NSDictionary        *_sqls=nil;
static NSDictionary        *_pacs=nil;
static long long           _drsport;
static NSString            *_drspacs;

static NSDictionary        *_oids=nil;
static NSDictionary        *_titles=nil;
static NSData              *_oidsdata=nil;
static NSData              *_titlesdata=nil;
static NSDictionary        *_oidsaeis=nil;
static NSDictionary        *_titlesaets=nil;
static NSDictionary        *_titlesaetsstrings=nil;
static NSDictionary        *_pacsTitlesDictionary=nil;
static NSArray             *_localoids=nil;
static NSDictionary        *_custodianDictionary=nil;



-(id)init{
    return nil;
}

-(id)initWithSqls:(NSDictionary*)sqls
             pacs:(NSDictionary*)pacs
          drsport:(long long)drsport
          drspacs:(NSString*)drspacs
{
    self = [super init];
    if(self) {
        _sqls=sqls;
        _pacs=pacs;
        _drsport=drsport;
        _drspacs=drspacs;

#pragma mark pacs

//TODO classify pacs (sql, dicomweb, dicom, custodian)
        
        NSMutableDictionary *oids=[NSMutableDictionary dictionary];
        NSMutableDictionary *titles=[NSMutableDictionary dictionary];
        for (NSDictionary *d in [pacs allValues])
        {
            NSString *newtitle=d[@"custodiantitle"];
            if (
                !newtitle
                || ![newtitle length]
                || ![K.SHRegex numberOfMatchesInString:newtitle options:0 range:NSMakeRange(0,[newtitle length])]
                )
            {
                NSLog(@"bad custodiantitle");
                return nil;
            }
            
            NSString *newoid=d[@"custodianoid"];
            if (
                !newoid
                || ![newoid length]
                || ![K.UIRegex numberOfMatchesInString:newoid options:0 range:NSMakeRange(0,[newoid length])]
                )
            {
                NSLog(@"bad custodianoid");
                return nil;
            }
            
            if ( oids[newoid] || titles[newtitle])
            {
                //verify if there is no incoherence
                if (
                    ![newtitle isEqualToString:oids[newoid]]
                    || ![newoid isEqualToString:titles[newtitle]]
                    )
                {
                    NSLog(@"pacs incoherence in custodian oid and title ");
                    return nil;
                }
                
            }
            else
            {
                //add custodian
                [oids setObject:newtitle forKey:newoid];
                [titles setObject:newoid forKey:newtitle];
            }
        }
        
        
        
        //response data for root queries custodians/titles and custodians/oids
        _oidsdata = [NSJSONSerialization dataWithJSONObject:[oids allKeys] options:0 error:nil];
        _titlesdata = [NSJSONSerialization dataWithJSONObject:[titles allKeys] options:0 error:nil];
        
        
        
        //pacs OID classified by custodian
        NSMutableDictionary *oidsaeis=[NSMutableDictionary dictionary];
        for (NSString *oid in [oids allKeys])
        {
            NSMutableArray *oidaeis=[NSMutableArray array];
            for (NSString *k in [pacs allKeys])
            {
                NSDictionary *d=[pacs objectForKey:k];
                if ([[d objectForKey:@"custodianoid"]isEqualToString:oid])[oidaeis addObject:k];
            }
            [oidsaeis setValue:oidaeis forKey:oid];
        }
        NSLog(@"\r\nknown pacs OID classified by corresponding custodian OID:\r\n%@",[oidsaeis description]);
        
        
        
        //pacs titles grouped on custodian
        NSMutableDictionary *titlesaets=[NSMutableDictionary dictionary];
        NSMutableDictionary *titlesaetsStrings=[NSMutableDictionary dictionary];
        for (NSString *title in [titles allKeys])
        {
            NSMutableArray *titleaets=[NSMutableArray array];
            NSMutableString *s=[NSMutableString stringWithString:@"("];
            
            for (NSString *k in [pacs allKeys])
            {
                NSDictionary *d=[pacs objectForKey:k];
                if ([[d objectForKey:@"custodiantitle"]isEqualToString:title])
                {
                    [titleaets addObject:[d objectForKey:@"pacstitle"]];
                    if ([s isEqualToString:@"("])
                        [s appendFormat:@"'%@'",[d objectForKey:@"pacstitle"]];
                    else [s appendFormat:@",'%@'",[d objectForKey:@"pacstitle"]];
                }
            }
            [titlesaets setObject:titleaets forKey:title];
            [s appendString:@")"];
            [titlesaetsStrings setObject:s forKey:title];
        }
        NSLog(@"\r\nknown pacs aet classified by corresponding custodian title:\r\n%@",[titlesaets description]);
        
        
        NSMutableDictionary *pacsTitlesDictionary=[NSMutableDictionary dictionary];
        NSMutableArray      *localOIDs=[NSMutableArray array];
        NSMutableDictionary *custodianDictionary=nil;
        for (NSString *key in [pacs allKeys])
        {
            [pacsTitlesDictionary setObject:key forKey:[(pacs[key])[@"custodiantitle"] stringByAppendingPathExtension:(pacs[key])[@"pacstitle"]]];
            
            if ([(pacs[key])[@"sqlprolog"] length]||[(pacs[key])[@"dcm4cheelocaluri"] length])
            {
                [localOIDs addObject:key];
                if ([(pacs[key])[@"custodianoid"] isEqualToString:key]) custodianDictionary=pacs[key];
            }
        }

        _oids=[NSDictionary dictionaryWithDictionary:oids];
        _titles=[NSDictionary dictionaryWithDictionary:titles];
        _oidsaeis=[NSDictionary dictionaryWithDictionary:oidsaeis];
        _titlesaets=[NSDictionary dictionaryWithDictionary:titlesaets];
        _titlesaetsstrings=[NSDictionary dictionaryWithDictionary:titlesaetsStrings];
        _pacsTitlesDictionary=[NSDictionary dictionaryWithDictionary:pacsTitlesDictionary];
        _localoids=[NSArray arrayWithArray:localOIDs];
        _custodianDictionary=[NSDictionary dictionaryWithDictionary:custodianDictionary];

#pragma mark -
#pragma mark handlers
#pragma mark -
        
#pragma mark /
//        [self addWadoHandler];//(default handler)

        
#pragma mark /echo
        [self addHandler:@"GET" path:@"/echo" processBlock:
         ^(RSRequest* request, RSCompletionBlock completionBlock)
         {completionBlock(^RSResponse* (RSRequest* request){
            return [RSDataResponse responseWithText:@"echo"];
        }(request));}];
        LOG_DEBUG(@"added handler /echo");
#pragma mark /(custodians|pacs/titles|pacs/oids)
        [self addCustodiansHandler];//
        LOG_DEBUG(@"added handler /custodians");

#pragma mark /mwlitem
        [self addMWLHandler];
        LOG_DEBUG(@"added handler /mwlitem");        
        LOG_DEBUG(@"-------------");

#pragma mark /pdf
        [self addPDFHandler];
        LOG_DEBUG(@"added handler /pdf /report /informe");
        LOG_DEBUG(@"-------------");
    }
    return self;
}


#pragma mark -
#pragma mark getters

+(NSDictionary*)sqls                 { return _sqls;}
+(NSDictionary*)pacs                 { return _pacs;}
+(long long)drsport                  { return _drsport;}
+(NSString*)drspacs                  { return _drspacs;}

+(NSDictionary*)oids                 { return _oids;}
+(NSDictionary*)titles               { return _titles;}
+(NSData*)oidsdata                   { return _oidsdata;}
+(NSData*)titlesdata                 { return _titlesdata;}
+(NSDictionary*)oidsaeis             { return _oidsaeis;}
+(NSDictionary*)titlesaets           { return _titlesaets;}
+(NSDictionary*)titlesaetsstrings    { return _titlesaetsstrings;}
+(NSDictionary*)pacsTitlesDictionary { return _pacsTitlesDictionary;}
+(NSArray*)localoids                 { return _localoids;}
+(NSDictionary*)custodianDictionary  { return _custodianDictionary;}

@end
