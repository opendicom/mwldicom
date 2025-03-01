//
//  DRS+pacs.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180115.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

#import "DRS+pacs.h"
#import "K.h"

@implementation DRS (pacs)

-(void)addCustodiansHandler
{
    NSRegularExpression *custodiansRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\/(custodians|pacs)" options:0 error:NULL];
    [self addHandler:@"GET" regex:custodiansRegex processBlock:
     ^(RSRequest* request, RSCompletionBlock completionBlock)
     {completionBlock(^RSResponse* (RSRequest* request){
        
        //using NSURLComponents instead of RSRequest
        NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
        
        NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
        NSUInteger pCount=[pComponents count];
        if ([[pComponents lastObject]isEqualToString:@""]) pCount--;
        
        if (pCount<3) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];
        
        if ([pComponents[2]isEqualToString:@"titles"])
        {
            //custodians/titles
            if (pCount==3) return [RSDataResponse responseWithData:DRS.titlesdata contentType:@"application/json"];
            
            NSUInteger p3Length = [pComponents[3] length];
            if (  (p3Length>16)
                ||![K.SHRegex numberOfMatchesInString:pComponents[3] options:0 range:NSMakeRange(0,p3Length)])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} datatype should be DICOM SH]",urlComponents.path];
            
            if (!DRS.titles[pComponents[3]])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} not found]",urlComponents.path];
            
            //custodians/titles/{TITLE}
            if (pCount==4) return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:DRS.titles[pComponents[3]]] options:0 error:nil] contentType:@"application/json"];
            
            if (![pComponents[4]isEqualToString:@"aets"])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{title} unique resource is 'aets']",urlComponents.path];
            
            //custodians/titles/{title}/aets
            if ((pCount==5)||((pCount==6)&&![pComponents[5]length]))
                return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[DRS.titlesaets objectForKey:pComponents[3]] options:0 error:nil] contentType:@"application/json"];
            
            NSUInteger p5Length = [pComponents[5]length];
            if (  (p5Length>16)
                ||![K.SHRegex numberOfMatchesInString:pComponents[5] options:0 range:NSMakeRange(0,p5Length)])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aet}datatype should be DICOM SH]",urlComponents.path];
            
            NSUInteger aetIndex=[[DRS.titlesaets objectForKey:pComponents[3]] indexOfObject:pComponents[5]];
            if (aetIndex==NSNotFound)
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aet} not found]",urlComponents.path];
            
            if (pCount>6) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];
            
            //custodians/titles/{title}/aets/{aet}
            return [RSDataResponse responseWithData:
                    [NSJSONSerialization dataWithJSONObject:
                     [NSArray arrayWithObject:(DRS.oidsaeis[DRS.titles[pComponents[3]]])[aetIndex]]
                                                    options:0
                                                      error:nil
                     ]
                                        contentType:@"application/json"
                    ];
        }
        
        
        if ([pComponents[2]isEqualToString:@"oids"])
        {
            //custodians/oids
            if (pCount==3) return [RSDataResponse responseWithData:DRS.oidsdata contentType:@"application/json"];
            
            NSUInteger p3Length = [pComponents[3] length];
            if (  (p3Length>64)
                ||![K.UIRegex numberOfMatchesInString:pComponents[3] options:0 range:NSMakeRange(0,p3Length)]
                )
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} datatype should be DICOM UI]",urlComponents.path];
            
            if (!DRS.oids[pComponents[3]])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} not found]",urlComponents.path];
            
            //custodian/oids/{OID}
            if (pCount==4) return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:DRS.oids[pComponents[3]]] options:0 error:nil] contentType:@"application/json"];
            
            if (![pComponents[4]isEqualToString:@"aeis"])
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{OID} unique resource is 'aeis']",urlComponents.path];
            
            //custodian/oids/{OID}/aeis
            if ((pCount==5)||((pCount==6)&&![pComponents[5]length]))
                return [RSDataResponse responseWithData:[NSJSONSerialization dataWithJSONObject:[DRS.oidsaeis objectForKey:pComponents[3]] options:0 error:nil] contentType:@"application/json"];
            
            NSUInteger p5Length = [pComponents[5]length];
            if (  (p5Length>64)
                ||![K.UIRegex numberOfMatchesInString:pComponents[5] options:0 range:NSMakeRange(0,p5Length)]
                )
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aei}datatype should be DICOM UI]",urlComponents.path];
            
            NSUInteger aeiIndex=[[DRS.oidsaeis objectForKey:pComponents[3]] indexOfObject:pComponents[5]];
            if (aeiIndex==NSNotFound)
                return [RSErrorResponse responseWithClientError:404 message:@"%@ [{aei} not found]",urlComponents.path];
            
            if (pCount>6) return [RSErrorResponse responseWithClientError:400 message:@"%@ [no handler]",urlComponents.path];
            
            //custodian/oids/{OID}/aeis/{aei}
            return [RSDataResponse responseWithData:
                    [NSJSONSerialization dataWithJSONObject:
                     [NSArray arrayWithObject:(DRS.pacs[pComponents[5]])[@"dicomaet"]]
                                                    options:0
                                                      error:nil
                     ]
                                        contentType:@"application/json"
                    ];
        }
        return [RSErrorResponse responseWithClientError:404 message:@"%@ [no handler]",urlComponents.path];
        
    }(request));}];
}
@end
