//
//  NSMutableString+DSCD.m
//  httpdicom
//
//  Created by jacquesfauquex on 20171217.
//  Copyright © 2017 opendicom.com. All rights reserved.
//

#import "NSMutableString+DSCD.h"
#import "DICMTypes.h"
#import "NSUUID+DICM.h"
#import "K.h"

@implementation NSMutableString (DSCD)
-(void)appendDSCDprefix
{
    
    //[self appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><?xml-stylesheet type=\"text/xsl\" href=\"#Transform\"?><!DOCTYPE document [<!ATTLIST xsl:stylesheet id ID #REQUIRED>]><dscd xmlns:cda=\"urn:hl7-org:v3\" xmlns:sdtc=\"urn:hl7-org:sdtc\" xmlns:scd=\"urn:salud.uy/2014/signed-clinical-document\"><xsl:stylesheet id=\"Transform\" version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" xmlns:cda=\"urn:hl7-org:v3\" xmlns:scd=\"urn:salud.uy/2014/signed-clinical-document\" xmlns:sdtc=\"urn:hl7-org:sdtc\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\" xmlns=\"http://www.w3.org/1999/xhtml\"><xsl:variable name=\"cda\" select=\"dscd/scd:SignedClinicalDocument/cda:ClinicalDocument\"/><xsl:template match=\"/\"><html><head><title><xsl:value-of select=\"$cda/cda:title/text()\"/></title><style type=\"text/css\"> body { color: #003366; background-color: #FFFFFF; font-family: Verdana, Tahoma, sans-serif; font-size: 13px; } h2 { font-size: 17pt; font-weight: bold; text-align: center; } label.level1 { font-size: 14pt; font-weight: bold; margin-bottom: 0; padding-bottom: 0; } label.level2 { font-size: 11pt; font-weight: bold; margin-bottom: 0; padding-bottom: 0; } label.level3 { font-weight: bold; margin-bottom: 0; padding-bottom: 0; } table { width:100%; margin-bottom:2em; } th,td { width:50%; } dt { float: left; clear: left; width: 200px; text-align: left; font-weight: bold; color: green; } dt:after { content: \":\"; } dd { margin: 0 0 0 210px; padding: 0 0 0.5em 0; } div { margin: 2em; } section { margin: 0 0 0 0; padding: 0 0 0 0;} .left,.right { float: left; width: 50%; margin:0%; overflow:scroll; } article { height: auto; margin-bottom: 2em; } tbody>tr>th { text-align: right; font-weight: normal; } tbody>tr>td { text-align: left; font-weight: bold; } p { margin: 0 0 0 0; padding: 0 0 0 0; }</style></head><body><h2><xsl:value-of select=\"$cda/cda:title/text()\"/></h2><hr/><table><tr><td><xsl:text>Paciente: </xsl:text><b><xsl:call-template name=\"getPersonName\"><xsl:with-param name=\"personName\" select=\"$cda/cda:recordTarget/cda:patientRole/cda:patient/cda:name\"/></xsl:call-template><xsl:text> </xsl:text></b></td><td><xsl:text>Identificación del Paciente: </xsl:text><b><xsl:value-of select=\"concat($cda/cda:recordTarget/cda:patientRole/cda:id/@extension,'^^^',$cda/cda:recordTarget/cda:patientRole/cda:id/@root)\"/></b></td></tr><tr><td><xsl:text>Fecha de Nacimiento: </xsl:text><b><xsl:call-template name=\"formatDate\"><xsl:with-param name=\"date\" select=\"$cda/cda:recordTarget/cda:patientRole/cda:patient/cda:birthTime/@value\"/></xsl:call-template></b></td><td><xsl:text>Sexo: </xsl:text><b><xsl:value-of select=\"$cda/cda:recordTarget[1]/cda:patientRole[1]/cda:patient[1]/cda:name[1]/cda:administrativeGenderCode[1]/@displayName\"/></b></td></tr><tr><td><br/></td><td><br/></td></tr><tr><td><xsl:text>Institución solicitante: </xsl:text><b><xsl:value-of select=\"$cda/cda:informationRecipient/cda:intendedRecipient/cda:informationRecipient/cda:name/text()\"/></b></td><td><xsl:text>Fecha estudio: </xsl:text><b><xsl:call-template name=\"formatDate\"><xsl:with-param name=\"date\" select=\"$cda/cda:documentationOf[1]/cda:serviceEvent[1]/cda:effectiveTime[1]/cda:low[1]/@value\"/></xsl:call-template></b></td></tr><tr><td><xsl:text>Estudio: </xsl:text><b><xsl:value-of select=\"$cda/cda:title/text()\"/></b></td><td><xsl:text>Número acceso: </xsl:text><b><xsl:value-of select=\"$cda/cda:inFulfillmentOf[1]/cda:order[1]/cda:id[1]/@extension\"/></b></td></tr></table><hr/><xsl:apply-templates select=\"$cda/cda:component[1]/*/cda:text[1]\"/></body></html></xsl:template><xsl:template name=\"getPersonName\"><xsl:param name=\"personName\"/><xsl:value-of select=\"$personName/cda:family[1]/text()\"/><xsl:if test=\"$personName/cda:family[2]\"><xsl:value-of select=\"concat('>',$personName/cda:family[2]/text())\"/></xsl:if><xsl:value-of select=\"'^'\"/><xsl:for-each select=\"$personName/cda:given\"><xsl:value-of select=\"text()\"/><xsl:text> </xsl:text></xsl:for-each></xsl:template><xsl:template name=\"formatDate\"><xsl:param name=\"date\"/><xsl:if test=\"$date != ''\"><xsl:value-of select=\"substring ($date, 1, 4)\"/><xsl:text>-</xsl:text><xsl:value-of select=\"substring ($date, 5, 2)\"/><xsl:text>-</xsl:text><xsl:value-of select=\"substring ($date, 7, 2)\"/></xsl:if></xsl:template><xsl:template name=\"formatTime\"><xsl:param name=\"date\"/><xsl:if test=\"$date != ''\"><xsl:text>T</xsl:text><xsl:value-of select=\"substring ($date, 9, 2)\"/><xsl:text>:</xsl:text><xsl:value-of select=\"substring ($date, 11, 2)\"/><xsl:text>:</xsl:text><xsl:value-of select=\"substring ($date, 13, 2)\"/></xsl:if></xsl:template><xsl:template match=\"cda:text\"><xsl:choose><xsl:when test=\"@mediaType='text/plain' and text() != ''\"><xsl:value-of select=\"text()\"/></xsl:when><xsl:when test=\"@mediaType='application/pdf'\"><xsl:element name=\"a\"><xsl:attribute name=\"href\"><xsl:value-of select=\"cda:reference/@value\"></xsl:value-of></xsl:attribute><xsl:choose><xsl:when test=\"text() != ''\"><xsl:value-of select=\"text()\"/></xsl:when><xsl:otherwise><xsl:text>pdf</xsl:text></xsl:otherwise></xsl:choose></xsl:element></xsl:when><xsl:otherwise><xsl:text>ningun adjunto</xsl:text></xsl:otherwise></xsl:choose></xsl:template></xsl:stylesheet>"];
    

    [self appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><?xml-stylesheet type=\"text/xsl\" href=\"#Transform\"?><!DOCTYPE document [<!ATTLIST xsl:stylesheet id ID #REQUIRED>]><dscd xmlns:cda=\"urn:hl7-org:v3\" xmlns:sdtc=\"urn:hl7-org:sdtc\" xmlns:scd=\"urn:salud.uy/2014/signed-clinical-document\"><xsl:stylesheet id=\"Transform\" version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" xmlns:cda=\"urn:hl7-org:v3\" xmlns:scd=\"urn:salud.uy/2014/signed-clinical-document\" xmlns:sdtc=\"urn:hl7-org:sdtc\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\" xmlns=\"http://www.w3.org/1999/xhtml\"><xsl:variable name=\"cda\" select=\"dscd/scd:SignedClinicalDocument/cda:ClinicalDocument\"/><xsl:template match=\"/\"><html><head><title><xsl:value-of select=\"$cda/cda:title/text()\"/></title><style type=\"text/css\"> body { color: #003366; background-color: #FFFFFF; font-family: Verdana, Tahoma, sans-serif; font-size: 13px; } h2 { font-size: 17pt; font-weight: bold; text-align: center; } label.level1 { font-size: 14pt; font-weight: bold; margin-bottom: 0; padding-bottom: 0; } label.level2 { font-size: 11pt; font-weight: bold; margin-bottom: 0; padding-bottom: 0; } label.level3 { font-weight: bold; margin-bottom: 0; padding-bottom: 0; } table { width:100%; margin-bottom:2em; } th,td { width:50%; } dt { float: left; clear: left; width: 200px; text-align: left; font-weight: bold; color: green; } dt:after { content: \":\"; } dd { margin: 0 0 0 210px; padding: 0 0 0.5em 0; } div { margin: 2em; } section { margin: 0 0 0 0; padding: 0 0 0 0;} .left,.right { float: left; width: 50%; margin:0%; overflow:scroll; } article { height: auto; margin-bottom: 2em; } tbody>tr>th { text-align: right; font-weight: normal; } tbody>tr>td { text-align: left; font-weight: bold; } p { margin: 0 0 0 0; padding: 0 0 0 0; }</style></head><body><h2><xsl:value-of select=\"$cda/cda:title/text()\"/></h2><hr/><table><tr><td><xsl:text>Paciente: </xsl:text><b><xsl:call-template name=\"getPersonName\"><xsl:with-param name=\"personName\" select=\"$cda/cda:recordTarget/cda:patientRole/cda:patient/cda:name\"/></xsl:call-template><xsl:text> </xsl:text></b></td><td><xsl:text>Identificación del Paciente: </xsl:text><b><xsl:value-of select=\"concat($cda/cda:recordTarget/cda:patientRole/cda:id/@extension,'^^^',$cda/cda:recordTarget/cda:patientRole/cda:id/@root)\"/></b></td></tr><tr><td><xsl:text>Fecha de Nacimiento: </xsl:text><b><xsl:call-template name=\"formatDate\"><xsl:with-param name=\"date\" select=\"$cda/cda:recordTarget/cda:patientRole/cda:patient/cda:birthTime/@value\"/></xsl:call-template></b></td><td><xsl:text>Sexo: </xsl:text><b><xsl:value-of select=\"$cda/cda:recordTarget[1]/cda:patientRole[1]/cda:patient[1]/cda:name[1]/cda:administrativeGenderCode[1]/@displayName\"/></b></td></tr><tr><td><br/></td><td><br/></td></tr><tr><td><xsl:text>Institución solicitante: </xsl:text><b><xsl:value-of select=\"$cda/cda:informationRecipient/cda:intendedRecipient/cda:informationRecipient/cda:name/text()\"/></b></td><td><xsl:text>Fecha estudio: </xsl:text><b><xsl:call-template name=\"formatDate\"><xsl:with-param name=\"date\" select=\"$cda/cda:documentationOf[1]/cda:serviceEvent[1]/cda:effectiveTime[1]/cda:low[1]/@value\"/></xsl:call-template></b></td></tr><tr><td><xsl:text>Estudio: </xsl:text><b><xsl:value-of select=\"$cda/cda:title/text()\"/></b></td><td><xsl:text>Número acceso: </xsl:text><b><xsl:value-of select=\"$cda/cda:inFulfillmentOf[1]/cda:order[1]/cda:id[1]/@extension\"/></b></td></tr></table><hr/><xsl:apply-templates select=\"$cda/cda:component[1]/*/cda:text[1]\"/></body></html></xsl:template><xsl:template name=\"getPersonName\"><xsl:param name=\"personName\"/><xsl:value-of select=\"$personName/cda:family[1]/text()\"/><xsl:if test=\"$personName/cda:family[2]\"><xsl:value-of select=\"concat('>',$personName/cda:family[2]/text())\"/></xsl:if><xsl:value-of select=\"'^'\"/><xsl:for-each select=\"$personName/cda:given\"><xsl:value-of select=\"text()\"/><xsl:text> </xsl:text></xsl:for-each></xsl:template><xsl:template name=\"formatDate\"><xsl:param name=\"date\"/><xsl:if test=\"$date != ''\"><xsl:value-of select=\"substring ($date, 1, 4)\"/><xsl:text>-</xsl:text><xsl:value-of select=\"substring ($date, 5, 2)\"/><xsl:text>-</xsl:text><xsl:value-of select=\"substring ($date, 7, 2)\"/></xsl:if></xsl:template><xsl:template name=\"formatTime\"><xsl:param name=\"date\"/><xsl:if test=\"$date != ''\"><xsl:text>T</xsl:text><xsl:value-of select=\"substring ($date, 9, 2)\"/><xsl:text>:</xsl:text><xsl:value-of select=\"substring ($date, 11, 2)\"/><xsl:text>:</xsl:text><xsl:value-of select=\"substring ($date, 13, 2)\"/></xsl:if></xsl:template><xsl:template match=\"cda:text\"><xsl:choose><xsl:when test=\"@mediaType='text/plain' and text() != ''\"><xsl:value-of select=\"text()\"/></xsl:when><xsl:when test=\"@mediaType='application/pdf'\"><xsl:element name=\"iframe\"><xsl:attribute name=\"src\"><xsl:value-of select=\"cda:reference/@value\"/></xsl:attribute><xsl:attribute name=\"frameborder\">0</xsl:attribute><xsl:attribute name=\"width\">100%</xsl:attribute><xsl:attribute name=\"height\">450</xsl:attribute></xsl:element></xsl:when><xsl:otherwise><xsl:text>ningun adjunto</xsl:text></xsl:otherwise></xsl:choose></xsl:template></xsl:stylesheet>"];

}

