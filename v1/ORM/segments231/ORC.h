#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface ORC : NSObject

//https://dcm4chee-arc-hl7cs.readthedocs.io/en/latest/orm/inbound.html#tab-pv1-orm-omg

//1  OrderControl
//2  PlacerOrderNumber
//3  FillerOrderNumber

//4  OrderStatus
//http://ihewiki.wustl.edu/wiki/index.php/HL7_Tables#Order_Status
//Order status is sent by an Order Filler but not by an Order Placer.

//    http://www.hl7.eu/refactored/tab0038.html
//    https://dcm4che.atlassian.net/wiki/spaces/ee2/pages/311689217/HL7+ORM+Service+Order+Control+Operation+Mapping
      //    A=ARRIVED
      //    CA=CANCELED
//    CM=COMPLETED
//    DC=DISCONTINUED
      //    ER=ERROR
      //    HD=ON HOLD
//    IP=IN PROCESS, unspecified
      //    RP=REPLACED
      //    SC=IN PROCESS, SCHEDULED

//7  Quantity/Timing (^^^201304242036^^MEDIUM)
//http://ihewiki.wustl.edu/wiki/index.php/HL7_Tables#Quantity.2FTiming
//    S=STAT
//    A=ASAP
//    R=ROUTINE
//    P=PRE-OP
//    C=CALL-BACK
//    T=TIMING

//18 EnteringDevice ( This field may contain multiple values encoded as HL7 repeating field despite current HL7v2 not allowing multiple values for this field.)
//we define it with IP of the sender (as in sending facility MSH-4)

+(NSString*)NewSendingRisName:(NSString*)sendingRisName //MSH-3
             receivingPacsaet:(NSString*)receivingPacsaet //MSH-6
                  isrPlacerDT:(NSString*)PlacerNumber
         isrFillerScheduledDT:(NSString*)FillerNumber
               spsOrderStatus:(NSString*)OrderStatus
                  spsDateTime:(NSString*)scheduledDateTime
                   rpPriority:(NSString*)priority
               EnteringDevice:(NSString*)EnteringDevice //IP of the sender (MSH-4)
             RequestingService:(NSString*)RequestingService
;

@end

//NS_ASSUME_NONNULL_END
