//
//  DRS+weasis.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180118.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

#import "DRS+weasis.h"

@implementation DRS (weasis)

-(void)addWeasisStudiesHandler
{
 NSRegularExpression *mwstudiesRegex = [NSRegularExpression regularExpressionWithPattern:@"^/manifest/weasis/studies" options:NSRegularExpressionCaseInsensitive error:NULL];
 [httpdicomServer addHandler:@"GET" regex:mwstudiesRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock)
 {completionBlock(^RSResponse* (RSRequest* request)
 {
 LOG_DEBUG(@"client: %@",request.remoteAddressString);
 NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
 NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
 
 //request parts logging
 NSURL *requestURL=request.URL;
 NSString *bSlash=requestURL.baseURL.absoluteString;
 NSString *b=[bSlash substringToIndex:[bSlash length]-1];
 NSString *p=requestURL.path;
 //NSString *q=requestURL.query;
 NSDictionary *q=request.query;
 
 
 NSDictionary *entityDict=devices[q[@"custodianOID"]];
 NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
 if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
 //db response may be in latin1
 NSStringEncoding charset=(NSStringEncoding)[entityDict[@"sqlstringencoding"] integerValue ];
 if (charset!=4 && charset!=5) return [RSErrorResponse responseWithClientError:404 message:@"unknown sql charset : %lu",(unsigned long)charset];
 
 NSString *sqlString;
 NSString *AccessionNumber=request.query[@"AccessionNumber"];
 if (AccessionNumber)sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyAccessionNumber"],entityDict[@"sqlprolog"],AccessionNumber];
 else
 {
 NSString *StudyInstanceUID=request.query[@"StudyInstanceUID"];
 if (StudyInstanceUID)sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyStudyInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID];
 else return [RSErrorResponse responseWithClientError:404 message:
 @"parameter AccessionNumber or StudyInstanceUID required in %@%@?%@",b,p,q];
 }
 //SQL for studies
 NSMutableData *studiesData=[NSMutableData data];
 int studiesResult=task(@"/bin/bash",
 @[@"-s"],
 [sqlString dataUsingEncoding:NSUTF8StringEncoding],
 studiesData
 );
 
 
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:studiesData encoding:NSISOLatin1StringEncoding];
 [studiesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 NSMutableArray *studyArray=[NSJSONSerialization JSONObjectWithData:studiesData options:0 error:nil];
 //[0] p.family_name,p.given_name,p.middle_name,p.name_prefix,p.name_suffix,
 //[1] patient_id.pat_id,
 //[2] iopid.entity_uid,
 //[3] patient.pat_birthdate,
 //[4] patient.pat_sex,
 
 //[5] study.study_iuid,
 //[6] study.accession_no,
 //[7] ioan.entity_uid,
 //[8] study_query_attrs.retrieve_aets,
 //[9] study.study_id,
 //[10] study.study_desc,
 //[11] study.study_date,
 //[12] study.study_time
 //[13] NumberOfStudyRelatedInstances
 
 //the accessionNumber may join more than one study of one or more patient !!!
 //look for patient roots first
 NSMutableArray *uniquePatients=[NSMutableArray array];
 for (NSArray *studyInstance in studyArray)
 {
 [uniquePatients addObject:[studyInstance[1]stringByAppendingPathComponent:studyInstance[2]]];
 }
 
 NSMutableString *weasisManifest=[NSMutableString string];
 //each patient
 for (NSString *patient in [NSSet setWithArray:uniquePatients])
 {
 NSUInteger studyIndex=[uniquePatients indexOfObject:patient];
 NSArray *patientAttrs=studyArray[studyIndex];
 [weasisManifest appendFormat:
 @"<Patient PatientName=\"%@\" PatientID=\"%@\" IssuerOfPatientID=\"%@\" PatientBirthDate=\"%@\" PatientSex=\"%@\">\r",
 patientAttrs[0],
 patientAttrs[1],
 patientAttrs[2],
 patientAttrs[3],
 patientAttrs[4]
 ];
 
 for (NSArray *studyInstance in studyArray)
 {
 if (  [studyInstance[1]isEqualToString:patientAttrs[1]]
 )
 {
 //                             &&[studyInstance[2]isEqualToString:patientAttrs[2]]
 //TODO: add second if clause?
 
 //each study of this patient
 [weasisManifest appendFormat:
 @"<Study SpecificCharacterSet=\"UTF-8\" StudyInstanceUID=\"%@\" AccessionNumber=\"%@\" IssuerOfAccessionNumber=\"%@\" RetrieveAETitle=\"%@\" StudyID=\"%@\" StudyDescription=\"%@\" StudyDate=\"%@\" StudyTime=\"%@\" WadorsURI=\"/studies/%@\" NumberOfStudyRelatedInstances=\"%@\">\r",
 studyInstance[5],
 studyInstance[6],
 studyInstance[7],
 studyInstance[8],
 studyInstance[9],
 studyInstance[10],
 studyInstance[11],
 studyInstance[12],
 studyInstance[5],
 studyInstance[13]
 ];
 
 //series
 
 NSMutableData *seriesData=[NSMutableData data];
 int seriesResult=task(@"/bin/bash",
 @[@"-s"],
 [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisSeriesStudyInstanceUID"],entityDict[@"sqlprolog"],studyInstance[5]]
 dataUsingEncoding:NSUTF8StringEncoding],
 seriesData
 );
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:seriesData encoding:NSISOLatin1StringEncoding];
 [seriesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 NSMutableArray *seriesArray=[NSJSONSerialization JSONObjectWithData:seriesData options:0 error:nil];
 
 for (NSArray *seriesInstance in seriesArray)
 {
 [weasisManifest appendFormat:
 @"<Series SeriesInstanceUID=\"%@\" SeriesDescription=\"%@\" SeriesNumber=\"%@\" Modality=\"%@\"  WadorsURI=\"/studies/%@/series/%@\" NumberOfSeriesRelatedInstances=\"%@\">\r",
 seriesInstance[0],
 seriesInstance[1],
 seriesInstance[2],
 seriesInstance[3],
 studyInstance[5],
 seriesInstance[0],
 seriesInstance[4]
 ];
 //instances
 NSMutableData *instanceData=[NSMutableData data];
 int instanceResult=task(@"/bin/bash",
 @[@"-s"],
 [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisInstanceSeriesInstanceUID"],entityDict[@"sqlprolog"],seriesInstance[0]]
 dataUsingEncoding:NSUTF8StringEncoding],
 instanceData
 );
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:instanceData encoding:NSISOLatin1StringEncoding];
 [instanceData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 
 NSMutableArray *instanceArray=[NSJSONSerialization JSONObjectWithData:instanceData options:0 error:nil];
 for (NSArray *instance in instanceArray)
 {
 [weasisManifest appendFormat:
 @"<Instance SOPInstanceUID=\"%@\" InstanceNumber=\"%@\" SOPClassUID=\"%@\"/>\r",
 instance[0],
 instance[1],
 instance[2]
 ];
 }
 [weasisManifest appendString:@"</Series>\r"];
 }
 [weasisManifest appendString:@"</Study>\r"];
 }
 }
 [weasisManifest appendString:@"</Patient>\r"];
 }
 return [RSDataResponse responseWithData:[weasisManifest dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/xml"];
 
 }(request));}];
}


