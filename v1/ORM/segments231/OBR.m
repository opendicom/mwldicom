#import "OBR.h"

@implementation OBR

static unsigned long uniqueRpID;
static unsigned long uniqueSpsID;
+(void)initialize
{
    uniqueRpID=[[NSDate date]timeIntervalSinceReferenceDate];
    uniqueSpsID=uniqueRpID;
}

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
{

   if (!ProtocolCode)ProtocolCode=@"";
   if (!DangerCode)DangerCode=@"";
   if (!RelevantClinicalInfo)RelevantClinicalInfo=@"";
   if (!OrderingProvider)OrderingProvider=@"";
   if (!PlacerField1)PlacerField1=@"";
    if (!PlacerField2) PlacerField2=[NSString stringWithFormat:@"%lu",uniqueRpID++];
   if (!FillerField1)FillerField1=[NSString stringWithFormat:@"%lu",uniqueSpsID++];
   if (!FillerField2)FillerField2=@"";
   if (!DiagnosticServiceSectID)DiagnosticServiceSectID=@"";
   if (!TransportationMode)TransportationMode=@"";
   if (!ReasonForStudy)ReasonForStudy=@"";
   if (!PrincipalResultInterpreter)PrincipalResultInterpreter=@"";
   if (!Technician)Technician=@"";
   if (!UniversalServiceID)UniversalServiceID=@"";

    //
   return [NSString stringWithFormat:@"OBR||||%@||||||||%@|%@|||%@||%@|%@|%@|%@|||%@||||||%@|%@|%@||%@||||||||||%@",
           ProtocolCode,
           DangerCode,
           RelevantClinicalInfo,
           OrderingProvider,
           PlacerField1,
           PlacerField2,
           FillerField1,
           FillerField2,
           DiagnosticServiceSectID,
           TransportationMode,
           ReasonForStudy,
           PrincipalResultInterpreter,
           Technician,
           UniversalServiceID
           ];

}

@end
