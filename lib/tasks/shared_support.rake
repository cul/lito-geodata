# Shared support code for rake tasks under lib/tasks/. Nothing in this
# file is used outside of a rake invocation - it's loaded automatically
# alongside every other *.rake file, so no explicit require is needed
# from individual task files.

def puts_datestamp(msg)
  puts "#{Time.now}   #{msg}"
end

# Solr URLs may carry HTTP basic auth credentials embedded as
# https://user:password@host:port/solr/core - strip those before ever
# putting a Solr URL in log output, while keeping the rest of the URL
# (host, port, core path) visible for debugging.
def redact_solr_credentials(url)
  uri = URI.parse(url)
  return url unless uri.user || uri.password

  uri.user = nil
  uri.password = nil
  uri.to_s
rescue URI::InvalidURIError
  '[unparsable Solr URL, not logging it]'
end

# Is the passed geometry valid?
def valid_geometry?(locn_geometry)
  return false unless locn_geometry.present?

  # :solr_geom  => "ENVELOPE(#{w}, #{e}, #{n}, #{s})",
  # Solr docs say:   "minX, maxX, maxY, minY order"
  # maximum boundary: (minX=-180.0,maxX=180.0,minY=-90.0,maxY=90.0)
  match = locn_geometry.match(/ENVELOPE\(([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)\)/)

  # Not parsable ENVELOPE() syntax?
  return false unless match.present?

  minX, maxX, maxY, minY = match.captures
  return false if minX.to_f < -180 ||
                  maxX.to_f >  180 ||
                  maxY.to_f >   90 ||
                  minY.to_f <  -90

  return true
end
