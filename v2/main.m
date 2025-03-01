/*
 syntax:
 [0] mwldicom
 [1] deploypath
 [2] httpdicomport
 [3] loglevel [ DEBUG | VERBOSE | INFO | WARNING | ERROR | EXCEPTION]
 [4] defaultTimezone
 [5] defaultPacs
 */

//
//  Created by jacquesfauquex on 2017-03-20.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

/*
 Copyright:  Copyright (c) 2017 jacques.fauquex@opendicom.com All Rights Reserved.
 
 This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 If a copy of the MPL was not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/
 
 Covered Software is provided under this License on an “as is” basis, without warranty of
 any kind, either expressed, implied, or statutory, including, without limitation,
 warranties that the Covered Software is free of defects, merchantable, fit for a particular
 purpose or non-infringing. The entire risk as to the quality and performance of the Covered
 Software is with You. Should any Covered Software prove defective in any respect, You (not
 any Contributor) assume the cost of any necessary servicing, repair, or correction. This
 disclaimer of warranty constitutes an essential part of this License. No use of any Covered
 Software is authorized under this License except under this disclaimer.
 
 Under no circumstances and under no legal theory, whether tort (including negligence),
 contract, or otherwise, shall any Contributor, or anyone who distributes Covered Software
 as permitted above, be liable to You for any direct, indirect, special, incidental, or
 consequential damages of any character including, without limitation, damages for lost
 profits, loss of goodwill, work stoppage, computer failure or malfunction, or any and all
 other commercial damages or losses, even if such party shall have been informed of the
 possibility of such damages. This limitation of liability shall not apply to liability for
 death or personal injury resulting from such party’s negligence to the extent applicable
 law prohibits such limitation. Some jurisdictions do not allow the exclusion or limitation
 of incidental or consequential damages, so this exclusion and limitation may not apply to
 You.
 */

#import <Foundation/Foundation.h>
#import "K.h" //constants
#import "ODLog.h" //log level init

#import "DRS.h"

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {

        

NSArray *args=[[NSProcessInfo processInfo] arguments];
if ([args count]!=6)
{
    NSLog(@"syntax: httpdicom deploypath httpdicomport loglevel defaultTimezone defaultPacs");
    return 1;
}
        
        
//arg [1] deploypath
NSString *deployPath=[args[1]stringByExpandingTildeInPath];
BOOL isDirectory=FALSE;
if (![[NSFileManager defaultManager]fileExistsAtPath:deployPath isDirectory:&isDirectory] || !isDirectory)
{
    LOG_ERROR(@"deploy folder does not exist");
    return 1;
}

        
        
//arg [2] httpdicomport
long long port=[args[2]longLongValue];
if (port <1 || port>65535)
{
    NSLog(@"port should be between 1 and 65535");
    return 1;
}


        
#pragma mark log level
//arg [3] loglevel
NSUInteger llindex=[@[@"DEBUG",@"VERBOSE",@"INFO",@"WARNING",@"ERROR",@"EXCEPTION"] indexOfObject:args[3]];
if (llindex==NSNotFound)
{
    NSLog(@"ODLogLevel (arg 1) should be one of [ DEBUG | VERBOSE | INFO | WARNING | ERROR | EXCEPTION ]");
    return 1;
}
ODLogLevel=(int)llindex;

 

#pragma mark K init

        
//arg [4] defaultTimezone
NSRegularExpression *TZRegex = [NSRegularExpression regularExpressionWithPattern:@"^[+-][0-2][0-9][0-5][0-9]$" options:0 error:NULL];
if (![TZRegex numberOfMatchesInString:args[4] options:0 range:NSMakeRange(0,[args[4] length])])
{
    NSLog(@"defaultTimezone (arg 4)format should be ^[+-][0-2][0-9][0-5][0-9]$");
    return 1;
}
else [K setDefaultTimezone:args[4]];

        

// /voc/scheme
NSDictionary *scheme=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/scheme.plist"]];
if (!scheme) [K loadScheme:@{}];
else [K loadScheme:scheme];

        
// /voc/code
NSArray *codes=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:[deployPath stringByAppendingPathComponent:@"voc/code/"] error:nil];
if (!codes) LOG_WARNING(@"no folder voc/code into deploy");
else if (![codes count]) LOG_WARNING(@"no code file registered");
else
{
     for (NSString *code in codes)
    {
        if ([code hasPrefix:@"."]) continue;
        [K loadCode:[NSDictionary dictionaryWithContentsOfFile:[[deployPath stringByAppendingPathComponent:@"voc/code"] stringByAppendingPathComponent:code]] forKey:[code stringByDeletingPathExtension]];
    }
    
}
        
