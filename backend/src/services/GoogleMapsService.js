/**
 * GoogleMapsService
 * Wrapper for Google Maps API - geocoding, directions, distance matrix, autocomplete.
 */

const { Client } = require('@googlemaps/google-maps-services-js');
const config = require('../config');
const logger = require('../utils/logger');

class GoogleMapsService {
  constructor() {
    this.client = new Client();
    this.apiKey = config.googleMaps.apiKey;
  }

  /**
   * Geocode an address to lat/lng
   */
  async geocode(address) {
    try {
      const response = await this.client.geocode({
        params: {
          address,
          key: this.apiKey,
          region: 'in',
        },
      });

      if (response.data.status !== 'OK' || response.data.results.length === 0) {
        throw new Error(`Geocode failed: ${response.data.status}`);
      }

      const result = response.data.results[0];
      return {
        latitude: result.geometry.location.lat,
        longitude: result.geometry.location.lng,
        formatted_address: result.formatted_address,
        place_id: result.place_id,
        address_components: result.address_components,
      };
    } catch (error) {
      logger.error('Geocode error:', error.message);
      throw error;
    }
  }

  /**
   * Reverse geocode lat/lng to address
   */
  async reverseGeocode(lat, lng) {
    try {
      const response = await this.client.reverseGeocode({
        params: {
          latlng: { lat, lng },
          key: this.apiKey,
          region: 'in',
        },
      });

      if (response.data.status !== 'OK' || response.data.results.length === 0) {
        throw new Error(`Reverse geocode failed: ${response.data.status}`);
      }

      const result = response.data.results[0];
      return {
        formatted_address: result.formatted_address,
        place_id: result.place_id,
        address_components: result.address_components,
      };
    } catch (error) {
      logger.error('Reverse geocode error:', error.message);
      throw error;
    }
  }

  /**
   * Get route/directions between two points
   */
  async getDirections(originLat, originLng, destLat, destLng) {
    try {
      const response = await this.client.directions({
        params: {
          origin: { lat: originLat, lng: originLng },
          destination: { lat: destLat, lng: destLng },
          mode: 'driving',
          key: this.apiKey,
          region: 'in',
          alternatives: false,
        },
      });

      if (response.data.status !== 'OK' || response.data.routes.length === 0) {
        throw new Error(`Directions failed: ${response.data.status}`);
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];

      return {
        distance_meters: leg.distance.value,
        distance_text: leg.distance.text,
        duration_seconds: leg.duration.value,
        duration_text: leg.duration.text,
        polyline: route.overview_polyline?.points || '',
        start_address: leg.start_address,
        end_address: leg.end_address,
        steps: leg.steps.map((step) => ({
          instruction: step.html_instructions,
          distance: step.distance.text,
          duration: step.duration.text,
          polyline: step.polyline?.points,
        })),
      };
    } catch (error) {
      logger.error('Directions error:', error.message);
      throw error;
    }
  }

  /**
   * Get distance matrix for multiple origins/destinations
   */
  async getDistanceMatrix(origins, destinations) {
    try {
      const response = await this.client.distancematrix({
        params: {
          origins: origins.map((o) => ({ lat: o.lat, lng: o.lng })),
          destinations: destinations.map((d) => ({ lat: d.lat, lng: d.lng })),
          mode: 'driving',
          key: this.apiKey,
          region: 'in',
        },
      });

      if (response.data.status !== 'OK') {
        throw new Error(`Distance matrix failed: ${response.data.status}`);
      }

      return response.data.rows.map((row) =>
        row.elements.map((element) => ({
          status: element.status,
          distance_meters: element.distance?.value,
          distance_text: element.distance?.text,
          duration_seconds: element.duration?.value,
          duration_text: element.duration?.text,
        }))
      );
    } catch (error) {
      logger.error('Distance matrix error:', error.message);
      throw error;
    }
  }

  /**
   * Place autocomplete for search
   */
  async placeAutocomplete(input, location = null, radius = 50000) {
    try {
      const params = {
        input,
        key: this.apiKey,
        components: ['country:in'],
        language: 'en',
      };

      if (location) {
        params.location = { lat: location.lat, lng: location.lng };
        params.radius = radius;
      }

      const response = await this.client.placeAutocomplete({ params });

      if (response.data.status !== 'OK') {
        throw new Error(`Place autocomplete failed: ${response.data.status}`);
      }

      return response.data.predictions.map((prediction) => ({
        place_id: prediction.place_id,
        description: prediction.description,
        main_text: prediction.structured_formatting?.main_text || '',
        secondary_text: prediction.structured_formatting?.secondary_text || '',
        types: prediction.types,
      }));
    } catch (error) {
      logger.error('Place autocomplete error:', error.message);
      throw error;
    }
  }

  /**
   * Get place details by place_id
   */
  async getPlaceDetails(placeId) {
    try {
      const response = await this.client.placeDetails({
        params: {
          place_id: placeId,
          key: this.apiKey,
          fields: ['formatted_address', 'geometry', 'name', 'place_id', 'address_components', 'types'],
        },
      });

      if (response.data.status !== 'OK') {
        throw new Error(`Place details failed: ${response.data.status}`);
      }

      const result = response.data.result;
      return {
        place_id: result.place_id,
        name: result.name,
        formatted_address: result.formatted_address,
        latitude: result.geometry.location.lat,
        longitude: result.geometry.location.lng,
        address_components: result.address_components,
        types: result.types,
      };
    } catch (error) {
      logger.error('Place details error:', error.message);
      throw error;
    }
  }

  /**
   * Get ETA for driver to pickup
   */
  async getETA(driverLat, driverLng, pickupLat, pickupLng) {
    try {
      const directions = await this.getDirections(driverLat, driverLng, pickupLat, pickupLng);
      return {
        duration_seconds: directions.duration_seconds,
        duration_text: directions.duration_text,
        distance_meters: directions.distance_meters,
        distance_text: directions.distance_text,
      };
    } catch (error) {
      logger.error('ETA calculation error:', error.message);
      // Return approximate ETA based on straight-line distance
      const approxKm = this._haversineDistance(driverLat, driverLng, pickupLat, pickupLng);
      const approxMin = Math.ceil(approxKm * 2.5); // Assuming 25 km/h average
      return {
        duration_seconds: approxMin * 60,
        duration_text: `${approxMin} mins`,
        distance_meters: approxKm * 1000,
        distance_text: `${approxKm.toFixed(1)} km`,
        is_estimate: true,
      };
    }
  }

  _haversineDistance(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}

module.exports = new GoogleMapsService();
