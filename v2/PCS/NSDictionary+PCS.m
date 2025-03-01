//
//  NSDictionary+PCS.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180426.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "NSDictionary+PCS.h"

@implementation NSDictionary (PCS)

+(NSDictionary*)da4dd:(NSDictionary*)dd
{
    if (![dd count]) return nil;
    NSArray *dkeys=[dd allKeys];
    NSArray *ddkeys=[dd[dkeys[0]] allKeys];
    NSArray *keys=[@[@"key"] arrayByAddingObjectsFromArray:ddkeys];

 
    //create mutabledictionary of mutablearrays
    NSMutableDictionary *mdma=[NSMutableDictionary dictionary];
    for (NSString *k in keys)
    {
        [mdma setObject:[NSMutableArray array] forKey:k];
    }
    
    //fill up mutablearrays
    for (NSString *dk in dkeys)
    {
        [mdma[@"key"] addObject:dk];
        NSDictionary *kd=dd[dk];
        for (NSString *ddk in ddkeys)
        {
            [mdma[ddk] addObject:kd[ddk]];
        }
    }
    
    //create mutabledictionary of arrays
    NSMutableDictionary *mda=[NSMutableDictionary dictionary];
    for (NSString *k in keys)
    {
        [mda setObject:[NSArray arrayWithArray:mdma[k]] forKey:k];
    }

    //create return dictionary of arrays
    return [NSDictionary dictionaryWithDictionary:mda];
}

@end
