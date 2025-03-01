//
//  DRS+pdf.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180116.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+functions.h"
#import "DRS+pdf.h"
#import "K.h"

#import "NSData+PCS.h"
#import "NSString+PCS.h"
#import "NSURLSessionDataTask+PCS.h"
#import "DICMTypes.h"
#import "NSMutableString+DSCD.h"
#import "NSUUID+DICM.h"

#import "NSMutableURLRequest+enclosed.h"
#import "NSMutableURLRequest+patient.h"
#import "NSMutableURLRequest+instance.h"
#import "NSMutableURLRequest+html5dicom.h"


@implementation DRS (pdf)


-(void)addPDFHandler
{
    
NSRegularExpression *pdfRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/(pdf|informe|report)$" options:0 error:NULL];
[self addHandler:@"POST" regex:pdfRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
{
    NSError *error=nil;
    NSString *pdfType=[request.URL.absoluteURL.path substringFromIndex:1];
#pragma mark params
    NSMutableArray *names=[NSMutableArray array];
    NSMutableArray *values=[NSMutableArray array];
    NSMutableArray *types=[NSMutableArray array];
    NSMutableString *jsonString=[NSMutableString string];
    NSString *errorString=nil;
    if (!parseRequestParams(request, jsonString, names, values, types, &errorString))
    {
        LOG_WARNING(@"[pdf]<request> <-404: params error: %@",errorString);
        return [RSErrorResponse responseWithClientError:404 message:@"%@",errorString];
    }
    NSArray *pdfSplitted=[jsonString componentsSeparatedByString:@"\"enclosurePdf\""];
    LOG_VERBOSE(@"[pdf]<request> \r\n%@ \"enclosurePdfSize\"=%lu} ",pdfSplitted[0], [pdfSplitted[1] length]-4);

    
    
#pragma mark validation AccessionNumber input
    //AccessionNumber must be present
    NSUInteger AccessionNumberIndex=[names indexOfObject:@"AccessionNumber"];
    if (AccessionNumberIndex==NSNotFound)
    {
        LOG_WARNING(@"[pdf]<request> <-404: AccessionNumber required");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] AccessionNumber required"];
    }
    NSString *AccessionNumber1=values[AccessionNumberIndex];
    
    if (![K.SHRegex numberOfMatchesInString:AccessionNumber1 options:0 range:NSMakeRange(0,[values[AccessionNumberIndex] length])])
    {
        LOG_WARNING(@"[pdf]<request> AccessionNumber should be > 1 and < 16 chars in length, without space, nor return, nor tab");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] AccessionNumber should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
    }
    
    NSString *issuerLocal1=nil;
    NSUInteger issuerLocalIndex=[names indexOfObject:@"issuerLocal"];
    if ((issuerLocalIndex!=NSNotFound) && [values[issuerLocalIndex] length]) issuerLocal1=values[issuerLocalIndex];
    
    NSString *issuerUniversal1=nil;
    NSUInteger issuerUniversalIndex=[names indexOfObject:@"issuerUniversal"];
    if ((issuerUniversalIndex!=NSNotFound) && [values[issuerUniversalIndex] length]) issuerUniversal1=values[issuerUniversalIndex];
    
    NSString *issuerType1=nil;
    NSUInteger issuerTypeIndex=[names indexOfObject:@"issuerType"];
    if (issuerTypeIndex==NSNotFound) issuerTypeIndex=[names indexOfObject:@"issuerTipo"];
    if ((issuerTypeIndex!=NSNotFound) && [values[issuerTypeIndex] length]) issuerType1=values[issuerTypeIndex];


#pragma mark save custom3
   //since there is an accessionNumber
   NSString *sql=[NSString stringWithFormat:@"export MYSQL_PWD=pacs;/usr/local/mysql/bin/mysql -upacs -h 127.0.0.1 -b pacsdb -e \"SELECT study_custom3 FROM study WHERE accession_no='%@';\"",AccessionNumber1];
   NSMutableData *custom3data=[NSMutableData data];
   bash([sql dataUsingEncoding:NSUTF8StringEncoding],custom3data);
   NSString *custom3=[[NSString alloc] initWithData:custom3data encoding:NSUTF8StringEncoding];
   NSLog(@"before: an:%@  custom3:%@",AccessionNumber1, custom3);


    
#pragma mark validation pacs
    NSString *pacsUID1=nil;
    NSDictionary *pacs=nil;

    NSUInteger pacsIndex=[names indexOfObject:@"pacs"];
    if (pacsIndex!=NSNotFound)
    {
        pacsUID1=values[pacsIndex];
        if (![K.UIRegex numberOfMatchesInString:pacsUID1 options:0 range:NSMakeRange(0,[pacsUID1 length])])
        {
            LOG_WARNING(@"[pdf]<request> <-404:  pacsUID '%@' should be an OID",pacsUID1);
            return [RSErrorResponse responseWithClientError:404 message:@"[pdf] pacsUID '%@' should be an OID",pacsUID1];
        }
        pacs=DRS.pacs[pacsUID1];
        if (!pacs)
        {
            LOG_WARNING(@"[pdf]<request> <-404:  pacs '%@' not known",pacsUID1);
            return [RSErrorResponse responseWithClientError:404 message:@"[pdf] pacs '%@' not known",pacsUID1];
        }
        //dcm4cheelocaluri available?
        if (
              !pacs[@"dcm4cheelocaluri"]
            ||![pacs[@"dcm4cheelocaluri"] length]
            )
        {
            LOG_WARNING(@"[pdf]<request> <-404:  pacs '%@' is not a dcm4chee-arc",pacsUID1);
            return [RSErrorResponse responseWithClientError:404 message:@"[pdf] pacs '%@' is not a dcm4chee-arc",pacsUID1];
        }
        LOG_VERBOSE(@"[pdf]<pacs> %@",pacsUID1);
    }
    else
    {
        if (issuerLocal1)
        {
            NSString *orgAet=[issuerLocal1 componentsSeparatedByString:@"-"][0];
            pacsUID1=DRS.pacsTitlesDictionary[[orgAet stringByAppendingPathExtension:issuerLocal1]];
            pacs=DRS.pacs[pacsUID1];
            LOG_VERBOSE(@"[pdf]<pacs> %@ %@",issuerLocal1,pacsUID1);
        }
        else
        {
            pacsUID1=DRS.drspacs;
            pacs=DRS.pacs[DRS.drspacs];
            LOG_VERBOSE(@"[pdf]<pacs> %@ (default)",pacsUID1);
        }
    }

    
#pragma mark validation PatientID input
    //PatientID must be present
    NSUInteger PatientID1Index=[names indexOfObject:@"PatientID"];
    if (PatientID1Index==NSNotFound)
    {
        LOG_WARNING(@"[pdf]<request> <-404:  'PatientID' required");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientID' required"];
    }
    NSString *PatientID1=values[PatientID1Index];
    if (![K.SHRegex numberOfMatchesInString:values[PatientID1Index] options:0 range:NSMakeRange(0,[PatientID1 length])])
    {
        LOG_WARNING(@"[pdf]<request> <-404:  PatientID should be > 1 and < 16 chars in length, without space, nor return, nor tab");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] PatientID should be > 1 and < 16 chars in length, without space, nor return, nor tab"];
    }
    
    //PatientIDIssuer input
    NSUInteger IDCountryIndex=[names indexOfObject:@"PatientIDCountry"];
    if (IDCountryIndex==NSNotFound)
    {
        LOG_WARNING(@"[pdf]<request> <-404: 'PatientIDCountry' required");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientIDCountry' required"];
    }
    
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
                    if (iso3166Index==NSNotFound)
                    {
                        LOG_WARNING(@"[pdf]<request> <-404:  PatientID Country '%@' not valid",IDCountryValue);
                        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] PatientID Country '%@' not valid",IDCountryValue];
                    }
                }
            }
        }
    }
    
    NSUInteger PatientIDTypeIndex=[names indexOfObject:@"PatientIDType"];
    if (PatientIDTypeIndex==NSNotFound)
    {
        LOG_WARNING(@"[pdf]<request> <-404: 'PatientIDType' required");
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientIDType' required"];
    }
    if ([[K.personidtype allKeys] indexOfObject:values[PatientIDTypeIndex]]==NSNotFound)
    {
        LOG_WARNING(@"[pdf]<request> <-404: PatientIDType '%@' unknown",values[PatientIDTypeIndex]);
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] PatientIDType '%@' unknown",values[PatientIDTypeIndex]];
    }
    
    NSString *IssuerOfPatientID1=[NSString stringWithFormat:@"2.16.858.1.%@.%@",(K.iso3166[XXX])[iso3166Index],values[PatientIDTypeIndex]];

