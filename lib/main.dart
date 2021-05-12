import 'dart:async';
import 'dart:io';
import 'package:find_hotel/app.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:find_hotel/bottom_navigation/bloc/bottom_navigation_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'package:find_hotel/home/view/place_detail_widget.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as LocationManager;
import 'package:flutter_bloc/flutter_bloc.dart';
const kGoogleApiKey = "AIzaSyDRrbd-AJN0bph6zCa8Yd6l7pADEJIuptA";
GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey,);

void main() {
  runApp(App(authenticationRepository:AuthenticationRepository(),
    userRepository: UserRepository(),));
}

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
  static Route route() {
    return MaterialPageRoute<void>(builder: (_) => Home());
  }
}

class HomeState extends State<Home> {
  final homeScaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController mapController;
  List<PlacesSearchResult> places = [];
  bool isLoading = false;
  String errorMessage;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  String defaultLocale = Platform.localeName;

  @override
  Widget build(BuildContext context) {
    Widget expandedChild;
    if (isLoading) {
      expandedChild = Center(child: CircularProgressIndicator(value: null));
    } else if (errorMessage != null) {
      expandedChild = Center(
        child: Text(errorMessage),
      );
    } else {
      expandedChild = buildPlacesList();
    }

    return Scaffold(
        key: homeScaffoldKey,
        appBar: AppBar(
          title: const Text("FindY Hotel"),
          actions: <Widget>[
            isLoading
                ? IconButton(
              icon: Icon(Icons.timer),
              onPressed: () {},
            )
                : IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                refresh();
              },
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                _handlePressButton();
              },
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              child: SizedBox(
                  height: 200.0,
                  child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      myLocationEnabled: true,
                      initialCameraPosition:
                      const CameraPosition(target: LatLng(0.0, 0.0)),

                      markers: Set<Marker>.of(markers.values),
                    onTap: _handleTap,
                  ))),

            Expanded(child: expandedChild)
          ], 
        ),
    );
  }
  _handleTap(LatLng point) {
    setState(() {
      final marker =(Marker(
        markerId: MarkerId(point.toString()),
        position: point,
        infoWindow: InfoWindow(
          title: 'I am a marker',
        ),
        icon:
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
      ));
      markers[marker.markerId]=marker;
      refresh();
    });
  }
  void refresh() async {
    final center = await getUserLocation();

    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: center == null ? LatLng(0, 0) : center, zoom: 15.0)));
    getNearbyPlaces(center);
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    refresh();
  }

  Future<LatLng> getUserLocation() async {
    var currentLocation;
    final location = LocationManager.Location();
    try {
      final currentLocation = await location.getLocation();
      final lat = currentLocation.latitude;
      final lng = currentLocation.longitude;
      final center = LatLng(lat, lng);
      return center;
    } on Exception {
      currentLocation = null;
      return null;
    }
  }

  void getNearbyPlaces(LatLng center) async {
    setState(() {
      this.isLoading = true;
      this.errorMessage = null;
    });

    final location = Location(center.latitude, center.longitude);
    final result = await _places.searchNearbyWithRadius(location, 2500 ,type:"lodging",language: defaultLocale);
    setState(() {
      this.isLoading = false;
      try{
      if (result.status == "OK") {
        this.places = result.results;
        result.results.forEach((f) {
          final marker= Marker(
              markerId: MarkerId(f.geometry.location.lat.toString() +
                  f.geometry.location.lng.toString()),
              position: LatLng(f.geometry.location.lat, f.geometry.location.lng),
              infoWindow: InfoWindow(title:"${f.name}", snippet:"${f.types?.first}"));
          markers[marker.markerId] = marker;
        });
      } else {
        this.errorMessage = result.errorMessage;
      }}
      catch(Exception){
        this.errorMessage = result.errorMessage;
      }
    });
  }

  void onError(PlacesAutocompleteResponse response) {
    homeScaffoldKey.currentState.showSnackBar(
      SnackBar(content: Text(response.errorMessage)),
    );
  }

  Future<void> _handlePressButton() async {
    try {
      final center = await getUserLocation();
      Prediction p = await PlacesAutocomplete.show(
          context: context,
          strictbounds: center == null ? false : true,
          apiKey: kGoogleApiKey,
          onError: onError,
          mode: Mode.fullscreen,
          language: defaultLocale,
          location: center == null
              ? null
              : Location(center.latitude, center.longitude),
          radius: center == null ? null : 1000000);

      showDetailPlace(p.placeId);
    } catch (e) {
      return;
    }
  }

  Future<Null> showDetailPlace(String placeId) async {
    if (placeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlaceDetailWidget(placeId)),
      );
    }
  }

  ListView buildPlacesList() {
    final placesWidget = places.map((f) {
      List<Widget> list = [
        Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text(
            f.name,
            style: Theme.of(context).textTheme.subtitle,
          ),
        )
      ];
      if (f.formattedAddress != null) {
        list.add(Padding(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Text(
            f.formattedAddress,
            style: Theme.of(context).textTheme.subtitle,
          ),
        ));
      }

      if (f.vicinity != null) {
        list.add(Padding(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Text(
            f.vicinity,
            style: Theme.of(context).textTheme.body1,
          ),
        ));
      }

      if (f.types?.first != null) {
        list.add(Padding(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Text(
            f.types.first,
            style: Theme.of(context).textTheme.caption,
          ),
        ));
      }

      return Padding(
        padding: EdgeInsets.only(top: 4.0, bottom: 4.0, left: 8.0, right: 8.0),
        child: Card(
          child: InkWell(
            onTap: () {
              showDetailPlace(f.placeId);
            },
            highlightColor: Colors.lightBlueAccent,
            splashColor: Colors.red,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: list,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return ListView(shrinkWrap: true, children: placesWidget);
  }
}