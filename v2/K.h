//
//  K.h  Key Constant
//  httpdicom
//
//  Created by jacquesfauquex on 20180321.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

#import <Foundation/Foundation.h>

//iso3166 country parsing
#define PAIS 0
#define COUNTRY 1
#define AB 2
#define ABC 3
#define XXX 4

//DICOM coded triplet
#define CODE 0
#define SCHEME 1
#define MEANING 2

//fidji
#define fidjiqueueconcurrency 4

#define levelPatient 0
#define levelStudy 1
#define levelSeries 2
#define levelInstance 3

#define patientTopFilterNumber 16
#define studyTopFilterNumber 39
#define seriesTopFilterNumber 59
#define instanceTopFilterNumber 63


//patient 0+
#define IssuerOfPatientID 0
#define IssuerOfPatientIDLocalNamespaceEntityID 1
#define IssuerOfPatientIDUniversalEntityID 2
#define IssuerOfPatientIDUniversalEntityIDType 3
#define PatientID 4
#define PatientName 5
#define PatientBirthDate 6
#define PatientSex 7

//procedure code 17+
#define ProcedureCodeValue 17
#define ProcedureCodingSchemeDesignator 18
#define ProcedureCodeMeaning 19

//study 20+
#define StudyInstanceUID 20
#define StudyDescription 21
#define StudyDate 22
#define StudyTime 23
#define StudyID 24

#define AccessionNumber 29

#define IssuerOfAccessionNumberLocalNamespaceEntityID 30
#define IssuerOfAccessionNumberUniversalEntityID 31
#define IssuerOfAccessionNumberUniversalEntityIDType 32
#define ReferringPhysicianName 33
#define NameOfPhysiciansReadingStudy 34
#define ModalitiesInStudy 35
#define NumberOfStudyRelatedSeries 36
#define NumberOfStudyRelatedInstances 37

//series 40+
#define SeriesInstanceUID 40
#define Modality 41
#define SeriesDescription 42
#define SeriesNumber 43
#define BodyPartExamined 44

#define StationName 47
#define InstitutionalDepartmentName 48
#define InstitutionName 49
#define PerformingPhysicianName 50

#define InstitutionCodeValue 52
#define InstitutionschemeDesignator 53

#define PerformedProcedureStepStartDate 55
#define PerformedProcedureStepStartTime 56
#define RequestScheduledProcedureStepID 57
#define RequestProcedureID 58

#define NumberOfSeriesRelatedInstances 59

//instances 60+
#define SOPInstanceUID 60
#define SOPClassUID 61
#define InstanceNumber 62
#define HL7InstanceIdentifier 63

//the 64 bits correspond to the array of 64 queryable tags
#define specificfilterbitmap 0x90040106E0DA0070
#define genericfilterbitmap  0x60338E0901240085


@interface K : NSObject

@property (class, nonatomic, readonly) NSArray               *key;
@property (class, nonatomic, readonly) NSArray               *tag;
@property (class, nonatomic, readonly) NSArray               *vr;

@property (class, nonatomic, readonly) NSArray               *modalities;

@property (class, nonatomic, readonly) NSArray               *levels;

@property (class, nonatomic, readonly) NSRegularExpression   *PPPRegex;
@property (class, nonatomic, readonly) NSRegularExpression   *DARegex;
@property (class, nonatomic, readonly) NSRegularExpression   *SHRegex;
@property (class, nonatomic, readonly) NSRegularExpression   *UIRegex;
@property (class, nonatomic, readonly) NSRegularExpression   *TZRegex;

@property (class, nonatomic, readonly) NSString              *defaultTimezone;

@property (class, nonatomic, readonly) NSDictionary          *scheme;
@property (class, nonatomic, readonly) NSDictionary          *schemeindexes;
@property (class, nonatomic, readonly) NSDictionary          *code;
@property (class, nonatomic, readonly) NSDictionary          *codeindexes;
@property (class, nonatomic, readonly) NSDictionary          *procedure;
@property (class, nonatomic, readonly) NSDictionary          *procedureindexes;
@property (class, nonatomic, readonly) NSArray               *iso3166;
@property (class, nonatomic, readonly) NSDictionary          *personidtype;

+(void)setDefaultTimezone:(NSString*)timezone;
+(void)loadIso3166ByCountry:(NSArray*)country;
+(void)loadPersonIDTypes:(NSDictionary*)personidtype;
+(void)loadScheme:(NSDictionary*)scheme;
+(void)loadCode:(NSDictionary*)code forKey:(NSString*)key;
+(void)loadProcedure:(NSDictionary*)procedure forKey:(NSString*)key;

+(NSUInteger)indexOfAttribute:(NSString*)refString;
@end
