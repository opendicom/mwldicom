#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

//https://dcm4chee-arc-hl7cs.readthedocs.io/en/latest/orm/inbound.html#tab-zds-orm-omg

//1 StudyInstanceUID

@interface ZDS : NSObject

+(NSString*)StudyInstanceUID:(NSString*)StudyInstanceUID;

@end

//NS_ASSUME_NONNULL_END