#pragma mark initializations
    NSDate *now=[NSDate date];
    NSString *CDAID=[[NSUUID UUID]ITUTX667UIDString];
    NSString *studyUID=nil;
    NSString *seriesUID=nil;
    NSString *SOPIUID=nil;
    NSMutableURLRequest *POSTenclosedRequest;
    //pacs or input
    NSString *patientFamily1=nil;
    NSString *patientFamily2=nil;
    NSString *patientNames=nil;

    NSString *PatientName1=nil;
    NSString *PatientBirthdate1=nil;
    NSString *PatientSexValue1=nil;
    NSString *ReferringPhysiciansName1=nil;
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
#pragma mark dscd
    NSMutableString *dscd=[NSMutableString string];
    [dscd appendDSCDprefix];
    [dscd appendSCDprefix];
    
#pragma mark <realmCode> *
#pragma mark <typeId> 1
    [dscd appendCDAprefix];
    
#pragma mark <templateId> *
    
#pragma mark <id> 1
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
    NSString *enclosureTextarea=nil;
    NSUInteger enclosureTextareaIndex=[names indexOfObject:@"DocumentTitle"];
    if ((enclosureTextareaIndex!=NSNotFound) && [values[enclosureTextareaIndex] length]) enclosureTextarea=values[enclosureTextareaIndex];
    else if ([pdfType isEqualToString:@"informe"]||[pdfType isEqualToString:@"report"]) enclosureTextarea=@"informe imagenológico";
    else enclosureTextarea=@"pdf";
    
    [dscd appendRequestCDATitle:enclosureTextarea];
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



    
#pragma mark ACCESSIONNUMBER ALREADY IN PACS?
//    NSArray *customArray=nil;
    NSDictionary *existingStudy=[NSURLSessionDataTask existsInPacs:pacs accessionNumber:AccessionNumber1 issuerLocal:issuerLocal1 issuerUniversal:issuerUniversal1 issuerType:issuerType1 returnAttributes:true];
