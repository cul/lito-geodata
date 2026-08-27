
# Rake tasks for ingesting other institution's layers
# from https://github.com/OpenGeoMetadata

# Other institutions make their data available in various formats:
# - FGDC
# - GeoBlacklight Schema
# - Aardvark Schema
# The FGDC and GeoBlacklight metadata needs to be mapped to Aardvark for ingest.
#
# Shared helpers (valid_geometry?, puts_datestamp, redact_solr_credentials)
# live in lib/tasks/shared_support.rake, not in this file.
#
# transform_fgdc is the only remaining consumer of the FGDC->Aardvark
# conversion logic (Columbia's own collection is Aardvark-native now,
# via ingest.rake) - required explicitly here since it's no longer
# incidentally loaded by ingest.rake the way it was in GB4.
require 'find'

require 'fgdc2aardvark'
include Fgdc2aardvark

require 'fgdc_helpers'
include FgdcHelpers

namespace :opengeometadata do
  commit_within = (ENV['SOLR_COMMIT_WITHIN'] || 5000).to_i
  ogm_path = ENV['OGM_PATH'] || 'public/opengeometadata'
  metadata_server = APP_CONFIG['metadata_server'] || abort('metadata_server undefined!')

  fgdc_repos     = (APP_CONFIG['opengeometadata_fgdc_repos'] || []).sort
  geobl_repos    = (APP_CONFIG['opengeometadata_geobl_repos'] || []).sort
  aardvark_repos = (APP_CONFIG['opengeometadata_aardvark_repos'] || []).sort
  all_repos = (fgdc_repos + geobl_repos + aardvark_repos).sort

  # ---------------------------------------------------------------------- #
  desc "Download OpenGeoMetadata for all configured institutions"
  task :fetch_all => :environment do
    puts_datestamp "---- metadata:fetch_all ----"

    all_repos.each do |repo|
      printf("-- Updating %s --\n", repo)
      Rake::Task["opengeometadata:fetch"].reenable
      Rake::Task["opengeometadata:fetch"].invoke(repo)
    end

  end


  desc 'Fetch a single OpenGeoMetadata repo (create or update)'
  task :fetch, [:repo] => :environment do |t, args|
    unless repo = args[:repo]
      puts "Must pass input arg :repo (e.g.: rake opengeometadata:fetch[edu.nyu])"
      next
    end
    github = "https://github.com/OpenGeoMetadata/#{repo}.git"

    FileUtils.mkdir_p(ogm_path)

    if Dir.exist?("#{ogm_path}/#{repo}")
      puts "Pulling #{repo}"
      system "cd #{ogm_path}/#{repo} && git pull origin"
    else
      puts "Cloning #{repo}"
      system "cd #{ogm_path} && git clone --depth 1 #{github}"
    end
  end

