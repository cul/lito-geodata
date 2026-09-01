# Makes items whose cataloged dct_format_s is "GeoPackage" (not just
# "Shapefile") eligible for the generated vector download dropdown -
# Shapefile/KMZ/GeoJSON/CSV - when they have valid wms+wfs references.
#
# GeoBlacklight's own Geoblacklight::References#downloads_by_format is a
# closed case statement that only recognizes "Shapefile"/"GeoTIFF"/
# "ArcGRID" - most of our catalog is cataloged as "GeoPackage" and was
# being routed nowhere, even when fully GeoServer-backed. We prepend a
# module to add that one case and fall through (via `super`) to the
# gem's own behavior for everything else.
#
# NOTE: this intentionally does NOT add "Geopackage" to
# config/settings.yml's DOWNLOAD_FORMATS.VECTOR list, and does NOT
# override web_service_hash - that's what actually exposes an "Export
# Geopackage" option, which requires GeoServer's GeoPackage Output
# extension (not yet installed on our GeoServer as of 2026-08-31). Once
# that's in place, see git history / chat log for the additional
# pieces: the DOWNLOAD_FORMATS.VECTOR entry, the web_service_hash
# override, lib/geoblacklight/geopackage_download.rb, and
# app/controllers/download_controller.rb.
module GeodataDownloadFormats
  def downloads_by_format
    return vector_download_formats if format == "GeoPackage"

    super
  end
end

Rails.application.config.to_prepare do
  Geoblacklight::References.prepend(GeodataDownloadFormats)
end