#pragma mark - YES
    if (existingStudy)
    {
        
        LOG_VERBOSE(@"[pdf]<accessionNumber>\r\n%@",[existingStudy description]);
        //check if Patient ID matches
        BOOL IDmatches=[PatientID1 isEqualToString:((existingStudy[@"00100020"])[@"Value"])[0]];
        // !!!!!!!  el pacs no devuelve 00100021 !!!!!!!
        //if (IssuerOfPatientID1) IDmatches &= [IssuerOfPatientID1 isEqualToString:((existingStudy[@"00100021"])[@"Value"])[0]];
        
        //Si AccessionNumber corresponde a un estudio presente en el PACS y PatientID a un paciente que no corresponde, el informe está rechazado
        if (!IDmatches)
        {
            LOG_WARNING(@"[pdf]<request> <-404:  there exists a study with same accession number but different patient ID. Cannot register the report.");

            return [RSErrorResponse responseWithClientError:404 message:@"[pdf] there exists a study with same accession number but different patient ID. Cannot register the report."];
        }
        
        //Si el identificador del paciente corresponde pero los otros datos patronímicos no corresponden, ni de cerca (por ejemplo sexo diferente, fecha de nacimiento muy diferente, nombres o apellido que no corresponden) el informe está rechazado.
//#pragma mark TODO check other demographics

        //  Si ambos el accessionNumber y PatientID  corresponden a un estudio ya presente en el PACS, el informe se adjunta al estudio y los otros campos demográficos del paciente son opcionales y no tomados en cuenta
        
        

#pragma mark <recordTarget> +
        PatientName1=(((existingStudy[@"00100010"])[@"Value"])[0])[@"Alphabetic"];
        NSArray *PatientArray=[PatientName1 componentsSeparatedByString:@"^"];
        NSArray *PatientFamilyArray=[PatientArray[0] componentsSeparatedByString:@">"];
        patientFamily1=PatientFamilyArray[0];
        if ([PatientFamilyArray count]==2) patientFamily2=PatientFamilyArray[1];
        if ([PatientArray count]>1) patientNames=PatientArray[1];
        [dscd appendCDARecordTargetWithPid:((existingStudy[@"00100020"])[@"Value"])[0]
                                    issuer:((existingStudy[@"00100021"])[@"Value"])[0]
                                 apellido1:patientFamily1
                                 apellido2:patientFamily2
                                   nombres:patientNames
                                       sex:((existingStudy[@"00100040"])[@"Value"])[0]
                                 birthdate:((existingStudy[@"00100030"])[@"Value"])[0]
         ];
        
#pragma mark <author> +
        if (NameofPhysicianReadingStudy1 && (NameofPhysicianReadingStudy1.length > 1))
        {
            NSArray  *readingInstServProf=[NameofPhysicianReadingStudy1 componentsSeparatedByString:@"^"];
            NSString* institution=readingInstServProf[0];
            NSString* service=nil;
            NSString* user=nil;
            if ([readingInstServProf count]>1) service=readingInstServProf[1];
            if ([readingInstServProf count]>2) user=readingInstServProf[2];

            [dscd appendCDAAuthorInstitution:institution
                                     service:service
                                        user:user];
        }
        else [dscd appendCDAAuthorAnonymousOrgid:pacsUID1 orgname:pacs[@"custodiantitle"]];

        
#pragma mark <dataEnterer> ?
#pragma mark <informant> *
        
#pragma mark <custodian> 1
        [dscd appendCDACustodianOid:pacs[@"custodianoid"]
                               name:pacs[@"custodiantitle"]];
        
#pragma mark <informationRecipient> *
        NSString *informationRecipient=(((existingStudy[@"00080090"])[@"Value"])[0])[@"Alphabetic"];
        if (informationRecipient && [informationRecipient length]) ReferringPhysiciansName1=informationRecipient;
        else
        {
            NSUInteger ReferringPhysiciansNameIndex=[names indexOfObject:@"ReferringPhysiciansName"];
            if (ReferringPhysiciansNameIndex!=NSNotFound) ReferringPhysiciansName1=[values[ReferringPhysiciansNameIndex] spaceNormalize];
        }
        if (ReferringPhysiciansName1) [dscd appendCDAInformationRecipient:ReferringPhysiciansName1];

#pragma mark <legalAuthenticator> ?
#pragma mark <authenticator> *
#pragma mark <participant> *
        
        
#pragma mark <inFulfillentOf> * <Order>
        //(=AccessionNumber)
        [dscd appendCDAInFulfillmentOfOrder:((existingStudy[@"00080050"])[@"Value"])[0] issuerOID:pacs[@"custodianoid"]];
        
#pragma mark <documentationOf> * <serviceEvent>
        //(=Procedimiento)
        [dscd appendCDADocumentationOfNotCoded:((existingStudy[@"00081030"])[@"Value"])[0]];
        
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
        
        [dscd appendCDAsuffix];
        [dscd appendSCDsuffix];
        [dscd appendDSCDsuffix];

#pragma mark request to APPEND to study

        studyUID=((existingStudy[@"0020000D"])[@"Value"])[0];
        seriesUID=[[NSUUID UUID]ITUTX667UIDString];
        SOPIUID=[[NSUUID UUID]ITUTX667UIDString];
        
        //dicom object
        if ([pdfType isEqualToString:@"informe"]||[pdfType isEqualToString:@"report"])
        {
            POSTenclosedRequest=
            [NSMutableURLRequest
             POSTenclosedToPacs:pacs
             CS:@"ISO_IR 192"
             DA:[DICMTypes DAStringFromDate:now]
             TM:[DICMTypes TMStringFromDate:now]
             TZ:K.defaultTimezone
             AN:AccessionNumber1
             ANLocal:pacs[@"pacstitle"]
             ANUniversal:pacs[@"custodianoid"]
             ANUniversalType:@"ISO"
             modality:@"DOC"
             studyDescription:((existingStudy[@"00081030"])[@"Value"])[0]
             procedureCodes:@[]
             referring:ReferringPhysiciansName1
             reading:NameofPhysicianReadingStudy1
             name:PatientName1
             pid:((existingStudy[@"00100020"])[@"Value"])[0]
             issuer:((existingStudy[@"00100021"])[@"Value"])[0]
             birthdate:((existingStudy[@"00100030"])[@"Value"])[0]
             sex:((existingStudy[@"00100040"])[@"Value"])[0]
             instanceUID:SOPIUID
             seriesUID:seriesUID
             studyUID:studyUID
             studyID:nil
             seriesNumber:@"-16"
             seriesDescription:@"Informe imagenológico"
             enclosureHL7II:CDAID
             enclosureTitle:enclosureTextarea
             enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
             enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
             contentType:@"application/dicom"
             ];
        }
        else //pdf document which is not a report
        {
            POSTenclosedRequest=
            [NSMutableURLRequest
             POSTenclosedToPacs:pacs
             CS:@"ISO_IR 192"
             DA:[DICMTypes DAStringFromDate:now]
             TM:[DICMTypes TMStringFromDate:now]
             TZ:K.defaultTimezone
             AN:AccessionNumber1
             ANLocal:pacs[@"pacstitle"]
             ANUniversal:pacs[@"custodianoid"]
             ANUniversalType:@"ISO"
             modality:@"OT"
             studyDescription:((existingStudy[@"00081030"])[@"Value"])[0]
             procedureCodes:@[]
             referring:ReferringPhysiciansName1
             reading:NameofPhysicianReadingStudy1
             name:PatientName1
             pid:((existingStudy[@"00100020"])[@"Value"])[0]
             issuer:((existingStudy[@"00100021"])[@"Value"])[0]
             birthdate:((existingStudy[@"00100030"])[@"Value"])[0]
             sex:((existingStudy[@"00100040"])[@"Value"])[0]
             instanceUID:SOPIUID
             seriesUID:seriesUID
             studyUID:studyUID
             studyID:nil
             seriesNumber:@"-31"
             seriesDescription:@"documento PDF"
             enclosureHL7II:CDAID
             enclosureTitle:enclosureTextarea
             enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
             enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
             contentType:@"application/dicom"
             ];
        }


    }
    else //No existe AccessionNumber
    {
#pragma mark - NO
        
#pragma mark patient in pacs ?
        NSArray *patients=[NSURLSessionDataTask existsInPacs:pacs pid:PatientID1 issuer:IssuerOfPatientID1 returnAttributes:true];
        if (patients)
        {
            if ([patients count]>1)
            {
                LOG_WARNING(@"[pdf]<request> <-404:  there is more than one patient with pid:%@ and issuer:%@",PatientID1,IssuerOfPatientID1);
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] <request> <-404:  there is more than one patient with pid:%@ and issuer:%@",PatientID1,IssuerOfPatientID1];
            }
            PatientName1=((((patients[0])[@"00100010"])[@"Value"])[0])[@"Alphabetic"];
            PatientBirthdate1=(((patients[0])[@"00100030"])[@"Value"])[0];
            PatientSexValue1=(((patients[0])[@"00100040"])[@"Value"])[0];
        }
        else
        {
            //NO. Create patient
            //PatientName input
            NSMutableString *PatientMutableName=[NSMutableString string];
            
            NSUInteger apellido1Index=[names indexOfObject:@"apellido1"];
            if (apellido1Index==NSNotFound)
            {
                LOG_WARNING(@"[pdf]<request> <-404:  'apellido1' required");
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'apellido1' required"];
            }
            patientFamily1=[[values[apellido1Index] uppercaseString]spaceNormalize];
            [PatientMutableName appendString:patientFamily1];
            
            NSUInteger apellido2Index=[names indexOfObject:@"apellido2"];
            patientFamily2=[[values[apellido2Index] uppercaseString]spaceNormalize];
            if (apellido2Index!=NSNotFound) [PatientMutableName appendFormat:@">%@",patientFamily2];
            
            NSUInteger nombresIndex=[names indexOfObject:@"nombres"];
            patientNames=[[values[nombresIndex] uppercaseString]spaceNormalize];
            
            if (nombresIndex!=NSNotFound) [PatientMutableName appendFormat:@"^%@",patientNames];
            PatientName1=[NSString stringWithString:PatientMutableName];
            
            
            //PatientBirthDate
            NSUInteger PatientBirthDateIndex=[names indexOfObject:@"PatientBirthDate"];
            if (PatientBirthDateIndex==NSNotFound)
            {
                LOG_WARNING(@"[pdf]<request> <-404:  'PatientBirthDate' required");
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientBirthDate' required"];
            }
            PatientBirthdate1=values[PatientBirthDateIndex];
            if (![K.DARegex numberOfMatchesInString:PatientBirthdate1 options:0 range:NSMakeRange(0,[PatientBirthdate1 length])])
            {
                LOG_WARNING(@"[pdf]<request> <-404:  'PatientBirthdate' format should be aaaammdd");
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientBirthdate' format should be aaaammdd"];
            }
            
            //PatientSex
            NSUInteger PatientSexIndex=[names indexOfObject:@"PatientSex"];
            if (PatientSexIndex==NSNotFound)
            {
                LOG_WARNING(@"[pdf]<request> <-404:  'PatientSex' required");
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientSex' required"];
            }
            PatientSexValue1=[values[PatientSexIndex]uppercaseString];
            NSUInteger PatientSexSaluduyIndex=0;
            if ([PatientSexValue1 isEqualToString:@"M"])PatientSexSaluduyIndex=1;
            else if ([PatientSexValue1 isEqualToString:@"F"])PatientSexSaluduyIndex=2;
            else if ([PatientSexValue1 isEqualToString:@"O"])PatientSexSaluduyIndex=9;
            else
            {
                LOG_WARNING(@"[pdf]<request> <-404:  'PatientSex' should be 'M','F' or 'O'");
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] 'PatientSex' should be 'M','F' or 'O'"];
            }
            LOG_VERBOSE(@"[pdf] <PatientID> %@",PatientID1);

            
            
            
            
            NSString *URLString=[NSString stringWithFormat:@"%@/rs/patients/%@%%5E%%5E%%5E%@",
                                 pacs[@"dcm4cheelocaluri"],
                                 PatientID1,IssuerOfPatientID1
                                 ];
            LOG_VERBOSE(@"[pdf] <Patient> PUT  request %@",URLString);
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
            LOG_DEBUG(@"[pdf] <Patient> PUT request HTTPBody: %@",[[NSString alloc] initWithData:[PUTpatientRequest HTTPBody] encoding:NSUTF8StringEncoding]);
            
            NSHTTPURLResponse *PUTpatientResponse=nil;
            //URL properties: expectedContentLength, MIMEType, textEncodingName
            //HTTP properties: statusCode, allHeaderFields
            NSData *PUTpatientResponseData=[NSURLSessionDataTask sendSynchronousRequest:PUTpatientRequest returningResponse:&PUTpatientResponse error:&error];
            NSString *PUTpatientResponseString=[[NSString alloc]initWithData:PUTpatientResponseData encoding:NSUTF8StringEncoding];
            LOG_VERBOSE(@"[pdf] <Patient> PUT response %ld HTTPBody: %@",(long)PUTpatientResponse.statusCode,PUTpatientResponseString);
            if ( error || PUTpatientResponse.statusCode>299)
            {
                LOG_WARNING(@"[pdf]<Patient> <-404:  PUT response: %@",[error description]);
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] can not PUT patient %@. Error: %@",PatientName1,[error description]];
            }
            //check patient created and get the metadata
            if (![NSURLSessionDataTask existsInPacs:pacs pid:PatientID1 issuer:IssuerOfPatientID1 returnAttributes:false])
            {
                LOG_WARNING(@"[pdf]<request> <-404:  could not create in pacs patient with pid:%@ and issuer:%@",PatientID1,IssuerOfPatientID1);
                return [RSErrorResponse responseWithClientError:404 message:@"[pdf] <request> <-404:  could not create in pacs patient with pid:%@ and issuer:%@",PatientID1,IssuerOfPatientID1];
            }
        }
        
