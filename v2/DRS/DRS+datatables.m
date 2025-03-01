//
//  DRS+datatables.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180118.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+datatables.h"

@implementation DRS (datatables)

//query ajax with params:
//agregate 00080090 in other accesible PCS...

//q=current query
//r=Req=request sql
//s=subselection from caché

NSRegularExpression *dtstudiesRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/studies" options:0 error:NULL];
-(void)addDatatablesStudiesHandler
{
[httpdicomServer addHandler:@"GET" regex:dtstudiesRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
     {
         LOG_VERBOSE(@"%@",[request.URL description]);
         LOG_DEBUG(@"client: %@",request.remoteAddressString);
         NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
         NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
         
         
         NSDictionary *q=request.query;
         
         NSString *session=q[@"session"];
         if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
         
         NSDictionary *r=Req[session];
         int recordsTotal;
         
         NSString *qPatientID=q[@"columns[3][search][value]"];
         NSString *qPatientName=q[@"columns[4][search][value]"];
         //NSString *qStudyDate=q[@"columns[5][search][value]"];
         NSString *qDate_start=q[@"date_start"];
         NSString *qDate_end=q[@"date_end"];
         NSString *qModality;
         if ([q[@"columns[6][search][value]"]isEqualToString:@"ALL"]) qModality=@"%%";
         else qModality=q[@"columns[6][search][value]"];
         if (!qModality) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'columns[6][search][value]' (modality) parameter"] contentType:@"application/dicom+json"];
         
         NSString *qStudyDescription=q[@"columns[7][search][value]"];
         
         NSString *rPatientID=r[@"columns[3][search][value]"];
         NSString *rPatientName=r[@"columns[4][search][value]"];
         //NSString *rStudyDate=r[@"columns[5][search][value]"];
         NSString *rDate_start=r[@"date_start"];
         NSString *rDate_end=r[@"date_end"];
         NSString *rModality=r[@"columns[6][search][value]"];
         NSString *rStduyDescription=r[@"columns[7][search][value]"];
         
         
         //same or different context?
         if (
             !r
             || [q[@"new"]isEqualToString:@"true"]
             || (q[@"username"]    && ![q[@"username"]isEqualToString:r[@"username"]])
             || (q[@"useroid"]     && ![q[@"useroid"]isEqualToString:r[@"useroid"]])
             || (session           && ![session isEqualToString:r[@"session"]])
             || (q[@"custodiantitle"]         && ![q[@"custodiantitle"]isEqualToString:r[@"custodiantitle"]])
             || (q[@"aet"] && ![q[@"aet"]isEqualToString:r[@"aet"]])
             || (q[@"role"]        && ![q[@"role"]isEqualToString:r[@"role"]])
             
             || (q[@"search[value]"] && ![q[@"search[value]"]isEqualToString:r[@"search[value]"]])
             
             ||(    qPatientID
                &&![qPatientID isEqualToString:rPatientID]
                &&![rPatientID isEqualToString:@""]
                )
             ||(    qPatientName
                &&![qPatientName isEqualToString:rPatientName]
                &&![rPatientName isEqualToString:@""]
                )
             ||(    qDate_start
                &&![qDate_start isEqualToString:rDate_start]
                &&![rDate_start isEqualToString:@""]
                )
             ||(    qDate_end
                &&![qDate_end isEqualToString:rDate_end]
                &&![rDate_end isEqualToString:@""]
                )
             ||(  ![qModality isEqualToString:rModality]
                &&![rModality isEqualToString:@"%%"]
                )
             ||(    qStudyDescription
                &&![qStudyDescription isEqualToString:rStduyDescription]
                &&![rStduyDescription isEqualToString:@""]
                )
             )
         {
             //LOG_INFO(@"%@",[[request URL]description]);
#pragma mark --different context
#pragma mark reemplazar org por custodianTitle e institucion por aet
             //find dest
             NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
             NSDictionary *entityDict=devices[destOID];
             
             NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
             if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
             
             //local ... simulation qido through database access
             
             //LOG_INFO(@"different context with db: %@",entityDict[@"sqlobjectmodel"]);
             
             if (r){
                 //replace previous request of the session.
                 [Req removeObjectForKey:session];
                 [Total removeObjectForKey:session];
                 [Filtered removeObjectForKey:session];
                 [Date removeObjectForKey:session];
                 if(sPatientID[@"session"])[sPatientID removeObjectForKey:session];
                 if(sPatientName[@"session"])[sPatientName removeObjectForKey:session];
                 //if(sStudyDate[@"session"])[sStudyDate removeObjectForKey:session];
                 if(sDate_start[@"session"])[sDate_start removeObjectForKey:session];
                 if(sDate_end[@"session"])[sDate_end removeObjectForKey:session];
                 if(sModality[@"session"])[sModality removeObjectForKey:session];
                 if(sStudyDescription[@"session"])[sStudyDescription removeObjectForKey:session];
                 
             }
             //copy of the sql request of the new context
             [Req setObject:q forKey:session];
             
             //TODO: remove old sessions
             [Date setObject:[NSDate date] forKey:session];
             
             if(qPatientID)[sPatientID setObject:qPatientID forKey:session];
             if(qPatientName)[sPatientName setObject:qPatientName forKey:session];
             //if(qStudyDate)[sStudyDate setObject:qStudyDate forKey:session];
             if(qDate_start)[sDate_start setObject:qDate_start forKey:session];
             if(qDate_end)[sDate_end setObject:qDate_end forKey:session];
             [sModality setObject:qModality forKey:session];
             if(qStudyDescription)[sStudyDescription setObject:qStudyDescription forKey:session];
             
             //1 create where clause
             
             //WHERE study.rejection_state!=2    (or  1=1)
             //following filters use formats like " AND a like 'b'"
             NSMutableString *studiesWhere=[NSMutableString stringWithString:sqlobjectmodel[@"studiesWhere"]];
             
             //PEP por aet or custodian
             if ([q[@"aet"] isEqualToString:q[@"custodiantitle"]])
             {
                 //[studiesWhere appendFormat:
                 //@" AND %@ in %@",
                 //sqlobjectmodel[@"accessControlId"],
                 //custodianTitlesaetsStrings[q[@"custodiantitle"]]
                 //];
             }
             else
             {
                 //[studiesWhere appendFormat:
                 //@" AND %@ in ('%@','%@')",
                 //sqlobjectmodel[@"accessControlId"],
                 //q[@"aet"],
                 //q[@"custodiantitle"]
                 //];
             }
             
             if (q[@"search[value]"] && ![q[@"search[value]"] isEqualToString:@""])
             {
                 //AccessionNumber q[@"search[value]"]
                 [studiesWhere appendString:
                  [NSString mysqlEscapedFormat:@" AND %@ like '%@'"
                                   fieldString:sqlobjectmodel[@"AccessionNumber"]
                                   valueString:q[@"search[value]"]
                   ]
                  ];
             }
             else
             {
                 if(qPatientID && [qPatientID length])
                 {
                     [studiesWhere appendString:
                      [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                       fieldString:sqlobjectmodel[@"PatientID"]
                                       valueString:qPatientID
                       ]
                      ];
                 }
                 
                 if(qPatientName && [qPatientName length])
                 {
                     //PatientName _00100010 Nombre
                     NSArray *patientNameComponents=[qPatientName componentsSeparatedByString:@"^"];
                     NSUInteger patientNameCount=[patientNameComponents count];
                     
                     [studiesWhere appendString:
                      [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                       fieldString:(sqlobjectmodel[@"PatientName"])[0]
                                       valueString:patientNameComponents[0]
                       ]
                      ];
                     
                     if (patientNameCount > 1)
                     {
                         [studiesWhere appendString:
                          [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                           fieldString:(sqlobjectmodel[@"PatientName"])[1]
                                           valueString:patientNameComponents[1]
                           ]
                          ];
                         
                         if (patientNameCount > 2)
                         {
                             [studiesWhere appendString:
                              [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                               fieldString:(sqlobjectmodel[@"PatientName"])[2]
                                               valueString:patientNameComponents[2]
                               ]
                              ];
                             
                             if (patientNameCount > 3)
                             {
                                 [studiesWhere appendString:
                                  [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                                   fieldString:(sqlobjectmodel[@"PatientName"])[3]
                                                   valueString:patientNameComponents[3]
                                   ]
                                  ];
                                 
                                 if (patientNameCount > 4)
                                 {
                                     [studiesWhere appendString:
                                      [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                                       fieldString:(sqlobjectmodel[@"PatientName"])[4]
                                                       valueString:patientNameComponents[4]
                                       ]
                                      ];
                                 }
                             }
                         }
                     }
                 }
                 
                 if(
                    (qDate_start && [qDate_start length])
                    ||(qDate_end && [qDate_end length])
                    )
                 {
                     NSString *s=nil;
                     if (qDate_start && [qDate_start length]) s=qDate_start;
                     else s=@"";
                     NSString *e=nil;
                     if (qDate_end && [qDate_end length]) e=qDate_end;
                     else e=@"";
                     [studiesWhere appendString:[sqlobjectmodel[@"StudyDate"] sqlFilterWithStart:s end:e]];
                 }
                 
                 //qModality contains ONE modality or joker %%
                 [studiesWhere appendFormat:@" AND %@ like '%%%@%%'", sqlobjectmodel[@"ModalitiesInStudy"], qModality];
                 
                 if(qStudyDescription && [qStudyDescription length])
                 {
                     //StudyDescription _00081030 Descripción
                     [studiesWhere appendString:
                      [NSString mysqlEscapedFormat:@" AND %@ like '%@%%'"
                                       fieldString:sqlobjectmodel[@"StudyDescription"]
                                       valueString:qStudyDescription
                       ]
                      ];
                 }
             }
             LOG_INFO(@"%@",[studiesWhere substringFromIndex:65]);
             
             
             //2 count
             NSString *sqlCountQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                      entityDict[@"sqlprolog"],
                                      sqlobjectmodel[@"studiesCountProlog"],
                                      studiesWhere,
                                      sqlobjectmodel[@"studiesCountEpilog"]
                                      ];
             LOG_DEBUG(@"%@",sqlCountQuery);
             NSMutableData *countData=[NSMutableData data];
             if (task(@"/bin/bash",@[@"-s"],[sqlCountQuery dataUsingEncoding:NSUTF8StringEncoding],countData))
                 [RSErrorResponse responseWithClientError:404 message:@"%@",@"can not access the db"];//NotFound
             NSString *countString=[[NSString alloc]initWithData:countData encoding:NSUTF8StringEncoding];
             // max (max records filtered para evitar que filtros insuficientes devuelvan casi todos los registros... lo que devolvería un resultado inútil.
             recordsTotal=[countString intValue];
             int maxCount=[q[@"max"]intValue];
             LOG_INFO(@"total:%d, max:%d",recordsTotal,maxCount);
             if (recordsTotal > maxCount) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:[NSString stringWithFormat:@"you need a narrower filter. The browser table accepts up to %d matches. %d matches were found",maxCount, recordsTotal]] contentType:@"application/dicom+json"];
             
             if (!recordsTotal) return [RSDataResponse
                                        responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:@{
                                                                                                              @"draw":q[@"draw"],
                                                                                                              @"recordsTotal":@0,
                                                                                                              @"recordsFiltered":@0,
                                                                                                              @"data":@[]
                                                                                                              }]
                                        contentType:@"application/dicom+json"
                                        ];
             else
             {
                 //order is performed later, from mutableDictionary
                 //3 select
                 NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                         entityDict[@"sqlprolog"],
                                         sqlobjectmodel[@"datatablesStudiesProlog"],
                                         studiesWhere,
                                         [NSString stringWithFormat: sqlobjectmodel[@"datatablesStudiesEpilog"],session,
                                          session
                                          ]
                                         ];
                 
                 NSMutableArray *studiesArray=jsonMutableArray(sqlDataQuery,(NSStringEncoding) [entityDict[@"sqlstringencoding"]integerValue]);
                 
                 [Total setObject:studiesArray forKey:session];
                 [Filtered setObject:[studiesArray mutableCopy] forKey:session];
             }
             
         }//end diferent context
         else
         {
             
#pragma mark --same context
             
             recordsTotal=[Total[session] count];
             //LOG_INFO(@"same context recordsTotal: %d ",recordsTotal);
             
             //subfilter?
             // in case there is subfilter, derive BFiltered from BTotal
             //https://developer.apple.com/reference/foundation/nsmutablearray/1412085-filterusingpredicate?language=objc
             
             if (recordsTotal > 0)
             {
                 BOOL toBeFiltered=false;
                 
                 NSRegularExpression *PatientIDRegex=nil;
                 if(qPatientID && ![qPatientID isEqualToString:sPatientID[session]])
                 {
                     toBeFiltered=true;
                     PatientIDRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qPatientID withFormat:@"datatables\\/patient\\?PatientID=%@.*"] options:0 error:NULL];
                 }
                 
                 NSRegularExpression *PatientNameRegex=nil;
                 if(qPatientName && ![qPatientName isEqualToString:sPatientName[session]])
                 {
                     toBeFiltered=true;
                     PatientNameRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qPatientName withFormat:@"%@.*"] options:NSRegularExpressionCaseInsensitive error:NULL];
                 }
                 
                 NSString *until;
                 if(   qDate_end
                    && (  !sDate_end[session]
                        || ([qDate_end compare:sDate_end[session]]==NSOrderedAscending)
                        )
                    )
                 {
                     toBeFiltered=true;
                     until=qDate_end;
                 }
                 
                 NSString *since;
                 if(   qDate_start
                    && (  !sDate_start[session]
                        || ([qDate_start compare:sDate_start[session]]==NSOrderedDescending)
                        )
                    )
                 {
                     toBeFiltered=true;
                     since=qDate_start;
                 }
                 
                 NSString *modalitySelected=nil;
                 //sModality contains the last selected modality within the same context
                 if(![qModality isEqualToString:sModality[session]])
                 {
                     toBeFiltered=true;
                     modalitySelected=qModality;
                 }
                 else modalitySelected=sModality[session];
                 
                 NSRegularExpression *StudyDescriptionRegex=nil;
                 if(qStudyDescription  && ![qStudyDescription isEqualToString:sStudyDescription[session]])
                 {
                     toBeFiltered=true;
                     StudyDescriptionRegex=[NSRegularExpression regularExpressionWithPattern:[NSString regexDicomString:qStudyDescription withFormat:@"%@.*"] options:NSRegularExpressionCaseInsensitive error:NULL];
                 }
                 
                 if(toBeFiltered)
                 {
                     //filter from BTotal copy
                     [Filtered removeObjectForKey:session];
                     [Filtered setObject:[Total[session] mutableCopy] forKey:session];
                     
                     //create compound predicate
                     NSPredicate *compoundPredicate = [NSPredicate predicateWithBlock:^BOOL(NSArray *row, NSDictionary *bindings) {
                         if (PatientIDRegex)
                         {
                             //LOG_INFO(@"patientID filter");
                             if (![PatientIDRegex numberOfMatchesInString:row[3] options:0 range:NSMakeRange(0,[row[3] length])]) return false;
                         }
                         if (PatientNameRegex)
                         {
                             //LOG_INFO(@"patientName filter");
                             if (![PatientNameRegex numberOfMatchesInString:row[4] options:0 range:NSMakeRange(0,[row[4] length])]) return false;
                         }
                         if (until)
                         {
                             //LOG_INFO(@"until filter");
                             if ([until compare:row[5]]==NSOrderedDescending) return false;
                         }
                         if (since)
                         {
                             //LOG_INFO(@"since filter");
                             if ([since compare:row[5]]==NSOrderedAscending) return false;
                         }
                         //row[6] contains modalitiesInStudies. Ej: CT\OT
                         if (![row[6] containsString:modalitySelected]) return false;
                         
                         if (StudyDescriptionRegex)
                         {
                             //LOG_INFO(@"description filter");
                             if (![StudyDescriptionRegex numberOfMatchesInString:row[7] options:0 range:NSMakeRange(0,[row[7] length])]) return false;
                         }
                         return true;
                     }];
                     
                     [Filtered[session] filterUsingPredicate:compoundPredicate];
                 }
             }
         }