-(void)appendSCDprefix
{
    [self appendString:@"<SignedClinicalDocument xmlns=\"urn:salud.uy/2014/signed-clinical-document\">"];
}

-(void)appendCDAprefix
{
    [self appendString:@"<ClinicalDocument xmlns=\"urn:hl7-org:v3\" xmlns:voc=\"urn:hl7-org:v3/voc\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"];
    [self appendString:@"<typeId root=\"2.16.840.1.113883.1.3\" extension=\"POCD_HD000040\"/>"];
}

-(void)appendCDAsuffix
{
    [self appendString:@"</ClinicalDocument>"];
}

-(void)appendSCDsuffix
{
    [self appendString:@"</SignedClinicalDocument>"];
}

-(void)appendDSCDsuffix
{
    [self appendString:@"</dscd>"];
}

-(void)appendCDATemplateId:(NSString*)UIDString
{
    [self appendFormat:@"<templateId root=\"%@\"/>",UIDString];
}

-(void)appendCDAID:(NSString*)CDAID
{
    [self appendFormat:@"<id root=\"%@\"/>",CDAID];
}

-(void)appendRequestCDATitle:(NSString*)title
{
    /*
     Requested imaging studies information
     https://s.details.loinc.org/LOINC/55115-0.html
     */
    [self appendFormat:@"<code code=\"55115-0\" codeSystem=\"2.16.840.1.113883.6.1\" codeSystemName=\"LOINC\" displayName=\"Solicitud de estudio imagenologico\"/><title>%@</title>", title];
}