#pragma mark create a new study with the report
    
#pragma mark validation StudyDescription

        NSDictionary *pacsProcedureDict=nil;
        NSInteger procedureIndex=NSNotFound;
        //K.schemeindexes
        NSUInteger schemeIndex=NSNotFound;//depending on the usage (dicom, CDA, etc) the scheme may have diferent name !
        
        NSUInteger StudyDescriptionIndex=[names indexOfObject:@"StudyDescription"];
        NSString *StudyDescription1=nil;
        NSArray *StudyDescription1Array=nil;
        if (StudyDescriptionIndex==NSNotFound)
        {
            LOG_WARNING(@"[pdf]<Request> <-404:  studyDescription required");
            return [RSErrorResponse responseWithClientError:404 message:@"[pdf] studyDescription required"];
        }
        else
        {
            StudyDescription1=[values[StudyDescriptionIndex]spaceNormalize];
            StudyDescription1Array=[StudyDescription1 componentsSeparatedByString:@"^"];
            if ([StudyDescription1Array count]!=3) LOG_WARNING(@"[pdf] <title> outside catalog: %@",StudyDescription1);
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
                            if (schemeIndex==NSNotFound)
                            {
                                schemeIndex=[K.schemeindexes[@"hl7v2"] indexOfObject:filter];
                                if (schemeIndex==NSNotFound)
                                {
                                    LOG_WARNING(@"[pdf]<Request> <-404:  code scheme '%@' not known",filter);
                                    return [RSErrorResponse responseWithClientError:404 message:@"[pdf] code scheme '%@' not known",filter];
                                }
                            }
                        }
                    }
                }
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
                                    LOG_WARNING(@"[pdf] study description includes an ambiguous code which belongs to various procedures: %@",StudyDescription1);
                                    break;
                                }
                            }
                            
                            procedureIndex=[pacsProcedureDict[@"displayname"] indexOfObject:thisCode];
                        }
                    }
                }
                //no match at all
                if (procedureIndex==NSNotFound)
                {
                    LOG_WARNING(@"[pdf]<Request> <-404:  code '%@' not known in pacs %@",StudyDescription1Array[0], pacsUID1);
                    return [RSErrorResponse responseWithClientError:404 message:@"[pdf] code '%@' not known in pacs %@",StudyDescription1Array[0], pacsUID1];
                }
                LOG_VERBOSE(@"[pdf] <procedure> %@",StudyDescription1Array[0]);
            }
        }
    

