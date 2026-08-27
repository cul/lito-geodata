# Rake tasks to build a GeoBlacklight 5 Solr instance directly from
# Aardvark JSON metadata.
#
# Columbia's spatial metadata is now maintained natively in Aardvark
# (no more FGDC XML source). The librarian publishes one JSON file per
# record, packaged as a single zip:
#   http://www.columbia.edu/acis/eds/gis/images/aardvarkmetadata.zip
#
# This replaces the old FGDC -> Aardvark transform pipeline entirely.
# fgdc2aardvark.rb / fgdc_helpers.rb are no longer required here; they
# remain in the codebase only as an archival reference for how the old
# FGDC-sourced records used to be converted.
#
# NOTE ON ACCESS RIGHTS: records in this zip may carry
# dct_accessRights_s == "restricted". Unlike opengeometadata.rake's
# ingest task (which suppresses restricted records from OTHER
# institutions for redistribution-rights reasons), this task does NOT
# suppress restricted Columbia records from the index. GeoBlacklight's
# normal pattern is to index restricted records and gate access
# (view/download) at the application layer via CAS auth. Per-record
# visibility should instead be controlled via gbl_suppressed_b, which
# is respected elsewhere in the GBL5 app config, not by this task.
# If this assumption is wrong, add a guard here before indexing.
#
# Shared helpers (valid_geometry?, puts_datestamp) live in
# lib/tasks/shared_support.rake, not in this file.

require 'open-uri'

tmpdir = '/tmp'

aardvark_current = File.join(Rails.root, "public/metadata/aardvark/current/")
aardvark_old      = File.join(Rails.root, "public/metadata/aardvark/old/")
zip_filename      = 'aardvarkmetadata.zip'

