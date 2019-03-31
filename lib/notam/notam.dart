import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cavokator_flutter/utils/custom_sliver.dart';
import 'package:cavokator_flutter/json_models/notam_json.dart';
import 'package:cavokator_flutter/utils/theme_me.dart';
import 'package:cavokator_flutter/utils/shared_prefs.dart';
import 'package:cavokator_flutter/private.dart';

class NotamPage extends StatefulWidget {

  NotamPage({@required this.isThemeDark});

  final bool isThemeDark;

  @override
  _NotamPageState createState() => _NotamPageState();
}

class _NotamPageState extends State<NotamPage> {
  final _formKey = GlobalKey<FormState>();
  final _myTextController = new TextEditingController();

  String _userSubmitText;
  List<String> _myRequestedAirports = new List<String>();
  List<NotamJson> _myNotamList = new List<NotamJson>();
  bool _apiCall = false;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).requestFocus(new FocusNode()),
          child: CustomScrollView(
            slivers: _buildSlivers(context),
          ),
        );
      },
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    List<Widget> slivers = new List<Widget>();

    slivers.add(_myAppBar());
    slivers.add(_inputForm());

    var notamSect = _notamSections();
    for (var section in notamSect) {
      slivers.add(section);
    }

    return slivers;
  }

  Widget _myAppBar() {
    return SliverAppBar(
      iconTheme: new IconThemeData(color: Colors.black),
      title: Text(
        "NOTAM",
        style: TextStyle(color: Colors.black),
      ),
      expandedHeight: 150,
      // TODO: Settings option (value '0' if inactive)
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: new AssetImage('assets/images/notam_header.jpg'),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.access_alarm),
          color: Colors.black,
          onPressed: () {
            // TEST
          },
        ),
        IconButton(
          icon: Icon(Icons.clear),
          color: Colors.black,
          onPressed: () {
            // TEST
          },
        ),
      ],
    );
  }

  Widget _inputForm() {
    return CustomSliverSection(
      child: Container(
        margin: EdgeInsets.fromLTRB(10, 10, 10, 50),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(color: Colors.grey),
            color: ThemeMe.apply(widget.isThemeDark, DesiredColor.MainBackground)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                      ),
                      ImageIcon(
                        AssetImage("assets/icons/drawer_wx.png"),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 20, 0),
                      ),
                      Expanded(
                        child: TextFormField(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          keyboardType: TextInputType.text,
                          maxLines: null,
                          controller: _myTextController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: "Enter ICAO/IATA airports",
                          ),
                          validator: (value) {
                            if (value.isEmpty) {
                              return "Please enter at least one valid airport!";
                            } else {
                              // Try to parse some airports
                              // Split the input to suit or needs
                              RegExp exp = new RegExp(r"([a-z]|[A-Z]){3,4}");
                              Iterable<Match> matches =
                              exp.allMatches(_userSubmitText);
                              matches.forEach(
                                      (m) => _myRequestedAirports.add(m.group(0)));
                            }
                            if (_myRequestedAirports.isEmpty) {
                              return "Could not identify a valid airport!";
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                      ),
                      RaisedButton(
                          child: Text('Fetch WX!'),
                          onPressed: () {
                            _fetchButtonPressed(context);
                          }),
                      Padding(padding: EdgeInsets.fromLTRB(0, 0, 10, 0)),
                      RaisedButton(
                        child: Text('Clear'),
                        onPressed: () {
                          setState(() {
                            _apiCall = false;
                            _myNotamList.clear();
                            SharedPreferencesModel().setWeatherUserInput("");
                            SharedPreferencesModel().setWeatherInformation("");
                            _myTextController.text = "";
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _notamSections() {
    List<Widget> mySections = List<Widget>();

    if (_apiCall) {
      mySections.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) =>
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsetsDirectional.only(top: 50),
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ),
            childCount: 1,
          ),
        ),
      );
    } else {
      if (_myNotamList.isNotEmpty) {

      }
      else {
        mySections.add(
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(),
              childCount: 1,
            ),
          ),
        );
      }
    }

    return mySections;
  }

  @override
  void initState() {
    super.initState();

    _restoreSharedPreferences();

    _userSubmitText = _myTextController.text;
    _myTextController.addListener(onInputTextChange);
  }


  void _restoreSharedPreferences() {
    SharedPreferencesModel().getNotamUserInput().then((onValue) {

      setState(() {
        _myTextController.text = onValue;
      });
    });

    SharedPreferencesModel().getNotamInformation().then((onValue) {
      if (onValue.isNotEmpty){
        setState(() {
          _myNotamList = notamJsonFromJson(onValue);
        });
      }
    });
  }


  void _fetchButtonPressed(BuildContext context) {
    _myRequestedAirports.clear();

    if (_formKey.currentState.validate()) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Fetching NOTAMS, hold position!'),
        ),
      );
      setState(() {
        _apiCall = true;
      });

      _callNotamApi().then((weatherJson) {
        setState(() {
          _apiCall = false;
          if (weatherJson != null) {
            _myNotamList = weatherJson;
          }
        });
      });

    }
    FocusScope.of(context).requestFocus(new FocusNode());
  }

  // Ensure that submitted airports are split correctly
  void onInputTextChange() {
    // Ensure that submitted airports are split correctly
    String textEntered = _myTextController.text;
    // Don't do anything if we are deleting text!
    if (textEntered.length > _userSubmitText.length) {
      if (textEntered.length > 3) {
        // Take a look at the last 4 chars entered
        String lastFourChars =
        textEntered.substring(textEntered.length - 4, textEntered.length);
        // If there is at least a space, do nothing
        bool spaceDetected = true;
        for (String char in lastFourChars.split("")) {
          if (char == " ") {
            spaceDetected = false;
          }
        }
        if (spaceDetected) {
          _myTextController.text = textEntered + " ";
          _myTextController.selection = TextSelection.fromPosition(
              TextPosition(offset: _myTextController.text.length));
        }
      }
    }
    _userSubmitText = textEntered;
  }

  Future<List<NotamJson>> _callNotamApi() async {
    String allAirports = "";
    if (_myRequestedAirports.isNotEmpty) {
      for (var i = 0; i < _myRequestedAirports.length; i++) {
        if (i != _myRequestedAirports.length - 1) {
          allAirports += _myRequestedAirports[i] + ",";
        } else {
          allAirports += _myRequestedAirports[i];
        }
      }
    }

    String server = PrivateVariables.apiURL;
    String api = "Notam/GetNotam?";
    String source = "source=Cavokator";
    String airports = "&airports=$allAirports";
    String url = server + api + source + airports;

    List<NotamJson> exportedJson;
    try {
      final response = await http.post(url).timeout(Duration(seconds: 15));
      if (response.statusCode != 200) {
        // TODO: this error is OK, but what about checking Internet connectivity as well??
        Scaffold.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Oops! There was connection error!',
                style: TextStyle(
                  color: Colors.black,
                )
            ),
            backgroundColor: Colors.red[100],
          ),
        );
        return null;
      }
      exportedJson = notamJsonFromJson(response.body);
      SharedPreferencesModel().setNotamInformation(response.body);
      SharedPreferencesModel().setNotamInformation(_userSubmitText);
    } catch (Exception) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Oops! There was connection error!',
              style: TextStyle(
                color: Colors.black,
              )
          ),
          backgroundColor: Colors.red[100],
        ),
      );
      return null;
    }
    return exportedJson;
  }





}