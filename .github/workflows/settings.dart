
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
class SettingsOverlay extends StatelessWidget{
  static const id='settings'; final Game game;
  final VoidCallback? onResume; final Future<void> Function()? onSave; final Future<void> Function()? onLoad; final Future<void> Function()? onReset;
  const SettingsOverlay({super.key,required this.game,this.onResume,this.onSave,this.onLoad,this.onReset});
  @override Widget build(BuildContext context){return Align(alignment:Alignment.center,child:Container(
    margin:const EdgeInsets.all(20),padding:const EdgeInsets.all(16),width:700,
    decoration:BoxDecoration(color:const Color(0xDD111111),borderRadius:BorderRadius.circular(16)),
    child:DefaultTextStyle(style:const TextStyle(color:Colors.white),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text("Пауза / Налаштування",style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:8,children:[
        ElevatedButton(onPressed:onResume,child:const Text("Продовжити")),
        ElevatedButton(onPressed:onSave,child:const Text("Зберегти")),
        ElevatedButton(onPressed:onLoad,child:const Text("Завантажити")),
        ElevatedButton(onPressed:() async{
          final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
            title:const Text("Скинути прогрес?"),content:const Text("Це видалить збереження."),
            actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text("Ні")),TextButton(onPressed:()=>Navigator.pop(context,true),child:const Text("Так"))],
          )); if(ok==true) await onReset?.call();
        },child:const Text("Скинути")),
      ]),
    ])),
  ));}
}
