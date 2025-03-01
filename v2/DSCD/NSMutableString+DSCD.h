//
//  NSMutableString+DSCD.h
//  httpdicom
//
//  Created by jacquesfauquex on 20171217.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableString (DSCD)

-(void)appendDSCDprefix;
-(void)appendSCDprefix;
-(void)appendCDAprefix;
-(void)appendCDAsuffix;
-(void)appendSCDsuffix;
-(void)appendDSCDsuffix;

-(void)appendCDATemplateId:(NSString*)UIDString;
-(void)appendCDAID:(NSString*)CDAID;

-(void)appendRequestCDATitle:(NSString*)title;
-(void)appendReportCDATitle:(NSString*)title;

-(void)appendCurrentCDAEffectiveTime;
-(void)appendNormalCDAConfidentialityCode;
-(void)appendEsCDALanguageCode;
-(void)appendFirstCDAVersionNumber;

-(void)appendCDARecordTargetWithPid:(NSString*)pid
                             issuer:(NSString*)issuer
                          apellido1:(NSString*)apellido1
                          apellido2:(NSString*)apellido2
                            nombres:(NSString*)nombres
                                sex:(NSString*)sex
                          birthdate:(NSString*)birthdate;

-(void)appendCDAAuthorInstitution:(NSString*)institution
                          service:(NSString*)service
                             user:(NSString*)user;

-(void)appendCDAAuthorTime:(NSString*)time
                      root:(NSString*)root
                 extension:(NSString*)extension
                     given:(NSString*)given
                    family:(NSString*)family
                     orgid:(NSString*)orgid
                   orgname:(NSString*)orgname;

-(void)appendCDAAuthorAnonymousOrgid:(NSString*)orgid
                             orgname:(NSString*)orgname;

-(void)appendCDACustodianOid:(NSString*)oid
                        name:(NSString*)name;

-(void)appendCDAInformationRecipient:(NSString*)ReferringPhysiciansName1;

-(void)appendCDAInFulfillmentOfOrder:(NSString*)AccessionNumber1 issuerOID:(NSString*)issuerOID;

-(void)appendCDADocumentationOfNotCoded:(NSString*)StudyDescription1;
-(void)appendCDADocumentationOf:(NSString*)StudyDescription1 fromPacsProcedureDict:(NSDictionary*)pacsProcedureDict procedureIndex:(NSUInteger)procedureIndex schemeIndex:(NSUInteger)schemeIndex;

-(void)appendCDAComponentOfEncompassingEncounterEffectiveTime:(NSString*)DT;


/*
-(void)appendCdaRequestFrom:(NSString*)requesterName
                     issuer:(NSString*)issuer
            accessionNumber:(NSString*)accessionNumber
                   studyUID:(NSString*)studyUID
                       code:(NSString*)code
                     system:(NSString*)system
                    display:(NSString*)display
                   datetime:(NSString*)DT;


-(void)appendComponentofWithSnomedCode:(NSString*)snomedCode
                         snomedDisplay:(NSString*)snomedDisplay
                                 lowDA:(NSString*)lowDA
                                highDA:(NSString*)highDA
                           serviceCode:(NSString*)serviceCode
                           serviceName:(NSString*)serviceName;
*/

-(void)appendEmptyCDAComponent;

-(void)appendCDAComponentWithText:(NSString*)text;
-(void)appendCDAComponentWithBase64Pdf:(NSString*)base64Pdf;
-(void)appendCDAComponentWithTextThumbnail:(NSString*)textThunbnail forBase64Pdf:(NSString*)base64Pdf;

@end
