import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:freibad_app/models/appointment.dart';
import 'package:freibad_app/models/person.dart';
import 'package:freibad_app/models/request.dart';
import 'package:freibad_app/models/session.dart';
import 'package:freibad_app/services/api_service.dart';
import 'package:freibad_app/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class SessionData with ChangeNotifier {
  final bool useAPIService;
  final bool useStorageService;
  final String token;

  List<Person> _persons;
  List<Session> _appointments;
  List<Request> _requests;
  List<Map<String, String>> _availableLocations = [];
  List<Map<String, dynamic>> _availableTimeBlocks = [];

  List<Person> get persons => [..._persons];
  List<Session> get appointments => [..._appointments];
  List<Request> get requests => [..._requests];
  List<String> get availableLocations {
    if (_availableLocations.isEmpty) {
      _setLocaitonData();
      //trying again for next refresh
    }

    List<String> temp = [];
    for (Map<String, String> location in _availableLocations) {
      temp.add(location['name']);
    }
    return temp;
  }

  StorageService db;
  //use LocalStorage for production, use FakeLocalStorage for web

  Uuid uuid = Uuid(); // for creating unique ids

  SessionData({
    this.useAPIService = false,
    this.useStorageService = false,
    @required this.token,
  }) {
    if (useStorageService)
      db = LocalStorage();
    else
      db = FakeLocalStorage();
  }

  Future<void> fetchAndSetData() async {
    await db.setUpDB(); //loads DB
    _persons = await db.getPersons() ?? [];
    _appointments = await db.getAppointment() ?? [];
    _requests = await db.getRequests() ?? [];
    developer.log('fetching and setting local data finished');

    if (_persons.isEmpty && _appointments.isEmpty && _requests.isEmpty) {
      //syncing server data for a new login or a web login
      Map<String, List<dynamic>> userData;

      try {
        userData = (useAPIService
            ? await APIService.getUserData(token)
            : await FakeAPIService.getUserData(token));
        if (userData != null) {
          for (Session session in userData['sessions']) {
            _addSession(session);
          }
          for (Person person in userData['persons']) {
            _addPersonLocal(person);
          }
        }
      } catch (exception) {
        developer.log('something went wrong getting the user data: ',
            error: exception);
      }
    }

    //look for updates for requests
    for (Request request in _requests) {
      if (!useStorageService || kIsWeb)
        break; //do not make server request with wrong data or if data gets loaded from the server anyway
      if (request.hasFailed) continue;
      developer.log("looking for an update for $request");
      try {
        Session session = (useAPIService
            ? await APIService.getReservation(request.id, token)
            : await FakeAPIService.getReservation(request.id, token));

        if (session is Request) continue;

        _addAppointment(
          id: session.id,
          accessList: session.accessList,
          startTime: session.startTime,
          endTime: session.endTime,
          location: session.location,
        );
        deleteRequest(session.id);
      } catch (exception) {
        developer.log('Something went wrong updating the pending session',
            error: exception);
        continue;
      }
    }
    developer.log('finished updating pending sessions');

    _setLocaitonData();
    _setOpeningHoursData();
    notifyListeners();
  }

  void _setLocaitonData() async {
    try {
      _availableLocations = useAPIService
          ? await APIService.availableLocations(token)
          : await FakeAPIService.availableLocations(token);
      developer.log('finished receiving available time blocks');
    } catch (exception) {
      developer.log('Something went wrong loading the location data: ',
          error: exception);
    }
  }

  void _setOpeningHoursData() async {
    try {
      _availableTimeBlocks = useAPIService
          ? await APIService.availableTimeBlocks(token)
          : await FakeAPIService.availableTimeBlocks(token);
      developer.log('finished updating pending sessions');
    } catch (exception) {
      developer.log('Something went wrong loading the opening hours data: ',
          error: exception);
    }
  }

  String getLocationId(String location) {
    return _availableLocations[_availableLocations
        .indexWhere((element) => element['name'] == location)]['locationId'];
  }

  List<List<DateTime>> getTimeBlocks(String location, DateTime date) {
    if (_availableTimeBlocks.isEmpty) {
      _setOpeningHoursData();
      //trying again for next refresh
    }

    List<List<DateTime>> response = [];
    String locationId = getLocationId(location);
    int isoWeekday = date.weekday;

    List<Map<String, dynamic>> timeBlocksData = _availableTimeBlocks
        .where((element) => (element['locationId'] == locationId &&
            element['isoWeekday'] == isoWeekday))
        .toList();
    for (Map<String, dynamic> timeBlockData in timeBlocksData) {
      response.add([
        date.add(Duration(minutes: timeBlockData['startMinute'])),
        date.add(Duration(minutes: timeBlockData['endMinute']))
      ]);
    }

    return response;
  }

  Person findPersonById(String id) {
    Person unidentifiedPerson = Person(
        id: '',
        forename: 'Unknown',
        name: 'Unknown',
        streetName: 'Unknown',
        streetNumber: 'Unknown',
        postcode: 0,
        city: 'Unknown',
        phoneNumber: 'Unknown',
        email: 'Unknown');
    if (_persons == null) {
      return unidentifiedPerson;
    }
    try {
      return _persons.firstWhere((element) => element.id == id);
    } catch (exception) {
      developer.log('Looking up person with id: $id failed: ',
          error: exception);
      return unidentifiedPerson;
    }
  }

  void addPerson({
    @required String forename,
    @required String name,
    @required String streetName,
    @required String streetNumber,
    @required int postcode,
    @required String city,
    @required String phoneNumber,
    @required String email,
  }) async {
    Person person = Person(
        id: uuid.v1(),
        forename: forename,
        name: name,
        streetName: streetName,
        streetNumber: streetNumber,
        postcode: postcode,
        city: city,
        phoneNumber: phoneNumber,
        email: email);

    try {
      bool apiCallSuccessful = (useAPIService
          ? await APIService.addPerson(person, token)
          : await FakeAPIService.addPerson(person, token));
      if (!apiCallSuccessful) return;
      _addPersonLocal(person);
    } catch (exception) {
      developer.log('something went wrong adding a person: ', error: exception);
      //throw exception;
    }
    notifyListeners();
  }

  void _addPersonLocal(Person person) {
    db.addPerson(person);
    _persons.add(person);
    developer.log('added person');
  }

  void updatePerson({
    @required String id,
    String forename,
    String name,
    String streetName,
    String streetNumber,
    int postcode,
    String city,
    String phoneNumber,
    String email,
  }) async {
    Person currentPerson = findPersonById(id);
    Person updatedPerson = Person(
      id: id,
      forename: forename ?? currentPerson.forename,
      name: name ?? currentPerson.name,
      streetName: streetName ?? currentPerson.streetName,
      streetNumber: streetNumber ?? currentPerson.streetNumber,
      postcode: postcode ?? currentPerson.postcode,
      city: city ?? currentPerson.city,
      phoneNumber: phoneNumber ?? currentPerson.phoneNumber,
      email: email ?? currentPerson.email,
    );
    try {
      bool apiCallSuccessful = useAPIService
          ? await APIService.editPerson(updatedPerson, token)
          : await FakeAPIService.editPerson(updatedPerson, token);
      if (!apiCallSuccessful) return;

      db.updatePerson(updatedPerson);
      int pos = _persons.indexWhere((element) => element.id == id);
      _persons.replaceRange(pos, pos + 1, [updatedPerson]);
      developer.log('updated person');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void _addAppointment({
    String id,
    @required List<Map<String, String>> accessList,
    @required DateTime startTime,
    @required DateTime endTime,
    @required String location,
  }) async {
    Appointment appointment = Appointment(
        id: id ?? uuid.v1(),
        accessList: accessList,
        startTime: startTime,
        endTime: endTime,
        location: location);
    try {
      db.addSession(appointment);
      _appointments.add(appointment);
      developer.log('added appointment');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void addRequest({
    @required List<Map<String, String>> accessList,
    @required DateTime startTime,
    @required DateTime endTime,
    @required String location,
  }) async {
    Request request = Request(
        id: uuid.v1(),
        accessList: accessList,
        startTime: startTime,
        endTime: endTime,
        hasFailed: false,
        location: location);
    try {
      String locationId = getLocationId(location);

      Session resultSession = useAPIService
          ? await APIService.makeReservation(request, locationId, token)
          : await FakeAPIService.makeReservation(request, locationId, token);
      _addSession(resultSession);
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void _addSession(Session resultSession) {
    db.addSession(resultSession);

    if (resultSession is Request) {
      _requests.add(resultSession);
      developer.log('added request');
    } else if (resultSession is Appointment) {
      _appointments.add(resultSession);
      developer.log('added appointment');
    } else {
      developer.log(
          'Type of session is not saved. Type: ${resultSession.runtimeType}');
    }
  }

  void deletePerson(String personId) {
    try {
      db.deletePerson(personId);
      _persons
          .removeAt(_persons.indexWhere((element) => element.id == personId));
      developer.log('deleted person');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void deleteSession(Session session) {
    try {
      if (session is Appointment) {
        deleteAppointment(session.id);
      } else if (session is Request) {
        deleteRequest(session.id);
      } else {
        throw 'Add support to the Database for the children of Sessions';
      }
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  Future<void> deleteAppointment(String appointmentId) async {
    int elementPos =
        _appointments.indexWhere((element) => element.id == appointmentId);
    //save appointment, just in case something goes wrong
    Appointment appointmentToDelete = _appointments[elementPos];

    try {
      _appointments.removeAt(elementPos);
      notifyListeners();

      bool apiCallSuccessful = useAPIService
          ? await APIService.deleteReservation(appointmentId, token)
          : await FakeAPIService.deleteReservation(appointmentId, token);
      if (!apiCallSuccessful) {
        //api call not successful, add appointment back to list
        developer.log('api call not successful');
        _appointments.add(appointmentToDelete);
        notifyListeners();
        return;
      }

      db.deleteAppointment(appointmentId);
      developer.log('deleted appointment');
    } catch (exception) {
      //add appointment to list, to allow clean removal from server
      _appointments.add(appointmentToDelete);
      notifyListeners();
      developer.log(exception);
      throw exception;
    }
  }

  void deleteRequest(String requestId) async {
    int elementPos = _requests.indexWhere((element) => element.id == requestId);
    //save request, just in case something goes wrong
    Request requestToDelete = _requests[elementPos];

    try {
      _requests.removeAt(elementPos);
      notifyListeners();
      bool apiCallSuccessful = useAPIService
          ? await APIService.deleteReservation(requestId, token)
          : await FakeAPIService.deleteReservation(requestId, token);

      if (!apiCallSuccessful) {
        //api call not successful, add request back to list
        developer.log('api call not successful');
        _requests.add(requestToDelete);
        notifyListeners();
        return;
      }

      db.deleteRequest(requestId);
      developer.log('deleted request');
    } catch (exception) {
      //add request to list, to allow clean removal from server
      _requests.add(requestToDelete);
      notifyListeners();
      developer.log(exception);
      throw exception;
    }
  }
}
