#import "ORC.h"
#import "DICMTypes.h"

@implementation ORC

+(NSString*)NewSendingRisName:(NSString*)sendingRisName //MSH-3
             receivingPacsaet:(NSString*)receivingPacsaet //MSH-6
                  isrPlacerDT:(NSString*)PlacerNumber
         isrFillerScheduledDT:(NSString*)FillerNumber
               spsOrderStatus:(NSString*)OrderStatus
                  spsDateTime:(NSString*)scheduledDateTime
                   rpPriority:(NSString*)priority
               EnteringDevice:(NSString*)EnteringDevice //IP of the sender (MSH-4)
            RequestingService:(NSString*)RequestingService
{
   if (!PlacerNumber)PlacerNumber=@"";
   if (!FillerNumber)FillerNumber=@"";
   if (!OrderStatus)OrderStatus=@"SC";//SCHEDULED
   if (!scheduledDateTime)scheduledDateTime=[DICMTypes DTStringFromDate:[NSDate date]];
   if (!priority)priority=@"T";//T=Medium, S=STAT A,P,C=HIGH, R=ROUTINE
   if (!EnteringDevice)EnteringDevice=@"";

   return [NSString stringWithFormat:@"ORC|NW|%@^%@|%@^%@||%@||^^^%@^^%@||||||||||%@|%@",
           sendingRisName,
           PlacerNumber,
           receivingPacsaet,
           FillerNumber,
           OrderStatus,
           scheduledDateTime,
           priority,
           RequestingService,
           EnteringDevice
           ];
}

@end
