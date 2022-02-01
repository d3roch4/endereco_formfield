import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_geocoding/google_geocoding.dart' as google_geocoding;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:location/location.dart' as webLocations;
import 'package:flutter/gestures.dart';

import 'Endereco.dart';

class SelecionarLocal extends StatefulWidget{
  String cep;
  String cidade;
  String endereco;
  String complemento;
  double longitude;
  double latitude;
  bool autoDetectar;
  void Function(Endereco)? callback;

  SelecionarLocal({this.autoDetectar=true, required this.cep, required this.cidade, required this.endereco, required this.complemento, required this.latitude, required this.longitude, this.callback});

  @override
  _SelecionarLocalState createState() => _SelecionarLocalState();
}

class _SelecionarLocalState extends State<SelecionarLocal> {
  final _formKey = GlobalKey<FormState>();
  Endereco local = Endereco();
  var marcadores = Set<Marker>();
  TextEditingController? _cidadeController;
  TextEditingController? _enderecoController;
  TextEditingController? _cepController;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ZOOM_PADRAO = 16.0746;
  var googleGeocoding = google_geocoding.GoogleGeocoding("AIzaSyC-FoK9iKn8qrPX5bkRv-Z-soSns8svL7o");
  Completer<GoogleMapController> mapCtrl = Completer();