// /voc/procedure
NSArray *procedures=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:[deployPath stringByAppendingPathComponent:@"voc/procedure/"] error:nil];
if (!procedures) LOG_WARNING(@"no folder voc/procedure into deploy");
else if (![procedures count]) LOG_WARNING(@"no procedure file registered");
else
{
    for (NSString *procedure in procedures)
    {
        if ([procedure hasPrefix:@"."]) continue;
        [K loadProcedure:[NSDictionary dictionaryWithContentsOfFile:[[deployPath stringByAppendingPathComponent:@"voc/procedure"]stringByAppendingPathComponent:procedure]] forKey:[procedure stringByDeletingPathExtension]];

    }
}
        


        

        
// /voc/country (iso3166)
NSArray *iso3166ByCountry=[NSArray arrayWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/country.plist"]];
if (!iso3166ByCountry)
{
    LOG_ERROR(@"no folder voc/country.plist into deploy");
    return 1;
}
else [K loadIso3166ByCountry:iso3166ByCountry];

        

// /voc/personIDType (ica)
NSDictionary *personIDTypes=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"voc/personIDType.plist"]];
if (!personIDTypes)
{
    LOG_ERROR(@"no folder voc/personIDType.plist into deploy");
    return 1;
}
else [K loadPersonIDTypes:personIDTypes];


        
#pragma mark DRS params
        
        
// /pacs (also called device)
NSDictionary *pacs=[NSDictionary dictionaryWithContentsOfFile:[deployPath stringByAppendingPathComponent:@"pacs.plist"]];
if (!pacs)
{
    NSLog(@"could not get contents of pacs.plist");
    return 1;
}

        
        
//arg [5] defaultpacs
NSString *drspacs=args[5];
if (!pacs[args[5]])
{
    NSLog(@"defaultpacs OID not in pacs dictionary");
            return 1;
}
        


        
// /sql/map
NSMutableSet *sqlset=[NSMutableSet set];
for (NSDictionary *d in [pacs allValues])
{
    if (![d[@"sqlmap"] isEqualToString:@""]) [sqlset addObject:d[@"sqlmap"]];
}
NSMutableDictionary *sqls=[NSMutableDictionary dictionary];
for (NSString *sqlname in sqlset)
{
    NSString *sqlpath=[[deployPath
                        stringByAppendingPathComponent:@"sql/map"]
                       stringByAppendingPathComponent:sqlname];
    NSDictionary *sqlDict=[[NSDictionary alloc] initWithContentsOfFile:sqlpath];
    if (!sqlDict)
    {
        LOG_ERROR(@"%@ unavailable",sqlname);
        return 1;
    }
    
    [sqls setObject:sqlDict forKey:sqlname];
}


        

        
#pragma mark server init and run
        

        DRS *drs=[[DRS alloc] initWithSqls:sqls
                                      pacs:pacs
                                   drsport:port
                                   drspacs:drspacs
                  ];


        if (!drs)
        {
            NSLog(@"could not add DRS handlers to rest server");
            return 1;
        }

        NSError *error=nil;
        [drs startWithPort:port maxPendingConnections:16 error:&error];
        if (error != nil)
        {
            NSLog(@"could not start server on port:%lld. %@",port,[error description]);
            return 1;
        }

        while (true) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
        }
        return 0;//OK
    }//end autorelease pool
}
