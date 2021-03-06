import 'package:freibad_app/models/person.dart';
import 'package:freibad_app/models/request.dart';
import 'package:freibad_app/models/session.dart';
import 'package:freibad_app/services/reserve_api.dart';
import 'package:freibad_app/services/weather_api.dart';

abstract class API {}

class APIService extends API {
  static Future<bool> registerUser(String name, String password) async {
    try {
      return ReserveAPIService.registerUser(name, password);
    } catch (exception) {
      throw exception;
    }
  }

  static Future<String> loginUser(String name, String password) async {
    try {
      return ReserveAPIService.loginUser(name, password);
    } catch (exception) {
      throw exception;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWeather(
    double requestLocationLat,
    double requestLocationLon,
  ) async {
    return WeatherAPIService.fetchWeather(
        requestLocationLat, requestLocationLon);
  }

  static Future<bool> addPerson(Person person, String token) {
    try {
      return ReserveAPIService.addPerson(person, token);
    } catch (exception) {
      throw exception;
    }
  }

  static Future<bool> editPerson(Person person, String token) {
    try {
      return ReserveAPIService.updatePerson(person, token);
    } catch (exception) {
      throw exception;
    }
  }

  static Future<Session> makeReservation(
      Request session, String locationId, String token) {
    return ReserveAPIService.makeReservation(session, locationId, token);
  }

  static Future<Session> getReservation(String sessionId, String token) {
    return ReserveAPIService.getReservation(sessionId, token);
  }

  static Future<bool> deleteReservation(String sessionId, String token) {
    return ReserveAPIService.deleteReservation(sessionId, token);
  }

  static Future<List<Map<String, String>>> availableLocations(String token) {
    return ReserveAPIService.availableLocations(token);
  }

  static Future<List<Map<String, dynamic>>> availableTimeBlocks(String token) {
    return ReserveAPIService.availableTimeBlocks(token);
  }

  static Future<Map<String, List<dynamic>>> getUserData(String token) async {
    return ReserveAPIService.getUserData(token);
  }
}

class FakeAPIService extends API {
  static Future<List<Map<String, dynamic>>> fetchWeather(
    double requestLocationLat,
    double requestLocationLon,
  ) async {
    return FakeWeatherAPIService.fetchWeather(
        requestLocationLat, requestLocationLon);
  }

  static Future<bool> registerUser(String name, String password) {
    return FakeReserveAPIService.registerUser(name, password);
  }

  static Future<String> loginUser(String name, String password) {
    return FakeReserveAPIService.loginUser(name, password);
  }

  static Future<bool> addPerson(Person person, String token) {
    return FakeReserveAPIService.addPerson(person, token);
  }

  static Future<bool> editPerson(Person person, String token) {
    return FakeReserveAPIService.editPerson(person, token);
  }

  static Future<Session> makeReservation(
      Session session, String locationId, String token) {
    return FakeReserveAPIService.makeReservation(session, locationId, token);
  }

  static Future<Session> getReservation(String sessionId, String token) {
    return FakeReserveAPIService.getReservation(sessionId, token);
  }

  static Future<bool> deleteReservation(String sessionId, String token) {
    return FakeReserveAPIService.deleteReservation(sessionId, token);
  }

  static Future<List<Map<String, String>>> availableLocations(String token) {
    return FakeReserveAPIService.availableLocations(token);
  }

  static Future<List<Map<String, dynamic>>> availableTimeBlocks(String token) {
    return FakeReserveAPIService.availableTimeBlocks(token);
  }

  static Future<Map<String, List<dynamic>>> getUserData(String token) async {
    return FakeReserveAPIService.getUserData(token);
  }
}
