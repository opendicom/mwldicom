#import "MSH.h"
#import "DICMTypes.h"

@implementation MSH


+(NSString*)ControlID:(NSString*)ControlID
   SendingApplication:(NSString*)SendingApplication
      SendingFacility:(NSString*)SendingFacility
 ReceivingApplication:(NSString*)ReceivingApplication
    ReceivingFacility:(NSString*)ReceivingFacility
              Country:(NSString*)CountryCode
         CharacterSet:(NSStringEncoding)stringEncoding
    PrincipalLanguage:(NSString*)PrincipalLanguage
{
   if (!ControlID)ControlID=[[NSUUID UUID] UUIDString];
   if (!SendingApplication)SendingApplication=@"HIS";
   if (!SendingFacility)SendingFacility=@"IP";
   if (!ReceivingApplication)ReceivingApplication=@"CUSTODIAN";
   if (!ReceivingFacility)ReceivingFacility=@"PACS";
   //http://www.healthintersections.com.au/?p=350
   NSString *CharacterSet=nil;
   switch (stringEncoding) {
      case 1://ascii
         CharacterSet=@"ASCII";
         break;
      case 4://utf-8
         CharacterSet=@"UNICODE UTF-8";
         break;
      case 5:
      default:
         CharacterSet=@"8859/1";
         break;
   }
   
   return [NSString stringWithFormat:
           @"MSH|^~\\&|%@|%@|%@|%@|%@||ORM^O01|%@|P|2.3.1|||||%@|%@|%@",
           SendingApplication,
           SendingFacility,
           ReceivingApplication,
           ReceivingFacility,
           [DICMTypes DAStringFromDate:[NSDate date]],
           ControlID,
           CountryCode,
           CharacterSet,
           PrincipalLanguage
           ];
}

@end