namespace :metadata do

  desc "Download the Aardvark metadata zip"
  task :download => :environment do
    aardvark_metadata_url = APP_CONFIG['aardvark_metadata_url'] ||
                             abort('aardvark_metadata_url undefined! Set it in config/app_config.yml')

    begin
      puts "Downloading #{aardvark_metadata_url}..."
      download = URI.open(aardvark_metadata_url)
      IO.copy_stream(download, "#{tmpdir}/#{zip_filename}")
      puts "Download successful."
    rescue => ex
      puts "Download unsuccessful: #{ex}"
      next
    end

    # Sanity-check the new download isn't wildly different in size from
    # the last one, same guard rail as the old FGDC download task had.
    previous_zip = "#{aardvark_current}#{zip_filename}"
    if File.exist?(previous_zip)
      old_file_size = File.size(previous_zip)
      new_file_size = File.size("#{tmpdir}/#{zip_filename}")
      diff = (new_file_size - old_file_size).to_f
      delta = old_file_size.zero? ? 0 : ((diff / old_file_size) * 100).to_i
      puts "New metadata zip size is #{delta}% change from previous download."

      threshold = (ENV['AARDVARK_DIFF'] || 10).to_i
      if delta.abs > threshold
        puts "ERROR: percentage difference (#{delta}%) greater than limit (#{threshold}%)"
        puts "Use environment variable $AARDVARK_DIFF to override diff percentage threshold."
        abort "Aborting."
      end
    end

    puts "Moving #{zip_filename} into #{aardvark_current}..."
    FileUtils.rm_rf(aardvark_old)
    FileUtils.mv(aardvark_current, aardvark_old) if File.exist?(aardvark_current)
    FileUtils.mkdir_p(aardvark_current)
    FileUtils.mv("#{tmpdir}/#{zip_filename}", "#{aardvark_current}#{zip_filename}")

    puts "Unzipping #{zip_filename}..."
    if system("unzip -q -o #{aardvark_current}#{zip_filename} -d #{aardvark_current}")
      puts "Unzip successful."
    else
      puts "Unzip unsuccessful."
      next
    end
  end

  desc "Ingest the Aardvark JSON records into Solr"
  task :ingest, [:file_pattern] => :environment do |t, args|
    file_pattern = args[:file_pattern] || "."
    solr_url = Blacklight.connection_config[:url]

    # AARDVARK_DIR lets you point ingest at an already-downloaded local
    # directory of *.json records, bypassing metadata:download entirely.
    # Handy for local dev work against a shared server Solr/DB, e.g.:
    #   AARDVARK_DIR=~/Downloads/aa rake metadata:ingest
    # Defaults to the normal download/unzip target used by metadata:process.
    source_dir = File.expand_path(ENV['AARDVARK_DIR'] || aardvark_current)
    source_dir += '/' unless source_dir.end_with?('/')

    unless Dir.exist?(source_dir)
      abort "ERROR: source directory does not exist: #{source_dir}"
    end

    puts "Connecting to Solr (#{redact_solr_credentials(solr_url)})..."
    solr = RSolr.connect url: solr_url
    puts "solr=#{solr}"

    note = " of files matching /#{file_pattern}/" if file_pattern != '.'
    puts "Beginning ingest#{note} from #{source_dir}..."

    ingested = 0
    skipped  = 0

    Dir.glob("#{source_dir}*.json").each { |aardvark_file|
      next unless aardvark_file =~ /#{file_pattern}/

      label = File.basename(aardvark_file)
      puts " - #{label}" if file_pattern != '.'

      begin
        record = JSON.parse(File.read(aardvark_file))

        record['dct_references_s'] = normalize_dct_references(record['dct_references_s'])

        unless valid_geometry?(record['locn_geometry'])
          puts "ERROR: #{label} locn_geometry NOT valid: #{record['locn_geometry']}"
          skipped += 1
          next
        end

        solr.update params: { commitWithin: 500, overwrite: true },
                    data: [record].to_json,
                    headers: { 'Content-Type' => 'application/json' }
        ingested += 1
      rescue JSON::ParserError => ex
        puts "ERROR: #{label} is not valid JSON: " + ex.message
        skipped += 1
      rescue => ex
        puts "ERROR: ingesting #{label}: " + ex.message
        puts "  " + ex.backtrace.select { |x| x.match(/#{Rails.root}/) }.first.to_s
        skipped += 1
      end
    }

    puts "Ingested #{ingested} records, skipped #{skipped}."

    puts "Committing..."
    solr.commit
    puts "Done."
  end

  desc "Delete stale records from the Solr search index"
  task :prune_index => :environment do
    solr_url = Blacklight.connection_config[:url]
    puts "Connecting to Solr (#{redact_solr_credentials(solr_url)})..."
    solr = RSolr.connect url: solr_url
    puts "solr=#{solr}"

    if ENV['STALE_DAYS'] && ENV['STALE_DAYS'].to_i < 2
      puts "ERROR: Environment variable STALE_DAYS set to [#{ENV['STALE_DAYS']}]"
      puts "ERROR: Should be > 1, or unset to allow default setting."
      puts "ERROR: Skipping prune_index step."
      next
    end

    stale = (ENV['STALE_DAYS'] || 21).to_i
    query = "timestamp:[* TO NOW/DAY-#{stale}DAYS] AND schema_provider_s:Columbia"

    puts "Pruning..."
    puts "(#{query})"
    solr.delete_by_query query

    puts "Committing..."
    solr.commit
    puts "Optimizing..."
    begin
      solr.optimize
    rescue RSolr::Error::Http, Faraday::TimeoutError, Net::ReadTimeout
      # no-op
    end
    puts "Done."
  end

  desc "Download and Ingest Metadata"
  task :process => :environment do
    startTime = Time.now
    puts_datestamp "==== START metadata:process ===="

    puts_datestamp "---- metadata:download ----"
    Rake::Task['metadata:download'].execute

    puts_datestamp "---- metadata:ingest ----"
    Rake::Task['metadata:ingest'].execute

    puts_datestamp "---- metadata:prune_index ----"
    Rake::Task['metadata:prune_index'].execute

    elapsed_seconds = (Time.now - startTime).round
    min, sec = elapsed_seconds.divmod(60)
    elapsed_note = "(#{min} min, #{sec} sec)"
    puts_datestamp "==== END metadata:process #{elapsed_note} ===="
  end

end

# Aardvark's canonical dct_references_s shape is a JSON-encoded string
# whose values (including downloadUrl) are plain URL strings, e.g.:
#   {"http://schema.org/downloadUrl": "https://.../file.zip"}
#
# Some records may instead supply downloadUrl as an array of
# {"url": ..., "label": ...} hashes (to support multiple download
# formats/options). Solr's dct_references_s field is a single string
# field, so it always needs to hold a JSON-encoded string either way -
# this just normalizes the downloadUrl value inside that JSON to a
# single plain string, taking the first entry if given an array.
#
# If a record legitimately has multiple download options, taking only
# the first one here is a simplification. Revisit if/when the app UI
# needs to expose multiple download links per record.
def normalize_dct_references(value)
  return value unless value.present?

  parsed = value.is_a?(String) ? JSON.parse(value) : value
  key = 'http://schema.org/downloadUrl'

  if parsed[key].is_a?(Array)
    first = parsed[key].first
    normalized_url = first.is_a?(Hash) ? (first['url'] || first[:url]) : first
    puts "NOTE: #{key} was an array with #{parsed[key].size} entries; using first (#{normalized_url})" if parsed[key].size > 1
    parsed[key] = normalized_url
  end

  parsed.to_json
rescue JSON::ParserError => ex
  puts "WARNING: could not parse dct_references_s, leaving as-is: #{ex.message}"
  value
end
