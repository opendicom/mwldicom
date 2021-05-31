#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface PID : NSObject

//https://dcm4chee-arc-hl7cs.readthedocs.io/en/latest/adt/inbound.html#tab-pid-231

//2   PatientID:
//3   PatientIdentifierList ID^^^ISSUER
//4   AlternatePatientID
//5   PatientName: FAMILY1>FAMILY2^GIVEN1 GIVEN2
//6   MotherMaidenName (alternative to FAMILY2
//7   PatientBirthDate: AAAAMMDD
//8   PatientSex: M | F | O
//9   PatientAlias

+(NSString*)PatientID:(NSString*)PatientID
       IdentifierList:(NSString*)PatientIdentifierList
          AlternateID:(NSString*)AlternatePatientID
                 Name:(NSString*)PatientName
     MotherMaidenName:(NSString*)MotherMaidenName
            BirthDate:(NSString*)PatientBirthDate
                  Sex:(NSString*)PatientSex
                Alias:(NSString*)PatientAlias
;

@end

//NS_ASSUME_NONNULL_END
