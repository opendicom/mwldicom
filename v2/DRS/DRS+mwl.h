//
//  DRS+mwl.h
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
 "sala":"",
 "modalidad":"",

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
 
 "Priority":"",
 "ReferringPhysiciansName":"",
 "NameofPhysicianReadingStudy":"",
 
 "msg":"",
 "enclosurePdf":""
 }
 
 modalidad reemplaza Modality en la lista anterior. Es que en la nueva versión se va a examinar en conjunto con sala, y en base a un archivo de mapeo permitirá definir los valores correctos para los atributos DICOM ScheduledProcedureStepSequence.Modality y ScheduledProcedureStepSequence.ScheduledStationAETitle.
 
 Se agregan campos para caracterizar el AccessionNumber. Si es local se completa "issuerLocal" por ejemplo con el valor "IRP" o el nombre de la institución solicitante, en caso que se copio en AccessionNumber el numero de orden de servicio provisto por la institución solicitante.
 Existe también la opción de calificar el issuer del accessionNumber en base a un sistema nacional (por medio de OID, URL, etc). En este caso llenar "IssuerUniversal" y "issuerTipo". Para issuerTipo los valores admitidos son :
 - DNS (An Internet dotted name. Either in ASCII or as integers)
 - EUI64 (An IEEE Extended Unique Identifier)
 - ISO (OID)
 - URI
 - UUID
 - X400
 - X500
 
 Agregamos  también clave, que NO se copia en el item de la worklist.  Pero la información no se pierde porque la aplicación invocada para generar items realiza varias operaciones:
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


@interface DRS (mwl)

-(void)addMWLHandler;

@end
