
class Endereco {
  String cep='';
  String cidade='';
  String endereco='';
  String complemento='';
  double longitude=0;
  double latitude=0;

  Endereco();

  String getEnderecoCompleto(){
    String retorno = '';
    if(endereco.isNotEmpty){
      if(retorno.isNotEmpty) retorno += ', ';
      retorno += endereco;
    }
    if(complemento.isNotEmpty){
      if(retorno.isNotEmpty) retorno += ', ';
      retorno += complemento;
    }
    if(cidade.isNotEmpty) {
      if(retorno.isNotEmpty) retorno += ', ';
      retorno += cidade;
    }
    if(cep.isNotEmpty){
      if(retorno.isNotEmpty) retorno += ', CEP: ';
      retorno += cep;
    }
    return retorno;
  }

  Endereco.fromJson(Map<String, dynamic> json){
    cep = json['cep'];
    cidade = json['cidade'];
    endereco = json['endereco'];
    complemento = json['complemento'];
    longitude = json['longitude'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson(){
    return {
      'cep': cep,
      'cidade': cidade,
      'endereco': endereco,
      'complemento': complemento,
      'longitude': longitude,
      'latitude': latitude
    };
  }
}
