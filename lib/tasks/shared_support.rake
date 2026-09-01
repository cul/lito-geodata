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

#  Old Code - only accepted ENVELOPE
# # Is the passed geometry valid?
# def valid_geometry?(locn_geometry)
#   return false unless locn_geometry.present?
#
#   # :solr_geom  => "ENVELOPE(#{w}, #{e}, #{n}, #{s})",
#   # Solr docs say:   "minX, maxX, maxY, minY order"
#   # maximum boundary: (minX=-180.0,maxX=180.0,minY=-90.0,maxY=90.0)
#   match = locn_geometry.match(/ENVELOPE\(([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)\)/)
#
#   # Not parsable ENVELOPE() syntax?
#   return false unless match.present?
#
#   minX, maxX, maxY, minY = match.captures
#   return false if minX.to_f < -180 ||
#                   maxX.to_f >  180 ||
#                   maxY.to_f >   90 ||
#                   minY.to_f <  -90
#
#   return true
# end

#  New Code - accepts ENVELOPE or POLYGON
def valid_geometry?(locn_geometry)
  # return false unless locn_geometry.present?
  # if there's no coordinates in the Aardvark, load anyway, it's still useful 
  return true if locn_geometry.blank?

  case locn_geometry
  when /\AENVELOPE\(/i
    valid_envelope?(locn_geometry)
  when /\APOLYGON\s*\(/i
    valid_polygon?(locn_geometry)
  else
    false
  end
end

# :solr_geom  => "ENVELOPE(#{w}, #{e}, #{n}, #{s})",
# Solr docs say:   "minX, maxX, maxY, minY order"
# maximum boundary: (minX=-180.0,maxX=180.0,minY=-90.0,maxY=90.0)
def valid_envelope?(locn_geometry)
  match = locn_geometry.match(/ENVELOPE\(([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)[\ \,]*([\d\.\-]+)\)/)

  # Not parsable ENVELOPE() syntax?
  return false unless match.present?

  minX, maxX, maxY, minY = match.captures
  in_lon_lat_bounds?(minX:, maxX:, maxY:, minY:)
end

# e.g. POLYGON((-141.2 70.6, -50.5 70.6, -50.5 23.4, -141.2 23.4, -141.2 70.6))
# Rather than parse ring topology, just pull every "x y" vertex pair out
# and confirm each one is a plausible lon/lat coordinate.
def valid_polygon?(locn_geometry)
  vertices = locn_geometry.scan(/(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)/)

  # Not parsable POLYGON(...) syntax?
  return false if vertices.empty?

  vertices.all? { |x, y| x.to_f.between?(-180, 180) && y.to_f.between?(-90, 90) }
end

def in_lon_lat_bounds?(minX:, maxX:, maxY:, minY:)
  minX.to_f >= -180 &&
    maxX.to_f <= 180 &&
    maxY.to_f <= 90 &&
    minY.to_f >= -90
end



