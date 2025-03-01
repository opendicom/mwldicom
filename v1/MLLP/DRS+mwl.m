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
#import "NSUUID+DICM.h"

#import "ORMO01_231.h"
#import "mllpClient.h"

#import "NSMutableURLRequest+MWL.h"
#import "NSMutableURLRequest+patient.h"
#import "NSMutableURLRequest+instance.h"
#import "NSMutableURLRequest+html5dicom.h"


@implementation DRS (mwl)

-(void)addMWLHandler
{
[self addHandler:@"POST" path:@"/mwlitem" processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
{
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
    LOG_DEBUG(@"[mwlitem]<request>\r\n%@",[values description]);

    
#pragma mark validation pacs
    NSString *pacsUID1=nil;
    NSDictionary *pacs=nil;
    NSString *dcm4cheelocaluri=nil;
    
    NSUInteger pacsIndex=[names indexOfObject:@"pacs"];
    if (pacsIndex!=NSNotFound)
    {
        pacsUID1=values[pacsIndex];
        if (![DICMTypes.UIRegex numberOfMatchesInString:pacsUID1 options:0 range:NSMakeRange(0,[pacsUID1 length])])
            return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacsUID '%@' should be an OID",pacsUID1];
        pacs=DRS.pacs[pacsUID1];
        if (!pacs) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' not known",pacsUID1];
        
        //dcm4cheelocaluri available?
        dcm4cheelocaluri=pacs[@"dcm4cheelocaluri"];
        if (
              !dcm4cheelocaluri
            ||![dcm4cheelocaluri length]
            ) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] pacs '%@' is not a dcm4chee-arc",pacsUID1];
        LOG_INFO(@"[mwlitem] <pacs> %@",pacsUID1);
    }
    else
    {
        pacsUID1=DRS.drspacs;
        pacs=DRS.pacs[pacsUID1];
        LOG_INFO(@"[mwlitem] <pacs> %@ (default)",pacsUID1);
        dcm4cheelocaluri=pacs[@"dcm4cheelocaluri"];
    }
    
    
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
    }
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
    LOG_INFO(@"[mwlitem] <service> %@ <modality> %@",service1Title,Modality1);

    
#pragma mark validation AccessionNumber
    NSUInteger AccessionNumberIndex=[names indexOfObject:@"AccessionNumber"];
    if (AccessionNumberIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber required"];
    NSString *AccessionNumber1=values[AccessionNumberIndex];
    
    if (![DICMTypes.SHRegex numberOfMatchesInString:AccessionNumber1 options:0 range:NSMakeRange(0,[values[AccessionNumberIndex] length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] AccessionNumber should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
    
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
    LOG_INFO(@"[mwlitem] <accession> %@",AccessionNumber1);

    
    
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
            else LOG_INFO(@"[mwlitem] <procedure> %@",StudyDescription1Array[0]);
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
    if (![DICMTypes.SHRegex numberOfMatchesInString:values[PatientID1Index] options:0 range:NSMakeRange(0,[PatientID1 length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientID should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
    
    
    //PatientBirthDate
    NSUInteger PatientBirthDateIndex=[names indexOfObject:@"PatientBirthDate"];
    if (PatientBirthDateIndex==NSNotFound) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] 'PatientBirthDate' required"];
    NSString *PatientBirthdate1=values[PatientBirthDateIndex];
    if (![DICMTypes.DARegex numberOfMatchesInString:PatientBirthdate1 options:0 range:NSMakeRange(0,[PatientBirthdate1 length])]) return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] PatientBirthdate format should be aaaammdd"];
    
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

    
#pragma mark mllp create mwlitem
    
    //now
    NSDate *now=[NSDate date];
    
    //Priority
    NSString *Priority=nil;
    if ([[values[[names indexOfObject:@"Priority"]] uppercaseString] isEqualToString:@"URGENT"])Priority=@"A";
    else Priority=@"T";

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
        NSString *normalized=[values[NameofPhysicianReadingStudyIndex]spaceNormalize];
        NSArray *subcomponents=[normalized componentsSeparatedByString:@"^"];
        if ([subcomponents count]==3)
            NameofPhysicianReadingStudy1=[NSString stringWithFormat:@"%@^%@^%@",subcomponents[0],subcomponents[1],[subcomponents[2]localizedLowercaseString]];
        else NameofPhysicianReadingStudy1=normalized;
    }
    //if readingAsReferring.... implies corrective code into stow (put referring into reading and remove referring)
    NSString *referringOreading=nil;
    if ([service1Dict[@"readingAsReferring"]boolValue]==true) referringOreading=NameofPhysicianReadingStudy1;
    else referringOreading=ReferringPhysiciansName1;
    
    NSString *studyUID=[[NSUUID UUID]ITUTX667UIDString];
    
    //not available yet
    NSString * MessageControlId=nil;
    NSString * isrPatientInsuranceShortName=nil;
    NSString * isrDangerCode=nil;
    NSString * isrRelevantClinicalInfo=nil;
    NSString * rpID=nil;
    NSString * spsID=nil;
    NSString * rpTransportationMode=nil;
    NSString * rpReasonForStudy=nil;
    

    NSString *msg=[ORMO01_231
                   singleSpsMSH_3:@"IMATEC"
                   MSH_4:request.remoteAddressString
                   MSH_5:pacs[@"custodiantitle"]
                   MSH_6:pacs[@"deviceaet"]
                   MSH_10:MessageControlId
                   MSH_17:@"cl"
                   MSH_18:(NSStringEncoding)5
                   MSH_19:@"es"
                   PID_3:[NSString stringWithFormat:@"%@^^^%@",PatientID1,IssuerOfPatientID1]
                   PID_5:PatientName1
                   PID_7:PatientBirthdate1
                   PID_8:PatientSexValue1
                   PV1_8:isrPatientInsuranceShortName
                   ORC_2:[DICMTypes DTStringFromDate:now]
                   ORC_3:[DICMTypes DTStringFromDate:now]
                   ORC_5:@"SC"
                   ORC_7:[DICMTypes DTStringFromDate:now]
                   ORC_7_:Priority
                   OBR_4:StudyDescription1
                   OBR_12:isrDangerCode
                   OBR_13:isrRelevantClinicalInfo
                   OBR_16:referringOreading
                   OBR_18:AccessionNumber1
                   OBR_19:rpID
                   OBR_20:spsID
                   OBR_21:ScheduledStationAETitle
                   OBR_24:Modality1
                   OBR_30:rpTransportationMode
                   OBR_31:rpReasonForStudy
                   OBR_32:NameofPhysicianReadingStudy1
                   OBR_34:NameofPhysicianReadingStudy1
                   OBR_44:StudyDescription1
                   ZDS_1:studyUID
                   ];
    
    LOG_DEBUG(@"MLLP ->\r\n%@",msg);
    NSMutableString * payload=[NSMutableString string];
    if (![mllpClient sendPacs:pacs
                      message:msg
               stringEncoding:(NSStringEncoding)5
                      payload:(NSMutableString*)payload])
    {
        //could not send mllp
        LOG_ERROR(@"%@",payload);
        return [RSErrorResponse responseWithClientError:404 message:@"%@",payload];
    }
    LOG_DEBUG(@"%@",payload);

    
#pragma mark create mwlitem

    /*
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
        NSString *normalized=[values[NameofPhysicianReadingStudyIndex]spaceNormalize];
        NSArray *subcomponents=[normalized componentsSeparatedByString:@"^"];
        if ([subcomponents count]==3)
             NameofPhysicianReadingStudy1=[NSString stringWithFormat:@"%@^%@^%@",subcomponents[0],subcomponents[1],[subcomponents[2]localizedLowercaseString]];
        else NameofPhysicianReadingStudy1=normalized;
    }
    //if readingAsReferring.... implies corrective code into stow (put referring into reading and remove referring)
    NSString *referringOreading=nil;
    if ([service1Dict[@"readingAsReferring"]boolValue]==true) referringOreading=NameofPhysicianReadingStudy1;
    else referringOreading=ReferringPhysiciansName1;

    NSString *studyUID=[[NSUUID UUID]ITUTX667UIDString];
    
    //there is no option in the service web to use ISO_IR 100 !!!!
    NSMutableURLRequest *POSTmwlitemRequest=
    [NSMutableURLRequest
     POSTmwlitem:[dcm4cheelocaluri stringByAppendingPathComponent:@"rs/mwlitems"]
     CS:@"ISO_IR 192"
     aet:ScheduledStationAETitle
     DA:[DICMTypes DAStringFromDate:now]
     TM:[DICMTypes TMStringFromDate:now]
     TZ:K.defaultTimezone
     modality:Modality1
     accessionNumber:AccessionNumber1
     referring:referringOreading
     status:@"ARRIVED"
     studyDescription:StudyDescription1
     priority:Priority
     name:PatientName1
     pid:PatientID1
     issuer:IssuerOfPatientID1
     birthdate:PatientBirthdate1
     sex:PatientSexValue1
     contentType:@"application/json"
     studyUID:studyUID
     timeout:60
     ];
    LOG_DEBUG(@"[mwlitem] <mwlitem> POST ->\r\n%@",[[NSString alloc] initWithData:[POSTmwlitemRequest HTTPBody] encoding:NSUTF8StringEncoding]);
    
    NSHTTPURLResponse *POSTmwlitemResponse=nil;
    //URL properties: expectedContentLength, MIMEType, textEncodingName
    //HTTP properties: statusCode, allHeaderFields
    NSError *mwlitemerror=nil;

    NSData *mwlitemResponseData=[NSURLSessionDataTask sendSynchronousRequest:POSTmwlitemRequest returningResponse:&POSTmwlitemResponse error:&mwlitemerror];
    NSString *mwlitemResponseString=[[NSString alloc]initWithData:mwlitemResponseData encoding:NSUTF8StringEncoding];
 
    LOG_VERBOSE(@"[mwlitem] <mwlitem> POST <- %ld\r\n%@\r\n ",(long)POSTmwlitemResponse.statusCode,mwlitemResponseString);
    if (mwlitemerror || POSTmwlitemResponse.statusCode>299)
    {
        LOG_ERROR(@"[mwlitem] <mwlitem> %@",[mwlitemerror description]);
        return [RSErrorResponse responseWithClientError:404 message:@"[mwlitem] can not POST mwlitem for patient: %@. Error: %@ body:%@",PatientName1,[mwlitemerror description], mwlitemResponseString];
    }
    
 */
    NSMutableString* html = [NSMutableString stringWithString:@"<html><body>"];
    [html appendFormat:@"<p>mwlitem sent to %@</p>",dcm4cheelocaluri];
    
    
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
    if (procedureIndex!=NSNotFound)
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
    
    NSString *seriesUID=[[NSUUID UUID]ITUTX667UIDString];
    NSString *SOPIUID=[[NSUUID UUID]ITUTX667UIDString];

    //dicom object
    NSMutableURLRequest *POSTenclosedRequest=
    [NSMutableURLRequest
     POSTenclosed:[dcm4cheelocaluri stringByAppendingPathComponent:@"rs/studies"]
     CS:@"ISO_IR 192"
     DA:[DICMTypes DAStringFromDate:now]
     TM:[DICMTypes TMStringFromDate:now]
     TZ:K.defaultTimezone
     modality:@"OT"
     accessionNumber:AccessionNumber1
     accessionIssuer:pacsUID1
     ANLocal:pacs[@"deviceaet"]
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
    NSMutableURLRequest *GETqidoinstancemetadataxmlRequest=
    [NSMutableURLRequest
     GETqidoinstancemetadataxml:[dcm4cheelocaluri stringByAppendingPathComponent:@"rs/studies"]
     studyUID:studyUID
     seriesUID:seriesUID
     SOPIUID:SOPIUID
     timeout:60
     ];
    LOG_VERBOSE(@"[mwlitem] <CDA> GET -> %@\r\n ", GETqidoinstancemetadataxmlRequest.URL.absoluteString);
    NSHTTPURLResponse *GETqidoinstancemetadataxmlResponse=nil;
    NSError *qidoinstanceerror=nil;

    NSData *GETqidoinstancemetadataxmlResponseData=[NSURLConnection sendSynchronousRequest:GETqidoinstancemetadataxmlRequest returningResponse:&GETqidoinstancemetadataxmlResponse error:&qidoinstanceerror];
    if (GETqidoinstancemetadataxmlResponse.statusCode!=200)
    {
        NSString *GETqidoinstancemetadataxmlResponseString=[[NSString alloc]initWithData:GETqidoinstancemetadataxmlResponseData encoding:NSUTF8StringEncoding];
        LOG_ERROR(@"[mwlitem] <CDA> GET <- %ld %@", GETqidoinstancemetadataxmlResponse.statusCode, GETqidoinstancemetadataxmlResponseString);
        [html appendString:@"<p>qido failed</p>"];
    }

    
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

    [html appendString:@"</body></html>"];
     
     return [RSDataResponse responseWithHTML:html];
     
     
     
     }(request));}];
}
@end
