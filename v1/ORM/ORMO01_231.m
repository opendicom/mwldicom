#import "ORMO01_231.h"
#import "MSH.h"
#import "PID.h"
#import "PV1.h"
#import "ORC.h"
#import "OBR.h"
#import "ZDS.h"

@implementation ORMO01_231


+(NSString*)singleSpsMSH_3:(NSString*)sendingRisName
                     MSH_4:(NSString*)sendingRisIP
                     MSH_5:(NSString*)receivingCustodianTitle
                     MSH_6:(NSString*)receivingPacsaet
                    MSH_10:(NSString*)MessageControlId
                    MSH_17:(NSString*)CountryCode
                    MSH_18:(NSStringEncoding)sopStringEncoding      //00080005
                    MSH_19:(NSString*)PrincipalLanguage
                     PID_3:(NSString*)pID                           //00100020+00100021
                     PID_5:(NSString*)pName                         //00100010
                     PID_7:(NSString*)pBirthDate                    //00100030
                     PID_8:(NSString*)pSex                          //00100040
                     PV1_8:(NSString*)isrPatientInsuranceShortName  //00080090 ReferringPhysicianName
                     ORC_2:(NSString*)isrPlacerNumber               //00402016
                     ORC_3:(NSString*)isrFillerNumber               //00402017
                     ORC_5:(NSString*)spsOrderStatus                //00400020*
                     ORC_7:(NSString*)spsDateTime                   //00400002+00400003*
                    ORC_7_:(NSString*)rpPriority                    //00401003
                    ORC_17:(NSString*)RequestingService                  //00321033*
                     OBR_4:(NSString*)spsProtocolCode               //00400008(00040007)
                    OBR_12:(NSString*)isrDangerCode                    //00380500
                    OBR_13:(NSString*)isrRelevantClinicalInfo          //00102000
                    OBR_16:(NSString*)isrReferringPhysician         //00321032 RequestingPhysician
                    OBR_18:(NSString*)isrAccessionNumber            //00080050*
                    OBR_19:(NSString*)rpID                          //00401001
                    OBR_20:(NSString*)spsID                         //00400009
                    OBR_21:(NSString*)spsStationAETitle             //00400001*
                    OBR_24:(NSString*)spsModality                   //00080060*
                    OBR_30:(NSString*)rpTransportationMode          //00401004
                    OBR_31:(NSString*)rpReasonForStudy              //00401002
                    OBR_32:(NSString*)isrNameOfPhysiciansReadingStudy  //00081060*
                    OBR_34:(NSString*)spsTechnician                 //00400006 (PerformingPhysicianName)
                    OBR_44:(NSString*)rpUniversalStudyCode          //00321064(00321060)
                     ZDS_1:(NSString*)isrStudyInstanceUID            //0020000D
{
   NSMutableString *segments=[NSMutableString string];
   
   //MSH
   
   if (!CountryCode)CountryCode=@"cl";
   if (!PrincipalLanguage)PrincipalLanguage=@"es";
   
   [segments appendString:
    [MSH
     ControlID:MessageControlId
     SendingApplication:sendingRisName
     SendingFacility:sendingRisIP
     ReceivingApplication:receivingCustodianTitle
     ReceivingFacility:receivingPacsaet
     Country:CountryCode
     CharacterSet:sopStringEncoding
     PrincipalLanguage:PrincipalLanguage
     ]
    ];
   [segments appendString:@"\r"];
   
   //PID
   [segments appendString:
    [PID
     PatientID:nil
     IdentifierList:pID
     AlternateID:nil
     Name:pName
     MotherMaidenName:nil
     BirthDate:pBirthDate
     Sex:pSex
     Alias:nil
     ]
    ];
   [segments appendString:@"\r"];

   
   //PV1
   [segments appendString:
    [PV1
     VisitNumber:nil
     ReferringDoctor:isrPatientInsuranceShortName
     AmbultatoryStatus:nil
     ]
    ];
   [segments appendString:@"\r"];

   
   //ORC
   [segments appendString:
    [ORC
     NewSendingRisName:sendingRisName
     receivingPacsaet:receivingPacsaet
     isrPlacerDT:isrPlacerNumber
     isrFillerScheduledDT:isrFillerNumber
     spsOrderStatus:spsOrderStatus
     spsDateTime:spsDateTime
     rpPriority:rpPriority
     EnteringDevice:sendingRisIP
     RequestingService:RequestingService
     ]
    ];
   [segments appendString:@"\r"];

   
   //OBR
   [segments appendString:
    [OBR
     spsProtocolCode:spsProtocolCode
     isrDangerCode:isrDangerCode
     isrRelevantClinicalInfo:isrRelevantClinicalInfo
     isrReferringPhysician:isrReferringPhysician
     isrAccessionNumber:isrAccessionNumber
     rpID:rpID
     spsID:spsID
     spsStationAETitle:spsStationAETitle
     spsModality:spsModality
     rpTransportationMode:rpTransportationMode
     rpReasonForStudy:rpReasonForStudy
     isrNameOfPhysiciansReadingStudy:isrNameOfPhysiciansReadingStudy
     spsTechnician:spsTechnician
     rpUniversalStudyCode:rpUniversalStudyCode
     ]
    ];
   [segments appendString:@"\r"];

   
   //ZDS
   [segments appendString:
    [ZDS
     StudyInstanceUID:isrStudyInstanceUID
     ]
    ];

   [segments appendString:@"\r"];

   return [NSString stringWithString:segments];
}
@end
