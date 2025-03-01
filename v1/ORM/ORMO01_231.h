#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface ORMO01_231 : NSObject

//http://ihewiki.wustl.edu/wiki/index.php/HL7_Tables#RAD-2_and_RAD-3:_Placer_and_Filler_Order_Management
//Source: IHE RAD TF-2 Table B-1: HL7 Order Mapping to DICOM MWL
//* = addition by opendicom

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
;

//dcm4chee-arc GUI

//RequestedProcedureID
//StudyInstanceUID
//SPSStartDate
//SPSStartTime
//SP Physician's Name
//AccessionNumber
//Modalities
//SPSDescription
//SS AE Title

//detailed:

//Referring Physician´s Name
//RequestedProcedureDescription

//extended filter

//SPS Status
//SPS Description
//Scheduled Performing Phsysician´s Name



@end

NS_ASSUME_NONNULL_END
