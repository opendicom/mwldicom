<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0" 
    >


    <xsl:template match="root">
        <plist
            >
            <!--
            xmlns="http://www.opendicom.com/xsd/plist/code1.xsd"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.opendicom.com/xsd/plist/code1.xsd ../code1.xsd"
            version="1.0"
            -->
            <dict>
                <xsl:apply-templates  select="row"/>
            </dict>            
        </plist>        
    </xsl:template>


    <xsl:template match="row">
        <key><xsl:value-of select="key/text()"/></key>
        <dict>
            <key>displayname</key><string id="displayname"><xsl:value-of select="normalize-space(displayname/text())"/></string>
            <key>shortname</key><string id=""><xsl:value-of select="shortname/text()"/></string>
            <key>modality</key><string id="modality"><xsl:choose>
                <xsl:when test="modalidad='Rayos'">CR</xsl:when>
                <xsl:when test="modalidad='Mammografias'">MG</xsl:when>
                <xsl:when test="modalidad='Doppler'">US</xsl:when>
                <xsl:when test="modalidad='Ecocardiograma'">US</xsl:when>
                <xsl:when test="modalidad='Ecos Simples'">US</xsl:when>
                <xsl:when test="modalidad='Ecos Especiales'">US</xsl:when>
                <xsl:when test="modalidad='Pielos'"></xsl:when>
                <xsl:when test="modalidad='TAC MC 1'">CT</xsl:when>
                <xsl:when test="modalidad='Endoscopias'"></xsl:when>
                <xsl:when test="modalidad='Procedimientos'"></xsl:when>
                <xsl:when test="modalidad='Resonancia Magnetica'">MR</xsl:when>
                <xsl:when test="modalidad='Densitometria'"></xsl:when>
            </xsl:choose></string>
            <key>category</key><string id="category"><xsl:value-of select="modalidad/text()"/></string>
            <key>code</key><string id="code"><xsl:value-of select="code/text()"/></string>
            <key>codescheme</key><integer>4</integer>
            <key>qualifier</key><array></array>
        </dict>
    </xsl:template>
</xsl:stylesheet>