-(void)appendReportCDATitle:(NSString*)title
{
    [self appendFormat:@"<code code=\"18748-4\" codeSystem=\"2.16.840.1.113883.6.1\" codeSystemName=\"LOINC\" displayName=\"Solicitud de Diagnóstico imagenologico\"/><title>%@</title>", title];
}

-(void)appendCurrentCDAEffectiveTime
{
    [self appendFormat:@"<effectiveTime value=\"%@\"/>",[DICMTypes DTStringFromDate:[NSDate date]]];
}

-(void)appendNormalCDAConfidentialityCode
{
    [self appendString:@"<confidentialityCode code=\"N\" codeSystem=\"2.16.840.1.113883.5.25\" codeSystemName=\"HL7\" displayName=\"normal\"/>"];
}

-(void)appendEsCDALanguageCode
{
    [self appendString:@"<languageCode code=\"es\"/>"];
}

-(void)appendFirstCDAVersionNumber
{
    [self appendString:@"<versionNumber value=\"1\"/>"];
}

-(void)appendCDARecordTargetWithPid:(NSString*)pid
                             issuer:(NSString*)issuer
                          apellido1:(NSString*)apellido1
                          apellido2:(NSString*)apellido2
                            nombres:(NSString*)nombres
                                sex:(NSString*)sex
                          birthdate:(NSString*)birthdate
{
    NSArray *nombresArray=[nombres componentsSeparatedByString:@" "];
    NSMutableString *nombresString=[NSMutableString string];
    for (NSString *nombre in nombresArray)
    {
        [nombresString appendFormat:@"<given>%@</given>",nombre];
    }
    
    NSString *sexString=nil;
    if ([sex isEqualToString:@"M"])
        sexString=@"<administrativeGenderCode displayName=\"Masculino\" codeSystem=\"2.16.858.2.10000675.69600\" code=\"1\"></administrativeGenderCode>";
    else if ([sex isEqualToString:@"F"])
        sexString=@"<administrativeGenderCode displayName=\"Femenino\" codeSystem=\"2.16.858.2.10000675.69600\" code=\"2\"></administrativeGenderCode>";
    else
        sexString=@"<administrativeGenderCode displayName=\"otro\" codeSystem=\"2.16.858.2.10000675.69600\" code=\"9\"></administrativeGenderCode>";

    [self appendFormat:@"<recordTarget><patientRole><id root=\"%@\" extension=\"%@\"/><patient><name>%@<family>%@</family><family>%@</family>%@</name><birthTime value=\"%@\"/></patient></patientRole></recordTarget>",
     issuer,
     pid,
     nombresString,
     apellido1,
     apellido2,
     sexString,
     birthdate];
}