  @override
  void initState() {
    super.initState();
    marcadores.clear();

    _cidadeController = TextEditingController(text: widget.cidade);
    _enderecoController = TextEditingController(text: widget.endereco);
    _cepController = TextEditingController(text: widget.cep);

    if(widget.latitude!=null && widget.longitude!=null){
      var latLng = LatLng(widget.latitude, widget.longitude);
      marcadores.add(new Marker(position: latLng, markerId: MarkerId('posicaoAtual')));
    }
    else {
      var latLng = LatLng(-15.5321073, -55.5462201);
      marcadores.add(new Marker(position: latLng, markerId: MarkerId('posicaoAtual')));
    }
    if(widget.autoDetectar == true)
      detectarLocal();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text("Selecione um local"),
        actions: [
          ElevatedButton.icon(
            style: ButtonStyle(elevation: MaterialStateProperty.all(0)),
            icon: Icon(Icons.gps_fixed),
            label: Text('Detectar'),
            onPressed: detectarLocal
          )
        ],
      ),
      body: SingleChildScrollView(
        child: GetPlatform.isMobile || GetPlatform.isWeb
          ? getMapaEform()
          : getFormulario()
      )
    );
  }

  Widget getMapaEform(){
    return Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height/2.5,
            child: GoogleMap(
              mapType: MapType.hybrid,
              markers: marcadores,
              initialCameraPosition: CameraPosition(target: marcadores.first.position, zoom: ZOOM_PADRAO),
              onTap: _onTap,
              onMapCreated: (c)=> mapCtrl.complete(c),
              gestureRecognizers: Set()..add(Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())),
            )
        ),
          getFormulario()
      ]
    );
  }

  Widget getFormulario()
  {
    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TypeAheadFormField<Placemark>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _cepController,
                decoration: InputDecoration(labelText: 'Cep',
                    hintText: 'Ex.: 47806000'),
              ),
              suggestionsCallback: (query) async {
                var cep = await buscaCep(query);
                if(cep.isNotEmpty){
                  var place = Placemark(
                    country: 'BR',
                    locality: cep['localidade'],
                    subLocality: cep['bairro'],
                    administrativeArea: cep['uf'],
                    postalCode: cep['cep'],
                    thoroughfare: cep['logradouro'],
                    subThoroughfare: ''
                  );
                  return [place];
                }
                return [];
              },
              noItemsFoundBuilder: (c)=>Container(height: 0),
              itemBuilder: (context, suggestion) {
                return Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(placemark2string(suggestion)??''),
                );
              },
              onSuggestionSelected: (suggestion) async {
                var locs = await getCoordenasPorEndereco(placemark2string(suggestion)??'');
                var loc = locs[0];
                setCidade(suggestion, LatLng(loc.latitude, loc.longitude));
                setaEndereco(suggestion);
              },
              onSaved: (valor) => widget.cep = valor!,
            ),
            TypeAheadFormField<Placemark>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _cidadeController,
                decoration: InputDecoration(labelText: 'Cidade'),
              ),
              suggestionsCallback: buscaCidades,
              noItemsFoundBuilder: (c)=>Container(height: 0),
              itemBuilder: (context, sug) {
                var texto = getNomeCidade(sug);
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(texto),
                );
              },
              onSuggestionSelected: (sug) async{
                if (_cidadeController!.text == 'test') {
                  this._enderecoController!.text = ' ';
                  setCidade(sug, LatLng(-99, -99));
                }else {
                  var locs = await getCoordenasPorEndereco(placemark2string(sug)??'');
                  var loc = locs.first;
                  setCidade(sug, LatLng(loc.latitude, loc.longitude));
                }
                FocusScope.of(context).nextFocus();
              },
              validator: (valor) {
                if (valor!.isEmpty)
                  return 'Informe a cidade.';
                return null;
              },
              onSaved: (valor) => widget.cidade = valor!,
            ),
            TypeAheadFormField<Placemark>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _enderecoController,
                decoration: InputDecoration(labelText: 'Endereço',
                    hintText: 'Ex.: Rua Getulio Vargas, nº 53, Centro'),
              ),
              suggestionsCallback: (query) async {
                return getSugestoesEndereco(query);
              },
              noItemsFoundBuilder: (c)=>Container(height: 0),
              itemBuilder: (context, suggestion) {
                return Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(suggestion.name??''),
                );
              },
              onSuggestionSelected: (suggestion) async{
                var locs = await getCoordenasPorEndereco(placemark2string(suggestion)??'');
                var loc = locs[0];
                setCidade(suggestion, LatLng(loc.latitude, loc.longitude), zoom: ZOOM_PADRAO);
                setaEndereco(suggestion);
              },
              validator: (valor) {
                if (valor!.isEmpty)
                  return 'Preencha o endereço.';
                return null;
              },
              onSaved: (valor) => widget.endereco = valor!,
            ),
            TextFormField(
              controller: TextEditingController(text: widget.complemento),
              decoration: InputDecoration(labelText: 'Complemento'),
              maxLines: 2,
              onSaved: (valor) => widget.complemento = valor!,
            ),
            FractionallySizedBox(widthFactor: 1, child: RaisedButton(
              color: Get.theme.accentColor,
              child: Text('Continuar'),
              onPressed: finalizar,
            ))
          ],
        ),
      ),
    );
  }

  void finalizar() {
    local.latitude = widget.latitude;
    local.longitude = widget.longitude;

    if (local.longitude == null || local.latitude == null)
      scaffoldKey.currentState!.showSnackBar(SnackBar(content: Text(
          'Não foi possível obter as coordenas geograficas desse local.')));

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      local.cidade = widget.cidade;
      local.endereco = widget.endereco;
      local.complemento = widget.complemento;
      local.cep = widget.cep;

      if (widget.callback != null)
        widget.callback!(local);
      else
        Navigator.pop(context, local);
    }
  }

  String? placemark2string(Placemark place){
    return place.country=='Test' ? place.country : '${place.thoroughfare}, ${getNomeCidade(place)}';
  }

  Future<List<Placemark>> getSugestoesEndereco(String query) async {
    var cep = await buscaCep(query);
    if (cep.length > 0) {
      query = '${cep['cep']}, ${cep['logradouro']}, ${cep['bairro']}, ${cep['localidade']}, ${cep['uf']}';
      try {
        var lista = await getCoordenasPorEndereco(
            query, localeIdentifier: 'pt_BR');
        var places = await getPlacemarksPorCoordenadas(lista.first.latitude, lista.first.longitude);
        var place = places.first.toJson();
        place['thoroughfare'] = cep['logradouro'];
        place['subLocality'] = cep['bairro'];
        place['postalCode'] = cep['cep'];
        places.first = Placemark.fromMap(place);
        return places; //.map<String>((placemark)=>'${placemark.name}').toList();
      }catch(ex, stack){
        return [];
      }
    }

    query = '${query}, ${_cidadeController!.text}';
    try {
      var lista = await getCoordenasPorEndereco(
          query, localeIdentifier: 'pt_BR');
      return getPlacemarksPorCoordenadas(lista.first.latitude, lista.first.longitude); //.map<String>((placemark)=>'${placemark.name}').toList();
    }catch(ex, stack){
      return [];
    }
  }

  Future<Map<String, dynamic>> buscaCep(String cep) async {
    cep = cep.numericOnly();
    if(cep.length == 8) {
      var resp = await http.get(Uri.parse('https://viacep.com.br/ws/${cep}/json/'));
      if (resp.statusCode == 200) {
        dynamic result = json.decode(resp.body);
        if (result['erro'] != true) {
          return result;
        }
      }
    }
    return {};
  }

  Future<bool> detectarLocal() async {
    var location = new webLocations.Location();

    bool _serviceEnabled;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return false;
      }
    }

    var loc = await location.getLocation();
    _onTap(LatLng(loc.latitude!, loc.longitude!));
    return true;
  }

  Future<List<Placemark>> buscaCidades(String query) async {
    query = query.toLowerCase();
    if(query == 'test' || query == 'teste')
      return [new Placemark(country: 'Test')];
    if(query.isEmpty) {
      widget.cidade = '';
      _cidadeController!.clear();
      return
        [];
    }
    try{
      var lista = await getCoordenasPorEndereco('${query}');
      var places = getPlacemarksPorCoordenadas(lista.first.latitude, lista.first.longitude);
      return places;
    }catch(ex, stack){
      return [];
    }
  }

  String getNomeCidade(Placemark sug){
    String texto;
    if(sug.country == 'Test')//sug.position.latitude == -99 && sug.position.longitude == -99)
      texto = 'Test';
    else {
      String? cidade = sug.locality!.length > 0 ? sug.locality : sug.subAdministrativeArea;
      texto = '${cidade} - ${sug.administrativeArea}, ${sug.country}';
    }

    return texto;
  }

  Future<void> _onTap(LatLng latLong) async {
    widget.latitude = latLong.latitude;
    widget.longitude = latLong.longitude;
    print('Coordenadas setadas: ${widget.latitude}, ${widget.longitude}');

    List<Placemark> placemark = await getPlacemarksPorCoordenadas(widget.latitude, widget.longitude);

    if(placemark.isNotEmpty) {
      var first = placemark.first;
      setaEndereco(first);
      setCidade(first, latLong);
    }
  }

  void setCep(Placemark placemark) {
    widget.cep = placemark.postalCode!;
    this._cepController!.text = widget.cep;
  }

  void setCidade(Placemark place, LatLng latLong, {double? zoom}){
    _cidadeController!.text = getNomeCidade(place);
    setCep(place);
    moverCamera(LatLng(latLong.latitude, latLong.longitude), zoom: zoom);
  }

  void setaEndereco(Placemark placemark){
    widget.endereco = '${placemark.thoroughfare}, ${placemark.subThoroughfare}, ${placemark.subLocality}';
    this._enderecoController!.text = widget.endereco;
    setCep(placemark);
  }

  Future<void> moverCamera(LatLng latLng, {double? zoom}) async {
    widget.latitude = latLng.latitude;
    widget.longitude = latLng.longitude;
    print('movendo camera para: ${latLng.latitude},${latLng.longitude}');

    var cameraPosicao = CameraPosition(
      target: latLng,
      zoom: zoom ?? ZOOM_PADRAO,
    );
    await mapCtrl.future..animateCamera(CameraUpdate.newCameraPosition(cameraPosicao));
    marcadores.clear();
    marcadores.add( Marker(markerId: MarkerId(latLng.toString()), position: latLng) );
    setState(() {});
  }

  Future<List<Placemark>> getPlacemarksPorCoordenadas(double latitude, double longitude) async {
    List<Placemark> placemarkes;
    if(GetPlatform.isWeb){
      var result = await googleGeocoding.geocoding.getReverse(google_geocoding.LatLon(latitude, longitude));
      google_geocoding.AddressComponent Function() notFound = (){return google_geocoding.AddressComponent(longName: '', shortName: '');};

      placemarkes = result!.results!.map((e) => Placemark(
        name: e.formattedAddress,
        subAdministrativeArea: e.addressComponents!.firstWhere((c) => c.types!.contains('administrative_area_level_'), orElse: notFound).shortName,
        administrativeArea: e.addressComponents!.firstWhere((c) => c.types!.contains('administrative_area_level_1'), orElse: notFound).longName,
        subLocality: e.addressComponents!.firstWhere((c) => c.types!.contains('sublocality'), orElse: notFound).longName,
        locality: e.addressComponents!.firstWhere((c) => c.types!.contains('administrative_area_level_2'), orElse: notFound).longName,
        thoroughfare: e.addressComponents!.firstWhere((c) => c.types!.contains('route'), orElse: notFound).shortName,
        subThoroughfare: e.addressComponents!.firstWhere((c) => c.types!.contains('street_number'), orElse: notFound).shortName,
        country: e.addressComponents!.firstWhere((c) => c.types!.contains('country'), orElse: notFound).longName,
        postalCode: e.addressComponents!.firstWhere((c) => c.types!.contains('postal_code'), orElse: notFound).longName,
      )).toList();
    }else
      placemarkes = await placemarkFromCoordinates(latitude, longitude);

    return placemarkes;
  }

  getCoordenasPorEndereco(String endereco, {String localeIdentifier='pt_BR'}) async {
    if(GetPlatform.isWeb) {
      var risult = await googleGeocoding.geocoding.get(endereco, []);
      return risult!.results!.map((e) => Location(
          latitude: e.geometry!.location!.lat??0, longitude: e.geometry!.location!.lng??0, timestamp: DateTime.now()
      )).toList();
    }else
      return await locationFromAddress(endereco);
  }
}