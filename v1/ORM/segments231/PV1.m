#import "PV1.h"

@implementation PV1

+(NSString*)VisitNumber:(NSString*)VisitNumber
        ReferringDoctor:(NSString*)ReferringDoctor
      AmbultatoryStatus:(NSString*)AmbultatoryStatus
{
   if (!VisitNumber)VisitNumber=@"";
   if (!ReferringDoctor)ReferringDoctor=@"";
   if (!AmbultatoryStatus)AmbultatoryStatus=@"";

   return [NSString
           stringWithFormat:@"PV1||||||||%@|||||||%@||||%@",
           ReferringDoctor,
           AmbultatoryStatus,
           VisitNumber
           ];
}

@end