-(void)appendCDAAuthorTime:(NSString*)time
                      root:(NSString*)root
                 extension:(NSString*)extension
                     given:(NSString*)given
                    family:(NSString*)family
                     orgid:(NSString*)orgid
                   orgname:(NSString*)orgname
{
    //root+extension compulsory
    [self appendFormat:@"<author><time value=\"%@\"/><assignedAuthor><id root=\"%@\" extension=\"%@\"/><assignedPerson><name><given>%@</given><family>%@</family></name></assignedPerson><representedOrganization><id root=\"%@\"/><name>%@</name></representedOrganization></assignedAuthor></author>",
     time,
     root,
     extension,
     given,
     family,
     orgid,
     orgname
     ];
}

-(void)appendCDAAuthorInstitution:(NSString*)institution
                          service:(NSString*)service
                             user:(NSString*)user
{
    //time compulsory
    //root+extension compulsory
    if (!institution) institution=@"-";
    if (!service) service=@"-";
    if (!user) user=@"-";
    [self appendFormat:@"<author><time value=\"%@\"/><assignedAuthor><id/><assignedPerson><name><family>%@</family></name></assignedPerson><representedOrganization><name>%@^%@</name></representedOrganization></assignedAuthor></author>",
     [DICMTypes DTStringFromDate:[NSDate date]],
     user,
     institution,
     service
     ];
}