#pragma mark <recordTarget> +
        
        [dscd appendCDARecordTargetWithPid:PatientID1
                                    issuer:IssuerOfPatientID1
                                 apellido1:patientFamily1
                                 apellido2:patientFamily2
                                   nombres:patientNames
                                       sex:PatientSexValue1
                                 birthdate:PatientBirthdate1];

#pragma mark <author> +
        if (NameofPhysicianReadingStudy1 && [NameofPhysicianReadingStudy1 length])
        {
            NSArray  *readingInstServProf=[NameofPhysicianReadingStudy1 componentsSeparatedByString:@"^"];
            NSString* institution=readingInstServProf[0];
            NSString* service=nil;
            NSString* user=nil;
            if ([readingInstServProf count]>1) service=readingInstServProf[1];
            if ([readingInstServProf count]>2) user=readingInstServProf[2];
            
            [dscd appendCDAAuthorInstitution:institution
                                     service:service
                                        user:user];
        }
        else [dscd appendCDAAuthorAnonymousOrgid:pacsUID1 orgname:pacs[@"custodiantitle"]];

#pragma mark <dataEnterer> ?
#pragma mark <informant> *

#pragma mark <custodian> 1
    [dscd appendCDACustodianOid:pacs[@"custodianoid"]
                           name:pacs[@"custodiantitle"]];

