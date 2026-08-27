module Fgdc2aardvark
# Mapping from FGDC to Aardvark following:
#   https://opengeometadata.org/aardvark-fgdc-iso-crosswalk/
# Borrowing from:
# https://github.com/OpenGeoMetadata/GeoCombine/blob/draft_fgdc2Aardvark/lib/xslt/fgdc2Aardvark_draft_v1.xsl
# Detailed documentation on each Aardvark field:
#   https://opengeometadata.org/ogm-aardvark/

  # input args:
  #   fgdc_url - publicly accessible URL to FGDC XML
  #   doc  -  nokogiri::XML::Document representing the FGDC XML
  def fgdc2aardvark(fgdc_url, doc)
    layer = {}

    # # Figure this out first, some of the other metadata
    # # is based on this value
    # @dct_rights_sm = doc2dct_rights_sm(doc)

    # Add each element in turn, following the order from the example at:
    #   https://opengeometadata.org/JSON-format/#example
    
    layer[:dct_title_s] = doc2dct_title_s(doc)
    layer[:dct_alternative_sm] = doc2dct_alternative_sm(doc)
    layer[:dct_description_sm] = doc2dct_description_sm(doc)
    layer[:dct_language_sm] = doc2dct_language_sm(doc)
    layer[:dct_creator_sm] = doc2dct_creator_sm(doc)
    layer[:dct_publisher_sm] = doc2dct_publisher_sm(doc)
    layer[:schema_provider_s] = doc2schema_provider_s(doc)
    layer[:gbl_resourceClass_sm] = doc2gbl_resourceClass_sm(doc)
    layer[:gbl_resourceType_sm] = doc2gbl_resourceType_sm(doc)
    layer[:dcat_theme_sm] = doc2dcat_theme_sm(doc)
    layer[:dcat_keyword_sm] = doc2dcat_keyword_sm(doc)
    layer[:dct_temporal_sm] = doc2dct_temporal_sm(doc)
    layer[:dct_issued_s] = doc2dct_issued_s(doc)
    layer[:gbl_indexYear_im] = doc2gbl_indexYear_im(doc)
    layer[:gbl_dateRange_drsim] = doc2gbl_dateRange_drsim(doc)
    layer[:dct_spatial_sm] = doc2dct_spatial_sm(doc)
    layer[:dct_subject_sm] = doc2dct_subject_sm(doc)
    layer[:locn_geometry] = doc2locn_geometry(doc)
    layer[:dcat_bbox] = doc2dcat_bbox(doc)
    layer[:dcat_centroid] = doc2dcat_centroid(doc)
    layer[:pcdm_memberOf_sm] = doc2pcdm_memberOf_sm(doc)
    layer[:dct_isPartOf_sm] = doc2dct_isPartOf_sm(doc)
    layer[:dct_rights_sm] = doc2dct_rights_sm(doc)
    layer[:dct_license_sm] = doc2dct_license_sm(doc)
    layer[:dct_accessRights_s] = doc2dct_accessRights_s(doc)
    layer[:dct_format_s] = doc2dct_format_s(doc)
    layer[:dct_references_s] = doc2dct_references_s(doc, fgdc_url)
    layer[:gbl_wxsIdentifier_s] = doc2gbl_wxsIdentifier_s(doc)
    layer[:id] = doc2id(doc)
    layer[:dct_identifier_sm] = doc2dct_identifier_sm(doc)
    layer[:gbl_mdModified_dt] = doc2gbl_mdModified_dt(doc)
    layer[:gbl_mdVersion_s] = doc2gbl_mdVersion_s(doc)
    
    return JSON.pretty_generate(layer)

  end


  def doc2dct_title_s(doc)
    return doc.xpath("//idinfo/citation/citeinfo/title").text
  end

  def doc2dct_alternative_sm(doc)
  end

  def doc2dct_description_sm(doc)
    return doc.xpath("//idinfo/descript/abstract").text
  end

  def doc2dct_language_sm(doc)
    langdata = doc.xpath("//idinfo/descript/langdata").text
    return "English" if langdata.match /en/i

    # undetermined - default to English
    return "English"
  end

  def doc2dct_creator_sm(doc)
    # If not found, return empty array
    doc.xpath("//idinfo/citation/citeinfo/origin").map { |node|
      node.text.strip
    } || []
  end

  def doc2dct_publisher_sm(doc)
    # doc.xpath("//idinfo/citation/citeinfo/pubinfo/publish").text
    # doc.xpath("//idinfo/citation/citeinfo/pubinfo/publish").map(&:text.strip)
    doc.xpath("//idinfo/citation/citeinfo/pubinfo/publish").map { |node|
      node.text.strip
    }
  end

  def doc2schema_provider_s(doc)
    @provenance
  end

  def doc2gbl_resourceClass_sm(doc)
  end

  def doc2gbl_resourceType_sm(doc)
    sdtstype = doc.xpath('//metadata/spdoinfo/ptvctinf/sdtsterm/sdtstype').text
    return 'Polygon' if sdtstype.match /G-polygon/i
    return 'Point' if sdtstype.match /Point/i
    return 'Line' if sdtstype.match /String/i

    direct = doc.xpath('//metadata/spdoinfo/direct').text
    return 'Raster' if direct.match /Raster/i
    return 'Point' if direct.match /Point/i
    return 'Polygon' if direct.match /Vector/i

    indspref = doc.xpath('//metadata/spdoinfo/indspref').text
    return 'Table' if indspref.match /Table/i

    # undetermined
    return 'UNDETERMINED'
  end

  def doc2dcat_theme_sm(doc)
  end

  def doc2dcat_keyword_sm(doc)
  end

  def doc2dct_temporal_sm(doc)
  end

  def doc2dct_issued_s(doc)
    pubdate = doc.xpath("//idinfo/citation/citeinfo/pubdate").text
    dct_issued_s = '';
    return dct_issued_s unless pubdate.match /^A\d+^Z/

    dct_issued_s = dct_issued_s + pubdate[0..3] if pubdate.length >= 4
    dct_issued_s = dct_issued_s + "-" + pubdate[4..5] if pubdate.length >= 6
    dct_issued_s = dct_issued_s + "-" + pubdate[6..7] if pubdate.length == 8
    return dct_issued_s
  end

  def doc2gbl_indexYear_im(doc)
    # check each of four locations, find the first 4-digit sequence.
    if d = doc.at_xpath("//idinfo/timeperd/timeinfo/sngdate/caldate")
      d.text.scan(/\d\d\d\d/) { |year| return year }
    end
    if d = doc.at_xpath("//idinfo/timeperd/timeinfo/mdattim/sngdate/caldate")
      d.text.scan(/\d\d\d\d/) { |year| return year }
    end
    if d = doc.at_xpath("//idinfo/timeperd/timeinfo/rngdates/begdate")
      d.text.scan(/\d\d\d\d/) { |year| return year }
    end
    if d = doc.at_xpath("//idinfo/keywords/temporal/tempkey")
      d.text.scan(/\d\d\d\d/) { |year| return year }
    end

    # Couldn't find any date?
    return nil
  end

  def doc2gbl_dateRange_drsim(doc)
    if rngdates = doc.at_xpath("//idinfo/timeperd/timeinfo/rngdates")
      begdate = rngdates.xpath("begdate").text[0..3]
      enddate = rngdates.xpath("enddate").text[0..3]
      if begdate.match(/\d\d\d\d/) and enddate.match(/\d\d\d\d/)
        "[" + begdate + " TO " + enddate + "]"
      end
    end
  end

  def doc2dct_spatial_sm(doc)
    doc.xpath("//idinfo/keywords/place/placekey").map { |node|
      node.text.strip
    }
  end

  def doc2dct_subject_sm(doc)
    # # ALL subjects?
    # doc.xpath("//idinfo/keywords/theme/themekey").map { |node|
    #   node.text.strip
    # }

    # filter by vocabulary - anything labeled ISO 19115
    subjects = []
    if iso_theme = doc.at_css('theme:has(themekt[text() *= "ISO 19115"])')
      iso_theme.xpath(".//themekey").each { |node|
        subjects << node.text.sub(/^./, &:upcase)
      }
    end
    subjects.flatten.sort
  end

  def doc2locn_geometry(doc)
    return "ENVELOPE(#{@westbc}, #{@eastbc}, #{@northbc}, #{@southbc})"
  end

  def doc2dcat_bbox(doc)
    return "ENVELOPE(#{@westbc}, #{@eastbc}, #{@northbc}, #{@southbc})"
  end

  def doc2dcat_centroid(doc)
  end

  def doc2pcdm_memberOf_sm(doc)
  end

  def doc2dct_isPartOf_sm(doc)
  end

  def doc2dct_rights_sm(doc)
    # Access Constraints
    accconst = doc.xpath("//idinfo/accconst").text
    return "Public" if accconst.match /Unrestricted/i
    return "Public" if accconst.match /No restriction/i
    return "Public" if accconst.match /None/i
    return "Restricted" if accconst.match /Columbia/i
    return "Restricted" if accconst.match /Restricted/i

    # Use Constraints
    useconst = doc.xpath("//idinfo/useconst").text
    return "Public" if accconst.match /Unrestricted/i
    return "Public" if accconst.match /No restriction/i
    return "Public" if accconst.match /None/i
    return "Restricted" if accconst.match /Columbia/i
    return "Restricted" if accconst.match /Restricted/i

    # Default
    return "Restricted"
  end

  def doc2dct_license_sm(doc)
  end

  def doc2dct_accessRights_s(doc)
    return doc2dct_rights_sm(doc)
  end

  def doc2dct_format_s(doc)
    sdtstype = doc.xpath('//metadata/spdoinfo/ptvctinf/sdtsterm/sdtstype').text
    return 'Shapefile' if sdtstype.match /G-polygon/i
    return 'Shapefile' if sdtstype.match /Point/i
    return 'Shapefile' if sdtstype.match /String/i

    direct = doc.xpath('//metadata/spdoinfo/direct').text
    return 'GeoTIFF' if direct.match /Raster/i
    return 'Shapefile' if direct.match /Point/i
    return 'Shapefile' if direct.match /Vector/i

    geoform = doc.xpath("//metadata/idinfo/citation/citeinfo/geoform").text.strip
    return "GeoTIFF" if geoform.match /raster digital data/i
    return "Shapefile" if geoform.match /vector digital data/i

    formname = doc.xpath("//metadata/distinfo/stdorder/digform/digtinfo/formname").text.strip
    return "GeoTIFF" if formname.match /TIFF/i
    return "image/jpeg" if formname.match /JPEG2000/i
    return "Shapefile" if formname.match /Shape/i

    # OK, just return whatever crazy string is in the geoform/formname
    return geoform if geoform.length > 0
    return formname if formname.length > 0

    # or, if those are both empty, undetermined.
    return "UNDETERMINED"
  end

  def doc2dct_references_s(doc, fgdc_url)
    dct_references = {}

    ###   12 possible keys.  
    ###   Which ones are we able to provide?

    # Only Public content has been loaded into GeoServer.
    # Restricted content is only available via Direct Download.
    if doc2dct_rights_sm(doc) == 'Public'
      # For Columbia, only include GeoServer links for non-Raster data.
      # For all other institutions, include GeoServer links for all data.
      if (@provenance == 'Columbia' && doc2dct_format_s(doc) == 'Shapefile') ||
         (@provenance != 'Columbia')
        # Web Mapping Service (WMS) 
        dct_references['http://www.opengis.net/def/serviceType/ogc/wms'] =
            @geoserver_wms_url
        # Web Feature Service (WFS)
        dct_references['http://www.opengis.net/def/serviceType/ogc/wfs'] =
            @geoserver_wfs_url
      end
    end

    # International Image Interoperability Framework (IIIF) Image API
    # Direct download file
    if onlink = doc.at_xpath("//idinfo/citation/citeinfo/onlink")
      if onlink.text.match /.columbia.edu/
        dct_references['http://schema.org/downloadUrl'] = onlink.text.strip
      end
    end

    # This is unnecessary.  GeoBlacklight will already display FGDC XML
    # in a prettily formatted HTML panel.  And the HTML metadata isn't
    # downloadable - or anything else - in stock GeoBlacklight.
    # None of the OpenGeoBlacklight institutions bother with this.
    # # Full layer description
    # # Metadata in HTML
    # die "No APP_CONFIG['display_urls']['html']" unless APP_CONFIG['display_urls']['html']
    # dct_references['http://www.w3.org/1999/xhtml'] =
    #     APP_CONFIG['display_urls']['html'] + "/#{@key}.html"

    # # Metadata in ISO 19139
    # dct_references['http://www.isotc211.org/schemas/2005/gmd/'] =
    #     APP_CONFIG['display_urls']['iso19139'] + "/#{@key}.xml"
    # Metadata in FGDC
    dct_references['http://www.opengis.net/cat/csw/csdgm'] = fgdc_url
    # Metadata in MODS
    # ArcGIS FeatureLayer
    # ArcGIS TiledMapLayer
    # ArcGIS DynamicMapLayer
    # ArcGIS ImageMapLayer

    return dct_references.compact.to_json.to_s
  end

  # Purpose: To identify the layer or store for a WFS, WMS, or WCS web service so the application can construct the full web service link.
  # Entry Guidelines: Only the layer name is added here. The base service endpoint URLs (e.g. "https://maps-public.geo.nyu.edu/geoserver/sdr/wms") are added to the References field.
  # Commentary: This value is only used when a WxS service is listed in the References field. The WxS Identifer is used to point to specific layers within an OGC geospatial web service. This field is not used for ArcGIS Rest Services.
  def doc2gbl_wxsIdentifier_s(doc)
    return "#{@wxs_prefix}#{@key}".html_safe
    
    # case @provenance
    # when 'Columbia'
    #   "sde:columbia.#{@key}".html_safe
    # when 'Harvard'
    #   @key.html_safe
    # when 'Tufts'
    #   "sde:GISPORTAL.GISOWNER01.#{@key.upcase}"
    # else
    #   raise "ERROR:  doc2layer_id() got unknown provenance " + @provenance
    # end
  end
  
  # Purpose: To provide a unique alpha-numeric ID for the item that will act as the primary key in Solr and to create a unique landing page for the item.
  # Entry Guidelines: Enter a string of alpha-numeric characters separated by dashes. The ID must be globally unique across all institutions in your GeoBlacklight index.
  # Commentary: This field makes up the URL for the resource in GeoBlacklight. It is visible to the user and is used to create permalinks. If having a readable slug is desired, it is common to use the form institution-keyword1-keyword2.
  def doc2id(doc)
    identifier = "#{@provenance}-#{@key}".downcase
    identifier.gsub!(/[^A-Za-z0-9]/, '-')
    return identifier
  end

  # Purpose: To provide a general purpose field for identifiers.
  # Entry Guidelines: Enter a DOI, catalog number, and/or other system number.
  # Commentary: This is a general purpose field that can contain one or more string values. Ideally, at least one value would be a persistent identifier or permalink (such as a PURL or Handle). Additional values could be other identifiers used by the resource, such as the call number, OCLC number, or other system identifier. This field is not displayed in the interface.
  def doc2dct_identifier_sm(doc)
    identifier = "#{@provenance}.#{@key}"
    # We'd begun with a more complex identifier locally.
    identifier = "urn:columbia.edu:#{identifier}" if @provenance == 'Columbia'
    return identifier
  end

  def doc2gbl_mdModified_dt(doc)
    if d = doc.at_xpath("//metainfo/metd")
      year, month, day = d.text[0..3], d.text[4..5], d.text[6..7]
      "#{year}-#{month}-#{day}T00:00:00Z"
    end
  end

  def doc2gbl_mdVersion_s(doc)
    "Aardvark"
  end


end