-(void)appendCDAAuthorAnonymousOrgid:(NSString*)orgid
                             orgname:(NSString*)orgname
{
    //time compulsory
    //root+extension compulsory
    [self appendFormat:@"<author><time value=\"%@\"/><assignedAuthor nullFlavor=\"NA\"><id/><representedOrganization><id root=\"%@\"/><name>%@</name></representedOrganization></assignedAuthor></author>",
     [DICMTypes DTStringFromDate:[NSDate date]],
     orgid,
     orgname
     ];
}

-(void)appendCDACustodianOid:(NSString*)oid
                        name:(NSString*)name
{
    [self appendFormat:@"<custodian><assignedCustodian><representedCustodianOrganization><id root=\"%@\"/><name>%@</name></representedCustodianOrganization></assignedCustodian></custodian>",oid,name];
}

-(void)appendCDAInformationRecipient:(NSString*)ReferringPhysiciansName1
{
    [self appendFormat:@"<informationRecipient><intendedRecipient classCode=\"ASSIGNED\"><informationRecipient><name>%@</name></informationRecipient></intendedRecipient></informationRecipient>",ReferringPhysiciansName1];
}


-(void)appendCDAInFulfillmentOfOrder:(NSString*)AccessionNumber1 issuerOID:(NSString*)issuerOID
{
    [self appendFormat:@"<inFulfillmentOf><order><id root=\"%@\" extension=\"%@\"/></order></inFulfillmentOf>",issuerOID,AccessionNumber1];
}



