// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"
import githubAutoCompleteElement from "@github/auto-complete-element"
import Blacklight from "blacklight"
import Geoblacklight from "geoblacklight";

// Override GBL5's default leaflet-viewer controller to append a Carto
// basemap API key. Carto's Positron/darkMatter/etc basemaps now require
// one; OSM-based basemaps are untouched since they don't need it.
// See: https://carto.com/basemaps/apikey/
//
// The key itself is set as window.cartoApiKey by an inline <script> in
// app/views/shared/_header_navbar.html.erb, not a meta tag - see that
// file's comments for why.
import { tileLayer } from "leaflet";
import LeafletViewerController from "geoblacklight/controllers/leaflet_viewer_controller";
import leafletBasemaps from "geoblacklight/leaflet/basemaps";

const CARTO_BASEMAPS = [
  "positron", "darkMatter", "positronLite",
  "worldAntique", "worldEco", "flatBlue", "midnightCommander",
];

class GeodataLeafletViewerController extends LeafletViewerController {
  getBasemap() {
    const basemapName = this.basemapValue || "positron";
    const { url: baseUrl, ...basemapOptions } = leafletBasemaps[basemapName];

    let url = baseUrl;
    if (window.cartoApiKey && CARTO_BASEMAPS.includes(basemapName)) {
      url += (url.includes("?") ? "&" : "?") + "key=" + window.cartoApiKey;
    }

    return tileLayer(url, basemapOptions);
  }
}

Stimulus.register("leaflet-viewer", GeodataLeafletViewerController);


