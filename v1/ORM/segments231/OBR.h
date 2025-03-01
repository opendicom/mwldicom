#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

//https://dcm4chee-arc-hl7cs.readthedocs.io/en/latest/orm/inbound.html#tab-obr-orm-omg

//4  UniversalServiceID (^^^99845^RX INTESTINAL^CR)
//   (P1^Procedure 1^ERL_MESA^X1_A1^SP Action Item X1_A1^DSS_MESA)

//12 DangerCode (code^description^system)
//http://ihewiki.wustl.edu/wiki/index.php/HL7_Tables#Danger_Code
//    HI=HIV positive
//    TB=Active tuberculosis

//13 RelevantClinicalInfo
//16 OrderingProvider (id^family1>family2^given1 given2) ->afiliación
//18 PlacerField1 (AccessionNumber)
//19 PlacerField2 (RequestedProcedureID)
//20 FillerField1 (stepID, empty -> pacs uses 18)
//21 FillerField2 (aet modality)
//24 DiagnosticServiceSectID (modality)
//30 TransportationMode
//31 ReasonForStudy
//32 PrincipalResultInterpreter (not in the conformance statement, but in the db without use yet

//34 Technician
//44 ProcedureCode (P1^Procedure 1^ERL_MESA^X1_A1)

@interface OBR : NSObject

+(NSString*)spsProtocolCode:(NSString*)ProtocolCode
              isrDangerCode:(NSString*)DangerCode
    isrRelevantClinicalInfo:(NSString*)RelevantClinicalInfo
      isrReferringPhysician:(NSString*)OrderingProvider
         isrAccessionNumber:(NSString*)PlacerField1
                       rpID:(NSString*)PlacerField2
                      spsID:(NSString*)FillerField1
          spsStationAETitle:(NSString*)FillerField2
                spsModality:(NSString*)DiagnosticServiceSectID
       rpTransportationMode:(NSString*)TransportationMode
           rpReasonForStudy:(NSString*)ReasonForStudy
isrNameOfPhysiciansReadingStudy:(NSString*)PrincipalResultInterpreter
              spsTechnician:(NSString*)Technician
       rpUniversalStudyCode:(NSString*)UniversalServiceID
;

@end

//NS_ASSUME_NONNULL_END