-(void)appendCDADocumentationOfNotCoded:(NSString*)StudyDescription1
{
    if ([StudyDescription1 length]) [self appendFormat:@"<documentationOf><serviceEvent><code><originalText>%@</originalText></code></serviceEvent></documentationOf>",StudyDescription1];
}
-(void)appendCDADocumentationOf:(NSString*)StudyDescription1 fromPacsProcedureDict:(NSDictionary*)pacsProcedureDict procedureIndex:(NSUInteger)procedureIndex schemeIndex:(NSUInteger)schemeIndex
{
    NSMutableString *serviceEvents=[NSMutableString string];
    
    NSDictionary *standarizedSchemesCodes=(pacsProcedureDict[@"codes"])[procedureIndex];
    for (NSString *standarizedScheme in standarizedSchemesCodes)
    {
        NSString *standarizedCode=standarizedSchemesCodes[standarizedScheme];
        NSDictionary *standarizedCodeDict=(K.code[standarizedScheme])[standarizedCode];
 
        NSString *codeSystem=nil;
        if ((K.scheme[standarizedScheme])[@"oid"]) codeSystem=[NSString stringWithFormat:@" codeSystem=\"%@\"",(K.scheme[standarizedScheme])[@"oid"]];
        else codeSystem=@"";
        
        NSString *codeSystemName=nil;
        if ((K.scheme[standarizedScheme])[@"hl7v2"]) codeSystemName=[NSString stringWithFormat:@" codeSystemName=\"%@\"",(K.scheme[standarizedScheme])[@"hl7v2"]];
        else codeSystemName=@"";
        
        NSString *codeSystemVersion=nil;
        if ((K.scheme[standarizedScheme])[@"version"]) codeSystemVersion=[NSString stringWithFormat:@" codeSystemVersion=\"%@\"",(K.scheme[standarizedScheme])[@"version"]];
        else codeSystemVersion=@"";

        NSMutableString *serviceEvent=[NSMutableString stringWithFormat:@"<serviceEvent><code code=\"%@\"%@%@%@ displayName=\"%@\"><originalText>%@</originalText>",
                                       standarizedCode,
                                       codeSystem,
                                       codeSystemName,
                                       codeSystemVersion,
                                       (K.scheme[standarizedScheme])[@"description"],
                                       StudyDescription1];
        
        if ([standarizedCodeDict[@"translation"] count])
        {
#pragma mark TOOD translation
        }
        
        
        [serviceEvent appendString:@"</code></serviceEvent>"];
        
        //<performer></performer><effectiveTime></effectiveTime> could be added within serviceEvent only when the mpps is received
        
        [serviceEvents appendString:serviceEvent];
    }
    [self appendFormat:@"<documentationOf>%@</documentationOf>",serviceEvents];
}