#pragma mark <informationRecipient> *
    //(=ReferringPhysiciansName)
    NSUInteger ReferringPhysiciansNameIndex=[names indexOfObject:@"ReferringPhysiciansName"];
    if (ReferringPhysiciansNameIndex!=NSNotFound) ReferringPhysiciansName1=[values[ReferringPhysiciansNameIndex] spaceNormalize];
    if (ReferringPhysiciansName1) [dscd appendCDAInformationRecipient:ReferringPhysiciansName1];

#pragma mark <legalAuthenticator> ?
#pragma mark <authenticator> *
#pragma mark <participant> *
    

#pragma mark <inFulfillentOf> * <Order>
    //(=AccessionNumber)

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
        
    [dscd appendCDAsuffix];
    [dscd appendSCDsuffix];
    [dscd appendDSCDsuffix];
    
#pragma mark request to CREATE new study

    studyUID=[[NSUUID UUID]ITUTX667UIDString];
    seriesUID=[[NSUUID UUID]ITUTX667UIDString];
    SOPIUID=[[NSUUID UUID]ITUTX667UIDString];

    
    //dicom object
    if ([pdfType isEqualToString:@"informe"]||[pdfType isEqualToString:@"report"])
    {
        POSTenclosedRequest=
        [NSMutableURLRequest
         POSTenclosedToPacs:pacs
         CS:@"ISO_IR 192"
         DA:[DICMTypes DAStringFromDate:now]
         TM:[DICMTypes TMStringFromDate:now]
         TZ:K.defaultTimezone
         AN:AccessionNumber1
         ANLocal:pacs[@"pacstitle"]
         ANUniversal:pacs[@"custodianoid"]
         ANUniversalType:@"ISO"
         modality:@"DOC"
         studyDescription:StudyDescription1
         procedureCodes:@[]
         referring:ReferringPhysiciansName1
         reading:NameofPhysicianReadingStudy1
         name:PatientName1
         pid:PatientID1
         issuer:IssuerOfPatientID1
         birthdate:PatientBirthdate1
         sex:PatientSexValue1
         instanceUID:SOPIUID
         seriesUID:seriesUID
         studyUID:studyUID
         studyID:nil
         seriesNumber:@"-16"
         seriesDescription:@"Informe imagenológico"
         enclosureHL7II:CDAID
         enclosureTitle:enclosureTextarea
         enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
         enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
         contentType:@"application/dicom"
         ];
    }
    else //pdf document which is not a report
    {
        POSTenclosedRequest=
        [NSMutableURLRequest
         POSTenclosedToPacs:pacs
         CS:@"ISO_IR 192"
         DA:[DICMTypes DAStringFromDate:now]
         TM:[DICMTypes TMStringFromDate:now]
         TZ:K.defaultTimezone
         AN:AccessionNumber1
         ANLocal:pacs[@"pacstitle"]
         ANUniversal:pacs[@"custodianoid"]
         ANUniversalType:@"ISO"
         modality:@"OT"
         studyDescription:StudyDescription1
         procedureCodes:@[]
         referring:ReferringPhysiciansName1
         reading:NameofPhysicianReadingStudy1
         name:PatientName1
         pid:PatientID1
         issuer:IssuerOfPatientID1
         birthdate:PatientBirthdate1
         sex:PatientSexValue1
         instanceUID:SOPIUID
         seriesUID:seriesUID
         studyUID:studyUID
         studyID:nil
         seriesNumber:@"-31"
         seriesDescription:@"documento PDF"
         enclosureHL7II:CDAID
         enclosureTitle:enclosureTextarea
         enclosureTransferSyntax:@"1.2.840.10008.5.1.4.1.1.104.2"
         enclosureData:[dscd dataUsingEncoding:NSUTF8StringEncoding]
         contentType:@"application/dicom"
         ];
    }
    }
        
