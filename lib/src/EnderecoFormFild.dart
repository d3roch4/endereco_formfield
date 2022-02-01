import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Endereco.dart';
import 'SelecionarLocalWidget.dart';

class EnderecoFormField extends FormField<Endereco>{
  InputDecoration? inputDecoration;
  void Function(Endereco)? onChanged;
  VoidCallback? onEditingComplete;
  TextInputAction? textInputAction;
  bool autdoDetectar;
  
  EnderecoFormField({
    this.inputDecoration, 
    String Function(Endereco?)? validator,
    void Function(Endereco?)? onSaved,
    this.onChanged,
    this.onEditingComplete,
    Endereco? initialValue,
    this.textInputAction,
    this.autdoDetectar = true,
  }) : super(
    initialValue: initialValue,
    validator: validator,
    onSaved: onSaved,
    builder: (state) => (state as EnderecoFormFieldState).builder(state.context)
  );

  @override
  EnderecoFormFieldState createState() => EnderecoFormFieldState();
}

class EnderecoFormFieldState extends FormFieldState<Endereco>{
  final _focusNode = FocusNode();

  @override
  EnderecoFormField get widget => super.widget as EnderecoFormField;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if(_focusNode.hasFocus)
        escolherEndereco();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget builder(BuildContext context) {
    InputDecoration novoInputDecoration;
    if(widget.inputDecoration!=null)
      novoInputDecoration = widget.inputDecoration!.copyWith(errorText: this.errorText);
    else
      novoInputDecoration = InputDecoration(labelText: 'Endereço', errorText: this.errorText);

    return TextField(
      focusNode: _focusNode,
      onChanged: (value)=> escolherEndereco(),
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: (val)=>print(val),
      decoration: novoInputDecoration,
      textInputAction: widget.textInputAction,
      controller: TextEditingController(text: this.value != null ? this.value!.getEnderecoCompleto() : ""),
//          onTap: ()=> escolherEndereco(),
    );
  }

  void escolherEndereco() async {
    if(widget.onEditingComplete == null)
    _focusNode.unfocus();

    Endereco local = await Navigator.push(context, MaterialPageRoute(
      builder: (context) => SelecionarLocal(
        autoDetectar: widget.autdoDetectar && value?.longitude==null,
        cep: value!.cep,
        cidade: value!.cidade,
        endereco: value!.endereco,
        complemento: value!.complemento,
        latitude: value!.latitude,
        longitude: value!.longitude,
      )
    ));

    if(widget.onEditingComplete != null)
      widget.onEditingComplete!();

    this.didChange(local);
    if (widget.onChanged != null)
      widget.onChanged!(local);
  }
}