-(void)appendCDAComponentOfEncompassingEncounterEffectiveTime:(NSString*)DT
{
    [self appendFormat:@"<componentOf><encompassingEncounter><effectiveTime value=\"%@\"></effectiveTime></encompassingEncounter></componentOf>",DT];
}

     
/*
-(void)appendCDARequestFrom:(NSString*)requesterName
                     issuer:(NSString*)issuer
            accessionNumber:(NSString*)accessionNumber
                   studyUID:(NSString*)studyUID
             procedureCodes:(NSArray*)procedureCodes
                   datetime:(NSString*)DT
{
    [self appendFormat:@"<informationRecipient><intendedRecipient classCode=\"ASSIGNED\"><informationRecipient><name>%@</name></informationRecipient></intendedRecipient></informationRecipient><inFulfillmentOf><order><id root=\"%@\" extension=\"%@\"/></order></inFulfillmentOf><documentationOf><serviceEvent><id root=\"%@\"/><code code=\"%@\" codeSystem=\"%@\" displayName=\"%@\"></code><effectiveTime><low value=\"%@\"/></effectiveTime></serviceEvent></documentationOf>",requesterName, issuer,accessionNumber,studyUID,code,system,display,DT];
}


//cda ontology axis 2 event
//radiology snomedCode 371527006
//informe radiológico (elemento de registro)
-(void)appendCDAComponentofWithSnomedCode:(NSString*)snomedCode
                         snomedDisplay:(NSString*)snomedDisplay
                                 lowDA:(NSString*)lowDA
                                highDA:(NSString*)highDA
                           serviceCode:(NSString*)serviceCode
                           serviceName:(NSString*)serviceName
{
    [self appendFormat:@"<componentOf><encompassingEncounter classCode=\"ENC\"><code code=\"%@\" codeSystem=\"2.16.840.1.113883.6.96\" codeSystemName=\"SNOMED CT\" displayName=\"%@\"/><effectiveTime xsi:type=\"IVL_TS\"><low value=\"%@\"/><high value=\"%@\"/></effectiveTime><location typeCode=\"LOC\"><healthCareFacility classCode=\"SDLOC\"><code code=\"%@\" codeSystem=\"2.16.840.1.113883.6.96\" codeSystemName=\"SNOMED CT\" displayName=\"%@\"/></healthCareFacility></location></encompassingEncounter></componentOf>",
     snomedCode,
     snomedDisplay,
     lowDA,
     highDA,
     serviceCode,
     serviceName];
}
*/

-(void)appendEmptyCDAComponent
{
    [self appendString:@"<component><nonXMLBody><text mediaType=\"text/plain\"></text></nonXMLBody></component>"];
}

-(void)appendCDAComponentWithText:(NSString*)text
{
    [self appendFormat:@"<component><nonXMLBody><text mediaType=\"text/plain\">%@</text></nonXMLBody></component>",text];
}

-(void)appendCDAComponentWithBase64Pdf:(NSString*)base64Pdf
{
    [self appendFormat:@"<component><nonXMLBody><text mediaType=\"application/pdf\"><reference value=\"data:application/pdf;base64,%@\"/></text></nonXMLBody></component>",base64Pdf];
}

-(void)appendCDAComponentWithTextThumbnail:(NSString*)textThunbnail forBase64Pdf:(NSString*)base64Pdf
{
    [self appendFormat:@"<component><nonXMLBody><text mediaType=\"application/pdf\"><reference value=\"data:application/pdf;base64,%@\"/>%@</text></nonXMLBody></component>",base64Pdf,textThunbnail];
}

@end
