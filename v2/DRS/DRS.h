//
//  DRS.h
//  httpdicom
//
//  Created by jacquesfauquex on 20180112.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

/*
wado/encapsulated

pacs

fidji
 qido
 weasis
 datatables
 iheiid
 
 wadors/zipped
 
mwl
 
*/

#import <Foundation/Foundation.h>
#import "ODLog.h"
#import "K.h"

#import "RS.h"
#import "RSDataResponse.h"
#import "RSErrorResponse.h"
#import "RSFileResponse.h"
#import "RSStreamedResponse.h"



@interface DRS : RS

@property (class, nonatomic, readonly) NSDictionary          *sqls;
@property (class, nonatomic, readonly) NSDictionary          *pacs;
@property (class, nonatomic, readonly, assign) long long      drsport;
@property (class, nonatomic, readonly) NSString              *drspacs;
@property (class, nonatomic, readonly) NSDictionary          *oids;
@property (class, nonatomic, readonly) NSDictionary          *titles;
@property (class, nonatomic, readonly) NSData                *oidsdata;
@property (class, nonatomic, readonly) NSData                *titlesdata;
@property (class, nonatomic, readonly) NSDictionary          *oidsaeis;
@property (class, nonatomic, readonly) NSDictionary          *titlesaets;
@property (class, nonatomic, readonly) NSDictionary          *titlesaetsstrings;
@property (class, nonatomic, readonly) NSDictionary          *pacsTitlesDictionary;
@property (class, nonatomic, readonly) NSArray               *localoids;
@property (class, nonatomic, readonly) NSDictionary          *custodianDictionary;


-(id)initWithSqls:(NSDictionary*)sqls
             pacs:(NSDictionary*)pacs
          drsport:(long long)drsport
          drspacs:(NSString*)drspacs;

@end



/*
 #pragma mark TODO classify pacs
 // sql, dicomweb, dicom, custodian
 
 for (NSDictionary *d in [pacs allValues])
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
 LOG_ERROR(@"pacs incoherence in custodian oid and title ");
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
 
 
 //pacs OID classified by custodian
 NSMutableDictionary *custodianOIDsaeis=[NSMutableDictionary dictionary];
 for (NSString *custodianOID in [custodianoids allKeys])
 {
 NSMutableArray *custodianOIDaeis=[NSMutableArray array];
 for (NSString *k in [pacs allKeys])
 {
 NSDictionary *d=[pacs objectForKey:k];
 if ([[d objectForKey:@"custodianoid"]isEqualToString:custodianOID])[custodianOIDaeis addObject:k];
 }
 [custodianOIDsaeis setValue:custodianOIDaeis forKey:custodianOID];
 }
 LOG_VERBOSE(@"known pacs OID classified by corresponding custodian OID:\r\n%@",[custodianOIDsaeis description]);
 
 //pacs titles grouped on custodian
 NSMutableDictionary *custodianTitlesaets=[NSMutableDictionary dictionary];
 NSMutableDictionary *custodianTitlesaetsStrings=[NSMutableDictionary dictionary];
 for (NSString *custodianTitle in [custodiantitles allKeys])
 {
 NSMutableArray *custodianTitleaets=[NSMutableArray array];
 NSMutableString *s=[NSMutableString stringWithString:@"("];
 
 for (NSString *k in [pacs allKeys])
 {
 NSDictionary *d=[pacs objectForKey:k];
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
 LOG_VERBOSE(@"known pacs aet classified by corresponding custodian title:\r\n%@",[custodianTitlesaets description]);
 
 NSMutableDictionary *pacsTitlesDictionary=[NSMutableDictionary dictionary];
 NSMutableArray *localOIDs=[NSMutableArray array];
 NSDictionary *custodianDictionary=nil;
 for (NSString *key in [pacs allKeys])
 {
 [pacsTitlesDictionary setObject:key forKey:[(pacs[key])[@"custodiantitle"] stringByAppendingPathExtension:(pacs[key])[@"dicomaet"]]];
 
 if ([(pacs[key])[@"local"] boolValue])
 {
 [localOIDs addObject:key];
 if ([(pacs[key])[@"custodianoid"] isEqualToString:key]) custodianDictionary=pacs[key];
 }
 }
 */

