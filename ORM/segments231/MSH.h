#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface MSH : NSObject

//https://corepointhealth.com/resource-center/hl7-resources/hl7-msh-message-header/

+(NSString*)ControlID:(NSString*)ControlID
   SendingApplication:(NSString*)SendingApplication
      SendingFacility:(NSString*)SendingFacility
 ReceivingApplication:(NSString*)ReceivingApplication
    ReceivingFacility:(NSString*)ReceivingFacility
              Country:(NSString*)CountryCode
         CharacterSet:(NSStringEncoding)stringEncoding
    PrincipalLanguage:(NSString*)PrincipalLanguage
;

@end

//NS_ASSUME_NONNULL_END