#pragma mark --order
         if (q[@"order[0][column]"] && q[@"order[0][dir]"])
         {
             LOG_INFO(@"ordering with %@, %@",q[@"order[0][column]"],q[@"order[0][dir]"]);
             
             int column=[q[@"order[0][column]"]intValue];
             if ([q[@"order[0][dir]"]isEqualToString:@"desc"])
             {
                 [Filtered[session] sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                     return [obj2[column] caseInsensitiveCompare:obj1[column]];
                 }];
             }
             else
             {
                 [Filtered[session] sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                     return [obj1[column] caseInsensitiveCompare:obj2[column]];
                 }];
             }
         }
         
#pragma mark --response
         
         NSMutableDictionary *resp = [NSMutableDictionary dictionary];
         NSUInteger recordsFiltered=[Filtered[session]count];
         [resp setObject:q[@"draw"] forKey:@"draw"];
         [resp setObject:[NSNumber numberWithInt:recordsTotal] forKey:@"recordsTotal"];
         [resp setObject:[NSNumber numberWithUnsignedInteger:recordsFiltered] forKey:@"recordsFiltered"];
         
         if (!recordsFiltered)  return [RSDataResponse
                                        responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:@{@"draw":q[@"draw"],@"recordsTotal":@0,@"recordsFiltered":@0,@"data":@[]}]
                                        contentType:@"application/dicom+json"
                                        ];
         else
         {
             //start y length
             long ps=[q[@"start"]intValue];
             long pl=[q[@"length"]intValue];
             //LOG_INFO(@"paging desired (start=[%ld],filas=[%ld],last=[%lu])",ps,pl,recordsFiltered-1);
             if (ps < 0) ps=0;
             if (ps > recordsFiltered-1) ps=0;
             if (ps+pl+1 > recordsFiltered) pl=recordsFiltered-ps;
             //LOG_INFO(@"paging applied (start=[%ld],filas=[%ld],last=[%lu])",ps,pl,recordsFiltered-1);
             NSArray *page=[Filtered[session] subarrayWithRange:NSMakeRange(ps,pl)];
             if (!page)page=@[];
             [resp setObject:page forKey:@"data"];
         }
         
         return [RSDataResponse
                 responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                 contentType:@"application/dicom+json"
                 ];
     }
