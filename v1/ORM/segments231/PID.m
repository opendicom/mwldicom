#import "PID.h"

@implementation PID

+(NSString*)PatientID:(NSString*)PatientID
       IdentifierList:(NSString*)PatientIdentifierList
          AlternateID:(NSString*)AlternatePatientID
                 Name:(NSString*)PatientName
     MotherMaidenName:(NSString*)MotherMaidenName
            BirthDate:(NSString*)PatientBirthDate
                  Sex:(NSString*)PatientSex
                Alias:(NSString*)PatientAlias
{
   if (!PatientID)PatientID=@"";
   if (!PatientIdentifierList)PatientIdentifierList=@"";
   if (!AlternatePatientID)AlternatePatientID=@"";
   if (!PatientName)PatientName=@"";
   if (!MotherMaidenName)MotherMaidenName=@"";
   if (!PatientBirthDate)PatientBirthDate=@"";
   if (!PatientSex)PatientSex=@"";
   if (!PatientAlias)PatientAlias=@"";
   
   return [NSString stringWithFormat:
           @"PID||%@|%@|%@|%@|%@|%@|%@|%@",
           PatientID,
           PatientIdentifierList,
           AlternatePatientID,
           PatientName,
           MotherMaidenName,
           PatientBirthDate,
           PatientSex,
           PatientAlias
           ];
}

@end
