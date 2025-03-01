#import "ZDS.h"

@implementation ZDS

+(NSString*)StudyInstanceUID:(NSString*)StudyInstanceUID
{
   return [NSString stringWithFormat:@"ZDS|%@",StudyInstanceUID];
}

@end