(request));}];
}

-(void)addDatatablesPatientHandler
{

//ventana emergente con todos los estudios del paciente
//"datatables/patient
//PatientID=33333333&IssuerOfPatientID.UniversalEntityID=NULL&session=1"

NSRegularExpression *dtpatientRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/patient" options:0 error:NULL];
[httpdicomServer addHandler:@"GET" regex:dtpatientRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
     {
         LOG_DEBUG(@"client: %@",request.remoteAddressString);
         NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
         NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
         
         
         NSDictionary *q=request.query;
         
         NSString *session=q[@"session"];
         if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
         
         if (!q[@"PatientID"]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"studies of patient query without required 'patientID' parameter"] contentType:@"application/dicom+json"];
         
         //WHERE study.rejection_state!=2    (or  1=1)
         //following filters use formats like " AND a like 'b'"
         
         //find dest
         NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
         NSDictionary *entityDict=devices[destOID];
         
         NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
         if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
         
         NSMutableString *studiesWhere=[NSMutableString stringWithString:sqlobjectmodel[@"studiesWhere"]];
         [studiesWhere appendString:
          [NSString mysqlEscapedFormat:@" AND %@ like '%@'"
                           fieldString:sqlobjectmodel[@"PatientID"]
                           valueString:q[@"PatientID"]
           ]
          ];
         //PEP por custodian aets
         
         //[studiesWhere appendFormat:
         //@" AND %@ in ('%@')",
         //sqlobjectmodel[@"accessControlId"],
         //[custodianTitlesaets[q[@"custodiantitle"]] componentsJoinedByString:@"','"]
         //];
         
         LOG_INFO(@"WHERE %@",[studiesWhere substringFromIndex:38]);
         
         
         NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                 entityDict[@"sqlprolog"],
                                 sqlobjectmodel[@"datatablesStudiesProlog"],
                                 studiesWhere,
                                 [NSString stringWithFormat: sqlobjectmodel[@"datatablesStudiesEpilog"],session,
                                  session
                                  ]
                                 ];
         
         NSMutableArray *studiesArray=jsonMutableArray(sqlDataQuery, (NSStringEncoding) [entityDict[@"sqlstringencoding"]integerValue]);
         
         //sorted study date (5) desc
         [studiesArray sortWithOptions:0 usingComparator:^NSComparisonResult(id obj1, id obj2) {
             return [obj2[5] caseInsensitiveCompare:obj1[5]];
         }];
         
         
         NSMutableDictionary *resp = [NSMutableDictionary dictionary];
         if (q[@"draw"])[resp setObject:q[@"draw"] forKey:@"draw"];
         NSNumber *count=[NSNumber numberWithUnsignedInteger:[studiesArray count]];
         [resp setObject:count forKey:@"recordsTotal"];
         [resp setObject:count forKey:@"recordsFiltered"];
         [resp setObject:studiesArray forKey:@"data"];
         return [RSDataResponse
                 responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                 contentType:@"application/dicom+json"
                 ];
     }
                                                                          (request));}];
}

