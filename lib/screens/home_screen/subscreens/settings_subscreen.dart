import 'package:flutter/material.dart';
import 'package:freibad_app/provider/settings.dart';
import 'package:provider/provider.dart';

class SettingsSubscreen extends StatefulWidget {
  @override
  _SettingsSubscreenState createState() => _SettingsSubscreenState();
}

class _SettingsSubscreenState extends State<SettingsSubscreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Freibad-Server"),
              Switch.adaptive(
                activeColor: Theme.of(context).primaryColor,
                value: Provider.of<Settings>(context).useServer,
                onChanged: (value) {
                  Provider.of<Settings>(context, listen: false).useServer =
                      value;
                },
              )
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Weather-API"),
              Switch.adaptive(
                activeColor: Theme.of(context).primaryColor,
                value:
                    Provider.of<Settings>(context, listen: false).useWeatherAPI,
                onChanged: (value) {
                  Provider.of<Settings>(context, listen: false).useWeatherAPI =
                      value;
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