-(void)addWeasisSeriesHandler
{
 #pragma mark /manifest/weasis/studies/{StudyInstanceUID}/series/{SeriesInstanceUID}
 
 NSRegularExpression *mwseriesRegex = [NSRegularExpression regularExpressionWithPattern:@"^/manifest/weasis/studies/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*" options:NSRegularExpressionCaseInsensitive error:NULL];
 ///series/[1-2](\\d)*(\\.0|\\.[1-9](\\d)*)*
 
 [httpdicomServer addHandler:@"GET" regex:mwseriesRegex processBlock:
 ^(RSRequest* request, RSCompletionBlock completionBlock)
 {completionBlock(^RSResponse* (RSRequest* request)
 {
 LOG_DEBUG(@"client: %@",request.remoteAddressString);
 NSURLComponents *urlComponents=[NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
 NSArray *pComponents=[urlComponents.path componentsSeparatedByString:@"/"];
 
 //request parts logging
 NSURL *requestURL=request.URL;
 NSString *bSlash=requestURL.baseURL.absoluteString;
 NSString *b=[bSlash substringToIndex:[bSlash length]-1];
 
 NSString *p=requestURL.path;
 NSString *StudyInstanceUID=pComponents[4];
 NSString *SeriesInstanceUID=pComponents[6];
 
 //NSString *q=requestURL.query;
 NSDictionary *q=request.query;
 NSDictionary *entityDict=devices[q[@"custodianOID"]];
 NSDictionary *sqlobjectmodel=sql[entityDict[@"sqlobjectmodel"]];
 if (!sqlobjectmodel) return [RSErrorResponse responseWithClientError:404 message:@"%@ [sql not found]",urlComponents.path];
 //db response may be in latin1
 NSStringEncoding charset=(NSStringEncoding)[entityDict[@"sqlstringencoding"] integerValue ];
 if (charset!=4 && charset!=5) return [RSErrorResponse responseWithClientError:404 message:@"unknown sql charset : %lu",(unsigned long)charset];
 
 NSString *sqlString=[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisSeriesStudyInstanceUIDSeriesInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID,SeriesInstanceUID];
 
 //LOG_INFO(@"%@",sqlString);
 
 //SQL for series
 NSMutableData *seriesData=[NSMutableData data];
 int seriesResult=task(@"/bin/bash",
 @[@"-s"],
 [sqlString dataUsingEncoding:NSUTF8StringEncoding],
 seriesData
 );
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:seriesData encoding:NSISOLatin1StringEncoding];
 [seriesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 NSMutableArray *seriesArray=[NSJSONSerialization JSONObjectWithData:seriesData options:0 error:nil];
 if (![seriesArray count]) return [RSErrorResponse responseWithClientError:404 message:@"0 record for %@%@?%@",b,p,q];
 //[0] SeriesInstanceUID,
 //[1] SeriesDescription,
 //[2] SeriesNumber,
 //[3] Modality,
 
 //get corresponding patient and study
 //SQL for studies
 
 NSMutableData *studiesData=[NSMutableData data];
 int studiesResult=task(@"/bin/bash",
 @[@"-s"],
 [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisStudyStudyInstanceUID"],entityDict[@"sqlprolog"],StudyInstanceUID] dataUsingEncoding:NSUTF8StringEncoding],
 studiesData
 );
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:studiesData encoding:NSISOLatin1StringEncoding];
 [studiesData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 NSMutableArray *studyArray=[NSJSONSerialization JSONObjectWithData:studiesData options:0 error:nil];
 
 //[0]  p.family_name,p.given_name,p.middle_name,p.name_prefix,p.name_suffix,
 //[1] patient_id.pat_id,
 //[2] iopid.entity_uid,
 //[3] patient.pat_birthdate,
 //[4] patient.pat_sex,
 
 //[5] study.study_iuid,
 //[6] study.accession_no,
 //[7] ioan.entity_uid,
 //[8] study_query_attrs.retrieve_aets,
 //[9] study.study_id,
 //[10] study.study_desc,
 //[11] study.study_date,
 //[12] study.study_time
 
 //the accessionNumber may join more than one study of one or more patient !!!
 //look for patient roots first
 NSMutableArray *uniquePatients=[NSMutableArray array];
 for (NSArray *studyInstance in studyArray)
 {
 [uniquePatients addObject:[studyInstance[1]stringByAppendingPathComponent:studyInstance[2]]];
 }
 
 NSMutableString *weasisManifest=[NSMutableString string];
 //each patient
 for (NSString *patient in [NSSet setWithArray:uniquePatients])
 {
 NSUInteger studyIndex=[uniquePatients indexOfObject:patient];
 NSArray *patientAttrs=studyArray[studyIndex];
 [weasisManifest appendFormat:
 @"<Patient PatientName=\"%@\" PatientID=\"%@\" IssuerOfPatientID=\"%@\" PatientBirthDate=\"%@\" PatientSex=\"%@\">\r",
 patientAttrs[0],
 patientAttrs[1],
 patientAttrs[2],
 patientAttrs[3],
 patientAttrs[4]
 ];
 
 for (NSArray *studyInstance in studyArray)
 {
 if (  [studyInstance[1]isEqualToString:patientAttrs[1]]
 &&[studyInstance[2]isEqualToString:patientAttrs[2]]
 )
 {
 //each study of this patient
 [weasisManifest appendFormat:
 @"<Study SpecificCharacterSet=\"UTF-8\" StudyInstanceUID=\"%@\" AccessionNumber=\"%@\" IssuerOfAccessionNumber=\"%@\" RetrieveAETitle=\"%@\" StudyID=\"%@\" StudyDescription=\"%@\" StudyDate=\"%@\" StudyTime=\"%@\" WadorsURI=\"/studies/%@\" NumberOfStudyRelatedInstances=\"%@\">\r",
 studyInstance[5],
 studyInstance[6],
 studyInstance[7],
 studyInstance[8],
 studyInstance[9],
 studyInstance[10],
 studyInstance[11],
 studyInstance[12],
 studyInstance[5],
 studyInstance[13]
 ];
 for (NSArray *seriesInstance in seriesArray)
 {
 [weasisManifest appendFormat:
 @"<Series SeriesInstanceUID=\"%@\" SeriesDescription=\"%@\" SeriesNumber=\"%@\" Modality=\"%@\"  WadorsURI=\"/studies/%@/series/%@\" NumberOfSeriesRelatedInstances=\"%@\">\r",
 seriesInstance[0],
 seriesInstance[1],
 seriesInstance[2],
 seriesInstance[3],
 studyInstance[5],
 seriesInstance[0],
 seriesInstance[4]
 ];
 
 //instances
 NSMutableData *instanceData=[NSMutableData data];
 int instanceResult=task(@"/bin/bash",
 @[@"-s"],
 [[NSString stringWithFormat:sqlobjectmodel[@"manifestWeasisInstanceSeriesInstanceUID"],entityDict[@"sqlprolog"],seriesInstance[0]]
 dataUsingEncoding:NSUTF8StringEncoding],
 instanceData
 );
 if (charset==5) //latin1
 {
 NSString *latin1String=[[NSString alloc]initWithData:instanceData encoding:NSISOLatin1StringEncoding];
 [instanceData setData:[latin1String dataUsingEncoding:NSUTF8StringEncoding]];
 }
 NSMutableArray *instanceArray=[NSJSONSerialization JSONObjectWithData:instanceData options:0 error:nil];
 for (NSArray *instance in instanceArray)
 {
 [weasisManifest appendFormat:
 @"<Instance SOPInstanceUID=\"%@\" InstanceNumber=\"%@\" SOPClassUID=\"%@\"/>\r",
 instance[0],
 instance[1],
 instance[2]
 ];
 }
 [weasisManifest appendString:@"</Series>\r"];
 }
 [weasisManifest appendString:@"</Study>\r"];
 }
 }
 [weasisManifest appendString:@"</Patient>\r"];
 }
 return [RSDataResponse responseWithData:[weasisManifest dataUsingEncoding:NSUTF8StringEncoding] contentType:@"text/xml"];
 
 }(request));}];
}
@end