-(void)addDatatablesSeriesHandler
{
    //"datatables/series?AccessionNumber=22&IssuerOfAccessionNumber.UniversalEntityID=NULL&StudyIUID=2.16.858.2.10000675.72769.20160411084701.1.100&session=1"
NSRegularExpression *dtseriesRegex = [NSRegularExpression regularExpressionWithPattern:@"/datatables/series" options:0 error:NULL];
[httpdicomServer addHandler:@"GET" regex:dtseriesRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock){completionBlock(^RSResponse* (RSRequest* request)
     {
         LOG_DEBUG(@"client: %@",request.remoteAddressString);
         NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
         NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
         
         
         NSDictionary *q=request.query;
         NSString *session=q[@"session"];
         if (!session || [session isEqualToString:@""]) return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'session' parameter"] contentType:@"application/dicom+json"];
         
         
         //find dest
         NSString *destOID=pacsTitlesDictionary[[q[@"custodiantitle"] stringByAppendingPathExtension:q[@"aet"]]];
         NSDictionary *entityDict=devices[destOID];
         
         NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
         if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
         NSString *where;
         NSString *AccessionNumber=q[@"AccessionNumber"];
         NSString *StudyInstanceUID=q[@"StudyInstanceUID"];
         if (
             [entityDict[@"preferredStudyIdentificator"] isEqualToString:@"AccessionNumber"]
             && AccessionNumber
             && ![AccessionNumber isEqualToString:@"NULL"])
         {
             NSString *IssuerOfAccessionNumber=q[@"IssuerOfAccessionNumber.UniversalEntityID"];
             if (IssuerOfAccessionNumber && ![IssuerOfAccessionNumber isEqualToString:@"NULL"]) where=[NSString stringWithFormat:@"%@ AND %@='%@' AND %@='%@'", sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"AccessionNumber"],AccessionNumber,sqlobjectmodel[@"IssuerOfAccessionNumber"],IssuerOfAccessionNumber];
             else where=[NSString stringWithFormat:@"%@ AND %@='%@'",sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"AccessionNumber"],AccessionNumber];
             
         }
         else if (StudyInstanceUID && ![StudyInstanceUID isEqualToString:@"NULL"])
             where=[NSString stringWithFormat:@"%@ AND %@='%@'",sqlobjectmodel[@"seriesWhere"],sqlobjectmodel[@"StudyInstanceUID"],StudyInstanceUID];
         else return [RSDataResponse responseWithData:[NSData jsonpCallback:q[@"callback"] forDraw:q[@"draw"] withErrorString:@"query without required 'AccessionNumber' or 'StudyInstanceUID' parameter"] contentType:@"application/dicom+json"];
         
         
         LOG_INFO(@"WHERE %@",[where substringFromIndex:38]);
         
         NSString *sqlDataQuery=[NSString stringWithFormat:@"%@%@%@%@",
                                 entityDict[@"sqlprolog"],
                                 sqlobjectmodel[@"datatablesSeriesProlog"],
                                 where,
                                 [NSString stringWithFormat:
                                  sqlobjectmodel[@"datatablesSeriesEpilog"],
                                  session,
                                  session
                                  ]
                                 ];
         
         NSMutableArray *seriesArray=jsonMutableArray(sqlDataQuery,(NSStringEncoding) [entityDict[@"sqlstringencoding"] integerValue]);
         //LOG_INFO(@"series array:%@",[seriesArray description]);
         
         NSMutableDictionary *resp = [NSMutableDictionary dictionary];
         if (q[@"draw"])[resp setObject:q[@"draw"] forKey:@"draw"];
         NSNumber *count=[NSNumber numberWithUnsignedInteger:[seriesArray count]];
         [resp setObject:count forKey:@"recordsTotal"];
         [resp setObject:count forKey:@"recordsFiltered"];
         [resp setObject:seriesArray forKey:@"data"];
         return [RSDataResponse
                 responseWithData:[NSData jsonpCallback:q[@"callback"]withDictionary:resp]
                 contentType:@"application/dicom+json"
                 ];
     }
(request));}];
}
@end
