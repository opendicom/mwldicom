<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    
    <xsl:template match="root">
        <plist
            xmlns="http://www.opendicom.com/xsd/plist/code.xsd"
            
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.opendicom.com/xsd/plist/code.xsd ../code.xsd"
            
            version="1.0"
            >
            
            <dict>
                <xsl:apply-templates  select="row"/>
            </dict>            
        </plist>        
    </xsl:template>
    
    <xsl:template match="row">
        <xsl:if test="(presta/text() != '000') and (corr/text() = '0000')">
            <xsl:variable name="glosa1" select="normalize-space(following-sibling::row[1][corr='0001']/glosa/text())"/>
            <xsl:variable name="glosa2" select="normalize-space(following-sibling::row[2][corr='0002']/glosa/text())"/>
            <xsl:variable name="glosa3" select="normalize-space(following-sibling::row[3][corr='0003']/glosa/text())"/>
            <xsl:variable name="glosa4" select="normalize-space(following-sibling::row[4][corr='0004']/glosa/text())"/>
            <xsl:variable name="glosa5" select="normalize-space(following-sibling::row[5][corr='0005']/glosa/text())"/>
            <key><xsl:value-of select="concat(grupo/text(),sub_grupo/text(),presta/text())"/></key>
        <dict>
            <key>codescheme</key><integer>4</integer>
            <key>codemeaning</key><string id="codemeaning"><xsl:value-of select="normalize-space(concat(glosa/text(),$glosa1,$glosa2,$glosa3,$glosa4,$glosa5))"/></string>
            <key>modality</key><string id="modality"></string>
            <key>category</key><string id="category"><xsl:value-of select="concat(grupo/text(),'.',sub_grupo/text())"/></string>
            <key>uri</key><string id="uri"></string>
            <key>translation</key><dict></dict>
        </dict>
            
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>