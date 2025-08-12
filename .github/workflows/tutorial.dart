
import 'package:flutter/material.dart';
class TutorialOverlay extends StatelessWidget{
  static const id='tutorial'; final VoidCallback onClose; const TutorialOverlay({super.key,required this.onClose});
  @override Widget build(BuildContext context){return Stack(children:[
    Container(color:const Color(0xCC000000)),
    Center(child:Container(padding:const EdgeInsets.all(16),margin:const EdgeInsets.all(20),width:700,
      decoration:BoxDecoration(color:const Color(0xFF1E1E1E),borderRadius:BorderRadius.circular(12)),
      child:const Column(mainAxisSize:MainAxisSize.min,children:[
        Text("Як грати",style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold)),SizedBox(height:8),
        Text("Оранка → Культивація → Посів → Ріст → Збір. Купуй насіння/паливо/агрегати в Магазині. Обирай культуру та працюй відповідним комбайном.",style:TextStyle(color:Colors.white70)),
      ]),
    )),
    Positioned(top:40,right:20,child:ElevatedButton(onPressed:onClose,child:const Text("Закрити"))),
  ]);}
}
