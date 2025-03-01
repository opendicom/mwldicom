//
//  DRS+mwl.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180116.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+functions.h"
#import "DRS+mwl.h"
#import "K.h"

#import "NSData+PCS.h"
#import "NSString+PCS.h"
#import "NSURLSessionDataTask+PCS.h"
#import "DICMTypes.h"
#import "NSMutableString+DSCD.h"
#import "NSDictionary+DICM.h"
#import "NSMutableData+DICM.h"
#import "NSUUID+DICM.h"

#import "NSMutableURLRequest+MWL.h"
#import "NSMutableURLRequest+patient.h"
#import "NSMutableURLRequest+instance.h"
#import "NSMutableURLRequest+html5dicom.h"


@implementation DRS (mwl)

const uint8 SB=0x0B;
const uint8 EB=0x1C;
const uint8 CR=0x0D;

-(void)addMWLHandler
{
[self addHandler:@"POST" path:@"/mwlitem" processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
{
    NSMutableString* html = [NSMutableString stringWithString:@"<html><head><title>response</title></head><body>"];

#pragma mark params
    NSMutableArray *names=[NSMutableArray array];
    NSMutableArray *values=[NSMutableArray array];
    NSMutableArray *types=[NSMutableArray array];
    NSString *errorString=nil;
    if (!requestParams(request, names, values, types, &errorString))
    {
        LOG_WARNING(@"[mwlitem]<request> params error: %@",errorString);
        return [RSErrorResponse responseWithClientError:404 message:@"%@",errorString];
    }
    unsigned long lastIndex=names.count ;
    if (lastIndex==values.count)
    {
        LOG_DEBUG(@"[mwlitem]<request>");
        for (int i =0; i < lastIndex; i++)
        {
            if ([names[i] isEqualToString:@"enclosurePdf"])
                LOG_DEBUG(@"%@:%lu bytes",names[i],(unsigned long)[values[i] length]);
            else if ([names[i] isEqualToString:@"nombre"]);
            else if ([names[i] isEqualToString:@"modalidad"]);
            else if ([names[i] isEqualToString:@"issuerLocal"]);
            else if ([names[i] isEqualToString:@"issuerTipo"]);
            else if ([names[i] isEqualToString:@"PatientBirthDate"]);
            else if ([names[i] isEqualToString:@"PatientIDType"]);
            else if ([names[i] isEqualToString:@"issuerUniversal"]);
            else if ([names[i] isEqualToString:@"PatientIDCountry"]);
            else if ([names[i] isEqualToString:@"Priority"]);
            else if ([names[i] isEqualToString:@"NameofPhysicianReadingStudy"])
                LOG_DEBUG(@"%@:                     %@",names[i],values[i]);
            else
                LOG_DEBUG(@"%@:%@",names[i],values[i]);
        }
        
        if (lastIndex==2)
        {
#pragma mark reporting physician change
            NSString *rad=nil;
            NSString *an=nil;
            if ([names[0] isEqualToString:@"NameofPhysicianReadingStudy"])
            {
                //if ([K.PPPRegex numberOfMatchesInString:values[0] options:0 range:NSMakeRange(0,[values[0] length])]==1)
                    rad=values[0];
                if ([names[1] isEqualToString:@"AccessionNumber"])
                {
                    //if ([K.UIRegex numberOfMatchesInString:values[1] options:0 range:NSMakeRange(0,[values[1] length])]==1)
                    an=values[1];
                }
            }
            else if ([names[1] isEqualToString:@"NameofPhysicianReadingStudy"])
            {
                //if ([K.PPPRegex numberOfMatchesInString:values[1] options:0 range:NSMakeRange(0,[values[1] length])]==1)
                    rad=values[1];
                if ([names[0] isEqualToString:@"AccessionNumber"])
                {
                    //if ([K.UIRegex numberOfMatchesInString:values[0] options:0 range:NSMakeRange(0,[values[0] length])]==1)
                    an=values[0];
                }
            }
            
            if (rad && an)
            {
               //do it
                NSString *sql=[NSString stringWithFormat:@"export MYSQL_PWD=pacs;/usr/local/mysql/bin/mysql -upacs -h 127.0.0.1 -b pacsdb -e \"UPDATE study SET study_custom3='%@' WHERE accession_no='%@';\"",rad,an];
                NSLog(@"%@",sql);
                NSMutableData *sqlResp=[NSMutableData data];
                if (bash([sql dataUsingEncoding:NSUTF8StringEncoding],sqlResp))
                    [html appendFormat:@"<p>an:%@ udpate to rad:'%@' failed. %@</p>",an,rad,[[NSString alloc] initWithData:sqlResp encoding:NSUTF8StringEncoding] ];
                else [html appendFormat:@"<p>an:%@ new rad:%@</p>",an,rad];
            }
            else
            {
                [html appendFormat:@"<p>bad params</p><p>%@:%@</p><p>%@:%@</p>",names[0],values[0],names[1],values[1] ];
            }
        }
        else
        {
#pragma mark new worklistitem
            
        #pragma mark validation pacs
            NSString *pacsUID1=nil;
            NSDictionary *pacs=nil;

            NSUInteger pacsIndex=[names indexOfObject:@"pacs"];
            if (pacsIndex!=NSNotFound)
            {
                pacsUID1=values[pacsIndex];
                if (![K.UIRegex numberOfMatchesInString:pacsUID1 options:0 range:NSMakeRange(0,[pacsUID1 length])])
                    return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacsUID '%@' should be an OID",pacsUID1];
                pacs=DRS.pacs[pacsUID1];
                if (!pacs) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' not known",pacsUID1];
                
                //dcm4cheelocaluri available?
                if (
                      !pacs[@"dcm4cheelocaluri"]
                    ||![pacs[@"dcm4cheelocaluri"] length]
                    ) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' is not a dcm4chee-arc",pacsUID1];
                LOG_VERBOSE(@"[mwlitem] <pacs> %@",pacsUID1);
            }
            else
            {
                pacsUID1=DRS.drspacs;
                pacs=DRS.pacs[DRS.drspacs];
                LOG_VERBOSE(@"[mwlitem] <pacs> %@ (default)",pacsUID1);
            }
            
            //pacs.dcm4cheelocaluri
            NSString *dcm4cheelocaluri=dcm4cheelocaluri=pacs[@"dcm4cheelocaluri"];
            
            
        #pragma mark validation service
            //(was sala)
            NSString *service1Title=nil;
            NSUInteger serviceIndex=[names indexOfObject:@"servicio"];
            NSUInteger salaIndex=[names indexOfObject:@"sala"];
            if (serviceIndex!=NSNotFound) service1Title=[values[serviceIndex]spaceNormalize];
            else if (salaIndex!=NSNotFound) service1Title=[values[salaIndex]spaceNormalize];
            
            NSDictionary *service1Dict=(pacs[@"services"])[service1Title];
            NSArray *service1Modalities=nil;
            NSString *ScheduledStationAETitle=nil;
            if (service1Dict)
            {
                service1Modalities=service1Dict[@"modalities"];
                ScheduledStationAETitle=service1Dict[@"StationAETitle"];
            } else if (service1Title) ScheduledStationAETitle=service1Title;
            
            //modality
            NSString *Modality1=nil;
            NSUInteger modalidadIndex=[names indexOfObject:@"modalidad"];
            if (modalidadIndex==NSNotFound)
            {
                if ([service1Modalities count]!=1) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] modality required"];
                Modality1=service1Modalities[0];
            }
            else if (service1Modalities)
            {
                NSString *modalidadBuscada=nil;
                if      ([values[modalidadIndex]isEqualToString:@"RM"]) modalidadBuscada=@"MR";
                else if ([values[modalidadIndex]isEqualToString:@"TC"]) modalidadBuscada=@"CT";
                else                                                    modalidadBuscada=values[modalidadIndex];

                if ([service1Modalities indexOfObject:modalidadBuscada]==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] modalidad %@ not available in sala %@",values[modalidadIndex],ScheduledStationAETitle];
                    Modality1=values[modalidadIndex];
            }
            else if ([K.modalities indexOfObject:values[modalidadIndex]]==NSNotFound)  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] Modality '%@', should be one of %@",values[modalidadIndex], [K.modalities description]];
            else Modality1=values[modalidadIndex];
            if (!ScheduledStationAETitle && !Modality1)  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] sala and/or modalidad required"];
            LOG_VERBOSE(@"[mwlitem] <service> %@ <modality> %@",service1Title,Modality1);

            
        #pragma mark validation AccessionNumber
            NSUInteger AccessionNumberIndex=[names indexOfObject:@"AccessionNumber"];
            if (AccessionNumberIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber required"];
            NSString *AccessionNumber1=values[AccessionNumberIndex];
            
            if (![K.SHRegex numberOfMatchesInString:AccessionNumber1 options:0 range:NSMakeRange(0,[values[AccessionNumberIndex] length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
            
            //Already exists in the PACS?
            NSData *AccessionNumberUnique=[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rs/mwlitems?AccessionNumber=%@",dcm4cheelocaluri,AccessionNumber1]]];
            if (   AccessionNumberUnique
                &&[AccessionNumberUnique length])
            {
                 NSError *arrayOfDictsError=nil;
                NSArray *arrayOfDicts=[NSJSONSerialization JSONObjectWithData:AccessionNumberUnique options:0 error:&arrayOfDictsError];
                if (
                    !arrayOfDictsError
                    && [arrayOfDicts count]
                    )
                {
                    LOG_VERBOSE(@"[mwlitem] already exists\r\n%@\r\n ",[[NSString alloc]initWithData:AccessionNumberUnique encoding:NSUTF8StringEncoding]);
                    return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber '%@' already exists in pacs '%@'",AccessionNumber1,pacsUID1];
                }
                LOG_WARNING(@"[mwlitem] <AN> GET %@ <-\r\n%@\r\n ",AccessionNumber1,[[NSString alloc]initWithData:AccessionNumberUnique encoding:NSUTF8StringEncoding]);
            }
            LOG_VERBOSE(@"[mwlitem] <accession> %@",AccessionNumber1);

            
            
        #pragma mark validation StudyDescription
            NSDictionary *pacsProcedureDict=nil;
            NSInteger procedureIndex=NSNotFound;
            //K.schemeindexes
            NSUInteger schemeIndex=NSNotFound;//depending on the usage (dicom, CDA, etc) the scheme may have diferent name !

            NSUInteger StudyDescriptionIndex=[names indexOfObject:@"StudyDescription"];
            NSString *StudyDescription1=nil;
            NSArray *StudyDescription1Array=nil;
            if (StudyDescriptionIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] studyDescription required"];
            else
            {
                StudyDescription1=[values[StudyDescriptionIndex]spaceNormalize];
                StudyDescription1Array=[StudyDescription1 componentsSeparatedByString:@"^"];
                if ([StudyDescription1Array count]!=3) LOG_WARNING(@"[mwlitem] <title> outside catalog: %@",StudyDescription1);
                else
                {
                    //scheme
                    NSString *filter=StudyDescription1Array[1];
                    schemeIndex=[K.schemeindexes[@"key"] indexOfObject:filter];
                    if (schemeIndex==NSNotFound)
                    {
                        schemeIndex=[K.schemeindexes[@"oid"] indexOfObject:filter];
                        if (schemeIndex==NSNotFound)
                        {
                            schemeIndex=[K.schemeindexes[@"shortname"] indexOfObject:filter];
                            if (schemeIndex==NSNotFound)
                            {
                                schemeIndex=[K.schemeindexes[@"dcm"] indexOfObject:filter];
                                if (schemeIndex==NSNotFound) schemeIndex=[K.schemeindexes[@"hl7v2"] indexOfObject:filter];
                            }
                        }
                    }
                    if (schemeIndex==NSNotFound)  LOG_WARNING(@"[mwlitem] code scheme '%@' not known",filter);
                    else
                    {
                        //schemeIndex found
                    
                        pacsProcedureDict=K.procedureindexes[pacsUID1];
                        NSString *thisCode=StudyDescription1Array[0];
                    
                        //try with key (=code)
                        procedureIndex=[pacsProcedureDict[@"key"] indexOfObject:thisCode];
                        if (procedureIndex==NSNotFound)
                        {
                            //try with shortname
                            procedureIndex=[pacsProcedureDict[@"shortname"] indexOfObject:thisCode];
                            if (procedureIndex==NSNotFound)
                            {
                                //try with displayname
                                procedureIndex=[pacsProcedureDict[@"displayname"] indexOfObject:StudyDescription1Array[2]];
                                if (procedureIndex==NSNotFound)
                                {
                                    //try with corresponding code and select if there is one correspondance only
                                    NSUInteger codesCount=[pacsProcedureDict[@"codes"] count];
                                    for (NSUInteger i=0;i<codesCount;i++)
                                    {
                                        NSArray *theseCorrespondingCodes=[(pacsProcedureDict[@"codes"])[i] allValues];
                                        if ((procedureIndex==NSNotFound)&&([theseCorrespondingCodes indexOfObject:thisCode]!=NSNotFound)) procedureIndex=i;
                                        else if ([theseCorrespondingCodes indexOfObject:thisCode]!=NSNotFound)
                                        {
                                            procedureIndex=NSNotFound;
                                            LOG_WARNING(@"[mwlitem] study description includes an ambiguous code which belongs to various procedures: %@",StudyDescription1);
                                            break;
                                        }
                                    }
                                    procedureIndex=[pacsProcedureDict[@"displayname"] indexOfObject:thisCode];
                                }
                            }
                        }
                    }
                    //no match at all
                    if (procedureIndex==NSNotFound) LOG_WARNING(@"[mwlitem] code '%@' not known in pacs %@",StudyDescription1Array[0], pacsUID1);
                    else LOG_VERBOSE(@"[mwlitem] <procedure> %@",StudyDescription1Array[0]);
                }
            }

            
        #pragma mark patient validation
            NSMutableString *PatientName1=[NSMutableString string];
            
            NSUInteger apellido1Index=[names indexOfObject:@"apellido1"];
            if (apellido1Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'apellido1' required"];
            NSString *apellido1String=[[values[apellido1Index] uppercaseString]spaceNormalize];
            [PatientName1 appendString:apellido1String];
            
            NSUInteger apellido2Index=[names indexOfObject:@"apellido2"];
            NSString *apellido2String=[[values[apellido2Index] uppercaseString]spaceNormalize];
            if (apellido2Index!=NSNotFound) [PatientName1 appendFormat:@">%@",apellido2String];
            
            NSUInteger nombresIndex=[names indexOfObject:@"nombres"];
            NSString *nombresString=[[values[nombresIndex] uppercaseString]spaceNormalize];
            
            if (nombresIndex!=NSNotFound) [PatientName1 appendFormat:@"^%@",nombresString];
            
            
            //PatientID
            NSUInteger IDCountryIndex=[names indexOfObject:@"PatientIDCountry"];
            if (IDCountryIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientIDCountry' required"];
            
            NSString *IDCountryValue=[values[IDCountryIndex] uppercaseString];
            
            NSUInteger iso3166Index=NSNotFound;
            iso3166Index=[K.iso3166[PAIS] indexOfObject:IDCountryValue];
            if (iso3166Index==NSNotFound)
            {
                iso3166Index=[K.iso3166[COUNTRY] indexOfObject:IDCountryValue];
                if (iso3166Index==NSNotFound)
                {
                    iso3166Index=[K.iso3166[AB] indexOfObject:IDCountryValue];
                    if (iso3166Index==NSNotFound)
                    {
                        iso3166Index=[K.iso3166[ABC] indexOfObject:IDCountryValue];
                        if (iso3166Index==NSNotFound)
                        {
                            iso3166Index=[K.iso3166[XXX] indexOfObject:IDCountryValue];
                            if (iso3166Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientID Country '%@' not valid",IDCountryValue];
                        }
                    }
                }
            }
            
            NSUInteger PatientIDTypeIndex=[names indexOfObject:@"PatientIDType"];
            if (PatientIDTypeIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientIDType' required"];
            if ([[K.personidtype allKeys] indexOfObject:values[PatientIDTypeIndex]]==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientIDType '%@' unknown",values[PatientIDTypeIndex]];
            
            NSString *IssuerOfPatientID1=[NSString stringWithFormat:@"2.16.858.1.%@.%@",(K.iso3166[XXX])[iso3166Index],values[PatientIDTypeIndex]];
            
            NSUInteger PatientID1Index=[names indexOfObject:@"PatientID"];
            if (PatientID1Index==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientID' required"];
            NSString *PatientID1=values[PatientID1Index];
            if (![K.SHRegex numberOfMatchesInString:values[PatientID1Index] options:0 range:NSMakeRange(0,[PatientID1 length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientID should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
            
            
            //PatientBirthDate
            NSUInteger PatientBirthDateIndex=[names indexOfObject:@"PatientBirthDate"];
            if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientBirthDate' required"];
            NSString *PatientBirthdate1=values[PatientBirthDateIndex];
            if (![K.DARegex numberOfMatchesInString:PatientBirthdate1 options:0 range:NSMakeRange(0,[PatientBirthdate1 length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientBirthdate format should be aaaammdd"];
            
            //PatientSex
            NSUInteger PatientSexIndex=[names indexOfObject:@"PatientSex"];
            if (PatientSexIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientSex' required"];
            NSString *PatientSexValue1=[values[PatientSexIndex]uppercaseString];
            NSUInteger PatientSexSaluduyIndex=0;
            if ([PatientSexValue1 isEqualToString:@"M"])PatientSexSaluduyIndex=1;
            else if ([PatientSexValue1 isEqualToString:@"F"])PatientSexSaluduyIndex=2;
            else if ([PatientSexValue1 isEqualToString:@"O"])PatientSexSaluduyIndex=9;
            else  return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientSex should be 'M','F' or 'O'"];
            
            
        #pragma mark patient in pacs ?
            //change to GETPatients (if HEAD not available as in dcm4chee-arc 5.6)
            NSError *getpatienterror=nil;

            NSArray *patientExists=[NSURLSessionDataTask existsInPacs:pacs
                                                                       pid:PatientID1
                                                                    issuer:IssuerOfPatientID1
                                                          returnAttributes:true];
            if (patientExists)
            {
                if ([patientExists count]>1) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] <patient> patient ambiguity in pacs:\r\n%@",[patientExists description]];
                LOG_VERBOSE(@"[mwlitem] <patient> exists %@ %@ %@ %@ %@\r\n",PatientID1, IssuerOfPatientID1, ((((patientExists[0])[@"00100010"])[@"Value"])[0])[@"Alphabetic"],  (((patientExists[0])[@"00100030"])[@"Value"])[0],  (((patientExists[0])[@"00100040"])[@"Value"])[0]);
            }
            else
            {
                //create patient
                NSString *URLString=[NSString stringWithFormat:@"%@/rs/patients/%@%%5E%%5E%%5E%@",
                                     dcm4cheelocaluri,
                                     PatientID1,IssuerOfPatientID1
                                     ];
                NSMutableURLRequest *PUTpatientRequest=
                [NSMutableURLRequest
                 PUTpatient:URLString
                 name:PatientName1
                 pid:PatientID1
                 issuer:IssuerOfPatientID1
                 birthdate:(NSString *)PatientBirthdate1
                 sex:PatientSexValue1
                 contentType:@"application/json"
                 timeout:60
                 ];
                LOG_VERBOSE(@"[mwlitem] <Patient> PUT ->\r\n%@\r\n ",[[NSString alloc] initWithData:[PUTpatientRequest HTTPBody] encoding:NSUTF8StringEncoding]);
                
                NSHTTPURLResponse *PUTpatientResponse=nil;
                NSError *putpatienterror=nil;
                //URL properties: expectedContentLength, MIMEType, textEncodingName
                //HTTP properties: statusCode, allHeaderFields
                NSData *PUTpatientResponseData=[NSURLSessionDataTask sendSynchronousRequest:PUTpatientRequest returningResponse:&PUTpatientResponse error:&putpatienterror];
                NSString *PUTpatientResponseString=[[NSString alloc]initWithData:PUTpatientResponseData encoding:NSUTF8StringEncoding];
                LOG_VERBOSE(@"[mwlitem] <Patient> PUT <- %ld %@",(long)PUTpatientResponse.statusCode,PUTpatientResponseString);
                if ( putpatienterror || PUTpatientResponse.statusCode>299)
                {
                    LOG_ERROR(@"[mwlitem] <Patient> PUT %@",[getpatienterror description]);
                    return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not PUT patient %@. Response status: %ld body: %@ error: %@",PatientName1,(long)PUTpatientResponse.statusCode,[PUTpatientResponse description], [putpatienterror description]];
                }
            }

            

            
        #pragma mark create mwlitem

            //now
            NSDate *now=[NSDate date];
            
            //Priority
            NSString *Priority=nil;
            if ([[values[[names indexOfObject:@"Priority"]] uppercaseString] isEqualToString:@"URGENT"])Priority=@"URGENT";
            else Priority=@"MEDIUM";
            
            NSString *ReferringPhysiciansName1=nil;
            NSUInteger ReferringPhysiciansNameIndex=[names indexOfObject:@"ReferringPhysiciansName"];
            if (ReferringPhysiciansNameIndex!=NSNotFound)
            {
                NSString *normalized=[values[ReferringPhysiciansNameIndex]spaceNormalize];
                NSArray *subcomponents=[normalized componentsSeparatedByString:@"^"];
                if ([subcomponents count]==3)
                    ReferringPhysiciansName1=[NSString stringWithFormat:@"%@^%@^%@",subcomponents[0],subcomponents[1],[subcomponents[2]localizedLowercaseString]];
                else ReferringPhysiciansName1=normalized;

            }
            NSString *NameofPhysicianReadingStudy1=nil;
            NSUInteger NameofPhysicianReadingStudyIndex=[names indexOfObject:@"NameofPhysicianReadingStudy"];
            if (NameofPhysicianReadingStudyIndex!=NSNotFound)
            {
                NSArray *subcomponents=[values[NameofPhysicianReadingStudyIndex] componentsSeparatedByString:@"^"];
                if ([subcomponents count]==3)
                     NameofPhysicianReadingStudy1=[NSString stringWithFormat:@"%@^%@^%@",
                                                   [subcomponents[0]spaceNormalize],
                                                   [subcomponents[1]spaceNormalize],
                                                   [[subcomponents[2]localizedLowercaseString]spaceNormalize]
                                                   ];
                else NameofPhysicianReadingStudy1=[values[NameofPhysicianReadingStudyIndex]spaceNormalize];
            }
 //           else NameofPhysicianReadingStudy1=[NSString stringWithFormat:
 //                                              @"IRP^%@^-",
 //                                              Modality1
 //                                              ];

            /*if readingAsReferring.... implies corrective code into stow (put referring into reading and remove referring)
            NSString *referringOreading=nil;
            if ([service1Dict[@"readingAsReferring"]boolValue]==true) referringOreading=NameofPhysicianReadingStudy1;
            else referringOreading=ReferringPhysiciansName1;
            */
            NSString *mwlitemDate=[DICMTypes DAStringFromDate:now];
            NSString *mwlitemTime=[DICMTypes TMStringFromDate:now];
            NSMutableURLRequest *POSTmwlitemRequest=
            [NSMutableURLRequest
             POSTmwlitem:[dcm4cheelocaluri stringByAppendingPathComponent:@"rs/mwlitems"]
             CS:@"ISO_IR 192"
             aet:ScheduledStationAETitle
             DA:mwlitemDate
             TM:mwlitemTime
             TZ:K.defaultTimezone
             modality:Modality1
             accessionNumber:AccessionNumber1
             referring:NameofPhysicianReadingStudy1
             status:@"ARRIVED"
             studyDescription:StudyDescription1
             priority:Priority
             name:PatientName1
             pid:PatientID1
             issuer:IssuerOfPatientID1
             birthdate:PatientBirthdate1
             sex:PatientSexValue1
             contentType:@"application/json"
             timeout:60
             ];
            LOG_DEBUG(@"[mwlitem] <mwlitem> POST ->\r\n%@",[[NSString alloc] initWithData:[POSTmwlitemRequest HTTPBody] encoding:NSUTF8StringEncoding]);
            
            NSHTTPURLResponse *POSTmwlitemResponse=nil;
            //URL properties: expectedContentLength, MIMEType, textEncodingName
            //HTTP properties: statusCode, allHeaderFields
            NSError *mwlitemerror=nil;

            NSData *mwlitemResponseData=[NSURLSessionDataTask sendSynchronousRequest:POSTmwlitemRequest returningResponse:&POSTmwlitemResponse error:&mwlitemerror];
            NSString *mwlitemResponseString=[[NSString alloc]initWithData:mwlitemResponseData encoding:NSUTF8StringEncoding];
         
            //LOG_INFO(@"mwlitem %ld %@\r\n ",(long)POSTmwlitemResponse.statusCode,mwlitemResponseString);
            LOG_INFO(@"%@\r\n ",mwlitemResponseString);
#pragma mark create mwlitem folder in log
            [[NSFileManager defaultManager]createDirectoryAtPath:[@"/Users/Shared/export/" stringByAppendingFormat:@"%@/%@/%@",mwlitemDate,NameofPhysicianReadingStudy1,AccessionNumber1] withIntermediateDirectories:YES attributes:nil error:nil];//PatientID1
            
            if (mwlitemerror || POSTmwlitemResponse.statusCode>299)
            {
                LOG_ERROR(@"[mwlitem] <mwlitem> %@",[mwlitemerror description]);
                return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not POST mwlitem for patient: %@. Error: %@ body:%@",PatientName1,[mwlitemerror description], mwlitemResponseString];
            }

            
            
            
            [html appendFormat:@"<p>mwlitem sent to %@</p>",dcm4cheelocaluri];
            
            
#pragma mark NEW orm mllp pacs test
            //correct order is id^text^codingSystem (not id^codingSystem^text)
            NSArray *c=[StudyDescription1 componentsSeparatedByString:@"^"];
            NSString *description=nil;
            if (c.count==3)
            {
                NSArray *oc=@[c[0],c[2],c[1]];
                description=[oc componentsJoinedByString:@"^"];
            }
            else description=StudyDescription1;
            
            NSString *orm=[NSString stringWithFormat:
             @"MSH|^~\\&|||||||ORM^O01|||2.3.1|||||cl|8859/1|es\rPID|||%@^^^^%@||%@||%@|%@\rPV1||||||||referring^%@\rORC|NW||||||^^^%@%@^^T\rOBR||||^^^%@||||||||||||requesting||%@|%@|1|%@|||%@||||||||||performing^%@||||||||||%@\rZDS|%@",
                           
             PatientID1,
             IssuerOfPatientID1,
             PatientName1,
             PatientBirthdate1,
             PatientSexValue1,
             
             NameofPhysicianReadingStudy1,//referring
                           
             [DICMTypes DAStringFromDate:now],
             [DICMTypes TMStringFromDate:now],
             

             description,
             //requesting
             AccessionNumber1,
             AccessionNumber1,
             ScheduledStationAETitle,
             Modality1,
             NameofPhysicianReadingStudy1,//performing
             description,
            
                           
             AccessionNumber1
             ];
             
             NSMutableData *bytes=[NSMutableData data];
               [bytes appendBytes:&SB length:1];
               [bytes appendData:[orm dataUsingEncoding:NSISOLatin1StringEncoding]];
               [bytes appendBytes:&EB length:1];
               [bytes appendBytes:&CR length:1];
            
            [bytes writeToFile:@"/Users/Shared/mwldicom/log/orm.hl7" atomically:NO];
            [NSTask launchedTaskWithLaunchPath:@"/bin/bash" arguments:@[@"-c",@"exec 3>/dev/tcp/172.16.0.3/2575; cat /Users/Shared/mwldicom/log/orm.hl7 >&3"]];
            
            //NSTask *mllpTask=[[NSTask alloc]init];
            //[mllpTask setLaunchPath:@"/bin/bash"];
            //[mllpTask setArguments:@[@"-c",@"/Users/Shared/mllp.sh"]];
            //NSPipe *writePipe = [NSPipe pipe];
            //NSFileHandle *writeHandle = [writePipe fileHandleForWriting];
            //[mllpTask setStandardInput:writePipe];
            //[mllpTask launch];
            //[writeHandle writeData:bytes];

            
        #pragma mark - dscd
            NSMutableString *dscd=[NSMutableString string];
            [dscd appendDSCDprefix];
            [dscd appendSCDprefix];

        #pragma mark <realmCode> *
        #pragma mark <typeId> 1
            [dscd appendCDAprefix];
            
        #pragma mark <templateId> *
            
        #pragma mark <id> 1
            NSString *CDAID=[[NSUUID UUID]ITUTX667UIDString];
            /*RIDI
             NSString *CDAID=[NString stringWithFormat:@"2.16.858.2.%llu.67430.%@.%lu.%llu",
                organizationId,
                [DICMTypes DTStringFromDate:timestamp],
                incremental,
                manufacturerId];
             */
            [dscd appendCDAID:CDAID];
            
        #pragma mark <code> 1
        #pragma mark <title> ?
            // (=StudyDescription)
            [dscd appendRequestCDATitle:StudyDescription1];
            //appendReportCDATitle
            
        #pragma mark <effectiveTime> 1
            [dscd appendCurrentCDAEffectiveTime];
            
        #pragma mark <confidentialityCode> 1
            [dscd appendNormalCDAConfidentialityCode];
            
        #pragma mark <languageCode> ?
            [dscd appendEsCDALanguageCode];
            
        #pragma mark <setId> ?
            
        #pragma mark <versionNumber> ?
            [dscd appendFirstCDAVersionNumber];

        #pragma mark <copyTime> ?

            

        #pragma mark <recordTarget> +
            [dscd appendCDARecordTargetWithPid:PatientID1
                                        issuer:IssuerOfPatientID1
                                     apellido1:apellido1String
                                     apellido2:apellido2String
                                       nombres:nombresString
                                           sex:PatientSexValue1
                                     birthdate:PatientBirthdate1];
            
        #pragma mark <author> +
            [dscd appendCDAAuthorAnonymousOrgid:pacsUID1
                                        orgname:pacs[@"custodiantitle"]];
        #pragma mark <dataEnterer> ?
        #pragma mark <informant> *

        #pragma mark <custodian> 1
            [dscd appendCDACustodianOid:pacs[@"custodianoid"]
                                   name:pacs[@"custodiantitle"]];

        #pragma mark <informationRecipient> *
            //(=ReferringPhysiciansName)
            if (ReferringPhysiciansName1) [dscd appendCDAInformationRecipient:ReferringPhysiciansName1];

        #pragma mark <legalAuthenticator> ?
        #pragma mark <authenticator> *
        #pragma mark <participant> *
            

        #pragma mark <inFulfillentOf> * <Order>
            //(=AccessionNumber)
            [dscd appendCDAInFulfillmentOfOrder:AccessionNumber1 issuerOID:pacs[@"custodianoid"]];

        #pragma mark <documentationOf> * <serviceEvent>
            //(=Procedimiento)
            if (procedureIndex!=NSNotFound)
            {
                if ([(pacsProcedureDict[@"codes"])[procedureIndex] count]==0) [dscd appendCDADocumentationOfNotCoded:StudyDescription1];
                else [dscd appendCDADocumentationOf:StudyDescription1 fromPacsProcedureDict:pacsProcedureDict procedureIndex:procedureIndex schemeIndex:schemeIndex];
            }
            
        #pragma mark <relatedDocument> *
            //(=documento reemplazado)
        #pragma mark <authorization> *

        #pragma mark <componentOf> ? <encompassingEncounter>
            //      <code>
            //      <effectiveTime>  <low> <high>
            //      <location>
            //      <encounterParticipant
            [dscd appendCDAComponentOfEncompassingEncounterEffectiveTime:
             [[DICMTypes DAStringFromDate:now] stringByAppendingString:[DICMTypes TMStringFromDate:now]]
             ];
            
        #pragma mark <component> 1
            
            //enclosureTextarea & enclosurePdf
            NSString *enclosureTextarea=nil;
            NSUInteger enclosureTextareaIndex=[names indexOfObject:@"enclosureTextarea"];
            if ((enclosureTextareaIndex!=NSNotFound) && [values[enclosureTextareaIndex] length]) enclosureTextarea=values[enclosureTextareaIndex];

            NSString *enclosurePdf=nil;
            NSUInteger enclosurePdfIndex=[names indexOfObject:@"enclosurePdf"];
            if ((enclosurePdfIndex!=NSNotFound) && [values[enclosurePdfIndex] length]) enclosurePdf=values[enclosurePdfIndex];

            if (enclosureTextarea)
            {
                if (enclosurePdf) [dscd appendCDAComponentWithTextThumbnail:enclosureTextarea forBase64Pdf:enclosurePdf];
                else              [dscd appendCDAComponentWithText:enclosureTextarea];
            }
            else if (enclosurePdf)[dscd appendCDAComponentWithBase64Pdf:enclosurePdf];
            else                  [dscd appendEmptyCDAComponent];
                
        #pragma mark epilog
            [dscd appendCDAsuffix];
            [dscd appendSCDsuffix];
            [dscd appendDSCDsuffix];
            
            
        #pragma mark - TODO create array procedureCode {code, scheme meaning, traduction}
            NSMutableArray *mutableArray=[NSMutableArray array];
            if (procedureIndex)
            {
                NSDictionary *standarizedSchemesCodes=(pacsProcedureDict[@"codes"])[procedureIndex];
                for (NSString *standarizedScheme in standarizedSchemesCodes)
                {
                    NSString *standarizedCode=standarizedSchemesCodes[standarizedScheme];
                    NSDictionary *standarizedCodeDict=(K.code[standarizedScheme])[standarizedCode];
                    
                    [mutableArray addObject:@{
                                              @"code":standarizedCode,
                                              @"scheme":(K.scheme[standarizedScheme])[@"dcm"],
                                              @"meaning":standarizedCodeDict[@"meaning"]
                                              }];
                    
                    if ([standarizedCodeDict[@"translation"] count])
                    {
        #pragma mark TOOD translation
                    }
                }
            }
            
            NSString *studyUID=AccessionNumber1;
            NSString *seriesUID=[[NSUUID UUID]ITUTX667UIDString];
            NSString *SOPIUID=[[NSUUID UUID]ITUTX667UIDString];

#pragma mark dicom pdf object
if (enclosurePdf)
{
//metainfo
            //minimal format, one step with accessionNumber=procid=stepid=studyiuid
            NSMutableDictionary *metainfo=[NSMutableDictionary dictionary];
            [metainfo addEntriesFromDictionary:
             [NSDictionary DICM0002ForMediaStorageSOPClassUID:@"1.2.840.10008.5.1.4.1.1.104.1"
                 mediaStorageSOPInstanceUID:SOPIUID
                 implementationClassUID:@""
                 implementationVersionName:@""
                 sourceApplicationEntityTitle:@""
                 privateInformationCreatorUID:@""
                 privateInformation:nil
              ]
             ];
            NSMutableData *metainfoData=[NSMutableData DICMDataGroup2WithDICMDictionary:metainfo];
            


//dicm
            NSMutableDictionary *dicm=[NSMutableDictionary dictionary];

            //DICMC120100    SOP Common
            [dicm addEntriesFromDictionary:
             [NSDictionary
              DICMC120100ForSOPClassUID1:@"1.2.840.10008.5.1.4.1.1.104.1"
              SOPInstanceUID1:SOPIUID
              charset1:@"ISO_IR 192"
              DA1:mwlitemDate
              TM1:mwlitemTime
              TZ:K.defaultTimezone
              ]
             ];
                
                //DICMC070101    Patient
             [dicm addEntriesFromDictionary:
              [NSDictionary
               DICMC070101PatientWithName:[NSString stringWithFormat:@"%@>%@^%@",apellido1String,apellido2String,nombresString]
               pid:PatientID1
               issuer:IssuerOfPatientID1
               birthdate:PatientBirthdate1
               sex:PatientSexValue1
               ]
              ];

                //DICMC070201    General Study
                [dicm addEntriesFromDictionary:
                 [NSDictionary
                  DICMC070201StudyWithUID:studyUID
                  DA:mwlitemDate
                  TM:mwlitemTime
                  ID:@""
                  AN:AccessionNumber1
                  ANLocal:nil
                  ANUniversal:nil
                  ANUniversalType:nil
                  description:StudyDescription1
                  procedureCodes:[NSArray arrayWithArray:mutableArray]
                  referring:ReferringPhysiciansName1
                  reading:NameofPhysicianReadingStudy1
                  ]
                 ];

                
                //DICMC240100    Encapsulated Series
                [dicm addEntriesFromDictionary:[NSDictionary
                 DICMC240100ForModality1:@"OT"
                              seriesUID1:seriesUID
                           seriesNumber2:@"-32"
                               seriesDA3:mwlitemDate
                               seriesTM3:mwlitemTime
                      seriesDescription3:@"Orden de servicio"]];
                
                //DICMC070501    General Equipment
                [dicm addEntriesFromDictionary:[NSDictionary DICMC070501ForInstitution:pacs[@"pacstitle"]]];
                
                //DICMC080601    SC Equipment
                [dicm addEntriesFromDictionary:[NSDictionary
                 DICMC080601ForConversionType1:@"WSD"]];

                //DICMC240200    Encapsulated Document
                [dicm addEntriesFromDictionary:
                 [NSDictionary
                  DICMC240200EncapsulatedPDFWithDA:mwlitemDate
                  TM:mwlitemTime
                  title:@"Solicitud de informe imagenológico"
                  b64pdf:enclosurePdf
                  ]
                 ];

//MutableDictionary -> NSMutableData
                const UInt32        tag00020000pdf     = 0x02;
                const UInt32        vrULmonovaluedpdf  = 0x044C55;
                NSMutableData *stowData=[NSMutableData dataWithLength:128];
                [stowData appendDICMSignature];
                UInt32 count00020000 = (UInt32)[metainfoData length];
                [stowData appendBytes:&tag00020000pdf    length:4];
                [stowData appendBytes:&vrULmonovaluedpdf length:4];
                [stowData appendBytes:&count00020000  length:4];
                [stowData appendData:metainfoData];
                [stowData appendData:[NSMutableData DICMDataWithDICMDictionary:dicm bulkdataBaseURI:nil]];
                [stowData writeToFile:[@"/Users/Shared/export/" stringByAppendingFormat:@"%@/%@/%@/%@",mwlitemDate,NameofPhysicianReadingStudy1,AccessionNumber1,AccessionNumber1] atomically:NO];
}

            

            
#pragma mark dicom cda object
            NSMutableURLRequest *POSTenclosedRequest=
            [NSMutableURLRequest
             POSTenclosed:[dcm4cheelocaluri stringByAppendingPathComponent:@"rs/studies"]
             CS:@"ISO_IR 192"
             DA:mwlitemDate
             TM:mwlitemTime
             TZ:K.defaultTimezone
             modality:@"OT"
             accessionNumber:AccessionNumber1
             accessionIssuer:pacsUID1
             ANLocal:pacs[@"pacstitle"]
             studyDescription:StudyDescription1
             procedureCodes:[NSArray arrayWithArray:mutableArray]
             referring:ReferringPhysiciansName1
             reading:NameofPhysicianReadingStudy1
             name:PatientName1
             pid:PatientID1
             issuer:IssuerOfPatientID1
             birthdate:(NSString *)PatientBirthdate1
             sex:PatientSexValue1
             instanceUID:SOPIUID
             seriesUID:seriesUID
             studyUID:studyUID
             seriesNumber:@"-32"
             seriesDescription:@"Orden de servicio"
             enclosureHL7II:@""
             enclosureTitle:@"Solicitud de informe imagenológico"
             enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
             enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
             contentType:@"application/dicom"
             timeout:60
             ];
            
            NSHTTPURLResponse *POSTenclosedResponse=nil;
            //URL properties: expectedContentLength, MIMEType, textEncodingName
            //HTTP properties: statusCode, allHeaderFields
            
            NSError *enclosederror=nil;

            NSData *POSTenclosedResponseData=[NSURLConnection sendSynchronousRequest:POSTenclosedRequest returningResponse:&POSTenclosedResponse error:&enclosederror];
            
            NSString *POSTenclosedResponseString=[[NSString alloc]initWithData:POSTenclosedResponseData encoding:NSUTF8StringEncoding];
            
            if (enclosederror || POSTenclosedResponse.statusCode>299)
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
                
                
                LOG_ERROR(@"[mwlitem] <CDA> POST CDA for patient: %@. Error: %@ body:%@",PatientName1,[enclosederror description], POSTenclosedResponseString);
                return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not POST CDA for patient: %@. Error: %@ body:%@",PatientName1,[enclosederror description], POSTenclosedResponseString];
            }
            LOG_VERBOSE(@"[mwlitem] <CDA> POST <- %ld",POSTenclosedResponse.statusCode);
            [html appendFormat:@"<p>solicitud dicom cda sent to %@</p>",dcm4cheelocaluri];


        #pragma mark qido of the stow, in order to actualize metadata in pacs
            NSMutableURLRequest *GETqidostudyRequest=
            [NSMutableURLRequest
             GETqidostudy:[dcm4cheelocaluri stringByAppendingFormat:@"/rs/studies?StudyInstanceUID=%@",studyUID]
             timeout:60
             ];
            NSHTTPURLResponse *GETqidostudyResponse=nil;
            NSError *GETqidostudyerror=nil;

            NSData *GETqidostudyResponseData=[NSURLConnection sendSynchronousRequest:GETqidostudyRequest returningResponse:&GETqidostudyResponse error:&GETqidostudyerror];
            if (GETqidostudyResponse.statusCode!=200)
            {
                NSString *GETqidostudyResponseString=[[NSString alloc]initWithData:GETqidostudyResponseData encoding:NSUTF8StringEncoding];
                LOG_ERROR(@"[mwlitem] %ld %@", GETqidostudyResponse.statusCode, [dcm4cheelocaluri stringByAppendingFormat:@"rs/studies?StudyInstanceUID=%@",studyUID]);
                [html appendString:@"<p>qido failed</p>"];
            }
            else LOG_INFO(@"[mwlitem] qido %ld",GETqidostudyResponse.statusCode);

            
        #pragma mark create user in html5dicom
            /*
            Url : http://ip:puerto/accounts/api/user
             found in services1dict html5dicomuserserviceuri
             
            Content-Type : application/json
            
            Body
            {
                "institution": “IRP",
                "username": "15993195-1",
                "password": "clave",
                "first_name": "Claudio Anibal",
                "last_name": "Baeza Gonzalez",
                "is_active": “False"
            }
            
            Para la MWL “is_active" debe ser False
            Para el informe “is_active” debe ser True
            */
            
             NSUInteger clave1Index=[names indexOfObject:@"clave"];
            if (clave1Index==NSNotFound) LOG_VERBOSE(@"[mwlitem] no parameter 'clave' -> no user created in html5dicom");
            else
            {
                NSString *clave1String=values[clave1Index];
                if (![clave1String length]) LOG_VERBOSE(@"mwlitem] parameter 'clave'empty -> no user created in html5dicom");
                else
                {
                    NSMutableURLRequest *POSThtml5dicomuserRequest=nil;
                    if (service1Dict) POSThtml5dicomuserRequest=
                        [NSMutableURLRequest
                         POSThtml5dicomuserRequest:service1Dict[@"html5dicomuserserviceuri"]
                         institution:pacs[@"custodiantitle"]
                         username:PatientID1
                         password:clave1String
                         firstname:nombresString
                         lastname: [NSString stringWithFormat:@"%@ %@",apellido1String, apellido2String]
                         isactive: NO
                         timeout:60
                         ];
                    else POSThtml5dicomuserRequest=
                        [NSMutableURLRequest
                         POSThtml5dicomuserRequest:pacs[@"html5dicomuserserviceuri"]
                         institution:pacs[@"custodiantitle"]
                         username:PatientID1
                         password:clave1String
                         firstname:nombresString
                         lastname: [NSString stringWithFormat:@"%@ %@",apellido1String, apellido2String]
                         isactive: NO
                         timeout:60
                         ];

                    NSString *POSThtml5dicomuserRequestBodyString=[[NSString alloc]initWithData:POSThtml5dicomuserRequest.HTTPBody encoding:NSUTF8StringEncoding];
                    NSHTTPURLResponse *POSThtml5dicomuserResponse=nil;
                    NSError *posthtml5usererror=nil;

                    NSData *POSThtml5dicomuserRequestResponseData=[NSURLConnection sendSynchronousRequest:POSThtml5dicomuserRequest returningResponse:&POSThtml5dicomuserResponse error:&posthtml5usererror];
                    NSString *POSThtml5dicomuserRequestResponseString=[[NSString alloc]initWithData:POSThtml5dicomuserRequestResponseData encoding:NSUTF8StringEncoding];
                    
                    if (POSThtml5dicomuserResponse.statusCode==201)
                    {
                        LOG_VERBOSE(@"[mwlitem] <html5user> created");
                        [html appendFormat:@"<p>created html5user %@</p>",[[NSString alloc]initWithData:POSThtml5dicomuserRequest.HTTPBody encoding:NSUTF8StringEncoding]];
                    }
                    else
                    {
                        NSString *POSThtml5dicomuserRequestResponseString=[[NSString alloc]initWithData:POSThtml5dicomuserRequestResponseData encoding:NSUTF8StringEncoding];
                        LOG_WARNING(@"[mwlitem] <html5user> POST -> \r\n%@",[[NSString alloc]initWithData:POSThtml5dicomuserRequest.HTTPBody encoding:NSUTF8StringEncoding]);
                        LOG_WARNING(@"[mwlitem] <html5user> POST <- NOT CREATED \r\n%@",[POSThtml5dicomuserResponse description]);
                        [html appendFormat:@"<p>patient %@ NOT created in %@</p>",PatientID1,service1Dict[@"html5dicomuserserviceuri"]];
                    }
                }
            }
            
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
    }
    [html appendString:@"</body></html>"];
     
     return [RSDataResponse responseWithHTML:html];
     
     
     
     }(request));}];
}
@end