# ---------------------------------------------------------------------- #

  desc "Transform OpenGeoMetadata FGDC to GeoBL for some institutions"
  task :transform_all=> :environment do
    puts_datestamp "---- metadata:transform_all ----"

    fgdc_repos = APP_CONFIG['opengeometadata_fgdc_repos'] || []
    fgdc_repos.each do |repo|
      printf("-- Transforming FGDC XML from %s --\n", repo)
      Rake::Task["opengeometadata:transform_fgdc"].reenable
      Rake::Task["opengeometadata:transform_fgdc"].invoke(repo)
    end

    geobl_repos = APP_CONFIG['opengeometadata_geobl_repos'] || []
    geobl_repos.each do |repo|
      printf("-- Transforming GeoBl JSON from %s --\n", repo)
      Rake::Task["opengeometadata:transform"].reenable
      Rake::Task["opengeometadata:transform"].invoke(repo)
    end

  end


  # Some OpenGeoMetadata repos provide FGDC, not GeoBlacklight JSON
  desc "Transform OpenGeoMetadata FGDC XML to GeoBlacklight Schema JSON"
  task :transform_fgdc, [:repo] => :environment do |t, args|
    unless repo = args[:repo]
      puts "Must pass input arg :repo (e.g.: rake opengeometadata:transform_fgdc[edu.tufts])"
      next
    end

    unless Dir.exist?("#{ogm_path}/#{repo}")
      puts "ERROR: Cannot not find directory #{ogm_path}/#{repo}"
      next
    end

    puts "Begining transform..."
    transformed = 0
    Find.find("#{ogm_path}/#{repo}") do |fgdc_file|

      # Different institutions use different naming conventions,
      # but hopefully any XML files found will be FGDC XML.
      # next unless File.basename(fgdc_file) == 'fgdc.xml'
      next unless File.basename(fgdc_file).match?(/.xml$/)

      # fgdc_file should be the full path to an FGDC XML file.
      # What should the aardvark JSON filename be?
      # + Replace  .../123/456/fgdc.xml   with   .../123/456/aardvark.json
      # + Replace  .../fgdc/abc.xml       with   .../aardvark/abc.json
      fgdc_dirname = File.dirname(fgdc_file)
      fgdc_basename = File.basename(fgdc_file)

      aardvark_dirname = fgdc_dirname.sub(/fgdc/, 'aardvark')
      FileUtils.mkdir_p(aardvark_dirname) unless Dir.exist?(aardvark_dirname)
      aardvark_basename = fgdc_basename.sub(/fgdc/, 'aardvark').sub(/.xml/, '.json')

      aardvark_file = "#{aardvark_dirname}/#{aardvark_basename}"

      # e.g.:  /blah/blah/blah/public/opengeometadata/edu.tufts/192/125/94/208/fgdc.xml
      # We need to turn this into:
      # https://geoblah.columbia.edu/opengeometadata/edu.tufts/192/125/94/208/fgdc.xml
      fgdc_url = metadata_server + fgdc_file.gsub(/.*opengeometadata/, '/opengeometadata')

      begin
        # The GeoBlacklight schema file will be the same basename, but json
        fgdc_xml = File.read(fgdc_file)
        nokogiri_doc  = Nokogiri::XML(fgdc_xml) do |config|
          config.strict.nonet
        end
        # Parse doc to set @key, etc.
        set_variables(repo, nokogiri_doc)

        # Need the original funky XML filename, as well as the nokogiri doc
        aardvark_json = fgdc2aardvark(fgdc_url, nokogiri_doc)

        File.write(aardvark_file, aardvark_json + "\n")
        transformed = transformed + 1
      rescue => ex
        puts "ERROR: #{fgdc_file}: " + ex.message
        # puts "  " + ex.backtrace.select{ |x| x.match(/#{Rails.root}/) }.first
      end
    end
    puts "Transformed #{transformed} files."
  end
# ---------------------------------------------------------------------- #



  desc "Ingest OpenGeoMetadata for all configured institutions"
  task :ingest_all=> :environment do
    puts_datestamp "---- metadata:ingest_all ----"
    all_repos.each do |repo|
      printf("-- Ingesting %s --\n", repo)
      Rake::Task["opengeometadata:ingest"].reenable
      Rake::Task["opengeometadata:ingest"].invoke(repo)
    end
  end

  desc 'Ingest a single OpenGeoMetadata repo'
  task :ingest, [:repo] => :environment do |t, args|
    unless repo = args[:repo]
      puts "Must pass input arg :repo (e.g.: rake opengeometadata:ingest[edu.nyu])"
      next
    end

    puts "Ingesting #{repo}"
    unless Dir.exist?("#{ogm_path}/#{repo}")
      puts "ERROR: Cannot not find directory #{ogm_path}/#{repo}"
      next
    end

    solr_url = Blacklight.connection_config[:url]
    puts "Connecting to Solr (#{redact_solr_credentials(solr_url)})..."
    solr = RSolr.connect url: solr_url
    puts "solr=#{solr}"

    puts "local repo path:  #{ogm_path}/#{repo}"

    found = 0
    restricted = 0
    ingested = 0
    Find.find("#{ogm_path}/#{repo}") do |path|
      # Support either:   .../123/456/aardvark.json   or:   .../aardvark/ABCDE.json
      next unless (File.basename(path) == 'aardvark.json') or (path.match?(/aardvark.*json/))

      found = found + 1
      begin
        doc = JSON.parse(File.read(path))
      rescue JSON::ParserError
        puts "ERROR: JSON::ParserError reading #{path}"
        next
      end
      [doc].flatten.each do |record|
        begin
          # GEO-26 - Suppress restricted layers. NOTE: this check is
          # specific to OTHER institutions' redistribution-rights
          # concerns - it intentionally does NOT apply to Columbia's own
          # collection (see ingest.rake's header note).
          if (record['dct_rights_sm'] == 'Restricted') or
             (record['dct_accessRights_s'] == 'Restricted')
            restricted = restricted + 1
            next
          end

          # Skip out-of-bounds ENVELOPE() data
          if not valid_geometry?(record['locn_geometry'])
            puts "ERROR: layer id #{record['gbl_wxsIdentifier_s']} locn_geometry data NOT valid:  #{record['locn_geometry']}"
            next
          end

          puts "Indexing #{record['id']}: #{path}" if ENV['DEBUG']
          solr.update params: { commitWithin: commit_within, overwrite: true },
                      data: [record].to_json,
                      headers: { 'Content-Type' => 'application/json' }
          ingested = ingested + 1
        rescue RSolr::Error::Http => error
          puts error
        end
      end
    end
    puts "Found #{found} layers total, #{restricted} restricted, ingested #{ingested}."
    solr.commit
  end

