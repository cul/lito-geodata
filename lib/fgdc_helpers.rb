module FgdcHelpers
  
  def set_variables(repo, nokogiri_doc)
    # fetch repo-specific configuration variables
    fgdc_mapping_constants = APP_CONFIG['fgdc_mapping_constants']
    abort "Missing fgdc_mapping_constants from app_config!" unless fgdc_mapping_constants.present?
    repo_config = fgdc_mapping_constants[repo]
    abort "Missing fgdc mapping details for repo #{repo} in app_config!" unless repo_config.present?

    @provenance         =  repo_config['provenance']
    @geoserver_wms_url  =  repo_config['geoserver_wms_url']
    @geoserver_wfs_url  =  repo_config['geoserver_wfs_url']
    @key_xpath          =  repo_config['key_xpath']
    @wxs_prefix         =  repo_config['wxs_prefix']
    
    # the unique key for this metadata record
    key = nokogiri_doc.xpath(@key_xpath)
    key = key.text if key.class == Nokogiri::XML::NodeSet
    @key = key.to_s.strip

    # bounding coordinates
    @northbc = nokogiri_doc.xpath("//idinfo/spdom/bounding/northbc").text.to_f
    @southbc = nokogiri_doc.xpath("//idinfo/spdom/bounding/southbc").text.to_f
    @eastbc = nokogiri_doc.xpath("//idinfo/spdom/bounding/eastbc").text.to_f
    @westbc = nokogiri_doc.xpath("//idinfo/spdom/bounding/westbc").text.to_f
  end

end