#pragma mark - POST request
        
    NSHTTPURLResponse *POSTenclosedResponse=nil;
    //URL properties: expectedContentLength, MIMEType, textEncodingName
    //HTTP properties: statusCode, allHeaderFields
    
    NSData *POSTenclosedResponseData=[NSURLConnection sendSynchronousRequest:POSTenclosedRequest returningResponse:&POSTenclosedResponse error:&error];
    
    NSString *POSTenclosedResponseString=[[NSString alloc]initWithData:POSTenclosedResponseData encoding:NSUTF8StringEncoding];
    LOG_VERBOSE(@"[pdf]<cda> POST %@ (body length:%ld) <-%ld",
             [POSTenclosedRequest.URL absoluteURL],
             (long)[POSTenclosedRequest.HTTPBody length],
             (long)POSTenclosedResponse.statusCode);

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
        
        
        LOG_ERROR(@"[pdf]<stow dicom> can not send to pacs for patient: %@.\r\n%@\r\n%@",PatientName1,[error description], POSTenclosedResponseString);
        return [RSErrorResponse responseWithClientError:404 message:@"[pdf] can not send to pacs for patient: %@\r\n%@\r\n%@",PatientName1,[error description], POSTenclosedResponseString];
    }

    NSMutableString* html = [NSMutableString stringWithString:@"<html><head><title>response</title></head><body>"];
    [html appendFormat:@"<p>solicitud dicom cda sent to %@</p>",pacs[@"dcm4cheelocaluri"]];
        
        
