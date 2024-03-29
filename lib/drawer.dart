import 'dart:async';
import 'dart:io';
import 'package:cavokator_flutter/favourites/favourites.dart';
import 'package:cavokator_flutter/temperature/temperature.dart';
import 'package:cavokator_flutter/utils/changelog.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:cavokator_flutter/weather/weather.dart';
import 'package:cavokator_flutter/condition/condition.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:cavokator_flutter/utils/shared_prefs.dart';
import 'package:cavokator_flutter/utils/theme_me.dart';
import 'package:cavokator_flutter/settings/settings.dart';
import 'package:cavokator_flutter/about/about.dart';
import 'package:rate_my_app/rate_my_app.dart';

class DrawerItem {
  String title;
  String asset;

  DrawerItem(this.title, this.asset);
}

class DrawerPage extends StatefulWidget {
  final Function changeBrightness;
  final bool savedThemeDark;
  final String thisAppVersion;

  DrawerPage({required this.changeBrightness, required this.savedThemeDark, required this.thisAppVersion});

  final drawerItems = [
    DrawerItem("Weather", "assets/icons/drawer_wx.png"),
    // DrawerItem("NOTAM", "assets/icons/drawer_notam.png"),
    DrawerItem("RWY Condition", "assets/icons/drawer_condition.png"),
    DrawerItem("TEMP Corrections", "assets/icons/drawer_temperature.png"),
    DrawerItem("Favourites", "assets/icons/drawer_favourites.png"),
    DrawerItem("Settings", "assets/icons/drawer_settings.png"),
    DrawerItem("About", "assets/icons/drawer_about.png"),
  ];

  @override
  _DrawerPageState createState() => _DrawerPageState();
}

class _DrawerPageState extends State<DrawerPage> {
  var _airports = <List<dynamic>>[];

  Future? _csvLoaded;

  int? _activeDrawerIndex = 0;
  int? _selected = 0;
  bool _sharedPreferencesReady = false;

  bool? _isThemeDark;
  bool _showHeaderImages = true;
  String _switchThemeString = "";

  double _scrollPositionWeather = 0;
  double _scrollPositionNotam = 0;

  bool _hideBottomNavBar = false;
  bool _bottomWeatherButtonDisabled = false;
  bool _bottomNotamButtonDisabled = false;
  bool _swipeSections = true; // TODO (maybe?): setting to deactivate this?

  bool? _numberOfMaxAirports;
  int _maxAirportsRequested = 8;

  late PageController _myPageController;

  // Parameters for Favourites
  bool _autoFetch = false;
  bool _fetchBoth = false;
  List<String> _favToWxNotam = <String>[];
  FavFrom _favFrom = FavFrom.drawer;
  List<String> _importedToFavourites = <String>[];

  Widget myFloat = SpeedDial(
    overlayColor: Colors.black,
    overlayOpacity: 0.5,
    elevation: 8.0,
    shape: CircleBorder(),
    visible: false,
  );

  void callbackFab(Widget fab) {
    setState(() {
      this.myFloat = fab;
    });
  }

  @override
  void initState() {
    super.initState();

    _csvLoaded = loadAsset();

    _handleVersionNumber();

    _restoreSharedPreferences().then((value) {
      setState(() {
        _sharedPreferencesReady = true;
      });
    });
  }

