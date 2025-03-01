//
//  DRS+pdf.h
//  httpdicom
//
//  Created by jacquesfauquex on 20180116.
//  Copyright © 2018 ridi.salud.uy. All rights reserved.
//

/* PARAMETERS

 Los nombres que empiezan con mayúscula corresponden exactamente a atributos DICOM.
 Los nombres que empiezan con minúscula reciben valores que requieren tratamiento antes de transformarse en atributo DICOM.
 
 {
 "pacs":"",
 
 "AccessionNumber":"",
 "issuerLocal":"",
 "issuerUniversal":"",
 "issuerTipo":"",
 
 "StudyDescription":"",
 "apellido1":"",
 "apellido2":"",
 "nombres":"",
 
 "PatientID":"",
 "PatientIDCountry":"",
 "PatientIDType":"",
 
 "clave":"",
 
 "PatientBirthDate":"",
 "PatientSex":"",
 
 "ReferringPhysiciansName":"",
 "NameofPhysicianReadingStudy":"",
 
 "DocumentTitle":"",
 "concepto":"",
 "clase":"",
 "VerificationFlag":"",
 "HL7InstanceIdentifier":"",

 "enclosurePdf":""
 }
 
 AccessionNumber y PatientID son campos obligatorios.
 
 
 Si AccessionNumber corresponde a un estudio presente en el PACS y PatientID a un paciente que no corresponde, el informe está rechazado.
 Si el identificador del paciente corresponde pero los otros datos patronímicos no corresponden, ni de cerca (por ejemplo sexo diferente, fecha de nacimiento muy diferente, nombres o apellido que no corresponden) el informe está rechazado.
 
 Si ambos el accessionNumber y PatientID  corresponden a un estudio ya presente en el PACS, el informe se adjunta al estudio y los otros campos demográficos del paciente son opcionales y no tomados en cuenta
 
 Si no existe un estudio con este numero, se crea un estudio nuevo. y si necesario un paciente nuevo.
 Si no existe un estudio con este numero ni este PatientID, se crea un paciente nuevo y un  estudio nuevo.
 
 
 Si ReferringPhysiciansName ya fue pasado en la orden de servicio, no es necesario repetirlo (y no se puede modificar por este medio... quedará con el nombre definido en la orden de servicio)
 
 Si clave ya fue pasado en la orden de servicio, repetirla solamente para modificarla. Sino dejar el campo vacío.
 
 Son opcionales:
 
 - concepto (codificación del titulo, en caso que se usen codificaciones de informes de radiología)
 - clase (clasificación del documento)
 Ambos tienen el formato código^nombre del vocabulario^significado en español o inglés.
 Nombre del vocabulario puede ser SNOMED, LOINC, etc...
 -VerificacionFlag. En caso de estar presente, puede tener como valor UNVERIFIED o VERIFIED
 -HL7InstanceIdentifier
 
AccessionNumber
===============
 Si es local se completa "issuerLocal" por ejemplo con el valor "IRP" o el nombre de la institución solicitante, en caso que se copio en AccessionNumber el numero de orden de servicio provisto por la institución solicitante.
 Existe también la opción de calificar el issuer del accessionNumber en base a un sistema nacional (por medio de OID, URL, etc). En este caso llenar "IssuerUniversal" y "issuerTipo". Para issuerTipo los valores admitidos son :
 - DNS (An Internet dotted name. Either in ASCII or as integers)
 - EUI64 (An IEEE Extended Unique Identifier)
 - ISO (OID)
 - URI
 - UUID
 - X400
 - X500
 
Clave
=====
 (1) se comunica al servicio rest /patient del PACS para verificar los datos patronímicos y eventualmente crear la ficha paciente
 (nuevo) se comunicara con html5dicom para pasar nombre identificador y clave del paciente
 (3) se crea con el servicio rest /mwlItem del PACS para agregar la tarea a la worklist
 (4) crea un documento de solicitud el cual contiene el pdf de orden de servicio. Este documento es el primero del estudio.

AccessionNumber= (<17 caracteres - identificador único de este estudio de este paciente en la historia clínica de BCBSU)
StudyDescription= (formato: código^scheme^meaning)
PatientName= (apellido1>apellido2^nombre1 nombre2   todo en mayusculas)
PatientID= (cédula sin puntos, con guión antes del dígito verificador,  o nro pasaporte)
PatientIDIssuer= (formato: 2.16.858.1.[ID país].[ID tipo de documento] ,  ver lista de los ID abajo)
PatientBirthDate= (formato: aaaammdd)
PatientSex= (M=masculino, F=feminino, O=no especificado)
Priority=
pdf= (dato médico u otras comunicaciones en el formato de documento indicado por el nombre del parámetro, codificado base64)
msg= texto

Referring= (quien pidió el examen. Formato:   BCBSU^^Apellido (y eventualmente nombre)^especialidad)
*/

#import "DRS.h"


@interface DRS (pdf)

-(void)addPDFHandler;

@end