#pragma mark - qido of the stow, in order to actualize metadata in pacs
    if (![NSURLSessionDataTask existsInPacs:(NSDictionary*)pacs
                                   studyUID:(NSString*)studyUID
                                  seriesUID:(NSString*)seriesUID
                                     sopUID:(NSString*)SOPIUID
                           returnAttributes:false]) [html appendString:@"<p>qido failed</p>"];
    else
    {
        if (    ![NameofPhysicianReadingStudy1 isEqualToString:@"*'"]
            &&  ![NameofPhysicianReadingStudy1 isEqualToString:custom3]
        )
        {

            NSString *sql=[NSString stringWithFormat:
                            @"export MYSQL_PWD=pacs;/usr/local/mysql/bin/mysql -upacs -h 127.0.0.1 -b pacsdb -e \"UPDATE study SET study_custom3='%@' WHERE accession_no='%@';\"",
                            NameofPhysicianReadingStudy1,
                            AccessionNumber1];
             //NSLog(@"%@",sql);
             NSMutableData *sqlResp=[NSMutableData data];
             if (bash([sql dataUsingEncoding:NSUTF8StringEncoding],sqlResp))
                 [html appendFormat:@"<p>new study_custom3: %@ failed. %@</p>",NameofPhysicianReadingStudy1,[[NSString alloc] initWithData:sqlResp encoding:NSUTF8StringEncoding] ];
             else [html appendFormat:@"<p>new study_custom 3: %@</p>",NameofPhysicianReadingStudy1];

        }

        [html appendString:@"<p>qido OK</p>"];
#pragma mark - create user in html5dicom
    
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
         
         
         
         POSThtml5dicomuserRequest:(NSString*)URLString
         institution:(NSString*)institution
         username:(NSString*)username
         password:(NSString*)password
         firstname:(NSString*)firstname
         lastname:(NSString*)lastname
         isactive:(BOOL)isactive
         timeout:(NSTimeInterval)timeout
         */
        
        NSString *clave1String=nil;
        NSUInteger clave1Index=[names indexOfObject:@"clave"];
        if ((clave1Index!=NSNotFound) && [values[clave1Index] length])
            clave1String=values[clave1Index];

        NSMutableURLRequest *POSThtml5dicomuserRequest=[NSMutableURLRequest
                 POSThtml5dicomuserRequest:pacs[@"html5dicomuserserviceuri"]
                 institution:pacs[@"custodiantitle"]
                 username:PatientID1
                 password:clave1String
                 firstname:patientNames
                 lastname:[NSString stringWithFormat:@"%@ %@",patientFamily1, patientFamily2]
                 isactive:true
                 timeout:[pacs[@"timeoutinterval"] integerValue]
                 ];
        
        NSString *POSThtml5dicomuserRequestBodyString=[[NSString alloc]initWithData:POSThtml5dicomuserRequest.HTTPBody encoding:NSUTF8StringEncoding];
        
        NSHTTPURLResponse *POSThtml5dicomuserResponse=nil;
        NSData *POSThtml5dicomuserRequestResponseData=[NSURLConnection sendSynchronousRequest:POSThtml5dicomuserRequest    returningResponse:&POSThtml5dicomuserResponse error:&error];
        
        NSString *POSThtml5dicomuserRequestResponseString=[[NSString alloc]initWithData:POSThtml5dicomuserRequestResponseData encoding:NSUTF8StringEncoding];
                
        if (POSThtml5dicomuserResponse.statusCode==201) [html appendFormat:@"<p>patient %@ created in %@ %@</p>",PatientID1,pacs[@"html5dicomuserserviceuri"],POSThtml5dicomuserRequestBodyString];
        else
        {
            NSString *POSThtml5dicomuserRequestResponseString=[[NSString alloc]initWithData:POSThtml5dicomuserRequestResponseData encoding:NSUTF8StringEncoding];
                    
            LOG_ERROR(@"[pdf] %@\r\n%@", POSThtml5dicomuserRequestBodyString, POSThtml5dicomuserRequestResponseString);
            
            [html appendFormat:@"<p>patient %@ NOT created in %@</p>",PatientID1,pacs[@"html5dicomuserserviceuri"]];
        }
    }
    /*
     
     // TODO create array procedureCode {code, scheme meaning, traduction}
     NSMutableArray *mutableArray=[NSMutableArray array];
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
     // TOOD translation
     }
     }

     
     

     
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

    
/*
    //restore reading
    NSString *sqlUpdate=[NSString stringWithFormat:@"export MYSQL_PWD=pacs;/usr/local/mysql/bin/mysql -upacs -h 127.0.0.1 -b pacsdb -e \"UPDATE study SET study_custom3='%@' WHERE accession_no='%@';\"",custom3,AccessionNumber1];
    NSMutableData *sqlUpdateResp=[NSMutableData data];
    if (bash([sqlUpdate dataUsingEncoding:NSUTF8StringEncoding],sqlUpdateResp))
        [html appendFormat:@"<p>an:%@ udpate to rad:'%@' failed. %@</p>",AccessionNumber1,custom3,[[NSString alloc] initWithData:sqlUpdateResp encoding:NSUTF8StringEncoding] ];
    else [html appendFormat:@"<p>an:%@ restored rad:%@</p>",AccessionNumber1,custom3];
*/

    [html appendString:@"</body></html>"];
     
    
    
     return [RSDataResponse responseWithHTML:html];
     
     
     
     }(request));}];
}
@end