  @override
  void dispose() {
    _myPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isThemeDark = widget.savedThemeDark;
    _switchThemeString = _isThemeDark == true ? "DARK" : "LIGHT";
    var drawerOptions = <Widget>[];

    for (var i = 0; i < widget.drawerItems.length; i++) {
      var myItem = widget.drawerItems[i];
      Color? myBackgroundColor = Colors.transparent; // Transparent
      if (i == _selected) {
        myBackgroundColor = Colors.grey[200];
      }

      // Adding divider just before FAVOURITES (3 before end)
      if (i == widget.drawerItems.length - 3) {
        drawerOptions.add(Divider());
      }

      drawerOptions.add(
        ListTileTheme(
            selectedColor: Colors.red,
            iconColor: ThemeMe.apply(_isThemeDark, DesiredColor.MainText),
            textColor: ThemeMe.apply(_isThemeDark, DesiredColor.MainText),
            child: Ink(
              color: myBackgroundColor,
              child: ListTile(
                leading: ImageIcon(AssetImage(myItem.asset)),
                title: Text(myItem.title),
                selected: i == _selected,
                onTap: () => _onSelectItem(i),
              ),
            )),
      );
    }
    return FutureBuilder(
        future: _csvLoaded,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snampshot) {
          if (snampshot.connectionState == ConnectionState.done) {
            return Scaffold(
              floatingActionButton: myFloat,
              drawer: Drawer(
                elevation: 2, // This avoids shadow over SafeArea
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Container(
                      height: 300,
                      child: DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Container(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              Flexible(
                                child: Image(
                                  image: AssetImage('assets/images/appicon.png'),
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Text(
                                'CAVOKATOR',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(_switchThemeString),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 20),
                                    ),
                                    Flexible(
                                      child: Switch(
                                        value: _isThemeDark!,
                                        onChanged: (bool value) {
                                          _handleThemeChanged(value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(children: drawerOptions),
                  ],
                ),
              ),
              body: _getDrawerItemWidget(),
              //bottomNavigationBar: _bottomNavBar(),
            );
          } else {
            return Scaffold(
              body: Container(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/appicon.png'),
                        width: 200,
                      ),
                      Text(
                        'CAVOKATOR',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        });
  }

  Widget? _getDrawerItemWidget() {
    if (_sharedPreferencesReady) {
      // This shared pref. needs to go here or else won't update
      // live if we change the configuration in Settings
      SharedPreferencesModel().getSettingsShowHeaders().then((onValue) {
        _showHeaderImages = onValue;
      });
      SharedPreferencesModel().getSettingsMaxAirports().then((onValue) {
        if (onValue == 8) {
          _numberOfMaxAirports = true;
          _maxAirportsRequested = 8;
        } else {
          _numberOfMaxAirports = false;
          _maxAirportsRequested = 20;
        }
      });

      _myPageController = PageController(
        initialPage: (_activeDrawerIndex == 0) ? 0 : 1,
        keepPage: false,
      );

      switch (_activeDrawerIndex) {
        case 0:
          /*
          if (_swipeSections) {
            return PageView(
              physics: NeverScrollableScrollPhysics(),
              controller: _myPageController,
              children: <Widget>[
                WeatherPage(
                  isThemeDark: _isThemeDark,
                  myFloat: myFloat,
                  callback: callbackFab,
                  showHeaders: _showHeaderImages,
                  hideBottomNavBar: _turnBottomNavBarOff,
                  showBottomNavBar: _turnBottomNavBarOn,
                  recalledScrollPosition: _scrollPositionWeather,
                  notifyScrollPosition: _setWeatherScrollPosition,
                  airportsFromFav: _favToWxNotam,
                  autoFetch: _autoFetch,
                  cancelAutoFetch: _cancelAutoFetch,
                  callbackToFav: _callbackToFav,
                  fetchBoth: _fetchBoth,
                  maxAirportsRequested: _maxAirportsRequested,
                  thisAppVersion: widget.thisAppVersion,
                ),
                NotamPage(
                  isThemeDark: _isThemeDark,
                  myFloat: myFloat,
                  callback: callbackFab,
                  showHeaders: _showHeaderImages,
                  hideBottomNavBar: _turnBottomNavBarOff,
                  showBottomNavBar: _turnBottomNavBarOn,
                  recalledScrollPosition: _scrollPositionNotam,
                  notifyScrollPosition: _setNotamScrollPosition,
                  airportsFromFav: _favToWxNotam,
                  autoFetch: _autoFetch,
                  cancelAutoFetch: _cancelAutoFetch,
                  callbackToFav: _callbackToFav,
                  fetchBoth: _fetchBoth,
                  maxAirportsRequested: _maxAirportsRequested,
                  thisAppVersion: widget.thisAppVersion,
                ),
              ],
            );
          } else {
          */
          return WeatherPage(
            isThemeDark: _isThemeDark,
            myFloat: myFloat,
            callback: callbackFab,
            showHeaders: _showHeaderImages,
            hideBottomNavBar: _turnBottomNavBarOff,
            showBottomNavBar: _turnBottomNavBarOn,
            recalledScrollPosition: _scrollPositionWeather,
            notifyScrollPosition: _setWeatherScrollPosition,
            airportsFromFav: _favToWxNotam,
            autoFetch: _autoFetch,
            cancelAutoFetch: _cancelAutoFetch,
            callbackToFav: _callbackToFav,
            fetchBoth: _fetchBoth,
            maxAirportsRequested: _maxAirportsRequested,
            thisAppVersion: widget.thisAppVersion,
            airports: _airports,
          );
          //}
          break;
        /*
        case 1:
          if (_swipeSections) {
            return PageView(
              physics: NeverScrollableScrollPhysics(),
              controller: _myPageController,
              children: <Widget>[
                WeatherPage(
                  isThemeDark: _isThemeDark,
                  myFloat: myFloat,
                  callback: callbackFab,
                  showHeaders: _showHeaderImages,
                  hideBottomNavBar: _turnBottomNavBarOff,
                  showBottomNavBar: _turnBottomNavBarOn,
                  recalledScrollPosition: _scrollPositionWeather,
                  notifyScrollPosition: _setWeatherScrollPosition,
                  airportsFromFav: _favToWxNotam,
                  autoFetch: _autoFetch,
                  cancelAutoFetch: _cancelAutoFetch,
                  callbackToFav: _callbackToFav,
                  fetchBoth: _fetchBoth,
                  maxAirportsRequested: _maxAirportsRequested,
                  thisAppVersion: widget.thisAppVersion,
                ),
                NotamPage(
                  isThemeDark: _isThemeDark,
                  myFloat: myFloat,
                  callback: callbackFab,
                  showHeaders: _showHeaderImages,
                  hideBottomNavBar: _turnBottomNavBarOff,
                  showBottomNavBar: _turnBottomNavBarOn,
                  recalledScrollPosition: _scrollPositionNotam,
                  notifyScrollPosition: _setNotamScrollPosition,
                  airportsFromFav: _favToWxNotam,
                  autoFetch: _autoFetch,
                  cancelAutoFetch: _cancelAutoFetch,
                  callbackToFav: _callbackToFav,
                  fetchBoth: _fetchBoth,
                  maxAirportsRequested: _maxAirportsRequested,
                  thisAppVersion: widget.thisAppVersion,
                ),
              ],
            );
          } else {
            return NotamPage(
              isThemeDark: _isThemeDark,
              myFloat: myFloat,
              callback: callbackFab,
              showHeaders: _showHeaderImages,
              hideBottomNavBar: _turnBottomNavBarOff,
              showBottomNavBar: _turnBottomNavBarOn,
              recalledScrollPosition: _scrollPositionNotam,
              notifyScrollPosition: _setNotamScrollPosition,
              airportsFromFav: _favToWxNotam,
              autoFetch: _autoFetch,
              cancelAutoFetch: _cancelAutoFetch,
              callbackToFav: _callbackToFav,
              fetchBoth: _fetchBoth,
              maxAirportsRequested: _maxAirportsRequested,
              thisAppVersion: widget.thisAppVersion,
            );
          }
          break;
          */
        case 1:
          return ConditionPage(
            isThemeDark: _isThemeDark,
            myFloat: myFloat,
            callback: callbackFab,
            showHeaders: _showHeaderImages,
          );
        case 2:
          return TemperaturePage(
            isThemeDark: _isThemeDark,
            myFloat: myFloat,
            callback: callbackFab,
            showHeaders: _showHeaderImages,
          );
        case 3:
          return FavouritesPage(
            isThemeDark: _isThemeDark,
            callbackFab: callbackFab,
            callbackFromFav: _callbackFromFav,
            favFrom: _favFrom,
            importedAirports: _importedToFavourites,
            callbackPage: _callbackPage,
            maxAirportsRequested: _maxAirportsRequested,
          );
        case 4:
          return SettingsPage(
            isThemeDark: _isThemeDark,
            myFloat: myFloat,
            callback: callbackFab,
            showHeaders: _showHeaderImages,
            maxAirports: _numberOfMaxAirports,
          );
        case 5:
          return AboutPage(
            isThemeDark: _isThemeDark,
            myFloat: myFloat,
            callback: callbackFab,
            thisAppVersion: widget.thisAppVersion,
          );
        default:
          return Text("Error");
      }
    }
    return null;
  }

  _onSelectItem(int index) {
    /*
    if (index == 1 && _selected == 0) {
      _myPageController.animateToPage(
          1,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    } else if (index == 0 && _selected == 1) {
      _myPageController.animateToPage(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    }
    */

    setState(() {
      _activeDrawerIndex = index;
      _selected = index;
      _favFrom = FavFrom.drawer;
    });

    Navigator.of(context).pop();
  }

  _handleThemeChanged(bool newValue) {
    setState(() {
      _isThemeDark = newValue;
      _switchThemeString = (newValue == true) ? "DARK" : "LIGHT";
      if (newValue == true) {
        widget.changeBrightness(Brightness.dark);
        SharedPreferencesModel().setAppTheme("DARK");
      } else {
        widget.changeBrightness(Brightness.light);
        SharedPreferencesModel().setAppTheme("LIGHT");
      }
    });
  }

  Widget? _bottomNavBar() {
    if (_hideBottomNavBar) {
      return null;
    }

    if (_activeDrawerIndex == 0 || _activeDrawerIndex == 1) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: ThemeMe.apply(_isThemeDark, DesiredColor.MainText)!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              icon: ImageIcon(
                AssetImage("assets/icons/drawer_wx.png"),
                color: (_selected == 0)
                    ? ThemeMe.apply(_isThemeDark, DesiredColor.MagentaCategory)
                    : ThemeMe.apply(_isThemeDark, DesiredColor.MainText),
              ),
              onPressed: () {
                if (!_bottomWeatherButtonDisabled) {
                  _bottomNotamButtonDisabled = true;
                  _bottomWeatherButtonDisabled = true;
                  _myPageController.animateToPage(0, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
                  setState(() {
                    _selected = 0;
                  });
                  Future.delayed(Duration(milliseconds: 750), () {
                    _bottomNotamButtonDisabled = false;
                    _bottomWeatherButtonDisabled = false;
                  });
                }
              },
            ),
            IconButton(
              icon: ImageIcon(
                AssetImage("assets/icons/drawer_notam.png"),
                color: (_selected == 1)
                    ? ThemeMe.apply(_isThemeDark, DesiredColor.MagentaCategory)
                    : ThemeMe.apply(_isThemeDark, DesiredColor.MainText),
              ),
              onPressed: () {
                if (!_bottomNotamButtonDisabled) {
                  _bottomNotamButtonDisabled = true;
                  _bottomWeatherButtonDisabled = true;
                  _myPageController.animateToPage(1, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
                  setState(() {
                    _selected = 1;
                  });
                  Future.delayed(Duration(milliseconds: 750), () {
                    _bottomNotamButtonDisabled = false;
                    _bottomWeatherButtonDisabled = false;
                  });
                }
              },
            ),
          ],
        ),
      );
    } else {
      return null;
    }
  }

  Future<Null> _restoreSharedPreferences() async {
    var lastUsed;
    await SharedPreferencesModel().getSettingsLastUsedSection().then((onLastUsedValue) {
      lastUsed = int.parse(onLastUsedValue);
    });

    await SharedPreferencesModel().getSettingsOpenSpecificSection().then((onValue) async {
      var savedSelection = int.parse(onValue);
      if (savedSelection == 99) {
        // Open last-recalled page
        _activeDrawerIndex = _selected = lastUsed;
      } else {
        // Open specific (user chosen) page
        _activeDrawerIndex = _selected = int.parse(onValue);
      }
    });
  }

  void _handleVersionNumber() {
    SharedPreferencesModel().getAppVersion().then((onValue) async {
      if (onValue != widget.thisAppVersion) {
        if (onValue == "") {
          // Do nothing in this particular case as it is a  installation
          // and we only show news to those who already have the app
        } else {
          _showChangeLogDialog(context);
        }
        SharedPreferencesModel().setAppVersion(widget.thisAppVersion);
      } else {
        // Changelog is more important than RateMyApp

        RateMyApp rateMyApp = RateMyApp(
          preferencesPrefix: 'rateMyApp_',
          minDays: 7,
          minLaunches: 10,
          remindDays: 7,
          remindLaunches: 10,
          googlePlayIdentifier: 'com.github.manuito83.cavokator',
          appStoreIdentifier: '1476573096',
        );

        // DEBUG RATING
        // await rateMyApp.reset(); // Only to reset all rating SharedPreferences
        // The rest shows just one example (number of app launches)
        // SharedPreferences preferences = await SharedPreferences.getInstance();
        // var launches = preferences.getInt('rateMyApp_launches') ?? 0;
        // print("Total launches: $launches");

        rateMyApp.init().then((_) {
          if (rateMyApp.shouldOpenDialog) {
            rateMyApp.showRateDialog(
              context,
              title: 'Rate Cavokator (please?!)', // The dialog title.
              message: 'Cavokator is free with no ads, with the sole aim of '
                  'offering easy and quick access to information pilots need.'
                  '\n\nIf you have suggestions, please send us an email. '
                  'Otherwise, it would really help us if you rate us positively and '
                  'leave a comment, it shouldn\'t take more than a minute! '
                  '\n\nHowever, we won\'t ask again if you click NO. Thanks.',
              rateButton: 'YES, RATE!', // The dialog "rate" button text.
              noButton: 'NO', // The dialog "no" button text.
              laterButton: 'LATER', // The dialog "later" button text.
              dialogStyle: DialogStyle(), // Custom dialog styles.
            );
          }
        });
      }
    });
  }

  void _showChangeLogDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (context) {
          return ChangeLog(appVersion: widget.thisAppVersion);
        });
  }

  void _turnBottomNavBarOff() {
    setState(() {
      _hideBottomNavBar = true;
    });
  }

  void _turnBottomNavBarOn() {
    setState(() {
      _hideBottomNavBar = false;
    });
  }

  void _setWeatherScrollPosition(double position) {
    _scrollPositionWeather = position;
  }

  void _setNotamScrollPosition(double position) {
    _scrollPositionNotam = position;
  }

  void _callbackFromFav(int whatPage, List<String> favToWxNotam, bool autoFetch, bool fetchBoth) {
    setState(() {
      _activeDrawerIndex = whatPage;
      _selected = whatPage;
      _favToWxNotam = favToWxNotam;
      _autoFetch = autoFetch;
      _fetchBoth = fetchBoth;
    });
  }

  void _callbackToFav(int whatPage, FavFrom favFrom, List<String> importedToFavourites) {
    setState(() {
      _activeDrawerIndex = whatPage;
      _selected = whatPage;
      _favFrom = favFrom;
      _importedToFavourites = importedToFavourites;
    });
  }

  void _cancelAutoFetch() {
    _autoFetch = false;
    _favToWxNotam.clear();
  }

  void _callbackPage(int whatPage) {
    setState(() {
      _activeDrawerIndex = whatPage;
      _selected = whatPage;
    });
  }

  Future loadAsset() async {
    await rootBundle.loadString('assets/airports/airports.csv').then((value) async {
      List<List<dynamic>> csvTable = CsvToListConverter().convert(
        value,
        fieldDelimiter: ";",
        eol: Platform.isAndroid ? "\r\n" : "\n",
      );
      _airports = csvTable;
    });
  }
}
