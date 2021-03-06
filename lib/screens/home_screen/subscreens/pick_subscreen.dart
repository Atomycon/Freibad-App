import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:date_picker_timeline/date_picker_timeline.dart';
import 'package:freibad_app/models/person.dart';
import 'package:freibad_app/models/weather.dart';
import 'package:freibad_app/provider/session_data.dart';
import 'package:freibad_app/provider/weather_data.dart';
import 'package:freibad_app/screens/home_screen/components/person_detail_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PickSubscreen extends StatefulWidget {
  @override
  _PickSubscreenState createState() => _PickSubscreenState();
}

class _PickSubscreenState extends State<PickSubscreen> {
  DateTime sessionDate;
  DateTime startTime;
  DateTime endTime;
  String location;
  List<Person> selectedPersons = [];
  Map<DateTime, Weather> cachedWeather;
  DateTime currentMaxTempDateTime;

  @override
  Widget build(BuildContext context) {
    if (sessionDate != null && cachedWeather != null) {
      currentMaxTempDateTime = cachedWeather[sessionDate].maxTempTime;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            FutureBuilder(
              initialData: cachedWeather,
              future: Provider.of<WeatherData>(context, listen: false)
                  .getWeatherForecast(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.connectionState == ConnectionState.done)
                    cachedWeather = snapshot.data;

                  return buildDateSelector(snapshot.data);
                } else if (snapshot.hasError) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Weather not available'),
                      content: Text('Something went wrong ${snapshot.error}'),
                      actions: <Widget>[
                        FlatButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('OK'))
                      ],
                    ),
                  );
                }
                return buildDateSelector(cachedWeather);
              },
            ),
            if (sessionDate != null && location != null)
              buildTimeSelector(
                  Provider.of<SessionData>(context)
                      .getTimeBlocks(location, sessionDate),
                  maxTemp: currentMaxTempDateTime),
            buildLocationSelector(),
            buildPersonSelector(context),
            buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget buildDateSelector(Map<DateTime, Weather> weatherForecast) {
    bool hasWeather = weatherForecast != null && weatherForecast.length > 0;

    double dateInfoWidgetHeight = 11.5;
    double selectorHeight = 100;
    double selectorWidth = 75;

    int numberOfDays;

    Color selectedColor = Theme.of(context).primaryColor;
    Color unselectedColor = Colors.white;

    Map<DateTime, Widget> selectedDateInfo = {};
    Map<DateTime, Widget> unselectedDateInfo = {};

    if (hasWeather)
      weatherForecast.forEach(
        (date, dailyWeatherForecast) {
          selectedDateInfo.putIfAbsent(
            date,
            () => _getWeatherWidget(
              dailyWeatherForecast.skyIcon,
              '${dailyWeatherForecast.maxTemp} ${dailyWeatherForecast.tempUnit}',
              dateInfoWidgetHeight,
              selectedColor,
            ),
          );
          unselectedDateInfo.putIfAbsent(
            date,
            () => _getWeatherWidget(
              dailyWeatherForecast.skyIcon,
              '${dailyWeatherForecast.maxTemp} ${dailyWeatherForecast.tempUnit}',
              dateInfoWidgetHeight,
              unselectedColor,
            ),
          );
        },
      );

    numberOfDays = hasWeather ? weatherForecast.length : 15;

    return Container(
      width: selectorWidth * (numberOfDays + 1) +
          20, //define width, so the widget can be centered, 20px for edge
      child: DatePicker(
        DateTime.now(),
        key: ObjectKey(
            cachedWeather), //TODO figure out why UniqueKey does not work here?
        daysCount: numberOfDays,
        onDateChange: (selectedDate) {
          setState(
            () {
              startTime = null;
              sessionDate = selectedDate;
            },
          );
        },
        selectedTextColor: selectedColor,
        unselectedTextColor: Colors.white,
        selectedBackgroundColor: Colors.transparent,
        height: selectorHeight,
        width: selectorWidth,
        dateInfoHeight: dateInfoWidgetHeight,
        unselectedDateInfo: unselectedDateInfo,
        selectedDateInfo: selectedDateInfo,
      ),
    );
  }

  Widget buildTimeSelector(List<List<DateTime>> timeBlocks,
      {DateTime maxTemp}) {
    //find time closest to the best weather
    DateTime bestStartTime;
    if (maxTemp != null) {
      Duration shortestGap;
      for (List<DateTime> timeBlock in timeBlocks) {
        for (DateTime time in timeBlock) {
          Duration timeDifference = time.difference(maxTemp).abs();
          if (shortestGap == null) {
            shortestGap = timeDifference;
            bestStartTime = timeBlock[0];
          } else if (shortestGap > timeDifference) {
            shortestGap = timeDifference;
            bestStartTime = timeBlock[0];
          }
        }
      }
      //developer.log('$bestStartTime recommended session start time for maxTemp: $maxTemp (according to the ClimaCellApi)');
    }
    return Column(
      children: timeBlocks
          .map(
            (time) => SizedBox(
              width: double.infinity,
              child: FlatButton(
                onPressed: () {
                  setState(() {
                    startTime = time[0];
                    endTime = time[1];
                  });
                },
                textColor:
                    startTime != null && startTime.compareTo(time[0]) == 0
                        ? Theme.of(context).primaryColor
                        : time[0] == bestStartTime
                            ? Theme.of(context).primaryColor.withOpacity(0.5)
                            : Colors.white,
                child: Text(
                  '${DateFormat.Hm().format(time[0])} - ${DateFormat.Hm().format(time[1])}',
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget buildLocationSelector() {
    List<String> availableLocations =
        Provider.of<SessionData>(context).availableLocations;
    location = location ?? availableLocations[0];
    return DropdownButton(
      value: location,
      dropdownColor: Theme.of(context).cardColor,
      items: List.generate(
        availableLocations.length,
        (i) => DropdownMenuItem(
          value: availableLocations[i],
          child: Text(availableLocations[i]),
        ),
      ),
      onChanged: (value) {
        setState(
          () {
            location = value;
          },
        );
      },
    );
  }

  Widget buildPersonSelector(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: IconButton(
            icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => buildSelectPersonDialog(context),
              );
            },
          ),
        ),
        ...selectedPersons.map(
          (person) => Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              padding: EdgeInsets.all(8),
              width: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('${person.forename} ${person.name}'),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      setState(
                        () {
                          selectedPersons.remove(person);
                        },
                      );
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Container buildSubmitButton(BuildContext context) {
    return Container(
      width: 150,
      child: RaisedButton.icon(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        onPressed: () {
          if (sessionDate != null &&
              startTime != null &&
              selectedPersons != null &&
              location != null &&
              selectedPersons.isNotEmpty) {
            developer.log(
                "request for $selectedPersons on $startTime for $location");

            Scaffold.of(context).showSnackBar(
              SnackBar(
                content: Text("Request send!"),
              ),
            );

            Provider.of<SessionData>(context, listen: false).addRequest(
              accessList: [
                for (Person person in selectedPersons) ...{
                  {'person': person.id, 'code': ''}
                }
              ],
              startTime: startTime,
              endTime: endTime,
              location: location,
            );
            setState(() {
              startTime = null;
              endTime = null;
              sessionDate = null;
              selectedPersons = [];
            });
          } else {
            Scaffold.of(context).showSnackBar(
              SnackBar(
                content: Text("Add date/location/person"),
              ),
            );
          }
        },
        color: Theme.of(context).cardColor,
        icon: Icon(
          Icons.check,
          color: Theme.of(context).primaryColor,
        ),
        label: Text(
          'Submit',
          style: TextStyle(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  SimpleDialog buildSelectPersonDialog(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      backgroundColor: Theme.of(context).cardColor,
      children: [
        IconButton(
          icon: Icon(
            Icons.add,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => PersonDetailDialog(
                canEdit: true,
                personId: null,
              ),
            );
          },
        ),
        ...Provider.of<SessionData>(context).persons.map(
          (person) {
            if (!selectedPersons.contains(person)) {
              return InkWell(
                onTap: () {
                  setState(
                    () {
                      selectedPersons.add(person);
                    },
                  );
                  Navigator.pop(context);
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => PersonDetailDialog(
                      canEdit: true,
                      personId: person.id,
                    ),
                  );
                },
                child: SizedBox(
                  height: 35,
                  child: Center(
                    child: Text(
                      '${person.forename} ${person.name}',
                    ),
                  ),
                ),
              );
            } else {
              return Container();
            }
          },
        )
      ],
    );
  }

  Widget _getWeatherWidget(
      IconData skyIcon, String temp, double size, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          skyIcon,
          color: color,
          size: size,
        ),
        Text(
          temp,
          style: TextStyle(fontSize: size, color: color),
        ),
      ],
    );
  }
}