# ---------------------------------------------------------------------- #

  desc "Prune stale OpenGeoMetadata records for all configured institutions"
  task :prune_all=> :environment do
    puts_datestamp "---- metadata:prune_all ----"
    all_repos.each do |repo|
      printf("-- Pruning %s\n", repo)
      Rake::Task["opengeometadata:prune"].reenable
      Rake::Task["opengeometadata:prune"].invoke(repo)

      puts "Optimizing..."
      begin
        solr = RSolr.connect url: Blacklight.connection_config[:url]
        solr.optimize
      rescue RSolr::Error::Http, Faraday::TimeoutError, Net::ReadTimeout
        # no-op
      end
      puts "Done."
    end
  end


  desc "Delete stale records from the Solr search index"
  task :prune, [:repo] => :environment do |t, args|
    unless repo = args[:repo]
      puts "Must pass input arg :repo (e.g.: rake opengeometadata:prune[edu.nyu])"
      next
    end

    puts "Pruning stale records for #{repo}..."

    solr_url = Blacklight.connection_config[:url]
    puts "Connecting to Solr (#{redact_solr_credentials(solr_url)})..."
    solr = RSolr.connect url: solr_url
    puts "solr=#{solr}"

    providers = getRepoProviders(repo)

    Array(providers).each do |provider|
      stale = (ENV['STALE_DAYS'] || 21).to_i
      # query = "timestamp:[* TO NOW/DAY-#{stale}DAYS] AND schema_provider_s:\"#{provider}\""
      query = "timestamp:[* TO NOW-#{stale}DAY] AND schema_provider_s:\"#{provider}\""

      puts "Pruning #{provider}..."
      puts "(#{query})"
      solr.delete_by_query query
    end

    puts "Committing..."
    solr.commit
    # Optimize during prune_all, not after each institution.
    # puts "Optimizing..."
    # begin
    #   solr.optimize
    # rescue Net::ReadTimeout
    #   # Not a problem really - we kicked off an optimization,
    #   # it'll take a while to complete.
    #   puts "-- lost server connectivity during optimization"
    # rescue => ex
    #   puts "Error during optimization: " + ex.message + "(#{ex.class})"
    # end
    puts "Done."
  end

  desc "Download, Ingest, and Prune OpenGeoMetadata for all institutions"
  task :process => :environment do
    startTime = Time.now
    puts_datestamp "==== START opengeometadata:process ===="

    Rake::Task["opengeometadata:fetch_all"].invoke
    Rake::Task["opengeometadata:transform_all"].invoke
    Rake::Task["opengeometadata:ingest_all"].invoke
    Rake::Task["opengeometadata:prune_all"].invoke

    elapsed_seconds = (Time.now - startTime).round
    min, sec = elapsed_seconds.divmod(60)
    elapsed_note = "(#{min} min, #{sec} sec)"
    puts_datestamp "==== END metadata:process #{elapsed_note} ===="
  end

end


# A given repo (e.g., NYU) may contain metadata records from
# multiple provenances (e.g., [ "NYU", "Baruch CUNY"]).
# We'll hard-code this mapping for now, but we should really
# extract possible provenance values from the supplied data.
#
def getRepoProviders(repo)
  case repo
  when 'geobtaa'
    # The "Big Ten" is an alliance of 14 [sic] institutions.
    # Only 9 of them contribute records to OpenGeoMetadata currently.
    [ 'Illinois', 'Indiana', 'Iowa', 'Maryland', 'Michigan',
      'Michigan State', 'Minnesota', 'Purdue', 'Wisconsin' ]
  when 'edu.berkeley'
    return 'Berkeley'
  when 'edu.cornell'
    return 'Cornell'
  when 'edu.harvard'
    return 'Harvard'
  when 'edu.mit'
    return 'MIT'
  when 'edu.nyu'
    return [ 'NYU', 'Baruch CUNY' ]
  when 'edu.princeton.arks'
    return 'Princeton'
  when 'edu.stanford.purl'
    return 'Stanford'
  when 'edu.tufts'
    return 'Tufts'
  when 'edu.virginia'
    return 'UVa'
  else
    raise "ERROR:  Unknown provider value for repo #{repo}"
  end
end
